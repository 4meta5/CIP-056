# PLAN: CIP-056 Simple Token Implementation

Status: planning-only (no implementation started)

## Goal

Deliver a minimal, secure, readable Canton token-standard implementation in DAML/Haskell that:
- Implements all 6 CIP-056 interface packages as-is (stable ABI)
- Is simpler than Splice's Amulet implementation while preserving required behavior and safety conventions
- Provides an off-ledger registry HTTP service aligned to Splice OpenAPI conventions

## Non-Goals

- Full Splice registry internals (mining rounds, fee schedules, reward coupons, featured apps)
- Multi-tenant auth gateway, high-scale ops hardening, custom compliance engines
- Extension APIs not required for baseline CIP-056 flow (burn/mint, delegation, compliance partitions)
- Feature parity with `ExternalPartyAmuletRules` nonce/deduplication machinery

---

## 1. CIP-056 Interface Specification

### 1.1 Dependency Graph

```
splice-api-token-metadata-v1          (AnyValue, ChoiceContext, Metadata, ExtraArgs)
    |
    v
splice-api-token-holding-v1           (InstrumentId, Lock, Holding, HoldingView)
    |
    +---> splice-api-token-transfer-instruction-v1   (Transfer, TransferFactory, TransferInstruction)
    |
    +---> splice-api-token-allocation-v1             (SettlementInfo, TransferLeg, Allocation)
              |
              +---> splice-api-token-allocation-instruction-v1  (AllocationFactory, AllocationInstruction)
              |
              +---> splice-api-token-allocation-request-v1      (AllocationRequest)
```

Our packages depend on all 6 interface DARs. We implement templates against them; we never modify the interfaces.

### 1.2 Data Types (MetadataV1)

| Type | Fields | Notes |
|---|---|---|
| `AnyValue` | Sum: `AV_Text`, `AV_Int`, `AV_Decimal`, `AV_Bool`, `AV_Date`, `AV_Time`, `AV_RelTime`, `AV_Party`, `AV_ContractId`, `AV_List`, `AV_Map` | Used in `ChoiceContext.values` |
| `AnyContract` | Interface, viewtype `AnyContractView` | Never implemented; use only as `ContractId AnyContract` via `coerceContractId` |
| `AnyContractId` | `= ContractId AnyContract` | Type alias for opaque contract references |
| `ChoiceContext` | `values : TextMap AnyValue` | App-backend-to-choice plumbing; keys are app-internal |
| `Metadata` | `values : TextMap Text` | DNS-prefix keys (k8s convention); keep small |
| `ExtraArgs` | `context : ChoiceContext`, `meta : Metadata` | Passed to every interface choice |
| `ChoiceExecutionMetadata` | `meta : Metadata` | Generic choice result wrapper |

### 1.3 Holding Interface (HoldingV1)

| Type | Fields |
|---|---|
| `InstrumentId` | `admin : Party`, `id : Text` |
| `Lock` | `holders : [Party]`, `expiresAt : Optional Time`, `expiresAfter : Optional RelTime`, `context : Optional Text` |
| `HoldingView` | `owner : Party`, `instrumentId : InstrumentId`, `amount : Decimal`, `lock : Optional Lock`, `meta : Metadata` |

**Interface**: `Holding` — viewtype `HoldingView`, no choices defined on the interface itself.

### 1.4 Transfer Interfaces (TransferInstructionV1)

| Type | Fields |
|---|---|
| `Transfer` | `sender : Party`, `receiver : Party`, `amount : Decimal`, `instrumentId : InstrumentId`, `requestedAt : Time`, `executeBefore : Time`, `inputHoldingCids : [ContractId Holding]`, `meta : Metadata` |
| `TransferInstructionResult` | `output : TransferInstructionResult_Output`, `senderChangeCids : [ContractId Holding]`, `meta : Metadata` |
| `TransferInstructionResult_Output` | `Pending {transferInstructionCid}` \| `Completed {receiverHoldingCids}` \| `Failed` |
| `TransferInstructionStatus` | `TransferPendingReceiverAcceptance` \| `TransferPendingInternalWorkflow {pendingActions : Map Party Text}` |
| `TransferInstructionView` | `originalInstructionCid : Optional (ContractId TransferInstruction)`, `transfer : Transfer`, `status : TransferInstructionStatus`, `meta : Metadata` |
| `TransferFactoryView` | `admin : Party`, `meta : Metadata` |

**Interface `TransferFactory`** (nonconsuming):

