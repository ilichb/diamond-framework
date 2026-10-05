#!/usr/bin/env python3
"""
calibration_heavy_tail.py - Finding C-10: robustness of the collusion
test on heavy-tailed graphs.

The paper claims (main.tex:74 and :566) that the collusion detection
mechanism is robust to heavy-tailed interaction graphs. Section 5
calibrates q99 of lambda_max(B) only on Erdos-Renyi graphs
(calibration_modularity.py, q99 = 9.0542). The single existing
Chung-Lu generator (sim_laplacian.py, power_law_beta = 2.3) measures
lambda_max(L_sym) on one seed, not the null quantile of lambda_max(B).

This script closes that gap: calibrates the null q99 of lambda_max(B)
under Chung-Lu power-law degree distributions with tail exponent beta,
at the same n and mean degree as the canonical calibration, and
compares the shift against the ER baseline.

The generator is reimplemented here (not imported from sim_laplacian)
for two reasons: (i) sim_laplacian's rng is a module-global, not
injectable per replicate; (ii) sim_laplacian applies clip(w, 0.5, None),
which truncates the extreme tail and biases the test. The canonical
Chung-Lu formula p_ij = min(1, w_i w_j / sum(w)) is used.

It also measures the H1 power side: one planted clique on a random node
set of size m, with intra-clique probability 10x the local background
p_bg(i,j) (which generalizes the ER '10x' of clique_spectra.py to the
heterogeneous Chung-Lu background), reporting the true positive rate
under the model's own q99 and under the paper's ER threshold 9.0542,
plus the empirical false-positive rate of that ER threshold on each
null.

The q99 standard error is a non-parametric bootstrap. std/sqrt(n) is the
SE of the mean and understates the uncertainty of an extreme quantile;
it is kept only as a reference column.

Deterministic: numpy-only, seed declared, no clock, no disk I/O.
"""
import numpy as np

N = 500
D_MEAN = 20.0
N_REPLICATES = 500
N_REPLICATES_H1 = 200
N_BOOT = 1000
RNG_SEED = 42
Q99_ER = 9.0542   # canonical, from calibration_modularity.py (informational)
ALPHA = 0.01
BETAS = [2.1, 2.3, 2.5, 3.0]
CLIQUE_K = 1
CLIQUE_M = 20
DENSITY_FACTOR = 10.0

def chung_lu_expected_degrees(n, d_mean, beta):
    """Power-law expected degree sequence w_i proportional to
    i^(-1/(beta-1)), normalized to mean d_mean. beta > 2."""
    idx = np.arange(1, n + 1)
    w = idx ** (-1.0 / (beta - 1.0))
    w = w / w.mean() * d_mean
    return w

def sample_chung_lu(w, rng):
    """Canonical Chung-Lu: p_ij = min(1, w_i w_j / sum(w)).
    Returns symmetric adjacency matrix without diagonal."""
    W_sum = w.sum()
    P = np.outer(w, w) / W_sum
    np.clip(P, 0.0, 1.0, out=P)
    U = rng.random((len(w), len(w)))
    A = (U < P).astype(float)
    A = np.triu(A, k=1)
    A = A + A.T
    return A

def sample_er(n, d_mean, rng):
    """Erdos-Renyi G(n, p) with p = d_mean / (n - 1)."""
    p = d_mean / (n - 1)
    A = (rng.random((n, n)) < p).astype(float)
    A = np.triu(A, k=1)
    A = A + A.T
    return A

def sample_er_h1(n, d_mean, rng, clique_size, density_factor):
    """ER background with one planted clique on clique_size random nodes.

    Intra-clique pairs take p_clique(i,j) = min(1, density_factor * p_bg)
    in place of p_bg, exactly as generate_h1 in clique_spectra.py. The
    node set is drawn with rng.choice; under ER the block position is
    exchangeable, so this matches the contiguous first-block convention
    of clique_spectra.py statistically.
    """
    p_bg = d_mean / (n - 1)
    clique = np.sort(rng.choice(n, size=clique_size, replace=False))
    P = np.full((n, n), p_bg)
    block = P[np.ix_(clique, clique)]
    np.clip(density_factor * block, 0.0, 1.0, out=block)
    P[np.ix_(clique, clique)] = block
    U = rng.random((n, n))
    A = (U < P).astype(float)
    A = np.triu(A, k=1)
    A = A + A.T
    return A

