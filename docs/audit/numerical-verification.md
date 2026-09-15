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
- **Verdict:** **Refuted.** The 4.7% figure was not reproducible. With standard parameters
  the measured rate is **40.58%**.
- **Resolution:** The paper reports 40.58%; the original number was withdrawn.

### F-002 — Collusion detection on the normalized adjacency matrix

- **Claim as originally made:** the normalized adjacency matrix `A_sym` is sufficient to
  detect colluding cliques.
- **Test:** `verification/rmt/calibration_modularity.py`
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
- **Verdict:** **Misapplied.** With `S_f*(T)` independent of the private capital cost ω, there is no revelation game. The optimal payment is a uniform posted price `F₀* = π_val(R) − ω̄·Θ`, saturated at the highest-cost type.
- **Resolution:** Section 6 reports the posted price. Myerson applies only if the allocation depends on the private type.
- **Sample:** N_VALIDATORS=1000, ω ~ U[0.01, 0.10], seed 42. IR holds for all types; F0=1.2·F0* breaks IR for 0.2% of sampled types.

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
