# Compound Phase

Document a recently solved problem to compound team knowledge.

## Purpose

Capture problem solutions while context is fresh, creating structured documentation for future reference. Each documented solution makes subsequent occurrences faster to resolve.

## When to Use

After solving a non-trivial problem (not simple typos or obvious errors) that has been verified working.

## Execution

### Phase 1: Research (parallel)

Gather information in parallel:

1. **Context** — Extract problem type, component, symptoms from conversation
2. **Solution** — Identify root cause, investigation steps, working fix with code examples
3. **Related docs** — Search `docs/solutions/` for related documentation
4. **Prevention** — Develop prevention strategies and test cases
5. **Classification** — Determine category and filename

### Phase 2: Assemble and Write

Collect all research results and write a single documentation file:

```
docs/solutions/[category]/[filename].md
```

Categories (auto-detected from problem):
- build-errors/
- test-failures/
- runtime-errors/
- performance-issues/
- database-issues/
- security-issues/
- integration-issues/

### Phase 3: Optional Enhancement

Based on problem type, route to specialized local skills for review:

- Security issues → `diff-review`
- Code quality → `refactor-suggestions`

## Documentation Structure

Each document includes:

- **Problem symptom** — exact error messages, observable behavior
- **Investigation steps** — what was tried and why
- **Root cause** — technical explanation
- **Working solution** — step-by-step fix with code
- **Prevention strategies** — how to avoid in future
- **Cross-references** — links to related docs and issues

## Key Principle

Only one file is written — the final documentation. Research phases return text data to the orchestrator; they do not create files.
