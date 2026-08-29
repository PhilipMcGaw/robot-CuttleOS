from pathlib import Path

from rov_datalogger.store import TelemetryStore


def test_record_preserves_raw_and_json_payload(tmp_path: Path):
    store = TelemetryStore(tmp_path / "telemetry.sqlite3")
    store.record("sensor/depth", b'{"value": 12.5}')
    row = store.connection.execute(
        "SELECT topic, payload, payload_text, payload_json FROM messages"
    ).fetchone()
    store.close()
    assert row[0] == "sensor/depth"
    assert row[1] == b'{"value": 12.5}'
    assert row[2] == '{"value": 12.5}'
    assert row[3] == '{"value":12.5}'


def test_record_if_changed_ignores_repeated_payload(tmp_path: Path):
    store = TelemetryStore(tmp_path / "telemetry.sqlite3")
    assert store.record_if_changed("sensor/depth", b"12.5", "2026-01-01T00:00:00+00:00") is True
    assert store.record_if_changed("sensor/depth", b"12.5", "2026-01-01T00:00:01+00:00") is False
    assert store.record_if_changed("sensor/depth", b"12.6", "2026-01-01T00:00:02+00:00") is True
    count = store.connection.execute(
        "SELECT COUNT(*) FROM messages WHERE topic = ?", ("sensor/depth",)
    ).fetchone()[0]
    store.close()
    assert count == 2
