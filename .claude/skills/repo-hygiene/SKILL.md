---
name: repo-hygiene
description: |
  Detect and clean AI-generated slop from skills directories. Use when: (1) test-skill-*
  directories accumulate from testing, (2) CLAUDE.md has stale skill references,
  (3) placeholder content exists in skills. Provides scan, clean, and CLAUDE.md sync.
category: development
---

# Repo Hygiene

Detect and clean AI-generated slop (test skills, placeholder content) from your project.

## Slop Patterns

| Pattern | Example | Action |
|---------|---------|--------|
| `test-skill-*` | `test-skill-1234567890` | Auto-delete (always safe) |
| Timestamped | `my-skill-1706625000000` | Review before deleting |
| `_temp_*` | `_temp_claude-svelte5-skill` | Review (may need rename) |
| Placeholder content | "NEW content with improvements!" | Delete |

## Detection Guidance
- Scan `.claude/skills/` and `packages/*/.claude/skills/` (with `-r`)
- Check CLAUDE.md for stale references and duplicates
- `test-skill-*` matching `/^test-skill-\d+$/` is always safe to delete
- `_temp_*` is never auto-deleted (review required)

## Workflow
1. Scan for slop patterns
2. Auto-delete `test-skill-*` and placeholder content
3. Review timestamped and `_temp_*` entries
4. Sync CLAUDE.md references

## Safety
- Preview before deleting (dry-run)
- Require explicit confirmation for actual deletion
- Never auto-delete `_temp_*` or timestamped entries

## Anti-Patterns
- Committing test-skill-* directories — always scan before commit
- Leaving stale CLAUDE.md references — sync after any skill change
- Deleting `_temp_*` without checking for valuable content
