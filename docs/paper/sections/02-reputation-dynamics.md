# 2. Reputation Dynamics

## 2.1 The CIR Process

Validator reputation is modeled as a mean-reverting stochastic process with
abrupt downward shocks. In its continuous form, the process follows the
Cox–Ingersoll–Ross (CIR) diffusion:

    dR(t) = α(R̄ − R(t))dt + σ₀√(R(t))dW(t)                       (1)

with α > 0 the mean-reversion speed, R̄ > 0 the long-run mean, and σ₀ > 0
the diffusion coefficient. The process is strictly positive under the Feller
condition 2αR̄ ≥ σ₀², which we assume throughout.

Slashing events are modeled as multiplicative downward jumps:

    R(t) ↦ R(t⁻) · y,  y ∈ (0, 1]                                (2)

where y is drawn from a Lévy measure ν supported on (0, 1]. The choice of
multiplicative rather than additive jumps is not cosmetic; it is required
for the process to remain in its domain.

## 2.2 Domain Validity Under Jumps

The original formulation of the Diamond Framework used additive jumps of
the form:

    dR(t) = α(R̄ − R(t))dt + σ₀√(R(t))dW(t) + ∫ J(z)Ñ(dt, dz)    (3)

with J(z) < 0. This specification is not well posed. Additive negative
jumps can push R below zero regardless of the Feller condition, because
the Feller condition constrains the diffusion, not the jump component.

We quantify this failure by Monte Carlo simulation. With parameters
α = 0.5, R̄ = 1.0, σ₀ = 0.8 (Feller satisfied: 2αR̄ = 1.0 ≥ σ₀² = 0.64),
jump intensity λ = 0.8, mean jump magnitude 0.15, R(0) = 0.3, and T = 5,
the additive-jump specification produces:

    fraction of trajectories with R(t) < 0 for some t ∈ [0, T]:
        additive jumps:       40.58%                                (4)
        multiplicative jumps:  0.0000%  (minimum observed: 0.000000)

over 100,000 simulated paths with dt = 0.001
[verification/stochastics/sim_positivity.py].

The failure rate of 40.58% is not a tail event. With the specified
parameters, two in five trajectories violate the domain within five
time units. The multiplicative specification resolves this by construction:
a jump of the form R ↦ R·y with y ∈ (0, 1] preserves positivity pathwise,
and the CIR component remains positive under Feller.

## 2.3 The Whitewashing Bound

For a validator whose reputation has been reduced to near zero, the
expected time to recover to a target level R₀ is governed by the
first-passage time of the CIR diffusion. Under the scale function
s'(x) = x^{−κ}exp(β·x) with κ = 2αR̄/σ₀² and β = 2α/σ₀², the classical
expression for the expected first-passage time is:

    E[τ_{R₀}] = 2 ∫₀^{R₀} s'(z) M(z) dz                             (5)

