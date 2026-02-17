# Review Phase

Verify code quality through multi-angle analysis before merge.

## Input

A PR number, branch name, or "latest" to review the current branch.

## Execution

### 1. Setup

- Determine review target (PR, branch, or current)
- Fetch PR metadata if applicable
- Ensure you are on the correct branch

### 2. Run Reviews

Route to local review skills based on content:

| Content Type | Route To |
|-------------|----------|
| Security-sensitive changes | `diff-review` |
| Rust code | `code-review-rust` |
| TypeScript code | `code-review-ts` |
| Modified code for refactor candidates | `refactor-suggestions` |

### 3. Synthesize Findings

Categorize findings by severity:

- **P1 Critical** — blocks merge (security, data corruption, breaking changes)
- **P2 Important** — should fix (performance, architecture, reliability)
- **P3 Nice-to-have** — enhancements (cleanup, minor improvements)

### 4. Report

Present findings summary with counts per severity level. P1 findings must be addressed before merge.

## Key Principle

Use local review skills for the actual review logic. This phase is coordination, not duplication.
