# SCOPE: Canton Network Token Standard (CIP-056)

## 1. Mission

This project delivers a minimal, correct DAML/Haskell implementation of the 6 CIP-056 on-ledger interfaces (`splice-api-token-*-v1` version 1.0.0). It proves a non-Splice registry can implement the standard and interoperate with standard-compliant wallets and the existing Splice off-ledger infrastructure. Spec: CIP-0056 Final (2025-03-07, approved 2025-03-31). SDK: 3.4.10, LF target: 2.1.

## 2. Omitted Feature Analysis

After completing a security audit (AUDIT0.md) of 3 HIGH + 22 MEDIUM issues across three codebases, a pattern emerged: most Splice bugs (15 of 22 MEDIUM issues) were classified NOT APPLICABLE to our simple token implementation because the vulnerable subsystems don't exist in our architecture. This section examines six feature categories omitted from this project and asks whether each is required for a production CIP-056 token registry.

### 2.1 Mining Rounds

**What it is:** A 4-phase temporal state machine (`OpenMiningRound` -> `SummarizingMiningRound` -> `IssuingMiningRound` -> `ClosedMiningRound`) that anchors every transfer, fee calculation, reward issuance, and holding expiry to a discrete round number. 4 templates, 5 lifecycle choices, 49 references in AmuletRules.daml.

**Why Splice needs it:** The DSO has no global clock. Rounds provide a shared temporal reference that multiple SVs can agree on. Fees scale with `amuletPrice` (set per round by SV voting). Holdings decay per round via `ExpiringAmount.ratePerRound`.

**Why we left it out:** CIP-056 uses absolute timestamps (`executeBefore : Time`, `Lock.expiresAt : Optional Time`). The spec says nothing about rounds. Our zero-fee model eliminates holding decay entirely. Flat `Decimal` amounts replace `ExpiringAmount`.

**Critical for production?** No. Rounds solve a coordination problem that only exists with multiple operators and a token whose value fluctuates against a reference currency. A single-admin registry with fixed-price tokens has no use for rounds. If you later need fee scaling, implement it with a simple `feeRate : Decimal` field on the factory, not a round state machine.

**Complexity to add:** ~400 LOC for templates + lifecycle, ~300 LOC integration changes, plus an off-ledger scheduler.

### 2.2 Rewards (Coupons, Featured Apps, Validator Incentives)

**What it is:** 10 templates (`FeaturedAppRight`, `FeaturedAppActivityMarker`, `AppRewardCoupon`, `ValidatorRewardCoupon`, `SvRewardCoupon`, `ValidatorFaucetCoupon`, `UnclaimedReward`, `DevelopmentFundCoupon`, etc.) implementing a multi-party incentive system. Every transfer mints reward coupons; coupons are redeemed for newly-issued tokens during round summarization. ~1,200 LOC across Amulet.daml, ValidatorLicense.daml, and Issuance.daml.

**Why Splice needs it:** Amulet is a network utility token. Validators need compensation for running sequencer nodes. Featured apps need incentives to build on the network. SVs need rewards for governance participation.

**Why we left it out:** CIP-056 is a token standard, not a tokenomics framework. The spec defines transfer and allocation interfaces, not rewards, issuance curves, or beneficiary systems. Our tokens represent value held by a registry admin (like a stablecoin or security token), not network utility tokens that must self-fund infrastructure.

**Critical for production?** No, unless your token's economic model requires on-ledger issuance incentives. Most production token registries (stablecoins, RWA tokens, corporate tokens) have no reward system. The `meta : Metadata` extension point and `beneficiaries : Optional [AppRewardBeneficiary]` field in CIP-056 `Transfer` let you add reward logic without embedding it in the core transfer path.

**Complexity to add:** ~1,500 LOC. Tightly coupled to rounds: every coupon captures a round number, redemption requires the issuing round's rates. You cannot add rewards without also adding rounds.

### 2.3 Governance (Voting, Confirmation, Action Execution)

**What it is:** A multi-party voting system with Byzantine fault tolerance. `VoteRequest` templates are created, SVs vote with `Confirmation` contracts, and when a quorum is reached, `executeActionRequiringConfirmation` dispatches one of 11+ governance action types. Requires `ceil((n + f + 1) / 2)` votes where `f = floor((n - 1) / 3)`. 7 templates, 39+ choices on DsoRules alone, 1,826 LOC.

**Why Splice needs it:** The Splice network is operated by a consortium of Super Validators. No single party can unilaterally change token parameters, add operators, or modify fee schedules.

**Why we left it out:** Our registry has a single admin. The admin creates the factory, sets supported instruments, and can pause the registry by archiving the factory contract. No voting needed because there's only one decision-maker.

**Critical for production?** No, for a single-admin registry. Yes, if you need consortium governance. Most production token registries are operated by a single legal entity (the issuer). Consortium governance is a specific Splice design choice for decentralized network operation, not a token standard requirement. If you need multi-party governance later, it's an orthogonal system that wraps your existing factory with vote-gated admin actions.

