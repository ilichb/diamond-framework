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
- **Verdict:** **Refuted.** A_sym attenuates cliques. The modularity
  matrix `B = W - dd^T/(2m)` detects them: for a single small clique
  the true positive rate is **97.2% (modularity with s[-1])** versus
  **3.3% (A_sym)**. Ratio 29.2×.
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
  `verification/stochastics/archive/mfpt_bound.py`
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
  produces λ₂(B) = 8.8537 (s[-2], the statistic at the time), below
  the theoretical edge but above the then-current empirical
  q99 = 8.8372. The empirical threshold is the operational one.
  The right-tail statistic is now s[-1] (see F-018), with
  q99 = 9.0542.
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
  EIP-197 charges 45,000 + 34,000k; adding a constant harness
  overhead of 142 gas yields exactly 113,142 (k=2) and 181,142
  (k=4). The measured 113,142 was correct for k=2 but mislabeled.
- **Resolution:** v2 uses a parameterized function; k=4 for Groth16
  is 181,142 gas (measured). The linearity is verified exactly
  against EIP-197 for k ∈ {1, 2, 4}.

### F-018 — Right-tail statistic uses s[-2] instead of s[-1]

- **Claim as originally made:** the right-tail statistic for the
  modularity matrix B is lambda_2(B) = s[-2], the second-largest
  eigenvalue.
- **Test:** `verification/rmt/recalibrate_top.py`
- **Verdict:** **Refuted.** For a balanced two-block assortative
  structure (250/250, intra-density 10x the cross-density), the
  signal is at s[-1] = 17.5 while s[-2] = 8.5 sits inside the bulk.
  The paper's statistic is blind to the most natural collusion
  topology. The "skip Perron" convention is valid for the adjacency
  matrix, where s[-1] is the trivial Perron eigenvalue d_max. For
  the modularity matrix, B*1 = 0 places the trivial eigenvalue at
  the middle of the spectrum, and s[-1] is the signal.
- **Resolution:** **Right-tail statistic should be s[-1].**
  s[-1] is clearly better in 4 of 8 configurations, tied in 3,
  and loses by at most 0.05 in 1 (100/400 rho=10, both > 0.94).
  The new null quantile at alpha=0.01 is q99(s[-1]) = 9.0542
  (mean 8.7679, std 0.1115). The cascade update is complete:
  Sections 5.2 and 5.4-5.8, 9.4, 10.3-10.4, 10.7 and 11 use s[-1]
  (commit 5e31e82), and `calibration_modularity.py` returns s[-1]
  with its output regenerated. The `max(s[-1], s[-2])` alternative
  was evaluated and rejected: it is identically equal to s[-1], and
  the standardized max(z1, z2) does not justify the additional
  calibration. The decision is s[-1].
  The mechanism: B*1 = 0 places the trivial eigenvalue at the center
  of the spectrum. With a single planted community, the only direction
  with signal is s[-1], and s[-2] remains in the bulk. With k >= 2
  communities, the partition indicator decomposes into multiple
  directions and s[-2] also carries signal.
  A standardized version max(z1, z2) was also evaluated: it never
  loses power (0 wins, 8 ties, 0 losses) but the threshold rises
  from z99(z1) = 2.5677 to z99(max_z) = 2.8603, absorbing most of
  the benefit. The maximum gain is +0.035 in one configuration.
  The plain s[-1] statistic is retained.

### F-019 — ER-calibrated collusion threshold on heavy-tailed nulls

- **Claim as originally made:** the detection mechanism "must be robust
  to heavy-tailed interaction graphs" (`main.tex:74`) and "the
  calibration is performed on Erdős–Rényi and Chung–Lu graphs"
  (`main.tex:698`, `:1215`), so the threshold `q99 = 9.0542` of
  Section 5.4 applies to them.
