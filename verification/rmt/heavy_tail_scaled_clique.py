#!/usr/bin/env python3
"""
heavy_tail_scaled_clique.py - Finding C-23: isolate the clique-size confound
in the heavy-tail collusion test.

C-22 (heavy_tail_n5000.py, F-020) ran the n = 5000 experiment and tripped the
stop-gate: at a fixed clique size m = 20 the per-null true-positive rate is
below 0.5 for every beta. That run conflates two effects:

  (i)  the heavy-tail miscalibration of the ER threshold (F-019), and
  (ii) clique-size scaling: at n = 5000 a fixed m = 20 clique is 0.4% of the
       network, versus 4% at n = 500. Even on a pure ER null the ER-baseline
       power at m = 20 collapses (TPR_ER = 0.005), so the experiment cannot
       tell "the test fails on heavy tails" from "m = 20 is too small".

This script separates the two. Holding n = 5000 and the null models fixed, it
sweeps the clique size over three regimes:

  m = 20   fixed size (continuity with C-22 / F-019 at n = 500)
  m = 63   preserves the clique fraction of the square root of n
           (m / sqrt(n): 20 / sqrt(500) = 0.894 -> 0.894 * sqrt(5000) = 63.2)
  m = 200  preserves the clique fraction of n (m / n: 20 / 500 = 4% -> 200)

For each (null model, clique size) it reports the per-null TPR (at the null's
own q99) and the ER-threshold TPR, with Wilson 95% intervals, plus the ER
baseline TPR with the scaled clique. The decision rule (C-23):

  TPR_pernull >= 0.9 at m = 63 for beta >= 2.3
      -> power recovers once the clique scales with sqrt(n); Section 5.4
         must state the sqrt(n) scaling rule.
  TPR_pernull < 0.5 at m = 200 for beta >= 2.3
      -> the failure is structural, not a scale artifact; Section 5.4 must
         drop the "n >= 5000" remedy and the defence falls to S_min.
  otherwise
      -> mixed; report per beta and edit Section 5.4 per regime.

The null sampler (Erdos-Renyi / Chung-Lu, planted clique) is imported from
heavy_tail_n5000.py, so the H0 calibration here reproduces C-22 exactly.

Output: verification/rmt/results/heavy_tail_scaled_clique_output.txt

Deterministic: seed declared, no clock, no disk I/O. The independent-seed
tasks are distributed over cores; each task's result depends only on its own
seed, so the output is identical to a serial run.

Runtime: a few minutes on 6 cores.
"""

import os
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))

import heavy_tail_n5000 as ht  # noqa: E402

N = ht.N
D_MEAN = ht.D_MEAN
N_H0 = ht.N_H0
N_H1 = ht.N_H1
RNG_SEED = ht.RNG_SEED
ALPHA = ht.ALPHA
BETAS = ht.BETAS
DENSITY_FACTOR = ht.DENSITY_FACTOR
CLIQUE_SIZES = (20, 63, 200)
Q99_ER_N500 = ht.Q99_ER_N500
NPROC = min(6, os.cpu_count() or 1)


def _q99(vals):
    return float(np.quantile(vals, 1 - ALPHA))


def _h0_task(model):
    """N_H0 H0 replicates of lambda_max(B) for one null model.
    model = ("ER", None) or ("CL", beta)."""
    name, beta = model
    rng = np.random.default_rng(RNG_SEED)
    if name == "ER":
        w, p = None, D_MEAN / (N - 1)
    else:
        w, p = ht.chung_lu_expected_degrees(N, D_MEAN, beta), None
    vals = np.empty(N_H0)
    for i in range(N_H0):
        A = ht.sample_sparse(N, ht.make_block_fn(w, N, p, None, 1.0), rng)
        vals[i] = ht.lambda_max_B(A)
    return vals


def _h1_task(task):
    """N_H1 replicates of lambda_max(B) for one null model with one planted
    clique (size m, intra density DENSITY_FACTOR). task = (name, beta, m)."""
    name, beta, m = task
    rng = np.random.default_rng(RNG_SEED)
    if name == "ER":
        w, p = None, D_MEAN / (N - 1)
    else:
        w, p = ht.chung_lu_expected_degrees(N, D_MEAN, beta), None
    vals = np.empty(N_H1)
    for i in range(N_H1):
        clique = np.sort(rng.choice(N, size=m, replace=False))
        A = ht.sample_sparse(
            N, ht.make_block_fn(w, N, p, clique, DENSITY_FACTOR), rng)
        vals[i] = ht.lambda_max_B(A)
    return vals


def wilson_ci(k, n, z=1.96):
    p = k / n
    denom = 1 + z * z / n
    center = (p + z * z / (2 * n)) / denom
    half = z / denom * np.sqrt(p * (1 - p) / n + z * z / (4 * n * n))
    return center - half, center + half


def _map(task_fn, items):
    if NPROC == 1:
        return [task_fn(x) for x in items]
    import multiprocessing as mp
    with mp.Pool(NPROC) as pool:
        return pool.map(task_fn, items)


