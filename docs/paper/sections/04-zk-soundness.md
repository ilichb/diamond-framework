# 4. Zero-Knowledge Threshold Proof

## 4.1 Circuit Specification

The protocol requires validators to prove, without revealing the full
reputation tensor T, that its Frobenius norm exceeds a threshold:

    ‖T‖_F ≥ Θ_r                                                    (1)

The natural implementation is a zero-knowledge proof over an R1CS
circuit that verifies (1). The prover commits to T in some form and
proves knowledge of a witness satisfying the inequality.

The original specification of the protocol used a Tucker-compressed
witness: the prover supplies the core tensor G and factor matrices
A⁰, A¹, A², the circuit reconstructs T̂ = G ×₀ A⁰ ×₁ A¹ ×₂ A², and
verifies ‖T̂‖_F ≥ Θ_r. This specification is unsound.

## 4.2 Soundness Failure

The circuit accepts a proof of knowledge of some tensor T̂ whose norm
exceeds Θ_r. It does not check that T̂ equals any committed tensor.
A prover with zero reputation can therefore choose G and the factor
matrices at will and produce a valid proof for any threshold.

We demonstrate the exploit by constructing a tensor with true norm
below the threshold and a fabricated tensor with norm above it
[verification/zk/soundness_zk_check.py]:

| Tensor | ‖·‖_F | Threshold | Accepted |
|--------|-------|-----------|----------|
| True reputation | 0.223607 | 0.5 | No |
| Fabricated (prover-chosen) | 1.000000 | 0.5 | Yes |

The exploit is trivial. Groth16 is sound with respect to the circuit;
the circuit verifies a property of a value the prover controls
completely. There is no commitment binding the prover to any specific
tensor.

## 4.3 Repair Options

Four designs are considered, three of which are sound
[verification/zk/soundness_zk_check.py]. We add a fifth column with the
on-chain gas cost of verification, measured locally with Foundry
[integrations/avalanche/benchmarks/src/GasBenchmarks.sol]. The
primitive costs on the EVM are

    ecAdd (0x06):      292 gas
    ecMul (0x07):    6,142 gas
    ecPairing (0x08): 45,000 + 34,000·k + 142 gas

with k the number of pairings. Groth16 verification uses k = 4, giving
181,142 gas for the pairing step alone. These measurements match
EIP-196 and EIP-197 exactly.

| Design | Sound | Constraints | Proof size | On-chain gas (direct) |
|--------|-------|-------------|------------|------------------------|
| As specified (Tucker, no commitment) | No | 573 | 0.20 KB | ~206k |
| Option A: Merkle commitment, full opening | Yes | 1,080,501 | 0.20 KB | ~470M |
| Option A': Poseidon commitment over full tensor | Yes | 240,261 | 0.20 KB | ~30M |
| Option B: Pedersen + Bulletproofs | Yes | 0 | 0.72 KB | ~6.5M |

