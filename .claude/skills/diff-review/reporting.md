# Report Generation (Phase 6)

Structured markdown report for security-focused code review.

## Required Sections

### 1. Executive Summary
Severity distribution table, overall risk (CRITICAL/HIGH/MEDIUM/LOW), recommendation (APPROVE/REJECT/CONDITIONAL), key metrics (files analyzed, test gaps, blast radius, regressions).

### 2. What Changed
Commit range, timeline, file summary table (file, +/- lines, risk, blast radius), totals.

### 3. Critical Findings
Per HIGH/CRITICAL issue: file:line, commit, blast radius, test coverage status, description, historical context (git blame), attack scenario (concrete steps), proof of concept, recommendation (specific fix with code).

### 4. Test Coverage Analysis
Coverage percentage, untested changes table (function, risk, impact), risk assessment.

### 5. Blast Radius Analysis
High-impact functions table (function, callers, risk, priority).

### 6. Historical Context
Security-related removals, regression risks, commit message red flags.

### 7. Recommendations
Immediate (blocking), before production (tracking), technical debt (future). Checkboxes for each.

### 8. Analysis Methodology
Strategy used (DEEP/FOCUSED/SURGICAL), files reviewed percentage by risk level, techniques applied, limitations, confidence level.

## Formatting
- Severity indicators with color emoji
- Code blocks with syntax highlighting
- Line references: `file.ext:L123`
- Before/after comparisons for code changes

## Output
Filename: `<PROJECT>_DIFFERENTIAL_REVIEW_<DATE>.md`. Always generate persistent file, not ephemeral chat output.
