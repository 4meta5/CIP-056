# Review Mode Prompts

Read this when: code is written and ready for review, especially when reviewing your own work.

---

## Multi-Pass Review Discipline

Review the diff in three sequential passes. Each pass uses a different lens. Do not combine passes.

### Pass 1: First Impressions

Read the diff as if you have never seen the codebase. Note:
- Names that confuse or mislead
- Control flow that surprises
- Comments that contradict the code
- Anything that requires re-reading to understand

Do not evaluate correctness yet. Capture confusion signals only.

### Pass 2: Edge Cases and Error Paths

For each changed function or block:
1. What inputs are not handled?
2. What happens on empty, null, zero, negative, or maximum values?
3. What error paths exist? Are they tested?
4. What happens if an external dependency fails (network, disk, API)?
5. Are there race conditions or ordering assumptions?

For each edge case found, state whether it is handled, unhandled, or partially handled.

### Pass 3: Regression Radar

Look at what the change touches and what it does not touch:
1. What existing behavior could this break?
2. What callers or consumers of the changed code exist?
3. Are there implicit contracts (ordering, format, timing) that this change violates?
4. Do existing tests still cover the modified behavior?
5. What integration points are affected?

---

## Adversarial Diff Variant

Use this variant when reviewing security-sensitive or high-risk changes.

Read the diff as an attacker. For each change:
1. Can this be exploited with crafted input?
2. Does this widen the attack surface?
3. Are there TOCTOU (time-of-check-time-of-use) issues?
4. Does this trust data that should be validated?
5. Does this expose internal state or error details?

---

## Repeat Condition

After completing all 3 passes:
- If findings exist: address them, then run passes again on the updated diff.
- Stop after 2 consecutive clean passes (no new findings).
- Hard stop after 4 total pass cycles regardless of findings.

Do not loop indefinitely. Diminishing returns set in quickly.

---

## Findings Format

Classify each finding:

| Severity | Meaning | Action |
|----------|---------|--------|
| **Blocker** | Cannot ship. Correctness or security issue. | Must fix before merge. |
| **Major** | Significant quality or reliability concern. | Should fix before merge. |
| **Minor** | Improvement opportunity. Low risk if skipped. | Fix if time allows. |
| **Structural Follow-up** | Architectural concern beyond this diff's scope. | Track as future work. Do not block merge. |

For each finding:
1. Location (file and line)
2. What you observed
3. Why it matters
4. Suggested resolution (one sentence)
