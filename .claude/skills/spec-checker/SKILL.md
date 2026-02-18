---
name: spec-checker
description: >-
  Performs specification-to-code compliance analysis.
  Use when: (1) verifying implementations match their formal specifications,
  (2) auditing smart contracts against whitepapers, (3) checking that code
  behavior aligns with design documents.
category: audit
---

# Spec Compliance Checker

Determine whether a codebase implements exactly what the documentation states. Work must be deterministic, evidence-grounded, traceable, and exhaustive.

## 7-Phase Compliance Workflow

1. **Documentation Discovery** — Identify all spec content (whitepapers, design docs, READMEs, protocol descriptions). Build unified spec corpus.
2. **Format Normalization** — Clean canonical form. Preserve headings, formulas, tables, code, invariants. Remove layout noise.
3. **Spec Intent IR Extraction** — Extract ALL intended behavior into structured records: invariants, preconditions, postconditions, formulas, flows, security requirements, edge cases. Each with source section, confidence score.
4. **Code Behavior IR Extraction** — Line-by-line semantic analysis. Per function: signature, visibility, preconditions, state reads/writes, computations, external calls, postconditions, enforced invariants.
5. **Alignment (Spec-to-Code)** — For each Spec-IR item, locate Code-IR matches. Classify: full_match, partial_match, mismatch, missing_in_code, code_stronger_than_spec, code_weaker_than_spec. Include reasoning and confidence.
6. **Divergence Classification** — Classify misalignments by severity (CRITICAL/HIGH/MEDIUM/LOW). Each finding: evidence links, exploitability reasoning with concrete attack scenarios, recommended remediation.
7. **Final Report** — Executive summary, alignment matrix, divergence findings, missing invariants, incorrect logic, flow mismatches, access control drift, undocumented behavior, remediations, risk assessment.

## Global Rules
- Never infer unspecified behavior — classify as UNDOCUMENTED
- Always cite exact evidence (section/quote from spec, file + line from code)
- Always provide confidence scores (0-1) for all mappings
- Do NOT rely on prior knowledge of known protocols — only use provided materials
- Every claim must quote original text or line numbers. Zero speculation.

## Execution
1. Ask user to identify spec documents and codebase scope
2. Execute all 7 phases sequentially, producing artifacts at each stage
3. Write final report as structured document
4. Highlight CRITICAL and HIGH findings prominently

## Anti-Patterns
- "Spec is clear enough" — ambiguity hides in plain sight; extract to IR and classify
- "Code obviously matches" — obvious matches have subtle divergences; document with evidence
- Low confidence left uninvestigated — investigate until >= 0.8 or classify as AMBIGUOUS
