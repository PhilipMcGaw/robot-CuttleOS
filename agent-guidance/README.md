# Reusable agent guidance kit

This folder contains reusable agent guidance for use in other project repositories. The root [`AGENTS.md`](../AGENTS.md) remains the active, CuttleOS-specific instruction file for this repository.

## Files

- [`PROJECT_WORKING_RULES.md`](PROJECT_WORKING_RULES.md) is the project-agnostic baseline. Keep it intact when adopting it in another project.
- [`PROJECT_WORKING_RULES_SUPPLEMENT_TEMPLATE.md`](PROJECT_WORKING_RULES_SUPPLEMENT_TEMPLATE.md) is the per-project applicability and exception record. Copy it to the other project and fill it in; do not put project-specific rules in the baseline.
- [`AGENTS_TEMPLATE.md`](AGENTS_TEMPLATE.md) is a starting point for that project's root `AGENTS.md`. Fill in its paths and project instructions, then save it as `AGENTS.md` in the target repository.

## Set up another repository

1. Copy the generic baseline and both templates into a clearly named guidance folder in the target repository, for example `agent-guidance/`.
2. Copy `AGENTS_TEMPLATE.md` to the target repository root as `AGENTS.md` and replace its placeholders with the project’s actual context paths and instructions.
3. Copy `PROJECT_WORKING_RULES_SUPPLEMENT_TEMPLATE.md` to the target repository root as `PROJECT_WORKING_RULES_SUPPLEMENT.md` and complete its applicability table and local requirements.
4. Keep the generic baseline unchanged. Have the root `AGENTS.md` point to both `agent-guidance/PROJECT_WORKING_RULES.md` and `PROJECT_WORKING_RULES_SUPPLEMENT.md` using paths that work in the target repository.
5. Add more-specific `AGENTS.md` files only where a subdirectory needs rules beyond or narrower than the root instructions.

The root `AGENTS.md` is the entry point agents discover automatically. It should explicitly direct agents to read the baseline and supplement; storing either file in a folder does not make it active by itself.