where M(z) = ∫₀^z m'(y) dy and m'(y) = 1/(σ²(y)s'(y)) is the speed
measure density.

We evaluate (5) by numerical quadrature in the well-conditioned form

    E[τ_{R₀}] = 2 ∫₀^{R₀} g(y) dy,
    g(y) = (1/σ₀²) ∫₁^{R₀/y} s^{−κ} exp(β·y·(s−1)) ds              (6)

which avoids the catastrophic cancellation that arises from computing
s(R₀) − s(y) directly when κ > 1
[verification/stochastics/mfpt_bound_explicit.py].

For the two parameter regimes of interest:

| Parameters | Exact MFPT | Bound with C\*=1 | Implicit C\* |
|------------|------------|-------------------|---------------|
| α=0.5, σ₀=0.8 | 11.2203 | 19.965 | 0.562 |
| α=2.0, σ₀=0.5 | 443.7374 | 1.415×10¹⁰ | 3.14×10⁻⁸ |

The analytical bound of the original formulation,
C\*·R₀^{1−κ}·exp(β·R₀), requires specifying C\*. With C\* = 1 the bound
exceeds the exact MFPT in both regimes: by a factor of 1.78 in the first,
and by 3.19×10⁷ (7.5 orders of magnitude) in the second. **C\* = 1 is
not a valid lower bound for the CIR first-passage time.** The implicit
C\* values (0.562 and 3.14×10⁻⁸) are the largest constants for which
the bound holds.

We verified the numerical values by two independent methods. The first
is direct Euler simulation of the CIR
[verification/stochastics/dt_convergence.py]. The simulated MFPT
converges monotonically to the exact value as dt → 0:

| dt | MFPT (α=0.5, σ₀=0.8) | MFPT (α=2.0, σ₀=0.5) |
|----|----------------------|----------------------|
| 0.02 | 12.3115 (+9.7%) | 561.55 (+26.6%) |
| 0.005 | 11.7708 (+4.9%) | 503.71 (+13.5%) |
| 0.001 | 11.3334 (+1.0%) | 461.83 (+4.1%) |
| 0.0005 | 11.2453 (+0.2%) | — |

The Euler scheme with max(R, 0) truncation overestimates the MFPT
because it delays arrival at the threshold. The bias is monotone in dt
and consistent across regimes.

The second method is the censoring test
[verification/stochastics/censoring_test.py]. In the first regime the
process has no censoring within T_max = 300: all 20,000 simulated paths
reach R₀. In the second regime only 39.7% reach R₀ at T_max = 300, and
the tail of τ is geometric (ratio P_emp/P_geo ≈ 0.9927 with std 0.0038
across five windows). The geometric tail implies that the unconditional
MFPT is T₀/(1 − p) where p = P(τ > T₀), giving 635.7 in that regime.

The two methods agree on the qualitative structure: the first-passage
time is finite, grows with R₀, and is dominated by the ratio α/σ₀².
No claim of superexponential growth is made.

## 2.4 Stationary Distribution

Under the Feller condition 2αR̄ ≥ σ₀², the CIR process has a unique
stationary distribution:

    R_∞ ~ Gamma(k, θ),  k = 2αR̄/σ₀²,  θ = σ₀²/(2α)                 (7)

with moments

    E[R_∞] = kθ = R̄
    Var[R_∞] = kθ² = σ₀²R̄/(2α)                                     (8)

We verify (7) and (8) by simulating the process from R(0) = R̄ over
T = 50, discarding the first 50% of samples as burn-in, and comparing
empirical moments against the theoretical values
[verification/stochastics/stationary_stats.py]. The results:

| Parameters | E[R_∞] theory | E[R_∞] empirical | Var theory | Var empirical |
|------------|---------------|-------------------|------------|----------------|
| α=0.5, σ₀=0.8 | 1.000000 | 0.998296 (0.17%) | 0.640000 | 0.637595 (0.38%) |
| α=2.0, σ₀=0.5 | 1.000000 | 1.000062 (0.006%) | 0.062500 | 0.063097 (0.96%) |

The relative differences are below 1% in all four quantities. The
Z-score of the whitewashing target R₀ = 2.2 is 1.50σ in the first
regime and 4.80σ in the second, consistent with empirical estimates
(1.5050σ and 4.7770σ).

A two-sample Kolmogorov–Smirnov test against Gamma(k, θ) does not
reject the stationary distribution at 95%: D = 0.00354, p = 0.557
(first regime); D = 0.00479, p = 0.201 (second regime). Because the
simulated values are autocorrelated (50,000 paths × 2,500 steps), the
KS p-value is indicative only. The moment comparison is the primary
evidence.

## 2.5 Integro-Differential Formulation

For the Fokker–Planck density p(r, t) of the reputation process, the
forward equation is:

    ∂p/∂t = −∂/∂r[μ(r)p] + ½ ∂²/∂r²[σ²(r)p]
            + λ ∫_{0}^{1} [p(r/y, t)/y − p(r, t)] ν(dy)           (9)

with μ(r) = α(R̄ − r), σ²(r) = σ₀²r, and the jump term written for the
multiplicative specification. The domain is r ∈ (0, ∞), with absorbing
boundary at r = 0.

The associated value function C_R(r) for reputational collateral
satisfies the integro-differential equation:

    ∂C_R/∂t + μ(r)∂C_R/∂r + ½σ²(r)∂²C_R/∂r²
        + λ ∫_{0}^{1}[C_R(ry) − C_R(r)]ν(dy) − rC_R = −π(r)        (10)

with boundary condition C_R(0) = 0, interpreted in the viscosity sense.
Existence and uniqueness follow from standard arguments for integro-PDEs
with polynomial growth of π [see Oksendal–Sulem, Applied Stochastic
Control of Jump Diffusions, 2nd ed., Chapter 12].

## 2.6 Summary of the Section

| Claim | Status | Script |
|-------|--------|--------|
| Additive jumps violate positivity | Verified | `sim_positivity.py` |
| Multiplicative jumps preserve positivity | Verified | `sim_positivity.py` |
| Exact MFPT via numerical integration | Verified | `mfpt_bound_explicit.py` |
| C\* = 1 is not a valid bound | Verified | `mfpt_bound_explicit.py` |
| Euler bias decreases with dt | Verified | `dt_convergence.py` |
| D4 tail is geometric; S2.2 has no censoring | Verified | `censoring_test.py` |
| Stationary distribution is Gamma(k, θ) | Verified | `stationary_stats.py` |

The Section's quantitative content is limited to:
- Positivity verification (40.58% vs 0.0000%).
- Exact MFPT by numerical integration (11.2203 and 443.7374).
- C\* implicit per regime (0.562 and 3.14×10⁻⁸).
- Convergent simulated MFPT with dt (11.2453 at dt=5e-4).
- Stationary moments (relative difference below 1%).

