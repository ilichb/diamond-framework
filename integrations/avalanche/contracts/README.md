# `integrations/avalanche/contracts/` — On-chain protocol code

Status: **skeleton**. This directory contains the interfaces only; the
implementations are not written yet. See
[`docs/architecture/implementation-plan.md`](../../../docs/architecture/implementation-plan.md)
and [`docs/architecture/avalanche-integration.md`](../../../docs/architecture/avalanche-integration.md).

## Contents

| Path | Status | Milestone |
|------|--------|-----------|
| `interfaces/IAVIPRegistry.sol` | Interface (provisional) | M1 |
| `interfaces/IAVIPValidatorManager.sol` | Interface (provisional) | M2 |
| `interfaces/IZKThresholdVerifier.sol` | Interface (provisional) | M3 |
| `AVIPRegistry.sol` | **Not implemented** | M1 |
| `AVIPValidatorManager.sol` | **Not implemented** | M2 |
| `verifiers/` | **Not implemented** | M3 |

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
