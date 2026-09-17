# 8. Bootstrap Dynamics

## 8.1 The Genesis Problem

At the genesis block, no validator has reputation. The reputation
tensor T is identically zero and the reputational collateral C_R(0)
is zero. The protocol therefore begins as a pure proof-of-stake
system with full financial stake requirements, and transitions to a
hybrid regime as validators accumulate reputation.

The bootstrap question is: does the transition concentrate reputation
in the early validators, and if so, how much? A mechanism that
concentrates reputation in a small set of genesis validators would
recreate the centralization it was designed to avoid.

## 8.2 Reputation Models

The dynamics of reputation during the bootstrap determine the
outcome. We compare three models in earlier work and select one for
the paper. The models differ in how a validator's activity `a`
translates into reputation growth:

| Model | Gain rule | Stationary value |
|-------|-----------|------------------|
| Saturating | k·a·(1−R) | R → 1 for all a |
| Decreasing | k·a·(1−R)² | R → 1 for all a |
| net_gain | g·a·(1−R) − μ·R | R* = g·a/(g·a + μ) |

The saturating and decreasing models converge to R → 1 for all
validators regardless of activity. After a sufficiently long horizon,
the reputation is identical for all validators and carries no
information about contribution. This is the content of the earlier
comparison [verification/bootstrap/compare_reputation_models.py].

The net_gain model has a stationary value that depends on activity:

    R* = g · a / (g · a + μ)                                       (1)

The correlation between activity and reputation at stationarity is
0.76 in the reference simulation, versus 0.08–0.11 for the
saturating models [verification/bootstrap/compare_reputation_models.py].
We therefore use net_gain throughout the bootstrap analysis.

The sweep over μ at fixed g = 0.01
[verification/bootstrap/sweep_net_gain.py] gives a maximum of
R_std at μ/g = 1.5. We use g = 0.01, μ = 0.015.

## 8.3 Bootstrap Simulation

We simulate the bootstrap from R(0) = 0 over 500 epochs
[verification/bootstrap/simulate_bootstrap_net_gain.py]. Parameters:

- N_MAX = 100 validators, N_INIT = 10 at genesis.
- Entry rate 0.03 per epoch for new validators.
- Activity a ~ LogNormal(0, 0.5) per validator.
- Transition rate α(t) = min(1, t/200), reaching 1 at epoch 200.

We compare three policies:

- **pure_pos**: S_f = Θ throughout. No reputation adjustment.
- **hybrid_no_decay**: S_f(t) = max{VaR_tech, Θ − α(t)·C_R(R(t))}.
- **hybrid_decay**: same as hybrid_no_decay with R decaying at
  half-life 50 epochs.

## 8.4 Results

| Policy | t(α=1) | Gini | Top-10 | S_f med | R med | R max |
|--------|--------|------|--------|---------|-------|-------|
| pure_pos | 500 | 0.1283 | 0.1367 | 1.0000 | 0.3936 | 0.5976 |
| hybrid_no_decay | 200 | 0.1283 | 0.1367 | 0.7764 | 0.3936 | 0.5976 |
| hybrid_decay | 200 | 0.1563 | 0.1477 | 0.8393 | 0.2553 | 0.4348 |

The S_f med column measures the median financial stake required at
the end of the simulation. Under pure_pos it is Θ = 1.0. Under
hybrid_no_decay it is 0.7764, a reduction of 22.4%. Under hybrid_decay
it is 0.8393, a reduction of 16.1%.

The R med column is the median reputation. Under net_gain it converges
to the stationary value R* = g·a/(g·a + μ). For a validator with
median activity a ≈ 1, R* ≈ 0.4, consistent with the measured 0.3936.

## 8.5 Comparison of Policies

Two observations follow from the table.

**Decay does not reduce concentration.** The hybrid_decay policy has
higher Gini (0.1563) than hybrid_no_decay (0.1283). This is the
opposite of the intuition that decay limits accumulation. The reason
is that decay lowers the ceiling (R_max drops from 0.5976 to 0.4348)
but also lowers the floor, spreading the distribution. Under
hybrid_no_decay, the top validators saturate near R ≈ 0.6 and the
distribution compresses; under hybrid_decay, they fall back to
R ≈ 0.43 and the distribution widens. The falsification log records
this as F-015.

**hybrid_decay is dominated on both metrics.** It has higher Gini
(0.1563 vs 0.1283) and higher median S_f (0.8393 vs 0.7764). The only
advantage is lower R_max, which could matter if the protocol has a
constraint on maximum reputation. Absent such a constraint,
hybrid_no_decay is the recommended policy.

## 8.6 Recommendation

The protocol uses hybrid_no_decay. The financial stake reduction
under this policy is 22.4% at the median validator. This is lower
than the 37% that an earlier analysis reported under the saturating
model [see falsification log entry F-016], because the saturating
model produces R → 1 for all validators while net_gain produces
R* ≈ 0.4.

The reduction is real but modest. It corresponds to a validator with
median reputation needing to lock 77.6% of the stake it would need
under pure proof-of-stake. Validators with above-median reputation
lock less; validators below median lock more.

## 8.7 Summary of the Section

| Claim | Status | Script |
|-------|--------|--------|
| net_gain is the selected model | Verified | `compare_reputation_models.py` |
| μ/g = 1.5 maximizes R_std | Verified | `sweep_net_gain.py` |
| S_f median 0.7764 under hybrid_no_decay | Verified | `simulate_bootstrap_net_gain.py` |
| 22.4% stake reduction at median | Verified | `simulate_bootstrap_net_gain.py` |
| hybrid_decay raises Gini | Verified | `simulate_bootstrap_net_gain.py` |
| Hybrid_no_decay is recommended | Design | — |

The Section's quantitative content is limited to the bootstrap
simulation under the net_gain model and the comparison of three
policies. The saturation of the alternative models is documented as
F-016.

The selection of net_gain is based on its correlation with
activity (0.76 vs 0.08-0.11 for the saturating models), not on
satisfying all four criteria of the model comparison. The
standard deviation of reputation under net_gain is 0.0282 in
`compare_reputation_models.py` and 0.0424 at the sweep optimum
mu/g = 1.5; both fall below the 0.05 threshold used in the
comparison script. The threshold is a heuristic, not a
requirement, and the net_gain model is chosen for the correlation
property, which the saturating models fail by an order of
magnitude.
