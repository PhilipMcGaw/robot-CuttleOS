from collections import namedtuple
import asyncio
import json
import logging
import os
import threading
import time
from datetime import datetime, timezone
from enum import Enum
from pathlib import Path

import board
import busio
import nats
from adafruit_ads7830.analog_in import AnalogIn
import adafruit_ads7830.ads7830
from adafruit_motor import servo
from adafruit_pca9685 import PCA9685
from board import SCL, SDA

from .time_sync import (
    TimeSynchronisationConfig,
    load_time_synchronisation_config,
    parse_time_synchronisation_message,
)

logger = logging.getLogger(__name__)
logging.basicConfig(format="%(levelname)s: %(message)s", level=logging.INFO)

i2c = busio.I2C(SCL, SDA)
pca = PCA9685(i2c, address=0x5F)  # ROV hardware uses PCA9685 address 0x5F.

pca.frequency = 50

NATS_URL = os.getenv("NATS_URL", "nats://127.0.0.1:4222")
NATS_SUBJECT = os.getenv("NATS_SUBJECT", ">")
NATS_LOSS_TIMEOUT_MS = float(os.getenv("NATS_LOSS_TIMEOUT_MS", "100"))
ROBOT_PROFILE_PATH = Path(os.getenv("ROBOT_PROFILE_PATH", "/etc/robot/profile.json"))
nats_data = {}
nats_lock = threading.Lock()
nats_client = None
nats_loop = None
nats_ready = threading.Event()
nats_connected = threading.Event()
nats_fault = threading.Event()
nats_disconnected_at = None


class ControlState(Enum):
    """High-level Control state used to gate actuator authority."""

    INITIALISING = "initialising"
    ACTIVE = "active"
    NATS_DISCONNECTED = "nats-disconnected"
    NATS_FAULT = "nats-fault"


control_state = ControlState.INITIALISING
control_state_lock = threading.Lock()


def set_control_state(state: ControlState) -> None:
    """Set the Control state in one place so future safety transitions stay explicit."""
    global control_state
    with control_state_lock:
        if control_state != state:
            logger.info("Control state: %s -> %s", control_state.value, state.value)
        control_state = state


def get_control_state() -> ControlState:
    """Return the current Control state safely across the NATS and control threads."""
    with control_state_lock:
        return control_state


def load_active_time_synchronisation_config() -> TimeSynchronisationConfig | None:
    """Load the optional browser-clock contract once as Control starts."""
    try:
        config = load_time_synchronisation_config(ROBOT_PROFILE_PATH)
    except ValueError as exc:
        logger.error("Time synchronisation is disabled: invalid active profile %s: %s", ROBOT_PROFILE_PATH, exc)
        return None
    if config is None:
        logger.warning("Browser time synchronisation is disabled: no enabled configuration in %s", ROBOT_PROFILE_PATH)
        return None
    logger.info("Browser time synchronisation enabled for profile %s", config.profile_id)
    return config


TIME_SYNCHRONISATION_CONFIG = load_active_time_synchronisation_config()

ServoChannelData = namedtuple('ServoChannelData', ['number', 'topic', 'home_angle', 'current_angle'])

servo_channels = {
    # PCA9685 channels 12–15 are reserved for the H-bridges.
    "Camera": ServoChannelData(0, "output/servos/camera/demand", 90, 90),
    "Front Left": ServoChannelData(1, "output/servos/front_left/demand", 90, 90),
    "Front Right": ServoChannelData(2, "output/servos/front_right/demand", 90, 90),
    "Rear Left": ServoChannelData(3, "output/servos/rear_left/demand", 90, 90),
    "Rear Right": ServoChannelData(4, "output/servos/rear_right/demand", 90, 90),
    "Vertical Left Front": ServoChannelData(5, "output/servos/vertical_left_front/demand", 90, 90),
    "Vertical Right Front": ServoChannelData(6, "output/servos/vertical_right_front/demand", 90, 90),
    "Vertical Rear Left": ServoChannelData(7, "output/servos/vertical_rear_left/demand", 90, 90),
    "Vertical Rear Right": ServoChannelData(8, "output/servos/vertical_rear_right/demand", 90, 90),
}

AnalogChannelData = namedtuple('AnalogChannelData', ['number', 'topic', 'previous_value', 'current_value', 'last_read_time', 'alpha', 'interval'])

