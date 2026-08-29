"""Checks for Control-owned hardware bindings in the shared robot profiles."""

from pathlib import Path
import sys
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from rov_cockpit.app import ActiveRobotProfile, load_active_robot_profile


def load_profile(name: str) -> ActiveRobotProfile:
    path = ROOT / "configs" / "profiles" / f"{name}.json"
    with patch("rov_cockpit.app.active_robot_profile_path", return_value=path):
        return load_active_robot_profile()


def adapter(profile: ActiveRobotProfile):
    assert len(profile.hardware.adapters) == 1
    result = profile.hardware.adapters[0]
    assert result.driver == "adeept-robot-hat-adm133"
    assert result.model == "ADM133"
    assert result.validation_status == "planned-unverified"
    return result


def test_k9_adm133_bindings_resolve_to_profile_topics() -> None:
    profile = load_profile("k9")
    main_hat = adapter(profile)

    assert main_hat.bindings["dc-motor-drive"].commands == ["drive.throttle", "drive.steering"]
    assert [profile.commands[key].subject for key in main_hat.bindings["dc-motor-drive"].commands] == [
        "k9.command.drive.throttle",
        "k9.command.drive.steering",
    ]
    assert [profile.commands[key].subject for key in main_hat.bindings["pca9685-servos"].commands] == [
        "k9.command.animatronics.head.pan",
        "k9.command.animatronics.head.tilt",
    ]
    assert main_hat.actuators["head-pan"].port_alias == "servo-00"
    assert main_hat.actuators["head-pan"].pca9685_channel == 0
    assert main_hat.actuators["head-pan"].command == "head.pan"
    assert main_hat.actuators["head-tilt"].port_alias == "servo-01"
    assert main_hat.actuators["head-tilt"].pca9685_channel == 1
    assert main_hat.actuators["head-tilt"].command == "head.tilt"
    assert [profile.telemetry[key].subject for key in main_hat.bindings["adc-battery"].telemetry] == [
        "k9.telemetry.power.battery.percentage",
        "k9.telemetry.power.battery.voltage",
    ]


def test_piwars_adm133_bindings_resolve_to_profile_topics() -> None:
    profile = load_profile("piwars")
    main_hat = adapter(profile)

    assert [profile.commands[key].subject for key in main_hat.bindings["dc-motor-drive"].commands] == [
        "piwars.command.drive.throttle",
        "piwars.command.drive.steering",
    ]
    assert [profile.telemetry[key].subject for key in main_hat.bindings["line-tracking"].telemetry] == [
        "piwars.telemetry.sensors.line.left",
        "piwars.telemetry.sensors.line.centre",
        "piwars.telemetry.sensors.line.right",
    ]
    assert [profile.telemetry[key].subject for key in main_hat.bindings["ultrasonic-range"].telemetry] == [
        "piwars.telemetry.sensors.distance.front"
    ]


def main() -> int:
    test_k9_adm133_bindings_resolve_to_profile_topics()
    test_piwars_adm133_bindings_resolve_to_profile_topics()
    print("[PASS] ADM133 profile-topic bindings passed for K9 and PiWars.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
