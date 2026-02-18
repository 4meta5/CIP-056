# SCOPE: Canton Network Token Standard (CIP-056)

## 1. Mission

This project delivers a minimal, correct DAML/Haskell implementation of the 6 CIP-056 on-ledger interfaces (`splice-api-token-*-v1` version 1.0.0). It proves a non-Splice registry can implement the standard and interoperate with standard-compliant wallets and the existing Splice off-ledger infrastructure. Spec: CIP-0056 Final (2025-03-07, approved 2025-03-31). SDK: 3.4.10, LF target: 2.1.

## 2. In Scope

- 7 on-ledger templates: `SimpleHolding`, `LockedSimpleHolding`, `SimpleTokenRules`, `SimpleTransferInstruction`, `SimpleAllocation`, `TransferPreapproval`, `SimpleAllocationRequest`
- All 6 CIP-056 interfaces implemented: `Holding`, `TransferFactory`, `TransferInstruction`, `AllocationFactory`, `Allocation`, `AllocationRequest`
- 3 transfer paths: self-transfer (merge/split), direct transfer (preapproval), two-step (lock-then-accept)
- DvP allocation and atomic settlement
- Zero-fee model (flat `Decimal`)
- Multi-instrument support via `supportedInstruments`
- 24 security invariants (see PLAN.md section 9)
- 27 tests: 7 transfer + 5 allocation + 2 defrag + 12 negative + 1 positive
- Compatibility with Splice off-ledger APIs (our contracts produce the same interface views and result types the off-ledger service expects)

## 3. Out of Scope

| Feature | Reason | Where It Lives |
|---|---|---|
| Fee engine (`ExpiringAmount`, mining rounds, 4x fee reserve) | Zero-fee model eliminates all fee machinery | Splice `ExternalPartyAmuletRules` |
| `PaymentTransferContext` / `exercisePaymentTransfer` | No fee indirection needed | Splice transfer factory |
| `FeaturedAppRight` / `FeaturedAppActivityMarker` | No reward system | Splice featured apps |
| `TransferCommand` / `TransferCommandCounter` | No delegation model | Splice external-party flows |
| `HasCheckedFetch` machinery | Simple `fetch` + `assertMsg` suffices | Splice group-id framework |
| `BurnMintFactory` | Removed from spec 2025-04-15 | Deferred by CIP-056 |
| `RegistryAppInstall` | Removed from spec 2025-04-15 | Deferred by CIP-056 |
| Off-ledger HTTP service | Already exists in `../splice/token-standard` | Splice off-ledger service |
| CLI tooling | Out of scope for contract project | N/A |
| Multi-tenant auth | Infrastructure concern, not on-ledger | Deployment layer |
| Compliance engines | Extension API, not baseline CIP-056 | Post-MVP |
| Multi-step `AllocationInstruction` | Factory returns `Completed` immediately | Splice multi-step workflow |
| 8+ `TransferInput` variants | Replaced by single `[ContractId Holding]` | Splice type dispatch |

## 4. Differences from Splice

| # | Feature | Splice | This Project | Justification | Spec Compliance |
|---|---|---|---|---|---|
| 1 | Holding amount type | `ExpiringAmount` with `ratePerRound` | Flat `Decimal` | Zero-fee model; no holding decay | Compliant (amount is Decimal in spec) |
| 2 | Transfer input types | 8+ `TransferInput` variants | `[ContractId Holding]` | Single list eliminates type dispatch | Compliant (spec uses `[ContractId Holding]`) |
| 3 | Lock holders | Complex lock holder sets | Admin-only (`[admin]`) | Simplifies unlock authorization | Compliant (spec allows any holders) |
| 4 | `TransferInstruction_Update` | Real multi-step workflow | `fail` stub | Simple registry has no internal workflow | Compliant (choice exists, behavior is registry-specific) |
| 5 | Preapproval mechanism | Complex with `provider`/`beneficiaries` | Simple nonconsuming `TransferPreapproval_Send` | No featured app rewards | Compliant (preapproval is registry-specific) |
| 6 | Transfer creation | Via `PaymentTransferContext` | Direct `create` | No fee engine indirection | Compliant |
| 7 | Fetch validation | `HasCheckedFetch` with `ForDso`/`ForOwner` | `assertMsg` | No group-id machinery | Compliant (validation method is internal) |
| 8 | Burn metadata | `copyOnlyBurnMeta` propagation | `emptyMetadata` | No burns to propagate | Compliant (metadata is registry-specific) |
| 9 | `tx-kind` annotations | `splice.lfdecentralizedtrust.org/tx-kind` | Not implemented | GAP (P2) | Partial (improves wallet interop) |
| 10 | Submission window | ~10min (limited by `OpenMiningRound`) | Full 24h | No round dependency | Compliant (closer to spec intent) |
| 11 | Factory-to-instrument | One factory per instrument | One factory, multiple instruments via `supportedInstruments` | Fewer on-ledger contracts | Compliant (factory structure is internal) |

## 5. CIP-056 Spec Gap Analysis

Features in CIP-056 not fully implemented by either Splice or this project.

| # | Feature | Splice | This Project | Reason | Recommendation |
|---|---|---|---|---|---|
| 1 | Delegates on `TransferInstruction` | N/A | N/A | Removed from spec | None needed |
| 2 | `RegistryAppInstall` | N/A | N/A | Removed from spec 2025-04-15 | None needed |
| 3 | Hold standard extension API | Not in baseline | Not in baseline | No formal interface in CIP-056 | Implement when spec adds interface |
| 4 | Compliance partitions | No formal interface | No formal interface | Outside baseline CIP-056 | Track for future |
| 5 | Full 24h submission delay | Partial (~10min) | Supported | Splice limited by `OpenMiningRound` | Satisfied in this project |
| 6 | `BurnMintFactory` standardization | N/A | N/A | Removed from spec 2025-04-15 | Track for future |
| 7 | CNS integration | Outside CIP-056 | Outside CIP-056 | Separate standard | Implement when CNS stabilizes |
| 8 | `expiresAfter` lock behavior | Both use `expiresAt` only | Both use `expiresAt` only | Spec should clarify relationship | Spec clarification needed |
| 9 | Automatic holding selection | Not implemented | Not implemented | Registry-side input picking | Post-MVP |
| 10 | `expireLockKey` pattern (withdraw/reject after lock expiry) | Done | GAP | Edge case: locked holding archived before instruction exercised | **P0 TODO** |