def main():
    models = [("ER", None)] + [("CL", b) for b in BETAS]
    c22_q99 = {2.1: 47.3792, 2.3: 37.0298, 2.5: 30.2631, 3.0: 22.8598}

    print("=" * 78)
    print("CLIQUE-SIZE SWEEP AT n = 5000 (C-23)")
    print("=" * 78)
    print()
    print(f"n = {N}, d_mean = {D_MEAN}, seed = {RNG_SEED}, alpha = {ALPHA}")
    print(f"N_H0 = {N_H0}, N_H1 = {N_H1}, intra-clique density = {DENSITY_FACTOR}x")
    print("clique sizes: " + ", ".join(f"m = {m}" for m in CLIQUE_SIZES))
    print("  (m = 20 fixed; m = 63 preserves m/sqrt(n); m = 200 preserves m/n)")
    print(f"cores = {NPROC}")
    print()

    h0_vals = _map(_h0_task, models)
    q99 = {model: _q99(v) for model, v in zip(models, h0_vals)}
    q99_er = q99[("ER", None)]

    print("1. H0 CALIBRATION (must reproduce C-22; FPR is vs the ER threshold)")
    print("-" * 78)
    print(f"   {'model':>6} {'beta':>6} {'q99':>9} {'C-22 q99':>9} "
          f"{'FPR_ER':>8}")
    for (name, beta), v in zip(models, h0_vals):
        bstr = "--" if beta is None else f"{beta:.2f}"
        c22 = "--" if name == "ER" else f"{c22_q99[beta]:.4f}"
        fpr = float((v > q99_er).mean())
        print(f"   {name:>6} {bstr:>6} {q99[(name, beta)]:>9.4f} {c22:>9} "
              f"{fpr:>8.4f}")
    print(f"   ER baseline q99 at n = 5000 = {q99_er:.4f} "
          f"(canonical at n = 500 = {Q99_ER_N500})")
    print()

    tasks = [(name, beta, m) for (name, beta) in models for m in CLIQUE_SIZES]
    h1_vals = _map(_h1_task, tasks)
    res = {t: v for t, v in zip(tasks, h1_vals)}

    def tpr_own(name, beta, m):
        return int((res[(name, beta, m)] > q99[(name, beta)]).sum()) / N_H1

    def tpr_er(name, beta, m):
        return int((res[(name, beta, m)] > q99_er).sum()) / N_H1

    print("2. POWER VS ONE PLANTED CLIQUE, BY SIZE")
    print("-" * 78)
    print(f"   {'model':>6} {'beta':>6} {'m':>4} {'q99_own':>9} {'TPR_own':>8} "
          f"{'CI95_own':>15} {'TPR_ER':>8}")
    for name, beta in models:
        for m in CLIQUE_SIZES:
            v = res[(name, beta, m)]
            k_own = int((v > q99[(name, beta)]).sum())
            lo, hi = wilson_ci(k_own, N_H1)
            bstr = "--" if beta is None else f"{beta:.2f}"
            print(f"   {name:>6} {bstr:>6} {m:>4} {q99[(name, beta)]:>9.4f} "
                  f"{k_own / N_H1:>8.3f} {('[%.3f,%.3f]' % (lo, hi)):>15} "
                  f"{tpr_er(name, beta, m):>8.3f}")
    print()

    print("3. DECISION (C-23 rule)")
    print("-" * 78)
    heavy = [b for b in BETAS if b >= 2.3]
    t63 = {b: tpr_own("CL", b, 63) for b in heavy}
    t200 = {b: tpr_own("CL", b, 200) for b in heavy}
    print("   per-null TPR by beta at the two scaled sizes:")
    print(f"   {'beta':>6} {'m=63':>8} {'m=200':>8}")
    for b in heavy:
        print(f"   {b:>6.2f} {t63[b]:>8.3f} {t200[b]:>8.3f}")
    min63 = min(t63.values())
    min200 = min(t200.values())
    print()
    print(f"   min per-null TPR at m = 63,  beta >= 2.3: {min63:.3f}")
    print(f"   min per-null TPR at m = 200, beta >= 2.3: {min200:.3f}")
    print()
    if min63 >= 0.9:
        print("   VERDICT: power recovers once the clique scales with sqrt(n).")
        print("   Section 5.4 must state the sqrt(n) scaling rule and that a")
        print("   fixed-size clique is below the detection floor as n grows.")
    elif min200 < 0.5:
        print("   VERDICT: structural failure, not a scale artifact. Even at")
        print("   m = 200 (4% of n, the n = 500 fraction) the heavy-tailed")
        print("   per-null TPR stays below 0.5. Section 5.4 must drop the")
        print("   'n >= 5000' remedy; the defence falls to S_min (Section 6.3).")
    else:
        print("   VERDICT: mixed. Power is size-dependent per beta; report per")
        print("   regime and edit Section 5.4 accordingly.")
    print()
    print("=" * 78)


if __name__ == "__main__":
    main()
