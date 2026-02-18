# Review Mode Prompts

Use when: code written and ready for review, especially your own work.

## Multi-Pass Review

### Pass 1: First Impressions
Read the diff as a stranger. Note: confusing names, surprising control flow, comments contradicting code, anything requiring re-reading. Do not evaluate correctness yet.

### Pass 2: Edge Cases and Error Paths
Per changed function: unhandled inputs? Empty/null/zero/negative/max values? Error paths tested? External dependency failures? Race conditions or ordering assumptions? Classify each as handled/unhandled/partial.

### Pass 3: Regression Radar
What existing behavior could break? What callers/consumers exist? Implicit contracts violated? Existing tests still cover modified behavior? Integration points affected?

## Adversarial Variant
For security-sensitive changes: Can this be exploited with crafted input? Attack surface widened? TOCTOU issues? Untrusted data trusted? Internal state exposed?

## Repeat Condition
Stop after 2 consecutive clean passes or 4 total cycles. Do not loop indefinitely.

## Findings Classification
- **Blocker** — Cannot ship. Must fix before merge.
- **Major** — Significant concern. Should fix before merge.
- **Minor** — Low risk if skipped. Fix if time allows.
- **Structural Follow-up** — Beyond this diff's scope. Track, do not block.

Per finding: location (file:line), observation, why it matters, suggested resolution (one sentence).
