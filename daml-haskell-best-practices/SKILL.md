---
name: daml-haskell-best-practices
description: CIP-056 Canton Token Standard implementation patterns for DAML/Haskell. Code patterns extracted from Splice production implementation for building templates, factory choices, transfer/allocation workflows, lock semantics, testing, and off-ledger APIs.
Use when: implementing or reviewing DAML templates, interface instances, factory choices, transfer/allocation workflows, lock semantics, testing, or off-ledger APIs for CIP-056.
category: patterns
user-invocable: true
---

# DAML/Haskell Patterns for CIP-056

Agent-optimized pattern reference. Every section is a discrete pattern with production code.

## Build Tooling: dpm (not daml)

**CRITICAL**: Use `dpm` (Digital Asset Package Manager) for all CLI operations. The `daml` assistant is deprecated and must not be used.

| Task | Command |
|---|---|
| Build a package | `dpm build` (run from package directory containing `daml.yaml`) |
| Run tests | `dpm test` |
| Clean build artifacts | `dpm clean` |
| Run sandbox | `dpm sandbox` |
| Run a Daml script | `dpm script` |

The `dpm` binary is at `~/.dpm/bin/dpm`. It is a drop-in replacement — same subcommands, same flags.

`dpm test` requires Java on PATH. If `java` is not found, set JAVA_HOME:
```
JAVA_HOME=/opt/homebrew/Cellar/openjdk@21/21.0.10/libexec/openjdk.jdk/Contents/Home PATH="$JAVA_HOME/bin:$PATH" dpm test
```

## When to Reference This Skill

- Implementing a new DAML template or choice: Template Structure, Controller Patterns, Signatory table
- Implementing transfer logic: Transfer Factory 3-Way Dispatch, Two-Step Transfer, Consume-and-Create
- Implementing allocation/DvP: Allocation / DvP, Lock Semantics
- Writing tests: Testing Patterns, submitMulti
- Building off-ledger APIs: Off-Ledger API Patterns
- Debugging authorization errors: Signatory / Observer Patterns, Controller Patterns, submitMulti, Common Errors
- For full implementation plan: see PLAN.md (this skill is patterns only, not execution steps)
- For interface type signatures: see PLAN.md sections 1.2-1.7

## Quick Reference

| Need | Section |
|---|---|
| Template naming conventions | Template Structure |
| Interface view + `*Impl` pattern | Interface Implementation |
| Factory security check | expectedAdmin Validation |
| All 15 security checks | Validation Utilities |
| Archiving/creating holdings | Consume-and-Create |
| Passing app context to choices | ExtraArgs / ChoiceContext |
| Locking funds for pending ops | Lock Semantics |
| Transfer pending/accept/reject | Two-Step Transfer |
| Self/direct/two-step routing | Transfer Factory 3-Way Dispatch |
| Preapproval for direct transfer | TransferPreapproval |
| Time checks on factory entry | Time Validation |
| Who can exercise what | Controller Patterns |
| Double-spend prevention | Contention via inputHoldingCids |
| DvP settlement | Allocation / DvP |
| Multi-step allocation (future) | AllocationInstruction Patterns |
| Who signs, who observes | Signatory / Observer Patterns |
| Interface contract ID casts | Contract ID Coercion |
| Multi-party test submission | submitMulti Pattern |
| Common runtime errors | Common Errors |
| Which DAR provides which type | Interface DAR Dependencies |
| Where to put code | Module Structure |

## Interface DAR Dependencies

| DAR | Key Exports |
|---|---|
| `splice-api-token-metadata-v1` | `AnyValue`, `ChoiceContext`, `Metadata`, `ExtraArgs`, `ChoiceExecutionMetadata` |
| `splice-api-token-holding-v1` | `InstrumentId`, `Lock`, `Holding`, `HoldingView` |
| `splice-api-token-transfer-instruction-v1` | `Transfer`, `TransferFactory`, `TransferInstruction`, `TransferInstructionResult`, `TransferFactoryView` |
| `splice-api-token-allocation-v1` | `SettlementInfo`, `TransferLeg`, `AllocationSpecification`, `Allocation`, result types |
| `splice-api-token-allocation-instruction-v1` | `AllocationFactory`, `AllocationInstruction`, `AllocationInstructionResult`, `AllocationFactoryView` |
| `splice-api-token-allocation-request-v1` | `AllocationRequest`, `AllocationRequestView` |

Import pattern:

```daml
import Splice.Api.Token.MetadataV1
import Splice.Api.Token.HoldingV1
import Splice.Api.Token.TransferInstructionV1
import Splice.Api.Token.AllocationV1
import Splice.Api.Token.AllocationInstructionV1
import Splice.Api.Token.AllocationRequestV1
```

## Module Structure

Code lives in `simple-token/daml/SimpleToken/`. See PLAN.md section 3 for full tree.

| File | Contents |
|---|---|
| `Holding.daml` | `SimpleHolding`, `LockedSimpleHolding` |
| `Rules.daml` | `SimpleTokenRules`, `simpleTransferImpl`, `simpleAllocateImpl` |
| `TransferInstruction.daml` | `SimpleTransferInstruction` |
| `Allocation.daml` | `SimpleAllocation` |
| `Util.daml` | `requireExpectedAdminMatch`, time validators, holding helpers |
| `Preapproval.daml` | `TransferPreapproval` |

