# Project working rules supplement

This file supplements the project-agnostic baseline at `agent-guidance/PROJECT_WORKING_RULES.md`. Keep the generic baseline intact. Use this supplement to explain how it applies to this project, record justified exceptions, and add project-specific instructions.

## Project identity

- **Project:** [name]
- **Repository root:** [root directory]
- **Project purpose:** [brief description]
- **Primary users or audience:** [audience]

## Context to read

List the authoritative orientation, architecture, status, safety, and contribution documents. State when each should be read.

- [Document and purpose]

## Sources of truth

Identify the authoritative sources for implementation, configuration, decisions, evidence, and current status. Give an order for resolving conflicts.

1. [Highest authority]
2. [Next authority]
3. [Lower-confidence context]

## Rule applicability and exceptions

The generic rules apply unless this section records a specific reason they do not apply or a project requirement changes their application. Avoid restating the baseline.

| Generic rule or section | Applies? | Project-specific handling and reason |
|---|---|---|
| [Rule or section] | Yes / No / With conditions | [Explain scope, exception, or why it is irrelevant] |

Exceptions MUST be narrow, explain their reason, and identify their scope. An exception changes only the stated rule and scope. It does not remove unrelated baseline requirements. Do not create exceptions to higher-priority instructions, user authorization, or environment permissions.

## Project-specific requirements

Add only requirements that are not already stated in the baseline. Use clear, direct wording. Use `MUST`, `MUST NOT`, `SHOULD`, `SHOULD NOT`, and `MAY` only with their intended normative meaning.

### File formatting and line endings

Agree the project's line-ending policy with the project owner before generating configuration. Use LF (`\n`) as the proposed default for text files. Treat Windows batch files (`*.bat`) as a CRLF (`\r\n`) exception when required by the Windows toolchain. Ask whether other file types need exceptions and record the answers. Do not assume VS Code is required.

After the owner confirms the policy, offer to create or update `.gitattributes` and `.editorconfig`, plus `.vscode/settings.json` only if the project uses VS Code. Mark the default and each exception by file type. Identify which file is authoritative for Git checkout normalisation and which files provide editor defaults. Do not name a configuration file as the source of truth unless it exists and has that role in the project.

- **Text-file default:** LF (`\n`), unless the owner confirms another policy
- **Exceptions:** `*.bat` may use CRLF (`\r\n`) where required; [other confirmed file types]
- **Policy sources:** [`.gitattributes` for Git normalisation; `.editorconfig` and supported editor settings for editor defaults]
- **Editing rule:** Preserve the policy and avoid mixed or line-ending-only changes

### Architecture and interfaces

- [Project-specific boundaries and contracts]

### Safety and consequential operations

- [Equipment, production, deployment, or data safeguards]

### Documentation and status

- [Required documentation updates and project status terms]

### Development and verification

- [Environment, commands, and verification expectations]

### Generated files and assets

- [Generation, licensing, attribution, and storage rules]

### Version control and release

- [Repository interface and authorization rules for commit, push, or release]

## Maintenance

Update this supplement when project structure, authority, workflows, or safety boundaries change. Keep general rules in the generic baseline; keep implementation detail in the project’s canonical documentation. If a project repeatedly needs a different general rule, propose a deliberate baseline revision rather than silently changing the baseline in one repository.
