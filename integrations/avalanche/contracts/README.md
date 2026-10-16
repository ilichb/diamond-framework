# `integrations/avalanche/contracts/` — On-chain protocol code

Status: **four implementations, plus the M7d transport and the M8 custody pair**.
`AVIPRegistry.sol` (milestone M1) and `AVIPValidatorManager.sol` (milestone M2) are
written and tested, and M3 adds `verifiers/Bn254.sol` (library) plus
`verifiers/Groth16Verifier.sol`. M7d adds the Teleporter/AWM transport of
`avalanche-integration.md` §4: `AVIPMessageCodec.sol` (the wire format) and
`AVIPMessageEndpoint.sol` (the shared boundary) with one contract per message type.
M8 adds the funds half of `§5.2.3`: `AVIPStakeVault.sol` (escrow behind
`IAVIPCustody`), `AVIPBurnSink.sol` (the reference `IFundSink`) and a third
constructor argument on `AVIPValidatorManager` — with `custody == address(0)` the
manager is the original M2, unchanged.
The only file here without an implementation is
`interfaces/IZKThresholdVerifier.sol`: the interface is real and `Groth16Verifier`
implements it, but nothing is deployed. See
[`docs/architecture/implementation-plan.md`](../../../docs/architecture/implementation-plan.md)
and [`docs/architecture/avalanche-integration.md`](../../../docs/architecture/avalanche-integration.md).

## Contents

| Path | Status | Milestone |
|------|--------|-----------|
| `AVIPRegistry.sol` | **Implemented + tested** (`../test/AVIPRegistry.t.sol`, 48 tests) | M1, amended in M2 (decode), M3 (`Bn254.decodeProof`) and M9a (the authority pair) |
| `AVIPValidatorManager.sol` | **Implemented + tested** (`../test/AVIPValidatorManager.t.sol`, 37 tests; amended in M8, whose custody path is covered by `../test/M8StakeVault.t.sol`) | M2, amended in M8 and M9b/M9c (the derived slash amount, the ejection surcharge) |
| `interfaces/IAVIPRegistry.sol` | Implemented (provisional types, real signatures) | M1, amended in M2, M9a (`guardian`, `CHANGE_DELAY`, `propose*`/`execute*`/`cancel*` and the events they emit) |
| `interfaces/IAVIPValidatorManager.sol` | Implemented (provisional types, real signatures) | M2, amended in M8 (`custody()`, `FinancialStakeNotBacked`, `CustodyNotBound`) and M9b (`slash(address,bytes32)`, `NothingToSlash` for `SlashExceedsStake`) |
| `interfaces/IZKThresholdVerifier.sol` | Implemented by `verifiers/Groth16Verifier.sol` | M3 |
| `interfaces/ITeleporterMessenger.sol` | Declared (the subset M7d calls, verbatim from `icm-contracts`) | M7d |
| `interfaces/ITeleporterReceiver.sol` | Declared (verbatim from `icm-contracts`), implemented by `AVIPMessageEndpoint.sol` | M7d |
| `interfaces/IAVIPCustody.sol` | Implemented by `AVIPStakeVault.sol` (one read, one manager-only write, plus the bind) | M8 |
| `interfaces/IFundSink.sol` | Implemented by `AVIPBurnSink.sol`; a deployment that keeps the funds implements it too | M8 |
| `interfaces/IERC20Minimal.sol` | Declared (three functions, no metadata), deliberately not OpenZeppelin's | M8 |
| `interfaces/IERC20BurnableMinimal.sol` | Declared (the one function the reference sink adds) | M8 |
| `verifiers/Bn254.sol` | **Implemented + tested** (`../test/Bn254.t.sol`, 16 tests) | M3 |
| `verifiers/Groth16Verifier.sol` | **Implemented + tested** (`../test/Groth16Verifier.t.sol`, 18 tests) | M3 |
| `AVIPStakeVault.sol` | **Implemented + tested** (`../test/M8StakeVault.t.sol`) | M8 |
| `AVIPBurnSink.sol` | **Implemented + tested** (`../test/M8StakeVault.t.sol`, the reference sink) | M8 |
| `AVIPMessageCodec.sol` | **Implemented + tested** (`../test/M7dTransport.t.sol`, 48 tests over the whole milestone) | M7d |
| `AVIPMessageEndpoint.sol` | **Implemented + tested** (abstract: the messenger check, the allowlist, the nonce guard, the sending) | M7d |
| `AVIPCommitmentRelay.sol` | **Implemented + tested** — §4's message type 1 | M7d |
| `AVIPCollusionAlertChannel.sol` | **Implemented + tested** — §4's message type 2 | M7d |
| `AVIPSlashingChannel.sol` | **Implemented + tested** — §4's message type 3 | M7d |


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
- **A role cannot rotate itself (M9a, plan §12.1.2).** The constructor takes an
  immutable `guardian` and `setSequencer`/`setVerifier` are gone. Each role now
  changes in three steps: `propose*` is `onlyGuardian`, rejects `address(0)` and
  arms `eta = now + CHANGE_DELAY`; `execute*` is **permissionless** and commits
  only once `eta` has elapsed; `cancel*` returns to the guardian. Every step
  emits (`SequencerProposed`/`Changed`/`ChangeCancelled` and the `Verifier`
  triple). `CHANGE_DELAY = 2 days` is a **deployment constant, not a model
  parameter** (§6): it is the window in which a rotation is visible, while the
  second authority is what makes it effective — the sitting sequencer can
  neither rotate itself nor veto the proposal that replaces it, and the guardian
  alone cannot install a key without the delay passing first. The guardian must
  differ from the sequencer (`RolesCollapsed`), since one key holding both would
  propose its own continuation and the delay would only announce it.