Tests live in `simple-token-test/daml/SimpleToken/Test/`. Off-ledger service lives in `service/src/SimpleToken/Api/`.

## Core Definitions

These are used throughout all patterns. They come from `splice-api-token-metadata-v1` but are shown here because they appear in every code example.

```daml
emptyMetadata : Metadata
emptyMetadata = Metadata with values = TextMap.empty

emptyChoiceContext : ChoiceContext
emptyChoiceContext = ChoiceContext with values = TextMap.empty
```

---

## General DAML Conventions

### Template Structure

PascalCase templates. Choice naming: `Template_ChoiceName`. Define result types before the template that uses them.

```daml
data MyTemplate_DoThingResult = MyTemplate_DoThingResult
  with
    outputCid : ContractId SomeContract
    meta : Metadata
  deriving (Show, Eq)

template MyTemplate
  with
    admin : Party
    owner : Party
    amount : Decimal
  where
    signatory admin, owner
    ensure amount > 0.0

    choice MyTemplate_DoThing : MyTemplate_DoThingResult
      with
        actor : Party
      controller actor
      do ...
```

Keep templates small. One template per lifecycle concept (holding, locked holding, transfer instruction, allocation).

### Interface Implementation

Pattern: `interface instance I for T where view = ... ; choiceImpl = ...`

Thin delegation — the `*Impl` function lives outside the interface instance block so it can be shared or tested independently.

```daml
-- from Splice: ExternalPartyAmuletRules.daml
interface instance TransferFactory for ExternalPartyAmuletRules where
  view = TransferFactoryView with
    admin = dso
    meta = emptyMetadata

  transferFactory_transferImpl self arg = amulet_transferFactory_transferImpl this self arg
  transferFactory_publicFetchImpl _self arg = do
    requireExpectedAdminMatch arg.expectedAdmin dso
    pure (view $ toInterface @TransferFactory this)
```

The `this` keyword refers to the template record. The `self` argument is `ContractId Interface`. Use `_self` when unused.

### Contract ID Coercion

DAML interfaces use typed contract IDs. Coerce between template and interface levels:

```daml
-- Upcast: template ContractId -> interface ContractId
let holdingCid : ContractId Holding = toInterfaceContractId @Holding simpleHoldingCid

-- Downcast: interface ContractId -> template ContractId
-- UNSAFE — use only when you know the concrete type
let simpleHoldingCid : ContractId SimpleHolding = fromInterfaceContractId holdingCid

-- Safe downcast: fetch the interface, then pattern match
holding <- fetch holdingCid  -- fetches as Holding interface
case fromInterface @SimpleHolding holding of
  Some simpleHolding -> ...  -- got the concrete template
  None -> ...                -- it's a different template (e.g., LockedSimpleHolding)
```

Use `toInterfaceContractId` when returning holdings from choices (all results use `[ContractId Holding]`). Use `fromInterfaceContractId` only when you're certain of the concrete type.

### Controller Patterns

**View-based**: Controller derives from the interface view.

```daml
-- TransferInstruction_Accept: controlled by receiver
controller (view this).transfer.receiver

-- TransferInstruction_Withdraw: controlled by sender
controller (view this).transfer.sender
```

**Multi-party**: Allocation choices require the triple.

```daml
-- Allocation_ExecuteTransfer, Allocation_Cancel
controller allocationControllers (view this)
-- where allocationControllers v = [v.allocation.settlement.executor, v.allocation.transferLeg.sender, v.allocation.transferLeg.receiver]
```

**Admin + extraActors**: For registry-internal updates.

```daml
-- TransferInstruction_Update
controller (view this).transfer.instrumentId.admin, extraActors
```

### Result Type Patterns

All factory/instruction results follow the same shape:

```daml
-- Transfer results
data TransferInstructionResult_Output
  = TransferInstructionResult_Pending   { transferInstructionCid : ContractId TransferInstruction }
  | TransferInstructionResult_Completed { receiverHoldingCids : [ContractId Holding] }
  | TransferInstructionResult_Failed

-- Allocation results
data AllocationInstructionResult_Output
  = AllocationInstructionResult_Pending   { allocationInstructionCid : ContractId AllocationInstruction }
  | AllocationInstructionResult_Completed { allocationCid : ContractId Allocation }
  | AllocationInstructionResult_Failed
```

Both include `senderChangeCids : [ContractId Holding]` and `meta : Metadata` alongside the output.

---

## CIP-056 Patterns

### expectedAdmin Validation

Every factory choice MUST validate `expectedAdmin` as its first action. This prevents contract-swap attacks where a malicious party substitutes a factory contract under a different admin.

```daml
requireExpectedAdminMatch : Party -> Party -> Update ()
requireExpectedAdminMatch expected actual =
  require
    ("Expected admin " <> show expected <> " matches actual admin " <> show actual)
    (expected == actual)
```

Call pattern in every `*Impl` function:

```daml
simpleTransferImpl this _self arg = do
  requireExpectedAdminMatch arg.expectedAdmin this.admin
  -- ... rest of implementation
```