The column 'On-chain gas (direct)' measures the cost of performing
the verification work on-chain without a recursive SNARK. For the
first row it is the cost of verifying the Groth16 proof of the small
circuit (~206k, constant). For options A, A', and B it is the cost
of the on-chain work the SNARK would otherwise do: hashing the tensor
(A, A') or performing the Bulletproofs scalar multiplications (B).
With recursion, all three options collapse to ~206k on-chain; the
column shows why recursion is not optional.

The constraint count for the unsound design decomposes as

    R₁R₂R₃ + R₁R₂R₃ + CDH + 1 = 36 + 36 + 500 + 1 = 573           (2)

covering the Tucker factor products, the reconstruction of T̂, the sum
of squares, and the final comparison. This is an order-of-magnitude
estimate of the arithmetic complexity; it is not an exact Groth16
constraint count.

**Option A** commits to T with a Merkle tree of Poseidon hashes and
opens all N = C·D·H leaves inside the circuit. The circuit requires
1,080,501 constraints. Direct on-chain verification of the resulting
Groth16 proof costs approximately 206k gas if the circuit fits in one
Groth16 proof, which it does not: 1.08M constraints produce a
proving key of tens of gigabytes and a proving time of minutes. On-
chain direct verification is not viable.

**Option A'** commits to T with a Poseidon tree over the entire tensor
inside the circuit. With 240,261 constraints the circuit is still too
large for practical Groth16 proving on consumer hardware.

**Option B** replaces the R1CS circuit with a Pedersen commitment to
the flattened tensor and a Bulletproofs inner-product argument. The
proof size for n = 500 elements is O(log n) ≈ 0.72 KB. The R1CS
constraint count is zero because there is no circuit; soundness is
provided by the special-soundness of the Bulletproofs protocol and
the binding property of the Pedersen commitment under the discrete
logarithm assumption. Direct verification on-chain requires 2N scalar
multiplications and 2N point additions, or approximately 6.5M gas for
N = 500. This is 31× the cost of Groth16 verification.

None of the three sound designs admits direct on-chain verification
at acceptable cost. Option A and Option A' are prohibitively large
at the constraint level. Option B is prohibitively expensive at the
gas level. The viable path is recursive SNARK composition, treated
in Section 4.4.

## 4.4 Recursive Verification

The Bulletproofs verification, which is O(N) in scalar
multiplications and costs ~6.5M gas for N = 500 if performed
on-chain, is instead performed off-chain. A recursive SNARK then
attests that the off-chain verification was correct, and only the
recursive proof is posted on-chain.

The recursive proof has constant size and constant verification cost.
For a Groth16 recursion over BN254, the on-chain cost is approximately
250k gas, dominated by the ecPairing step at 181,142 gas. This is the
same order of magnitude as the cost of verifying a single Groth16
proof directly.

We do not measure the proving time of the recursive proof in this
paper. The recursive circuit is larger than the inner verification
circuit by a factor that depends on the SNARK used for recursion. For
the reference configuration, we estimate the recursive proving time
in the range of tens of seconds on a modern CPU, but the estimate is
not verified.

The choice of recursion framework (Groth16 recursion, Plonk
recursion, Halo2 recursion) is not fixed in this paper. All three
produce constant-size on-chain proofs at similar gas cost; the
difference is the proving time and the trusted setup requirements.

**Why Option B, and its cost.** Of the four designs of Section 4.3,
only Option B has a transparent setup: Bulletproofs require no trusted
setup. Selecting it does not remove the Tucker representation from the
protocol: Tucker remains useful for data transmission outside the
circuit (Section 3.5), but the circuit operates on the raw committed
tensor.

The protocol adopts Option B with recursive SNARK composition.

## 4.5 Estimates and Their Provenance

The gas measurements for the EVM precompiles are exact: they match
EIP-196 and EIP-197 to the gas unit. The Poseidon-2 measurement of
104,963 gas is an upper bound from an unoptimized Solidity
implementation; production implementations are 20-40k gas. The
relevant constraint on Poseidon in this paper is the R1CS count of
240 per hash, which is independent of the on-chain gas cost.

The constraint counts remain arithmetic rather than measured: they
depend on the single implementation parameter above (240 R1CS
constraints per Poseidon-2 hash over BN254), a value that appears in
the literature but is not verified here. Changing this parameter
scales the constraint counts linearly.

The recursive SNARK cost of ~250k gas is an estimate. The Bulletproofs
proof size of 0.72 KB for n = 500 is an estimate from the literature.
The proving time of the recursive proof is not measured.

The exploit demonstration of Section 4.2 is not an estimate. The
values 0.223607 and 1.000000 are computed by the script.

## 4.6 Summary of the Section

| Claim | Status | Script |
|-------|--------|--------|
| Original circuit is unsound | Verified | `soundness_zk_check.py` |
| Fabricated tensor passes threshold | Verified | `soundness_zk_check.py` |
| Constraint count for unsound design | Arithmetic | `soundness_zk_check.py` |
| Merkle opening: ~1.08×10⁶ constraints | Arithmetic | `soundness_zk_check.py` |
| Poseidon tree: ~2.4×10⁵ constraints | Arithmetic | `soundness_zk_check.py` |
| Bulletproofs: 0 R1CS, ~0.72 KB | Estimate | `soundness_zk_check.py` |
| Tucker is not in the security path | Design | Section 3.5 |
| Groth16 k=4 pairing: 181,142 gas | Verified | GasBenchmarks.sol |
| Bulletproofs direct on-chain: ~6.5M gas | Estimated | GasBenchmarks.sol |
| Recursion required for on-chain viability | Design | — |

The Section demonstrates the unsoundness of the original design with
a concrete exploit, and recommends a replacement. The exact cost of
the replacement depends on implementation parameters not fixed in
this paper; the arithmetic is correct given those parameters.
