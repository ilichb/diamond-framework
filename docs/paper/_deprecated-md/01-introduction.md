# 1. Introduction

## 1.1 The Validator Trust Gap

Proof-of-stake networks secure their consensus by requiring validators
to lock financial collateral. Slashing conditions make misbehavior
costly, and the resulting cryptoeconomic security guarantees are well
formalized. This mechanism has proven effective. It has also produced
a structural tension.

High stake requirements deter honest but capital-constrained
participants, concentrating validation power in the hands of large
token holders. Low requirements expose the network to Sybil attacks
and near-zero-cost misbehavior. The tension is not a design flaw of
any particular protocol; it is a consequence of using a single
instrument — financial capital — to serve two purposes simultaneously:
deterrence and admission.

In proof-of-work networks, physical capacity constraints (hardware,
energy, cooling) act as a natural brake on centralization. A miner
with a technological advantage cannot expand indefinitely without
facing diminishing returns on capacity. In proof-of-stake networks
the collateral is purely financial and does not face an equivalent
physical brake. The resulting concentration dynamics can be
self-reinforcing.

## 1.2 Reputation as Partial Collateral

The Diamond Framework introduces a second instrument to the admission
decision: verifiable, non-transferable reputation. A validator with a
long history of contributions faces a large opportunity cost if it
misbehaves, because destruction of its reputation eliminates future
income streams. This opportunity cost can serve as partial collateral,
reducing the financial barrier for honest participants without
degrading the Cost of Attack that secures the network.

Making this intuition rigorous requires solving several problems:

1. **Stochastic modeling.** Reputation evolves continuously and is
   subject to abrupt downward shocks. The dynamics must remain in
   their positive domain under all admissible shocks.

2. **Verifiability.** Reputation claims must be cryptographically
   verifiable without revealing the underlying tensor and without
   relying on a centralized oracle.

3. **Collusion resistance.** Validators may coordinate to inflate
   each other's reputation. The detection mechanism must be robust to
   heavy-tailed interaction graphs and must have a stated boundary
   below which detection is information-theoretically impossible.

4. **Incentive compatibility.** The mechanism must ensure validators
   report their true reputation, or — if reputation is publicly
   verified — must make the reporting question vacuous.

5. **Data integrity.** The reputation signal is derived from
   consensus events on source chains. The transport of these events
   must be verifiable, and fraud must be detectable and deterred.

The Diamond Framework addresses all five.

## 1.3 Contributions

The paper makes four contributions.

**A cryptoeconomic protocol.** We present a validator admission rule
in which financial stake and reputational collateral are partial
substitutes. The rule is CoA(i) = S_f(i) + C_R(T(i)) ≥ Θ(t), where
C_R(T) is the reputational collateral derived from a verified
reputation tensor T. The protocol includes the reputation dynamics,
the collusion test, the payment rule, the data layer, and the
bootstrap simulation.

**A numerical verification suite.** Every quantitative claim in the
paper is paired with a script that reproduces it. The scripts are
self-contained, depend only on NumPy and SciPy, and declare their
seeds and sample sizes. The suite covers stochastic simulation,
spectral calibration, game-theoretic equilibrium, and EVM gas
benchmarks. Claims without scripts are labeled as conjectures.

**A falsification log.** During development, eighteen quantitative
claims were made, tested, and either confirmed or corrected. The
corrections include a fabricated simulation figure, a mismeasurement
of a gas cost, a factor of two in an integral, a rounding rule that
shifted a phase transition, and an unverified projection of a
multidimensional type. The log is part of the paper's record, not a
supplement to it.

**Design decisions with explicit boundaries.** Where the protocol
cannot deliver a guarantee — for adversaries that are not rational,
for collusion below the Kesten-Stigum boundary, for real reputation
data that is not available — the paper states the boundary and does
not claim the guarantee. The limitations section separates
methodological limits (the numerical methods could be improved) from
design limits (the protocol does not solve these problems even with
perfect methods).

## 1.4 Paper Structure

Section 2 presents the reputation dynamics: a CIR diffusion with
multiplicative downward jumps, the positivity proof, and the exact
mean first-passage time.

Section 3 introduces the tensor representation and the Tucker
compression, and shows that the compression fails for block
structure while remaining useful for low-rank tensors.

Section 4 specifies the zero-knowledge threshold proof. The original
circuit is unsound; the repair uses a Pedersen commitment with
Bulletproofs and recursive SNARK composition. The EVM precompile
costs are measured locally.

Section 5 develops the collusion detection. The modularity matrix
B = W − ddᵀ/(2m) replaces the normalized adjacency matrix A_sym. The
null quantile is calibrated by Monte Carlo, and the detection boundary
is characterized.

Section 6 specifies the payment rule: a saturated uniform posted
price. Incentive Compatibility is tautological because reputation is
verified on-chain and the allocation does not depend on any private
type.

Section 7 describes the data layer: the ingestion of consensus
events, the transport via state inclusion proofs, and the fraud proof
mechanism with its audit equilibrium.

Section 8 presents the bootstrap simulation under the net_gain
reputation model, with the comparison of three policies for the
transition from pure proof-of-stake to hybrid.

Section 9 evaluates reproducibility, on-chain gas costs, and the
stability of the conclusions under parameter variation.

Section 10 states the limitations of the design and of the numerical
verification, separated by category.

Section 11 concludes.

## 1.5 Reproducibility

The paper is accompanied by a public repository containing:

- The verification scripts (`verification/`).
- The EVM benchmarks (`integrations/avalanche/benchmarks/`).
- The falsification log (`docs/audit/numerical-verification.md`).
- The paper source (`docs/paper/sections/`).

Every quantitative claim in the paper can be traced to a script, a
benchmark, or a log entry. The commands to reproduce the claims are
listed in `verification/README.md`. Running the full suite takes
approximately ten minutes on a single core.

## 1.6 Summary of the Section

| Component | Where | Purpose |
|-----------|-------|---------|
| Validator trust gap | 1.1 | Problem statement |
| Reputation as collateral | 1.2 | Core idea |
| Protocol + verification | 1.3 | Contributions |
| Paper sections | 1.4 | Structure |
| Reproducibility | 1.5 | How to verify |

The paper reports what is verified and what is not. The distinction is
maintained throughout.
