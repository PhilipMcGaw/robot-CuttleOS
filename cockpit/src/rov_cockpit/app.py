"""ROV Cockpit web application."""

import csv
import io
import json
import os
import re
import asyncio
import shutil
import threading
import urllib.request
from datetime import datetime, timezone
from urllib.parse import parse_qs
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Any

import nats
import uvicorn
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse, HTMLResponse, RedirectResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel, Field
from .auth import SESSION_COOKIE, create_session, hash_password, load_users, read_session, save_users, verify_password

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = BASE_DIR.parents[2]  # Go up to monorepo root
TEMPLATES_DIR = BASE_DIR / "templates"
STATIC_DIR = BASE_DIR / "static"
DEFAULT_CAMERA_CONFIG = PROJECT_ROOT / "configs" / "cameras.json"
CAMERA_CONFIG_PATH = Path(os.getenv("CAMERA_CONFIG", str(DEFAULT_CAMERA_CONFIG)))
DEPLOYED_ROBOT_PROFILE_PATH = Path("/etc/robot/profile.json")
ROBOT_PROFILE_PATH = Path(os.getenv("ROBOT_PROFILE_PATH", str(DEPLOYED_ROBOT_PROFILE_PATH)))
ROBOT_PROFILE_NAME = os.getenv("ROBOT_PROFILE", "rov")
NATS_URL = os.getenv("NATS_URL", "nats://127.0.0.1:4222")
NATS_SUBJECT = os.getenv("NATS_SUBJECT", ">")
MAP_TILE_PROXY = os.getenv("MAP_TILE_PROXY", "false").lower() == "true"
MEDIA_ROOT = Path(os.getenv("MEDIA_ROOT", str(PROJECT_ROOT / "media")))
CSV_ROOT = Path(os.getenv("CSV_ROOT", str(PROJECT_ROOT / "data" / "csv")))
STILLS_DIR = MEDIA_ROOT / "stills"
VIDEOS_DIR = MEDIA_ROOT / "videos"
MEDIA_MIN_FREE_GB = float(os.getenv("MEDIA_MIN_FREE_GB", "2"))
MEDIA_CONFIG_PATH = PROJECT_ROOT / "configs" / "media.json"
USERS_PATH = PROJECT_ROOT / "configs" / "users.json"
AUTH_SECRET = os.getenv("COCKPIT_AUTH_SECRET", "change-this-cockpit-secret")
ENABLE_SIMULATOR = os.getenv("COCKPIT_ENABLE_SIMULATOR", "false").lower() == "true"
simulation_enabled = ENABLE_SIMULATOR

templates = Jinja2Templates(directory=str(TEMPLATES_DIR))
nats_data: dict[str, str] = {}
nats_lock = threading.Lock()
telemetry_clients: set[WebSocket] = set()
telemetry_loop: asyncio.AbstractEventLoop | None = None


class CameraConfig(BaseModel):
    """Configuration for one Motion camera instance."""

    id: str = Field(pattern=r"^[a-zA-Z0-9_-]+$")
    name: str = Field(min_length=1, max_length=80)
    device: str = Field(min_length=1, max_length=120)
    enabled: bool = True
    width: int = Field(default=640, ge=160, le=3840)
    height: int = Field(default=480, ge=120, le=2160)
    framerate: int = Field(default=30, ge=1, le=120)
    stream_port: int = Field(default=8001, ge=1024, le=65535)


class MediaConfig(BaseModel):
    """Recording settings shared by Motion and the Cockpit."""

    recording_minutes: int = Field(default=30, ge=1, le=240)

class SimulationTelemetry(BaseModel):
    values: dict[str, float]


class TimeSynchronisationConfig(BaseModel):
    """Browser-to-Control clock synchronisation settings in a robot profile."""

    enabled: bool = True
    command_subject: str = Field(pattern=r"^[a-z0-9]+(?:\.[a-z0-9-]+)+$")
    status_subject: str = Field(pattern=r"^[a-z0-9]+(?:\.[a-z0-9-]+)+$")
    interval_seconds: int = Field(default=60, ge=30, le=3_600)
    minimum_adjustment_seconds: float = Field(default=0.5, ge=0, le=60)


