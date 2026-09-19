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
relative to the background.

Quantitatively, for a clique of size m = 20 with intra-clique
density 10× the background:

    degree of a clique node:      ≈ 27.2
    degree of a background node:  ≈ 20.0
    normalized intra-clique edge: 1/27.2 ≈ 0.037
    normalized background edge:   1/20.0 ≈ 0.050

The clique's edges are weaker after normalization than the
background's. The density signal is cancelled by the degree increase.

We verify this numerically
[verification/rmt/clique_spectra.py]. For a single clique of size
m = 20 with intra-clique density 10× the background, the three
candidate matrices give the following leading non-trivial eigenvalue:

| Matrix | Statistic | λ (H₀) | λ (H₁) | Bulk edge | Gap (H₁) |
|--------|-----------|--------|--------|-----------|----------|
| W (raw) | s[-2] | 8.6896 | 10.6439 | 8.9443 | +1.6996 |
| A_sym | s[-2] | 0.4254 | 0.4316 | 0.4472 | −0.0156 |
| B | s[-1] | 8.6896 | 10.7011 | 8.9443 | +1.7569 |

The choice of statistic differs by matrix. For W and A_sym, s[-1] is
the Perron eigenvalue (trivial, equal to d_max and 1 respectively)
and s[-2] is the leading non-trivial direction. For B, the identity
B·1 = 0 places the trivial eigenvalue at the center of the spectrum,
and s[-1] is the signal. The change is documented in falsification
log entry F-018.

The table shows that W separates the clique from the bulk (gap
+1.6996 against the asymptotic edge 2√d̄ = 8.9443). A_sym does not
(gap −0.0156 against its bulk edge 0.4472). B separates the clique
by a wider gap than W (+1.7569 vs +1.6996) and exceeds both the
theoretical bulk edge and the empirically calibrated threshold
q99 = 9.0542 of Section 5.4.

The relationship between B and W is explained by a structural
identity. For a regular graph with degree d, the modularity matrix
is B = A − (d/n)·11ᵀ, and since 1 is orthogonal to every other
eigenvector, the spectrum of B equals that of A with the Perron
eigenvalue replaced by 0. Consequently λ_max(B) = λ₂(W) exactly.
The Erdős–Rényi graph used in the null simulation is almost regular
(degrees 10–33, mean 19.88, std 4.22), so the identity holds to
within 10⁻⁵ in H₀. In H₁ the clique raises the degrees of its 20
members, breaking the regularity and leaving B slightly ahead of W.

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

We calibrate the null distribution of λ_max(B) and λ_min(B) by Monte
Carlo on Erdős–Rényi graphs with n = 500 and d̄ = 20
[verification/rmt/calibration_modularity.py]. The calibration uses
N_H0 = 2000 replicates with seed 42.

| Statistic | Mean | Std | q99 |
|-----------|------|-----|-----|
| λ_max(B) (right tail, cliques) | 8.7679 | 0.1115 | 9.0542 |
| −λ_min(B) (left tail, bipartite) | 8.8601 | 0.1101 | 9.1371 |

The empirical thresholds at significance level α are:

| α | Reject H₀ if |
|---|--------------|
| 0.01 | λ_max(B) > 9.0542 or −λ_min(B) > 9.1371 |
| 0.05 | λ_max(B) > 8.9663 or −λ_min(B) > 9.0428 |

The dual-tail structure distinguishes clique-based collusion (right
tail) from bipartite polarization (left tail). The right-tail
threshold is calibrated at q99 = 9.0542, which is 2.57σ above the
null mean. The left-tail threshold is calibrated at 9.1371, which is
2.52σ above its null mean.

The statistic for the right tail is s[-1], the largest eigenvalue of
B, not s[-2]. The change is documented in falsification log entry
F-018: for a balanced two-block structure the signal is at s[-1] =
17.5 while s[-2] = 8.5 sits inside the bulk. The "skip Perron"
convention that motivates s[-2] in the adjacency matrix does not
apply to the modularity matrix, where B·1 = 0 places the trivial
eigenvalue at the center of the spectrum.

## 5.5 Detection Power

We measure the power of the right-tail test against clique-based
collusion by simulating graphs with k planted cliques of size m and
intra-clique density 10× the background
[verification/rmt/calibration_modularity.py]. The measurement uses
N_H1 = 500 replicates per configuration with Wilson 95% confidence
intervals.

| Configuration | λ_max(B) mean | TPR @ α=0.01 | 95% CI |
|---------------|---------------|--------------|--------|
| k=1, m=20 | 9.7452 | 0.972 | [0.954, 0.983] |
| k=3, m=20 | 10.2714 | 1.000 | [0.992, 1.000] |
| k=5, m=20 | 10.5294 | 1.000 | [0.992, 1.000] |
| k=1, m=40 | 14.2441 | 1.000 | [0.992, 1.000] |
| k=3, m=40 | 16.2281 | 1.000 | [0.992, 1.000] |