analog_channels = {
    "Battery Level": AnalogChannelData(0, "input/analog/battery/raw", 0, 0, 0, 0.1, 1),
    "Analog Channel 1": AnalogChannelData(1, "input/analog/light_tracker/raw", 0, 0, 0, 0.1, 10),
    "Analog Channel 2": AnalogChannelData(2, "input/analog/2/raw", 0, 0, 0, 0.1, 10),
    "Analog Channel 3": AnalogChannelData(3, "input/analog/3/raw", 0, 0, 0, 0.1, 10),
    "Analog Channel 4": AnalogChannelData(4, "input/analog/4/raw", 0, 0, 0, 0.1, 10),
    "Analog Channel 5": AnalogChannelData(5, "input/analog/5/raw", 0, 0, 0, 0.1, 10),
    "Analog Channel 6": AnalogChannelData(6, "input/analog/6/raw", 0, 0, 0, 0.1, 10),
    "Analog Channel 7": AnalogChannelData(7, "input/analog/7/raw", 0, 0, 0, 0.1, 10),
}


def dashboard_topic(subject):
    return subject.replace(".", "/")


async def publish_time_synchronisation_status(
    config: TimeSynchronisationConfig,
    *,
    utc_unix_ms: int,
    offset_seconds: float,
    status: str,
) -> None:
    """Publish an observational result without feeding it back into the clock handler."""
    if nats_client is None:
        return
    payload = {
        "value": utc_unix_ms,
        "units": "ms",
        "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "profile": config.profile_id,
        "source": "control",
        "status": status,
        "offset_seconds": round(offset_seconds, 3),
    }
    try:
        await nats_client.publish(config.status_subject, json.dumps(payload, separators=(",", ":")).encode())
    except Exception as exc:
        logger.warning("Could not publish time-synchronisation status: %s", exc)


async def handle_time_synchronisation(message) -> None:
    """Apply one validated browser time value when the active profile permits it."""
    config = TIME_SYNCHRONISATION_CONFIG
    if config is None:
        return
    try:
        request = parse_time_synchronisation_message(message.data, config)
    except ValueError as exc:
        logger.warning("Rejected browser time-synchronisation message: %s", exc)
        return

    if abs(request.offset_seconds) < config.minimum_adjustment_seconds:
        await publish_time_synchronisation_status(
            config,
            utc_unix_ms=request.utc_unix_ms,
            offset_seconds=request.offset_seconds,
            status="within-tolerance",
        )
        return

    try:
        time.clock_settime(time.CLOCK_REALTIME, request.utc_unix_ms / 1_000)
    except AttributeError:
        logger.error("Browser time synchronisation requires Linux time.clock_settime support")
        return
    except PermissionError:
        logger.error("Browser time synchronisation needs CAP_SYS_TIME; install configs/python.service and restart Control")
        return
    except OSError as exc:
        logger.error("Could not apply browser time synchronisation: %s", exc)
        return

    logger.info("Updated system clock from Cockpit (offset %.3f s)", request.offset_seconds)
    await publish_time_synchronisation_status(
        config,
        utc_unix_ms=request.utc_unix_ms,
        offset_seconds=request.offset_seconds,
        status="adjusted",
    )


async def on_message(message):
    config = TIME_SYNCHRONISATION_CONFIG
    if config is not None and message.subject == config.command_subject:
        await handle_time_synchronisation(message)
        return
    with nats_lock:
        nats_data[dashboard_topic(message.subject)] = message.data.decode(errors="replace")


async def on_nats_disconnected():
    global nats_disconnected_at
    nats_connected.clear()
    nats_disconnected_at = time.monotonic()
    if not nats_fault.is_set():
        set_control_state(ControlState.NATS_DISCONNECTED)
    logger.warning("NATS connection interrupted; monitoring for recovery within %.0f ms.", NATS_LOSS_TIMEOUT_MS)


async def on_nats_reconnected():
    global nats_disconnected_at
    disconnected_for = 0.0
    if nats_disconnected_at is not None:
        disconnected_for = (time.monotonic() - nats_disconnected_at) * 1_000
    nats_disconnected_at = None
    nats_connected.set()
    if nats_fault.is_set():
        set_control_state(ControlState.NATS_FAULT)
        logger.warning("NATS connection restored after %.0f ms; operator re-arm required.", disconnected_for)
    else:
        set_control_state(ControlState.ACTIVE)
        logger.warning("NATS connection recovered after %.0f ms; operation continues.", disconnected_for)


async def connect_nats():
    global nats_client
    nats_client = await nats.connect(
        NATS_URL,
        disconnected_cb=on_nats_disconnected,
        reconnected_cb=on_nats_reconnected,
    )
    await nats_client.subscribe(NATS_SUBJECT, cb=on_message)
    nats_ready.set()
    nats_connected.set()
    logger.info("Connected to NATS Core at %s, subject %s", NATS_URL, NATS_SUBJECT)


