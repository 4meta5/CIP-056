# canton-token-template

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

> [!WARNING]
> This software is experimental and not intended for production use. Use at your own risk.

A DAML template for building CIP-056 token registries on the Canton Network. Clone it, run the setup script, start writing contracts.

800 lines of production code implement all 6 CIP-056 on-ledger interfaces. 36 tests cover transfer lifecycle, allocation/DvP, defragmentation, and 20 security invariants. Three verification tools (static analysis, property testing, formal proofs) validate the result.

## Quick Start

```sh
git clone https://github.com/OpenZeppelin/canton-token-template.git && cd canton-token-template
scripts/setup.sh            # checks tools, builds, runs tests
```

Or manually:

```sh
cd simple-token && dpm build
cd ../simple-token-test && dpm build && dpm test
```

`dpm test` requires Java 21. The setup script detects your JAVA_HOME automatically.

## What You Get

```
simple-token/          7 templates implementing 6 CIP-056 interfaces
simple-token-test/     36 tests (9 transfer, 5 allocation, 2 defrag, 20 security)
dars/                  Splice interface DARs + daml-props (committed, no setup needed)
scripts/               setup.sh (bootstrap) and verify.sh (run all verification tools)
docs/                  Design docs: PLAN.md, SCOPE.md, AUDIT.md
```

## Customizing

Rename the token: edit `simple-token/daml.yaml` and `SimpleTokenRules.supportedInstruments`.

Add behavior: the factory's 3-way dispatch (self-transfer, direct, two-step) lives in `Rules.daml`. Allocation/DvP logic is in `Allocation.daml`. Each template maps to one lifecycle state.

Write tests first. The TDD skill enforces RED-GREEN-REFACTOR gates.

## Verification

```sh
scripts/verify.sh     # runs all three tools
```

- [daml-lint](https://github.com/OpenZeppelin/daml-lint) -- static analysis (6 detectors, <1s)
- [daml-props](https://github.com/OpenZeppelin/daml-props) -- property-based testing with shrinking (~30s)
- [daml-verify](https://github.com/OpenZeppelin/daml-verify) -- formal verification via Z3 (~2s)

Install verification tools: `scripts/setup.sh` (without `--skip-verification`).

## Agent Skills

For AI-assisted development with Claude Code or Codex, see [daml-skills](https://github.com/OpenZeppelin/daml-skills.git).

## Prerequisites

- [dpm](https://docs.daml.com) (Digital Asset Package Manager)
- Daml SDK 3.4.10
- Java 21

## Docs

- [docs/SCOPE.md](docs/SCOPE.md) -- what's in scope, what's not, differences from Splice
- [docs/PLAN.md](docs/PLAN.md) -- implementation plan, security invariants, test criteria
- [docs/AUDIT.md](docs/AUDIT.md) -- verification report from three tools

