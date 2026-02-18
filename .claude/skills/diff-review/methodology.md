# Differential Review Methodology

Phases 0-4 of the security-focused code review workflow.

## Pre-Analysis: Baseline Context
Build baseline understanding before analyzing changes. Capture: system-wide invariants, trust boundaries, validation patterns, call graphs for critical functions, state flows, external dependencies. Store baseline context for reference during differential analysis.

## Phase 0: Intake and Triage
1. Extract changes (git diff --stat, git log --oneline, changed file list)
2. Assess codebase size: SMALL (<20 files, deep analysis), MEDIUM (20-200, focused), LARGE (200+, surgical)
3. Risk-score each file: HIGH (auth, crypto, external calls, value transfer, validation removal), MEDIUM (business logic, state changes, new public APIs), LOW (comments, tests, UI, logging)

## Phase 1: Changed Code Analysis
Per changed file:
1. Read both versions (baseline and changed)
2. Analyze each diff region: BEFORE, AFTER, behavioral impact, security implications
3. Git blame removed code — red flags: removed from "fix"/"security"/"CVE" commits (CRITICAL), recently added then removed (HIGH)
4. Check for regressions (code added -> removed for security -> re-added = REGRESSION)
5. Micro-adversarial per change: what attack did removed code prevent? New surface exposed? Logic bypassable? Checks weaker?

## Phase 2: Test Coverage Analysis
- Identify production code changes vs test changes
- For each changed function, search for existing tests
- Risk elevation: new function + no tests -> MEDIUM becomes HIGH; modified validation + unchanged tests -> HIGH

## Phase 3: Blast Radius
- Count callers for each modified function
- Classify: 1-5 LOW, 6-20 MEDIUM, 21-50 HIGH, 50+ CRITICAL
- Priority matrix: HIGH risk + CRITICAL blast = P0 (deep + all deps)

## Phase 4: Deep Context
For each HIGH RISK changed function:
1. Map complete flow: entry conditions, state reads/writes, external calls, return values, side effects
2. Trace internal calls (full call graph)
3. Trace external calls (trust boundaries, reentrancy risks)
4. Identify invariants: what must always/never be true? Maintained after changes?
5. Cross-cutting pattern detection: find validation patterns, check if any removed in diff

Proceed to [adversarial.md](adversarial.md) for HIGH RISK changes.
