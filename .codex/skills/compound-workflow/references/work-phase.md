# Work Phase

Execute a plan systematically while maintaining quality.

## Input

A plan file, specification, or todo file.

## Execution

### Phase 1: Quick Start

1. **Read and clarify** — Read the plan completely. Ask clarifying questions now, not after building.
2. **Setup environment** — Create feature branch or use existing one. Never commit to default branch without explicit permission.
3. **Create task list** — Break plan into actionable tasks with dependencies.

### Phase 2: Execute

For each task in priority order:

1. Mark task as in-progress
2. Read referenced files from the plan
3. Look for similar patterns in codebase
4. Implement following existing conventions
5. Write tests for new functionality (route to `tdd`)
6. Run tests after changes
7. Mark task as completed
8. Check off the corresponding item in the plan file
9. Evaluate for incremental commit

**Incremental commits:** Commit when a logical unit is complete and tests pass. Do not commit WIP or partial work.

**Scope discipline:** Route to `rick-rubin` if implementation starts drifting from the plan.

### Phase 3: Quality Check

1. Run full test suite
2. Run linting
3. Verify all tasks completed
4. Verify code follows existing patterns

### Phase 4: Ship

1. Create commit with conventional format
2. Push to remote
3. Create PR with summary, testing notes, and monitoring plan

## Key Principles

- **Start fast** — Clarify once, then execute
- **Plan is guide** — Follow referenced code patterns
- **Test as you go** — Run tests after each change
- **Ship complete** — Do not leave features 80% done
