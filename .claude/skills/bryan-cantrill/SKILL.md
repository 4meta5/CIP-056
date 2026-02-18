---
name: bryan-cantrill
description: >-
  Evidence-first engineering. Written design before implementation, risk-ordered
  execution, observability as a requirement, scope discipline through explicit
  non-goals. Use when: (1) starting non-trivial implementation work, (2) planning
  task order, (3) reviewing whether a feature is complete, (4) enforcing merge
  and review discipline.
category: principles
---

# Bryan Cantrill

Write it down. Reduce uncertainty first. Instrument reality. Do not merge unreviewed thinking.

## Core Principles
1. No non-trivial implementation without a written design artifact
2. Reduce risk first, not what is easiest first
3. Every feature must define its observability contract
4. Every plan must declare explicit non-goals
5. No solo merge of architectural shifts
6. Measure reality. Opinion is not evidence.

## Planning Template
```
State: [ideation | discussion | published | committed]
Goal:
Non-goals:
Alternatives considered:
Primary risk:
What invalidates this approach:
Observability plan:
Minimal end-to-end slice:
What we explicitly defer:
```
If this cannot be filled concisely, the work is not understood.

## Risk-Ordered Execution
1. Lock interfaces
2. Add observability scaffolding
3. Attack highest-risk unknown
4. Deliver minimal end-to-end slice
5. Harden
6. Expand features

Before sequencing: What reduces uncertainty first? What invalidates the plan fastest? What assumptions are most dangerous?

## Observability Contract
Every feature must answer: (1) What signal proves it works? (2) What signal proves it fails? (3) What signal distinguishes failure modes? If unanswerable, the feature is incomplete.

## Scope Discipline
Every plan declares non-goals. When new work appears during implementation: create a new design artifact or remove something of equal weight. No silent expansion.

## Merge Discipline
Designs reviewed before implementation begins. Significant changes reviewed before merge. Unreviewed thinking becomes institutional debt.

## Anti-Patterns
- "We'll instrument later" — later never comes; define observability now
- "The design is in my head" — unwritten design is unreviewed design
- "This is too small to plan" — small changes compound into architectural drift