class ActiveRobotTimeProfile(BaseModel):
    """The minimum active-profile fields required by the Cockpit time relay."""

    profile_id: str = Field(min_length=1)
    namespace: str = Field(pattern=r"^[a-z0-9-]+$")
    time_synchronisation: TimeSynchronisationConfig | None = None


class RobotCommand(BaseModel):
    """A profile-defined logical Cockpit command."""

    subject: str = Field(pattern=r"^[a-z0-9]+(?:\.[a-z0-9-]+)+$")
    unit: str = ""


class RobotTelemetry(BaseModel):
    """A profile-defined logical telemetry value."""

    subject: str = Field(pattern=r"^[a-z0-9]+(?:\.[a-z0-9-]+)+$")
    unit: str = ""


class HardwareTopicBinding(BaseModel):
    """Logical profile keys consumed or published by one hardware function."""

    commands: list[str] = Field(default_factory=list)
    telemetry: list[str] = Field(default_factory=list)


class HardwareActuatorBinding(BaseModel):
    """One semantic actuator assigned to a stable Control-owned physical port."""

    port_alias: str = Field(pattern=r"^servo-[0-9]{2}$")
    pca9685_channel: int = Field(ge=0, le=15)
    command: str = Field(pattern=r"^[a-z0-9][a-z0-9.-]*$")


class HardwareAdapter(BaseModel):
    """One Control-owned hardware adapter declared by the shared profile."""

    id: str = Field(pattern=r"^[a-z0-9][a-z0-9-]*$")
    driver: str = Field(pattern=r"^[a-z0-9][a-z0-9-]*$")
    model: str = Field(min_length=1, max_length=80)
    validation_status: str = Field(
        pattern=r"^(planned-unverified|bench-tested|production-validated)$"
    )
    bindings: dict[str, HardwareTopicBinding] = Field(default_factory=dict)
    actuators: dict[str, HardwareActuatorBinding] = Field(default_factory=dict)


class HardwareConfiguration(BaseModel):
    """Control-owned hardware adapters and their logical topic bindings."""

    adapters: list[HardwareAdapter] = Field(default_factory=list)


class SoundboardSound(BaseModel):
    """A selectable sound that is resolved by Control on the robot."""

    id: str = Field(pattern=r"^[a-z0-9][a-z0-9_-]*$")
    label: str = Field(min_length=1, max_length=80)
    file: str = Field(min_length=1, max_length=255)


class SoundboardConfig(BaseModel):
    """Profile-defined K9 soundboard contents."""

    directory: str = Field(min_length=1, max_length=255)
    sounds: list[SoundboardSound] = Field(min_length=1, max_length=64)


class ActiveRobotProfile(ActiveRobotTimeProfile):
    """The active profile fields consumed by Cockpit's shared shell."""

    display_name: str = Field(min_length=1, max_length=80)
    identity_icon: str = Field(default="fa-robot", pattern=r"^fa-[a-z0-9-]+$")
    capabilities: dict[str, bool] = Field(default_factory=dict)
    commands: dict[str, RobotCommand] = Field(default_factory=dict)
    telemetry: dict[str, RobotTelemetry] = Field(default_factory=dict)
    hardware: HardwareConfiguration = Field(default_factory=HardwareConfiguration)
    soundboard: SoundboardConfig | None = None


class BrowserTimeSynchronisation(BaseModel):
    """UTC supplied by the authenticated browser in Unix milliseconds."""

    unix_time_ms: int = Field(ge=1_704_067_200_000, le=4_102_444_800_000)


class SoundboardPlaybackRequest(BaseModel):
    """A user-selected profile sound identifier."""

    sound_id: str = Field(pattern=r"^[a-z0-9][a-z0-9_-]*$")


def active_robot_profile_path() -> Path:
    """Prefer the deployed profile, with a local source-profile fallback for development."""
    if "ROBOT_PROFILE_PATH" in os.environ or ROBOT_PROFILE_PATH.is_file():
        return ROBOT_PROFILE_PATH
    return PROJECT_ROOT / "configs" / "profiles" / f"{ROBOT_PROFILE_NAME}.json"


