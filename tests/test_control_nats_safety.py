"""Control NATS safety-state tests without requiring Raspberry Pi hardware."""
from __future__ import annotations

import asyncio
import importlib
import sys
import types
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[1]


def _load_control_module(monkeypatch: pytest.MonkeyPatch):
    """Load Control with hardware modules replaced by small test doubles."""
    modules: dict[str, types.ModuleType] = {}

    board = types.ModuleType("board")
    board.SCL = object()
    board.SDA = object()
    board.I2C = lambda: object()
    modules["board"] = board

    busio = types.ModuleType("busio")
    busio.I2C = lambda *_args: object()
    modules["busio"] = busio

    nats = types.ModuleType("nats")
    nats.connect = lambda *_args, **_kwargs: None
    modules["nats"] = nats

    ads = types.ModuleType("adafruit_ads7830")
    ads.analog_in = types.ModuleType("adafruit_ads7830.analog_in")
    ads.analog_in.AnalogIn = object
    ads.ads7830 = types.ModuleType("adafruit_ads7830.ads7830")
    ads.ads7830.ADS7830 = object
    modules["adafruit_ads7830"] = ads
    modules["adafruit_ads7830.analog_in"] = ads.analog_in
    modules["adafruit_ads7830.ads7830"] = ads.ads7830

    motor = types.ModuleType("adafruit_motor")
    motor.servo = types.ModuleType("adafruit_motor.servo")
    motor.servo.Servo = object
    modules["adafruit_motor"] = motor
    modules["adafruit_motor.servo"] = motor.servo

    pca_module = types.ModuleType("adafruit_pca9685")
    pca_module.PCA9685 = object
    modules["adafruit_pca9685"] = pca_module

    time_sync = types.ModuleType("rov_control.time_sync")

    class TimeSynchronisationConfig:  # noqa: N801 - mirrors production API
        pass

    time_sync.TimeSynchronisationConfig = TimeSynchronisationConfig
    time_sync.load_time_synchronisation_config = lambda _path: None
    time_sync.parse_time_synchronisation_message = lambda *_args: None
    modules["rov_control.time_sync"] = time_sync

    for name, module in modules.items():
        monkeypatch.setitem(sys.modules, name, module)

    control_src = str(ROOT / "control" / "src")
    if control_src not in sys.path:
        sys.path.insert(0, control_src)

    sys.modules.pop("rov_control.main", None)
    return importlib.import_module("rov_control.main")


def test_short_nats_dropout_recovers_to_active(monkeypatch: pytest.MonkeyPatch) -> None:
    control = _load_control_module(monkeypatch)
    control.set_control_state(control.ControlState.ACTIVE)
    control.nats_fault.clear()

    asyncio.run(control.on_nats_disconnected())
    assert control.get_control_state() == control.ControlState.NATS_DISCONNECTED

    asyncio.run(control.on_nats_reconnected())
    assert control.get_control_state() == control.ControlState.ACTIVE
    assert not control.nats_fault.is_set()


def test_nats_dropout_at_timeout_enters_latched_fault(monkeypatch: pytest.MonkeyPatch) -> None:
    control = _load_control_module(monkeypatch)
    control.set_control_state(control.ControlState.ACTIVE)
    control.nats_fault.clear()
    control.nats_connected.clear()
    control.nats_disconnected_at = control.time.monotonic() - (control.NATS_LOSS_TIMEOUT_MS / 1_000)

    home_positions: list[tuple[int, int]] = []
    monkeypatch.setattr(
        control,
        "set_angle",
        lambda channel, angle: home_positions.append((channel, angle)),
    )
    control.pca.channels = [types.SimpleNamespace(duty_cycle=None) for _ in range(16)]

    control.check_nats_safety()

    assert control.get_control_state() == control.ControlState.NATS_FAULT
    assert control.nats_fault.is_set()
    assert len(home_positions) == len(control.servo_channels)
    assert all(channel.duty_cycle == 0 for channel in control.pca.channels[12:16])


