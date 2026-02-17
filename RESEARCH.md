# RESEARCH: Canton Network Token Standard (CIP-056) in DAML/Haskell

Date consolidated: February 17, 2026  
Research source dates: up to February 16, 2026

## Purpose
This document consolidates all provided research into one implementer-focused reference for building a secure, minimal, and extensible CIP-056 implementation in DAML/Haskell on Canton.

## Ground Truth and Primary Sources
- CIP-0056 (Final; created 2025-03-07, approved 2025-03-31): canonical standard intent and required APIs.
- `../splice/token-standard`: practical reference implementation of interfaces, OpenAPI specs, and tests.
- `../splice/token-standard/CHANGELOG.md`: required deltas and compatibility expectations (notably `expectedAdmin`, `requestedAt`, `supportedApis`, metadata evolution, result type semantics).
- Splice docs for integration patterns: interface querying, transaction-tree parsing, explicit disclosure, LocalNet testing.
- Canton architecture references: extended UTXO model, privacy, determinism, transaction trees.

## Core Interpretation of CIP-056
CIP-056 is an interoperability standard for wallets/apps on Canton, centered on:
- On-ledger interface contracts for holdings and transfer/settlement workflows.
- Off-ledger registry APIs for metadata, factory retrieval, and choice-context/disclosure retrieval.
- Safety-first workflow construction in a privacy-preserving UTXO ledger.

It is not an ERC-20 clone. It is institution-oriented and workflow-oriented.

## Canonical On-Ledger API Surface
From Splice interface DARs:
- Holding API: `Holding` interface + `HoldingView`.
- Transfer API: `TransferFactory`, `TransferInstruction`, `TransferInstructionResult`.
- DvP API: `AllocationFactory`, `Allocation`, `AllocationInstruction` (depending on flow), and `AllocationRequest` for app-initiated requests.

Key practical invariants:
- Holdings are UTXO-like contracts; “balance” is aggregated holdings.
- Double-spend prevention is consumption/contention, not account-map mutation.
- Transfer/Allocation flows intentionally support pending states and multi-step execution.

## Canonical Off-Ledger API Surface (OpenAPI)
Splice OpenAPI specs define expected paths and payload patterns:
- Metadata:
  - `GET /registry/metadata/v1/info`
  - `GET /registry/metadata/v1/instruments`
  - `GET /registry/metadata/v1/instruments/{instrumentId}`
- Transfer instruction:
  - `POST /registry/transfer-instruction/v1/transfer-factory`
  - `POST /registry/transfer-instruction/v1/{transferInstructionId}/choice-contexts/{accept|reject|withdraw}`
- Allocation instruction:
  - `POST /registry/allocation-instruction/v1/allocation-factory`
- Allocation:
  - `POST /registry/allocations/v1/{allocationId}/choice-contexts/{execute-transfer|withdraw|cancel}`

Important payload conventions:
- `choiceContextData` + `disclosedContracts` as explicit transaction-construction inputs.
- `excludeDebugFields` support for bandwidth/safety hygiene.
- 409 conflict behavior when contracts are in reassignment state.

## Security-Critical Design Conventions from Splice
- Enforce `expectedAdmin` in factory choices.
- Treat metadata as extensible namespaced key-value map (DNS-prefix convention).
- Use explicit `requestedAt` and explicit deadlines (`executeBefore`, etc.) for long prepare→submit windows.
- Keep lock context human-readable but non-sensitive.

## Ethereum-to-Canton Mapping (Practical)
- `balanceOf` → query active `Holding` contracts and sum `amount`.
- `transfer` → `TransferFactory_Transfer` then possibly `TransferInstruction_*` lifecycle.
- `approve/allowance` → no direct global map analog; use allocation/delegation-style constrained rights.
- Event logs → transaction-tree parsing filtered by interfaces/choices.

## Rough Edges and Constraints
- UTXO contention is normal: retries are required in clients.
- Atomicity requires same-synchronizer inputs for each transaction.
- Privacy means wallets may need off-ledger supplied disclosures to exercise choices correctly.
- Contract keys are useful for lookup but should not be sole global uniqueness control across domains.
- Pruning implies validation must rely on current ACS state, not deep history.

## Minimal Viable Registry Shape (Evidence-Aligned)
- Interfaces as stable ABI boundary.
- Internal templates implement interfaces with minimal custom branching.
- Offer-accept transfer workflow as default safe baseline.
- Direct allocation creation for DvP MVP; multi-step instruction support can be deferred.
- Registry config gate for pause/policy checks.

## Testing Insights
- Reuse Splice test harness ideas as executable spec style.
- Must test:
  - transfer pending/accept/reject/withdraw;
  - allocation create/execute/cancel/withdraw;
  - contention behavior (one of duplicate attempts fails);
  - at least one multi-leg atomic DvP scenario.
- Integration tests should verify off-ledger choice-context/disclosure path and JSON API submission flow.

## Operational and Implementation Conventions (from nearby repos)
Observed in parent repos (`../splice`, `../daml-finance`):
- Keep interface/API packages separate from implementation packages.
- Keep script/test packages separate from production DAR packages.
- Favor explicit module boundaries and small package scopes.
- Treat SDK/network version alignment as deploy-time variable.

## Non-MVP / Explicitly Deferred
- Full regulated-internal approval chains for all transfers/allocations.
- Broad authN/authZ gatewaying for registry APIs (CIP permits unauthenticated baseline).
- Advanced extension APIs (burn/mint standardization, hold standard, compliance partitions) beyond baseline deliverability.

## Source Inventory (consolidated from provided list)
Primary and highly relevant:
- CIP-056 spec and Canton Network explainer.
- `../splice/token-standard` interfaces, OpenAPI specs, changelog, tests.
- Splice docs for token-standard integration and LocalNet usage.
- Canton architecture docs/whitepaper references.

Secondary/contextual:
- ERC-20/721/1155/2612/777 references for conceptual mapping.
- Daml forum/blog posts on keys, pruning, divulgence, testing, security.

Implementation guidance in this repo should prioritize primary sources and treat secondary sources as supplemental context.