- **The verifier stays mutable on purpose.** `setVerifier`'s `address(0)` hole is
  gone, but the slower `propose*`/`execute*` path replaces it rather than freezing
  it: this registry is also the commitment history (`_roots`, `_changedEntries`)
  that `admit` reads back, so a frozen verifier would turn a circuit bug into a
  redeploy that loses the history.
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
- **Slashing is authority-only, unbounded in amount and *always* ejects (M9b, plan
  §12.1.2).** `slash(address validator, bytes32 reason)` takes **the whole stake on
  record** — the amount is derived, never transported — so there is no amount to
  bound and M2's `SlashExceedsStake` is gone with the argument. The argument was a
  remote parameter: the transported value and `stakeOf` could disagree, and the
  check existed only to reconcile them. A validator with nothing on record reverts
  `NothingToSlash`. Since the amount equals the record and `S_f* >= S_min > 0`, the
  slash always revokes the admission (`ValidatorEjected`, with the empty record it
  leaves behind).
- **Re-entry is priced by history (M9c, plan §12.1.2).** Every ejection increments a
  per-validator counter that is never reset, and the next `admit` requires
  `S_f*(certifiedNorm) + ejections * EJECTION_SURCHARGE` (**κ**, `0.1` in WAD). The
  surcharge is a **separate term**, not an inflation of `S_f*`: `Theta - S_f*` is the
  collateral the norm earns, so inflating it would make that credit shrink with the
  validator's history and go negative for a serial ejectee. `collateralOf` therefore
  recovers the norm's image from the two stored numbers (the count cannot move while
  a validator is admitted, since an ejection revokes the admission in the same call)
  and reports the same credit at every re-admission. The reason a requirement is
  larger is observable: `AdmissionEvaluated` carries the surcharge. κ is a
  **deployment constant with no paper value** (§6), which is why
  `../scripts/DeployValidatorManager.s.sol` asserts and reports it rather than any
  `verification/` script doing so.

- **Not covered here**: token custody/transfer and fund movement (M8, the Treasury
  Module), removal from the validator set, weight recomputation and reward
  distribution (M6/M7).
The names `AVIPRegistry` and `AVIPValidatorManager` come from the target
architecture (`docs/architecture/avalanche-integration.md` §1–§2), which
specified both contracts and, when written, stated that they were *not yet
implemented*; that note's §*Status of the code* carries the update, and the
contracts below are what it was waiting for.

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
still not a breaking change while nothing is deployed. M7d's two Teleporter
interfaces are provisional in a stronger sense: they are transcribed from an
external project (`ava-labs/icm-contracts`) that this repository does not vendor,
so nothing here compiles against the real `TeleporterMessenger` — the whole
milestone is validated offline against `../test/mocks/MockTeleporterMessenger.sol`
(see plan §5.11).

## What the M7d transport fixes (message types 1-3 of §4)

`docs/architecture/avalanche-integration.md` §4 names three messages and nothing
more. M7d fixes what they are on the wire and what each one does on arrival:

- **The envelope carries a nonce, because AWM does not hand one to a receiver.**
  `ITeleporterReceiver.receiveTeleporterMessage(sourceChain, originSender, payload)`
  has no nonce and no message id, and a solver may re-deliver a message whose
  execution failed. Every AVIP message is therefore
  `abi.encode(kind, nonce, payload)`, and each endpoint keeps its own
  `(sourceChain, originSender, nonce)` set: **at most one delivery per message**,
  which is the only thing standing between a re-delivery and a second slash. The
  envelope is also checked to be the canonical encoding of what it decodes to, so
  two encodings of one message cannot exist.
