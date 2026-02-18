# Plan Phase

Transform feature descriptions into structured implementation plans.

## Input
Feature description, bug report, or brainstorm document. If a brainstorm doc exists in `docs/brainstorms/` (created within 14 days), use as context and skip idea refinement.

## Research
1. **Local** (always): Scan repo for existing patterns, CLAUDE.md guidance, `docs/solutions/`
2. **External** (conditional): Only for high-risk topics (security, payments, external APIs) or unfamiliar territory

## Spec Flow Analysis
After structuring the plan: map all user flows, identify gaps/ambiguities, formulate clarifying questions.

## Detail Levels
- **Minimal** — Simple bugs, small improvements. Problem statement + acceptance criteria + essential context.
- **Standard** — Most features. Adds: background, technical considerations, success metrics, dependencies, risks.
- **Comprehensive** — Major features, architectural changes. Adds: phased implementation, alternatives considered, resource requirements, risk mitigation.

## Plan File
`docs/plans/YYYY-MM-DD-<type>-<descriptive-name>-plan.md` (type: `feat`, `fix`, `refactor`).
Required: title, type, problem/feature description, acceptance criteria (checkboxes).

## Scope Discipline
Route to `rick-rubin` to prevent scope creep. Defer non-essential to "Later" section.
