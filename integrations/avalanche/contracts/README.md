# `integrations/avalanche/contracts/` — On-chain protocol code

Status: **one implementation**. `AVIPRegistry.sol` (milestone M1) is written and
tested; everything else here is still an interface. See
[`docs/architecture/implementation-plan.md`](../../../docs/architecture/implementation-plan.md)
and [`docs/architecture/avalanche-integration.md`](../../../docs/architecture/avalanche-integration.md).

## Contents

| Path | Status | Milestone |
|------|--------|-----------|
| `AVIPRegistry.sol` | **Implemented + tested** (`../test/AVIPRegistry.t.sol`) | M1 |
| `interfaces/IAVIPRegistry.sol` | Interface (provisional) | M1 |
| `interfaces/IAVIPValidatorManager.sol` | Interface (provisional) | M2 |
| `interfaces/IZKThresholdVerifier.sol` | Interface (provisional) | M3 |
| `AVIPValidatorManager.sol` | **Not implemented** | M2 |
| `verifiers/` | **Not implemented** | M3 |

### What `AVIPRegistry` fixes

- **Merkle convention**: leaf hash `keccak256(abi.encodePacked(leaf))`, pair
  hash over the sorted pair (so a proof needs no direction bits), and the root
  of a single-leaf tree is that leaf's hash.
- **Freshness rule** (paper, Data Layer): an epoch cannot differ from the
  previous one by more than `gamma * N = 0.10 * 500 = 50` entries. The bound is
  checked against the delta the sequencer *declares*; the registry never stores
  the tensor.
- **Not covered here**: the data layer's fraud proof, the pairing check and the
  admission rule. See the header of `../test/AVIPRegistry.t.sol` and
  [`docs/architecture/implementation-plan.md`](../../../docs/architecture/implementation-plan.md) §5.1.

The names `AVIPRegistry` and `AVIPValidatorManager` come from the target
architecture (`docs/architecture/avalanche-integration.md` §1–§2), which
specifies both contracts and states that they are *not yet implemented*.

## Interfaces are provisional

The interface files exist to fix the **types** of the contract boundary before
any logic is written. Function signatures may change when the implementation
lands; a signature change is not a breaking change while nothing is deployed.

## Project layout

This directory is the `src` of the Foundry project rooted at
`integrations/avalanche/` (`foundry.toml` there). The gas benchmarks under
`../benchmarks/` are a **separate** Foundry project and are not compiled here.

## Build and test

```shell
cd integrations/avalanche
forge build
forge test
```

## Anchor boundary

Nothing under `integrations/` belongs to the ten files sealed in
`verification/anchor_root.sha256`, so building and testing here does not
invalidate the repository anchor. Do not add scripts to, or run,
`verification/run_all.sh` from here: that regenerates
`verification/output_manifest.txt`, which **is** part of the anchor.

## Rule from `CONTRIBUTING.md`

Code in `integrations/avalanche/` is merged only with unit tests **and** an
explicit statement of what is tested and what is not.
