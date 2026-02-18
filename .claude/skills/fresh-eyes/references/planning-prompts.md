# Planning Mode Prompts

Use when: about to implement a feature, fix, or refactor. Audit the plan before committing.

## Acceptance Criteria Extraction
Review the plan. Extract every testable criterion. For each: expected behavior (one sentence), observable output/state change, pass/fail definition. If fewer than 3 criteria extracted, the plan is underspecified.

## Hidden Complexity Identification
For each plan step: What assumptions about existing code? What state must exist? What side effects? What other components affected? Mark each dependency as VERIFIED (checked code) or ASSUMED (hidden complexity until verified).

## Tech Debt Trap Detection
Scan for: hardcoded values, implicit contracts, missing error paths, tight coupling (change requires 3+ files), premature abstraction. For each: specific location and maintenance cost.

## Pre-Mortem Scenarios
Assume the implementation ships and fails. Generate 3 scenarios: (1) user-visible failure, (2) technical root cause, (3) what in the plan enabled it, (4) what would have caught it. Target most likely failure modes, not implausible ones.

## Minimal Test Plan
Tie each acceptance criterion to a concrete test (unit/integration/manual). Every criterion gets at least one test. If a criterion cannot be tested, it is underspecified. Do not add tests beyond what criteria require.
