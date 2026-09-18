# Verification Suite

This directory contains the scripts that verify every quantitative
claim in the Diamond Framework paper.

## Structure

- `stochastics/` — Reputation dynamics (positivity, MFPT, stationarity).
- `mechanism/` — Frobenius counterexample, fee specification.
- `zk/` — Constraint counts and soundness of the threshold circuit.
- `rmt/` — Spectral calibration for collusion detection.
- `tensor/` — Tucker compression analysis.
- `data-layer/` — Fraud proof incentive equilibrium.
- `bootstrap/` — Genesis transition and reputation models.

## Running

    pip install -r requirements.txt
    python3 stochastics/sim_positivity.py
    python3 stochastics/stationary_stats.py
    python3 stochastics/mfpt_bound_explicit.py
    python3 stochastics/dt_convergence.py
    python3 stochastics/censoring_test.py
    python3 mechanism/frobenius_counterexample.py
    python3 mechanism/fee_specification.py
    python3 zk/constraint_count_check.py
    python3 zk/soundness_zk_check.py
    python3 rmt/sim_laplacian.py
    python3 rmt/calibration_modularity.py
    python3 rmt/clique_spectra.py
    python3 rmt/wilson_intervals.py
    python3 tensor/tucker_analysis.py
    python3 data-layer/simulate_data_layer_v3.py
    python3 bootstrap/compare_reputation_models.py
    python3 bootstrap/sweep_net_gain.py
    python3 bootstrap/simulate_bootstrap_net_gain.py

## Runtime

Approximate runtimes on a 2020-era desktop:

| Script | Time |
|--------|------|
| sim_positivity.py | ~34 s |
| calibration_modularity.py | ~400 s |
| dt_convergence.py | ~130 s |
| censoring_test.py | ~17 s |
| clique_spectra.py | ~17 s |
| wilson_intervals.py | < 1 s |
| stationary_stats.py | ~12 s |
| All others | < 5 s each |

Total: ~10 min on a single core.

## Reproducibility

All scripts use numpy.random.default_rng with declared seeds. Monte
Carlo sample sizes are declared at the top of each file. Tail
quantiles require N >= 100 / alpha for reliable estimation.
