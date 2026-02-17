# Slop Pattern Reference

Detailed reference for slop detection patterns.

## Pattern Categories

### 1. Naming Patterns

#### test-skill-* (High Confidence)

**Regex**: `/^test-skill-\d+$/`

**Examples**:
- `test-skill-1769733125594`
- `test-skill-0`
- `test-skill-999999999999`

**Origin**: Auto-generated during unit/integration testing

**Action**: Delete (safe)

**False Positives**: None expected

#### Timestamped Names (Medium Confidence)

**Regex**: `/-\d{13}$/`

**Examples**:
- `my-skill-1706625000000`
- `backup-1234567890123`

**Origin**: Likely auto-generated with Date.now()

**Action**: Review before deletion

**False Positives**: Version numbers, intentional timestamps

#### _temp_ Prefix (Low Confidence)

**Regex**: `/^_temp_/`

**Examples**:
- `_temp_claude-svelte5-skill`
- `_temp_experiment`

**Origin**: Manual creation for temporary work

**Action**: Review - may contain valuable content

**False Positives**: None, but content may be valuable

### 2. Content Patterns

#### Placeholder Heading

**Regex**: `/^# Test Skill\s*$/m`

**Matches**: `# Test Skill` at start of line with no other text

**Origin**: Default template not customized

**Action**: Delete or rewrite

#### Placeholder Body

**Regex**: `/^NEW content with improvements!$/m`

**Matches**: Exact string as full line

**Origin**: Auto-generated placeholder text

**Action**: Delete

#### Lorem Ipsum (Disabled by default)

**Regex**: `/^Lorem ipsum dolor sit amet/im`

**Note**: Only matches full phrase at line start to avoid false positives in documentation about lorem ipsum.

### 3. Directory Structure Patterns

#### Empty Skills

Skills with only SKILL.md containing < 100 characters of content (excluding frontmatter).

**Action**: Review - may be work in progress

#### Missing SKILL.md

Directories in `.claude/skills/` without SKILL.md.

**Action**: Delete or investigate

## Confidence Levels

| Level | Meaning | Action |
|-------|---------|--------|
| High | Very likely slop | Auto-delete |
| Medium | Probably slop | Review recommended |
| Low | Possibly slop | Manual review required |

## Adding New Patterns

To add detection for new slop patterns:

1. Edit `packages/skills-cli/src/commands/hygiene.ts`
2. Add pattern to `SLOP_PATTERNS` object
3. Add detection logic in `scanForSlop()`
4. Add tests in `hygiene.test.ts`

## Exclusions

The following are NOT considered slop:

- Skills with proper frontmatter and substantial content
- Skills with `category` field set
- Skills referenced in CLAUDE.md that exist
- Skills with `references/` or `docs/` subdirectories