def nats_thread():
    global nats_loop
    nats_loop = asyncio.new_event_loop()
    asyncio.set_event_loop(nats_loop)
    try:
        nats_loop.run_until_complete(connect_nats())
        nats_loop.run_forever()
    except Exception:
        logger.exception("NATS connection stopped")
    finally:
        nats_loop.close()


def set_safe_outputs() -> None:
    """Force all actuators to their safe physical state."""
    for data in servo_channels.values():
        set_angle(int(data.number), int(data.home_angle))
    for channel in range(12, 16):
        pca.channels[channel].duty_cycle = 0x0000


def enter_nats_safe_state() -> None:
    if nats_fault.is_set():
        return
    nats_fault.set()
    set_control_state(ControlState.NATS_FAULT)
    logger.error("NATS connection has exceeded %.0f ms; forcing robot to safe state.", NATS_LOSS_TIMEOUT_MS)
    with nats_lock:
        nats_data.clear()
    set_safe_outputs()


def check_nats_safety() -> None:
    if nats_connected.is_set() or nats_fault.is_set() or nats_disconnected_at is None:
        return
    if (time.monotonic() - nats_disconnected_at) * 1_000 >= NATS_LOSS_TIMEOUT_MS:
        enter_nats_safe_state()


def publish_nats(topic, value):
    if nats_client is None or nats_loop is None or not nats_ready.is_set() or not nats_connected.is_set():
        logger.warning("NATS is not connected; cannot publish %s", topic)
        return
    subject = topic.replace("/", ".")
    future = asyncio.run_coroutine_threadsafe(
        nats_client.publish(subject, str(value).encode()), nats_loop
    )
    future.result(timeout=2)


def publish_camera_pitch(servo_angle: int, home_angle: int) -> None:
    """Publish camera inclination relative to the ROV body; zero is straight ahead."""
    publish_nats("sensor/camera/main/pitch", int(servo_angle) - int(home_angle))


def read_analog_channels():
    global analog_channels

    i2c = board.I2C()
    adc = adafruit_ads7830.ads7830.ADS7830(i2c)

    with nats_lock:
        for name, data in analog_channels.items():
            raw_analog_value = AnalogIn(adc, data.number).value

            last_read_time = data.last_read_time
            if time.monotonic() >= last_read_time:
                logger.info(f"Read {name} to Value {raw_analog_value}")

                publish_nats(data.topic, raw_analog_value)
                last_read_time = time.monotonic() + data.interval

                if name == "Battery Level":
                    # R15 and R17 form the on-board battery voltage divider.
                    # R15 = 3 kΩ and R17 = 1 kΩ, giving a divider ratio of 0.25.
                    # The battery limits are 6.00 V (empty) and 8.28 V (full).
                    r15 = 3
                    r17 = 1
                    battery_empty = 6.0
                    battery_full = 8.28
                    division_ratio = r17 / (r15 + r17)
                    # TODO: Verify the ADC reference voltage and fitted divider before
                    # treating the calculated battery voltage as validated telemetry.
                    actual_battery_voltage = (raw_analog_value / 65535) * 5 / division_ratio
                    battery_percentage = ((actual_battery_voltage - battery_empty) / (battery_full - battery_empty)) * 100

                    publish_nats("input/analog/battery/percentage", round(battery_percentage, 2))
                    publish_nats("input/analog/battery/voltage", round(actual_battery_voltage, 2))
                    logger.info(f"Current battery level: {round(battery_percentage, 2)} %")

            analog_channels[name] = AnalogChannelData(
                number=data.number,
                topic=data.topic,
                previous_value=data.previous_value,
                current_value=raw_analog_value,
                last_read_time=last_read_time,
                interval=data.interval,
                alpha=data.alpha,
            )


def write_servo_outputs():
    global servo_channels

    if nats_fault.is_set() or not nats_connected.is_set():
        return

    with nats_lock:
        for name, data in servo_channels.items():
            if data.topic in nats_data:
                demanded_angle = int(nats_data[data.topic])
                if 0 <= demanded_angle <= 180:
                    if demanded_angle != data.current_angle:
                        set_angle(int(data.number), int(demanded_angle))
                        servo_channels[name] = ServoChannelData(
                            number=data.number,
                            topic=data.topic,
                            home_angle=data.home_angle,
                            current_angle=demanded_angle,
                        )
                        if name == "Camera":
                            publish_camera_pitch(demanded_angle, data.home_angle)
                        logger.debug(f"Set {name} (Channel {data.number}) to angle {demanded_angle}")
                else:
                    logger.warning(f"Demanded angle {demanded_angle} for {name} is out of range (0-180)")


