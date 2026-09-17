# Numerical Verification Log

**Status:** living document, backfilled as each component is merged into `verification/`.

This log records every quantitative claim of the Diamond Framework, the script that tests
it, and the verdict. It exists because the project documents its own error correction: a
claim that fails its test is corrected or removed, not quietly reworded.

## Rules

1. Every quantitative claim requires a script in `verification/`.
2. Every script declares its sample size (`N_REPLICATES` for Monte Carlo, and the
   estimation method for empirical quantiles).
3. Every script is deterministic given its seed, and the seed is declared in the output.
4. Claims without numerical backing are labelled `[CONJECTURE]` in the paper.

## Falsification history

### F-001 — Positivity rate of reputation trajectories

- **Claim as originally made:** 4.7% of trajectories go negative.
- **Test:** `verification/stochastics/sim_positivity.py`
- **Verdict:** **Refuted.** The 4.7% figure was fabricated: it was
  presented as the result of a simulation that was never run. With
  standard parameters the measured rate is **40.58%**.
- **Resolution:** The paper reports 40.58%; the original number was withdrawn.

### F-002 — Collusion detection on the normalized adjacency matrix

- **Claim as originally made:** the normalized adjacency matrix `A_sym` is sufficient to
  detect colluding cliques.
- **Test:** `verification/rmt/calibration_modularity.py`,
  `verification/rmt/clique_spectra.py`,
  `verification/rmt/archive/calibracion_rmt.py`
- **Verdict:** **Refuted.** `A_sym` attenuates cliques. The modularity matrix
  `B = W - dd^T/(2m)` detects them: for a single small clique the true positive rate is
  **24.8% (modularity)** versus **3.3% (`A_sym`)**.
- **Resolution:** The protocol's collusion test uses the modularity matrix.

### F-003 — Tracy–Widom threshold

- **Claim as originally made:** the theoretical Tracy–Widom threshold applies to the
  collaboration graph spectrum.
- **Verdict:** **Not applicable.** Sparse, heavy-tailed collaboration graphs violate the
  assumptions behind the TW law.
- **Resolution:** The protocol uses empirically calibrated quantiles instead of the
  theoretical threshold.

### F-004 — Myerson projection via Frobenius norm

- **Claim as originally made:** a multidimensional type can be projected to a scalar with
  the Frobenius norm before applying the Myerson rule.
- **Test:** `verification/mechanism/frobenius_counterexample.py`
- **Verdict:** **Refuted.** Collapsing the type to a scalar destroys the information needed
  for incentive compatibility.
- **Resolution:** Myerson is applied only to the capital cost type; the remaining
  dimensions are handled separately. The payment rule is a saturated uniform posted price,
  not a Myerson auction. See `fee_specification.py`.

### F-005 — Direction of μ in the net_gain model

- **Claim as originally made:** increasing μ increases reputation dispersion.
- **Verdict:** **Partially refuted.** Increasing μ reduces R* and dispersion.
  The correct direction is to decrease μ toward the band μ/g ∈ [1, 2].
- **Resolution:** The paper reports μ/g = 1.5 as the argmax of R_std. The
  optimum is a band, not a point.
- **Test:** `verification/bootstrap/sweep_net_gain.py`
- **Sample:** μ sweep with g = 0.01, N_SEEDS = 5 (seeds 42–46), N_EPOCHS = 500;
  R_std = 0.0424 at μ/g = 1.5, 0.0405 at 1.0, 0.0383 at 0.8, 0.0190 at 0.2.

### F-006 — Myerson rule for the payment

- **Claim as originally made:** the payment follows Myerson's optimal auction rule.
- **Test:** `verification/mechanism/fee_specification.py`
- **Verdict:** **Misapplied.** With `S_f*(T)` independent of the private capital cost ω, there is no revelation game and IC is tautological (the type is publicly verified on-chain). The optimal payment is a uniform posted price `F₀* = π_val(R) − ω̄·Θ`, saturated at the highest-cost type.
- **Resolution:** Section 6 reports the posted price. Myerson applies only if the allocation depends on the private type.
- **Sample:** N_VALIDATORS=1000, ω ~ U[0.01, 0.10], seed 42. IR holds for all types; F0=1.2·F0* breaks IR for 0.2% of sampled types.

### F-007 — Whitewashing bound tightness

- **Claim as originally made:** the analytical bound on the whitewashing
  first-passage time is superexponential and therefore vacuous.
- **Test:** `verification/stochastics/mfpt_bound_explicit.py`,
  `verification/stochastics/dt_convergence.py`,
  `verification/stochastics/mfpt_bound.py`
- **Verdict:** **Refuted.** The claim that the analytical bound
  is vacuous was based on a C*=1 normalization that is not
  universal. With the corrected MFPT (11.2203 for scenario 2.2,
  443.7374 for scenario D4) and the C*=1 bound (19.965 and
  1.415×10¹⁰), the ratio bound/MFPT is 1.78 in scenario 2.2 and
  3.19×10⁷ in D4 (7.5 orders of magnitude). The bound with C*=1
  is invalid in both regimes: the implicit C* is 0.562 and
  3.14×10⁻⁸ respectively.
