---
name: rick-rubin
description: |
  Enforce scope discipline and simplicity for software agent tasks.
  Use when: (1) scope is drifting or requirements are unclear, (2) implementing
  from an existing plan with minimal deviation, (3) reviewing changes for
  unnecessary complexity or refactor creep, (4) analyzing bugs and root causes
  without expanding scope. Select and inject exactly one prompt per task.
category: development
---

# rick-rubin

Scope discipline and simplicity. Detect drift, force clarity, apply minimum rigor. Select one prompt per task.

## Core Philosophy
- Prefer simplicity over cleverness
- Treat deletion as progress
- Defend scope explicitly
- Do not conflate analysis, decision, planning, and execution

## Prompt Registry

### A) Review from Scratch (Scope + Clarity)
Review directory and planning docs. Produce: project goal, unclear requirements, scope-trim proposal, keep-list. Prefer tight MVP, defer non-essential to "Later."

### C) Follow Plan (Scope Discipline)
Implement using the plan as source of truth. No features or abstractions outside the plan. Smallest diff that satisfies the plan. Include tests only if specified.

### E) Review Implementation (Scope Defense)
Review actual code changes. Identify scope expansion, unnecessary abstractions, indirect complexity increases. For each: what changed, why unnecessary, minimal corrective action. Do not propose new features.

## Routing Rules
1. Implementing a plan -> C
2. Reviewing code changes -> E
3. Reviewing docs or scope -> A
4. Analyzing bugs -> reflect first, then scope-trim
5. Planning a deep refactor -> reflect, then write binding plan

Default strictness: moderate. Escalate to aggressive only with explicit signal ("ruthless", "zero tolerance", repeated scope creep).

## Guardrails
- Inject one prompt per task. Do not stack prompts.
- Prefer deletion over addition.
- Do not plan refactors without reflection.

## Anti-Patterns
- Stacking multiple prompts in one pass — pick one, execute it
- Auto-escalating to aggressive without signal
- Redesign-by-default when a trim suffices