## 6. Architectural Decisions

Resolved decisions from the design review, matched to implementation.

| Decision | Resolution | Rationale | Review Ref |
|---|---|---|---|
| Expired lock handling | Accept expired, reject unexpired via `archiveAndSumInputs` (invariants #19/#20) | Spec says "Registries SHOULD allow holdings with expired locks as inputs" | Q1 |
| Consuming vs nonconsuming preapproval | Nonconsuming `TransferPreapproval_Send` | Matches Splice/Standard2; better UX (no recreate after each transfer) | Q2 |
| Expired fund cleanup | Sender self-serves via `LockedSimpleHolding_Unlock` (TODO) or uses expired lock as factory input | No automation needed; expired locks accepted as inputs | Q3 |
| Per-input `instrumentId` | Per-input check in `archiveAndSumInputs` (invariant #17) | Defense-in-depth against cross-instrument attacks | Q4 |
| Multi-instrument support | One factory, multiple instruments via `supportedInstruments` list | Fewer on-ledger contracts for multi-token registries | Q5 |
| Off-ledger auth | Out of scope for on-ledger contracts | CIP-056 permits unauthenticated baseline | Q6 |
| Contention retries | Client-side | Standard Canton UTXO behavior; service stays stateless | Q7 |
| DvP testing | `submitMulti` in Daml Script (`test_dvpTwoLegs`) | Proves authorization model; atomicity guaranteed by Canton | Q8 |
| Metadata DNS prefix | `emptyMetadata` for MVP | Placeholder until project domain chosen; no premature commitment | Q9 |
| `TransferInstruction_Update` | `fail` stub | Simple registry has no internal workflow; honest failure message | Q10 |
| Registry pause | Archive factory | Zero-code, effective; re-create factory to resume | Q11 |

## 7. Off-Ledger Compatibility

This project does NOT implement off-ledger APIs. The off-ledger infrastructure in `../splice/token-standard` is the canonical implementation. Our contracts produce interface views and result types that the Splice off-ledger service already understands.

Specifically:
- Our `Holding` views match `HoldingView` (owner, instrumentId, amount, lock, meta).
- Our `TransferFactory`/`TransferInstruction`/`Allocation` implement the same interface choices with the same result types (`TransferInstructionResult`, `AllocationInstructionResult`, etc.).
- Wallets using the Splice off-ledger APIs can exercise choices on our contracts without modification.

The off-ledger service provides `ChoiceContext` (with contract IDs like preapprovals) and `disclosedContracts` (for contracts the wallet cannot see but needs to reference) via OpenAPI-aligned endpoints. Our factory reads preapproval contract IDs from `ChoiceContext` under key `"transfer-preapproval"` following the same convention.

OpenAPI endpoint structure (implemented by Splice off-ledger service):
- Metadata: `GET /registry/metadata/v1/info`, `/instruments`, `/instruments/{instrumentId}`
- Transfer: `POST /registry/transfer-instruction/v1/transfer-factory`, `/{id}/choice-contexts/{accept|reject|withdraw}`
- Allocation: `POST /registry/allocation-instruction/v1/allocation-factory`
- Settlement: `POST /registry/allocations/v1/{id}/choice-contexts/{execute-transfer|withdraw|cancel}`

## 8. Post-MVP

Ordered by priority and dependency.

1. `expireLockKey` pattern for withdraw/reject after lock expiry (P0, medium)
2. `ensure amount > 0.0` on holding templates (P1, small)
3. `LockedSimpleHolding_Unlock` choice for manual lock release (P1, small)
4. `test_publicFetch` dedicated test (P2, small)
5. `tx-kind` metadata annotations (P2, small)
6. Off-ledger HTTP service
7. Integration tests (depends on off-ledger service)
8. Fee schedule introduction
9. Burn/mint extension APIs
10. Delegation/operator model
11. Hold standard extension API

## 9. References

### Primary Sources
- CIP-0056 Final (created 2025-03-07, approved 2025-03-31): canonical standard intent and required APIs
- `../splice/token-standard`: reference implementation of interfaces, OpenAPI specs, and tests
- `../splice/token-standard/CHANGELOG.md`: deltas and compatibility expectations (`expectedAdmin`, `requestedAt`, `supportedApis`, metadata evolution, result type semantics)
- Splice docs for token-standard integration: interface querying, transaction-tree parsing, explicit disclosure, LocalNet testing
- Canton architecture references: extended UTXO model, privacy, determinism, transaction trees

### Secondary Sources
- ERC-20/721/1155/2612/777 references for conceptual mapping
- Daml forum/blog posts on keys, pruning, divulgence, testing, security
- CertIK CIP-56 analysis: https://www.certik.com/resources/blog/cip-56-redefining-token-standards-for-institutional-defi
- Canton Network technical primer: https://www.canton.network/blog/a-technical-primer
- Canton Token Standard guide: https://www.canton.network/blog/what-is-cip-56-a-guide-to-cantons-token-standard
- Canton Network whitepaper: https://www.digitalasset.com/hubfs/Canton/Canton%20Network%20-%20White%20Paper.pdf
