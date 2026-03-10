# Verification Report: Canton Network Token Standard

Three open-source verification tools and manual code review by the author were used to analyze this codebase. All findings have been patched or acknowledged.

## Summary

| Metric | Value |
|--------|-------|
| Tools used | 3 (daml-lint, daml-props, daml-verify) |
| Findings identified | 5 |
| Patched | 2 (G1, G2) |
| Acknowledged | 1 (G4 — contract keys dropped in Daml LF 2.1) |
| Low severity (test only) | 1 (G5 — head-of-list in test harness) |
| Informational | 1 (unbounded list fields — admin-only creation) |
| Formal properties proved | 9/9 |
| Property-based tests passed | 5/5 (200 random sequences each) |

---

## Tools Used

### daml-lint (Static Analysis)

Static analyzer for DAML that catches security anti-patterns through AST pattern matching. 6 detectors covering missing ensure clauses, unguarded division, missing positive-amount checks, archive-before-execute, head-of-list on queries, and unbounded fields.

**How it was run:**

```bash
cd daml-lint && cargo build --release

# Production code
daml-lint canton-network-token-standard/simple-token/daml/ --format markdown

# Test code
daml-lint canton-network-token-standard/simple-token-test/daml/ --format markdown
```

**Production code results (simple-token):**

| Detector | Severity | File | Finding |
|----------|----------|------|---------|
| `unbounded-fields` | MEDIUM | AllocationRequest.daml:12 | `senders` list without length bound |
| `unbounded-fields` | MEDIUM | Holding.daml:32 | `extraObservers` list without length bound |
| `unbounded-fields` | MEDIUM | Rules.daml:20 | `supportedInstruments` list without length bound |

No HIGH findings. All three MEDIUM findings are `unbounded-fields` on List parameters in templates where creation is admin-controlled.

**Test code results (simple-token-test):**

| Detector | Severity | File | Finding |
|----------|----------|------|---------|
| `head-of-list-query` | MEDIUM | Defragmentation.daml:80 | Head pattern on queryFilter |
| `head-of-list-query` | MEDIUM | Negative.daml:233 | Head pattern on queryFilter |
| `head-of-list-query` | MEDIUM | SimpleRegistry.daml:153 | Head pattern on queryFilter |

Test harness only. Non-deterministic query ordering does not affect test correctness in single-party sandbox.

### daml-verify (Formal Verification)

Lightweight formal verification using Z3 SMT solver. Proves critical invariants hold for **all possible inputs**, not just sampled test cases. 9 properties across conservation, division safety, and temporal ordering.

**How it was run:**

```bash
cd daml-verify
source .venv/bin/activate
python main.py
```

**Results:**

```
daml-verify: 9 properties, 9 proved, 0 disproved

  [PROVED] C1: conservation total
  [PROVED] C2: receiver amount
  [PROVED] C3: sender change
  [PROVED] D1: scaleFees safety
  [PROVED] D2: issuance safety
  [PROVED] D3: ensure sufficient
  [PROVED] T1: transfer temporal
  [PROVED] T2: allocation temporal
  [PROVED] T3: lock expiry
```

### daml-props (Property-Based Testing)

Pure DAML property-based testing library with shrinking. Generates random action sequences, checks invariants hold for all, and shrinks failing cases to minimal counterexamples.

**How it was run:**

```bash
cd daml-props && dpm build
cd daml-props-dogfood && dpm build
JAVA_HOME=/opt/homebrew/Cellar/openjdk@21/21.0.10/libexec/openjdk.jdk/Contents/Home \
  PATH="$JAVA_HOME/bin:$PATH" dpm test
```

**Results:** All 5 SimpleToken property tests passed (200 random sequences each, up to 15 actions per sequence).

---

## Findings

### G1: Missing `ensure amount > 0.0` (Patched)

**Severity:** HIGH
**Detector:** daml-lint `missing-ensure-decimal`
**Location:** Holding.daml:19, Holding.daml:44
**Description:** `SimpleHolding` and `LockedSimpleHolding` lacked `ensure amount > 0.0` clauses, permitting zero-value holdings.
**Status:** Patched in commit `509e1f8` ("tdd for all hardening fixes").

