from pathlib import Path


ROOT = Path(__file__).parents[2]
SIMULATOR = ROOT / "apps/cockpit/rov_cockpit/templates/simulator.jinja"


def test_simulator_exposes_all_instrument_topics() -> None:
    content = SIMULATOR.read_text(encoding="utf-8")
    expected = (
        "sensor/water/depth",
        "sensor/ahrs/imu/heading",
        "sensor/ahrs/imu/pitch",
        "sensor/ahrs/imu/roll",
        "input/analog/battery/voltage",
        "input/analog/battery/percentage",
        "output/lights/left",
        "sensor/camera/main/pitch",
        "sensor/water/temperature",
    )
    for topic in expected:
        assert topic in content
