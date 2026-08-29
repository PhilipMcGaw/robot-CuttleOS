# Cockpit tests

Tests for the Cockpit package belong here. At minimum, verify application import, authentication boundaries, media path containment, camera fallback behaviour, and telemetry WebSocket handling when changing the web layer.
# Test guidance

Run the documentation currency audit from the repository root:

```text
python tests/test_documentation.py
```

This standard-library check verifies maintained documentation, required status terminology, and references to current scripts, configuration, examples, and frontend artefacts. It is also run by CI.

For a pull request, pass the changed repository-relative paths to `python tests/documentation_change_policy.py`. The classifier requires at least one documentation change whenever a configured behaviour-affecting path changes.