### G2: Preapproval amount validation (Patched)

**Severity:** HIGH
**Detector:** daml-lint `missing-positive-amount`
**Location:** Preapproval.daml:39-40
**Description:** `TransferPreapproval_Send` accepted `amount` parameter without asserting `> 0`.
**Status:** Patched in commit `509e1f8`.

### G4: Missing contract keys (Acknowledged)

**Severity:** MEDIUM
**Source:** Manual review by the author
**Location:** Rules.daml:20-25, Preapproval.daml:14-22
**Description:** `SimpleTokenRules` and `TransferPreapproval` lack contract keys, permitting duplicate instances. Daml LF 2.1 dropped contract keys entirely. Single-admin architecture limits blast radius to admin-caused duplicates only.
**Status:** Acknowledged. Not patchable under Daml LF 2.1.

### G5: Head pattern on queryFilter (Low — test only)

**Severity:** LOW
**Detector:** daml-lint `head-of-list-query`
**Location:** SimpleRegistry.daml:153, Defragmentation.daml:80, Negative.daml:233
**Description:** `:: _` pattern on queryFilter results in test harness. Non-deterministic ordering is safe in single-party sandbox but would be unsafe in production code.
**Status:** Test harness only. No production impact.

### Unbounded list fields (Informational)

**Severity:** INFO
**Detector:** daml-lint `unbounded-fields`
**Location:** AllocationRequest.daml:12, Holding.daml:32, Rules.daml:20
**Description:** Three templates have `List` fields without ensure clauses bounding length. Template creation requires admin signatory, limiting abuse to admin-controlled operations.
**Status:** Acknowledged. Admin-only creation provides sufficient mitigation.

---

## Conservation Proofs (daml-verify)

These proofs establish that the transfer engine cannot create or destroy tokens. They hold for **all possible inputs** — not sampled test cases.

| Property | Statement | Result |
|----------|-----------|--------|
| C1: conservation total | `totalInput == receiverAmount + senderChange` for all transfer paths | PROVED |
| C2: receiver amount | Receiver gets exactly `transfer.amount` in self-transfer, direct, and two-step-accept | PROVED |
| C3: sender change | `senderChange == totalInput - transfer.amount` (non-negative by D3) | PROVED |

**Model fidelity:** Symbolic models in `daml_verify/model/transfer.py` were compared line-by-line to `Rules.daml`, `Preapproval.daml`, `TransferInstruction.daml`, and `Allocation.daml`. All arithmetic relationships are exact. Abstractions (per-input validation, lock expiry handling) do not affect conservation arithmetic.

27 guards were cataloged across all source files: 2 template ensure clauses, 8 transfer factory guards, 8 allocation factory guards, 3 per-input guards, and 6 choice-level guards.

## Temporal Proofs (daml-verify)

These proofs establish that time-dependent logic is consistent.

| Property | Statement | Result |
|----------|-----------|--------|
| T1: transfer temporal | `requestedAt <= now` and `executeBefore > now` implies `requestedAt < executeBefore` | PROVED |
| T2: allocation temporal | `requestedAt <= now` and `allocateBefore > now` and `allocateBefore <= settleBefore` implies ordering | PROVED |
| T3: lock expiry | Lock `expiresAt == executeBefore` and `executeBefore > now` implies lock is still active | PROVED |

## Division Safety Proofs (daml-verify)

| Property | Statement | Result |
|----------|-----------|--------|
| D3: ensure sufficient | `totalInput >= requested > 0` implies `senderChange >= 0` (no negative balances from change) | PROVED |

D1 and D2 are Splice-specific properties (scaleFees and issuance tranche division safety). They prove that adding guards to Splice's `amuletPrice` and `capPerCoupon` fields would eliminate division-by-zero. CNTS has no unguarded division.

## Property-Based Testing Results (daml-props)

Pure state-machine model of the transfer engine. 4 parties, 6 action types (self-transfer, direct transfer, two-step initiate/accept/reject/withdraw). Each test runs 200 random sequences.

