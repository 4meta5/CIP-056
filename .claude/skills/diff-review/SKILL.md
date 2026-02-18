---
name: diff-review
description: >-
  Performs security-focused differential review of code changes (PRs, commits, diffs).
  Adapts analysis depth to codebase size, uses git history for context, calculates
  blast radius, checks test coverage, and generates comprehensive markdown reports.
  Use when: (1) reviewing security-sensitive changes, (2) assessing blast radius
  from a diff, (3) producing an evidence-based security review report.
category: audit
---

# Differential Security Review

Security-focused code review for PRs, commits, and diffs.

## Core Principles
1. **Risk-First** — Focus on auth, crypto, value transfer, external calls
2. **Evidence-Based** — Every finding backed by git history, line numbers, attack scenarios
3. **Adaptive** — Scale to codebase size (SMALL <20 files: deep; MEDIUM 20-200: focused; LARGE 200+: surgical)
4. **Honest** — Explicitly state coverage limits and confidence level
5. **Output-Driven** — Always generate a markdown report file

## Risk Level Triggers
- **HIGH:** Auth, crypto, external calls, value transfer, validation removal
- **MEDIUM:** Business logic, state changes, new public APIs
- **LOW:** Comments, tests, UI, logging

## Workflow
```
Phase 0: Triage (classify files by risk, assess codebase size)
Phase 1: Code Analysis (read both versions, git blame removed code, micro-adversarial per change)
Phase 2: Test Coverage (identify gaps, elevate risk for untested changes)
Phase 3: Blast Radius (count callers, classify impact 1-5/6-20/21-50/50+)
Phase 4: Deep Context (map function flows, trace calls, identify invariants for HIGH risk)
Phase 5: Adversarial (attacker modeling, exploit scenarios — see adversarial.md)
Phase 6: Report (structured markdown — see reporting.md)
```

## Reference Files
- **[methodology.md](methodology.md)** — Phases 0-4 detailed workflow
- **[adversarial.md](adversarial.md)** — Phase 5 attacker modeling and exploit scenarios
- **[reporting.md](reporting.md)** — Phase 6 report structure and templates
- **[patterns.md](patterns.md)** — Common vulnerability patterns (reentrancy, access control, overflow, etc.)

## Red Flags (Stop and Investigate)
- Removed code from "security", "CVE", or "fix" commits
- Access control modifiers removed (onlyOwner, internal -> external)
- Validation removed without replacement
- External calls added without checks
- High blast radius (50+ callers) + HIGH risk change

## Quality Checklist
- All changed files analyzed
- Git blame on removed security code
- Blast radius calculated for HIGH risk
- Attack scenarios are concrete, not generic
- Findings reference specific line numbers + commits
- Report file generated

## Anti-Patterns
- Skipping git history analysis — history reveals regressions
- Making generic findings without evidence — cite lines and commits
- Claiming full analysis when time-limited — state coverage honestly
