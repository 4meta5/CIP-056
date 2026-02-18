  What the Plan Is                                                                                                 
                                                                                                                   
  PLAN.md is a blueprint for building a minimal CIP-056 token registry — a simpler alternative to Digital Asset's  
  own Splice/Amulet implementation. CIP-056 is the Canton Network's answer to ERC-20, but designed for             
  institutional finance: privacy-preserving, atomically settleable across sovereign ledgers, and workflow-oriented
  rather than balance-map-oriented.

  The plan builds against 6 published interface DARs (compiled Daml packages) that define the canonical token API.
  We never modify these interfaces — we implement templates that satisfy them. This is the Canton equivalent of
  implementing an ERC-20 interface, except the "interface" is a typed Daml contract interface enforced at the
  language level, not just a function signature convention.

  ---
  The Architecture, Explained

  The UTXO Foundation

  Canton doesn't store balances. It stores active contracts (the Active Contract Set / ACS). A user's "balance" is
  the sum of all their active Holding contracts. When you transfer 50 tokens, you don't decrement a counter — you
  archive (destroy) input holding contracts and create new ones for the recipient and any change. This is
  conceptually identical to Bitcoin's UTXO model.

  This matters because:
  - Double-spend prevention is free: Two transactions that try to archive the same holding contract will conflict
  at the ledger level. Exactly one wins. The other gets a contention error and must retry.
  - Privacy is structural: Only the parties on a contract can see it. Alice's holdings are invisible to Bob unless
  Bob is a stakeholder.
  - Fragmentation is a real operational concern: Every transfer can split one holding into two (amount + change).
  Over time, users accumulate many small holdings. Canton recommends keeping UTXOs below ~10 per user. Our plan
  defers merge/defrag utilities to post-MVP but designs the data model to support them.

  The Seven Templates

  The plan specifies 7 concrete templates (plus 1 test-only helper):

  SimpleHolding — An unlocked holding. Fields: admin, owner, instrumentId, amount, meta. Signatories: admin +
  owner. This is the resting state of tokens.

  LockedSimpleHolding — A holding with a lock. Same fields plus a Lock (holders, expiry, context). Lock holders
  become signatories, meaning they must authorize any unlock. Used as the escrow mechanism for two-step transfers
  and allocations.

  SimpleTokenRules — The factory contract. Signed only by admin. Implements both TransferFactory and
  AllocationFactory interfaces. This is the single entry point for all token operations. Its transferImpl function
  contains the most important branching logic in the entire system.

  SimpleTransferInstruction — Created during two-step transfers. Represents a pending transfer awaiting receiver
  acceptance. Holds a reference to the locked holding backing it.

  SimpleAllocation — Created during DvP allocation. Represents funds locked for settlement. Holds a reference to
  the locked holding.

  TransferPreapproval — Created by a receiver to pre-authorize incoming transfers. Enables the "direct transfer"
  path that completes in one step.

  SimpleAllocationRequest — Test helper only. An app creates this to request that senders allocate funds for a
  multi-leg settlement.

  The Three Transfer Paths

  This is the core architectural decision. The factory dispatches to one of three paths:

  Self-transfer (sender == receiver): Used for merge/split operations. Archives inputs, creates consolidated
  output. Completes immediately. This is how you defragment holdings.

  Direct transfer (preapproval exists): The receiver has pre-authorized receipt by creating a TransferPreapproval
  contract. The factory finds it in the ChoiceContext, exercises it, and the transfer completes in one atomic
  transaction. Best UX — one step.

  Two-step transfer (no preapproval, different parties): Funds are locked in a LockedSimpleHolding and a
  SimpleTransferInstruction is created. The receiver must then accept (funds go to receiver), reject (funds return
  to sender), or the sender can withdraw. The lock expires at executeBefore.

  This three-way dispatch mirrors exactly how Splice's ExternalPartyAmuletRules works, just without the fee engine,
   mining rounds, and reward systems.

  The DvP (Delivery vs. Payment) Mechanism

  For atomic multi-asset settlement (e.g., exchanging bonds for cash), the allocation system works:

  1. Each sender locks their funds via AllocationFactory_Allocate, creating a SimpleAllocation.
  2. Once all legs have allocations, the executor atomically exercises Allocation_ExecuteTransfer on all of them in
   a single transaction.
  3. Canton's atomic transaction guarantee means either all legs succeed or none do. No partial settlement.

  This only works if all contracts are on the same synchronizer. Cross-synchronizer atomicity requires the Global
  Synchronizer, which is how Canton achieves what Ethereum can't do natively.

  The Zero-Fee Decision

  Splice locks amount + (fees * 4.0) to guard against fee changes between locking and execution. It couples to
  mining rounds for fee calculation. Our plan eliminates all of this: transfer amount in = transfer amount out.
  This is the single biggest simplification — it removes the ExpiringAmount, OpenMiningRound,
  PaymentTransferContext, and exercisePaymentTransfer dependencies entirely.

  The Off-Ledger Service

  Wallets can't construct transactions alone. They need:
  - The factory contract ID
  - A ChoiceContext with any contract IDs the choice implementation needs (like preapprovals)
  - disclosedContracts for contracts the wallet can't see but needs to reference

  The off-ledger HTTP service provides these via OpenAPI-aligned endpoints. It's the bridge between wallet UX and
  on-ledger execution.

  The Security Model

  15 invariants, every one tied to a specific implementation point. The most critical:
  - expectedAdmin validation on every factory choice (prevents contract-swap attacks)
  - Time validation: requestedAt must be in the past, executeBefore must be in the future
  - Mandatory archival of all input holdings (contention guarantee)
  - Lock holder = admin (prevents sender from unilaterally reclaiming locked funds)

  ---
  Open Questions

  1. How should the factory handle input holdings that are LockedSimpleHolding with expired locks?

  The CIP-056 spec says "Registries SHOULD allow holdings with expired locks as inputs to transfers." Our plan
  acknowledges this but the handling strategy is unspecified.

  - A) Reject locked holdings entirely at the factory level (Recommended) — Only accept SimpleHolding as inputs. If
   a user has a locked holding with an expired lock, they must first explicitly unlock it via
  LockedSimpleHolding_Unlock in a separate transaction, then use the resulting SimpleHolding. Simplest code path.
  No type-dispatch complexity in the factory. Slight UX cost: two transactions instead of one for expired-lock
  inputs.
  - B) Auto-unlock expired locks inline during factory execution — The factory detects LockedSimpleHolding inputs,
  checks if the lock is expired, and archives + recreates as unlocked before proceeding. This is what Splice does
  with holdingToTransferInputs. Better UX but adds type-dispatch logic (fromInterface pattern matching) to the
  factory, and requires the factory to have authority to archive locked holdings (which it does, since admin is a
  signatory on both).
  - C) Treat all holdings uniformly via the Holding interface view — Never downcast. Read amount from the view,
  archive via interface, create new SimpleHolding. Cleanest abstraction but may not work because archiving a
  LockedSimpleHolding via its interface contract ID requires all signatories (including lock holders) to authorize.

  2. Should TransferPreapproval be one-time-use (consumed on transfer) or persistent (nonconsuming)?

  The plan says "consumed on use (each preapproval is one-time)" but this forces receivers to recreate preapprovals
   after every incoming transfer.

  - A) One-time-use / consuming (Recommended) — Each preapproval is archived when exercised. Receiver must create a
   new one for each expected incoming transfer. Simplest mental model. No state management. Prevents unbounded
  authorization exposure. Matches the plan as written.
  - B) Persistent / nonconsuming — Preapproval stays active. Any sender can use it for any amount up to some limit.
   Requires adding amount/sender constraints and expiry to prevent open-ended authorization. Scope creep: needs
  rate limiting, cap tracking, and revocation mechanisms.
  - C) Persistent with counter — Preapproval tracks remaining authorized amount. Consume-and-recreate with
  decremented counter. Middle ground but adds mutable-state tracking complexity.

  3. What happens to locked funds when executeBefore passes and nobody acts?

  The two-step transfer creates a LockedSimpleHolding with expiresAt = executeBefore. After expiry:

  - A) Sender self-serves by using the expired locked holding as an input to a new self-transfer (Recommended) —
  The expired lock means the sender can unlock it (lock holders can no longer block). Sender exercises
  LockedSimpleHolding_Unlock directly, or uses the locked holding as an input to a self-transfer if option 1B was
  chosen. No cleanup automation needed. The SimpleTransferInstruction still exists on the ledger but is inert (any
  exercise would fail the deadline check).
  - B) Add an explicit SimpleTransferInstruction_Expire choice — Admin or sender can exercise this after
  executeBefore passes, which archives the instruction and unlocks funds. More explicit lifecycle but adds a choice
   and an automation concern (who triggers it?).
  - C) Add off-ledger automation that periodically cleans up expired instructions — Registry service scans for
  expired instructions and triggers cleanup. Operational overhead. Scope creep into automation infrastructure.

  4. How should the factory validate that input holdings belong to the correct instrumentId?

  The plan validates instrumentId.admin == factory admin at the top of the factory, but doesn't specify whether
  each individual input holding's instrumentId is checked.

  - A) Validate only at the factory level — transfer.instrumentId.admin == admin (Recommended) — Since the factory
  only creates holdings with the correct instrumentId, and holdings are signed by admin, any holding signed by our
  admin necessarily has the correct instrument. Circular trust — if you trust the admin's signature, you trust the
  holding's instrument. No per-holding check needed.
  - B) Validate each holding's instrumentId matches transfer.instrumentId — Fetch each holding, check instrumentId
  field. Defense in depth against bugs or multi-instrument scenarios. Adds one comparison per holding. Minimal
  cost, maximal safety.

  5. Should the project support multiple instruments per factory, or one factory per instrument?

  The current plan has SimpleTokenRules with a single admin : Party field. The instrumentId is constructed from
  admin + "SimpleToken". But the InstrumentId type has both admin and id fields.

  - A) One factory, one hardcoded instrument ID (Recommended) — instrumentId = InstrumentId with admin; id =
  "SimpleToken". Simplest. If someone wants a second instrument, they deploy a second SimpleTokenRules with a
  different admin or fork the code. No multi-instrument routing logic.
  - B) One factory, configurable instrument ID — Add instrumentIdText : Text to SimpleTokenRules. Factory creates
  holdings with InstrumentId with admin; id = instrumentIdText. Slightly more flexible, trivial code change, but
  opens the question of what "multiple instruments from the same admin" means operationally.
  - C) One factory, multiple instruments — Factory maintains a list of supported instruments. Adds routing logic,
  per-instrument validation, and configuration management. Scope creep without clear user need at MVP.

  6. How should the off-ledger service authenticate requests?

  The plan's non-goals include "multi-tenant auth gateway" but the service still needs some access control.

  - A) No authentication for MVP (Recommended) — The off-ledger service runs as a sidecar to the participant node.
  Only the participant's own applications can reach it. Network-level isolation (localhost binding or mTLS at infra
   layer) replaces application-level auth. CIP-056 permits unauthenticated baseline per the RESEARCH.md. Simplest
  path to working system.
  - B) Static API key — Simple shared secret in header. Easy to implement, sufficient for single-tenant MVP.
  - C) OAuth2 / JWT — Full token-based auth. Appropriate for multi-tenant production but significant scope
  expansion for MVP.

  7. How should contention retries be handled?

  The plan says "Clients MUST retry on contention failures" but doesn't specify where retry logic lives.

  - A) Client-side retries only (Recommended) — The wallet/app detects contention errors (contract not found),
  re-queries the ACS for current holdings, and resubmits. This is the documented Canton convention. The off-ledger
  service is stateless and doesn't need to manage retry state.
  - B) Off-ledger service retry loop — The service catches contention errors, re-queries holdings, and resubmits.
  Reduces client complexity but makes the service stateful and adds timeout/backoff logic.
  - C) Optimistic locking at the service level — Service tracks in-flight holding usage and avoids proposing the
  same holdings to concurrent requests. Most sophisticated, lowest contention, but significant complexity.

  8. Should the DvP test use a real multi-party atomic transaction or simulate it?

  The plan specifies test_dvpTwoLegs but Daml Script tests run in a sandbox where atomicity is trivially
  guaranteed.

  - A) Daml Script test with submitMulti covering all parties (Recommended) — Single submitMulti [executor, alice,
  bob] [] that exercises both Allocation_ExecuteTransfer choices. Proves the authorization model works. Simple. The
   atomicity guarantee comes from Canton, not our code — testing it at the script level is sufficient for MVP.
  - B) Add integration test against LocalNet — Deploy to a real Canton topology, submit via JSON API, verify both
  legs committed. Tests the real synchronizer path. Deferred to Step 10 in the plan but would prove
  cross-participant atomicity.

  9. What metadata key prefix should the project use?

  Splice uses splice.lfdecentralizedtrust.org/. The plan shows placeholder simpletoken.example.com/ or
  myregistry.example.com/.

  - A) Use a real project-owned domain prefix — Pick an actual DNS name the project controls (or will control).
  Avoids conflicts, follows the k8s annotation convention properly. Requires deciding on a domain name now.
  - B) Use canton-token-standard.example.com/ as a placeholder (Recommended) — Clearly a placeholder, clearly
  scoped, easy to grep-and-replace when a real domain is chosen. No premature commitment to a domain name. Won't
  conflict with any production system.
  - C) Omit custom metadata entirely for MVP — Only use emptyMetadata. No custom keys. Simplest but means result
  metadata carries no useful information for wallet developers testing against the registry.

  10. How should the project handle the TransferInstruction_Update choice?

  The plan says "fail with message" but the interface requires the choice to exist.

  - A) Fail with descriptive message (Recommended, matches plan) — fail "SimpleTransferInstruction:
  TransferInstruction_Update not supported. This registry uses single-step acceptance." Clear, honest, no
  ambiguity. Wallets that parse transaction trees will never see this choice exercised.
  - B) No-op that returns the same instruction — Create a new SimpleTransferInstruction with identical fields,
  return Pending with the new CID. Technically compliant but misleading — makes it look like something happened
  when nothing did.

  11. Should there be a registry pause/config mechanism?

  RESEARCH.md mentions "Registry config gate for pause/policy checks" as part of the minimal viable registry shape.
   The plan omits it.

  - A) Omit for MVP (Recommended, matches plan) — No pause mechanism. If the admin needs to stop operations, they
  archive the SimpleTokenRules contract. This is a blunt instrument but effective and zero-code. Re-create the
  factory to resume.
  - B) Add a RegistryConfig contract with paused : Bool — Factory fetches config before every operation, rejects if
   paused. Small code cost (~10 lines), but adds a contract dependency to every transaction and a new operational
  concern (who manages the config contract?).
  - C) Add a feature flag in the factory template — SimpleTokenRules gets a paused : Bool field. Requires
  consume-and-recreate to toggle. Simplest config approach but factory CID changes on every toggle, breaking cached
   references.

  ---
  Known Canton Network Issues Relevant to This Plan

  UTXO fragmentation: Canton https://www.canton.network/blog/what-is-cip-56-a-guide-to-cantons-token-standard
  keeping holdings below ~10 per user and
  https://www.certik.com/resources/blog/cip-56-redefining-token-standards-for-institutional-defi. Our self-transfer
   path serves as the merge mechanism, but the plan defers automated defragmentation. In production, wallets that
  don't proactively merge will degrade.

  Same-synchronizer atomicity requirement: DvP only works when all contracts are on the
  https://www.canton.network/global-synchronizer. Cross-synchronizer transactions require the Global Synchronizer.
  The plan acknowledges this as risk #1 but doesn't specify which synchronizer topology to target. For
  institutional use cases (DTCC Treasury tokenization, Tradeweb repos), this is the critical infrastructure
  question.

  Contract reassignment: When contracts move between synchronizers, they enter a "reassignment" state where they're
   temporarily unavailable. The plan's off-ledger service must return 409 Conflict in this case. This is a real
  operational concern for multi-synchronizer deployments that the plan addresses at the API level but not at the
  on-ledger level.

  Disclosure and privacy: Canton's https://docs.daml.com/concepts/ledger-model/ledger-privacy.html means wallets
  may not see contracts they need to exercise choices against. The off-ledger service must provide
  disclosedContracts to bridge this gap. The plan's Disclosure.hs module handles this, but the exact disclosure
  assembly logic is unspecified.

  Daml SDK and Canton version pinning: The ecosystem is evolving rapidly —
  https://www.canton.network/hubfs/Canton%20Network%20Files/whitepapers/Polyglot_Canton_Whitepaper_11_02_25.pdf
  (EVM support) was announced in late 2025, and governance proposals like
  https://coinmarketcap.com/cmc-ai/canton-network/latest-updates/ (automated fee calculation via oracles) change
  the fee landscape. Pinning SDK versions early and tracking the CHANGELOG is essential.

  Sources:
  - https://www.certik.com/resources/blog/cip-56-redefining-token-standards-for-institutional-defi
  - https://www.canton.network/blog/what-is-cip-56-a-guide-to-cantons-token-standard
  - https://docs.global.canton.network.sync.global/app_dev/token_standard/index.html
  - https://www.digitalasset.com/hubfs/Canton/Canton%20Network%20-%20White%20Paper.pdf
  - https://www.canton.network/protocol
  - https://docs.sync.global/
  - https://docs.daml.com/concepts/ledger-model/ledger-privacy.html
  - https://www.blockdaemon.com/blog/how-canton-works
  - https://www.canton.network/canton-network-press-releases/dtcc-and-digital-asset-partner-to-tokenize-dtc-custodi
  ed-u.s.-treasury-securities-on-the-canton-network
  - https://www.canton.network/blog/a-technical-primer
  - https://www.canton.network/hubfs/Canton%20Network%20Files/whitepapers/Polyglot_Canton_Whitepaper_11_02_25.pdf
  - https://www.dfns.co/article/canton-token-standard-support
