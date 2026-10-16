# Avalanche Integration

## Scope

This document describes how the Diamond Framework integrates with the
Avalanche network. It complements the paper sections on the zero-
knowledge proof (Section 4) and the evaluation (Section 9). The
integration is specified but not yet deployed to a live network. The
benchmarks reported here are local.

**Status of the code when this note was written.** The repository contains the
gas benchmarks (`integrations/avalanche/benchmarks/`) and the three implemented
pieces of the protocol, each with its unit tests: `AVIPRegistry.sol` (milestone
M1), `AVIPValidatorManager.sol` (milestone M2) and the on-chain Groth16 verifier
`verifiers/Bn254.sol` + `verifiers/Groth16Verifier.sol` (milestone M3) — the
verifier runs the pairing check through the `0x06`/`0x07`/`0x08` precompiles,
but against a **placeholder** verifying key: the circuit and its trusted setup do
not exist yet (see §5.4 of [`implementation-plan.md`](implementation-plan.md)).
The deployment scripts, the off-chain prover and the data layer are specified in
this document but not yet implemented. Nothing described here has been deployed
to a live network, and none of it has been audited.

> **Status since this note was written** (`implementation-plan.md` §5.4–§5.11).
> Every piece the paragraph above calls unimplemented now exists, offline and
> tested: the deployment scripts (`DeployRegistry.s.sol` and
> `DeployValidatorManager.s.sol`, M7a, §5.8 — driven through a committed
> six-case dry run, **not yet run against Fuji**), the off-chain prover (M4,
> §5.5 — **not recursive**: the paper-literal recursion is still open, §5.5.7),
> the RMT detector (M5, §5.6), the data layer's fraud proof and its
> `eq:ingestion` interface (M7b, §5.9), the Pedersen/Poseidon ↔ keccak bridge
> that ties the statement's `root` to the registry's Merkle root (M7c, §5.10)
> and the transport of §4 (M7d, §5.11). The verifying key of M3 is no longer a
> placeholder either: M4b installed a real key over the V3 circuit and the
> unmodified `Groth16Verifier` accepts it (§5.4). The two closing sentences
> still hold — **nothing here is deployed to a live network and nothing has
> been audited** — and §6's four phases remain undone: a Fuji deployment needs
> a funded key and a live endpoint, which no milestone automates.

## 1. Target Architecture

The protocol uses three Avalanche components:

- **Subnet L1 (ACP-77)** for validator management. The Subnet operates
  its own validator set with its own admission rules, following the
  ACP-77 model in which Subnets assume direct responsibility for
  validator management.

- **C-Chain** for the reputation registry and the zero-knowledge
  verifier. The registry stores Merkle roots of the reputation tensor
  and validates proofs of threshold.

- **Teleporter / Avalanche Warp Messaging (AWM)** for cross-subnet
  propagation of reputation commitments and collusion alerts.

