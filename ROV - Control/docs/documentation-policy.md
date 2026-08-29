# Documentation currency policy

Documentation is an engineering deliverable and must be updated in the same change as the behaviour it describes.

This is a hard completion requirement, not an optional follow-up. A behaviour-affecting change is incomplete until the same change set contains the relevant documentation updates and, where applicable, an updated `MASTER_CONTEXT.md`. Obsolete contradictory documentation must be corrected or removed. “To be documented later” is not an acceptable completion state.

Update documentation whenever control behaviour, APIs, NATS subjects or payloads, configuration, hardware support, safety behaviour, deployment, data formats, tests, workflows, dependencies, or units change. Update `MASTER_CONTEXT.md` whenever architecture, boundaries, conventions, or validation status changes.

Distinguish implemented, automated-test verified, bench-tested, production-validated, and planned or unverified behaviour. Code existence alone is not evidence of hardware or production validation.

Run `python tests/test_documentation.py`. Pull-request paths are classified by `tests/documentation_change_policy.py` using `tests/documentation_change_policy.json`; behaviour-affecting changes require documentation in the same change. Intentional exemptions are recorded with reasons in that JSON file. Both checks run in CI.

## Written style, terminology, and units

Use formal British English, clear and concise technical language, and consistent terminology. Define abbreviations at first use. Use Oxford commas in lists of three or more items. Use SI units and recognised symbols with a space between the value and unit, for example `10 V`, `25 °C`, and `5 µs`; use ISO 8601 dates and explicit UTC offsets for distributed records. Preserve machine-readable syntax exactly, including NATS subjects, configuration keys, paths, and commands.

## Normative language and identifiers

Use `MUST`, `MUST NOT`, `SHALL`, `SHALL NOT`, `SHOULD`, `SHOULD NOT`, and `MAY` only with their RFC 2119 meanings. Distinguish illustrative examples from requirements. Format literal file names, paths, commands, configuration keys, API endpoints, subject names, and package names as code.

## Cross-repository consistency

Use `Cockpit`, `Control`, `Datalogger`, and `HiL/SiL` consistently for the services and environment. The current repository layout uses `ROV---Cockpit`, `ROV---Control`, `ROV---Datalogger`, and `ROV---HiL-and-SiL`. Interactive commands assume Zsh; scripts may use their declared shebang interpreter. When implementation and documentation disagree, record the discrepancy and correct the authoritative document in the same change.
