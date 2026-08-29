# ROV Datalogger current status

## Implemented

The runtime subscriber receives NATS Core messages and records a message to SQLite only when its payload differs from the last recorded value for that subject. Changes include their UTC timestamp, subject, raw payload, text representation, and normalised JSON where valid. A 30-day retention policy removes expired rows at startup and periodically during operation. CSV export primitives are available. Cockpit's canonical Raspberry Pi provisioner renders the Datalogger service for the actual checkout path and provides its local authenticated NATS URL through `/etc/robot/nats.env`. It does not control the ROV or provide a web UI.

## Automated-test verification

The repository contains `tests/test_store.py` and the documentation audit `tests/test_documentation.py`.

## Bench-tested and Production-validated

Physical ROV and production deployment validation are not recorded here and must not be inferred from source-code presence.

## Planned or unverified

- Reconnect handling and graceful service recovery.
- Batching, SQLite compaction, and operational monitoring. A lost database is intentionally recreated rather than restored.
- Raspberry Pi bench validation of the rendered unit, authenticated NATS URL, shared CSV export, and service restart behaviour.

## References

- `MASTER_CONTEXT.md`
- `docs/documentation-policy.md`
- `src/rov_datalogger/main.py`
- `src/rov_datalogger/store.py`
- `tests/test_store.py`
