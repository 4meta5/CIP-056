---
name: daml-haskell-best-practices
description: General best practices for building DAML/Haskell systems with simplicity, readability, security, and operational rigor.
Use when: (1) planning or reviewing DAML/Haskell architecture, (2) defining package/module structure and coding conventions,
(3) setting testing and verification strategy, (4) aligning off-ledger APIs and ledger workflows with production-safe patterns.
category: principles
user-invocable: true
---

# DAML/Haskell Best Practices

Use this skill for general DAML/Haskell engineering quality, independent of any single standard.

## Defaults
- Prefer interface-first design and small implementation templates.
- Keep modules focused and explicit; avoid large “god modules”.
- Prioritize deterministic behavior and explicit authorization boundaries.
- Treat off-ledger APIs as part of the security perimeter.

## Repository Structure
- Separate interface/API packages from implementation packages.
- Separate production DARs from test/script DARs.
- Keep integration adapters (HTTP, JSON API clients, streaming consumers) outside core domain modules.

## DAML Modeling Practices
- Model mutable state as consume-and-create workflows, not global mutable maps.
- Use contract keys mainly for lookup ergonomics, not as sole global uniqueness guarantees in distributed topologies.
- Keep signatories minimal; use controllers for action authorization.
- Keep payloads lean and avoid adding observers without a clear visibility reason.
- Make lock/context metadata human-readable and non-sensitive.

## Choice and Workflow Design
- Define clear lifecycle states and explicit transition choices.
- Include deadline/time-window validation on externally initiated workflows.
- Return structured outcome types so clients can reliably branch on `pending/completed/failed`-style outcomes.
- Avoid implicit workflow callbacks; use explicit contracts/steps.

## Off-Ledger Haskell Practices
- Prefer generated clients from OpenAPI/protobuf where available.
- Keep request/response types strict and versioned.
- Validate trust boundaries on all externally supplied IDs and contexts.
- Default to least-disclosure in APIs; include debug fields only when explicitly requested.
- Add basic abuse protections: rate limiting, bounded payloads, redacted logs.

## Testing and Verification
- Use executable scenario tests for workflow semantics.
- Add contention/race tests for conflicting contract consumption.
- Add negative authorization tests for every privileged choice path.
- Add property-style invariants where practical (e.g., conservation rules).
- Keep integration tests close to real command submission paths.

## Operational Readiness
- Treat SDK/network version compatibility as configuration, not hard-coded assumptions.
- Document synchronizer assumptions and failure modes.
- Track API compatibility and schema versioning explicitly.
- Require concise runbooks for deployment, rollback, and incident triage.

## Code Review Checklist
- Is authorization enforced in the language-level controller/signatory model?
- Are deadlines and replay risks addressed?
- Is private data exposure minimized on-ledger and off-ledger?
- Are result shapes and error paths deterministic and parseable by clients?
- Are tests covering happy path, conflict path, and unauthorized path?

## Anti-Patterns
- Large monolithic templates mixing unrelated workflows.
- Overloaded metadata with business-critical logic hidden in ad hoc keys.
- Off-ledger handlers that leak contract internals by default.
- Implicit coupling between unrelated choices/contracts without clear interfaces.
