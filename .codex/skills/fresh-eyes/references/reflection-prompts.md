# Reflection Mode Prompts

Read this when: a bug was fixed or an incident resolved and you want to understand why it happened.

---

## Causal Chain Construction

Build a chain from the user-visible symptom to the root cause. Each link must be justified with evidence.

**Format:**
```
Symptom: [what the user or system observed]
  ← caused by: [immediate technical cause] (evidence: [file:line or log entry])
    ← caused by: [deeper cause] (evidence: [file:line or design decision])
      ← caused by: [root cause] (evidence: [file:line, commit, or architecture])
```

Rules:
- Minimum 3 links. If your chain is shorter, you stopped too early.
- Every link must cite evidence (line number, commit, log, or documented decision).
- Do not skip levels. Each cause must directly produce the next effect.
- If a link is uncertain, mark it as UNCERTAIN and state what evidence would confirm it.

---

## Root vs Symptom Determination

After building the causal chain, classify each link:

| Link | Classification | Test |
|------|---------------|------|
| The thing that broke | Symptom | Fixing this alone would leave the underlying problem |
| The code that misbehaved | Proximate cause | Fixing this prevents this specific failure |
| The decision that made it possible | Root cause | Fixing this prevents the entire class of failures |

The root cause is the deepest link where a change would prevent the entire class of failures, not just this instance.

If the fix only addressed a symptom or proximate cause, note what remains unfixed and why the root cause persists.

---

## Tech Debt Signal Extraction

Examine the causal chain for patterns that indicate structural weakness:

| Signal | What It Looks Like | What It Means |
|--------|-------------------|---------------|
| Repeated area | Same file/module appears in multiple bug chains | This area is fragile |
| Missing validation | Input trusted without checking | Boundary is undefended |
| Implicit contract | Behavior depends on undocumented assumption | Change will break silently |
| Error swallowing | Failure hidden or ignored | Bugs will be harder to diagnose |
| Coupling | Fix required changes in 3+ files | Components are entangled |

For each signal detected, state:
1. Where it appears in the causal chain
2. What class of bugs it enables
3. Whether fixing it is worth the cost (not all debt needs paying)

---

## Pattern Detector Variant

Use this variant when you suspect a recurring pattern across multiple bugs.

Compare the current causal chain to previous ones:
1. Do the same modules appear?
2. Are the root causes structurally similar?
3. Is the same assumption being violated repeatedly?

If a pattern emerges, document it as a known fragility zone. This feeds into Planning mode for future work in the same area.

---

## Regression Test Guidance

For each root cause and proximate cause in the chain:

1. Does a test exist that would have caught this? If yes, why did it not catch it?
2. If no test exists, write a test description (not implementation) that would catch this specific failure.
3. Can the test be generalized to catch the class of failures, not just this instance?

Rules:
- One regression test per proximate cause at minimum.
- Property-based tests are preferred when the failure involves unexpected input combinations. Reference `tdd` skill for property-based testing patterns.
- Do not write tests for symptoms. Test causes.
