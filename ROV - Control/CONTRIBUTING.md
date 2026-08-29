# Contributing to ROV Control

Documentation updates are mandatory in the same change whenever control behaviour, NATS subjects or payloads, configuration, hardware mappings, safety behaviour, deployment, dependencies, tests, workflows, or units change. Keep `MASTER_CONTEXT.md` and `docs/status.md` current when architecture or validation status changes.

Use formal British English and distinguish implemented, automated-test verified, bench-tested, production-validated, and planned or unverified behaviour. Run `python tests/test_documentation.py` before submitting a change. CI also enforces the pull-request documentation classifier.