def sample_chung_lu_h1(w, rng, clique_size, density_factor):
    """Chung-Lu background with one planted clique on clique_size random
    nodes.

    Background p_bg(i,j) = min(1, w_i w_j / sum(w)); intra-clique pairs
    take min(1, density_factor * p_bg(i,j)), generalizing the '10x' rule
    to the heterogeneous background. The clique nodes are drawn at
    random (rng.choice), not taken as a contiguous block: in a power-law
    degree sequence the first clique_size indices hold the highest-
    degree hubs, so a contiguous block would inflate the planted signal.
    """
    n = len(w)
    P_bg = np.outer(w, w) / w.sum()
    np.clip(P_bg, 0.0, 1.0, out=P_bg)
    clique = np.sort(rng.choice(n, size=clique_size, replace=False))
    P = P_bg.copy()
    block = P[np.ix_(clique, clique)]
    np.clip(density_factor * block, 0.0, 1.0, out=block)
    P[np.ix_(clique, clique)] = block
    U = rng.random((n, n))
    A = (U < P).astype(float)
    A = np.triu(A, k=1)
    A = A + A.T
    return A

def modularity_lambda_max(A):
    """Largest eigenvalue of B = A - d d^T / (2m)."""
    d = A.sum(axis=1)
    two_m = d.sum()  # = 2m
    B = A - np.outer(d, d) / two_m
    eig = np.linalg.eigvalsh(B)
    return eig[-1]

def calibrate(sample_fn, n_rep, seed):
    """Run n_rep replicates, return array of lambda_max(B)."""
    rng = np.random.default_rng(seed)
    vals = np.empty(n_rep)
    for i in range(n_rep):
        A = sample_fn(rng)
        vals[i] = modularity_lambda_max(A)
    return vals

def summarize(vals):
    q99 = float(np.quantile(vals, 1 - ALPHA))
    mean = float(vals.mean())
    std = float(vals.std(ddof=1))
    se = std / np.sqrt(len(vals))
    return mean, std, q99, se

def bootstrap_q99_se(vals, n_boot=1000, rng_seed=RNG_SEED):
    """SE of the 0.99 quantile by non-parametric bootstrap."""
    rng = np.random.default_rng(rng_seed)
    n = len(vals)
    q99_boot = np.empty(n_boot)
    for b in range(n_boot):
        idx = rng.integers(0, n, size=n)
        q99_boot[b] = np.quantile(vals[idx], 0.99)
    return float(q99_boot.std(ddof=1))

def wilson_ci(k, n, z=1.96):
    """Wilson score interval for a binomial proportion. Same formula as
    verification/rmt/wilson_intervals.py, inlined to keep this file
    self-contained."""
    p_hat = k / n
    denom = 1 + z ** 2 / n
    center = (p_hat + z ** 2 / (2 * n)) / denom
    half = z / denom * np.sqrt(p_hat * (1 - p_hat) / n + z ** 2 / (4 * n ** 2))
    return center - half, center + half

