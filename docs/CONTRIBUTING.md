# Contributing to ROV Cockpit

## Documentation requirement

Documentation updates are mandatory in the same change whenever user-visible behaviour, APIs, configuration, hardware support, safety behaviour, deployment, data formats, tests, workflows, or frontend architecture changes.

Keep `MASTER_CONTEXT.md` current when project architecture, boundaries, conventions, or validation status changes. Keep `docs/status.md` current when implemented features, limitations, or validation evidence changes. Use formal British English and distinguish implemented, automated-test verified, bench-tested, production-validated, and planned or unverified behaviour.

Before submitting a change, run:

```text
python tests/test_control_documentation.py
python control/tests/test_documentation.py
python datalogger/tests/test_documentation.py
```

Where CI is enabled, the documentation checks run as part of the validation
pipeline. Documentation drift should be treated as a failed check locally as
well.

Pull requests are also checked by `tests/documentation_change_policy.py`. Its allowlist classifies source, frontend, configuration, deployment, dependency, and project-entry files as potentially behaviour-affecting. Such a change must include documentation in the same pull request. Intentional exemptions are maintained, with reasons, in `tests/documentation_change_policy.json`.
