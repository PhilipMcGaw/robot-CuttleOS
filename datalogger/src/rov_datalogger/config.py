from dataclasses import dataclass
import os
from pathlib import Path


@dataclass(frozen=True)
class Settings:
    nats_url: str = os.getenv("NATS_URL", "nats://127.0.0.1:4222")
    nats_subject: str = os.getenv("NATS_SUBJECT", ">")
    database_path: Path = Path(os.getenv("DATALOGGER_DATABASE", "data/telemetry.sqlite3"))
    retention_days: int = int(os.getenv("DATALOGGER_RETENTION_DAYS", "30"))
    export_directory: Path = Path(os.getenv("DATALOGGER_EXPORT_DIR", "data/csv"))

    @classmethod
    def from_environment(cls) -> "Settings":
        return cls()
