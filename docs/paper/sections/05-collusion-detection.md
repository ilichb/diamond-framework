# 5. Collusion Detection

## 5.1 The Collaboration Graph

Validators interact through shared governance votes, co-authored pull
requests, and simultaneous liquidity events. We model these
interactions as a symmetric weighted graph with adjacency matrix

    W ∈ ℝ^{n × n}                                                  (1)

where W_ij counts the interactions between validators i and j. The
graph has n = 500 nodes in the reference configuration, with mean
degree d̄ = 20.

The hypothesis of interest is that a subset of validators coordinates
to inflate each other's reputation without genuine contribution. In
graph terms, this appears as a dense subgraph (a clique) embedded in
a sparser background.

## 5.2 The Normalization Problem

A natural spectral approach analyzes the symmetric normalized
adjacency matrix

    A_sym = D^{−1/2} W D^{−1/2}                                    (2)

where D = diag(d₁, …, d_n), d_i = Σ_j W_ij. This matrix has a bulk
spectrum that recovers a Wigner-type distribution for heavy-tailed
graphs, which the original formulation of the protocol used for
detection.

The normalization is inappropriate for detecting cliques. Each edge
is scaled by 1/√(d_i d_j). Because a clique raises the degree of its
members, the normalization downweights the clique's internal edges
relative to the background. Quantitatively, for a clique of size
m = 20 with intra-clique density 10× the background:

    degree of a clique node:      ≈ 27.2
    degree of a background node:  ≈ 20.0
    normalized intra-clique edge: 1/27.2 ≈ 0.037
    normalized background edge:   1/20.0 ≈ 0.050

The clique's edges are weaker after normalization than the
background's. The density signal is cancelled by the degree increase.

We verify this numerically
[verification/rmt/clique_spectra.py]. For a single clique of size
m = 20 with intra-clique density 10× the background, the three
candidate matrices give the following second eigenvalues:

| Matrix | λ₂ (H₀) | λ₂ (H₁) | Bulk edge | Gap (H₁) |
|--------|---------|---------|-----------|----------|
| W (raw) | 8.6896 | 10.6439 | 8.9443 | +1.6996 |
| A_sym | 0.4254 | 0.4316 | 0.4472 | −0.0156 |
| B | 8.5369 | 8.8537 | 8.9443 | −0.0906 |

The table shows that W separates the clique from the bulk (gap
+1.6996 against the asymptotic edge 2√d̄ = 8.9443). A_sym does not
(gap −0.0156 against its bulk edge 0.4472). B responds to the clique
more strongly than A_sym by a factor of 51 in the shift Δλ₂
(+0.3168 vs +0.0062), but in this single realization it does not
exceed the theoretical bulk edge (gap −0.0906). It does, however,
exceed the empirically calibrated threshold of Section 5.4
(8.8537 > 8.8372), which is the operational threshold.

The gap between the theoretical edge 2√d̄ = 8.9443 and the empirical
threshold q99 = 8.8372 is a known feature of sparse graphs: the
asymptotic Wigner edge is not tight for n = 500 with d̄ = 20. The
paper uses the empirical threshold.

This is the content of the falsification log entry F-002.

## 5.3 The Modularity Matrix

The matrix that resolves both problems is the modularity matrix

    B = W − ddᵀ/(2m)                                               (3)

where d is the degree vector and m = (1/2) Σ_i d_i is the number of
edges. The matrix B satisfies

    B · 1 = 0                                                      (4)

which removes the degree bias by construction. Its bulk spectrum under
the null is centered at zero with edge 2√d̄ for the degree-corrected
stochastic block model.

The modularity matrix is the standard tool for community detection in
the stochastic block model. It has the property that the leading
eigenvector outside the bulk corresponds to the community structure,
not to the degree distribution.

## 5.4 Null Distribution and Calibration

We calibrate the null distribution of λ₂(B) and λ_min(B) by Monte
Carlo on Erdős–Rényi graphs with n = 500 and d̄ = 20
[verification/rmt/calibration_modularity.py]. The calibration uses
N_H0 = 2000 replicates with seed 42.

| Statistic | Mean | Std | q99 |
|-----------|------|-----|-----|
| λ₂(B) (right tail, cliques) | 8.6082 | 0.0925 | 8.8372 |
| −λ_min(B) (left tail, bipartite) | 8.8601 | 0.1101 | 9.1371 |

The empirical thresholds at significance level α are:

| α | Reject H₀ if |
|---|--------------|
| 0.01 | λ₂(B) > 8.8372 or −λ_min(B) > 9.1371 |
| 0.05 | λ₂(B) > 8.7614 or −λ_min(B) > 9.0428 |

The dual-tail structure distinguishes clique-based collusion (right
tail) from bipartite polarization (left tail). The right-tail
threshold is calibrated at q99 = 8.8372, which is 2.47σ above the
null mean. The left-tail threshold is calibrated at 9.1371, which is
2.52σ above its null mean.

## 5.5 Detection Power