def load_active_robot_profile() -> ActiveRobotProfile:
    """Load the active profile-derived Cockpit configuration once at startup."""
    path = active_robot_profile_path()
    try:
        profile = ActiveRobotProfile.model_validate_json(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise RuntimeError(f"Active robot profile was not found: {path}") from exc
    except (json.JSONDecodeError, ValueError) as exc:
        raise RuntimeError(f"Active robot profile is invalid: {path}: {exc}") from exc

    config = profile.time_synchronisation
    if config is not None:
        expected_command = f"{profile.namespace}.cockpit.command.system.time-sync"
        expected_status = f"{profile.namespace}.control.status.system.time-sync"
        if config.command_subject != expected_command or config.status_subject != expected_status:
            raise RuntimeError(
                "Active robot profile time-synchronisation subjects do not match its namespace"
            )
    soundboard_enabled = profile.capabilities.get("soundboard", False)
    if soundboard_enabled:
        if profile.soundboard is None:
            raise RuntimeError("Active robot profile enables soundboard without soundboard configuration")
        sound_command = profile.commands.get("sound.play")
        expected_sound_subject = f"{profile.namespace}.command.sound.play"
        if sound_command is None or sound_command.subject != expected_sound_subject:
            raise RuntimeError("Active robot profile sound command does not match its namespace")
        if len({sound.id for sound in profile.soundboard.sounds}) != len(profile.soundboard.sounds):
            raise RuntimeError("Active robot profile soundboard contains duplicate sound identifiers")
    elif profile.soundboard is not None:
        raise RuntimeError("Active robot profile defines soundboard configuration without enabling it")

    adapter_ids = [adapter.id for adapter in profile.hardware.adapters]
    if len(adapter_ids) != len(set(adapter_ids)):
        raise RuntimeError("Active robot profile defines duplicate hardware adapter identifiers")
    for adapter in profile.hardware.adapters:
        for function, binding in adapter.bindings.items():
            unknown_commands = sorted(set(binding.commands) - set(profile.commands))
            unknown_telemetry = sorted(set(binding.telemetry) - set(profile.telemetry))
            if unknown_commands or unknown_telemetry:
                details = []
                if unknown_commands:
                    details.append(f"unknown commands: {', '.join(unknown_commands)}")
                if unknown_telemetry:
                    details.append(f"unknown telemetry: {', '.join(unknown_telemetry)}")
                raise RuntimeError(
                    f"Hardware adapter {adapter.id!r} binding {function!r} references "
                    + "; ".join(details)
                )
        allocated_channels: set[int] = set()
        servo_binding = adapter.bindings.get("pca9685-servos")
        for actuator_name, actuator in adapter.actuators.items():
            expected_port_alias = f"servo-{actuator.pca9685_channel:02d}"
            if actuator.port_alias != expected_port_alias:
                raise RuntimeError(
                    f"Hardware adapter {adapter.id!r} actuator {actuator_name!r} maps "
                    f"{actuator.port_alias!r} to PCA9685 channel {actuator.pca9685_channel}; "
                    f"expected {expected_port_alias!r}"
                )
            if actuator.command not in profile.commands:
                raise RuntimeError(
                    f"Hardware adapter {adapter.id!r} actuator {actuator_name!r} references "
                    f"unknown command {actuator.command!r}"
                )
            if servo_binding is None or actuator.command not in servo_binding.commands:
                raise RuntimeError(
                    f"Hardware adapter {adapter.id!r} actuator {actuator_name!r} command "
                    f"{actuator.command!r} is not bound to pca9685-servos"
                )
            if actuator.pca9685_channel in allocated_channels:
                raise RuntimeError(
                    f"Hardware adapter {adapter.id!r} assigns PCA9685 channel "
                    f"{actuator.pca9685_channel} more than once"
                )
            allocated_channels.add(actuator.pca9685_channel)
    return profile


ACTIVE_ROBOT_PROFILE = load_active_robot_profile()
# Retained as a named alias while time synchronisation is migrated to the full
# active profile object.
ACTIVE_ROBOT_TIME_PROFILE = ACTIVE_ROBOT_PROFILE


def render_template(
    request: Request,
    name: str,
    context: dict[str, Any] | None = None,
    *,
    status_code: int = 200,
):
    """Render a Cockpit page with the non-optional active profile context.

    Shared templates use the profile for the document title and vehicle
    identity. Supplying it per response makes every page deterministic and
    avoids depending on a mutable Jinja environment global.
    """
    page_context = dict(context or {})
    page_context["active_robot_profile"] = ACTIVE_ROBOT_PROFILE
    return templates.TemplateResponse(
        request=request,
        name=name,
        context=page_context,
        status_code=status_code,
    )


def load_media_config() -> MediaConfig:
    try:
        return MediaConfig.model_validate(json.loads(MEDIA_CONFIG_PATH.read_text(encoding="utf-8")))
    except (FileNotFoundError, json.JSONDecodeError):
        return MediaConfig()


def save_media_config(config: MediaConfig) -> None:
    MEDIA_CONFIG_PATH.write_text(json.dumps(config.model_dump(), indent=2) + "\n", encoding="utf-8")
    motion_config = PROJECT_ROOT / "configs" / "motion.conf"
    if motion_config.is_file():
        content = motion_config.read_text(encoding="utf-8")
        content = re.sub(r"^movie_max_time\s+\d+\s*$", f"movie_max_time {config.recording_minutes * 60}", content, flags=re.MULTILINE)
        motion_config.write_text(content, encoding="utf-8")


def media_files(directory: Path, suffixes: tuple[str, ...]) -> list[Path]:
    """Return media files in newest-first order, without leaving MEDIA_ROOT."""
    directory.mkdir(parents=True, exist_ok=True)
    return sorted(
        (path for path in directory.iterdir() if path.is_file() and path.suffix.lower() in suffixes),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )


def csv_files() -> list[Path]:
    CSV_ROOT.mkdir(parents=True, exist_ok=True)
    return sorted((path for path in CSV_ROOT.rglob("*.csv") if path.is_file()), key=lambda path: path.stat().st_mtime, reverse=True)


def csv_path(filename: str) -> Path:
    root = CSV_ROOT.resolve()
    candidate = (CSV_ROOT / filename).resolve()
    if root != candidate and root not in candidate.parents:
        raise HTTPException(status_code=400, detail="CSV path is outside the configured data directory")
    if candidate.suffix.lower() != ".csv" or not candidate.is_file():
        raise HTTPException(status_code=404, detail="CSV export was not found")
    return candidate


def csv_fields(path: Path) -> list[str]:
    with path.open("r", newline="", encoding="utf-8-sig") as handle:
        return csv.DictReader(handle).fieldnames or []


def prune_videos() -> None:
    """Remove oldest recordings until the configured free-space floor is met."""
    VIDEOS_DIR.mkdir(parents=True, exist_ok=True)
    usage = shutil.disk_usage(MEDIA_ROOT)
    minimum_free = int(MEDIA_MIN_FREE_GB * 1024**3)
    for video in reversed(media_files(VIDEOS_DIR, (".mp4", ".avi", ".mkv", ".webm"))):
        if usage.free >= minimum_free:
            break
        try:
            video.unlink()
        except OSError:
            continue
        usage = shutil.disk_usage(MEDIA_ROOT)


def capture_still(camera_id: str) -> Path:
    """Save the current JPEG frame from a Motion camera stream."""
    camera = next((item for item in load_camera_config()["cameras"] if item["id"] == camera_id), None)
    if camera is None:
        raise HTTPException(status_code=404, detail="Unknown camera")
    url = f"http://127.0.0.1:{camera['stream_port']}/0/current"
    STILLS_DIR.mkdir(parents=True, exist_ok=True)
    filename = f"{camera_id}_{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ')}.jpg"
    destination = STILLS_DIR / filename
    try:
        with urllib.request.urlopen(url, timeout=5) as response:
            destination.write_bytes(response.read())
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Camera {camera_id} is unavailable") from exc
    prune_videos()
    return destination


async def media_maintenance() -> None:
    """Keep recording retention active while the Cockpit is running."""
    while True:
        prune_videos()
        await asyncio.sleep(60)


def dashboard_topic(subject: str) -> str:
    """Present NATS subjects using the existing dashboard topic notation."""
    return subject.replace(".", "/")


async def on_message(message: Any) -> None:
    """Store the latest value for each NATS subject."""
    topic = dashboard_topic(message.subject)
    payload = message.data.decode(errors="replace")
    with nats_lock:
        nats_data[topic] = payload


async def nats_error_callback(exc: Exception) -> None:
    """Suppress library retry tracebacks; startup reports read-only mode once."""
    return None


async def connect_nats_in_background(app: FastAPI) -> None:
    """Attempt NATS connection without delaying read-only Cockpit startup."""
    try:
        client = await asyncio.wait_for(
            nats.connect(
                NATS_URL,
                connect_timeout=3,
                max_reconnect_attempts=0,
                error_cb=nats_error_callback,
            ),
            timeout=4,
        )
        await client.subscribe(NATS_SUBJECT, cb=on_message)
        app.state.nats_client = client
        print(f"[PASS] NATS client connected: {NATS_URL} subject={NATS_SUBJECT}")
    except asyncio.CancelledError:
        raise
    except Exception as exc:
        app.state.nats_client = None
        print(f"[WARN] NATS Server is unavailable at {NATS_URL}: {exc}")
        print("[INFO] Cockpit is running in read-only mode; live telemetry and control are unavailable.")

    if telemetry_loop is not None and telemetry_loop.is_running():
        asyncio.run_coroutine_threadsafe(
            broadcast_telemetry(topic, payload), telemetry_loop
        )


async def broadcast_telemetry(topic: str, payload: str) -> None:
    """Forward one NATS update to connected cockpit browsers."""
    disconnected = set()
    for websocket in tuple(telemetry_clients):
        try:
            await websocket.send_json({"topic": topic, "value": payload})
        except Exception:
            disconnected.add(websocket)
    telemetry_clients.difference_update(disconnected)


def load_camera_config() -> dict[str, list[dict[str, Any]]]:
    """Load the camera registry, returning an empty registry if absent."""
    try:
        return json.loads(CAMERA_CONFIG_PATH.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return {"cameras": []}
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"Invalid camera configuration: {exc}") from exc


def save_camera_config(config: dict[str, list[dict[str, Any]]]) -> None:
    """Atomically replace the camera registry."""
    CAMERA_CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
    temporary_path = CAMERA_CONFIG_PATH.with_suffix(".tmp")
    temporary_path.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
    temporary_path.replace(CAMERA_CONFIG_PATH)


def topic_value(topic: str) -> str:
    """Return a cached NATS value or the dashboard's missing-value marker."""
    return nats_data.get(topic, "N/A")


def dashboard_snapshot() -> list[dict[str, Any]]:
    """Build the stable, dashboard-oriented NATS response."""
    with nats_lock:
        return [
            {
                "id": "System",
                "Uptime": topic_value("system/uptime"),
                "Date": topic_value("system/date"),
                "Time": topic_value("system/time"),
            },
            {
                "id": "Battery",
                "SOC": topic_value("power/battery/1/soc"),
                "Voltage": topic_value("power/battery/1/voltage"),
                "Current": topic_value("power/battery/1/current"),
                "Temperature": topic_value("power/battery/1/temperature"),
            },
            {
                "id": "Water",
                "Temperature": topic_value("sensor/water/temperature"),
                "Salinity": topic_value("sensor/water/salinity"),
            },
            {
                "id": "Direction",
                "Heading": topic_value("sensor/ahrs/imu/heading"),
                "Pitch": topic_value("sensor/ahrs/imu/pitch"),
                "Roll": topic_value("sensor/ahrs/imu/roll"),
            },
            {
                "id": "Location",
                "Latitude": topic_value("sensor/ahrs/gps/location/lat"),
                "Longitude": topic_value("sensor/ahrs/gps/location/lng"),
                "Altitude": topic_value("sensor/ahrs/gps/location/altitude"),
            },
            {
                "id": "Lights",
                "Left": topic_value("output/lights/left"),
                "Right": topic_value("output/lights/right"),
                "Aux1": topic_value("output/lights/aux1"),
                "Aux2": topic_value("output/lights/aux2"),
                "Laser": topic_value("output/lights/laser"),
                "Test": topic_value("output/lights/test"),
            },
            {
                "id": "Motors",
                **{
                    f"Motor{motor}speed": topic_value(f"output/motors/motor{motor}/speed")
                    for motor in range(1, 13)
                },
            },
        ]


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Start and stop the NATS client with the ASGI application."""
    global telemetry_loop
    telemetry_loop = asyncio.get_running_loop()
    maintenance_task = asyncio.create_task(media_maintenance())
    app.state.nats_client = None
    nats_task = asyncio.create_task(connect_nats_in_background(app))

    yield

    nats_task.cancel()
    await asyncio.gather(nats_task, return_exceptions=True)
    if app.state.nats_client is not None:
        await app.state.nats_client.drain()
        print("NATS client stopped")
    telemetry_loop = None
    maintenance_task.cancel()


app = FastAPI(title="ROV Cockpit", lifespan=lifespan)
app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")


@app.get("/favicon.ico", include_in_schema=False)
async def favicon():
    """Serve the conventional root favicon URL used by browsers."""
    return FileResponse(STATIC_DIR / "favicon.ico")


@app.get("/", response_class=HTMLResponse)
async def home(request: Request):
    soundboard = ACTIVE_ROBOT_PROFILE.soundboard if ACTIVE_ROBOT_PROFILE.capabilities.get("soundboard", False) else None
    return render_template(
        request,
        "home.jinja",
        {"config": {"simulator_enabled": ENABLE_SIMULATOR}, "soundboard": soundboard},
    )


@app.get("/login", response_class=HTMLResponse)
async def login_page(request: Request):
    error = None if USERS_PATH.is_file() else "No user accounts are configured yet. Create configs/users.json from configs/users.example.json."
    return render_template(request, "login.jinja", {"error": error})


@app.post("/login", response_class=HTMLResponse)
async def login(request: Request):
    form = parse_qs((await request.body()).decode("utf-8"))
    username = form.get("username", [""])[0]
    password = form.get("password", [""])[0]
    user = load_users(USERS_PATH).get(username)
    if not user or not verify_password(password, user.get("password_hash", "")):
        return render_template(request, "login.jinja", {"error": "Invalid username or password"}, status_code=401)
    response = RedirectResponse(url="/", status_code=303)
    response.set_cookie(SESSION_COOKIE, create_session(username, user["role"], AUTH_SECRET), httponly=True, samesite="lax")
    return response


@app.post("/logout")
async def logout():
    response = RedirectResponse(url="/", status_code=303)
    response.delete_cookie(SESSION_COOKIE)
    return response


@app.get("/logout")
async def logout_link():
    return await logout()


def authenticated_user(request: Request) -> dict[str, str] | None:
    return read_session(request.cookies.get(SESSION_COOKIE), AUTH_SECRET)


@app.get("/api/session")
async def session_info(request: Request):
    user = authenticated_user(request)
    return {"authenticated": user is not None, "username": user["user"] if user else None, "role": user["role"] if user else None}


@app.post("/api/system/time-sync")
async def relay_browser_time(payload: BrowserTimeSynchronisation, request: Request):
    """Relay a signed-in browser's UTC time to the active Control profile over NATS."""
    user = authenticated_user(request)
    if user is None or user["role"] not in {"driver", "admin"}:
        raise HTTPException(status_code=403, detail="Driver or administrator authentication is required")

    config = ACTIVE_ROBOT_TIME_PROFILE.time_synchronisation
    if config is None or not config.enabled:
        raise HTTPException(status_code=404, detail="Browser time synchronisation is not configured for this robot")
    client = getattr(request.app.state, "nats_client", None)
    if client is None:
        raise HTTPException(status_code=503, detail="NATS Core is unavailable")

    utc_timestamp = datetime.fromtimestamp(payload.unix_time_ms / 1_000, timezone.utc)
    message = {
        "value": payload.unix_time_ms,
        "units": "ms",
        "timestamp": utc_timestamp.isoformat().replace("+00:00", "Z"),
        "profile": ACTIVE_ROBOT_TIME_PROFILE.profile_id,
        "source": "cockpit-browser",
    }
    try:
        await client.publish(config.command_subject, json.dumps(message, separators=(",", ":")).encode())
        await client.flush(timeout=1)
    except Exception as exc:
        raise HTTPException(status_code=503, detail="Could not publish time synchronisation") from exc
    return {"accepted": True, "interval_seconds": config.interval_seconds}


@app.post("/api/soundboard/play")
async def relay_soundboard_playback(payload: SoundboardPlaybackRequest, request: Request):
    """Relay an authorised K9 sound selection to the profile-owned Control command."""
    user = authenticated_user(request)
    if user is None or user["role"] not in {"driver", "admin"}:
        raise HTTPException(status_code=403, detail="Driver or administrator authentication is required")

    soundboard = ACTIVE_ROBOT_PROFILE.soundboard
    sound_command = ACTIVE_ROBOT_PROFILE.commands.get("sound.play")
    if not ACTIVE_ROBOT_PROFILE.capabilities.get("soundboard", False) or soundboard is None or sound_command is None:
        raise HTTPException(status_code=404, detail="Soundboard is not configured for this robot")
    sound = next((item for item in soundboard.sounds if item.id == payload.sound_id), None)
    if sound is None:
        raise HTTPException(status_code=404, detail="Unknown sound")
    client = getattr(request.app.state, "nats_client", None)
    if client is None:
        raise HTTPException(status_code=503, detail="NATS Core is unavailable")

    message = {
        "value": sound.id,
        "units": sound_command.unit,
        "profile": ACTIVE_ROBOT_PROFILE.profile_id,
        "source": "cockpit-sound-drawer",
    }
    try:
        await client.publish(sound_command.subject, json.dumps(message, separators=(",", ":")).encode())
        await client.flush(timeout=1)
    except Exception as exc:
        raise HTTPException(status_code=503, detail="Could not publish soundboard command") from exc
    return {"accepted": True, "sound_id": sound.id, "label": sound.label}


@app.get("/account/", response_class=HTMLResponse)
async def account_page(request: Request):
    user = authenticated_user(request)
    if user is None:
        return RedirectResponse(url="/login", status_code=303)
    users = load_users(USERS_PATH)
    managed_users = sorted(users) if user["role"] == "admin" else [user["user"]]
    return render_template(
        request,
        "account.jinja",
        {"user": user, "managed_users": managed_users, "message": None, "error": None},
    )


@app.post("/account/password")
async def change_password(request: Request):
    form = parse_qs((await request.body()).decode("utf-8"))
    username = form.get("username", [""])[0]
    password = form.get("password", [""])[0]
    user = authenticated_user(request)
    if user is None:
        return RedirectResponse(url="/login", status_code=303)
    if user["role"] != "admin" and username != user["user"]:
        raise HTTPException(status_code=403, detail="Drivers may only change their own password")
    if len(password) < 12:
        raise HTTPException(status_code=400, detail="Password must be at least 12 characters")
    users = load_users(USERS_PATH)
    if username not in users:
        raise HTTPException(status_code=404, detail="User not found")
    users[username]["password_hash"] = hash_password(password)
    save_users(USERS_PATH, users)
    return RedirectResponse(url="/account/", status_code=303)


@app.get("/api/network-ping")
async def network_ping() -> dict[str, int]:
    """Small uncached response used by the cockpit's browser rate estimate."""
    return {"ok": 1}


@app.get("/api/system/status")
async def system_status(request: Request) -> dict[str, bool]:
    """Expose read-only operating state for the shared operator status surface."""
    client = getattr(request.app.state, "nats_client", None)
    return {
        "nats_connected": bool(client is not None and getattr(client, "is_connected", False)),
        "simulation_enabled": simulation_enabled,
    }


@app.websocket("/ws/telemetry")
async def telemetry_socket(websocket: WebSocket):
    """Provide NATS telemetry to browsers without exposing NATS directly."""
    await websocket.accept()
    telemetry_clients.add(websocket)
    try:
        with nats_lock:
            snapshot = dict(nats_data)
        for topic, value in snapshot.items():
            await websocket.send_json({"topic": topic, "value": value})
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        telemetry_clients.discard(websocket)


@app.get("/files/", response_class=HTMLResponse)
async def files(request: Request):
    prune_videos()
    return render_template(
        request,
        "files.jinja",
        {
            "cameras": load_camera_config()["cameras"],
            "media_config": load_media_config(),
            "stills": media_files(STILLS_DIR, (".jpg", ".jpeg", ".png")),
            "videos": media_files(VIDEOS_DIR, (".mp4", ".avi", ".mkv", ".webm")),
        },
    )


@app.get("/data/", response_class=HTMLResponse)
async def data_page(request: Request):
    return render_template(
        request,
        "data.jinja",
        {"files": [{"name": path.name, "relative": path.relative_to(CSV_ROOT).as_posix()} for path in csv_files()]},
    )


@app.get("/api/data/fields")
async def data_fields(file: str):
    return {"fields": csv_fields(csv_path(file))}


@app.get("/api/data/preview")
async def data_preview(file: str, sensors: str = "", limit: int = 250):
    path = csv_path(file)
    selected = [item for item in sensors.split(",") if item]
    with path.open("r", newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle)
        fields = [field for field in (reader.fieldnames or []) if not selected or field in selected]
        rows = [[row.get(field, "") for field in fields] for row in reader][:max(1, min(limit, 250))]
    return {"file": path.name, "fields": fields, "rows": rows}


@app.get("/api/data/download")
async def data_download(file: str, sensors: str = ""):
    path = csv_path(file)
    selected = [item for item in sensors.split(",") if item]
    output = io.StringIO(newline="")
    with path.open("r", newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle)
        fields = [field for field in (reader.fieldnames or []) if not selected or field in selected]
        writer = csv.writer(output)
        writer.writerow(fields)
        for row in reader:
            writer.writerow([row.get(field, "") for field in fields])
    return StreamingResponse(iter([output.getvalue()]), media_type="text/csv", headers={"Content-Disposition": f'attachment; filename="{path.stem}-selected.csv"'})


@app.get("/api/media/config")
async def get_media_config():
    return load_media_config()


@app.put("/api/media/config")
async def update_media_config(config: MediaConfig):
    save_media_config(config)
    return {"config": config, "restart_required": True}


@app.post("/api/cameras/{camera_id}/still")
async def save_still(camera_id: str):
    still = capture_still(camera_id)
    return {"filename": still.name, "url": f"/media/stills/{still.name}"}


@app.get("/media/{media_type}/{filename}")
async def download_media(media_type: str, filename: str):
    directories = {"stills": STILLS_DIR, "videos": VIDEOS_DIR}
    directory = directories.get(media_type)
    if directory is None or Path(filename).name != filename:
        raise HTTPException(status_code=404, detail="Media not found")
    path = directory / filename
    if not path.is_file():
        raise HTTPException(status_code=404, detail="Media not found")
    return FileResponse(path, filename=path.name)


@app.get("/map/", response_class=HTMLResponse)
async def map_page(request: Request):
    tile_prefix = "/map-tiles" if MAP_TILE_PROXY else None
    return render_template(request, "map.jinja", {"map_tile_prefix": tile_prefix})


@app.get("/3d/", response_class=HTMLResponse)
async def threed(request: Request):
    return render_template(request, "3d.jinja")


@app.get("/cameras/", response_class=HTMLResponse)
async def cameras_page(request: Request):
    return render_template(request, "cameras.jinja", {"cameras": load_camera_config()["cameras"]})


@app.get("/gamepad/", response_class=HTMLResponse)
async def gamepad_page(request: Request):
    return render_template(request, "gamepad.jinja")

@app.get("/simulator/", response_class=HTMLResponse)
async def simulator_page(request: Request):
    return render_template(request, "simulator.jinja")

@app.get("/api/development/simulation/state")
async def simulation_state():
    return {"enabled": simulation_enabled}

@app.post("/api/development/simulation/state")
async def set_simulation_state(payload: dict[str, bool]):
    global simulation_enabled
    simulation_enabled = bool(payload.get("enabled", False))
    return {"enabled": simulation_enabled}

@app.post("/api/development/simulation")
async def simulation_telemetry(payload: SimulationTelemetry):
    if not simulation_enabled:
        raise HTTPException(status_code=409, detail="Enable simulation mode before sending simulated telemetry")
    for topic, value in payload.values.items():
        with nats_lock:
            nats_data[topic] = str(value)
        # This endpoint already runs on the telemetry event loop. Await the
        # broadcast directly so every simulated topic reaches every browser
        # client before the request completes.
        await broadcast_telemetry(topic, str(value))
    return {"ok": True, "topics": len(payload.values)}


@app.get("/api/cameras")
async def get_cameras():
    return load_camera_config()


@app.put("/api/cameras/{camera_id}")
async def update_camera(camera_id: str, camera: CameraConfig):
    if camera.id != camera_id:
        raise HTTPException(status_code=400, detail="Camera ID in URL and body must match")

    config = load_camera_config()
    cameras = [item for item in config["cameras"] if item["id"] != camera_id]
    cameras.append(camera.model_dump())
    config["cameras"] = sorted(cameras, key=lambda item: item["id"])
    save_camera_config(config)
    return camera


@app.get("/json/")
async def get_nats():
    return dashboard_snapshot()


if __name__ == "__main__":
    uvicorn.run(
        "app:app",
        host=os.getenv("APP_HOST", "0.0.0.0"),
        port=int(os.getenv("APP_PORT", "8080")),
        reload=os.getenv("APP_RELOAD", "false").lower() == "true",
    )
