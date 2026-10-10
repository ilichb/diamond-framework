# `integrations/avalanche/contracts/` — On-chain protocol code

Status: **four implementations**. `AVIPRegistry.sol` (milestone M1) and
`AVIPValidatorManager.sol` (milestone M2) are written and tested, and M3 adds
`verifiers/Bn254.sol` (library) plus `verifiers/Groth16Verifier.sol`. The only
file here without an implementation is `interfaces/IZKThresholdVerifier.sol`:
the interface is real and `Groth16Verifier` implements it, but nothing is
deployed. See
[`docs/architecture/implementation-plan.md`](../../../docs/architecture/implementation-plan.md)
and [`docs/architecture/avalanche-integration.md`](../../../docs/architecture/avalanche-integration.md).

## Contents

| Path | Status | Milestone |
|------|--------|-----------|
| `AVIPRegistry.sol` | **Implemented + tested** (`../test/AVIPRegistry.t.sol`, 32 tests) | M1, amended in M2 (decode) and M3 (`Bn254.decodeProof`) |
| `AVIPValidatorManager.sol` | **Implemented + tested** (`../test/AVIPValidatorManager.t.sol`, 34 tests) | M2 |
| `interfaces/IAVIPRegistry.sol` | Implemented (provisional types, real signatures) | M1, amended in M2 |
| `interfaces/IAVIPValidatorManager.sol` | Implemented (provisional types, real signatures) | M2 |
| `interfaces/IZKThresholdVerifier.sol` | Implemented by `verifiers/Groth16Verifier.sol` | M3 |
| `verifiers/Bn254.sol` | **Implemented + tested** (`../test/Bn254.t.sol`, 16 tests) | M3 |
| `verifiers/Groth16Verifier.sol` | **Implemented + tested** (`../test/Groth16Verifier.t.sol`, 18 tests) | M3 |

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
- **Not covered here**: the data layer's fraud proof and the admission rule,
  which lives in `AVIPValidatorManager`. The blob is decoded by
  `Bn254.decodeProof` (M3); the pairing itself is `Groth16Verifier`. See the
  header of `../test/AVIPRegistry.t.sol` and
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
- **Not covered here**: token custody/transfer and fund movement (M8, the Treasury
  Module), removal from the validator set, weight recomputation and reward
  distribution (M6/M7).

The names `AVIPRegistry` and `AVIPValidatorManager` come from the target
architecture (`docs/architecture/avalanche-integration.md` §1–§2), which
specifies both contracts and states that they are *not yet implemented*.

### What M3 fixes (`verifiers/`)

- **`Bn254.sol` is a wrapper, not a curve implementation.** It encodes input for
  the EIP-196/EIP-197 precompiles (`0x06` `ecAdd`, `0x07` `ecMul`, `0x08`
  `ecPairing`) and decodes the proof blob. It does not implement field or group
  arithmetic, so a reviewer does not have to audit a BN254 library.
- **The identity is handled before the precompile.** EIP-196 has no encoding for
  the point at infinity (`(0, 0)` is off-curve, so `0x06`/`0x07` would fail), and
  `e(O, Q) = 1`, so `Groth16Verifier` drops any pair containing the identity
  instead of pushing a malformed G1 point. This is what makes an identity `a`
  (possible in a real proof) verify rather than revert.
- **`Fp2` is reordered exactly once.** A prover emits `pi_b = [[x0, x1],
  [y0, y1]]` in the natural order `(real, imaginary)`; EIP-197 wants the
  imaginary coefficient first. The swap lives in `Bn254.pushPair` and nowhere
  else, so the test vector in `../test/Bn254.t.sol` pins it.
- **The Verifying Key is installed in the constructor**, not baked into the byte
  code, so the same contract can be deployed for a new trusted setup. The
  constructor validates `alpha`, `beta`, `gamma`, `delta` and every `vk_x` on the
  curve (a key with an off-curve point reverts with `PrecompileFailed`), and
  `verifyingKeyDigest()` exposes `keccak256` of the installed key so a deployment
  can be checked against the ceremony transcript.
- **A rejected proof returns `false`; a malformed one reverts.** `verify` follows
  the circom convention: a well-formed proof of another equation (or the wrong
  statement) is a `false` verdict, while a non-canonical coordinate, an off-curve
  point or a wrong-length statement is a revert with a named error. Note the
  asymmetry documented in `Bn254`: `0x08` on a rejected input **consumes the
  whole gas budget**, so a caller must not treat "out of gas" as a `false`.
- **The public inputs are the registry's, and the fixture is a placeholder.** The
  statement is `[root, epoch, certifiedNorm]` built by `AVIPRegistry`; nothing
  else is read from the caller. `../test/fixtures/Groth16Fixtures.sol` is a
  **synthetic** BN254 instance produced by
  `../scripts/generate_groth16_fixtures.py` (see its header for what that does and
  does not prove): it exercises the verifier against the real precompiles, but it
  is not a circuit, has no witness and makes no soundness claim. Replacing it with
  a proof from the real circuit is a re-generation, not a rewrite: only the
  Verifying Key and the fixture change.

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
