# 10. Limitations

## 10.1 Scope

This section states the limits of the protocol and of the numerical
verification. It complements the methodological limitations of
Section 9 (validity of numerical methods, sample sizes, discretization
bias) with limits that would persist even if the numerical methods
were exact. These are limits of the design itself, not of the
simulation.

The distinction matters. If a reviewer asks why the paper does not
claim to have solved X, the answer is one of two things: either X was
not correctly measured (a limitation of Section 9), or X cannot be
solved within the design (a limitation of this section).

## 10.2 Adversary Model

The protocol assumes a rational, profit-maximizing adversary. Every
security argument in the paper is conditional on this assumption.
Specifically:

**The slashing of Section 7 deters fraud only if the adversary prefers
profit to loss.** A state actor, an ideological opponent, or a
competitor with non-monetary utility is not deterred by slashing. The
mechanism design does not apply to them.

**The cost of Sybil reputation is a market cost.** A validator
accumulates reputation by producing consensus events on the
source chains, and the cost of these events is set by the market
for validation on those chains. A Sybil adversary that controls
validators on a source chain pays the marginal cost of those
validators, not the market cost. The protocol does not model
this case; it assumes the adversary does not control the source
chains.

**The data layer bounty B* of Section 7.3 assumes auditors respond to
profit.** If no verifier is willing to audit at any bounty, the fraud
is not detected. The equilibrium n*(B) = ⌊B/B*⌋ has a solution only
if B is at least B*. Below that threshold, the mechanism provides no
detection regardless of the value of the reputation at stake.

These assumptions are standard in the cryptoeconomic literature but
they are not universal. The protocol's guarantees do not extend to
adversaries that violate them.

## 10.3 Collusion Detection Boundary

The modularity-spectrum test of Section 5 detects cliques and
bipartite structures with high power in the simulated range. The
smallest configuration tested (a single clique of size m=20) is
detected at 0.972 with s[-1] as the right-tail statistic.

The detection boundary below which the test loses power was not
located. Configurations smaller than m=20 were not simulated, and
the theoretical Kesten–Stigum threshold for the degree-corrected
SBM with the reference parameters (n = 500, d̄ = 20) is below the
tested range. The location of the boundary is an open question.

An adaptive adversary who knows the current test may attempt to
construct collusion below the (unlocated) boundary. The protocol
relies on economic deterrence for this regime rather than on
detection.

## 10.4 Collusion by Bipartite Polarization

The left-tail test measures bipartite polarization via
−λ_min(B) > 9.1371. The power of this test was measured
[verification/rmt/bipartite_power.py]: true positive rates of
0.990–1.000 across block configurations from balanced (250/250) to
heavily unbalanced (50/450), with density ratios ρ_between ∈ {2, 5,
10}.

The left-tail test is therefore not a gap. Its power is comparable
to the right-tail test. Both tails have been calibrated and
measured.

## 10.5 Reputation Model Selection

The bootstrap analysis of Section 8 uses the net_gain model

    R' = g·a·(1−R) − μ·R

selected for its correlation between activity and reputation (0.76 vs
0.08-0.11 for the saturating alternatives). The selection does not
satisfy all four criteria of the model comparison: the standard
deviation of reputation under net_gain is 0.0424 at the sweep optimum,
below the 0.05 threshold used in the comparison script. The threshold
is a heuristic.

If the true reputation dynamics differ from net_gain — if the activity
of a validator has decreasing returns, if reputation decays with a
different functional form, if there are non-linear effects — the
bootstrap results change. The qualitative conclusion (stake reduction
of 20-25% at the median validator) is robust to small changes in the
gain rule, but the specific numbers are not.

## 10.6 Community Structure and Tucker Compression

Section 3 shows that the Tucker decomposition does not capture block
structure. A tensor whose entries are constant within communities in
mode C has mode-1 and mode-2 unfoldings of full rank, and the
truncation to R₁ = 4 discards most of the energy. The reconstruction
error for a blocky tensor is 52.53%, comparable to that of a random
tensor.

If the real reputation tensor has community structure — if validators
cluster by chain, by domain, or by region — the Tucker compression
is inefficient for that structure. Whether the real tensor is
low-rank or blocky is not resolved in this paper. It is an empirical
question that requires multi-chain reputation data.

## 10.7 Calibration on Synthetic Graphs

The RMT calibration of Section 5 uses Erdős–Rényi and Chung–Lu
graphs. These are standard null models but they do not capture all
features of real collaboration graphs: community hierarchies,
temporal correlations between interactions, and directionality.

The empirical thresholds (q99 = 9.0542 for the right tail, 9.1371 for
the left tail) are valid for the calibration distribution. Their
validity on real collaboration graphs is an open question. If the
real graphs have different spectral properties, the thresholds need
recalibration. The recalibration procedure would be the one described in
Section 5.4 (Monte Carlo estimation of the null quantiles),
applied to real collaboration graphs instead of synthetic ones.

## 10.8 Bootstrap Assumptions

The bootstrap simulation of Section 8 assumes:

- Activity follows LogNormal(0, 0.5) per validator.
- Validators enter at a rate of 0.03 per epoch.
- The transition rate α(t) is linear in time, reaching 1 at epoch 200.

These are design choices, not empirical facts. The stationary
reputation R* = g·a/(g·a+μ) depends on the activity distribution; if
real activity is heavier-tailed or lighter-tailed, R* changes.

The bootstrap numbers (S_f median 0.7764, R median 0.3936, Gini 0.1283)
are specific to the reference parameters. The qualitative ranking of
policies (hybrid_no_decay dominates hybrid_decay) is robust; the
specific numbers are not.

## 10.9 What the Protocol Does Not Claim

For clarity, the protocol does not claim:

- Security against a non-rational adversary.
- Detection of collusion below the Kesten-Stigum boundary.
- Detection of bipartite polarization (threshold calibrated, power not
  measured).
- Optimality of the Tucker representation for the real reputation
  tensor.
- Validity of the RMT thresholds on real collaboration graphs.
- Independence of the bootstrap results from the activity distribution.

Each of these is a direction for future work. The protocols for
addressing them are defined in the repository.

## 10.10 Summary of the Section

| Limitation | Category | Section |
|------------|----------|---------|
| Rational adversary assumption | Design | 7, 10.2 |
| Sybil cost is market cost | Design | 7.2 |
| Bounty threshold B* | Design | 7.3 |
| Kesten-Stigum detection boundary | Design | 5.6 |
| Bipartite polarization power not measured | Gap | 5.7 |
| Net gain does not satisfy all criteria | Selection | 8.7 |
| Tucker fails for block structure | Method | 3.3 |
| RMT calibrated on synthetic graphs | Method | 5.7 |
| Bootstrap assumes LogNormal activity | Method | 8.3 |

The methodological limitations (calibration on synthetic data,
specific model choices) are separated from the design limitations
(non-rational adversary, sub-boundary collusion) because the two
require different responses. The methodological limits can be
addressed by collecting more data and recalibrating. The design
limits require different mechanisms or different claims.