- **Resolution:** Section 2.3 reports the bound with C* specified
  per regime, not with C*=1. The paper reports the exact MFPT
  from numerical integration as the primary quantity.
- **Sample:** `mfpt_bound_explicit.py` (numerical integration,
  error < 1e-7) and `dt_convergence.py` (N=5000 S2.2, N=2000 D4,
  seeds 42).

### F-008 — KS test in stationary_stats.py

- **Claim as originally made:** the stationary distribution of the CIR
  process was tested against Gamma(k, θ) and rejected.
- **Test:** `verification/stochastics/stationary_stats.py`
- **Verdict:** **Mis-tested.** The original script computed
  `max|sorted_emp - sorted_theory|/std`, which is a difference of order
  statistics, not an ECDF difference. The correct two-sample KS gives
  D=0.00354, p=0.557 (scenario 1) and D=0.00479, p=0.201 (scenario 2).
  Neither rejects Gamma at 95%.
- **Resolution:** The script is patched with a standard two-sample KS.
  The paper reports the moments (E, Var) as primary evidence and the KS
  as supplementary.
- **Caveat:** samples are autocorrelated (50k paths × 2500 steps), so
  the KS p-value is indicative, not strictly valid. Effective sample
  size is smaller than the raw count.

### F-009 — Catastrophic cancellation in mfpt_bound_explicit.py

- **Claim as originally made:** the explicit MFPT integral evaluates to
  -84905 (scenario 1) and 2.68e119 (scenario 2).
- **Test:** `verification/stochastics/mfpt_bound_explicit.py`
- **Verdict:** **Refuted.** The scale function s(x) = ∫_ε^x u^{−κ}e^{βu}du
  diverges at 0 for κ > 1. Computing s(R₀) − s(y) subtracts two nearly
  equal large numbers, losing all significant digits.
- **Resolution:** the script is rewritten using the well-conditioned
  form g(y) = (2/σ₀²)∫_1^{b/y} s^{−κ}e^{βy(s−1)}ds. The exact MFPT is
  11.220298 (scenario 1) and 443.737421 (scenario 2). C* implicit is
  0.561998 and 3.135455e-08 respectively.

### F-010 — Euler discretization bias in simulated MFPT

- **Claim as originally made:** the simulated MFPT from CIR paths is
  an unbiased estimate of the true mean first-passage time.
- **Test:** `verification/stochastics/dt_convergence.py`
- **Verdict:** **Refuted.** The Euler scheme with max(R, 0)
  truncation introduces a systematic bias that depends on both
  dt and T_max (through right-censoring). For scenario 2.2
  (N=5000, T_max=200, no censoring): MFPT at dt=0.02 is 12.31
  (+9.7% over exact 11.22); at dt=0.0005 it is 11.2453 (+0.22%);
  at dt=0.001 it is 11.3334 (+1.01%).
  For scenario D4 (N=2000, T_max=2000, ~95% hit fraction): MFPT
  at dt=0.02 is +27.6% over exact 443.7; at dt=0.001 it is
  +4.1% (N=2000). Reducing T_max to 1000 introduces right-censoring bias
  that dominates the Euler bias in the opposite direction.
- **Resolution:** The paper reports the exact MFPT from numerical
  integration. Simulated values are reported with explicit dt and
  T_max. Where T_max induces right-censoring above 5% of paths,
  the simulated value is reported as a lower bound on the true
  MFPT.

### F-011 — Factor of 2 in mfpt_bound_explicit.py

- **Claim as originally made:** the exact MFPT integral evaluates to
  22.4406 (scenario 1) and 887.4748 (scenario 2).
- **Test:** `verification/stochastics/dt_convergence.py`
- **Verdict:** **Refuted.** The script computed
  2∫(s(b)−s(y))·m(y)dy with m(y) = 2m'(y), which by the identity
  ∫(s(b)−s(y))m'(y)dy = ∫s'M evaluates to 4∫s'M = 2×E_correct.
  The correct values are 11.220298 and 443.737421.
- **Resolution:** the constant in g_outer is changed from 2/σ₀²
  to 1/σ₀², giving E = 2∫s'M. The dt_convergence test confirms
  convergence to the corrected values.
- **Sample:** `dt_convergence.py` with N_PATHS=5000 (S2.2,
  T_max=200) and 2000 (D4, T_max=2000), dt in {0.02, 0.005,
  0.001, 0.0005}, seeds 42.

### F-012 — Tucker compression and circuit cost

- **Claim as originally made:** Tucker compression reduces both
  storage and the cost of the ZK threshold circuit.
- **Test:** `verification/tensor/tucker_analysis.py`,
  `integrations/avalanche/benchmarks/src/GasBenchmarks.sol`
- **Verdict:** **Partially refuted.** The storage reduction is real
  (500 -> 146 entries, ratio 3.4247x, error 4.8e-16 for clean
  low-rank tensors). The circuit cost reduction is zero: the ZK
  proof (Section 4) verifies the norm of the raw committed tensor,
  not its Tucker approximation. A prover who fabricates the factors
  cannot produce a sound proof against the commitment.