def test_nats_recovery_does_not_clear_latched_fault(monkeypatch: pytest.MonkeyPatch) -> None:
    control = _load_control_module(monkeypatch)
    control.nats_fault.set()
    control.set_control_state(control.ControlState.NATS_FAULT)
    control.nats_disconnected_at = control.time.monotonic() - 0.2

    asyncio.run(control.on_nats_reconnected())

    assert control.get_control_state() == control.ControlState.NATS_FAULT
    assert control.nats_fault.is_set()


def test_actuator_outputs_are_inhibited_while_nats_faulted(monkeypatch: pytest.MonkeyPatch) -> None:
    control = _load_control_module(monkeypatch)
    control.nats_fault.set()
    control.nats_connected.set()
    control.nats_data["output/servos/camera/demand"] = "120"
    control.nats_data["output/hbridge/left/demand"] = "1"
    control.pca.channels = [types.SimpleNamespace(duty_cycle=0) for _ in range(16)]

    servo_calls: list[tuple[int, int]] = []
    monkeypatch.setattr(control, "set_angle", lambda channel, angle: servo_calls.append((channel, angle)))

    control.write_servo_outputs()
    control.write_hbridge_outputs()

    assert servo_calls == []
    assert all(channel.duty_cycle == 0 for channel in control.pca.channels[12:16])


def test_rearm_is_rejected_when_nats_is_unavailable(monkeypatch: pytest.MonkeyPatch) -> None:
    control = _load_control_module(monkeypatch)
    control.nats_fault.set()
    control.set_control_state(control.ControlState.NATS_FAULT)
    control.nats_ready.clear()
    control.nats_connected.clear()

    initialise_calls = 0

    def fake_initialise() -> None:
        nonlocal initialise_calls
        initialise_calls += 1

    monkeypatch.setattr(control, "initialise_hardware", fake_initialise)

    assert control.rearm() is False
    assert initialise_calls == 0
    assert control.get_control_state() == control.ControlState.NATS_FAULT
    assert control.nats_fault.is_set()


def test_successful_rearm_freshly_initialises_hardware(monkeypatch: pytest.MonkeyPatch) -> None:
    control = _load_control_module(monkeypatch)
    control.nats_fault.set()
    control.set_control_state(control.ControlState.NATS_FAULT)
    control.nats_ready.set()
    control.nats_connected.set()
    control.nats_data["stale/topic"] = "old demand"

    initialise_calls = 0

    def fake_initialise() -> None:
        nonlocal initialise_calls
        initialise_calls += 1

    monkeypatch.setattr(control, "initialise_hardware", fake_initialise)

    assert control.rearm() is True
    assert initialise_calls == 1
    assert control.get_control_state() == control.ControlState.ACTIVE
    assert not control.nats_fault.is_set()
    assert control.nats_data == {}


def test_failed_rearm_remains_latched_and_safe(monkeypatch: pytest.MonkeyPatch) -> None:
    control = _load_control_module(monkeypatch)
    control.nats_fault.set()
    control.set_control_state(control.ControlState.NATS_FAULT)
    control.nats_ready.set()
    control.nats_connected.set()
    control.pca.channels = [types.SimpleNamespace(duty_cycle=None) for _ in range(16)]

    monkeypatch.setattr(control, "initialise_hardware", lambda: (_ for _ in ()).throw(RuntimeError("initialisation failed")))
    home_positions: list[tuple[int, int]] = []
    monkeypatch.setattr(
        control,
        "set_angle",
        lambda channel, angle: home_positions.append((channel, angle)),
    )

    assert control.rearm() is False
    assert control.get_control_state() == control.ControlState.NATS_FAULT
    assert control.nats_fault.is_set()
    assert len(home_positions) == len(control.servo_channels)
    assert all(channel.duty_cycle == 0 for channel in control.pca.channels[12:16])
