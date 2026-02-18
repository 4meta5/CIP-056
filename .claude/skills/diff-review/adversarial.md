# Adversarial Vulnerability Analysis (Phase 5)

Apply to all HIGH RISK changes after completing Phase 4 deep context analysis.

## 1. Define Attacker Model
- **WHO:** Unauthenticated user, authenticated user, malicious admin, compromised service, front-runner
- **ACCESS:** Public API only, authenticated role, specific permissions, contract call capabilities
- **WHERE:** Specific endpoints, contract functions, RPC interfaces, external APIs

## 2. Identify Attack Vectors
Per entry point: exact function/endpoint attacker can access, specific API call sequence with parameters, how it reaches vulnerable code, what impact is achieved. Prove: function is public/external, attacker has required permissions, attack path exists.

## 3. Rate Exploitability
- **EASY:** Public APIs, no special privileges, single transaction, common access level
- **MEDIUM:** Multiple steps, elevated but obtainable privileges, specific system state needed
- **HARD:** Admin/owner privileges, rare edge conditions, significant resources required

## 4. Build Exploit Scenario
Concrete step-by-step: attacker starting position, each action with exact call/parameters/expected result, final concrete impact (specific amounts, privileges, data — not "could cause issues").

## 5. Cross-Reference Baseline
Check: Does this violate a system-wide invariant? Break a trust boundary? Bypass a validation pattern? Regress a previous fix?

## Vulnerability Report Template
Per finding: severity, attacker model (WHO/ACCESS/INTERFACE), attack vector steps, exploitability rating with justification, concrete measurable impact, proof of concept code, root cause (file:line), blast radius, baseline violation.

Proceed to [reporting.md](reporting.md) for final report.
