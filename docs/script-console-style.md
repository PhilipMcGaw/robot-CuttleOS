# Script console output style

## Purpose

CuttleOS command-line scripts shall present progress in a consistent, readable form. The output is part of the engineering interface of the script: it should make the current operation, result, and failure point obvious when a script is running on a development machine or robot.

The visual style is based on the established Test in a Box bootstrap scripts, which use full-width separators to identify major operations and clear status messages within each operation.

## Script structure

A script that performs more than one meaningful operation should normally use this structure:

1. A full-width banner identifying the script or overall operation.
2. A sequence of full-width section banners identifying the major operations as they run.
3. Status messages within each section.
4. A final full-width completion or failure banner.
5. A concise summary where it provides useful confirmation or next steps.

Example:

```text
======================================================================
  CuttleOS — Install Dependencies
======================================================================

------------------------------------------------------------------
  Python Environment
------------------------------------------------------------------

[INFO] Creating virtual environment...
[PASS] Virtual environment ready

------------------------------------------------------------------
  Frontend Dependencies
------------------------------------------------------------------

[INFO] Installing npm dependencies...
[PASS] Frontend dependencies installed

======================================================================
  Installation Complete
======================================================================
```

## Status messages

The following status prefixes shall be used consistently:

- `[INFO]` — progress information or useful non-error detail;
- `[PASS]` — an operation completed successfully;
- `[WARN]` — an unexpected or incomplete condition that does not prevent continuation;
- `[FAIL]` — an operation failed and the script cannot safely continue.

A status message should explain the engineering significance of a failure or warning where that is not obvious from the message itself. Corrective action should be stated where it is useful to the operator.

## Banners

The full-width banner is the primary visual structure. It should be wide enough to be obvious in a normal terminal, but the exact width is not significant. CuttleOS currently uses 70-character banners in its Bash scripts.

The top-level banner identifies the script or overall operation. Section banners identify meaningful sub-operations, such as dependency installation, configuration, service setup, validation, or frontend compilation.

Do not create a banner for every individual shell command. The purpose is to expose the engineering workflow, not to narrate implementation details.

## Output and comments

Terminal output and source-code comments serve different purposes. Output should explain what the script is currently doing and whether it succeeded. Source comments should explain non-obvious implementation decisions, assumptions, or constraints. Comments shall not be added merely to reproduce the terminal banners in the source code.

Scripts should avoid mixing several unrelated output styles. Bare `echo` statements, ad-hoc separators, and unlabelled progress messages should be replaced with the standard status and banner functions where practical.

Informal platform references in console output may use **RPi**; use **Raspberry Pi** when the script is defining or documenting the formal platform requirement.

## Platform consistency

The same conceptual output structure should be used by Bash, PowerShell, and Windows batch scripts. Platform-specific implementation may differ, but an operator should recognise the same stages and status meanings on each platform.

## Safety and failure behaviour

A banner or status message must not imply successful completion before the underlying operation has actually succeeded. A `[PASS]` message shall only be emitted after the operation it represents has returned successfully and any required validation has completed.

Scripts that perform provisioning, configuration, or other potentially consequential operations shall retain explicit failure handling. Visual consistency must not obscure the distinction between an informational message and a completed engineering action.

## Relationship to Test in a Box

Test in a Box is the reference implementation for the visual style, not a source of CuttleOS runtime behaviour. CuttleOS adopts the presentation convention because it makes multi-stage engineering scripts easier to follow and diagnose. The CuttleOS scripts remain responsible for their own platform, safety, deployment, and architectural requirements.