**Complexity to add:** ~2,500 LOC. Requires vote state machine, Byzantine threshold calculation, action dispatch, timeout handling, and integration with every admin-gated operation.

### 2.4 Wallet Delegation (Operator Model, Batch Execution)

**What it is:** `WalletAppInstall` grants an operator (wallet app provider) the right to execute transfers, payments, and traffic purchases on behalf of an end-user. `ExecuteBatch` dispatches multiple operations atomically. 8 wallet templates, 17 choices, ~500 LOC.

**Why Splice needs it:** End-users interact with Splice through wallet apps (web/mobile). The wallet app provider needs ledger authorization to submit transactions on the user's behalf.

**Why we left it out:** CIP-056 defines on-ledger interfaces. How users authenticate and submit transactions is an off-ledger concern. The Splice off-ledger service handles wallet-to-ledger communication. Our contracts produce the same interface views, so existing wallets work without modification.

**Critical for production?** No, for the on-ledger contracts. The delegation model is a deployment architecture choice. A production system needs *some* way for users to submit transactions (direct participant access, off-ledger API with JWT auth, simple signing proxy), but none of these require on-ledger delegation templates.

**Complexity to add:** ~800-1,200 LOC for delegation chain, batch dispatch, and operator authorization.

### 2.5 Traffic Purchasing

**What it is:** `BuyTrafficRequest` and `MemberTraffic` templates track how much Canton synchronizer bandwidth each participant has consumed and purchased. Extra traffic is bought at `extraTrafficPrice` ($/MB). 2 templates, 4 choices, ~150 LOC.

**Why Splice needs it:** The Splice network charges participants for synchronizer usage (sequencing, mediating transactions). This is the economic mechanism that funds network operation.

**Why we left it out:** This is Canton infrastructure billing, not token transfer logic. Whether and how participants pay for synchronizer access is a deployment concern. The CIP-056 spec says nothing about synchronizer traffic.

**Critical for production?** No. This is strictly deployment infrastructure. Our tokens can be transferred regardless of how the underlying Canton synchronizer is funded.

**Complexity to add:** ~600-800 LOC. Requires rounds (for pricing) and governance (for fee parameter changes).

### 2.6 Multi-Party SV Sets

**What it is:** The Super Validator system manages a consortium of node operators. Each SV runs CometBFT, sequencer, mediator, and scan nodes. SVs vote on governance actions, receive reward coupons proportional to their weight, and collectively maintain the amulet price via `AmuletPriceVote`. 5+ templates, 20+ choices, ~600 LOC for SV management alone, plus 1,000+ LOC for consensus/synchronizer integration.

**Why Splice needs it:** Splice is a decentralized network. Multiple independent organizations must jointly operate the infrastructure.

**Why we left it out:** Our registry is operated by a single admin party. A single-admin registry is explicitly allowed by CIP-056 (every `InstrumentId` has a single `.admin` field, every `TransferFactoryView` has a single `.admin` field).

**Critical for production?** No, unless you're building a decentralized network. If you later need multi-admin operation, Canton's topology system supports shared parties (multiple participants backing one logical party) without any on-ledger SV machinery.

**Complexity to add:** ~3,000-4,000 LOC. The most complex subsystem. Requires governance (for onboarding votes), rounds (for reward distribution), and dedicated CometBFT node management infrastructure.

### 2.7 Summary

| Feature | Splice LOC | Our LOC | CIP-056 Required | Production Required | Verdict |
|---------|-----------|---------|-------------------|---------------------|---------|
| Mining Rounds | ~700 | 0 | No | No | Correctly omitted |
| Rewards | ~1,200 | 0 | No | No | Correctly omitted |
| Governance | ~1,826 | 0 | No | No (single admin) | Correctly omitted |
| Wallet Delegation | ~500 | 0 | No | No (off-ledger) | Correctly omitted |
| Traffic Purchasing | ~150 | 0 | No | No (infra concern) | Correctly omitted |
| Multi-Party SVs | ~600+ | 0 | No | No (single admin) | Correctly omitted |
| **Total omitted** | **~4,976** | **0** | | | |
| **Core token logic** | **~1,756** | **~800** | **Yes** | **Yes** | **Implemented** |

Every omitted feature is Splice-specific infrastructure, not CIP-056 requirements. Our ~800 LOC implementation passes 36/36 tests and produces interface views compatible with Splice wallets. The audit found that 15 of 22 MEDIUM-severity Splice bugs are NOT APPLICABLE to our codebase precisely because we don't have these subsystems.

## 3. In Scope

- 7 on-ledger templates: `SimpleHolding`, `LockedSimpleHolding`, `SimpleTokenRules`, `SimpleTransferInstruction`, `SimpleAllocation`, `TransferPreapproval`, `SimpleAllocationRequest`
- All 6 CIP-056 interfaces implemented: `Holding`, `TransferFactory`, `TransferInstruction`, `AllocationFactory`, `Allocation`, `AllocationRequest`
- 3 transfer paths: self-transfer (merge/split), direct transfer (preapproval), two-step (lock-then-accept)
- DvP allocation and atomic settlement
- Zero-fee model (flat `Decimal`)
- Multi-instrument support via `supportedInstruments`
- 24 security invariants (see PLAN.md section 9)
- 36 tests: 9 transfer + 5 allocation + 2 defrag + 20 security
- Compatibility with Splice off-ledger APIs (our contracts produce the same interface views and result types the off-ledger service expects)

