# Project Agent Notes

## Purpose
This repository currently tracks planning artifacts for implementing the Canton Network Token Standard (CIP-056) in DAML/Haskell.

## Documentation Contract
- `RESEARCH.md` is the consolidated research baseline.
- `PLAN.md` is the implementation plan and source of execution scope.
- Planning-first workflow: do not start implementation work until plan documents are reviewed/approved.

## OpenAPI Convention
Align off-ledger specs/docs with the Splice token-standard OpenAPI approach and endpoint versioning (`/v1/` paths) as the default convention in this codebase.

## Skill Parity Convention
This repo maintains a generic DAML/Haskell best-practices skill for both runtimes:
- Codex skill path: `.codex/skills/daml-haskell-best-practices/SKILL.md`
- Claude skill path: `.claude/skills/daml-haskell-best-practices/SKILL.md`

Both runtime paths should resolve to the same canonical skill content to avoid drift.

## Symlink Convention
`AGENTS.md` should remain a symlink to `CLAUDE.md` so both runtimes consume the same project-level instructions.

## Installed Skills
- @.claude/skills/tdd/SKILL.md
- @.claude/skills/rick-rubin/SKILL.md
- @.claude/skills/elon-musk/SKILL.md
- @.claude/skills/steve-jobs/SKILL.md
- @.claude/skills/fresh-eyes/SKILL.md
- @.claude/skills/repo-hygiene/SKILL.md
- @.claude/skills/paul-graham/SKILL.md
- @.claude/skills/diff-review/SKILL.md
- @.claude/skills/compound-workflow/SKILL.md
- @.claude/skills/spec-checker/SKILL.md
- @.claude/skills/bryan-cantrill/SKILL.md
- @.claude/skills/linus-torvalds/SKILL.md
