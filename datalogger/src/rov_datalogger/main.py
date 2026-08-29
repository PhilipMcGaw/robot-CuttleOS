import logging
import asyncio
from pathlib import Path

import nats

from .config import Settings
from .store import TelemetryStore

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
LOGGER = logging.getLogger(__name__)


async def run(settings: Settings | None = None) -> None:
    settings = settings or Settings.from_environment()
    store = TelemetryStore(settings.database_path)
    removed = store.purge_older_than(settings.retention_days)
    LOGGER.info("Retention policy: %s days; removed %s expired messages", settings.retention_days, removed)
    export_path = settings.export_directory / "telemetry.csv"
    store.export_csv(export_path)
    client = await nats.connect(settings.nats_url)
    changed_messages = 0

    async def on_message(message):
        nonlocal changed_messages
        if store.record_if_changed(message.subject, message.data):
            changed_messages += 1
            LOGGER.info("Recorded changed value for %s", message.subject)
            if changed_messages % 100 == 0:
                removed = store.purge_older_than(settings.retention_days)
                if removed:
                    LOGGER.info("Retention cleanup removed %s expired messages", removed)
                store.export_csv(export_path)

    LOGGER.info("Connected to NATS at %s; subscribing to %s", settings.nats_url, settings.nats_subject)
    await client.subscribe(settings.nats_subject, cb=on_message)
    try:
        await asyncio.Event().wait()
    except (asyncio.CancelledError, KeyboardInterrupt):
        LOGGER.info("Stopping Datalogger")
    finally:
        await client.drain()
        store.close()


if __name__ == "__main__":
    asyncio.run(run())
