# Canton Network Token Standard (CIP-056)

Minimal, secure implementation of the Canton Network Token Standard in DAML and Haskell.

## Architecture

```
Package A  – Interfaces/wrappers (no business templates)
Package B  – Registry implementation templates and helper logic
Package C  – Test scripts and fixtures
Service D  – Haskell off-ledger API adapter (OpenAPI, /v1/ endpoints)
```

### On-Ledger (DAML)

- `Holding`, `TransferFactory`, `TransferInstruction`
- `AllocationFactory`, `Allocation`
- Offer-accept transfer path, direct allocation with deterministic result types

### Off-Ledger (Haskell)

OpenAPI-aligned HTTP service exposing:
- metadata v1
- transfer-instruction v1
- allocation-instruction v1
- allocations v1

### Tests

- Daml Script tests for transfer and allocation lifecycle
- Multi-leg DvP scenario
- Integration tests for disclosure/context with JSON API submission
- Negative tests: stale deadlines, unauthorized actors, contention

## Status

Planning phase. See `PLAN.md` for scope and work breakdown.

## License

See `LICENSE` for details.
