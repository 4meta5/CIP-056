# Planning Mode Prompts

Read this when: you are about to implement a feature, fix, or refactor and want to audit the plan before committing.

---

## Acceptance Criteria Extraction

Review the plan or feature description. Extract every testable acceptance criterion. If criteria are implicit or missing, write them explicitly.

For each criterion:
1. State the expected behavior in one sentence.
2. Define the observable output or state change.
3. Identify what "done" looks like (pass/fail, not subjective).

If you cannot extract at least 3 criteria, the plan is underspecified. Flag this before proceeding.

---

## Hidden Complexity Identification

Read the plan literally. For each step:
1. What assumptions does this step make about existing code?
2. What state must exist before this step can execute?
3. What side effects does this step produce?
4. Which other components depend on or are affected by this step?

List every dependency and assumption. Mark each as VERIFIED (you checked the code) or ASSUMED (you have not checked). Assumed dependencies are hidden complexity until verified.

---

## Tech Debt Trap Detection

Scan the plan for patterns that create future maintenance burden:

| Trap | Signal | Question to Ask |
|------|--------|-----------------|
| Hardcoded values | Magic numbers, string literals | Will this need to change? |
| Implicit contracts | Undocumented assumptions between modules | What breaks if this changes? |
| Missing error paths | Happy path only | What happens when this fails? |
| Tight coupling | One change requires changes in 3+ files | Can this be isolated? |
| Premature abstraction | Generic solution for a single use case | Is this actually needed now? |

For each trap detected, state the specific location and the maintenance cost it introduces.

---

## Pre-Mortem Scenario Template

Assume the implementation ships and fails in production. Work backward from failure.

Generate 3 scenarios:

**Scenario format:**
1. What failed (user-visible symptom)
2. Why it failed (technical root cause)
3. What in the plan enabled this failure
4. What would have caught it (test, review step, or design change)

Focus on failures that the current plan does not account for. Do not invent implausible scenarios. Target the most likely failure modes given the plan's assumptions.

---

## Minimal Test Plan

Tie each acceptance criterion to a concrete test:

| Criterion | Test Type | What It Validates |
|-----------|-----------|-------------------|
| (from extraction above) | Unit / Integration / Manual | Specific behavior verified |

Rules:
- Every criterion gets at least one test.
- Prefer unit tests. Use integration tests only when unit tests cannot cover the interaction.
- If a criterion cannot be tested, it is either underspecified or not a real criterion. Flag it.
- Do not add tests beyond what the acceptance criteria require.
