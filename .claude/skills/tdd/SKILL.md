---
name: tdd
description: |
  Enforces Test-Driven Development (TDD) workflow with three-phase gate system.
  Use when: (1) implementing new features, (2) fixing bugs, (3) refactoring code.
  Blocks progress at each phase until conditions are met. RED -> GREEN -> REFACTOR.
category: testing
---

# Test-Driven Development (TDD) Workflow

No implementation code until the full TDD cycle is followed.

## Three-Phase Gate System

### Phase 1: RED (Write Failing Test)
1. Write a test capturing expected behavior
2. Run it — must fail for the RIGHT reason (not syntax error)
3. Document failure output as proof

**If missing:** respond with "BLOCKED: PHASE 1 - RED REQUIRED" and stop.

### Phase 2: GREEN (Make It Pass)
1. Write the MINIMUM code to pass the test
2. No refactoring, no extras, no "while I'm here" changes
3. Run it — must pass. Document pass output as proof.

### Phase 3: REFACTOR (Clean Up)
1. Review for naming, structure, duplication improvements
2. Make changes while keeping tests green
3. Run tests after each change. Document what changed or "No refactoring needed."

## Gate Conditions

| Gate | Condition |
|------|-----------|
| RED -> GREEN | Test failure output shown |
| GREEN -> REFACTOR | Test pass output shown |
| REFACTOR -> Done | Tests still pass |

## Rules
- One feature per cycle. Complete RED->GREEN->REFACTOR before starting next feature.
- Never batch: "I'll write all tests first, then implement."

## Anti-Patterns
- "It's a simple change" — simple changes still need tests.
- "I'll add tests after" — tests after is not TDD. BLOCKED.
- "I know this works" — confidence is not proof.
