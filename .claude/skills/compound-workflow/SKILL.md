---
name: compound-workflow
description: >-
  Structured development workflow: brainstorm, plan, work, review, compound.
  Use when: (1) starting a new feature end-to-end, (2) coordinating multi-phase
  development work, (3) ensuring each phase completes before the next begins.
  Orchestration-thin — routes to existing local skills for phase-specific logic.
category: habits
---

# Workflow

A structured development cycle with five phases.

## Cycle
```
brainstorm -> plan -> work -> review -> compound
   (WHAT)     (HOW)   (DO)   (CHECK)   (LEARN)
```

## Phase Summary

| Phase | Purpose | Output | Routes To |
|-------|---------|--------|-----------|
| Brainstorm | Explore WHAT to build | Decision document | -- |
| Plan | Define HOW to build it | Structured plan file | `rick-rubin` (scope) |
| Work | Execute the plan | Working code + tests | `tdd`, `rick-rubin` |
| Review | Verify quality | Review findings | `diff-review` |
| Compound | Document learnings | Solution document | -- |

## Phases
1. **Brainstorm** — Explore requirements, 2-3 approaches, YAGNI. Exit: idea clear, approach chosen.
   See [references/plan-phase.md](references/plan-phase.md) for planning detail levels.
2. **Plan** — Research codebase patterns, write plan with acceptance criteria, run spec flow analysis.
   Routes to `rick-rubin` for scope discipline.
3. **Work** — Read plan, break into tasks, execute in priority order, test as you go, commit incrementally.
   Routes to `tdd` for test-driven work. See [references/work-phase.md](references/work-phase.md).
4. **Review** — Multi-angle review (security, performance, architecture). Synthesize by severity.
   Routes to `diff-review`. See [references/review-phase.md](references/review-phase.md).
5. **Compound** — Capture problem, investigation, root cause, solution in structured doc.
   See [references/compound-phase.md](references/compound-phase.md).

## Entry Points

| Scenario | Start At |
|----------|----------|
| Unclear requirements | Brainstorm |
| Clear requirements | Plan |
| Known bug fix | Work |
| PR ready | Review |
| Problem just solved | Compound |

## Key Rule
This skill is an orchestrator. It does not duplicate the internals of `tdd`, `rick-rubin`, `diff-review`, or language-specific review skills. Cross-link only.