Applied to: `TransferFactory_Transfer`, `TransferFactory_PublicFetch`, `AllocationFactory_Allocate`, `AllocationFactory_PublicFetch`.

### Validation Utilities

All 15 security invariants from PLAN.md section 9 as copy-paste utilities. Put these in `Util.daml`.

```daml
-- 1. expectedAdmin (see above)
requireExpectedAdminMatch : Party -> Party -> Update ()

-- 2. requestedAt must be in the past
assertDeadlineExceeded : Text -> Time -> Update ()
assertDeadlineExceeded name deadline = do
  now <- getTime
  require (name <> " must be in the past") (now >= deadline)

-- 3. executeBefore / allocateBefore must be in the future
assertWithinDeadline : Text -> Time -> Update ()
assertWithinDeadline name deadline = do
  now <- getTime
  require (name <> " must be in the future") (now < deadline)

-- 4. allocateBefore <= settleBefore ordering
requireDeadlineOrdering : Time -> Time -> Update ()
requireDeadlineOrdering allocateBefore settleBefore =
  require "allocateBefore <= settleBefore" (allocateBefore <= settleBefore)

-- 5. amount > 0
requirePositiveAmount : Decimal -> Update ()
requirePositiveAmount amount =
  require "Amount must be positive" (amount > 0.0)

-- 6. instrumentId matches factory admin
requireInstrumentIdMatch : InstrumentId -> Party -> Update ()
requireInstrumentIdMatch instrumentId admin =
  require
    ("Instrument admin " <> show instrumentId.admin <> " must match factory admin " <> show admin)
    (instrumentId.admin == admin)

-- 7. Non-empty input holdings
requireNonEmptyInputs : [ContractId Holding] -> Update ()
requireNonEmptyInputs inputHoldingCids =
  require "At least one input holding must be provided" (not $ null inputHoldingCids)

-- 8. Input holding belongs to sender (call per holding)
fetchAndValidateHolding : Party -> Party -> ContractId Holding -> Update SimpleHolding
fetchAndValidateHolding admin sender holdingCid = do
  let templateCid = fromInterfaceContractId @SimpleHolding holdingCid
  holding <- fetch templateCid
  require "Holding admin matches" (holding.admin == admin)
  require "Holding owner matches sender" (holding.owner == sender)
  pure holding

-- 9. Input holdings sum >= requested amount
requireSufficientFunds : [SimpleHolding] -> Decimal -> Update ()
requireSufficientFunds holdings amount = do
  let total = sum (map (.amount) holdings)
  require ("Insufficient funds: have " <> show total <> " need " <> show amount) (total >= amount)
```

Usage in factory impl:

```daml
simpleTransferImpl this _self arg = do
  let transfer = arg.transfer
  requireExpectedAdminMatch arg.expectedAdmin this.admin           -- 1
  assertDeadlineExceeded "Transfer.requestedAt" transfer.requestedAt -- 2
  assertWithinDeadline "Transfer.executeBefore" transfer.executeBefore -- 3
  requirePositiveAmount transfer.amount                              -- 5 (renumbered: 6 in PLAN)
  requireInstrumentIdMatch transfer.instrumentId this.admin          -- 6 (renumbered: 7)
  requireNonEmptyInputs transfer.inputHoldingCids                    -- 7 (renumbered: 8)
  holdings <- forA transfer.inputHoldingCids $
    fetchAndValidateHolding this.admin transfer.sender               -- 8 (renumbered: 10)
  requireSufficientFunds holdings transfer.amount                    -- sum check
  -- ... proceed with archive + create
```

### Consume-and-Create (UTXO Mutations)

Holdings are UTXO contracts. Never mutate in place. Always archive input + create output.

```daml
-- Fetch, validate, and archive all inputs (establishes contention)
holdings <- forA transfer.inputHoldingCids \holdingCid -> do
  holding <- fetchAndValidateHolding admin transfer.sender holdingCid
  archive (fromInterfaceContractId @SimpleHolding holdingCid)
  pure holding

-- Create outputs
let totalInput = sum (map (.amount) holdings)
let changeAmount = totalInput - transfer.amount
receiverCid <- toInterfaceContractId <$> create SimpleHolding with
  admin; owner = transfer.receiver; instrumentId; amount = transfer.amount; meta = emptyMetadata
changeCids <- if changeAmount > 0.0
  then do
    cid <- toInterfaceContractId <$> create SimpleHolding with
      admin; owner = transfer.sender; instrumentId; amount = changeAmount; meta = emptyMetadata
    pure [cid]
  else pure []
```

The spec requires: "the transfer MUST archive all of these holdings, so that the execution of the transfer conflicts with any other transfers using these holdings."

**Handling locked holdings as input**: The spec says registries SHOULD allow holdings with expired locks as inputs. Our pattern:

```daml
-- Fetch a holding that might be SimpleHolding or LockedSimpleHolding
fetchAndValidateAnyHolding : Party -> Party -> ContractId Holding -> Update Decimal
fetchAndValidateAnyHolding admin sender holdingCid = do
  holdingView <- view <$> fetch holdingCid
  require "Holding owner matches sender" (holdingView.owner == sender)
  require "Holding instrumentId admin matches" (holdingView.instrumentId.admin == admin)
  case holdingView.lock of
    None -> do
      archive (fromInterfaceContractId @SimpleHolding holdingCid)
    Some lock -> do
      -- Expired lock: archive the locked holding, create unlocked equivalent
      now <- getTime
      case lock.expiresAt of
        Some expiry | now >= expiry ->
          archive (fromInterfaceContractId @LockedSimpleHolding holdingCid)
        _ -> fail "Cannot use locked holding with non-expired lock as input"
  pure holdingView.amount
```

