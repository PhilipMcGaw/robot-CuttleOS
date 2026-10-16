# Project-agnostic agent working rules

This is the stable, project-agnostic baseline for agent work across software, engineering, research, and documentation projects. Do not edit or trim this file to fit an individual project. Use a separate project supplement to state applicability, justified exceptions, and additional local rules. A reusable supplement template is in [`PROJECT_WORKING_RULES_SUPPLEMENT_TEMPLATE.md`](PROJECT_WORKING_RULES_SUPPLEMENT_TEMPLATE.md).

## Purpose and authority

- Treat the repository as shared project work. Preserve existing work and make focused, reviewable changes.
- Read applicable `AGENTS.md` files and the project’s orientation and context documents before editing. More-specific instructions apply within their directory unless they conflict with higher-priority instructions or the user’s request.
- Identify the source of truth for each topic. Prefer current implementation, configuration, and direct evidence for behaviour; use maintained project documentation for intended architecture and policy; treat older notes and recollections as lower-confidence context.
- When sources disagree, identify the conflict and the relevant authority. Do not silently choose a convenient interpretation.
- Do not copy private reasoning, credentials, or unrelated personal information into project files.

## Scope and workspace

- Keep inspection and changes within the active repository and the permissions of the environment. A user-provided attachment may be read only when the user explicitly asks you to use it and the environment permits access to that file.
- Do not follow links, symlinks, or redirects to access material outside the permitted workspace.
- If a required resource is unavailable, say so and continue with work that does not depend on it. Do not search unrelated locations to fill the gap.
- Preserve unrelated changes. Do not reset, overwrite, delete, or stage unrelated work.
- Keep credentials, private keys, tokens, passwords, local configuration, generated logs, and temporary artefacts out of project changes unless the project explicitly requires them.

## Evidence and claims

- Keep documented facts, direct observations, test results, recollections, inferences, proposals, and unresolved questions distinct.
- Do not invent dates, measurements, responsibilities, decisions, configurations, outcomes, test results, or attribution.
- Do not treat a question, draft, implementation, or general technical explanation as evidence that a specific event or result occurred.
- Make claims proportional to the available evidence. State material uncertainty and conflicts plainly; prefer a narrower supported claim to a broader unsupported one.
- Use explicit status terms where useful, such as planned, designed, implemented, simulated, tested, validated, or production-proven. Define what each status means for the project.

## Editing and documentation

- Inspect relevant files, conventions, and current state before editing. Determine which file is authoritative and whether the change belongs in code, configuration, documentation, or generated output.
- Make the smallest coherent change that completes the request. Avoid unrelated cleanup and duplicate documentation.
- Update documentation in the same change when behaviour, interfaces, configuration, hardware support, safety, deployment, data formats, dependencies, workflows, or validation status changes.
- Keep stable project context separate from dated decisions, current status, and detailed procedures when the project has those document types.
- Never hand-edit generated output. Find and use the project’s generation process, or report why it cannot run.
- Preserve the project’s formatting, encoding, line-ending, terminology, and licensing conventions. Check licences and attribution before adding third-party assets.
- Do not create or run tests unless the user asks. If the user asks for verification, choose checks that fit the changed area and report what ran and what did not.

## Language and technical writing

- Write newly authored human-readable project text in British English unless the project has an explicitly adopted alternative. Preserve official names, product spellings, identifiers, quotations, code, and historical source text.
- Use clear, concise, precise language. Prefer familiar words, direct sentence structure, active voice, and consistent terminology. Remove repetition and promotional wording. Use the Oxford comma where it improves clarity.
- Use gender-neutral wording for roles and groups when gender is irrelevant. Use a person’s stated name and pronouns; do not infer them. Preserve gendered wording in quotations and historical material.
- Define an unfamiliar abbreviation or acronym at its first use on each page. Avoid abbreviations used only once. Preserve terminology defined by standards, protocols, manufacturers, or other authoritative sources.
- Use full ISO dates (`YYYY-MM-DD`) in technical records. In prose, write month and year as `April 2025`. Include a time zone or UTC offset when it affects interpretation; prefer UTC for distributed logs and test records unless the project requires another zone.
- Use SI units and symbols where applicable, with a non-breaking space between a value and its unit or symbol (for example, `10 mm`, `5 V`, and `25 °C`). Use correct Unicode symbols where readable and preserve required machine syntax. Retain imperial source values and add an appropriately rounded approximate SI conversion where useful.
- Use `program` for software and `programme` for an organised activity; use `licence` as a noun and `license` as a verb. Follow established project and external conventions where they apply.
- Use status terms precisely, such as planned, designed, implemented, simulated, bench-tested, validated, and production-proven. Do not claim full compliance with a writing standard unless the applicable current standard has been checked.
- Use normative terms such as `MUST`, `MUST NOT`, `SHOULD`, `SHOULD NOT`, and `MAY` only when their requirement or recommendation meaning is intended. Keep examples clearly distinct from requirements.

## Safety and consequential actions

- Treat commands that can affect physical equipment, production systems, user data, deployments, or external services as consequential.
- Prefer read-only inspection and safe simulation. Follow documented interlocks, safe states, and verification procedures.
- Do not perform destructive, irreversible, production, publishing, or external communication actions without clear user authorization. Prepare a reviewable result first when approval is required.
- Do not send messages to other people or services unless the user explicitly authorized that communication.

## Communication and delivery

- Keep the user informed with concise progress updates during sustained work.
- Report what changed, why, what verification was performed, and any material limitations or unresolved points.
- Link to changed files and identify the relevant evidence for conclusions.
- Do not claim a check passed unless it was actually run and passed.

## Version control

- Inspect repository status and the complete relevant diff before staging or committing. Stage only task-related files.
- Use the project’s normal version-control interface and authentication. If a command-line Git operation is needed, locate the executable before assuming Git is unavailable: check the shell command lookup, then a repository-provided helper, then the version-control application’s documented bundled executable or official installation. On Windows, `Get-Command git` and `where.exe git` can check `PATH`. Do not guess a versioned installation path; verify the executable exists and run its version command. Record machine-specific paths only in project-specific instructions and recheck them after application upgrades.
- Do not expose credentials.
- Do not rewrite history, force-push, or discard unrelated work.
- Follow the project supplement and the user’s instructions for whether and when to commit, push, or publish. The generic baseline does not require automatic commits or pushes for every project.
- When a push is required or authorized, follow the project’s branch-integration procedure. Fetch and integrate the latest target branch before pushing when the project workflow requires it. Do not assume the target branch is `main`.
- Report concrete blockers. Do not bypass permissions, rewrite history, force-push, or include unrelated changes.
