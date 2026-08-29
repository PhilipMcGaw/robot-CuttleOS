import csv
import json
import sqlite3
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Iterable


class TelemetryStore:
    def __init__(self, database_path: Path):
        self.database_path = database_path
        self.database_path.parent.mkdir(parents=True, exist_ok=True)
        self.connection = sqlite3.connect(self.database_path)
        self.connection.execute("""
            CREATE TABLE IF NOT EXISTS messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                received_at TEXT NOT NULL,
                topic TEXT NOT NULL,
                payload BLOB NOT NULL,
                payload_text TEXT,
                payload_json TEXT
            )
        """)
        self.connection.execute("CREATE INDEX IF NOT EXISTS idx_messages_received_at ON messages(received_at)")
        self.connection.execute("CREATE INDEX IF NOT EXISTS idx_messages_topic ON messages(topic)")
        self.connection.commit()

    def record(self, topic: str, payload: bytes, received_at: str | None = None) -> None:
        timestamp = received_at or datetime.now(timezone.utc).isoformat()
        text = payload.decode("utf-8", errors="replace")
        try:
            structured = json.dumps(json.loads(text), separators=(",", ":"))
        except (json.JSONDecodeError, TypeError):
            structured = None
        self.connection.execute(
            "INSERT INTO messages(received_at, topic, payload, payload_text, payload_json) VALUES (?, ?, ?, ?, ?)",
            (timestamp, topic, payload, text, structured),
        )
        self.connection.commit()

    def record_if_changed(self, topic: str, payload: bytes, received_at: str | None = None) -> bool:
        """Record a subject only when its payload differs from the last value."""
        previous = self.connection.execute(
            "SELECT payload FROM messages WHERE topic = ? ORDER BY id DESC LIMIT 1",
            (topic,),
        ).fetchone()
        if previous is not None and previous[0] == payload:
            return False
        self.record(topic, payload, received_at)
        return True

    def purge_older_than(self, retention_days: int, now: datetime | None = None) -> int:
        """Delete messages older than the configured UTC retention window."""
        if retention_days < 1:
            raise ValueError("retention_days must be at least 1")
        current = now or datetime.now(timezone.utc)
        cutoff = (current - timedelta(days=retention_days)).isoformat()
        cursor = self.connection.execute("DELETE FROM messages WHERE received_at < ?", (cutoff,))
        self.connection.commit()
        return cursor.rowcount

    def export_csv(self, destination: Path, rows: Iterable[tuple] | None = None) -> None:
        destination.parent.mkdir(parents=True, exist_ok=True)
        query = rows if rows is not None else self.connection.execute(
            "SELECT id, received_at, topic, payload_text, payload_json FROM messages ORDER BY id"
        )
        with destination.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.writer(handle)
            writer.writerow(("id", "received_at", "topic", "payload_text", "payload_json"))
            writer.writerows(query)

    def close(self) -> None:
        self.connection.close()