| Choice | Args | Controller | Returns |
|---|---|---|---|
| `TransferFactory_Transfer` | `expectedAdmin : Party`, `transfer : Transfer`, `extraArgs : ExtraArgs` | `transfer.sender` | `TransferInstructionResult` |
| `TransferFactory_PublicFetch` | `expectedAdmin : Party`, `actor : Party` | `actor` | `TransferFactoryView` |

**Interface `TransferInstruction`** (consuming):

| Choice | Args | Controller | Returns |
|---|---|---|---|
| `TransferInstruction_Accept` | `extraArgs : ExtraArgs` | `transfer.receiver` | `TransferInstructionResult` |
| `TransferInstruction_Reject` | `extraArgs : ExtraArgs` | `transfer.receiver` | `TransferInstructionResult` |
| `TransferInstruction_Withdraw` | `extraArgs : ExtraArgs` | `transfer.sender` | `TransferInstructionResult` |
| `TransferInstruction_Update` | `extraActors : [Party]`, `extraArgs : ExtraArgs` | `instrumentId.admin, extraActors` | `TransferInstructionResult` |

### 1.5 Allocation Interfaces (AllocationV1)

| Type | Fields |
|---|---|
| `Reference` | `id : Text`, `cid : Optional AnyContractId` |
| `SettlementInfo` | `executor : Party`, `settlementRef : Reference`, `requestedAt : Time`, `allocateBefore : Time`, `settleBefore : Time`, `meta : Metadata` |
| `TransferLeg` | `sender : Party`, `receiver : Party`, `amount : Decimal`, `instrumentId : InstrumentId`, `meta : Metadata` |
| `AllocationSpecification` | `settlement : SettlementInfo`, `transferLegId : Text`, `transferLeg : TransferLeg` |
| `AllocationView` | `allocation : AllocationSpecification`, `holdingCids : [ContractId Holding]`, `meta : Metadata` |
| `Allocation_ExecuteTransferResult` | `senderHoldingCids : [ContractId Holding]`, `receiverHoldingCids : [ContractId Holding]`, `meta : Metadata` |
| `Allocation_CancelResult` | `senderHoldingCids : [ContractId Holding]`, `meta : Metadata` |
| `Allocation_WithdrawResult` | `senderHoldingCids : [ContractId Holding]`, `meta : Metadata` |

**Interface `Allocation`**:

| Choice | Args | Controller | Returns |
|---|---|---|---|
| `Allocation_ExecuteTransfer` | `extraArgs : ExtraArgs` | `[executor, sender, receiver]` | `Allocation_ExecuteTransferResult` |
| `Allocation_Cancel` | `extraArgs : ExtraArgs` | `[executor, sender, receiver]` | `Allocation_CancelResult` |
| `Allocation_Withdraw` | `extraArgs : ExtraArgs` | `transferLeg.sender` | `Allocation_WithdrawResult` |

### 1.6 Allocation Instruction Interfaces (AllocationInstructionV1)

| Type | Fields |
|---|---|
| `AllocationInstructionView` | `originalInstructionCid : Optional (ContractId AllocationInstruction)`, `allocation : AllocationSpecification`, `pendingActions : Map Party Text`, `requestedAt : Time`, `inputHoldingCids : [ContractId Holding]`, `meta : Metadata` |
| `AllocationFactoryView` | `admin : Party`, `meta : Metadata` |
| `AllocationInstructionResult` | `output : AllocationInstructionResult_Output`, `senderChangeCids : [ContractId Holding]`, `meta : Metadata` |
| `AllocationInstructionResult_Output` | `Pending {allocationInstructionCid}` \| `Completed {allocationCid}` \| `Failed` |

**Interface `AllocationFactory`** (nonconsuming):

| Choice | Args | Controller | Returns |
|---|---|---|---|
| `AllocationFactory_Allocate` | `expectedAdmin : Party`, `allocation : AllocationSpecification`, `requestedAt : Time`, `inputHoldingCids : [ContractId Holding]`, `extraArgs : ExtraArgs` | `allocation.transferLeg.sender` | `AllocationInstructionResult` |
| `AllocationFactory_PublicFetch` | `expectedAdmin : Party`, `actor : Party` | `actor` | `AllocationFactoryView` |

**Interface `AllocationInstruction`**:

| Choice | Args | Controller | Returns |
|---|---|---|---|
| `AllocationInstruction_Withdraw` | `extraArgs : ExtraArgs` | `allocation.transferLeg.sender` | `AllocationInstructionResult` |
| `AllocationInstruction_Update` | `extraActors : [Party]`, `extraArgs : ExtraArgs` | `allocation.transferLeg.instrumentId.admin, extraActors` | `AllocationInstructionResult` |

