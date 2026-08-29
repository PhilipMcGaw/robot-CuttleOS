"""Unit checks for the profile-driven browser time-synchronisation contract."""

from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from rov_control.time_sync import (
    TimeSynchronisationConfig,
    load_time_synchronisation_config,
    parse_time_synchronisation_message,
)


class TimeSynchronisationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.config = TimeSynchronisationConfig(
            profile_id="rov",
            namespace="rov",
            command_subject="rov.cockpit.command.system.time-sync",
            status_subject="rov.control.status.system.time-sync",
            minimum_adjustment_seconds=0.5,
        )

    def test_profile_loads_expected_namespaced_subjects(self) -> None:
        path = ROOT / "tests" / "fixtures" / "time-sync-profile.json"
        config = load_time_synchronisation_config(path)
        self.assertEqual(config, self.config)

    def test_parser_uses_utc_milliseconds_and_active_profile(self) -> None:
        request = parse_time_synchronisation_message(
            b'{"value": 1767225600000, "units": "ms", "profile": "rov"}',
            self.config,
            current_time_seconds=1_767_225_599.0,
        )
        self.assertEqual(request.utc_unix_ms, 1_767_225_600_000)
        self.assertEqual(request.offset_seconds, 1.0)

    def test_parser_rejects_the_wrong_profile(self) -> None:
        with self.assertRaisesRegex(ValueError, "profile"):
            parse_time_synchronisation_message(
                b'{"value": 1767225600000, "units": "ms", "profile": "k9"}',
                self.config,
            )


if __name__ == "__main__":
    unittest.main()