We measure the power of the right-tail test against clique-based
collusion by simulating graphs with k planted cliques of size m and
intra-clique density 10× the background
[verification/rmt/calibration_modularity.py]. The measurement uses
N_H1 = 500 replicates per configuration with Wilson 95% confidence
intervals.

| Configuration | λ₂(B) mean | TPR @ α=0.01 | 95% CI |
|---------------|------------|--------------|--------|
| k=1, m=20 | 8.7643 | 0.248 | [0.212, 0.288] |
| k=3, m=20 | 9.7564 | 1.000 | [0.992, 1.000] |
| k=5, m=20 | 10.1206 | 1.000 | [0.992, 1.000] |
| k=1, m=40 | 8.9579 | 0.828 | [0.792, 0.859] |
| k=3, m=40 | 15.5205 | 1.000 | [0.992, 1.000] |

Three patterns are visible.

**The transition is abrupt.** A single clique of size 20 is detected
at 24.8% (TPR at α = 0.01). Three cliques of the same size are
detected at 100%. The difference between k=1 and k=3 is not a
gradient; it is a phase transition consistent with the
Kesten–Stigum threshold for the stochastic block model.

**Coordination matters more than size.** Three small cliques (60
nodes total) are more detectable than one medium clique (40 nodes).
The λ₂ mean for the former is 9.7564, for the latter 8.9579. The
detection statistic scales with the number of planted structures
faster than with their individual size.

**Partial detection is genuine.** The confidence interval for k=1,
m=20 is [0.212, 0.288], which excludes 0.5. This is not "almost
detectable"; it is a regime where the test is better than chance
but not reliable.

## 5.6 The Detection Boundary

The detection power measured in Section 5.5 follows a clear pattern:
the transition from partial to full detection is controlled by the
combination of clique size, clique count, and background degree. We
describe the pattern and state a conjecture, not a theorem.

**Empirical pattern.** The TPR at α = 0.01 for the five simulated
configurations, together with the ratio k·m²/n, is:

| Configuration | k·m²/n | TPR @ α=0.01 |
|---------------|--------|--------------|
| k=1, m=20 | 0.800 | 0.248 |
| k=3, m=20 | 2.400 | 1.000 |
| k=5, m=20 | 4.000 | 1.000 |
| k=1, m=40 | 3.200 | 0.828 |
| k=3, m=40 | 9.600 | 1.000 |

The ratio k·m²/n orders the configurations approximately by
detection power: partial below 1.0, near-full at 3.2 (k=1, m=40
with TPR = 0.828), and full for k ≥ 3 (ratio ≥ 2.4). The ordering
is not strict, as the k=1, m=40 case shows. This scaling appears
in the archived analysis of the protocol
[verification/rmt/archive/calibracion_rmt.py] and is consistent with
the five measurements above.

**[CONJECTURE]** The detection boundary for the modularity-spectrum
test on the degree-corrected stochastic block model is controlled by
the ratio k·m²/n, with a transition around k·m²/n ≈ 1.5. We do not
prove this; we state it as a conjecture consistent with our five data
points. A derivation from the Kesten–Stigum threshold or from the
random matrix literature would be a separate contribution.

Consequently, collusion below this boundary is not detectable from
the collaboration graph alone with the modularity-spectrum test. It
must be mitigated by other mechanisms: economic deterrence through
slashing (Section 7) and reputational collateral destruction
(Section 2).

## 5.7 Limitations

The calibration is performed on Erdős–Rényi and Chung–Lu graphs.
Real collaboration graphs have additional structure not captured by
these models: community hierarchies, temporal correlations between
interactions, and directionality (who initiates contact). The
empirical quantiles in Section 5.4 are valid for the calibration
distribution; their validity on real graphs is an open question.

The left tail (−λ_min) is calibrated but its power is not measured.
The H₀ distribution is characterized, but we do not simulate
bipartite structures to measure the false-negative rate. This is
declared as an open item.

An adversarial validator who knows the test can attempt to avoid
detection by keeping the clique density below the Kesten–Stigum
boundary, mixing clique members with honest interactions, or
avoiding clique structures entirely. The test has power against the
naive adversary (uniform cliques of moderate size); it does not have
power against an adaptive adversary who understands the boundary.
This is the fundamental limit of spectral detection and is
consistent with the detection boundary theorem.

## 5.8 Summary of the Section

| Claim | Status | Script |
|-------|--------|--------|
| A_sym masks cliques | Verified | `clique_spectra.py`, `sim_laplacian.py` |
| Modularity B removes degree bias | Verified | `calibration_modularity.py` |
| Null q99 = 8.8372 | Verified | `calibration_modularity.py` |
| TPR k=1, m=20 = 0.248 | Verified | `calibration_modularity.py` |
| TPR k=3, m=20 = 1.000 | Verified | `calibration_modularity.py` |
| TPR k=1, m=40 = 0.828 | Verified | `calibration_modularity.py` |
| Detection boundary (Kesten–Stigum) | Conjecture | — |
| Left-tail power not measured | Limitation | — |

The Section's quantitative content is limited to the calibration of
the null distribution, the power measurements for the right tail,
and the demonstration that A_sym fails where B succeeds.
