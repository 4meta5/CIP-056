---
name: elon-musk
description: |
  Delete-first refactoring for legacy systems: remove low-value code early,
  then re-add only what data proves necessary.
  Use when: (1) legacy code has obvious bloat/duplication, (2) complexity is
  blocking delivery, (3) the team can run tests, feature flags, and rollback.
category: principles
---

# Elon Musk

Delete-first refactoring. Shrink the system first, then optimize what survives.

## Operating Order
1. Confirm requirement owners and explicit keep-list
2. Delete first (if little is deleted, challenge scope)
3. Simplify the remaining architecture
4. Optimize only measured bottlenecks
5. Automate only after process stability

## Preconditions (all must be true)
- CI is green
- Characterization and contract tests exist for the target area
- Feature flags and rollback path are ready
- Owners for requirements and risk sign off

## Keep vs Delete Heuristic

**Keep:** Public API contracts, safety/regulatory behavior, proven hot paths with measurable value.

**Delete first:** Unused code, duplicate logic, code with no owner, code impossible to test or reason about.

## Git Safety Gates
- Isolated branch: `refactor/<area>-delete-first`
- Recoverable checkpoint (tag or backup branch) before deletion
- Small, reviewable commits with intent-first messages
- No deletion rampage on `main`
- No removal of auth/audit/PII/security controls without review

## Rollback
- Every risky deletion is flag-guarded
- Canary before full rollout
- Rollback steps recorded directly in PR description

## Anti-Patterns
- Deleting without a keep-list — always confirm what stays first
- Optimizing before simplifying — delete first, optimize survivors
- Automating an unstable process — stability before automation
