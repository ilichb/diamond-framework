# Avalanche Integration

## Scope

This document describes how the Diamond Framework integrates with the
Avalanche network. It complements the paper sections on the zero-
knowledge proof (Section 4) and the evaluation (Section 9). The
integration is specified but not yet deployed to a live network. The
benchmarks reported here are local.

**Status of the code.** The repository contains the gas benchmarks
(`integrations/avalanche/benchmarks/`) and the three implemented pieces of the
protocol, each with its unit tests: `AVIPRegistry.sol` (milestone M1),
`AVIPValidatorManager.sol` (milestone M2) and the on-chain Groth16 verifier
`verifiers/Bn254.sol` + `verifiers/Groth16Verifier.sol` (milestone M3) — the
verifier runs the pairing check through the `0x06`/`0x07`/`0x08` precompiles,
but against a **placeholder** verifying key: the circuit and its trusted setup do
not exist yet (see §5.4 of [`implementation-plan.md`](implementation-plan.md)).
The deployment scripts, the off-chain prover and the data layer are specified in
this document but not yet implemented. Nothing described here has been deployed
to a live network, and none of it has been audited.

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

1. **Registry and validator manager.** Deploy `AVIPRegistry.sol` and
   `AVIPValidatorManager.sol` to a testnet C-Chain. Verify the
   admission and slashing rules with synthetic reputation data.

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
