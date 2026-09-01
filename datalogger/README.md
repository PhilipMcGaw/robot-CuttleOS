# ROV data logger

This repository contains the standalone telemetry logging service.

## Planned responsibility

The service subscribes to selected NATS Core subjects and persists a message to SQLite only when its payload differs from the last recorded value for that subject. Each change includes its UTC timestamp, subject, raw payload, text representation, and JSON representation where valid. Repeated identical values are ignored, including after restart. CSV export is available for analysis and backup workflows.

Implementation status: the NATS subscriber, SQLite storage path, change-only recording, 30-day retention, CSV export, and deployment integration are implemented. Reconnect recovery, compaction, operational monitoring, and production validation remain outstanding.

## Design constraints

- Run independently from `Control/` and `Cockpit/`.
- Never block or alter motor-control messages.
- Store the original NATS subject, value, timestamp, and quality/status where available.
- Use SQLite as the primary store and CSV as an export format.
- Add batching, recovery, compaction, and backup behaviour before production deployment.

The service is intentionally independent of Control and Cockpit; a database or export failure must not stop hardware control or the operator interface.
# ROV Datalogger

The target and current Datalogger interface is NATS Core. The runtime subscriber preserves raw message bytes, text, and JSON representations in SQLite.

## Quick start

Windows:

```text
scripts\1_install_dependencies.bat
scripts\2_start_app.bat
```

Linux/Raspberry Pi:

For an installed robot, follow the repository's [`docs/deployment.md`](../docs/deployment.md): its canonical
provisioner installs this service beside Cockpit and Control, renders the
systemd unit for the actual checkout location, and supplies the local
authenticated NATS URL. For local Linux development:

```zsh
python -m venv .venv
.venv/bin/pip install -r requirements.txt
./run.sh
```

Configuration uses `NATS_URL`, `NATS_SUBJECT`, `DATALOGGER_DATABASE`, `DATALOGGER_RETENTION_DAYS`, and `DATALOGGER_EXPORT_DIR`. The deployed unit obtains `NATS_URL` from the restricted `/etc/robot/nats.env` file and writes CSV to Cockpit's shared media directory. Retention defaults to 30 days; expired rows are removed at startup and periodically during operation. A missing or lost SQLite database is disposable and is recreated automatically. A complete `telemetry.csv` export is written at startup and refreshed during operation. The provisioning path is implemented but has not yet been Raspberry Pi bench-tested.

## Design boundary

This service records data but does not control the ROV, alter NATS messages, or provide a web UI. Cockpit and Control remain separate services.

## CSV export

CSV export is available through the `TelemetryStore.export_csv()` API. A command-line export tool will be added when the query/reporting requirements are settled.