- **Test:** `verification/rmt/calibration_heavy_tail.py`
- **Verdict:** **Refuted.** Against four Chung–Lu power-law nulls at the
  same `n = 500`, `d̄ = 20`, the ER threshold rejects every H0 replicate:
  empirical FPR `1.0000` versus the nominal `alpha = 0.01`. The null
  quantiles are `14.4197`, `12.9942`, `12.0039`, `11.3169` for
  `beta = 2.1, 2.3, 2.5, 3.0`, all above `q99 = 9.0542` and above the
  asymptotic edge `2√d̄ = 8.9443` (see F-013). Recalibrating per null
  restores the size and destroys the power: against a single planted
  clique (`m = 20`, density 10x) the true positive rate at the null's
  own `q99` is `0.000`, `0.000`, `0.020`, `0.155`. The `TPR = 1.000` at
  the ER threshold is degenerate: a test that rejects every H0 graph has
  unit power by construction, so the published power figure carries no
  evidence of robustness on heavy-tailed graphs. The same run reproduces
  the committed ER null (mean `8.7693` vs `8.7679`, std `0.1107` vs
  `0.1115`, `main.tex:636`) and the published ER power (`0.960` vs
  `0.972`, `main.tex:1129`), so the CL result is not an artifact of the
  harness.
- **Resolution:** Section 5.4 must state that the ER-calibrated `q99`
  does not transfer to heavy-tailed nulls, and that the test requires
  either per-null recalibration or a weight-dependent bulk edge
  (proposed, not yet applied). The attribution "and Chung–Lu" at
  `main.tex:698` and `:1215` is not backed by any threshold-level CL
  measurement: the only CL graph in the suite before this script,
  `verification/rmt/sim_laplacian.py` (`beta = 2.3`), feeds the `L_sym`
  vs `A_sym` comparison, not the calibration of `q99`.
- **Sample:** `calibration_heavy_tail.py`, seed 42, `n = 500`,
  `d̄ = 20`, `N_H0 = 500`, `N_H1 = 200`, weights
  `w_i ∝ i^(-1/(beta-1))` normalised to `d̄`; deterministic (two runs,
  identical md5).
- **Caveat:** at `beta = 2.1` and `2.3` the requested degree sequence
  exceeds what a simple graph admits at `n = 500` (`d_max = 1120` and
  `694` against `n - 1 = 499`), so the null is realised with the excess
  stubs rejected (`7.32%` and `1.97%`) and those two rows are
  degree-capped rather than pure-tail. Separating a genuine tail from a
  saturated hub core requires `n >= 5000` (or a much smaller `d̄`); it is
  registered as a postponed experiment, with the code stored outside the
  repository.

### F-020 — The `n >= 5000` remedy for the heavy-tail threshold is refuted

- **Claim as originally made:** "The separation of the genuine tail from
  the saturated hub core requires `n >= 5000` (or a much smaller `d̄`) and
  a recalibrated Erdős–Rényi baseline" (`main.tex` §5.4), with the code
  "stored outside the repository as a postponed experiment" (restated in
  F-019).
- **Test:** `verification/rmt/heavy_tail_n5000.py`, `n = 5000`,
  `d̄ = 20`, seed 42, `N_H0 = 500`, `N_H1 = 200`, `alpha = 0.01`,
  clique size `m = 20` fixed, intra-clique density 10x,
  `beta in {2.1, 2.3, 2.5, 3.0}`.
- **Verdict:** **Refuted.** Increasing `n` does not restore the
  calibration.
- **Degree-sequence feasibility:** `beta = 2.1` remains degree-capped at
  `n = 5000` (expected `d_max = 7445.8` against `n - 1 = 4999`), so the
  "requires `n >= 5000`" remedy is false for the heaviest tail;
  `beta >= 2.3` is realised without capping.
- **FPR:** at the recalibrated ER threshold (`q99 = 9.1957` at
  `n = 5000`) the empirical false-positive rate is `1.0000` for all four
  Chung–Lu nulls (null `q99` = `47.3792`, `37.0298`, `30.2631`,
  `22.8598`; null-to-threshold shift `+38.18`, `+27.83`, `+21.07`,
  `+13.66`). F-019 is confirmed, not resolved, at `n = 5000`.
