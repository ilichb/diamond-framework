# Verification Suite

This directory contains the scripts that verify every quantitative
claim in the Diamond Framework paper.

## Structure

- `stochastics/` — Reputation dynamics (positivity, MFPT, stationarity).
- `mechanism/` — Frobenius counterexample, fee specification, M-05 attack
  model (deterrence versus detection latency).
- `zk/` — Constraint counts, soundness of the threshold circuit, and the
  threshold-to-stake quantization of the allocation rule.
- `rmt/` — Spectral calibration for collusion detection.
- `tensor/` — Tucker compression analysis.
- `data-layer/` — Fraud proof incentive equilibrium.
- `bootstrap/` — Genesis transition and reputation models.

Three shell helpers orchestrate and check the suite; they are not part of the
numbered claims: `run_all.sh` (harness), `audit-gate.sh` (guards G1..G11) and
`fase0_anchor.sh` (Fase 0 anchor generator — `--check` re-derives the anchor
into a temporary directory and diffs it against the committed one). A fourth
helper, `verification/eip_cost_check.py`, is the script behind guard G7: it
recomputes the EIP gas cost recorded as F-017 and exits 0. It is not a numbered
entry either, and it is why `find verification -maxdepth 2 -name '*.py'` counts
37 while the catalogue lists 36 — the extra `.py` writes no output (see
`docs/audit/post-closure-audit.md:136`).

## Running

    pip install -r requirements.txt
    python3 stochastics/sim_positivity.py
    python3 stochastics/stationary_stats.py
    python3 stochastics/mfpt_bound_explicit.py
    python3 stochastics/dt_convergence.py
    python3 stochastics/censoring_test.py
    python3 stochastics/mfpt_jump_diffusion.py
    python3 stochastics/cr_ide_solver.py
    python3 mechanism/frobenius_counterexample.py
    python3 mechanism/fee_specification.py
    python3 mechanism/fee_specification_net.py
    python3 mechanism/financial_floor_sensitivity.py
    python3 mechanism/m05_attack_model.py
    python3 zk/constraint_count_check.py
    python3 zk/soundness_zk_check.py
    python3 zk/threshold_quantization.py
    python3 zk/succinctness_comparison.py
    python3 rmt/sim_laplacian.py
    python3 rmt/calibration_modularity.py
    python3 rmt/calibration_heavy_tail.py
    python3 rmt/clique_spectra.py
    python3 rmt/clique_spectra_seeds.py
    python3 rmt/asym_weights.py
    python3 rmt/wilson_intervals.py
    python3 rmt/recalibrate_top.py
    python3 rmt/max_statistic.py
    python3 rmt/q99_standard_error.py
    python3 rmt/bipartite_power.py
    python3 rmt/heavy_tail_n5000.py
    python3 rmt/heavy_tail_scaled_clique.py
    python3 tensor/tucker_analysis.py
    python3 data-layer/simulate_data_layer_v3.py
    python3 data-layer/attacker_profit_analytical.py
    python3 bootstrap/compare_reputation_models.py
    python3 bootstrap/sweep_net_gain.py
    python3 bootstrap/simulate_bootstrap_net_gain.py
    python3 bootstrap/r_std_specification.py

## Runtime

The table below is the one quoted in the paper's §9.2: measured on the
reference 2020-era desktop, single core, and indicative. It is *not* a
description of what the current suite costs. The measured runtimes are not
transcribed here — the harness writes them, and the anchored copy is
verifiable:

    ver=verification/baseline_verified          # OUT_DIR of run_all.sh (durable run)
    awk 'NR>1{printf "%-34s %9.2f\n", $1,$3}' $ver/manifest.txt | sort -k2 -nr | head
    awk 'NR>1{s+=$3} END{printf "total %.1f s\n", s}' $ver/manifest.txt    # total 2074.6 s

Drift against the table is real, and mostly toward being faster:
`recalibrate_top.py` ~10 min → 62.93 s, `calibration_modularity.py` ~400 s
→ 103.70 s, `clique_spectra.py` ~17 s → 0.16 s. What has not changed is
where the cost sits: the two heavy-tail scripts are 68.4% of the total
(`heavy_tail_n5000.py` 920.13 s, `heavy_tail_scaled_clique.py` 499.23 s,
which parallelises as the table notes).

| Script | Reference desktop, single core (paper §9.2) |
|--------|------|
| recalibrate_top.py | ~10 min |
| max_statistic.py | ~2 min |
| bipartite_power.py | ~3 min |
| heavy_tail_n5000.py | ~15 min |
| heavy_tail_scaled_clique.py | ~24 min single-core (~5 min on 6 cores) |
| q99_standard_error.py | < 1 s |
| sim_positivity.py | ~34 s |
| calibration_modularity.py | ~400 s |
| calibration_heavy_tail.py | ~60 s |
| dt_convergence.py | ~130 s |
| censoring_test.py | ~17 s |
| mfpt_jump_diffusion.py | ~90 s |
| clique_spectra.py | ~17 s |
| clique_spectra_seeds.py | ~21 s |
| asym_weights.py | < 1 s |
| wilson_intervals.py | < 1 s |
| stationary_stats.py | ~12 s |
| r_std_specification.py | ~5 s |
| cr_ide_solver.py | < 1 s |
| All others | < 5 s each |

Scripts are CWD-independent: the suite reads no data file, and none of its
37 `.py` files (`find verification -maxdepth 2 -name '*.py'`) writes one
either — the `results/*.csv` rules in `.gitignore` are preventive, not a
description of outputs that exist.

## Reproducibility

All scripts use numpy.random.default_rng with declared seeds. Monte
Carlo sample sizes are declared at the top of each file. Tail
quantiles require N >= 100 / alpha for reliable estimation.

## Archive

The `*/archive/` subdirectories contain scripts that are
preserved for historical reference but superseded by canonical
versions. Their outputs are stored under `*/results/archive/`,
parallel to the canonical outputs in `*/results/`.
- `bootstrap/archive/simulate_bootstrap.py` (superseded by
  `bootstrap/simulate_bootstrap_net_gain.py`)
- `data-layer/archive/simulate_data_layer.py` and
  `simulate_data_layer_v2.py` (superseded by
  `data-layer/simulate_data_layer_v3.py`)
- `rmt/archive/` (early RMT versions)
- `stochastics/archive/mfpt_bound.py` (superseded by
  `stochastics/mfpt_bound_explicit.py`)

The archived scripts are not part of the verification suite and
their outputs are not reported in the paper.
