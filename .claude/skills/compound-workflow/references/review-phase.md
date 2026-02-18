# Review Phase

Verify code quality through multi-angle analysis before merge.

## Input
PR number, branch name, or "latest" for current branch.

## Execution
1. **Setup** — Determine review target, fetch PR metadata, ensure correct branch
2. **Run Reviews** — Route by content type:
   - Security-sensitive changes -> `diff-review`
   - Rust code -> `code-review-rust`
   - TypeScript code -> `code-review-ts`
   - Refactor candidates -> `refactor-suggestions`
3. **Synthesize** — Categorize findings:
   - **P1 Critical** — Blocks merge (security, data corruption, breaking changes)
   - **P2 Important** — Should fix (performance, architecture, reliability)
   - **P3 Nice-to-have** — Enhancements (cleanup, minor improvements)
4. **Report** — Summary with counts per severity. P1 must be addressed before merge.

## Key Principle
Use local review skills for actual review logic. This phase is coordination, not duplication.
