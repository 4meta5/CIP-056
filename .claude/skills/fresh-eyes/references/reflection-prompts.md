# Reflection Mode Prompts

Use when: bug fixed or incident resolved. Understand why it happened.

## Causal Chain Construction
Build from symptom to root cause. Each link justified with evidence (file:line, commit, log entry).
```
Symptom: [observed]
  <- caused by: [immediate cause] (evidence: ...)
    <- caused by: [deeper cause] (evidence: ...)
      <- caused by: [root cause] (evidence: ...)
```
Minimum 3 links. Mark uncertain links as UNCERTAIN with what evidence would confirm.

## Root vs Symptom Determination
Classify each link: Symptom (fixing leaves underlying problem), Proximate cause (prevents this specific failure), Root cause (prevents entire class of failures). If fix only addressed symptom, note what remains unfixed.

## Tech Debt Signal Extraction
Patterns in the causal chain: repeated area (fragile module), missing validation (undefended boundary), implicit contract (silent breakage), error swallowing (harder diagnosis), coupling (3+ file fix). For each: where in chain, what class of bugs it enables, whether fixing is worth cost.

## Regression Test Guidance
Per root/proximate cause: Does a test exist? If yes, why didn't it catch this? If no, write a test description (not implementation) for this failure. Can it generalize to the failure class? One regression test per proximate cause minimum.
