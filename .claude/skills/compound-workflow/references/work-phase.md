# Work Phase

Execute a plan systematically while maintaining quality.

## Input
A plan file, specification, or todo file.

## Execution

### Phase 1: Quick Start
1. Read the plan completely. Ask clarifying questions now, not after building.
2. Setup: create feature branch or use existing. Never commit to default branch without permission.
3. Break plan into actionable tasks with dependencies.

### Phase 2: Execute
Per task in priority order:
1. Mark in-progress, read referenced files, look for similar codebase patterns
2. Implement following existing conventions
3. Write tests (route to `tdd`)
4. Run tests after changes
5. Mark completed, check off plan item
6. Commit when logical unit complete and tests pass (no WIP commits)

Route to `rick-rubin` if implementation drifts from plan.

### Phase 3: Quality Check
Run full test suite, linting, verify all tasks completed, verify code follows existing patterns.

### Phase 4: Ship
Commit with conventional format, push, create PR with summary/testing notes/monitoring plan.

## Key Principles
- Start fast: clarify once, then execute
- Plan is guide: follow referenced code patterns
- Test as you go: run tests after each change
- Ship complete: do not leave features 80% done
