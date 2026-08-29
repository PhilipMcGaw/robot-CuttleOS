"""Profile-driven validation for browser-assisted Raspberry Pi clock synchronisation."""

from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
import time
from typing import Any


# Accept a broad, deliberate window. A Pi without an RTC may boot near 1970,
# so the offset itself cannot be used to reject a legitimate first correction.
MINIMUM_UTC_UNIX_MS = 1_704_067_200_000  # 2024-01-01T00:00:00Z
MAXIMUM_UTC_UNIX_MS = 4_102_444_800_000  # 2100-01-01T00:00:00Z


@dataclass(frozen=True)
class TimeSynchronisationConfig:
    """Validated time-synchronisation fields from the active robot profile."""

    profile_id: str
    namespace: str
    command_subject: str
    status_subject: str
    minimum_adjustment_seconds: float


@dataclass(frozen=True)
class TimeSynchronisationRequest:
    """A valid browser time value and its current offset from the Pi clock."""

    utc_unix_ms: int
    offset_seconds: float


def load_time_synchronisation_config(profile_path: Path) -> TimeSynchronisationConfig | None:
    """Load the optional time-synchronisation configuration from one active profile."""
    try:
        profile = json.loads(profile_path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return None
    except json.JSONDecodeError as exc:
        raise ValueError(f"Profile JSON is invalid: {exc}") from exc

    if not isinstance(profile, dict):
        raise ValueError("Profile root must be a JSON object")
    profile_id = profile.get("profile_id")
    namespace = profile.get("namespace")
    if not isinstance(profile_id, str) or not profile_id:
        raise ValueError("Profile must contain a non-empty profile_id")
    if not isinstance(namespace, str) or not namespace:
        raise ValueError("Profile must contain a non-empty namespace")

    raw_config = profile.get("time_synchronisation")
    if raw_config is None:
        return None
    if not isinstance(raw_config, dict):
        raise ValueError("time_synchronisation must be a JSON object")
    if raw_config.get("enabled") is False:
        return None

    command_subject = raw_config.get("command_subject")
    status_subject = raw_config.get("status_subject")
    expected_command = f"{namespace}.cockpit.command.system.time-sync"
    expected_status = f"{namespace}.control.status.system.time-sync"
    if command_subject != expected_command:
        raise ValueError(f"command_subject must be {expected_command!r}")
    if status_subject != expected_status:
        raise ValueError(f"status_subject must be {expected_status!r}")

    minimum_adjustment = raw_config.get("minimum_adjustment_seconds", 0.5)
    if isinstance(minimum_adjustment, bool):
        raise ValueError("minimum_adjustment_seconds must be numeric")
    try:
        minimum_adjustment = float(minimum_adjustment)
    except (TypeError, ValueError) as exc:
        raise ValueError("minimum_adjustment_seconds must be numeric") from exc
    if minimum_adjustment < 0:
        raise ValueError("minimum_adjustment_seconds must be zero or positive")

    return TimeSynchronisationConfig(
        profile_id=profile_id,
        namespace=namespace,
        command_subject=command_subject,
        status_subject=status_subject,
        minimum_adjustment_seconds=minimum_adjustment,
    )


def parse_time_synchronisation_message(
    payload: bytes,
    config: TimeSynchronisationConfig,
    *,
    current_time_seconds: float | None = None,
) -> TimeSynchronisationRequest:
    """Validate a Cockpit time message without altering the system clock."""
    try:
        body: Any = json.loads(payload.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValueError("Time-synchronisation payload must be UTF-8 JSON") from exc
    if not isinstance(body, dict):
        raise ValueError("Time-synchronisation payload must be a JSON object")
    if body.get("profile") != config.profile_id:
        raise ValueError("Time-synchronisation payload profile does not match the active profile")
    if body.get("units") != "ms":
        raise ValueError("Time-synchronisation payload units must be 'ms'")

    value = body.get("value")
    if isinstance(value, bool) or not isinstance(value, (int, float)) or int(value) != value:
        raise ValueError("Time-synchronisation payload value must be an integer UTC Unix time in ms")
    utc_unix_ms = int(value)
    if not MINIMUM_UTC_UNIX_MS <= utc_unix_ms <= MAXIMUM_UTC_UNIX_MS:
        raise ValueError("Time-synchronisation payload time is outside the accepted UTC range")

    now = time.time() if current_time_seconds is None else current_time_seconds
    return TimeSynchronisationRequest(
        utc_unix_ms=utc_unix_ms,
        offset_seconds=(utc_unix_ms / 1_000) - now,
    )
