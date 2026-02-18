---
name: fresh-eyes
description: >-
  Apply perspective-shift discipline to plans, code, and bugs. Re-examine work
  as if seeing it for the first time. Use when: (1) about to implement a feature
  or fix, (2) reviewing your own code after writing it, (3) diagnosing a bug
  where the obvious fix did not work, (4) catching blind spots from familiarity.
  Three modes: Planning, Review, Reflection.
category: principles
---

# Fresh Eyes

Re-examine work as if seeing it for the first time. Familiarity breeds blind spots.

## Core Philosophy
- Assume your first understanding is incomplete
- Read code and plans literally, not through the lens of intent
- Treat "obvious" as a warning sign
- Surface findings without filtering for convenience

## Modes

### Planning Mode
**Trigger:** Plan exists, work not started.
Audit for hidden complexity, missing acceptance criteria, and tech debt traps.
**Deliverables:** Acceptance criteria, hidden complexity inventory, pre-mortem scenarios, minimal test plan.
See [references/planning-prompts.md](references/planning-prompts.md).

### Review Mode
**Trigger:** Code written, ready for review (especially your own).
Multi-pass review with different lenses per pass.
**Deliverables:** Pass 1 (first impressions), Pass 2 (edge cases/error paths), Pass 3 (regression risks). Classify as Blocker/Major/Minor/Structural Follow-up.
Stop after 2 consecutive clean passes or a fixed timebox.
See [references/review-prompts.md](references/review-prompts.md).

### Reflection Mode
**Trigger:** Bug fixed or incident resolved.
Build causal chains from symptom to root cause.
**Deliverables:** Causal chain with evidence, root vs symptom classification, tech debt signals, regression test guidance.
See [references/reflection-prompts.md](references/reflection-prompts.md).

## Routing

| Context | Mode |
|---------|------|
| Plan exists, work not started | Planning |
| PR/diff ready, or self-reviewing | Review |
| Bug fixed, post-incident, obvious fix failed | Reflection |

## Anti-Patterns
- Using fresh-eyes as a delay tactic — each mode has concrete deliverables and exit conditions
- Looping Review passes indefinitely — two clean passes, then stop
- Proposing fixes in Planning mode — surface problems only