- **Resolution:** Section 3.5 distinguishes storage optimization
  (Tucker, outside the circuit) from security (commitment + proof,
  inside the circuit).
- **Sample:** `tucker_analysis.py`, rank (4,3,3), seed 42.

### F-013 — Empirical vs asymptotic bulk edge in sparse graphs

- **Claim as originally made:** the asymptotic Wigner bulk edge
  2√d̄ is the detection threshold for the modularity matrix B.
- **Test:** `verification/rmt/clique_spectra.py`
- **Verdict:** **Refuted.** For n = 500, d̄ = 20, the theoretical
  edge is 2√20 = 8.9443. A planted clique (k=1, m=20, density 10x)
  produces λ₂(B) = 8.8537, below the theoretical edge but above
  the empirical q99 = 8.8372. The empirical threshold is the
  operational one.
- **Resolution:** Section 5.4 uses the empirical threshold. The
  theoretical edge is reported for reference only.
- **Sample:** `clique_spectra.py`, seed 42, n=500, d̄=20.

### F-014 — Equilibrium formula in v2 of the data layer

- **Claim as originally made:** the equilibrium auditor count is
  n*(B) = round(B/B*).
- **Test:** `verification/data-layer/simulate_data_layer_v3.py`
- **Verdict:** **Refuted.** The round() function shifted the
  transition from B* to 0.75·B*. The correct equilibrium is
  n*(B) = ⌊B/B*⌋, which places the transition exactly at B*.
- **Resolution:** v3 uses integer floor. v2 is retained in the
  repository as a historical record; it is not the canonical
  script for Section 7.
- **Sample:** v2 and v3 with identical parameters; the difference
  is the rounding rule.

### F-015 — Decay reduces final Gini in bootstrap

- **Claim as originally made:** the hybrid_decay policy limits
  accumulation and produces a lower final Gini than hybrid_no_decay.
- **Test:** `verification/bootstrap/simulate_bootstrap_net_gain.py`
- **Verdict:** **Refuted.** Decay lowers R_max (0.4348 vs 0.5976)
  but raises Gini (0.1563 vs 0.1283). The no-decay policy saturates
  the top validators at R ≈ 0.6 and compresses the distribution;
  decay spreads it.
- **Resolution:** Section 8 reports both metrics and recommends
  hybrid_no_decay.
- **Sample:** N_EPOCHS=500, N_MAX=100, N_INIT=10, ENTRY_RATE=0.03,
  seed 42.

### F-016 — Bootstrap numbers depend on reputation model

- **Claim as originally made:** bootstrap dynamics under the
  saturating model (Delta_R = k*a*(1-R)) reduce the median financial
  stake from 1.0 to 0.628 (37% reduction).
- **Test:** `verification/bootstrap/simulate_bootstrap_net_gain.py`
- **Verdict:** **Refuted as the canonical model.** The paper selects
  net_gain (Delta_R = g*a*(1-R) - mu*R) because it is the only model
  with high correlation between activity and reputation (corr = 0.76).
  With net_gain (g=0.01, mu=0.015), the median financial stake under
  hybrid_no_decay is 0.7764, a 22.4% reduction.
- **Resolution:** Section 8 uses net_gain. The saturating script is
  retained in the repository as a historical record; it is not cited
  in the paper.
- **Sample:** identical parameters; the difference is the gain rule.

### F-017 — ecPairing mismeasurement in v1 benchmark

- **Claim as originally made:** ecPairing for Groth16 requires
  113,142 gas (function named benchEcPairing4).
- **Test:** `integrations/avalanche/benchmarks/src/GasBenchmarks.sol`
- **Verdict:** **Refuted.** The function passed 384 bytes to the
  precompile at 0x08, which corresponds to k=2 pairs, not k=4.
  EIP-197 charges 45,000 + 34,000k; the arithmetic with k=2 gives
  113,142 and with k=4 gives 181,142. The measured 113,142 was
  correct for k=2 but mislabeled.
- **Resolution:** v2 uses a parameterized function; k=4 for Groth16
  is 181,142 gas (measured). The linearity is verified exactly
  against EIP-197 for k ∈ {1, 2, 4}.

## Open items

| Item | Owner component | Status |
|------|-----------------|--------|
| `mu` sweep over bootstrap dynamics | `verification/bootstrap/` | **Done** — see F-005 (μ/g ∈ [1, 2]) |
| Payment rule specification | `verification/mechanism/` | **Done** — posted price F0*, not Myerson |
| Gas and latency benchmarks | `integrations/avalanche/` | Pending |
| Sections 6, 8 and 9 of the paper | `docs/paper/` | Open items |
| External security review | whole protocol | Not started |

## Reporting a falsification

Open a GitHub issue with the label `falsification`, including:

- the claim and where it appears,
- the script (or a minimal reproduction) that contradicts it,
- the sample size and seed used.

We will correct the claim or remove it.
