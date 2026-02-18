# Canton Network Token Standard (CIP-056)

## What This Is

Minimal DAML/Haskell implementation of the 6 CIP-056 on-ledger interfaces. Proves a non-[Splice](https://github.com/hyperledger-labs/splice) registry can implement the Canton token standard and interoperate with standard-compliant wallets. See [SCOPE.md](SCOPE.md) for full scope and [PLAN.md](PLAN.md) for implementation details.

## Status

On-ledger: **27/27 tests passing** (7 templates, 6 interfaces, 24 security invariants). Off-ledger: not in scope (uses Splice `token-standard`).

## Prerequisites

- **dpm** (Digital Asset Package Manager): `~/.dpm/bin/dpm`
- **Daml SDK** 3.4.10
- **Java 21** (for `dpm test`)
- Access to [Splice](https://github.com/hyperledger-labs/splice) interface DARs (linked via `dars/` symlinks)

## Quick Start

### Build

```sh
dpm build
```

### Test

```sh
JAVA_HOME=/opt/homebrew/Cellar/openjdk@21/21.0.10/libexec/openjdk.jdk/Contents/Home \
  PATH="$JAVA_HOME/bin:$PATH" dpm test
```

### What the 27 Tests Prove

- **7 transfer lifecycle tests** — self-transfer, direct (preapproval), two-step (pending/accept/reject/withdraw), exact-amount edge case
- **5 allocation/DvP tests** — allocate, execute, cancel, withdraw, multi-leg atomic settlement
- **2 defragmentation tests** — 10-holding merge, multi-instrument transfer
- **12 security tests** — admin validation, time windows, contention, authorization, cross-instrument attack, unexpired lock rejection
- **1 positive expired-lock test** — expired locks accepted as transfer inputs

## Project Structure

```
simple-token/          Production DAML contracts (7 templates, 6 interface implementations)
simple-token-test/     Test suite (27 tests across 5 modules)
dars/                  Symlinks to splice-api-token-*-v1 interface DARs
```

## Documentation

- [SCOPE.md](SCOPE.md) — What's in scope, what's not, differences from Splice, spec gap analysis
- [PLAN.md](PLAN.md) — Implementation plan, template designs, security invariants, test criteria

## Known Gaps

- `expireLockKey` pattern for post-expiry withdraw/reject edge case (P0)
- `ensure amount > 0.0` on holding templates (P1)
- `LockedSimpleHolding_Unlock` choice for manual lock release (P1)
- `test_publicFetch` dedicated test (P2)
- `tx-kind` metadata annotations (P2)

## License

See `LICENSE` for details.
