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
[verification/zk/soundness_zk_check.py]:

| Design | Sound | Constraints | Proof size |
|--------|-------|-------------|------------|
| As specified (Tucker, no commitment) | No | 573 | 0.20 KB |
| Option A: Merkle commitment, full opening | Yes | 1,080,501 | 0.20 KB |
| Option A': Poseidon commitment over full tensor | Yes | 240,261 | 0.20 KB |
| Option B: Pedersen + Bulletproofs | Yes | 0 | 0.72 KB |

The constraint count for the unsound design decomposes as

    R₁R₂R₃ + R₁R₂R₃ + CDH + 1 = 36 + 36 + 500 + 1 = 573           (2)

covering the Tucker factor products, the reconstruction of T̂, the sum
of squares, and the final comparison. This is an order-of-magnitude
estimate of the arithmetic complexity; it is not an exact Groth16
constraint count.

**Option A** commits to T with a Merkle tree of Poseidon hashes and
opens all N = C·D·H leaves inside the circuit. With log₂(N) = 9 and
240 constraints per Poseidon-2 hash over BN254, this requires

    N · log₂(N) · 240 + N + 1 ≈ 1,080,501                          (3)

constraints. This is prohibitively expensive.

**Option A'** commits to T with a Poseidon tree over the entire tensor
inside the circuit. With 2N − 1 hashes,

    (2N − 1) · 240 + N + 1 ≈ 240,261                               (4)

constraints. Less expensive than A but still heavy.

**Option B** replaces the R1CS circuit with a Pedersen commitment to
the flattened tensor and a Bulletproofs inner-product argument. The
proof size for n = 500 elements is O(log n) ≈ 0.72 KB. The R1CS
constraint count is zero because there is no circuit; soundness is
provided by the special-soundness of the Bulletproofs protocol and
the binding property of the Pedersen commitment under the discrete
logarithm assumption. Verification is O(N) scalar multiplications
off-chain, which can be wrapped in a recursive SNARK to O(1) on-chain.

## 4.4 Recommended Design

The protocol adopts Option B. The reasons are:

1. **Sound.** The Pedersen commitment binds the prover to a specific
   tensor; the Bulletproofs argument proves a threshold on that
   tensor's norm.
2. **Sub-linear proof.** O(log n) group elements, 0.72 KB for n = 500.
3. **Verification tractable off-chain.** O(N) scalar multiplications,
   recursive to O(1) on-chain.
4. **Transparent setup.** Bulletproofs require no trusted setup.

The cost is the loss of Tucker compression in the security path.
Tucker remains useful for data transmission outside the circuit
(Section 3.5), but the circuit operates on the raw committed tensor.

## 4.5 Estimates and Their Provenance

The constraint counts in Section 4.3 are arithmetic given a single
implementation parameter: the number of R1CS constraints per
Poseidon-2 hash over BN254. This paper uses 240, a value that appears
in the literature for Poseidon-2 but is not verified here. Changing
this parameter scales the constraint counts linearly. The Bulletproofs
proof size of 0.72 KB for n = 500 is likewise an estimate from the
literature.

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

The Section demonstrates the unsoundness of the original design with
a concrete exploit, and recommends a replacement. The exact cost of
the replacement depends on implementation parameters not fixed in
this paper; the arithmetic is correct given those parameters.
