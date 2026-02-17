# PLAN: Tightly Scoped MVP for CIP-056 in DAML/Haskell

Status: planning-only (no implementation started)

## Goal
Deliver a minimal, secure, readable Canton token-standard implementation in DAML/Haskell that is:
- CIP-056 aligned.
- Simpler than `../splice/token-standard` while preserving required behavior and safety conventions.
- OpenAPI-first for off-ledger specs/docs.

## Non-Goals (MVP)
- Full feature parity with all Splice registry internals.
- Broad productization concerns (multi-tenant auth gateway, high-scale ops hardening, custom compliance engines).
- Any extension API not required for baseline CIP-056 flow.

## Design Principles
- Keep public ABI stable: implement canonical Splice token-standard interfaces as-is.
- Minimize hidden behavior: explicit workflows over implicit callbacks.
- Default-safe choices: enforce admin expectations, time bounds, and authorization controls.
- Optimize for comprehension: small modules, narrow responsibilities, deterministic result types.
- Security before convenience: explicit disclosure/context handling and contention-aware semantics.

## MVP Scope
### 1) On-Ledger (DAML)
Implement templates that satisfy:
- `Holding`
- `TransferFactory` + `TransferInstruction`
- `AllocationFactory` + `Allocation`
- Optional reference app template implementing `AllocationRequest` for testing workflows

MVP workflow behavior:
- Transfer path: offer-accept default.
- Allocation path: direct allocation creation with completion result shape.
- All result types follow interface expectations (`Pending`, `Completed`, `Failed` where applicable).

### 2) Off-Ledger (Haskell)
Implement registry HTTP service aligned to Splice OpenAPI endpoints:
- metadata v1
- transfer-instruction v1 (factory + choice-contexts)
- allocation-instruction v1 (factory)
- allocations v1 (choice-contexts)

OpenAPI alignment rules:
- Reuse endpoint naming/versioning conventions.
- Preserve `choiceContextData`, `disclosedContracts`, `excludeDebugFields` semantics.
- Return conflict/not-found/error shapes consistently.

### 3) Test Harness
- Daml Script tests for transfer + allocation lifecycle.
- At least one atomic multi-leg DvP scenario.
- Integration checks for off-ledger context/disclosure with JSON API command submission.

## Work Breakdown Structure
## Phase 0: Baseline Decisions (1 day)
- Pin initial SDK/Canton line for local dev only (document as variable for deployment).
- Fix repository package layout and naming.
- Define coding standards and metadata namespace policy.

Deliverables:
- architecture note in repo docs
- package skeleton map

## Phase 1: Interface-First Ledger Model (2-3 days)
- Create minimal templates and views implementing required interfaces.
- Implement lock semantics and deterministic transfer/allocation outcomes.
- Add pause/config checks and strict authorization gates.

Deliverables:
- DAML packages compiling against token-standard interfaces
- documented invariants per choice

## Phase 2: Off-Ledger API Service (2-3 days)
- Implement OpenAPI-compatible handlers for metadata/factory/context endpoints.
- Build disclosure assembly logic with safe filtering.
- Enforce anti-spoof checks and expected admin consistency.

Deliverables:
- Haskell service with endpoint coverage
- request/response conformance tests

## Phase 3: End-to-End Verification (2 days)
- Daml Script scenarios for transfer and DvP.
- Integration flow: fetch factory/context → submit choice with disclosures → verify ledger state.
- Negative tests: stale deadlines, unauthorized actor, duplicate-input contention.

Deliverables:
- executable test suite
- failure-mode matrix

## Phase 4: Hardening and Readability Pass (1-2 days)
- Refactor for module clarity and naming consistency.
- Logging/rate-limiting guardrails on off-ledger service.
- Final doc pass for operators and wallet integrators.

Deliverables:
- concise runbook + API notes
- release-ready MVP checklist

## Architecture Shape (MVP)
- Package A: interfaces/wrappers (no business templates).
- Package B: registry implementation templates and helper logic.
- Package C: test scripts and fixtures.
- Service D: Haskell off-ledger API adapter.

Rationale:
- Mirrors observed SOTA packaging in `../splice` and `../daml-finance`.
- Keeps public interfaces decoupled from implementation churn.

## Security Requirements (Must-Have)
- Validate `expectedAdmin` in factory operations.
- Enforce authorization via interface controller semantics only.
- Validate time windows (`requestedAt` in past, expiry/deadlines in future).
- Enforce input holding consumption when provided to preserve deliberate contention guarantees.
- Keep lock context non-sensitive.
- Never disclose unnecessary contracts or debug fields by default.

## Simplicity Constraints
- No bespoke allowance model.
- No custom event layer beyond transaction-tree parsing conventions.
- Avoid internal multi-step approval machinery unless required by acceptance criteria.
- Prefer explicit linear workflows and small helper functions.

## Acceptance Criteria (MVP Complete)
- Core interfaces implemented and exercisable by wallet-like clients.
- OpenAPI endpoints respond with conformant payloads.
- FOP and DvP happy-path tests pass.
- Contention and authorization negative tests pass.
- Documentation clearly states what is in scope vs deferred.

## Risks and Mitigations
- Risk: hidden complexity from synchronizer assignment.
  - Mitigation: document same-synchronizer prerequisite and test on LocalNet topology early.
- Risk: disclosure leakage in off-ledger API.
  - Mitigation: strict disclosure whitelist and `excludeDebugFields` default behavior.
- Risk: UTXO fragmentation causes poor UX.
  - Mitigation: explicitly defer merge/defrag utilities but design data model to support later addition.

## Deferred Backlog (Post-MVP)
- Burn/mint extension APIs.
- Delegation/operator model.
- Compliance policy contracts and richer settlement orchestration.
- Wallet parser strict-mode tooling enhancements.

## Execution Order
1. Finalize package skeleton and invariants.
2. Implement DAML choices for transfer lifecycle.
3. Implement allocation lifecycle.
4. Implement off-ledger metadata/factory/context APIs.
5. Add full scripted and integration tests.
6. Hardening and docs.