### ExtraArgs / ChoiceContext / Metadata Plumbing

`ExtraArgs` bundles app-backend context (`ChoiceContext`) with caller metadata (`Metadata`). Every interface choice takes `extraArgs : ExtraArgs`.

**ChoiceContext**: `TextMap AnyValue` — app-internal keys. Used to pass contract IDs, flags, and configuration from the off-ledger registry to on-ledger choices.

```daml
-- Reading from ChoiceContext (from Splice: TokenApiUtils.daml)
getFromContextU : FromAnyValue a => ChoiceContext -> Text -> Update a
getFromContextU context k = either fail pure $ getFromContext context k

lookupFromContextU : FromAnyValue a => ChoiceContext -> Text -> Update (Optional a)
lookupFromContextU context k = either fail pure $ lookupFromContext context k

-- Usage: extract preapproval cid from context
optPreapprovalCid <- lookupFromContextU @(ContractId TransferPreapproval) extraArgs.context "transfer-preapproval"
```

**Metadata**: `TextMap Text` — DNS-prefix keys (k8s annotation convention). Keep small. Use your own DNS prefix for custom keys.

```daml
-- Our metadata key prefix
simpleTokenPrefix : Text
simpleTokenPrefix = "simpletoken.example.com/"

-- Define keys with your prefix
reasonMetaKey : Text
reasonMetaKey = simpleTokenPrefix <> "reason"
```

### Lock Semantics

`Lock` has `holders : [Party]`, `expiresAt : Optional Time`, `expiresAfter : Optional RelTime`, `context : Optional Text`.

Lock holders become signatories of the locked holding template. This means only owner + all holders can unlock.

