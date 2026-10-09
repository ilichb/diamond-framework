# `integrations/avalanche/contracts/` — On-chain protocol code

Status: **two implementations**. `AVIPRegistry.sol` (milestone M1) and
`AVIPValidatorManager.sol` (milestone M2) are written and tested. The only file
here without an implementation is `interfaces/IZKThresholdVerifier.sol`: the
threshold proof is still verified against a test double. See
[`docs/architecture/implementation-plan.md`](../../../docs/architecture/implementation-plan.md)
and [`docs/architecture/avalanche-integration.md`](../../../docs/architecture/avalanche-integration.md).

## Contents

| Path | Status | Milestone |
|------|--------|-----------|
| `AVIPRegistry.sol` | **Implemented + tested** (`../test/AVIPRegistry.t.sol`, 32 tests) | M1, amended in M2 |
| `AVIPValidatorManager.sol` | **Implemented + tested** (`../test/AVIPValidatorManager.t.sol`, 34 tests) | M2 |
| `interfaces/IAVIPRegistry.sol` | Implemented (provisional types, real signatures) | M1, amended in M2 |
| `interfaces/IAVIPValidatorManager.sol` | Implemented (provisional types, real signatures) | M2 |
| `interfaces/IZKThresholdVerifier.sol` | Interface only — no implementation | M3 |
| `verifiers/` | **Not implemented** | M3 |

### What `AVIPRegistry` fixes

- **Merkle convention**: leaf hash `keccak256(abi.encodePacked(leaf))`, pair
  hash over the sorted pair (so a proof needs no direction bits), and the root
  of a single-leaf tree is that leaf's hash.
- **Freshness rule** (paper, Data Layer): an epoch cannot differ from the
  previous one by more than `gamma * N = 0.10 * 500 = 50` entries. The bound is
  checked against the delta the sequencer *declares*; the registry never stores
  the tensor.
- **`verifyThreshold` certifies a norm, it does not compare it.** Since M2 it is
  `view` and takes `(epoch, certifiedNorm, proof)`: it builds the statement
  `[root, epoch, certifiedNorm]` from its own state (so a caller cannot inject a
  public input) and returns whatever
  `IZKThresholdVerifier.verify(a, b, c, input)` returns. Enforcing
  `||T||_F >= Theta_r` is the manager's job (§5.2.2 of the plan), which keeps
  economic parameters out of the circuit and the trusted setup. With no proof in
  the blob the registry reverts with `InvalidZKProof`.
- **Not covered here**: the data layer's fraud proof, the pairing check (the
  verifier is mocked) and the admission rule, which lives in
  `AVIPValidatorManager`. See the header of `../test/AVIPRegistry.t.sol` and
  [`docs/architecture/implementation-plan.md`](../../../docs/architecture/implementation-plan.md) §5.

### What `AVIPValidatorManager` fixes

- **Hybrid admission** `CoA = S_f + C_R(T) >= Theta`, with the paper's closed
  forms: `C_R(r) = 0.8 * r / (1 + r)` and
  `S_f*(T) = max{0.2, 1.0 - C_R(||T||_F)}`. All arithmetic is WAD (`1e18`) and
  integer-only; `THETA = 1e18` (Payment Rule, frozen at genesis), `CR_INF = 8e17`
  and `S_MIN = 2e17` (`verification/mechanism/financial_floor_sensitivity.py`),
  `THETA_R = 5e17` (ZK section, `[CONJECTURE]`, enforced **here** and not in the
  registry), `F0_STAR = 5e16` (main.tex §6.4). Every constant carries its
  provenance in the contract's NatSpec.
- **The norm is certified, never trusted.** `admit(validator, financialStake,
  certifiedNorm, proof)` rejects a caller-declared norm below `THETA_R` and then
  has `AVIPRegistry.verifyThreshold` certify that exact value against the current
  epoch's root. The proof binds the pair `(norm, epoch)`.
- **Non-custodial** (plan §5.2.3): the manager declares `financialStake`, stores
  it and emits it; it never transfers or holds a token. There is no ERC-20 and no
  native-value path.
- **Slashing is authority-only and bounded**, and it revokes the admission: when
  the remaining stake drops below that validator's `requiredStake`, the validator
  is ejected (`ValidatorEjected`). The stake is not zeroed, because there is
  nothing to seize.
- **Not covered here**: token custody/transfer, removal from the validator set,
  weight recomputation and reward distribution — those are M4/M7.

The names `AVIPRegistry` and `AVIPValidatorManager` come from the target
architecture (`docs/architecture/avalanche-integration.md` §1–§2), which
specifies both contracts and states that they are *not yet implemented*.

## Interfaces are provisional

The interface files exist to fix the **types** of the contract boundary before
any logic is written. M1 and M2 have landed against them, so their signatures are
now the real ones; the wording "provisional" only means a signature change is
still not a breaking change while nothing is deployed.

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
