# Compound Phase

Document a recently solved problem to compound team knowledge.

## When to Use
After solving a non-trivial problem that has been verified working.

## Execution
1. **Research** (parallel): Extract context/symptoms, identify root cause and working fix, search `docs/solutions/` for related docs, develop prevention strategies, determine category/filename
2. **Assemble and Write**: Single file at `docs/solutions/[category]/[filename].md`
   Categories: build-errors/, test-failures/, runtime-errors/, performance-issues/, database-issues/, security-issues/, integration-issues/
3. **Optional Enhancement**: Security issues -> `diff-review`, code quality -> `refactor-suggestions`

## Documentation Structure
- Problem symptom (exact errors, observable behavior)
- Investigation steps (what was tried and why)
- Root cause (technical explanation)
- Working solution (step-by-step with code)
- Prevention strategies
- Cross-references to related docs/issues

## Key Principle
Only one file is written (the final doc). Research phases return text to the orchestrator, not files.