Detection is uniform across the five configurations. The lowest true
positive rate is 0.972, for a single clique of size 20 with
intra-clique density 10× the background. All other configurations
are detected at 1.000.

The abrupt-transition pattern that appeared with s[-2] was an
artifact of the wrong statistic. With s[-1], the smallest clique is
detected at 97.2% and every other configuration at 100%. There is no
intermediate regime in the simulated range.

The single-clique case at m=20 remains the tightest: 0.972 with a
Wilson 95% confidence interval of [0.954, 0.983]. The interval is
above 0.9, so the detection is reliable. Configurations below m=20
were not simulated; the boundary at which detection degrades is
below the tested range.

**Comparison with A_sym.** The same test run on the normalized
adjacency matrix A_sym, with the same clique configuration (k=1,
m=20 on n = 500, d̄ = 20), gives a true positive rate of 0.033 at
α = 0.01 [verification/rmt/archive/calibracion_rmt.py], measured
over N_H1 = 30 replicates. The modularity matrix B gives 0.972 on
the same configuration, measured over N_H1 = 500 replicates. The
ratio is approximately 29.2×. This is the numerical basis for the
design decision to replace A_sym with B, documented as falsification
log entry F-002.

The two Wilson 95% confidence intervals do not overlap: A_sym is
[0.006, 0.167] and B is [0.954, 0.983]
[verification/rmt/wilson_intervals.py]. The comparison is
statistically significant at 95% despite the small sample size of
the A_sym measurement (N = 30).

## 5.6 The Detection Boundary

The detection power measured in Section 5.5 is uniform across the
simulated range. All five configurations have true positive rates
above 0.97. There is no observable transition from partial to full
detection within the tested parameter range.

This is a consequence of using s[-1] as the statistic. With the
previous statistic s[-2], the pattern appeared to be controlled by
the ratio k·m²/n and a boundary around k·m²/n ≈ 1.5 was conjectured.
That pattern was an artifact: with s[-1] the same configurations all
sit above the (much lower) effective boundary.

**[CONJECTURE]** The detection boundary for the modularity-spectrum
test with s[-1] on the degree-corrected stochastic block model lies
below the configurations tested here. We do not locate it precisely;
the smallest configuration tested (a single clique of size m=20) is
detected at 0.972, and configurations smaller than m=20 were not
simulated. A derivation of the boundary from the Kesten–Stigum
threshold or from the random matrix literature would be a separate
contribution.

Consequently, collusion at the scale tested here is detectable from
the collaboration graph alone. Collusion below the (unlocated)
boundary would not be. The protocol relies on economic deterrence
through slashing (Section 7) and reputational collateral destruction
(Section 2) for the sub-boundary regime, which is not characterized
in this paper.

## 5.7 Limitations

The calibration is performed on Erdős–Rényi and Chung–Lu graphs.
Real collaboration graphs have additional structure not captured by
these models: community hierarchies, temporal correlations between
interactions, and directionality (who initiates contact). The
empirical quantiles in Section 5.4 are valid for the calibration
distribution; their validity on real graphs is an open question.

The baseline measurement for A_sym uses N_H1 = 30 replicates,
smaller than the N_H1 = 500 used for B. The Wilson intervals of the
two measurements do not overlap, so the comparison is statistically
significant, but the A_sym estimate carries wider uncertainty
[verification/rmt/wilson_intervals.py].

The left tail (−λ_min) is calibrated at q99 = 9.1371 and its power
is measured against bipartite (disassortative) two-block structure:
TPR 0.990–1.000 at α = 0.01 for density ratios ρ_between ∈ {2, 5,
10} and all block sizes tested, from balanced (250/250) to heavily
unbalanced (50/450) [verification/rmt/bipartite_power.py].

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
| Modularity B with s[-1] detects cliques | Verified | `calibration_modularity.py` |
| Null q99 (right tail, s[-1]) = 9.0542 | Verified | `calibration_modularity.py` |
| TPR k=1, m=20 = 0.972 | Verified | `calibration_modularity.py` |
| TPR k=3, m=20 = 1.000 | Verified | `calibration_modularity.py` |
| TPR k=1, m=40 = 1.000 | Verified | `calibration_modularity.py` |
| A_sym vs B ratio = 29.2× | Verified | `wilson_intervals.py` |
| Detection boundary below tested range | Conjecture | — |
| Left-tail power measured | Verified | `bipartite_power.py` |

The Section's quantitative content is limited to the calibration of
the null distribution, the power measurements for the right tail,
and the demonstration that A_sym fails where B succeeds.