def write_hbridge_outputs():
    if nats_fault.is_set() or not nats_connected.is_set():
        return

    with nats_lock:
        hbridge_left_demand = int(nats_data.get("output/hbridge/left/demand", 0))
        hbridge_right_demand = int(nats_data.get("output/hbridge/right/demand", 0))

        # Each H-bridge uses complementary inputs to select direction; zero disables both inputs.
        if hbridge_left_demand > 0:
            pca.channels[12].duty_cycle = 0xFFFF
            pca.channels[13].duty_cycle = 0x0000
        elif hbridge_left_demand < 0:
            pca.channels[12].duty_cycle = 0x0000
            pca.channels[13].duty_cycle = 0xFFFF
        else:
            pca.channels[12].duty_cycle = 0x0000
            pca.channels[13].duty_cycle = 0x0000
        logger.debug(f"Set H-Bridge Left to demand {hbridge_left_demand}")

        if hbridge_right_demand > 0:
            pca.channels[14].duty_cycle = 0xFFFF
            pca.channels[15].duty_cycle = 0x0000
        elif hbridge_right_demand < 0:
            pca.channels[14].duty_cycle = 0x0000
            pca.channels[15].duty_cycle = 0xFFFF
        else:
            pca.channels[14].duty_cycle = 0x0000
            pca.channels[15].duty_cycle = 0x0000
        logger.debug(f"Set H-Bridge Right to demand {hbridge_right_demand}")


def set_angle(ID, angle):
    servo_angle = servo.Servo(
        pca.channels[ID], min_pulse=500, max_pulse=2400, actuation_range=180
    )
    servo_angle.angle = angle


def initialise_hardware() -> None:
    """Put every actuator into its known home or off state after startup or re-arm."""
    global servo_channels

    logger.debug("Sending home positions to NATS and setting servos to home position")
    for name, data in servo_channels.items():
        publish_nats(data.topic, data.home_angle)
        set_angle(int(data.number), int(data.home_angle))
        if name == "Camera":
            publish_camera_pitch(data.home_angle, data.home_angle)
    logger.debug("Setting H-bridges to off")
    publish_nats("output/hbridge/left/demand", 0)
    publish_nats("output/hbridge/right/demand", 0)


def rearm() -> bool:
    """Re-arm Control after a latched NATS fault using fresh hardware initialisation."""
    if get_control_state() != ControlState.NATS_FAULT or not nats_fault.is_set():
        logger.warning("Re-arm rejected: Control is not in the latched NATS fault state.")
        return False

    if not nats_ready.is_set() or not nats_connected.is_set():
        logger.warning("Re-arm rejected: NATS is not available.")
        return False

    set_control_state(ControlState.INITIALISING)
    with nats_lock:
        nats_data.clear()

    try:
        initialise_hardware()
    except Exception:
        logger.exception("Re-arm failed during hardware initialisation; remaining in NATS fault state.")
        set_safe_outputs()
        set_control_state(ControlState.NATS_FAULT)
        return False

    if not nats_ready.is_set() or not nats_connected.is_set():
        logger.error("Re-arm failed: NATS connection was lost during hardware initialisation.")
        set_safe_outputs()
        set_control_state(ControlState.NATS_FAULT)
        return False

    nats_fault.clear()
    set_control_state(ControlState.ACTIVE)
    logger.info("Control re-arm completed successfully; fresh hardware initialisation is complete.")
    return True


def setup() -> None:
    set_control_state(ControlState.INITIALISING)
    threading.Thread(target=nats_thread, name="nats-client", daemon=True).start()
    if not nats_ready.wait(timeout=10):
        raise RuntimeError("NATS server did not become ready")

    initialise_hardware()
    set_control_state(ControlState.ACTIVE)
    logger.debug("Setup complete.")


if __name__ == "__main__":
    try:
        setup()
        while True:
            check_nats_safety()
            read_analog_channels()
            write_servo_outputs()
            write_hbridge_outputs()
            time.sleep(0.01)
    except KeyboardInterrupt:
        logger.info("Stopping Control")
        set_safe_outputs()
        pca.deinit()
        if nats_loop is not None and nats_client is not None:
            asyncio.run_coroutine_threadsafe(nats_client.drain(), nats_loop).result(timeout=2)
