# 3. Tensor Compression

## 3.1 Tensor Representation of Reputation

Reputation is represented as a three-dimensional tensor

    T ∈ [0,1]^{C × D × H}                                          (1)

where C indexes chains (C = 20 in the reference configuration), D
indexes contribution domains (D = 5), and H indexes time horizons
(H = 5). Entry T[c,d,h] is the validator's normalized score on chain c,
in domain d, at horizon h.

The tensor has C·D·H = 500 entries in the reference configuration.
This is the object whose norm is compared against the reputational
threshold Θ_r in the zero-knowledge circuit of Section 4.

## 3.2 Tucker Decomposition

The Tucker decomposition of T is

    T ≈ G ×₀ A⁰ ×₁ A¹ ×₂ A²                                        (2)

where G ∈ ℝ^{R₁×R₂×R₃} is the core tensor and A⁰ ∈ ℝ^{C×R₁},
A¹ ∈ ℝ^{D×R₂}, A² ∈ ℝ^{H×R₃} are the factor matrices. We compute the
decomposition via higher-order SVD (HOSVD), which takes the leading
singular vectors of each mode unfolding.

For the reference configuration we use (R₁,R₂,R₃) = (4,3,3). The
storage required for the Tucker representation is

    R₁R₂R₃ + R₁C + R₂D + R₃H = 146 entries                         (3)

versus C·D·H = 500 entries for the uncompressed tensor. The storage
ratio is 3.4247× (a 70.8% reduction)
[verification/tensor/tucker_analysis.py].

## 3.3 Reconstruction Error

The HOSVD is exact for tensors of rank at most (R₁,R₂,R₃) and
approximate otherwise. We quantify the reconstruction error

    ε(T) = ‖T − T̂‖_F / ‖T‖_F                                      (4)

for four tensor types at rank (4,3,3):

| Tensor type | ‖T‖_F | ‖T − T̂‖_F | ε(T) |
|-------------|-------|-----------|------|
| Clean low-rank | 73.068 | 0.000 | 4.8×10⁻¹⁶ |
| Low-rank + noise (σ = 0.05) | 45.261 | 0.993 | 2.19% |
| Random (zero mean) | 6.407 | 5.493 | 85.74% |
| Blocky (community structure) | 6.775 | 3.559 | 52.53% |

Three observations follow.

First, the HOSVD implementation is exact: the clean low-rank tensor is
reconstructed to machine precision (relative error 4.8×10⁻¹⁶). This
verifies the decomposition itself.

Second, the error for a low-rank tensor corrupted by noise is equal to
the noise-to-signal ratio ‖N‖_F / ‖T‖_F. The decomposition captures
the underlying low-rank component exactly and fails to capture only the
noise, which is by construction not low-rank.

Third, and most importantly: **HOSVD does not capture block structure.**
A tensor whose entries are constant within communities in mode C has
mode-1 and mode-2 unfoldings of full rank. The truncation to R₁ = 4
rows discards most of the energy in those modes, and the reconstruction
error is dominated by truncation rather than by noise. In the reference
configuration the blocky tensor has error 52.53%, comparable to that
of a random tensor.

The practical implication is that Tucker compression is efficient for
tensors with low-rank structure and inefficient for tensors with
community structure. Which regime the reputation tensor occupies is
an empirical question that depends on the correlation of validator
scores across chains, domains, and horizons. We do not resolve this
question in this paper.

## 3.4 Error Versus Rank

For the low-rank noisy tensor, the reconstruction error decreases
monotonically with rank:

| (R₁,R₂,R₃) | Storage | Ratio | ε(T) |
|------------|---------|-------|------|
| (1,1,1) | 31 | 16.13× | 5.02% |
| (2,2,2) | 68 | 7.35× | 3.24% |
| (3,3,3) | 117 | 4.27× | 2.32% |
| (4,3,3) | 146 | 3.42× | 2.19% |
| (5,5,5) | 275 | 1.82× | 1.52% |

The trade-off is between storage reduction and reconstruction fidelity.
The choice of rank is a design parameter; the reference configuration
(4,3,3) is a specific operating point, not an optimum.

## 3.5 Tucker Is Not in the Security Path

The Tucker compression is a storage and transmission optimization. It
is not part of the trust chain of the protocol.

The zero-knowledge proof of Section 4 verifies a threshold on the norm
of the reputation tensor. The proof operates on the committed tensor,
not on its Tucker approximation. A prover who fabricates the factors G
and A_i cannot produce a sound proof of the committed tensor's norm,
because the commitment binds the prover to the raw tensor.

Consequently the storage savings of 3.42× do not translate into a
reduction of the ZK circuit cost. The circuit must verify the norm of
the raw tensor, which is O(C·D·H) constraints under the commitment
scheme. Tucker is used only outside the circuit, to reduce the size of
the data transmitted from the reputation oracle to the verifier.

This distinction corrects a claim in an earlier formulation of the
protocol, in which the storage savings were presented as a reduction
of the circuit cost. The two are independent: the storage reduction is
real (3.4247×) and the circuit cost reduction is zero. The falsification
log records this correction as F-012.

## 3.6 Summary of the Section

| Claim | Status | Script |
|-------|--------|--------|
| HOSVD is exact for low-rank tensors | Verified | `tucker_analysis.py` |
| Storage reduction 500 → 146 | Verified | `tucker_analysis.py` |
| Error for noisy low-rank: ‖N‖/‖T‖ | Verified | `tucker_analysis.py` |
| Error for random: 85.7% | Verified | `tucker_analysis.py` |
| Error for blocky: 52.5% (HOSVD fails) | Verified | `tucker_analysis.py` |
| Tucker is not in the security path | Design | Sections 4, 5 |

The quantitative content of this Section is limited to the storage
ratio and the reconstruction errors. The Tucker decomposition is a
representation choice, not a security mechanism.
