MODE | MODERATE | AGGRESSIVE
---- | -------- | ----------
DOC_REVIEW | A | B
IMPLEMENT_PLAN | C | D
REVIEW_IMPL | E | F
REFLECT | G | H
REFACTOR_PLAN | I | J

ESCALATE TO AGGRESSIVE IF:
- User requests it
- Scope creep repeats
- Bugs recur systemically
- Local fixes failed

DEFAULTS:
- Moderate strictness
- One prompt per task
- No automatic refactors

TERMINATION:
If context insufficient, request minimum missing input only.
