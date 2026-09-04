"""Checks for the conservative Testbot robot profile."""

from pathlib import Path
import sys
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from rov_cockpit.app import ActiveRobotProfile, load_active_robot_profile


def test_testbot_profile_is_conservative_and_namespaced() -> None:
    path = ROOT / "configs" / "profiles" / "testbot.json"
    with patch("rov_cockpit.app.active_robot_profile_path", return_value=path):
        profile: ActiveRobotProfile = load_active_robot_profile()

    assert profile.profile_id == "testbot"
    assert profile.namespace == "testbot"

    assert profile.capabilities["drive_control"] is True
    assert profile.capabilities["test_mode"] is True
    assert profile.capabilities["soundboard"] is False
    assert len(profile.hardware.adapters) == 1
    adapter = profile.hardware.adapters[0]
    assert adapter.driver == "adeept-robot-hat-adm133"
    assert adapter.validation_status == "planned-unverified"
    assert adapter.bindings["dc-motor-drive"].commands == ["drive.throttle", "drive.steering"]
    assert adapter.bindings["pca9685-camera-servo"].commands == ["camera.pitch"]
    assert adapter.actuators["camera-tilt"].pca9685_channel == 0
    assert adapter.channel_reservations["M1"].pca9685_channels == [15, 14]
    assert adapter.channel_reservations["M2"].pca9685_channels == [12, 13]
    assert adapter.bindings["ws2812-status"].commands == ["indicator.status.set"]
    assert adapter.bindings["buzzer"].commands == ["notification.buzzer.pattern"]
    assert profile.commands["drive.throttle"].subject == "testbot.command.drive.throttle"
    assert profile.commands["drive.steering"].subject == "testbot.command.drive.steering"
    assert profile.telemetry["battery_voltage"].subject == "testbot.telemetry.power.battery.voltage"