**Our implementation** (not Splice's nested-template pattern):

```daml
template LockedSimpleHolding
  with
    admin : Party
    owner : Party
    instrumentId : InstrumentId
    amount : Decimal
    lock : Lock
    meta : Metadata
  where
    signatory admin, owner, lock.holders    -- holders are signatories
    ensure amount > 0.0

    interface instance Holding for LockedSimpleHolding where
      view = HoldingView with
        owner; instrumentId; amount
        lock = Some lock
        meta

    choice LockedSimpleHolding_Unlock : ContractId Holding
      controller owner :: lock.holders      -- owner + all holders required
      do toInterfaceContractId <$> create SimpleHolding with
           admin; owner; instrumentId; amount; meta
```

Note: Splice uses `signatory lock.holders, signatory amulet` which derives signatories from the nested `Amulet` record. Our flat structure uses `signatory admin, owner, lock.holders` directly.

**Lock context**: Human-readable, non-sensitive. Wallets display this to users.

```daml
lock = Lock with
  holders = [admin]
  expiresAt = Some transfer.executeBefore
  expiresAfter = None
  context = Some ("transfer to " <> show transfer.receiver)
```

### TransferPreapproval

The receiver creates this template ahead of time to authorize incoming direct transfers. The factory looks it up in the `ChoiceContext`.

```daml
template TransferPreapproval
  with
    admin : Party
    receiver : Party
    instrumentId : InstrumentId
  where
    signatory admin, receiver

    choice TransferPreapproval_Accept : ContractId Holding
      -- ^ Accept a transfer by consuming this preapproval.
      -- Called by the factory during direct transfer dispatch.
      with
        sender : Party
        amount : Decimal
        inputHoldingCids : [ContractId Holding]
        meta : Metadata
      controller sender
      do
        -- Validate and archive input holdings
        holdings <- forA inputHoldingCids $
          fetchAndValidateHolding admin sender
        forA_ inputHoldingCids \cid ->
          archive (fromInterfaceContractId @SimpleHolding cid)
        -- Create receiver holding
        let totalInput = sum (map (.amount) holdings)
        requireSufficientFunds holdings amount
        receiverCid <- create SimpleHolding with
          admin; owner = receiver; instrumentId; amount; meta = emptyMetadata
        -- Create change for sender
        let changeAmount = totalInput - amount
        when (changeAmount > 0.0) do
          void $ create SimpleHolding with
            admin; owner = sender; instrumentId; amount = changeAmount; meta = emptyMetadata
        toInterfaceContractId <$> pure receiverCid
```

**Creating a preapproval** (receiver authorizes ahead of time):

```daml
preapprovalCid <- submitMulti [admin, receiver] [] do
  createCmd TransferPreapproval with admin; receiver; instrumentId
```

**Factory reads it from ChoiceContext**:

```daml
optPreapprovalCid <- lookupFromContextU @(ContractId TransferPreapproval) extraArgs.context "transfer-preapproval"
```

### Transfer Factory 3-Way Dispatch

The factory detects which transfer path to use. This is the single most important function to implement.

```daml
simpleTransferImpl : SimpleTokenRules -> ContractId TransferFactory -> TransferFactory_Transfer -> Update TransferInstructionResult
simpleTransferImpl this _self arg = do
  let transfer = arg.transfer
  let admin = this.admin

  -- === Validation (all paths) ===
  requireExpectedAdminMatch arg.expectedAdmin admin
  requirePositiveAmount transfer.amount
  requireInstrumentIdMatch transfer.instrumentId admin
  assertDeadlineExceeded "Transfer.requestedAt" transfer.requestedAt
  assertWithinDeadline "Transfer.executeBefore" transfer.executeBefore
  requireNonEmptyInputs transfer.inputHoldingCids

  -- === Dispatch ===
  optPreapprovalCid <- lookupFromContextU @(ContractId TransferPreapproval) arg.extraArgs.context "transfer-preapproval"

  case optPreapprovalCid of
    None
      | transfer.receiver == transfer.sender -> do
          -- SELF-TRANSFER: archive inputs, create output for sender
          holdings <- forA transfer.inputHoldingCids \cid -> do
            h <- fetchAndValidateHolding admin transfer.sender cid
            archive (fromInterfaceContractId @SimpleHolding cid)
            pure h
          requireSufficientFunds holdings transfer.amount
          let totalInput = sum (map (.amount) holdings)
          let changeAmount = totalInput - transfer.amount
          receiverCid <- toInterfaceContractId <$> create SimpleHolding with
            admin; owner = transfer.sender; instrumentId = transfer.instrumentId
            amount = transfer.amount; meta = emptyMetadata
          changeCids <- if changeAmount > 0.0
            then do
              cid <- toInterfaceContractId <$> create SimpleHolding with
                admin; owner = transfer.sender; instrumentId = transfer.instrumentId
                amount = changeAmount; meta = emptyMetadata
              pure [cid]
            else pure []
          pure TransferInstructionResult with
            senderChangeCids = changeCids
            output = TransferInstructionResult_Completed with receiverHoldingCids = [receiverCid]
            meta = emptyMetadata

      | otherwise -> do
          -- TWO-STEP: archive inputs, lock funds, create TransferInstruction
          holdings <- forA transfer.inputHoldingCids \cid -> do
            h <- fetchAndValidateHolding admin transfer.sender cid
            archive (fromInterfaceContractId @SimpleHolding cid)
            pure h
          requireSufficientFunds holdings transfer.amount
          let totalInput = sum (map (.amount) holdings)
          let changeAmount = totalInput - transfer.amount
          -- Lock the transfer amount
          lockedCid <- create LockedSimpleHolding with
            admin; owner = transfer.sender; instrumentId = transfer.instrumentId
            amount = transfer.amount; meta = emptyMetadata
            lock = Lock with
              holders = [admin]
              expiresAt = Some transfer.executeBefore
              expiresAfter = None
              context = Some ("transfer to " <> show transfer.receiver)
          -- Create change holding
          changeCids <- if changeAmount > 0.0
            then do
              cid <- toInterfaceContractId <$> create SimpleHolding with
                admin; owner = transfer.sender; instrumentId = transfer.instrumentId
                amount = changeAmount; meta = emptyMetadata
              pure [cid]
            else pure []
          -- Create transfer instruction
          instrCid <- toInterfaceContractId <$> create SimpleTransferInstruction with
            transfer = transfer with inputHoldingCids = [toInterfaceContractId lockedCid]
            lockedHoldingCid = lockedCid
          pure TransferInstructionResult with
            senderChangeCids = changeCids
            output = TransferInstructionResult_Pending with transferInstructionCid = instrCid
            meta = emptyMetadata

    Some preapprovalCid -> do
      -- DIRECT TRANSFER: verify preapproval, exercise it
      preapproval <- fetch preapprovalCid
      require "Preapproval receiver matches" (preapproval.receiver == transfer.receiver)
      require "Preapproval admin matches" (preapproval.admin == admin)
      -- Delegate to preapproval which archives inputs + creates outputs
      receiverCid <- exercise preapprovalCid TransferPreapproval_Accept with
        sender = transfer.sender
        amount = transfer.amount
        inputHoldingCids = transfer.inputHoldingCids
        meta = transfer.meta
      pure TransferInstructionResult with
        senderChangeCids = []  -- change handled inside preapproval
        output = TransferInstructionResult_Completed with receiverHoldingCids = [receiverCid]
        meta = emptyMetadata
```

### Two-Step Transfer Pattern

Lock funds first (step 1 — in factory above), then accept/reject/withdraw (step 2).

**Step 2a — Accept** (receiver exercises `TransferInstruction_Accept`):

```daml
transferInstruction_acceptImpl _self arg = do
  -- Validate deadline
  assertWithinDeadline "Transfer.executeBefore" this.transfer.executeBefore
  -- Unlock the locked holding (admin is signatory of both instruction and locked holding)
  archive this.lockedHoldingCid
  -- Create holding for receiver
  receiverCid <- toInterfaceContractId <$> create SimpleHolding with
    admin = this.transfer.instrumentId.admin
    owner = this.transfer.receiver
    instrumentId = this.transfer.instrumentId
    amount = this.transfer.amount
    meta = emptyMetadata
  pure TransferInstructionResult with
    senderChangeCids = []
    output = TransferInstructionResult_Completed with receiverHoldingCids = [receiverCid]
    meta = emptyMetadata
```

**Step 2b — Reject/Withdraw** (returns holdings to sender):

```daml
abortTransferInstruction : SimpleTransferInstruction -> Update TransferInstructionResult
abortTransferInstruction instr = do
  -- Unlock: archive locked holding, create unlocked for sender
  archive instr.lockedHoldingCid
  senderCid <- toInterfaceContractId <$> create SimpleHolding with
    admin = instr.transfer.instrumentId.admin
    owner = instr.transfer.sender
    instrumentId = instr.transfer.instrumentId
    amount = instr.transfer.amount
    meta = emptyMetadata
  pure TransferInstructionResult with
    senderChangeCids = [senderCid]
    output = TransferInstructionResult_Failed
    meta = emptyMetadata
```

### Time Validation

Two checks on every factory entry:

```daml
-- requestedAt must be in the past (ledger time >= requestedAt)
assertDeadlineExceeded "Transfer.requestedAt" transfer.requestedAt

-- executeBefore must be in the future (ledger time < executeBefore)
assertWithinDeadline "Transfer.executeBefore" transfer.executeBefore
```

For allocations, additional ordering:

```daml
assertDeadlineExceeded "settlement.requestedAt" settlement.requestedAt
assertWithinDeadline "settlement.allocateBefore" settlement.allocateBefore
require "allocateBefore <= settleBefore" (settlement.allocateBefore <= settlement.settleBefore)
```

### Contention via inputHoldingCids

Double-spend prevention is archival-based, not balance-map-based.

```
TX1: exercises TransferFactory_Transfer with inputHoldingCids = [H1, H2]
TX2: exercises TransferFactory_Transfer with inputHoldingCids = [H1, H3]

Both try to archive H1. Exactly one succeeds. The other gets a contention error.
Client retries with updated holding set.
```

This is the Canton UTXO model working as designed. No additional locking needed.

### Allocation / DvP

**Allocate**: Lock funds, create `Allocation` contract. Returns `Completed` immediately (no pending state in simple model).

```daml
simpleAllocateImpl : SimpleTokenRules -> ContractId AllocationFactory -> AllocationFactory_Allocate -> Update AllocationInstructionResult
simpleAllocateImpl this _self arg = do
  let admin = this.admin
  let settlement = arg.allocation.settlement
  let transferLeg = arg.allocation.transferLeg

  -- Validate
  requireExpectedAdminMatch arg.expectedAdmin admin
  assertDeadlineExceeded "settlement.requestedAt" settlement.requestedAt
  assertWithinDeadline "settlement.allocateBefore" settlement.allocateBefore
  requireDeadlineOrdering settlement.allocateBefore settlement.settleBefore
  requirePositiveAmount transferLeg.amount
  requireInstrumentIdMatch transferLeg.instrumentId admin
  assertDeadlineExceeded "requestedAt" arg.requestedAt
  requireNonEmptyInputs arg.inputHoldingCids

  -- Archive inputs
  holdings <- forA arg.inputHoldingCids \cid -> do
    h <- fetchAndValidateHolding admin transferLeg.sender cid
    archive (fromInterfaceContractId @SimpleHolding cid)
    pure h
  requireSufficientFunds holdings transferLeg.amount
  let totalInput = sum (map (.amount) holdings)
  let changeAmount = totalInput - transferLeg.amount

  -- Lock the funds
  lockedCid <- create LockedSimpleHolding with
    admin; owner = transferLeg.sender; instrumentId = transferLeg.instrumentId
    amount = transferLeg.amount; meta = emptyMetadata
    lock = Lock with
      holders = [admin]
      expiresAt = Some settlement.settleBefore
      expiresAfter = None
      context = Some ("allocation for leg " <> arg.allocation.transferLegId <> " to " <> show transferLeg.receiver)

  -- Create change
  changeCids <- if changeAmount > 0.0
    then do
      cid <- toInterfaceContractId <$> create SimpleHolding with
        admin; owner = transferLeg.sender; instrumentId = transferLeg.instrumentId
        amount = changeAmount; meta = emptyMetadata
      pure [cid]
    else pure []

  -- Create allocation
  allocationCid <- toInterfaceContractId <$> create SimpleAllocation with
    allocation = arg.allocation
    lockedHoldingCid = lockedCid

  pure AllocationInstructionResult with
    senderChangeCids = changeCids
    output = AllocationInstructionResult_Completed with allocationCid
    meta = emptyMetadata
```

**Execute**: All legs in one atomic transaction.

```daml
allocation_executeTransferImpl _self Allocation_ExecuteTransfer{..} = do
  assertWithinDeadline "settlement.settleBefore" this.allocation.settlement.settleBefore
  -- Unlock locked holding
  archive this.lockedHoldingCid
  -- Create receiver holding
  let transferLeg = this.allocation.transferLeg
  receiverCid <- toInterfaceContractId <$> create SimpleHolding with
    admin = transferLeg.instrumentId.admin
    owner = transferLeg.receiver
    instrumentId = transferLeg.instrumentId
    amount = transferLeg.amount
    meta = emptyMetadata
  pure Allocation_ExecuteTransferResult with
    senderHoldingCids = []
    receiverHoldingCids = [receiverCid]
    meta = emptyMetadata
```

**Cancel/Withdraw**: Unlock, return to sender.

```daml
unlockAllocation : SimpleAllocation -> Update [ContractId Holding]
unlockAllocation alloc = do
  archive alloc.lockedHoldingCid
  let transferLeg = alloc.allocation.transferLeg
  senderCid <- toInterfaceContractId <$> create SimpleHolding with
    admin = transferLeg.instrumentId.admin
    owner = transferLeg.sender
    instrumentId = transferLeg.instrumentId
    amount = transferLeg.amount
    meta = emptyMetadata
  pure [senderCid]
```

### AllocationInstruction Patterns

The MVP returns `Completed` immediately from `AllocationFactory_Allocate` (no pending state). For future multi-step allocation, the `AllocationInstruction` interface exists:

```daml
-- AllocationInstruction_Withdraw: sender reclaims before allocation completes
-- Controller: allocation.transferLeg.sender
-- Returns: AllocationInstructionResult (with Failed output)

-- AllocationInstruction_Update: registry advances internal workflow
-- Controller: instrumentId.admin + extraActors
-- Returns: AllocationInstructionResult (with Pending or Completed output)
```

If implementing multi-step, follow the same pattern as `SimpleTransferInstruction`: create an `AllocationInstruction` template with a `lockedHoldingCid`, implement `_Withdraw` to unlock and return `Failed`, implement `_Update` to advance state toward creating the final `SimpleAllocation`.

### Signatory / Observer Patterns

| Template | Signatories | Observers |
|---|---|---|
| `SimpleHolding` | `admin, owner` | — |
| `LockedSimpleHolding` | `admin, owner, lock.holders` | — |
| `SimpleTransferInstruction` | `instrumentId.admin, transfer.sender` | `transfer.receiver` |
| `SimpleAllocation` | `instrumentId.admin, transferLeg.sender` | `settlement.executor` |
| `SimpleAllocationRequest` | `settlement.executor` | senders of transfer legs |
| `SimpleTokenRules` | `admin` | — |
| `TransferPreapproval` | `admin, receiver` | — |

---

## Testing Patterns

### submitMulti Pattern

Holdings require both `admin` and `owner` as signatories. Use `submitMulti` for multi-party authorization:

```daml
-- Creating a holding (requires both admin and owner signatures)
holdingCid <- submitMulti [admin, alice] [] do
  createCmd SimpleHolding with
    admin; owner = alice; instrumentId; amount = 100.0; meta = emptyMetadata

-- Exercising allocation choices (requires executor + sender + receiver)
result <- submitMulti [executor, alice, bob] [] do
  exerciseCmd allocationCid Allocation_ExecuteTransfer with
    extraArgs = ExtraArgs with context = emptyChoiceContext; meta = emptyMetadata

-- Negative multi-party test
submitMultiMustFail [alice] [] do  -- missing admin
  createCmd SimpleHolding with admin; owner = alice; ...
```

`submitMulti signatories readAs` — first list is acting parties, second is read-only observers.

### Setup Pattern

```daml
setupApp : Script (Party, Party, Party, ContractId TransferFactory, [ContractId Holding])
setupApp = do
  admin <- allocateParty "admin"
  alice <- allocateParty "alice"
  bob <- allocateParty "bob"

  -- Create factory (only admin is signatory)
  factoryCid <- submit admin do
    createCmd SimpleTokenRules with admin
  let factory = toInterfaceContractId @TransferFactory factoryCid
  let instrumentId = InstrumentId with admin; id = "SimpleToken"

  -- Mint initial holdings (requires both admin + owner)
  h1 <- submitMulti [admin, alice] [] do
    createCmd SimpleHolding with admin; owner = alice; instrumentId; amount = 100.0; meta = emptyMetadata

  pure (admin, alice, bob, factory, [toInterfaceContractId h1])
```

### Test Structure

Tests are `Script ()` functions:

```daml
test_selfTransfer : Script ()
test_selfTransfer = do
  (admin, alice, bob, factory, holdings) <- setupApp
  now <- getTime
  result <- submit alice do
    exerciseCmd factory TransferFactory_Transfer with
      expectedAdmin = admin
      transfer = Transfer with
        sender = alice
        receiver = alice
        amount = 50.0
        instrumentId = InstrumentId with admin; id = "SimpleToken"
        requestedAt = now
        executeBefore = addRelTime now (hours 24)
        inputHoldingCids = holdings
        meta = emptyMetadata
      extraArgs = ExtraArgs with context = emptyChoiceContext; meta = emptyMetadata
  -- Assert result shape
  case result.output of
    TransferInstructionResult_Completed _ -> pure ()
    _ -> abort "Expected Completed"
  -- Verify change returned
  assert (length result.senderChangeCids == 1)
```

**Negative tests**: Use `submitMustFail` or `submitMultiMustFail`.

```daml
test_wrongExpectedAdmin : Script ()
test_wrongExpectedAdmin = do
  (admin, alice, bob, factory, holdings) <- setupApp
  wrongAdmin <- allocateParty "wrongAdmin"
  now <- getTime
  submitMustFail alice do
    exerciseCmd factory TransferFactory_Transfer with
      expectedAdmin = wrongAdmin  -- wrong!
      transfer = Transfer with
        sender = alice; receiver = alice; amount = 50.0
        instrumentId = InstrumentId with admin; id = "SimpleToken"
        requestedAt = now; executeBefore = addRelTime now (hours 24)
        inputHoldingCids = holdings; meta = emptyMetadata
      extraArgs = ExtraArgs with context = emptyChoiceContext; meta = emptyMetadata
```

**Query and filter**:

```daml
holdings <- queryFilter @SimpleHolding alice (\h -> h.owner == alice && h.amount > 0.0)
```

---

## Off-Ledger API Patterns

Registry HTTP service assembles `ChoiceContext` and `disclosedContracts` for wallet submissions. See PLAN.md step 9 for full scope. Detailed off-ledger Haskell patterns will be documented in a dedicated `service/PATTERNS.md` when implementation begins.

### Endpoint Structure

From Splice OpenAPI:

```
GET  /registry/metadata/v1/info
GET  /registry/metadata/v1/instruments
GET  /registry/metadata/v1/instruments/{instrumentId}
POST /registry/transfer-instruction/v1/transfer-factory
POST /registry/transfer-instruction/v1/{id}/choice-contexts/{accept|reject|withdraw}
POST /registry/allocation-instruction/v1/allocation-factory
POST /registry/allocations/v1/{id}/choice-contexts/{execute-transfer|withdraw|cancel}
```

### ChoiceContext Construction

The off-ledger service builds a `ChoiceContext` from its own state and returns it alongside `disclosedContracts` for wallet submission:

```haskell
-- Pseudocode: building transfer factory ChoiceContext
buildTransferContext :: TransferRequest -> IO ChoiceContextResponse
buildTransferContext req = do
  -- Look up preapproval if receiver has one
  mPreapproval <- lookupPreapproval req.receiverParty
  let contextValues = case mPreapproval of
        Nothing -> Map.empty
        Just cid -> Map.singleton "transfer-preapproval" (AV_ContractId cid)
  -- Collect disclosed contracts the wallet needs
  let disclosed = catMaybes [mPreapproval >>= \cid -> Just (DisclosedContract cid ...)]
  pure ChoiceContextResponse
    { choiceContextData = ChoiceContext contextValues
    , disclosedContracts = disclosed
    }
```

### Response Conventions

- Always include `choiceContextData` and `disclosedContracts` in factory/choice-context responses.
- Support `excludeDebugFields` query parameter (default `true`). Only expose what wallets need.
- Return **409 Conflict** when contracts are in reassignment state between synchronizers.
- Return **404 Not Found** when referenced contract IDs don't exist.

---

## Common Errors

| Error | Cause | Fix |
|---|---|---|
| `DA_AUTHORIZATION` on `createCmd` | Missing signatory — holdings need both `admin` and `owner` | Use `submitMulti [admin, owner] []` |
| `DA_AUTHORIZATION` on `exerciseCmd` | Wrong controller — check who can exercise this choice | See Controller Patterns; check Signatory table |
| `require failure "Expected admin X matches actual admin Y"` | Wrong `expectedAdmin` passed to factory | Use the admin party from your own participant's read |
| `require failure "must be in the past"` | `requestedAt` is in the future | Use `getTime` for current ledger time |
| `require failure "must be in the future"` | `executeBefore` / `allocateBefore` already passed | Extend deadline or create fresh instruction |
| `Contract not found` / `ContractNotFound` | Holding already archived by another transaction (contention) | Retry with fresh holding CIDs from ACS query |
| `fromInterface returns None` | Downcasting to wrong template type | Check if holding is `SimpleHolding` vs `LockedSimpleHolding`; use view-based checks |
| `require failure "Amount must be positive"` | Zero or negative transfer amount | Validate amount > 0 before submitting |
| `require failure "At least one input holding"` | Empty `inputHoldingCids` | Query holdings and include at least one |
| `require failure "Insufficient funds"` | Input holdings sum < requested amount | Include more holdings or reduce amount |

---

## Anti-Patterns

1. **Global mutable state** — No account-balance maps. Holdings are UTXO contracts. "Balance" = sum of active holdings.
2. **Skipping `expectedAdmin` check** — Every factory choice validates. No exceptions.
3. **Implicit observers** — Never add observers without clear visibility reason. Lock context is non-sensitive.
4. **Fat templates** — Don't mix unrelated workflows in one template. One template per lifecycle state.
5. **Metadata as logic** — Metadata is for extensibility, not business-critical branching. Don't gate control flow on metadata keys.
6. **Leaking contract internals** — Off-ledger APIs default to `excludeDebugFields = true`. Only expose what wallets need.
7. **Forgetting contention** — If `inputHoldingCids` is non-empty, ALL must be archived. Partial archival breaks the contention guarantee.
8. **Time validation omission** — Every factory entry validates `requestedAt` (past) and deadline (future). Without this, stale or premature submissions succeed.
9. **Holding creation without signatory alignment** — Both `admin` and `owner` must be signatories. A holding with only one signatory can be unilaterally archived.
10. **Using contract keys as global uniqueness** — Contract keys work for lookup, not as distributed uniqueness guarantees across synchronizers.
