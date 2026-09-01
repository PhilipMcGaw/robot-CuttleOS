# Cockpit tests

Tests for the Cockpit package belong here. At minimum, verify application import, authentication boundaries, media path containment, camera fallback behaviour, and telemetry WebSocket handling when changing the web layer.
# Test guidance

Run the documentation currency audit from the repository root:

```text
python tests/test_control_documentation.py
python control/tests/test_documentation.py
python datalogger/tests/test_documentation.py
```

These checks verify maintained documentation, required status terminology, and
references to current scripts, configuration, examples, and frontend artefacts.
They may also be run by CI when the repository workflow is enabled.

For a pull request, pass the changed repository-relative paths to `python tests/documentation_change_policy.py`. The classifier requires at least one documentation change whenever a configured behaviour-affecting path changes.
