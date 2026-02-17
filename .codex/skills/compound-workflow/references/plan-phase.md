# Plan Phase

Transform feature descriptions into structured implementation plans.

## Input

A feature description, bug report, or brainstorm document.

If a brainstorm document exists in `docs/brainstorms/` matching the feature and created within 14 days, use it as context and skip idea refinement.

## Research

1. **Local research** (always): Scan repo for existing patterns, CLAUDE.md guidance, and documented solutions in `docs/solutions/`.
2. **External research** (conditional): Run only for high-risk topics (security, payments, external APIs) or unfamiliar territory.

## Spec Flow Analysis

After structuring the plan, run spec flow analysis to validate completeness:

- Map all user flows and permutations
- Identify gaps, ambiguities, and missing specs
- Formulate specific clarifying questions

## Detail Levels

Choose based on complexity:

### Minimal

For simple bugs, small improvements. Includes: problem statement, acceptance criteria, essential context.

### Standard

For most features. Adds: background, technical considerations, success metrics, dependencies, risks.

### Comprehensive

For major features and architectural changes. Adds: phased implementation, alternatives considered, resource requirements, risk mitigation.

## Plan File Structure

```
docs/plans/YYYY-MM-DD-<type>-<descriptive-name>-plan.md
```

Type prefix: `feat`, `fix`, `refactor`.

Required sections (minimum):
- Title and type
- Problem/feature description
- Acceptance criteria (checkboxes)

## Scope Discipline

Route to `rick-rubin` during planning to prevent scope creep. The plan should be tight, deferring non-essential work to a "Later" section.