- **Per-null power:** recalibration does not restore the power:
  `TPR_pernull = 0.000, 0.010, 0.015, 0.005` for
  `beta = 2.1, 2.3, 2.5, 3.0` (Wilson 95% CIs all below `0.05`).
- **Scale confound:** the ER baseline itself loses power at `n = 5000`
  (`TPR_ER = 0.005` on pure Erdős–Rényi), because a fixed `m = 20`
  clique is `0.4%` of `n` at `n = 5000` versus `4%` at `n = 500`. The
  experiment therefore conflates heavy-tail miscalibration with
  clique-size scaling; it does not isolate the heavy-tail effect.
- **Conclusion:** The "requires `n >= 5000`" remedy is refuted. Whether
  the modularity-spectrum test is recoverable on heavy-tailed graphs at
  a fixed clique fraction is not resolved by this experiment; it is
  carried as C-23.
- **Sample:** `heavy_tail_n5000.py`, deterministic (seed 42), output in
  `verification/rmt/results/heavy_tail_n5000_output.txt`.

### F-021 — The heavy-tail failure is structural, not a clique-size artifact

- **Claim under test:** the E.R.-threshold failure on Chung–Lu nulls
  (F-019, F-020) might be an artifact of the clique scale: at `n = 5000`
  a fixed `m = 20` clique is `0.4%` of `n`, versus `4%` at `n = 500`
  (F-020), so a small clique could be below the detection floor for
  reasons unrelated to the tail.
- **Test:** `verification/rmt/heavy_tail_scaled_clique.py`, `n = 5000`,
  `d̄ = 20`, seed 42, `N_H0 = 500`, `N_H1 = 200`, `alpha = 0.01`, one
  planted clique at sizes `m = 20` (fixed), `m = 63` (preserves
  `m/√n`), `m = 200` (preserves `m/n`), intra-density 10x. The null
  sampler is imported from F-020, so the H0 calibration reproduces it
  exactly.
- **Verdict:** **Confirmed** (structural). The clique-size effect is
  real but orthogonal: at `m = 200` the ER baseline recovers full power
  (`TPR = 1.000`, Wilson 95% `[0.981, 1.000]`), whereas every Chung–Lu
  null stays at or below `0.085` under its own recalibrated `q99`
  (`0.025`, `0.035`, `0.035`, `0.085` for `beta = 2.1, 2.3, 2.5, 3.0`;
  all Wilson upper bounds `<= 0.132`). At the same clique fraction and
  the same `n`, ER detects and Chung–Lu does not.
- **Conclusion:** The modularity-spectrum test does not transfer to
  heavy-tailed graphs. The "requires `n >= 5000`" remedy is removed from
  `main.tex` §5.4; §5.7 declares that detection is not the binding
  defence in heavy-tailed regimes and that the guarantee rests on the
  financial floor `S_min` (C-21).
- **Sample:** `heavy_tail_scaled_clique.py`, deterministic (seed 42),
  output in
  `verification/rmt/results/heavy_tail_scaled_clique_output.txt`.

## Open items

| Item | Owner component | Status |
|------|-----------------|--------|
| `mu` sweep over bootstrap dynamics | `verification/bootstrap/` | **Done** — see F-005 (μ/g ∈ [1, 2]) |
| Payment rule specification | `verification/mechanism/` | **Done** — posted price F0*, not Myerson |
| Gas benchmarks | `integrations/avalanche/` | **Done** — ecPairing k=4 = 181,142 |
| Heavy-tailed threshold calibration | `verification/rmt/` | **Done** — see F-019 (ER `q99` does not transfer to Chung–Lu nulls) |
| Teleporter latency | `integrations/avalanche/` | Pending (requires testnet) |
| External security review | whole protocol | Not started |

## Reporting a falsification

Open a GitHub issue with the label `falsification`, including:

- the claim and where it appears,
- the script (or a minimal reproduction) that contradicts it,
- the sample size and seed used.

We will correct the claim or remove it.