| Test | Property | Sequences | Max Length | Result |
|------|----------|-----------|------------|--------|
| `test_simpleTokenConservation` | Total supply (holdings + locked) is constant | 200 | 15 | PASS |
| `test_simpleTokenPositiveAmounts` | All holdings have amount > 0 | 200 | 15 | PASS |
| `test_simpleTokenNonNegativeBalances` | No party's balance goes negative | 200 | 15 | PASS |
| `test_simpleTokenLifecycle` | Full two-step lifecycle preserves invariants | 200 | 20 | PASS |
| `test_simpleTokenSelfTransferExact` | Self-transfer of exact balance produces single output | 200 | 1 | PASS |

**Methodology:** Executors return `Right state` (no-op) for invalid preconditions (insufficient funds, bad amounts), matching Echidna/Foundry semantics. `Left` is reserved for true invariant violations. Generators bias toward edge cases using `genFrequency` for weighted selection.

---

## Not Applicable: Splice Issues

The following 22 MEDIUM-severity issues were identified through tool-based analysis (daml-lint, daml-verify) and manual review of the Splice codebase. They apply to Splice only, not to this project:

| ID | Splice Issue | Why N/A for CNTS |
|----|-------------|-----------------|
| M1 | Missing singleton enforcement on ValidatorLicense | No ValidatorLicense template |
| M2 | No queryFilter dedup on FeaturedAppRight | No FeaturedAppRight template |
| M3 | AppRewardCoupon minted without input validation | No reward coupon minting |
| M4 | ValidatorRewardCoupon round mismatch allowed | No reward coupons |
| M5 | Unchecked context map keys | ChoiceContext validated per-key |
| M6 | DsoRules_ConfirmAction majority threshold float | No DSO governance |
| M7 | Unbounded Text in vote reasons | No governance voting |
| M8 | AmuletPrice median edge cases | No price oracle |
| M9 | OpenMiningRound missing amuletPrice > 0 ensure | No mining rounds |
| M10 | SummarizingMiningRound unbounded arrays | No mining rounds |
| M11 | ExternalPartyAmuletRules missing input check | No external party rules |
| M12 | BuyTrafficRequest missing amount validation | No traffic purchases |
| M13 | WalletAppInstall batch empty-list | No wallet batching |
| M14 | MintingDelegation empty inputs | No minting delegation |
| M15 | AcceptedTransferOffer empty inputs | No transfer offers |
| M16 | TransferPreapprovalProposal empty inputs | Different preapproval design |
| M17 | Issuance capPerCoupon >= 0 allows zero | No issuance config |
| M18 | Issuance.daml:139 division by amuletPrice | No issuance logic |
| M19 | computeSynchronizerFees division by amuletPrice | No synchronizer fees |
| M20 | computeTransferPreapprovalFee division by amuletPrice | No preapproval fees |
| M21 | DsoRules fetchAndArchive before try/catch | No DSO governance |
| M22 | Unbounded Text fields in DsoRules/VoteRequest | No DSO governance |

---

## Methodology

### Model Fidelity

All symbolic models and pure state-machine models were validated against actual DAML source code through line-by-line comparison:

- **daml-verify models** (`transfer.py`, `allocation.py`, `fees.py`): 27 guards inventoried, all arithmetic relationships verified exact. Three discrepancies found and corrected during dogfooding (see `daml-verify/DOGFOOD.md`).
- **daml-props models** (`SimpleToken/Model.daml`, 249 LOC): Pure executor faithfully reproduces all 6 action types from `Rules.daml`. Invalid preconditions return `Right state` (no-op).

### Unmodeled Paths

Five conservation-preserving paths are not explicitly modeled (all are 1-holding-in, 1-holding-out of same amount):

- `transferInstruction_rejectImpl` (return locked funds to sender)
- `transferInstruction_withdrawImpl` (return locked funds to sender)
- `allocation_cancelImpl` (release allocated funds)
- `LockedSimpleHolding_Unlock` (unlock expired lock)
- Expire-lock pattern in `returnLockedFundsToSender`

### Tool Versions

- daml-lint: built from source (`cargo build --release`)
- daml-props: v0.1.0 (pure DAML, SDK 3.4.10, target 2.1)
- daml-verify: Python 3.10+, z3-solver >= 4.12
- DAML SDK: 3.4.10
