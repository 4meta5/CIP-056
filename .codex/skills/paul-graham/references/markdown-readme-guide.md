# Markdown and README Guide

## Markdown Basics

- Use ATX headings (`#`, `##`, `###`) in strict hierarchy.
- Do not skip heading levels.
- Use fenced code blocks with language identifiers.
- Keep bullets parallel and concise.
- Prefer relative links for repo-local docs.
- Use descriptive link labels.
- Keep line length readable and sections scannable.

## Readme Order

Recommended section order:

1. Title and one-line value proposition
2. Badges (if public/open-source)
3. Quick start
4. What it does
5. Installation
6. Usage examples
7. Configuration or API (if relevant)
8. Troubleshooting
9. Contributing
10. License

Use a table of contents when README length exceeds roughly 200 lines.

## Readme Quality Checklist

- Title and tagline are clear.
- First runnable example works from copy-paste.
- Quick start can be completed in about 10 minutes.
- Usage examples show expected output where helpful.
- Links are valid.
- Code blocks have language tags.
- Optional long sections use `<details>` when they hurt scanability.
- License section exists.

## CLI Docs Pattern

For command-line tools, include:

- Install instructions (global and local if both matter)
- Command table (`command`, `description`, `example`)
- Common flags (`--help`, `--version`, `--json`)
- Exit codes for scripting
- Environment variables

## Badge Order

When badges are used, order them:

1. Build status
2. Coverage
3. Version
4. License
5. Optional project badges

## Anti-Slop Rules

- Avoid filler intros and generic motivational language.
- Do not repeat the same point in multiple sections.
- Delete placeholders before finalizing.
- Replace vague claims with concrete behavior or examples.
