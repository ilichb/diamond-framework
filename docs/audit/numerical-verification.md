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
  dimensions are handled separately. The full payment rule is still **pending**.

## Open items

| Item | Owner component | Status |
|------|-----------------|--------|
| `mu` sweep over bootstrap dynamics | `verification/bootstrap/` | Pending |
| Myerson payment rule specification | `verification/mechanism/` | Pending |
| Gas and latency benchmarks | `integrations/avalanche/` | Pending |
| Sections 6, 8 and 9 of the paper | `docs/paper/` | Open items |
| External security review | whole protocol | Not started |

## Reporting a falsification

Open a GitHub issue with the label `falsification`, including:

- the claim and where it appears,
- the script (or a minimal reproduction) that contradicts it,
- the sample size and seed used.

We will correct the claim or remove it.