## 4. Out of Scope

Items not covered by the omitted feature analysis (section 2).

| Feature | Reason | Where It Lives |
|---|---|---|
| `HasCheckedFetch` machinery | Simple `fetch` + `assertMsg` suffices | Splice group-id framework |
| `BurnMintFactory` | Removed from spec 2025-04-15 | Deferred by CIP-056 |
| `RegistryAppInstall` | Removed from spec 2025-04-15 | Deferred by CIP-056 |
| Off-ledger HTTP service | Already exists in `../splice/token-standard` | Splice off-ledger service |
| CLI tooling | Out of scope for contract project | N/A |
| Multi-tenant auth | Infrastructure concern, not on-ledger | Deployment layer |
| Compliance engines | Extension API, not baseline CIP-056 | Post-MVP |
| Multi-step `AllocationInstruction` | Factory returns `Completed` immediately | Splice multi-step workflow |
| 8+ `TransferInput` variants | Replaced by single `[ContractId Holding]` | Splice type dispatch |

## 5. Differences from Splice

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
| 9 | `tx-kind` annotations | `splice.lfdecentralizedtrust.org/tx-kind` | `txKindMeta` on all results | Same DNS-prefixed key | Compliant (wallet interop) |
| 10 | Submission window | ~10min (limited by `OpenMiningRound`) | Full 24h | No round dependency | Compliant (closer to spec intent) |
| 11 | Factory-to-instrument | One factory per instrument | One factory, multiple instruments via `supportedInstruments` | Fewer on-ledger contracts | Compliant (factory structure is internal) |

## 6. CIP-056 Spec Gap Analysis

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
| 10 | `expireLockKey` pattern (withdraw/reject after lock expiry) | Done | ✅ Resolved | Edge case: locked holding archived before instruction exercised | Implemented via `expireLockContextKey` |

## 7. Architectural Decisions

Resolved decisions from the design review, matched to implementation.

| Decision | Resolution | Rationale | Review Ref |
|---|---|---|---|
| Expired lock handling | Accept expired, reject unexpired via `archiveAndSumInputs` (invariants #19/#20) | Spec says "Registries SHOULD allow holdings with expired locks as inputs" | Q1 |
| Consuming vs nonconsuming preapproval | Nonconsuming `TransferPreapproval_Send` | Matches Splice/Standard2; better UX (no recreate after each transfer) | Q2 |
| Expired fund cleanup | Sender self-serves via `LockedSimpleHolding_Unlock` choice or uses expired lock as factory input; expire-lock context pattern for reject/withdraw | No automation needed; expired locks accepted as inputs | Q3 |
| Per-input `instrumentId` | Per-input check in `archiveAndSumInputs` (invariant #17) | Defense-in-depth against cross-instrument attacks | Q4 |
| Multi-instrument support | One factory, multiple instruments via `supportedInstruments` list | Fewer on-ledger contracts for multi-token registries | Q5 |
| Off-ledger auth | Out of scope for on-ledger contracts | CIP-056 permits unauthenticated baseline | Q6 |
| Contention retries | Client-side | Standard Canton UTXO behavior; service stays stateless | Q7 |
| DvP testing | `submitMulti` in Daml Script (`test_dvpTwoLegs`) | Proves authorization model; atomicity guaranteed by Canton | Q8 |
| Metadata DNS prefix | `splice.lfdecentralizedtrust.org/tx-kind` on all results | Splice convention for wallet interop | Q9 |
| `TransferInstruction_Update` | `fail` stub | Simple registry has no internal workflow; honest failure message | Q10 |
| Registry pause | Archive factory | Zero-code, effective; re-create factory to resume | Q11 |

## 8. Off-Ledger Compatibility

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

## 9. Post-MVP

Ordered by priority. Items 1-4 are audit hardening fixes (~50 LOC total, see AUDIT0.md recommendations #28-31).

**P0 - Audit Hardening**
1. ✅ `expireLockKey` pattern for withdraw/reject after lock expiry
2. ✅ `ensure amount > 0.0` on `SimpleHolding` and `LockedSimpleHolding`
3. ✅ `amount > 0.0` check in `TransferPreapproval_Send`
4. ❌ Contract keys — NOT IMPLEMENTABLE on Daml LF 2.1 (Canton 3.x dropped contract key support)

**P1 - Functional Gaps**
5. ✅ `LockedSimpleHolding_Unlock` choice for manual lock release
6. ✅ `test_publicFetch` dedicated test
7. ✅ `tx-kind` metadata annotations

**P2 - Extensions**
8. Off-ledger HTTP service
9. Integration tests (depends on off-ledger service)
10. Fee schedule introduction
11. Burn/mint extension APIs
12. Delegation/operator model
13. Hold standard extension API

## 10. References

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
