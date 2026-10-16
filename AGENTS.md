# CuttleOS agent instructions

These instructions apply throughout the `robot-CuttleOS` repository. Read them before inspecting or changing project files. Follow any more-specific `AGENTS.md` in a subdirectory as well. The user’s current request and the active environment permissions take precedence over repository guidance.

The reusable, project-agnostic baseline is in [`agent-guidance/PROJECT_WORKING_RULES.md`](agent-guidance/PROJECT_WORKING_RULES.md). Apply it together with these CuttleOS-specific instructions. The companion templates in [`agent-guidance/`](agent-guidance/README.md) are provided for adoption in other repositories; they do not replace this active `AGENTS.md`.

## Project context and authority

Read [`MASTER_CONTEXT.md`](MASTER_CONTEXT.md) for the project definition, architecture, boundaries, and status discipline. Read the relevant documents in [`docs/`](docs/README.md) for the task area. In particular:

- [`docs/system-architecture.md`](docs/system-architecture.md) describes system boundaries and cross-project contracts.
- [`docs/control-architecture.md`](docs/control-architecture.md), [`docs/safety-and-control.md`](docs/safety-and-control.md), and [`docs/hardware-interface.md`](docs/hardware-interface.md) cover control, safety, and hardware boundaries.
- [`docs/nats-contract.md`](docs/nats-contract.md) describes messaging contract principles.
- [`docs/deployment.md`](docs/deployment.md), [`docs/testing.md`](docs/testing.md), and [`docs/documentation-policy.md`](docs/documentation-policy.md) cover deployment, validation, and documentation requirements.
- [`docs/status.md`](docs/status.md) records current implementation and validation status; [`ROADMAP.md`](ROADMAP.md) records planned work.

Authority order for implementation behaviour is current code and configuration, plus direct bench evidence where physical behaviour is claimed; then current status and focused canonical documentation; then `MASTER_CONTEXT.md` and `docs/system-architecture.md`; then older notes or recollection. Chartroom is authoritative for cross-project architecture and shared engineering guidance. This repository is authoritative for CuttleOS implementation details. Do not redefine another repository’s responsibilities or contracts here.

When sources disagree, surface the conflict and explain which source governs the claim. Do not treat plans, old notes, or generated prose as evidence of implemented behaviour.

## Workspace and collaboration

- Keep project-file inspection and changes inside this repository and within the active sandbox permissions. Read a user-provided attachment only when the user explicitly asks you to use it and the environment permits access to that exact file.
- Preserve unrelated user changes. Do not reset, discard, overwrite, delete, or stage unrelated work.
- Do not follow redirects or filesystem links to reach files outside the permitted workspace. If a required resource is unavailable, report that and proceed with independent work.
- Do not copy private reasoning, credentials, tokens, passwords, private keys, or unrelated personal data into project files or summaries.
- Keep changes focused and reviewable. Re-read a file if it changes while you are working.

## Safety and engineering boundaries

- Treat hardware-affecting operations as consequential. Prefer code inspection, mock or simulator paths, and read-only checks before physical operations.
- Do not energise, move, or alter physical hardware to test software unless the user explicitly requests it and the documented safety procedure permits it. Follow interlocks and safe-state procedures.
- Cockpit is an operator interface, not a safety-critical control path. Control owns command validation, actuator limits, timeouts, emergency stop, neutral behaviour, and hardware interfaces. Preserve service isolation and the documented NATS contracts.
- Keep physical device mapping in configuration and hardware-facing drivers. Use logical device identities and explicit units and scaling in application-facing interfaces.
- Do not infer hardware capability from a stub, mock, simulation, or old note. Clearly distinguish planned, designed, implemented, automated-test verified, simulated, bench-tested, and production-validated behaviour.
- Record commissioning evidence with the software revision, hardware revision, configuration, and test conditions when those are available. Do not invent missing details.

## Documentation and writing

- Documentation is part of the implementation. In the same change, update the relevant docs when behaviour, APIs, configuration, hardware support, safety, deployment, data formats, tests, workflows, frontend architecture, dependencies, bundled assets, or validation status changes.
- Update `MASTER_CONTEXT.md` when architecture, boundaries, operating conventions, or validation status changes. Update `docs/system-architecture.md` when a wider system boundary or cross-repository contract changes. Update `docs/status.md` when implemented features, limitations, or validation evidence changes. Update `LICENSES.md` when third-party dependencies or assets are added, removed, replaced, or redistributed.
- Follow [`docs/documentation-policy.md`](docs/documentation-policy.md), including its language, terminology, symbols, units, normative wording, and status rules. Write new human-readable project text in British English. Preserve official names, identifiers, quotations, code, and historical source text.
- Keep operator-facing text plain, concise, and action-oriented. Explain necessary technical terms in context. Engineering documentation may use field terminology but must remain direct and precise.
- Do not claim full ASD-STE100 compliance unless requested and checked against the current official specification.
- Use precise status language. Code presence or an automated test alone does not establish bench-tested or production-validated behaviour.
- Do not duplicate detailed implementation documentation in cross-project summaries when a link to the authoritative source is sufficient.
- Never hand-edit generated assets or compiled frontend output. Update the source and use the documented generation process when requested and safe.

## Development and verification

- Before changing code, inspect the relevant implementation, configuration, documentation, and existing validation approach. Check the repository state if the available tools support it.
- Do not add or run tests unless the user asks. If asked to test, start with the narrowest relevant check, then expand as appropriate. Report exact checks and any environment blockers.
- The repository documentation policy lists these documentation checks when applicable:

  ```text
  python tests/test_control_documentation.py
  python control/tests/test_documentation.py
  python datalogger/tests/test_documentation.py
  ```

- Inspect `scripts/deploy.sh` and the relevant provisioning scripts before changing build or deployment behaviour. Building and publishing are separate operations. Do not deploy or publish merely to validate a change.
- Treat production host commands and destructive synchronisation options such as `rsync --delete` as consequential. Do not run production deployment unless explicitly requested.
- Do not expose secrets in diagnostic output. Keep temporary files and generated run artefacts out of the repository unless the task requires them.

## Version control and delivery

- Use the available repository interface. On Windows, `git` may not be on PowerShell’s `PATH`; follow the configured GitHub Desktop or repository-helper workflow where available rather than assuming Git is unavailable.
- Review the complete task diff and status before staging. Stage only files that belong to the task. Do not rewrite history, force-push, or discard unrelated changes.
- Do not commit, push, deploy, publish, or contact external services unless the user requested it or an applicable instruction clearly authorizes it. Do not bypass a permission or sandbox block.
- In the hand-off, summarise changed files, rationale, checks performed (if requested), and material uncertainty or blockers. Do not report a check as passed unless it was run and passed.