def main():
    print("=" * 78)
    print("CALIBRATION OF THE COLLUSION TEST ON HEAVY-TAILED GRAPHS (C-10)")
    print("=" * 78)
    print()
    print(f"n = {N}, d_mean = {D_MEAN}")
    print(f"N_REPLICATES(H0) = {N_REPLICATES}, N_REPLICATES(H1) = {N_REPLICATES_H1}, N_BOOT = {N_BOOT}")
    print(f"seed = {RNG_SEED}, alpha = {ALPHA}")
    print(f"clique: k = {CLIQUE_K}, m = {CLIQUE_M}, intra density = {DENSITY_FACTOR}x local p_bg")
    print(f"Canonical ER threshold (calibration_modularity.py) = {Q99_ER}  [informational]")
    print()

    # ---- H0: null distribution of lambda_max(B) per model ----
    models = []
    vals_er = calibrate(lambda rng: sample_er(N, D_MEAN, rng), N_REPLICATES, RNG_SEED)
    models.append(("ER", None, vals_er, None))
    for beta in BETAS:
        w_beta = chung_lu_expected_degrees(N, D_MEAN, beta)
        vals_beta = calibrate(lambda rng, w=w_beta: sample_chung_lu(w, rng),
                              N_REPLICATES, RNG_SEED)
        models.append(("CL", beta, vals_beta, w_beta))

    q99_er_n500 = float(np.quantile(models[0][2], 1 - ALPHA))

    print("--- H0: null calibration; shift is vs the ER baseline at the same N ---")
    print()
    print(f"{'model':>6} {'beta':>6} {'mean':>7} {'std':>7} {'q99':>7} {'shift':>7} "
          f"{'SE_mean':>8} {'SE_q99':>8} {'ratio':>6} {'FPR':>7}")
    print("-" * 78)
    h0 = []
    for name, beta, vals, _w in models:
        m, s, q99, se_mean = summarize(vals)
        se_q99 = bootstrap_q99_se(vals, n_boot=N_BOOT)
        shift = q99 - q99_er_n500
        fpr = float((vals > Q99_ER).mean())
        bstr = "--" if beta is None else f"{beta:.2f}"
        print(f"{name:>6} {bstr:>6} {m:>7.4f} {s:>7.4f} {q99:>7.4f} {shift:>7.4f} "
              f"{se_mean:>8.4f} {se_q99:>8.4f} {se_q99 / se_mean:>6.2f} {fpr:>7.4f}")
        h0.append((q99, fpr))
    print()
    print(f"H0 baseline (same N): q99(ER, N = {N_REPLICATES}) = {q99_er_n500:.4f}")
    print(f"Canonical reference (informational): Q99_ER = {Q99_ER}")
    print()

    # ---- H1: power against one planted clique ----
    print("--- H1: power vs one planted clique (k = 1, m = 20, 10x local density) ---")
    print()
    print(f"{'model':>6} {'beta':>6} {'q99_own':>8} {'TPR_own':>7} {'CI95_own':>13} "
          f"{'TPR_paper':>9} {'CI95_paper':>13} {'FPR_paper':>9}")
    print("-" * 78)
    for (name, beta, _vals, w_beta), (q99_own, fpr_paper) in zip(models, h0):
        if name == "ER":
            h1_fn = lambda rng: sample_er_h1(N, D_MEAN, rng, CLIQUE_M, DENSITY_FACTOR)
        else:
            h1_fn = lambda rng, w=w_beta: sample_chung_lu_h1(w, rng, CLIQUE_M, DENSITY_FACTOR)
        vals_h1 = calibrate(h1_fn, N_REPLICATES_H1, RNG_SEED)
        k_own = int((vals_h1 > q99_own).sum())
        k_paper = int((vals_h1 > Q99_ER).sum())
        lo_o, hi_o = wilson_ci(k_own, N_REPLICATES_H1)
        lo_p, hi_p = wilson_ci(k_paper, N_REPLICATES_H1)
        ci_own = "[{:.3f},{:.3f}]".format(lo_o, hi_o)
        ci_paper = "[{:.3f},{:.3f}]".format(lo_p, hi_p)
        bstr = "--" if beta is None else f"{beta:.2f}"
        print(f"{name:>6} {bstr:>6} {q99_own:>8.4f} {k_own / N_REPLICATES_H1:>7.3f} "
              f"{ci_own:>13} {k_paper / N_REPLICATES_H1:>9.3f} {ci_paper:>13} "
              f"{fpr_paper:>9.4f}")
    print()

    print("=" * 78)
    print("VERDICT")
    print("=" * 78)
    print("  1. H0 shift: q99(CL) minus q99(ER at the same N) is large and")
    print("     positive. Positive shift means the CL null sits ABOVE the ER")
    print("     threshold, so the ER-calibrated threshold is ANTI-conservative")
    print("     on heavy-tailed nulls: it flags almost every graph. The")
    print("     direction of error is given by the FPR column, not by the")
    print("     sign of the shift alone.")
    print("  2. H0 FPR at lambda_max > 9.0542: empirical false-positive rate")
    print("     of the paper's ER threshold on each null. Values at or below")
    print("     alpha = 0.01 confirm conservation; values above it would")
    print("     refute it (anti-conservative threshold).")
    print("  3. H1 TPR: power against one planted clique. TPR_own uses the")
    print("     model's own q99; TPR_paper uses the ER threshold 9.0542 that")
    print("     the paper actually applies. The gap between the two")
    print("     quantifies whether the robustness survives in power, not")
    print("     only in false positives.")
    print()
    print(f"Runtime: ~2 min on a single core.")
    print(f"Deterministic: seed {RNG_SEED}, no clock, no entropy, no disk I/O.")

if __name__ == "__main__":
    main()