```
┌──────────────────────────────────────────────────────────────────┐
│ AVALANCHE PRIMARY NETWORK                                        │
│ ┌────────────────────────────┐ ┌───────────────────────────────┐ │
│ │ C-Chain (EVM)              │ │ P-Chain (Staking)             │ │
│ │ - AVIPRegistry             │ │ - Subnet L1 registration      │ │
│ │ - Groth16 verifier         │ │ - Validator set query         │ │
│ └─────────────▲──────────────┘ └───────────────▲───────────────┘ │
│               │ Teleporter / AWM               │                 │
│ ┌─────────────┴────────────────────────────────┴───────────────┐ │
│ │ ANDROMEDA SUBNET L1                                          │ │
│ │ - Snowman consensus                                          │ │
│ │ - Hybrid validator admission (stake + reputation)            │ │
│ │ - EVM precompiles for ZK verification                        │ │
│ └──────────────────────────────┬───────────────────────────────┘ │
│                                │                                 │
│ ┌──────────────────────────────┴───────────────────────────────┐ │
│ │ OFF-CHAIN PROVER (Rust)                                      │ │
│ │ - Multi-chain event ingestion                                │ │
│ │ - Tensor commitment (Pedersen)                               │ │
│ │ - Bulletproofs proof generation                              │ │
│ │ - Recursive SNARK composition                                │ │
│ └──────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

## 2. ACP-77 Subnet L1

The Subnet L1 is registered on the P-Chain following ACP-77. Validators
are admitted by the Subnet contract, not by the Primary Network. The
admission rule is the hybrid collateral condition of the paper:

    CoA(i) = S_f(i) + C_R(T(i)) ≥ Θ(t)

where S_f is the financial stake and C_R(T) is the reputational
collateral derived from the verified tensor. The threshold Θ(t) is
frozen at genesis for the reference implementation.

The validator manager contract (`AVIPValidatorManager.sol`) enforces
the admission rule and the slashing conditions. The contract does not
store the reputation tensor; it stores the Merkle root and verifies
inclusion proofs for the entries that the admission rule needs.

> **Implemented since this note was written** (milestone M2,
> `implementation-plan.md` §5.2, with two amendments: M8's custody and M9's
> `§12.1.2`): the condition above is `CoA = S_f + C_R(||T||_F) >= Theta` with
> `S_f*(r) = max{0.2, 1.0 - C_R(r)}`, and it is enforced by
> `AVIPValidatorManager.admit` against a norm the registry certified from its own
> committed root. Two things the note above does not say and the code does: a
> re-admission after an ejection must post `S_f*(r) + n_ejections * kappa`, a
> **deployment constant** that the paper names symbolically and gives no value
> (M9c, `§12.1.2`), while the reputational credit `C_R` is untouched by that
> history; and a slash takes the validator's whole recorded stake rather than a
> figure sent with the decision (M9b), so the loss collateralized on-chain is the
> stake that was posted.

## 3. EVM Precompiles and ZK Verification

The zero-knowledge threshold proof of Section 4 is verified on-chain
via the BN254 precompiles. The measured gas costs are:

| Primitive | Gas | Source |
|-----------|-----|--------|
| `ecAdd` (0x06) | 292 | Foundry benchmark |
| `ecMul` (0x07) | 6,142 | Foundry benchmark |
| `ecPairing` k=4 (0x08) | 181,142 | Foundry benchmark |

Groth16 verification uses k = 4 pairings. The total cost of a Groth16
verification is approximately 206k gas (181,142 for the pairing step
plus ~25k for the surrounding logic).

The protocol adopts the recursive SNARK composition of Section 4.4.
The Bulletproofs verification is performed off-chain; the recursive
SNARK attests that the verification was correct. Only the recursive
proof is posted on-chain, at a cost of approximately 250k gas.

## 4. Teleporter / AWM

Reputation commitments and collusion alerts are propagated across
subnets via Teleporter over Avalanche Warp Messaging. The messages
are signed by BLS signatures at the consensus level.

Three message types are defined:

- **Commitment propagation.** When a new reputation tensor is
  committed on a source chain, a message propagates the Merkle root
  to the Andromeda Subnet and to any other subnet that has subscribed.

- **Collusion alert.** When the RMT test of Section 5 flags a clique
  or a bipartite structure, a message reduces the effective voting
  weight of the flagged validators across all subscribed subnets.

- **Slashing notification.** When a fraud proof succeeds in the data
  layer of Section 7, a message propagates the slashing event to all
  subnets where the slashed validator is registered.

> **Implemented since this note was written** (milestone M7d,
> `implementation-plan.md` §5.11): the wire format of these three messages and one
> contract per type live in `contracts/AVIPMessageCodec.sol`,
> `AVIPCommitmentRelay.sol`, `AVIPCollusionAlertChannel.sol` and
> `AVIPSlashingChannel.sol`, with the origin allowlist and the replay rule in
> `AVIPMessageEndpoint.sol`, and the transcript is
> `scripts/m7d_output.txt`. Read §5.11 for what that does and does not claim:
> nothing is deployed, no BLS signature or source-chain quorum is exercised, the
> transport carries no funds, and the "voting weight" this section names is a rule
> for a validator set that does not exist on-chain here.

> **Amended in M9b** (§12.1.2, `implementation-plan.md` §5.13): the slashing
> notification carries the fraud proof's outcome — the validator, the epoch, the
> ingestion digest and the two values that disagree — and **no amount**. The stake
> a validator loses is the whole record that the destination's own manager holds
> (`AVIPValidatorManager.slash(address,bytes32)`), so the quantity the paper's §7.4
> writes as `L` is derived where the record is rather than transported across
> subnets: the type-3 payload shrank by one field and M2's `SlashExceedsStake` went
> with it. What the subnets share is the *fact* of the fraud; what each of them
> seizes is its own book.

## 5. Data Layer

The data layer operates per Section 7. Entries of the reputation
tensor are derived from consensus events on source chains. The
transport uses state inclusion proofs against signed headers of the
source chains. Each source chain requires either a light client or
a zero-knowledge bridge.

The freshness parameter γ bounds the propagation of undetected fraud
across epochs. For the reference implementation γ = 0.10.

## 6. Deployment Phases

The integration proceeds in four phases:

1. **Registry, validator manager and stake vault.** Deploy `AVIPRegistry.sol`,
   `AVIPValidatorManager.sol` and the custody the manager binds —
   `AVIPStakeVault.sol`, milestone M8 (§5.12) — to a testnet C-Chain, in that
   order: the vault is deployed first because it cannot know the manager's address,
   and the manager's constructor fills that hole and verifies it. Verify the
   admission and slashing rules with synthetic reputation data, and the fund
   movements (escrow, slash, `F_0*`) against a test deployment of an `IFundSink`.
   The scripts are `DeployRegistry.s.sol`, `DeployValidatorManager.s.sol` (with
   `CUSTODY`) and `DeployStakeVault.s.sol`; none of them is automated against a
   live network. `DeployRegistry.s.sol` resolves three roles and not two: beside
   `SEQUENCER` and `VERIFIER` it takes `GUARDIAN`, the only account allowed to
   *propose* a change to either of the other two. Anybody may then execute that
   change once the registry's `CHANGE_DELAY` (two days) has elapsed, which is what
   keeps the sitting sequencer from being the only key able to replace itself; a
   zero `GUARDIAN`, or one equal to the `SEQUENCER`, is refused before anything is
   deployed.

2. **Off-chain prover.** Implement the Pedersen commitment and the
   Bulletproofs proof generation in Rust. Integrate the recursive
   SNARK composition.

3. **RMT detector.** Implement the modularity-spectrum test with the
   empirically calibrated thresholds. Connect to the event indexer.

4. **Subnet L1.** Deploy the Andromeda Subnet L1 on a testnet with
   the hybrid consensus rules. Run stress and chaos tests.

## 7. Benchmarks Pending

Two benchmarks require a live deployment and are not reported:

- **Recursive SNARK proving time.** Measurable locally once the
  recursive circuit is implemented. Not done in this paper.
- **Teleporter latency.** Requires a live subnet. Not measurable
  without a testnet deployment.

The protocol for measuring these is defined in the repository. The
results will be added to the Evaluation section of
`docs/paper/main.tex` when available.