### 1.7 Allocation Request Interface (AllocationRequestV1)

| Type | Fields |
|---|---|
| `AllocationRequestView` | `settlement : SettlementInfo`, `transferLegs : TextMap TransferLeg`, `meta : Metadata` |

**Interface `AllocationRequest`**:

| Choice | Args | Controller | Returns |
|---|---|---|---|
| `AllocationRequest_Reject` | `actor : Party`, `extraArgs : ExtraArgs` | `actor` | `ChoiceExecutionMetadata` |
| `AllocationRequest_Withdraw` | `extraArgs : ExtraArgs` | `settlement.executor` | `ChoiceExecutionMetadata` |

---

## 2. Template Designs

### 2.1 `SimpleHolding` (unlocked holding)

```
template SimpleHolding
  with
    admin : Party
    owner : Party
    instrumentId : InstrumentId
    amount : Decimal
    meta : Metadata
  where
    signatory admin, owner
    ensure amount > 0.0

    interface instance Holding for SimpleHolding where
      view = HoldingView with
        owner
        instrumentId
        amount
        lock = None
        meta
```

- No choices on the template itself; holdings are consumed by factory logic.
- `admin` is the registry operator (equivalent to Splice's `dso`).

### 2.2 `LockedSimpleHolding` (locked holding)

```
template LockedSimpleHolding
  with
    admin : Party
    owner : Party
    instrumentId : InstrumentId
    amount : Decimal
    lock : Lock
    meta : Metadata
  where
    signatory admin, owner, lock.holders
    ensure amount > 0.0

    interface instance Holding for LockedSimpleHolding where
      view = HoldingView with
        owner
        instrumentId
        amount
        lock = Some lock
        meta

    choice LockedSimpleHolding_Unlock : ContractId Holding
      controller owner :: lock.holders
      do toInterfaceContractId <$> create SimpleHolding with
           admin; owner; instrumentId; amount; meta
```

- Lock holders are signatories (matches Splice's `LockedAmulet` pattern).
- `LockedSimpleHolding_Unlock` requires authorization from owner + all holders.
- Holdings with expired locks SHOULD be accepted as transfer inputs (spec requirement).

### 2.3 `SimpleTokenRules` (transfer factory + allocation factory)

```
template SimpleTokenRules
  with
    admin : Party
  where
    signatory admin

    interface instance TransferFactory for SimpleTokenRules where
      view = TransferFactoryView with admin; meta = emptyMetadata
      transferFactory_transferImpl self arg = simpleTransferImpl this self arg
      transferFactory_publicFetchImpl _self arg = do
        requireExpectedAdminMatch arg.expectedAdmin admin
        pure (view $ toInterface @TransferFactory this)

    interface instance AllocationFactory for SimpleTokenRules where
      view = AllocationFactoryView with admin; meta = emptyMetadata
      allocationFactory_allocateImpl self arg = simpleAllocateImpl this self arg
      allocationFactory_publicFetchImpl _self arg = do
        requireExpectedAdminMatch arg.expectedAdmin admin
        pure (view $ toInterface @AllocationFactory this)
```

**`simpleTransferImpl` dispatches 3 transfer modes** (mirroring `amulet_transferFactory_transferImpl`):

1. **Self-transfer** (`sender == receiver`): Consume inputs, create new holding for sender. Returns `Completed`.
2. **Direct transfer** (preapproval present in `ChoiceContext`): Consume inputs, create holding for receiver. Returns `Completed`.
3. **Two-step transfer** (no preapproval, `sender != receiver`): Lock funds into `LockedSimpleHolding`, create `SimpleTransferInstruction`. Returns `Pending`.

**`simpleAllocateImpl`**: Lock funds into `LockedSimpleHolding`, create `SimpleAllocation`. Returns `Completed`.

### 2.4 `SimpleTransferInstruction`

```
template SimpleTransferInstruction
  with
    transfer : Transfer
    lockedHoldingCid : ContractId LockedSimpleHolding
  where
    signatory transfer.instrumentId.admin, transfer.sender
    observer transfer.receiver

    interface instance TransferInstruction for SimpleTransferInstruction where
      view = TransferInstructionView with
        originalInstructionCid = None
        transfer
        status = TransferPendingReceiverAcceptance
        meta = emptyMetadata

      transferInstruction_acceptImpl _self _arg = do
        -- unlock + transfer to receiver
        ...
        pure TransferInstructionResult with
          senderChangeCids = ...
          output = TransferInstructionResult_Completed with receiverHoldingCids = ...
          meta = emptyMetadata

      transferInstruction_rejectImpl _self _arg = do
        -- unlock + return to sender
        ...
        pure TransferInstructionResult with
          senderChangeCids = ...
          output = TransferInstructionResult_Failed
          meta = emptyMetadata

      transferInstruction_withdrawImpl _self _arg = do
        -- unlock + return to sender (same as reject)
        ...

      transferInstruction_updateImpl _self _arg =
        fail "SimpleTransferInstruction: update not supported"
```

- Mirrors `AmuletTransferInstruction`: signatories are `admin + sender`, observer is `receiver`.
- Accept: unlock the locked holding, create new holding owned by receiver.
- Reject/Withdraw: unlock, return to sender. Both return `Failed`.
- Update: not used (no internal workflow steps in our simple model).

### 2.5 `SimpleAllocation`

```
template SimpleAllocation
  with
    allocation : AllocationSpecification
    lockedHoldingCid : ContractId LockedSimpleHolding
  where
    signatory allocationInstrumentAdmin allocation, allocation.transferLeg.sender
    observer allocation.settlement.executor

    interface instance Allocation for SimpleAllocation where
      view = AllocationView with
        allocation
        holdingCids = [toInterfaceContractId lockedHoldingCid]
        meta = emptyMetadata

      allocation_executeTransferImpl _self arg = do
        -- unlock locked holding, create holding for receiver
        ...
        pure Allocation_ExecuteTransferResult with
          senderHoldingCids = changeCids
          receiverHoldingCids = [receiverHoldingCid]
          meta = emptyMetadata

      allocation_cancelImpl _self arg = do
        -- unlock, return to sender
        ...
        pure Allocation_CancelResult with
          senderHoldingCids = ...
          meta = emptyMetadata

      allocation_withdrawImpl _self arg = do
        -- unlock, return to sender
        ...
        pure Allocation_WithdrawResult with
          senderHoldingCids = ...
          meta = emptyMetadata
```

- Mirrors `AmuletAllocation`: signatories are `instrumentId.admin + sender`, observer is `executor`.
- `ExecuteTransfer` controller: `[executor, sender, receiver]` (from `allocationControllers`).
- `Cancel` controller: same triple.
- `Withdraw` controller: sender only.

### 2.6 `SimpleAllocationRequest` (optional test helper)

```
template SimpleAllocationRequest
  with
    settlement : SettlementInfo
    transferLegs : TextMap TransferLeg
    meta : Metadata
  where
    signatory settlement.executor
    observer (map (.sender) $ values transferLegs)

    interface instance AllocationRequest for SimpleAllocationRequest where
      view = AllocationRequestView with settlement; transferLegs; meta

      allocationRequest_RejectImpl _self _arg = do
        pure ChoiceExecutionMetadata with meta = emptyMetadata

      allocationRequest_WithdrawImpl _self _arg = do
        pure ChoiceExecutionMetadata with meta = emptyMetadata
```

- Utility template for testing DvP workflows; not part of core registry.

### 2.7 `TransferPreapproval` (direct transfer authorization)

```
template TransferPreapproval
  with
    admin : Party
    receiver : Party
    instrumentId : InstrumentId
  where
    signatory admin, receiver

    choice TransferPreapproval_Accept : ContractId Holding
      with
        sender : Party
        amount : Decimal
        inputHoldingCids : [ContractId Holding]
        meta : Metadata
      controller sender
      do
        -- Validate and archive input holdings
        -- Create SimpleHolding for receiver with transfer amount
        -- Create change SimpleHolding for sender if needed
        ...
```

- Created by receiver ahead of time to authorize incoming direct transfers.
- Consumed on use (each preapproval is one-time).
- The factory reads the preapproval contract ID from `ChoiceContext` under key `"transfer-preapproval"`.
- Signatories: `admin + receiver`. Controller: `sender` (the party initiating the transfer).
- Lives in `Preapproval.daml`.

---

## 3. Module Structure

```
canton-network-token-standard/
  simple-token/                          -- Production DAR
    daml/
      SimpleToken/
        Holding.daml                     -- SimpleHolding, LockedSimpleHolding
        Rules.daml                       -- SimpleTokenRules, simpleTransferImpl, simpleAllocateImpl
        TransferInstruction.daml         -- SimpleTransferInstruction
        Allocation.daml                  -- SimpleAllocation
        Util.daml                        -- requireExpectedAdminMatch, time validation, holding helpers
        Preapproval.daml                 -- TransferPreapproval
    daml.yaml                            -- depends on all 6 splice-api-token-* DARs

  simple-token-test/                     -- Test DAR (not deployed to production)
    daml/
      SimpleToken/
        Test/
          Setup.daml                     -- setupApp, party allocation, initial holdings
          Transfer.daml                  -- transfer lifecycle tests
          Allocation.daml                -- allocation lifecycle tests
          DvP.daml                       -- multi-leg DvP scenario
          Negative.daml                  -- authorization, contention, deadline failures
          AllocationRequest.daml         -- SimpleAllocationRequest template + tests
    daml.yaml                            -- depends on simple-token

  service/                               -- Off-ledger Haskell HTTP service
    src/
      SimpleToken/
        Api/
          Metadata.hs                    -- GET /registry/metadata/v1/*
          TransferInstruction.hs         -- POST /registry/transfer-instruction/v1/*
          AllocationInstruction.hs       -- POST /registry/allocation-instruction/v1/*
          Allocations.hs                 -- POST /registry/allocations/v1/*
        Disclosure.hs                    -- disclosure assembly, ChoiceContext construction
        Config.hs                        -- registry config, instrument-id, admin party
    app/
      Main.hs
```

---

## 4. Transfer Flows

### 4.1 Self-Transfer (merge/split)

Sender and receiver are the same party. Completes immediately.

1. **Off-ledger**: Wallet fetches `TransferFactory` cid and `ChoiceContext` from registry API.
2. **On-ledger**: Wallet exercises `TransferFactory_Transfer` with `sender == receiver`.
3. **Impl**: `simpleTransferImpl` detects self-transfer:
   - Validates `expectedAdmin` matches `admin`.
   - Validates `amount > 0`, `requestedAt` in past, `executeBefore` in future.
   - Archives all `inputHoldingCids` (MUST archive to preserve contention guarantee).
   - Creates new `SimpleHolding` for sender with requested amount.
   - Creates change `SimpleHolding` if input total > requested amount.
4. **Result**: `TransferInstructionResult_Completed` with `receiverHoldingCids` = [new holding], `senderChangeCids` = [change if any].

### 4.2 Direct Transfer (with preapproval)

Receiver has pre-authorized receipt. Completes immediately.

1. **Off-ledger**: Wallet fetches `TransferFactory` cid. Registry includes preapproval contract id in `ChoiceContext` under a known key.
2. **On-ledger**: Wallet exercises `TransferFactory_Transfer` with preapproval in context.
3. **Impl**: `simpleTransferImpl` detects preapproval in `ChoiceContext`:
   - Validates `expectedAdmin`.
   - Validates transfer fields (amount, times, instrument).
   - Archives all `inputHoldingCids`.
   - Creates `SimpleHolding` for receiver with transfer amount.
   - Creates change `SimpleHolding` for sender.
4. **Result**: `TransferInstructionResult_Completed`.

**MVP simplification**: We implement a `TransferPreapproval` template (admin + receiver signatories) that the receiver creates ahead of time to authorize incoming transfers.

### 4.3 Two-Step Transfer (lock-then-accept)

No preapproval, sender != receiver. Requires receiver acceptance.

1. **Off-ledger**: Wallet fetches `TransferFactory` cid and `ChoiceContext`. No preapproval in context.
2. **On-ledger (step 1)**: Sender exercises `TransferFactory_Transfer`.
3. **Impl step 1**: `simpleTransferImpl` detects two-step path:
   - Validates all fields.
   - Archives all `inputHoldingCids`.
   - Creates `LockedSimpleHolding` with `lock.holders = [admin]`, `lock.expiresAt = Some executeBefore`, `lock.context = Some "transfer to <receiver>"`.
   - Creates `SimpleTransferInstruction` referencing the locked holding.
4. **Result**: `TransferInstructionResult_Pending` with `transferInstructionCid`.
5. **Off-ledger**: Receiver's wallet sees pending `TransferInstruction`. Fetches `ChoiceContext` for accept.
6. **On-ledger (step 2a — accept)**: Receiver exercises `TransferInstruction_Accept`.
   - Validates `executeBefore` not passed.
   - Archives `SimpleTransferInstruction` (consuming).
   - Exercises `LockedSimpleHolding_Unlock` (or directly archives locked holding with admin authority).
   - Creates `SimpleHolding` for receiver.
   - Returns `TransferInstructionResult_Completed`.
7. **On-ledger (step 2b — reject)**: Receiver exercises `TransferInstruction_Reject`.
   - Unlocks holding back to sender.
   - Returns `TransferInstructionResult_Failed`.
8. **On-ledger (step 2c — withdraw)**: Sender exercises `TransferInstruction_Withdraw`.
   - Unlocks holding back to sender.
   - Returns `TransferInstructionResult_Failed`.

**Lock semantics**: The admin is a lock holder so only admin+owner can unlock. This prevents the sender from unilaterally reclaiming funds during the pending window while the instruction exists. After `executeBefore`, expired locks SHOULD be accepted as inputs (spec: "Registries SHOULD allow holdings with expired locks as inputs to transfers").

---

## 5. Allocation / DvP Flow

### 5.1 Allocate

1. **Off-ledger**: App creates `SimpleAllocationRequest` (optional) and provides `AllocationFactory` cid + `ChoiceContext` to sender's wallet.
2. **On-ledger**: Sender exercises `AllocationFactory_Allocate`:
   - `simpleAllocateImpl` validates:
     - `expectedAdmin` matches.
     - `settlement.requestedAt` in past, `settlement.allocateBefore` in future.
     - `settlement.allocateBefore <= settlement.settleBefore`.
     - `transferLeg.amount > 0`.
     - `transferLeg.instrumentId` matches factory admin.
     - `requestedAt` in past.
     - At least one `inputHoldingCid`.
   - Archives all `inputHoldingCids`.
   - Creates `LockedSimpleHolding` (lock holders = [admin], expires at `settleBefore`, context = "allocation for transfer leg...").
   - Creates `SimpleAllocation` referencing the locked holding.
3. **Result**: `AllocationInstructionResult_Completed` with `allocationCid`.

### 5.2 Execute Settlement (DvP)

1. Once all legs have `Allocation` contracts, the executor (+ sender + receiver for each leg) exercises `Allocation_ExecuteTransfer` atomically in a single transaction.
2. Each `SimpleAllocation`:
   - Validates `settlement.settleBefore` not passed.
   - Unlocks locked holding.
   - Creates `SimpleHolding` for receiver.
   - Returns change to sender if applicable.
3. Atomicity: all legs in one transaction on the same synchronizer ensures DvP.

### 5.3 Cancel / Withdraw

- **Cancel** (executor + sender + receiver): Unlocks holdings, returns to sender. Used when settlement is aborted.
- **Withdraw** (sender only): Sender reclaims allocated holdings. SHOULD succeed if `allocateBefore` has not passed (sender can re-allocate).

---

## 6. Fee Model Decision

**Zero fees for MVP.**

Rationale:
- Eliminates fee reserve locking complexity (Splice locks `amount + fees * 4.0` to guard against fee changes between lock and execute).
- Eliminates mining round coupling (`OpenMiningRound`, `ClosedMiningRound`, `exercisePaymentTransfer`).
- Eliminates `ExpiringAmount` with `ratePerRound` and `createdAt` tracking.
- Transfer amount in = transfer amount out. No burn metadata to propagate.
- Change calculation becomes simple subtraction: `changAmount = sum(inputs) - requestedAmount`.

Post-MVP can introduce fees by:
1. Adding a `FeeSchedule` contract the factory fetches.
2. Deducting fees from transfer outputs.
3. Adding fee reserve multiplier to lock amounts.

---

## 7. Simplicity Decisions

| # | Splice Feature | Our Decision | Rationale |
|---|---|---|---|
| 1 | `ExpiringAmount` (holding fees via `ratePerRound`) | Flat `Decimal amount` | Zero fees; no holding decay |
| 2 | `OpenMiningRound` / `ClosedMiningRound` coupling | None | No fee calculation or round-based expiry |
| 3 | `feeReserveMultiplier = 4.0` over-lock | Lock exact amount | Zero fees; no fee drift between lock and execute |
| 4 | `PaymentTransferContext` / `exercisePaymentTransfer` | Direct create/archive | No fee engine indirection |
| 5 | `TransferPreapproval_Send` with `provider`/`beneficiaries` | Simple preapproval contract | No featured app rewards |
| 6 | `FeaturedAppRight` / `FeaturedAppActivityMarker` | Omitted | No reward system |
| 7 | `TransferCommand` with nonce deduplication | Omitted | No external-party delegation model |
| 8 | `TransferCommandCounter` | Omitted | No nonce tracking |
| 9 | `HasCheckedFetch` with `ForDso`/`ForOwner`/`ForRound` | Simple `fetch` + assert admin/owner | No group-id machinery; validate directly |
| 10 | `fetchReferenceData` for mining rounds | Omitted | No rounds to reference |
| 11 | `copyOnlyBurnMeta` propagation | `emptyMetadata` in results | No burns to propagate |

---

## 8. Contention Semantics

The CIP-056 spec mandates: "If [inputHoldingCids are] specified, then the transfer MUST archive all of these holdings, so that the execution of the transfer conflicts with any other transfers using these holdings."

**Implementation**:
- Every factory choice (`TransferFactory_Transfer`, `AllocationFactory_Allocate`) that receives non-empty `inputHoldingCids` MUST archive every listed holding contract.
- Archival is the first mutating action in the choice body, before creating new holdings.
- This means two concurrent transactions referencing the same holding will conflict at the ledger level — exactly one succeeds, the other aborts.
- Clients MUST retry on contention failures (this is normal Canton UTXO behavior).

**Change holdings**: When `sum(inputHoldings) > requestedAmount`, create a change `SimpleHolding` for the sender with the difference. Return it in `senderChangeCids`.

---

## 9. Security Invariants

| # | Invariant | Implementation Point |
|---|---|---|
| 1 | `expectedAdmin` matches actual admin | `TransferFactory_Transfer`, `TransferFactory_PublicFetch`, `AllocationFactory_Allocate`, `AllocationFactory_PublicFetch` — first line of impl |
| 2 | `requestedAt` must be in the past | `simpleTransferImpl`, `simpleAllocateImpl` — validate `requestedAt <= ledgerTime` |
| 3 | `executeBefore` must be in the future | `simpleTransferImpl` — validate `executeBefore > ledgerTime` |
| 4 | `allocateBefore` must be in the future | `simpleAllocateImpl` — validate on entry |
| 5 | `allocateBefore <= settleBefore` | `simpleAllocateImpl` — require ordering |
| 6 | `amount > 0` | Both factory impls — reject non-positive transfers |
| 7 | `instrumentId` matches factory admin | Both factory impls — `instrumentId.admin == admin` |
| 8 | At least one input holding | Both factory impls — `not (null inputHoldingCids)` |
| 9 | All input holdings archived | Both factory impls — archive before creating outputs |
| 10 | Input holdings belong to sender | Fetch and validate `owner == transfer.sender` on each input |
| 11 | Lock holders include admin | `LockedSimpleHolding` created with `lock.holders = [admin]` |
| 12 | Lock expiry matches deadline | `lock.expiresAt = Some executeBefore` (transfer) or `Some settleBefore` (allocation) |
| 13 | Transfer instruction signatories | `signatory transfer.instrumentId.admin, transfer.sender` — receiver is observer only |
| 14 | Allocation signatories | `signatory instrumentId.admin, transferLeg.sender` — executor is observer only |
| 15 | `TransferInstruction_Update` fails | Not supported in simple model; fail with message |

---

## 10. Acceptance Criteria

### Transfer Lifecycle

| # | Criterion | Test Function |
|---|---|---|
| 1 | Self-transfer: sender receives new holding, inputs archived, change returned | `test_selfTransfer` |
| 2 | Direct transfer with preapproval: receiver gets holding, sender gets change | `test_directTransferWithPreapproval` |
| 3 | Two-step transfer: factory returns Pending, creates locked holding + instruction | `test_twoStepTransferPending` |
| 4 | Two-step accept: receiver accepts, gets holding, locked holding archived | `test_twoStepTransferAccept` |
| 5 | Two-step reject: receiver rejects, sender gets holdings back, result is Failed | `test_twoStepTransferReject` |
| 6 | Two-step withdraw: sender withdraws, gets holdings back | `test_twoStepTransferWithdraw` |
| 7 | PublicFetch: returns correct factory view with admin | `test_publicFetch` |

### Allocation / DvP Lifecycle

| # | Criterion | Test Function |
|---|---|---|
| 8 | Allocate: creates allocation with locked holding, returns Completed | `test_allocate` |
| 9 | ExecuteTransfer: receiver gets holding, sender gets change | `test_allocationExecuteTransfer` |
| 10 | Cancel: sender gets holdings back | `test_allocationCancel` |
| 11 | Withdraw: sender reclaims holdings | `test_allocationWithdraw` |
| 12 | Multi-leg DvP: two allocations executed atomically, both receivers get holdings | `test_dvpTwoLegs` |

### Security / Negative Tests

| # | Criterion | Test Function |
|---|---|---|
| 13 | Wrong `expectedAdmin` fails | `test_wrongExpectedAdmin` |
| 14 | `requestedAt` in future fails | `test_futureRequestedAt` |
| 15 | `executeBefore` in past fails | `test_expiredExecuteBefore` |
| 16 | Zero or negative amount fails | `test_nonPositiveAmount` |
| 17 | Wrong `instrumentId` fails | `test_wrongInstrumentId` |
| 18 | Empty `inputHoldingCids` fails | `test_emptyInputHoldings` |
| 19 | Contention: two transfers using same holding — one fails | `test_holdingContention` |
| 20 | Unauthorized accept (non-receiver) fails | `test_unauthorizedAccept` |
| 21 | Accept after `executeBefore` fails | `test_expiredTransferAccept` |

---

## 11. Execution Order

Sequenced by dependency. No time estimates.

### Step 1: Package Skeleton
- Create `simple-token/daml.yaml` with dependencies on all 6 `splice-api-token-*` DARs.
- Create `simple-token-test/daml.yaml` with dependency on `simple-token`.
- Create module files with type signatures only (compiles but not implemented).
- Validate: `daml build` succeeds for both packages.

### Step 2: Holding Templates
- Implement `SimpleHolding` and `LockedSimpleHolding` with `Holding` interface instances.
- Implement `LockedSimpleHolding_Unlock` choice.
- Implement `Util.daml`: `requireExpectedAdminMatch`, time validation helpers.
- Validate: `daml build`, write `test_createHolding` and `test_lockUnlock`.

### Step 3: Transfer Factory (self-transfer path)
- Implement `SimpleTokenRules` template with `TransferFactory` interface instance.
- Implement self-transfer path in `simpleTransferImpl`.
- Validate: `test_selfTransfer`.

### Step 4: Transfer Factory (two-step path)
- Implement `SimpleTransferInstruction` template with `TransferInstruction` interface instance.
- Implement two-step path in `simpleTransferImpl` (lock + create instruction).
- Implement accept/reject/withdraw on `SimpleTransferInstruction`.
- Validate: `test_twoStepTransferPending`, `test_twoStepTransferAccept`, `test_twoStepTransferReject`, `test_twoStepTransferWithdraw`.

### Step 5: Transfer Factory (direct path)
- Implement `TransferPreapproval` template in `Preapproval.daml`.
- Implement direct transfer path in `simpleTransferImpl` (read preapproval from `ChoiceContext`, exercise `TransferPreapproval_Accept`).
- Validate: `test_directTransferWithPreapproval`.

### Step 6: Allocation Factory
- Implement `AllocationFactory` interface instance on `SimpleTokenRules`.
- Implement `SimpleAllocation` template with `Allocation` interface instance.
- Implement `simpleAllocateImpl`.
- Validate: `test_allocate`, `test_allocationExecuteTransfer`, `test_allocationCancel`, `test_allocationWithdraw`.

### Step 7: DvP Scenario
- Implement `SimpleAllocationRequest` (test helper).
- Write multi-leg DvP test.
- Validate: `test_dvpTwoLegs`.

### Step 8: Security / Negative Tests
- Write all negative test cases (criteria 13-21).
- Validate: all `submitMustFail` / `submitMultiMustFail` tests pass.

### Step 9: Off-Ledger Service
- Implement metadata endpoints.
- Implement transfer-instruction factory + choice-context endpoints.
- Implement allocation-instruction factory endpoint.
- Implement allocation choice-context endpoints.
- Implement `ChoiceContext` assembly (including preapproval lookup) and `disclosedContracts` bundling.
- Support `excludeDebugFields` query parameter (default `true`).
- Return 409 Conflict when contracts are in reassignment state between synchronizers.
- Return 404 Not Found when referenced contract IDs don't exist.
- Validate: request/response conformance against OpenAPI spec.

### Step 10: Integration Tests
- End-to-end: fetch factory via API, construct `ChoiceContext`, submit via JSON API, verify ledger state.
- Validate: full workflow passes on LocalNet topology.

---

## 12. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Hidden complexity from synchronizer assignment | Document same-synchronizer prerequisite; test on LocalNet early |
| Disclosure leakage in off-ledger API | Strict disclosure whitelist; `excludeDebugFields` default on |
| UTXO fragmentation degrades UX | Design data model to support later merge utility; defer for MVP |
| Lock holder authorization complexity | Admin is sole lock holder in MVP; simplifies unlock authorization |
| Interface DAR version drift | Pin specific `splice-api-token-*` versions in `daml.yaml`; track CHANGELOG |

---

## 13. Deferred (Post-MVP)

- Burn/mint extension APIs
- Delegation/operator model
- Multi-step allocation instructions (`AllocationInstruction` with `Update` workflow)
- Compliance policy contracts and richer settlement orchestration
- Fee schedule and holding fee decay
- Automatic holding selection (registry-side input picking)
- Merge/defragmentation utilities
- `TransferInstruction_Update` support for internal workflows
- Hold standard extension API
