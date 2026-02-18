# CIP-056 Feature Parity Checklist

**Spec**: CIP-0056 Final (created 2025-03-07, approved 2025-03-31)
**Interface packages**: `splice-api-token-*-v1` version 1.0.0 (all 6)
**Scope**: On-ledger DAML only. Off-ledger reuses Splice's existing OpenAPI endpoints.
**Date**: 2026-02-18

## Compared Implementations

| Codebase | Path | Status |
|---|---|---|
| **Splice** | `../splice/token-standard` | Reference implementation. Production-grade. Complex (fees, mining rounds, 8+ input types). |
| **This Project** | `canton-network-token-standard` | Planning-only. 7 templates designed, 15 security invariants, 11 open questions. No code. |
| **Standard2** | `../canton-network-token-standard2` | Experimental. Phase 1 complete (27/27 tests, 7 templates, 20 invariants). Off-ledger not started. |

---

## Legend

**Status**: `DONE` implemented and tested | `PLANNED` designed but no code | `PARTIAL` incomplete implementation | `GAP` not addressed | `N/A` not applicable

**Action**: `BORROW` adopt from Splice | `IMPROVE` Standard2 or novel approach preferred | `KEEP` current plan sufficient | `DECIDE` open question requiring resolution

---

## Summary Scoreboard

| Interface | Items | Splice | This Project | Standard2 |
|---|---|---|---|---|
| Holding (HoldingV1) | 6 | 6 DONE | 5 PLANNED, 1 GAP | 6 DONE |
| Transfer (TransferInstructionV1) | 21 | 20 DONE, 1 PARTIAL | 20 PLANNED, 1 GAP | 21 DONE |
| Allocation (AllocationV1) | 10 | 10 DONE | 10 PLANNED | 10 DONE |
| Allocation Instruction (AllocationInstructionV1) | 8 | 8 DONE | 5 PLANNED, 3 N/A | 5 DONE, 3 N/A |
| Allocation Request (AllocationRequestV1) | 4 | 4 DONE | 4 PLANNED | 4 DONE |
| Metadata (MetadataV1) | 5 | 5 DONE | 5 PLANNED | 4 DONE, 1 PARTIAL |
| Cross-Cutting | 15 | 13 DONE, 1 PARTIAL, 1 N/A | 11 PLANNED, 3 GAP, 1 N/A | 11 DONE, 2 PARTIAL, 1 GAP, 1 N/A |
| **Totals** | **69** | **66 DONE, 2 PARTIAL, 1 N/A** | **60 PLANNED, 5 GAP, 4 N/A** | **61 DONE, 3 PARTIAL, 1 GAP, 4 N/A** |

---

## Section 1: Holding (HoldingV1)

| # | Spec Requirement | Splice | This Project | Standard2 | Action | Notes |
|---|---|---|---|---|---|---|
| H1 | Holding interface implementation | DONE (Amulet, LockedAmulet) | PLANNED (SimpleHolding, LockedSimpleHolding) | DONE | KEEP | Both simple impls use flat Decimal amount vs Splice's ExpiringAmount |
| H2 | `owner` view field | DONE | PLANNED | DONE | KEEP | |
| H3 | `instrumentId` view field | DONE | PLANNED | DONE | KEEP | |
| H4 | `amount` view field | DONE (ExpiringAmount with ratePerRound) | PLANNED (flat Decimal) | DONE (flat Decimal) | KEEP | Zero-fee model eliminates holding fee decay |
| H5 | `lock` view field (Optional Lock with holders, expiresAt, expiresAfter, context) | DONE | PLANNED | DONE | KEEP | Admin-only lock holders in both simple impls |
| H6 | Locked variant with signatory lock holders | DONE (LockedAmulet) | GAP (no `extraObservers`) | DONE (LockedSimpleHolding + `extraObservers`) | IMPROVE | PLAN.md lacks `extraObservers`; required for Daml visibility model. See D1. |