- **One contract per message type, and one allowlist per type.** A commitment
  relay, a collusion-alert channel and a slashing channel; each answers for exactly
  one `kind` (enforced at construction) and each holds a
  `sourceChain → originSender` allowlist fixed by its constructor. There is no
  setter, in the same spirit as M2's `slashAuthority`: "who may slash this subnet"
  is a deployment fact, not a governance surface. An empty allowlist is allowed and
  means "this deployment receives nothing", which is how a send-only chain is wired.
- **What each type records.** A commitment is recorded once per `(source, epoch)`
  — root, statement root, link and delta, with the epoch's root read from
  `AVIPRegistry` rather than from the caller, and the link re-derived from the
  payload's own words on arrival. A collusion alert records the two tail decisions
  and the calibration they were decided against, once per epoch, so the flag set
  only grows. A slashing notification calls `AVIPValidatorManager.slash` with a
  `reason` **derived from the envelope** (`keccak256(sourceChain ‖ nonce)`), so no
  sender chooses the provenance id an auditor recomputes — and with **no amount**,
  which left the payload in M9b (§12.1.2): the record the destination's manager
  holds is what a slash takes, so the number a unit of the protocol loses is the
  destination's own book rather than a sender's claim about it.
- **The tie is carried, not proven.** M7c's link travels in the commitment message
  and is re-checked at both ends (`link == linkDigest(merkleRoot, statementRoot,
  epoch)`), which is the property §5.10 decided: off-chain and recomputable by any
  peer, with nothing learned by a peer that holds only the message.
- **Not claimed:** no Teleporter latency, no BLS or source-chain quorum, no fee, no
  on-chain voting weight behind an alert (M2's manager carries none, §5.2), and no
  claim that what a channel carries is *true* — soundness lives in M7b's fraud
  proof and in the data layer, not in the transport. Nothing is deployed.


## What M8 fixes (custody of `financialStake`, §5.12)

`docs/architecture/implementation-plan.md` §5.2.3 closed with M2's own limit: it
"does not implement token custody or transfer; that is delegated to the M8 Treasury
Module". M8 supplies it and leaves the one undecided fact a deployment fact:

- **Escrow, reported in WAD.** `AVIPStakeVault` accounts in the token's own base
  units and reports in WAD (`escrowed`), so every comparison against `stakeOf` is
  unit-clean. `WAD_PER_UNIT = 10 ** (18 - decimals)` is a constructor argument,
  because `decimals()` is a non-standard call the custody path never makes.
- **Admission bound to custody.** With a custody configured, `admit` additionally
  requires `financialStake <= escrowed(validator)` (`FinancialStakeNotBacked`), so
  what the manager admits is what its own `slash` can later take. With
  `custody == address(0)` the manager is the original M2 and checks no balance.
- **A slash that moves funds, atomically.** `slash` writes its record and *then*
  calls `custody.debit(validator, amount, reason)` in the same transaction: a
  failing token or a refusing sink reverts both, so record and escrow cannot
  diverge. Since M9b the amount is that record **in full** (§12.1.2), and its floor
  in base units can never exceed the escrow `admit` demanded of the same record —
  the rounding can only leave the vault holding more than the record.
- **The destination is a deployment fact (`D-M8-0`).** The vault transfers to a
  constructor-fixed `IFundSink` and *then* notifies it with the amount and a
  derived reason. `AVIPBurnSink` is the reference choice (destroy them through the
  token's own `burn`, no treasury and no key to spend them); a deployment that
  retains the funds implements the same interface.
- **The fee never touches the vault.** `payFee` charges its own caller `F_0*` and
  pulls it straight from the payer's balance to the sink; there is no per-epoch
  ledger here, because charging once per epoch is the caller's policy.
- **The handshake, and the one hole.** The vault cannot know the manager's address
  and the manager cannot know the vault's, so the vault is deployed first and its
  `bindManager()` is filled exactly once by the manager's constructor, which then
  verifies `manager() == address(this)`. A vault bound by somebody else, or a
  custody that reports nobody, **fails the manager's deployment** instead of
  producing a manager wired to nothing.
- **Not covered here:** interest, rewards or yield; a second token; an owner,
  pause, upgrade or setter (the constructor facts and the one-shot bind are the
  whole mutable surface); an exit queue; governance of the sink; fee-on-transfer
  or rebasing tokens (refused with `InexactTransfer`); a supply claim for the burn
  (the token decides what `burn` means, and `BurnFailed` is reported when it
  cannot); and any on-chain execution of the paper's `S_slash = 10`, which stays a
  *model* parameter: what a slash moves is the whole record, and §12.1.2 (M9b) is
  why no transported figure decides it. Nothing is deployed.


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