---

## Section 2: Transfer (TransferInstructionV1)

### TransferFactory (T1-T12)

| # | Spec Requirement | Splice | This Project | Standard2 | Action | Notes |
|---|---|---|---|---|---|---|
| T1 | TransferFactory interface implementation | DONE (ExternalPartyAmuletRules) | PLANNED (SimpleTokenRules) | DONE (SimpleTokenRules) | KEEP | |
| T2 | `TransferFactory_Transfer` nonconsuming choice | DONE | PLANNED | DONE | KEEP | Controller: `transfer.sender` |
| T3 | `TransferFactory_PublicFetch` nonconsuming choice | DONE | PLANNED | DONE | KEEP | Returns `TransferFactoryView` with admin + meta |
| T4 | `expectedAdmin` validation | DONE | PLANNED | DONE | KEEP | First line of impl; prevents contract-swap attacks |
| T5 | `requestedAt <= ledgerTime` validation | DONE | PLANNED | DONE | KEEP | Invariant #2 |
| T6 | `executeBefore > ledgerTime` validation | DONE | PLANNED | DONE | KEEP | Invariant #3 |
| T7 | Self-transfer path (sender == receiver) | DONE | PLANNED | DONE | KEEP | Merge/split/defrag mechanism |
| T8 | Direct transfer path (preapproval in ChoiceContext) | DONE (nonconsuming `TransferPreapproval_Send`) | PLANNED (consuming `TransferPreapproval_Accept`) | DONE (nonconsuming `TransferPreapproval_Send`) | DECIDE | See REVIEW.md Q2. Consuming vs nonconsuming preapproval. |
| T9 | Two-step transfer path (lock + instruction) | DONE | PLANNED | DONE | KEEP | Creates LockedSimpleHolding + SimpleTransferInstruction |
| T10 | Expired lock handling (accept expired locks as inputs) | DONE (`holdingToTransferInputs`) | GAP (REVIEW.md Q1 unresolved) | DONE (`archiveAndSumInputs` invariants #19/#20) | IMPROVE | Adopt Standard2's approach: accept expired, reject unexpired |
| T11 | Submission window (requestedAt to executeBefore) | PARTIAL (shorter due to OpenMiningRound dependency) | PLANNED | DONE | KEEP | Splice limited to ~10min; simple impls support full 24h window |
| T12 | Change holdings (`senderChangeCids`) | DONE | PLANNED | DONE | KEEP | `surplus = sum(inputs) - amount` |

### TransferInstruction (TI1-TI9)

| # | Spec Requirement | Splice | This Project | Standard2 | Action | Notes |
|---|---|---|---|---|---|---|
| TI1 | TransferInstruction interface implementation | DONE (AmuletTransferInstruction) | PLANNED (SimpleTransferInstruction) | DONE (SimpleTransferInstruction) | KEEP | |
| TI2 | `TransferInstruction_Accept` consuming choice | DONE | PLANNED | DONE | KEEP | Controller: `transfer.receiver` |
| TI3 | `TransferInstruction_Reject` consuming choice | DONE | PLANNED | DONE | KEEP | Controller: `transfer.receiver` |
| TI4 | `TransferInstruction_Withdraw` consuming choice | DONE | PLANNED | DONE | KEEP | Controller: `transfer.sender` |
| TI5 | `TransferInstruction_Update` consuming choice | DONE (real multi-step workflow) | PLANNED (`fail` stub) | DONE (`fail` stub) | KEEP | Simple registries have no internal workflow steps |
| TI6 | `originalInstructionCid` field | DONE (tracks lineage) | PLANNED (None) | DONE (None) | KEEP | No multi-step evolution in simple registry |
| TI7 | Status reporting (`TransferInstructionStatus`) | DONE (both variants) | PLANNED (`PendingReceiverAcceptance` only) | DONE (`PendingReceiverAcceptance` only) | KEEP | `PendingInternalWorkflow` not needed for simple registry |
| TI8 | Fund return on reject (sender gets holdings back) | DONE (minus fees) | PLANNED (full return) | DONE (full return) | KEEP | Zero fees = full return |
| TI9 | Fund return on withdraw (sender gets holdings back) | DONE (minus fees) | PLANNED (full return) | DONE (full return) | KEEP | Zero fees = full return |

---

## Section 3: Allocation (AllocationV1)

| # | Spec Requirement | Splice | This Project | Standard2 | Action | Notes |
|---|---|---|---|---|---|---|
| A1 | Allocation interface implementation | DONE (AmuletAllocation) | PLANNED (SimpleAllocation) | DONE (SimpleAllocation) | KEEP | |
| A2 | `AllocationView` fields (allocation, holdingCids, meta) | DONE | PLANNED | DONE | KEEP | |
| A3 | `Allocation_ExecuteTransfer` choice | DONE | PLANNED | DONE | KEEP | Unlock + create receiver holding + change |
| A4 | `Allocation_Cancel` choice | DONE | PLANNED | DONE | KEEP | Return all holdings to sender |
| A5 | `Allocation_Withdraw` choice | DONE | PLANNED | DONE | KEEP | Sender reclaims before deadline |
| A6 | `allocationControllers` = [executor, sender, receiver] | DONE | PLANNED | DONE | KEEP | All three parties must authorize Execute/Cancel |
| A7 | `allocateBefore` deadline check | DONE | PLANNED | DONE | KEEP | Invariant #4 |
| A8 | `settleBefore` deadline check | DONE | PLANNED | DONE | KEEP | Invariant #5: `allocateBefore <= settleBefore` |
| A9 | `Allocation_ExecuteTransferResult` (senderHoldingCids, receiverHoldingCids, meta) | DONE | PLANNED | DONE | KEEP | |
| A10 | `Allocation_CancelResult` / `Allocation_WithdrawResult` types | DONE | PLANNED | DONE | KEEP | Both return `senderHoldingCids` |

---

## Section 4: Allocation Instruction (AllocationInstructionV1)

| # | Spec Requirement | Splice | This Project | Standard2 | Action | Notes |
|---|---|---|---|---|---|---|
| AI1 | AllocationFactory interface implementation | DONE | PLANNED (combined in SimpleTokenRules) | DONE (combined in SimpleTokenRules) | KEEP | Single factory template for both Transfer + Allocation |
| AI2 | `AllocationFactory_Allocate` nonconsuming choice | DONE | PLANNED | DONE | KEEP | Controller: `allocation.transferLeg.sender` |
| AI3 | `AllocationFactory_PublicFetch` nonconsuming choice | DONE | PLANNED | DONE | KEEP | Returns `AllocationFactoryView` |
| AI4 | `expectedAdmin` validation on factory | DONE | PLANNED | DONE | KEEP | Invariant #1 (shared with TransferFactory) |
| AI5 | AllocationInstruction interface for multi-step | DONE (full multi-step) | N/A (direct-to-Completed) | N/A (direct-to-Completed) | KEEP | Simple registry skips Pending; returns Completed immediately |
| AI6 | `AllocationInstruction_Withdraw` choice | DONE | N/A | N/A | KEEP | Not needed when allocate returns Completed |
| AI7 | `AllocationInstruction_Update` choice | DONE | N/A | N/A | KEEP | Not needed when allocate returns Completed |
| AI8 | `AllocationInstructionResult` types (Pending/Completed/Failed) | DONE (all 3) | PLANNED (Completed only) | DONE (Completed only) | KEEP | Simple registries only use Completed path |

---

## Section 5: Allocation Request (AllocationRequestV1)

| # | Spec Requirement | Splice | This Project | Standard2 | Action | Notes |
|---|---|---|---|---|---|---|
| AR1 | AllocationRequest interface implementation | DONE | PLANNED (SimpleAllocationRequest) | DONE (SimpleAllocationRequest) | KEEP | Test helper for DvP workflows |
| AR2 | `AllocationRequestView` fields (settlement, transferLegs, meta) | DONE | PLANNED | DONE | KEEP | `transferLegs : TextMap TransferLeg` |
| AR3 | `AllocationRequest_Reject` choice | DONE | PLANNED | DONE | KEEP | Controller: `actor` (any sender of a leg) |
| AR4 | `AllocationRequest_Withdraw` choice | DONE | PLANNED | DONE | KEEP | Controller: `settlement.executor` |

---

## Section 6: Metadata (MetadataV1)

| # | Spec Requirement | Splice | This Project | Standard2 | Action | Notes |
|---|---|---|---|---|---|---|
| M1 | `AnyValue` sum type (11 variants) | DONE | PLANNED | DONE (replicated in ContextUtils.daml) | KEEP | ToAnyValue/FromAnyValue typeclasses copied from Splice's TokenApiUtils |
| M2 | `ChoiceContext` threading to every interface choice | DONE | PLANNED | DONE | KEEP | `transferPreapprovalContextKey = "transfer-preapproval"` |
| M3 | DNS-prefix metadata convention | DONE (`splice.lfdecentralizedtrust.org/`) | PLANNED (placeholder prefix) | PARTIAL (`emptyMetadata` mostly) | DECIDE | See REVIEW.md Q9. Need to pick a project domain prefix. |
| M4 | `ExtraArgs` (context + meta) on every interface choice | DONE | PLANNED | DONE | KEEP | Standard plumbing |
| M5 | `ChoiceExecutionMetadata` result type | DONE | PLANNED | DONE | KEEP | Used by AllocationRequest choices |

---

## Section 7: Cross-Cutting Requirements

| # | Spec Requirement | Splice | This Project | Standard2 | Action | Notes |
|---|---|---|---|---|---|---|
| X1 | Depend on all 6 `splice-api-token-*-v1` interface DARs | DONE (defines them) | PLANNED (data-dependencies in daml.yaml) | DONE (data-dependencies) | KEEP | |
| X2 | Contention semantics (archive all `inputHoldingCids`) | DONE | PLANNED (PLAN.md section 8) | DONE (`archiveAndSumInputs`) | IMPROVE | Std2's `archiveAndSumInputs` is cleaner than Splice's multi-type dispatch |
| X3 | Metadata conventions (DNS-prefix, `TextMap Text`) | DONE | PLANNED | PARTIAL | DECIDE | See REVIEW.md Q9. Placeholder prefix sufficient for MVP. |
| X4 | Global Synchronizer awareness (same-synchronizer atomicity) | DONE (production) | PLANNED (risk #1 in PLAN.md) | PARTIAL (LocalNet only) | KEEP | |
| X5 | Change holdings when `sum(inputs) > amount` | DONE | PLANNED | DONE | KEEP | Simple subtraction (no fee complication) |
| X6 | `amount > 0` validation | DONE | PLANNED (invariant #6) | DONE (invariant #6) | KEEP | |
| X7 | `instrumentId` matching per input holding | DONE (per factory) | PLANNED (factory-level only) | DONE (per-input invariant #17) | IMPROVE | Adopt Std2's per-input check. Defense-in-depth. |
| X8 | BurnMintFactory | N/A (removed from spec 2025-04-15) | N/A (deferred) | N/A (deferred) | N/A | `RegistryAppInstall` also removed |
| X9 | `tx-kind` metadata annotations | DONE (`splice.lfdecentralizedtrust.org/tx-kind`) | GAP | GAP | BORROW | Values: transfer, merge-split, unlock, burn, mint, expire-dust |
| X10 | Lock `context` strings (human-readable) | DONE | PLANNED | DONE ("pending-transfer", "allocation") | KEEP | |
| X11 | `sum(inputs) >= amount` check | DONE (implicit in fee calc) | GAP (not in 15 invariants) | DONE (invariant #18, explicit) | IMPROVE | Explicit check is defense-in-depth. Adopt from Std2. |
| X12 | Expired lock edge cases (withdraw/reject after owner unlock) | DONE (`expireLockKey` context pattern) | GAP (REVIEW.md Q1/Q3 unresolved) | DONE (invariants #19/#20) | BORROW + IMPROVE | Splice's `expireLockKey` for withdraw/reject; Std2's validation for inputs |
| X13 | `inputHoldingCids` archival as first mutation | DONE | PLANNED (PLAN.md section 8) | DONE | KEEP | |
| X14 | TransferPreapproval mechanism | DONE (nonconsuming) | PLANNED (consuming) | DONE (nonconsuming) | DECIDE | REVIEW.md Q2. Nonconsuming (Splice/Std2) vs consuming (PLAN.md). |
| X15 | Multi-instrument support | PARTIAL (one factory per instrument) | PLANNED (one factory, one instrument) | DONE (one factory, multiple instruments) | IMPROVE | Std2: 1 factory with `supportedInstruments` set. Fewer contracts. |

---

## Section 8: Test Coverage Comparison

| Test Category | Splice | This Project | Standard2 | Gap Analysis |
|---|---|---|---|---|
| Self-transfer | Yes | 0 (planned) | 3 (`selfTransfer`, `selfTransferExactAmount`, `merge10Holdings`) | Std2 ahead: exact-amount and 10-holding merge |
| Direct transfer (preapproval) | Yes | 0 (planned) | 1 (`directTransferWithPreapproval`) | |
| Two-step lifecycle (pending/accept/reject/withdraw) | Yes | 0 (planned) | 4 (`pending`, `accept`, `reject`, `withdraw`) | |
| Allocation lifecycle | Yes | 0 (planned) | 4 (`allocate`, `executeTransfer`, `cancel`, `withdraw`) | |
| DvP multi-leg | Yes | 0 (planned) | 1 (`dvpTwoLegs`) | |
| Security / negative | Yes | 0 (planned) | 12 (invariants #1-#20 coverage) | Std2: 5 novel tests (preapproval mismatch, unexpired lock, expired lock, multi-instrument, contention) |
| Defragmentation | Unknown | 0 | 2 (`merge10Holdings`, `multiInstrumentTransfer`) | Novel in Std2 |
| Withdraw after owner unlock | Unknown | 0 | 0 | **GAP in all simple impls** |
| Reject after lock expired | Unknown | 0 | 0 | **GAP in all simple impls** |
| PublicFetch | Yes | 0 (planned) | 0 | **GAP in Std2** |
| Preapproval instrumentId mismatch | Unknown | 0 | 1 (`preapprovalInstrumentIdMismatch`) | Novel in Std2 |

**Test totals**: Splice ~30+ (estimated) | This Project 0 | Standard2 27/27

---

## Section 9: Implementation Deviations

Known deviations discovered in Standard2 that this project must address.

| # | Deviation | PLAN.md Says | Actual (Standard2) | Impact | Action |
|---|---|---|---|---|---|
| D1 | `extraObservers` on `LockedSimpleHolding` | Not mentioned | `extraObservers : [Party]` with `observer extraObservers` | Required for Daml visibility. Receiver must see locked holding to accept/reject. | IMPROVE: Adopt. |
| D2 | Preapproval creates holdings inside choice body | `TransferPreapproval_Accept` validates and returns `()` | `TransferPreapproval_Send` creates receiver + change holdings | Required for authorization. Creating `SimpleHolding with owner = receiver` needs receiver's signatory. | IMPROVE: Adopt. |
| D3 | No separate `Util.daml` | Separate `Util.daml` for helpers | Validation inline in `Rules.daml`; context in `ContextUtils.daml` | Single use-site; separate module adds indirection without reuse. | KEEP: Simpler. |
| D4 | `allocateBefore` / `settleBefore` deadline checks | Implicit in section 5 | Explicit `require` checks before archiving inputs | Must validate deadlines before irreversible archival. | IMPROVE: Adopt explicit checks. |
| D5 | Nonconsuming preapproval | Consuming (one-time use) | Nonconsuming (reusable, like Splice) | Operational friction: consuming forces receiver to recreate after each transfer. | DECIDE: See REVIEW.md Q2. |
| D6 | Multi-instrument factory | One factory, one hardcoded instrument | One factory, `supportedInstruments` set | 1 factory vs N. Fewer on-ledger contracts. | IMPROVE: Adopt if scope permits. |
| D7 | Per-input `instrumentId` check | Factory-level only (`instrumentId.admin == admin`) | Per-input check in `archiveAndSumInputs` (invariant #17) | Defense-in-depth against bugs or multi-instrument scenarios. | IMPROVE: Adopt. |
| D8 | Explicit `sum(inputs) >= amount` | Not in 15 invariants | Invariant #18 after archival | Prevents negative change holdings. Required for correctness. | IMPROVE: Adopt. |

---

## Section 10: Action Items

### P0: Spec Compliance (must fix before implementation)

1. **Add `extraObservers` to `LockedSimpleHolding`** (D1) — Required by Daml visibility model. Without it, receiver cannot exercise Accept/Reject on TransferInstruction.
2. **Move holding creation inside preapproval choice** (D2) — Required by Daml authorization model. Receiver's signatory needed to create `SimpleHolding with owner = receiver`.
3. **Add explicit deadline checks before input archival** (D4) — Must validate `allocateBefore` / `settleBefore` / `executeBefore` before irreversible `archive` calls.
4. **Handle expired lock edge case for withdraw/reject** (X12) — When owner self-unlocks after lock expires, the SimpleTransferInstruction still references the now-archived locked holding. Need Splice's `expireLockKey` pattern or equivalent.

### P1: Defense-in-Depth (strongly recommended)

5. **Add per-input `instrumentId` check** (D7, X7) — Validate each holding's `instrumentId` matches transfer `instrumentId` inside input archival loop. Prevents cross-instrument attacks.
6. **Add explicit `sum(inputs) >= amount` check** (D8, X11) — Validate total input value covers requested amount before creating output holdings. Standard2's invariant #18.
7. **Adopt `archiveAndSumInputs` helper** (X2) — Cleaner than Splice's multi-type dispatch. Handles lock validation (accept expired #19, reject unexpired #20) in one place.
8. **Add lock expiry handling for inputs** (T10) — Accept expired locks, reject unexpired locks. Standard2's invariants #19/#20.

### P2: Open Questions (require decision before implementation)

9. **Consuming vs nonconsuming preapproval** (T8, X14, D5) — PLAN.md: consuming. Splice/Standard2: nonconsuming. Trade-off: operational friction vs authorization exposure. Cross-ref REVIEW.md Q2.
10. **Single vs multi-instrument factory** (X15, D6) — PLAN.md: one factory one instrument. Standard2: one factory multiple instruments. Cross-ref REVIEW.md Q5.
11. **Metadata DNS prefix** (M3, X3) — Need to choose: real domain, placeholder (`canton-token-standard.example.com/`), or `emptyMetadata`. Cross-ref REVIEW.md Q9.
12. **Expired lock cleanup strategy** (X12) — Sender self-serve unlock vs explicit expire choice vs automation. Cross-ref REVIEW.md Q1/Q3.
13. **`TransferInstruction_Update` implementation** — `fail` stub (PLAN.md, Standard2) vs no-op recreation. Cross-ref REVIEW.md Q10.
14. **Registry pause mechanism** — Archive factory (PLAN.md) vs `RegistryConfig` contract vs field flag. Cross-ref REVIEW.md Q11.
15. **Contention retry strategy** — Client-side only (PLAN.md) vs service-level. Cross-ref REVIEW.md Q7. *(Off-ledger; tracked for completeness.)*
16. **Off-ledger auth model** — No auth for MVP (PLAN.md) vs API key vs OAuth. Cross-ref REVIEW.md Q6. *(Off-ledger; tracked for completeness.)*
17. **DvP test strategy** — Daml Script `submitMulti` (PLAN.md) vs LocalNet integration. Cross-ref REVIEW.md Q8. *(Test infrastructure; tracked for completeness.)*

### P3: Test Gaps (implement during test phase)

18. **Withdraw after lock expired** — Sender exercises `TransferInstruction_Withdraw` after `executeBefore` passes and owner has already unlocked via `LockedSimpleHolding_Unlock`. Should handle gracefully.
19. **Reject after lock expired** — Same scenario from receiver side.
20. **`PublicFetch` tests** — Both `TransferFactory_PublicFetch` and `AllocationFactory_PublicFetch`. Standard2 has no coverage.
21. **Preapproval `instrumentId` mismatch** — Standard2 has this (test #22). This project should adopt.
22. **Multi-leg DvP with cancel** — One leg cancels after other leg allocates. Verify partial settlement prevented.

---

## What to BORROW from Splice

1. **`expireLockKey` context pattern** — For handling withdraw/reject when owner already unlocked the locked holding after expiry.
2. **`require` error messages** — Structured, better than `assertMsg` strings. Wallets parse these from transaction trees.
3. **`tx-kind` metadata annotations** (CHANGELOG 2025-04-15) — `splice.lfdecentralizedtrust.org/tx-kind` with values: `transfer`, `merge-split`, `unlock`, `burn`, `mint`, `expire-dust`. Universal transaction history parsing.
4. **Test patterns** — Two-step transfer abort after owner self-unlocks. PublicFetch validation.

## What to IMPROVE (from Standard2)

1. **`archiveAndSumInputs` helper** — Single function for input validation + archival + summing. Cleaner than Splice's multi-type dispatch.
2. **Security invariants #16-#20** — Cross-instrument attack prevention (#16, #17), sufficient funds (#18), expired lock acceptance (#19), unexpired lock rejection (#20).
3. **`extraObservers` on `LockedSimpleHolding`** — Required for Daml visibility model. Receiver/executor must observe locked holdings.
4. **Preapproval creates holdings inside choice body** — Required for Daml authorization model. Receiver's signatory available only inside preapproval choice.
5. **Multi-instrument factory** — 1 factory with `supportedInstruments` vs N factories. Fewer on-ledger contracts.
6. **Explicit `sum(inputs) >= amount` check** — Defense-in-depth. Prevents negative change holdings.

## What to KEEP from This Project's Plan

1. **Zero-fee model** — Eliminates ExpiringAmount, mining rounds, 4x fee reserve, PaymentTransferContext.
2. **Single `[ContractId Holding]` input type** — Eliminates 8+ TransferInput variants and linear pattern matching.
3. **Admin-only lock holders** — Simplifies unlock authorization.
4. **`TransferInstruction_Update` as `fail` stub** — Honest. Simple registries don't need multi-step internal workflows.
5. **No BurnMintFactory for MVP** — Deferred by spec itself (removed 2025-04-15).
6. **No registry pause mechanism for MVP** — Admin archives factory to stop operations.

## Rough Edges in Splice (documented for context)

1. **Fee engine coupling** — ExpiringAmount + OpenMiningRound + PaymentTransferContext permeates all transfer logic.
2. **8+ TransferInput variant types** — Linear pattern matching in factory dispatch.
3. **BoundedSet arithmetic** — 4x fee reserve multiplier for lock amounts.
4. **Nonce-based deduplication** — ExternalPartyAmuletRules. Not required by CIP-056.
5. **Short submission delay** — ~10min vs spec's 24h target, due to OpenMiningRound dependency.
6. **RegistryAppInstall removed** — From spec (2025-04-15). Was difficult to standardize across registries.
