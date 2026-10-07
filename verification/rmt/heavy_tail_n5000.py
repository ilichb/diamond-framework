#!/usr/bin/env python3
"""
heavy_tail_n5000.py - Finding C-22: the n >= 5000 heavy-tail experiment.

Finding F-019 (calibration_heavy_tail.py) showed that the ER-calibrated
threshold q99 = 9.0542 does not transfer to Chung-Lu power-law nulls at
n = 500, but that run carried a caveat: at beta = 2.1 and 2.3 the requested
degree sequence exceeds what a simple graph admits at n = 500, so those two
nulls are degree-capped rather than pure-tail. F-019 registered the
separation of a genuine tail from a saturated hub core as a postponed
experiment requiring n >= 5000.

This script runs that experiment. At n = 5000, d_bar = 20, the maximum
expected degree is below n - 1 for every beta in {2.1, 2.3, 2.5, 3.0}, so
the null is realised without degree-capping. It recalibrates the ER baseline
at n = 5000 and, per null, measures the empirical false-positive rate of
that ER threshold and the true-positive rate against one planted clique
(m = 20, 10x local density) at the null's own q99.

Gate (C-22): if the per-null true-positive rate is below 0.5 for every beta,
stop and report; do not edit Section 5.4.

Uses scipy.sparse Lanczos (ARPACK) for lambda_max(B): the dense eigvalsh of
the n = 500 script is O(n^3) and does not scale to n = 5000.

Deterministic: seed declared, no clock, no disk I/O.
"""
import numpy as np
import scipy.sparse as sp
from scipy.sparse.linalg import eigsh, LinearOperator

N = 5000
D_MEAN = 20.0
N_H0 = 500
N_H1 = 200
N_BOOT = 1000
RNG_SEED = 42
ALPHA = 0.01
BETAS = [2.1, 2.3, 2.5, 3.0]
CLIQUE_M = 20
DENSITY_FACTOR = 10.0
Q99_ER_N500 = 9.0542   # canonical reference at n = 500 (informational)
CHUNK = 1000


def chung_lu_expected_degrees(n, d_mean, beta):
    """Power-law expected degree sequence w_i proportional to
    i^(-1/(beta-1)), normalized to mean d_mean. beta > 2."""
    idx = np.arange(1, n + 1)
    w = idx ** (-1.0 / (beta - 1.0))
    return w / w.mean() * d_mean


def make_block_fn(w, n, er_p, clique, df):
    """Return a row-block callback P(i0, i1) -> (i1-i0, n) probabilities.

    w is None for Erdos-Renyi (constant er_p); otherwise Chung-Lu
    p_ij = w_i w_j / sum(w). When clique is given, intra-clique entries
    are multiplied by df (the '10x local density' rule)."""
    def fn(i0, i1):
        if w is None:
            P = np.full((i1 - i0, n), er_p)
        else:
            P = np.outer(w[i0:i1], w) / w.sum()
        if clique is not None:
            rows = clique[(clique >= i0) & (clique < i1)]
            if rows.size:
                P[np.ix_(rows - i0, clique)] *= df
        return P
    return fn


def sample_sparse(n, block_fn, rng):
    """Sample the upper triangle Bernoulli(block_fn) into a symmetric
    sparse adjacency matrix."""
    j = np.arange(n)
    rows, cols = [], []
    for i0 in range(0, n, CHUNK):
        i1 = min(i0 + CHUNK, n)
        P = block_fn(i0, i1)
        np.clip(P, 0.0, 1.0, out=P)
        U = rng.random(P.shape)
        M = U < P
        M &= j[None, :] > np.arange(i0, i1)[:, None]
        r, c = np.nonzero(M)
        rows.append(r + i0)
        cols.append(c)
    rows = np.concatenate(rows)
    cols = np.concatenate(cols)
    A = sp.csr_matrix((np.ones(rows.size), (rows, cols)), shape=(n, n))
    return A + A.T


def lambda_max_B(A):
    """Largest eigenvalue of B = A - d d^T / (2m) via Lanczos on a
    rank-1-corrected sparse operator."""
    n = A.shape[0]
    d = np.asarray(A.sum(axis=1)).ravel()
    two_m = d.sum()
    mv = lambda v: A @ v - d * (d @ v) / two_m
    op = LinearOperator((n, n), matvec=mv, dtype=float)
    try:
        val = eigsh(op, k=1, which='LA', return_eigenvectors=False,
                    tol=1e-3, maxiter=100000)
    except sp.linalg.ArpackNoConvergence as e:
        val = e.eigenvalues
    return float(np.max(val))


def calibrate(draw_fn, n_rep, seed):
    rng = np.random.default_rng(seed)
    vals = np.empty(n_rep)
    for i in range(n_rep):
        vals[i] = lambda_max_B(draw_fn(rng))
    return vals


def summarize(vals):
    return (float(vals.mean()), float(vals.std(ddof=1)),
            float(np.quantile(vals, 1 - ALPHA)))


def bootstrap_q99_se(vals, n_boot, rng_seed=RNG_SEED):
    rng = np.random.default_rng(rng_seed)
    n = len(vals)
    q = np.empty(n_boot)
    for b in range(n_boot):
        q[b] = np.quantile(vals[rng.integers(0, n, n)], 1 - ALPHA)
    return float(q.std(ddof=1))


def wilson_ci(k, n, z=1.96):
    p_hat = k / n
    denom = 1 + z ** 2 / n
    center = (p_hat + z ** 2 / (2 * n)) / denom
    half = z / denom * np.sqrt(p_hat * (1 - p_hat) / n + z ** 2 / (4 * n ** 2))
    return center - half, center + half


def draw_h1_er(rng):
    p = D_MEAN / (N - 1)
    clique = np.sort(rng.choice(N, size=CLIQUE_M, replace=False))
    return sample_sparse(N, make_block_fn(None, N, p, clique, DENSITY_FACTOR), rng)


def draw_h1_cl(w, rng):
    clique = np.sort(rng.choice(N, size=CLIQUE_M, replace=False))
    return sample_sparse(N, make_block_fn(w, N, None, clique, DENSITY_FACTOR), rng)


def main():
    print("=" * 78)
    print("HEAVY-TAIL COLLUSION TEST AT n = 5000 (C-22)")
    print("=" * 78)
    print()
    print(f"n = {N}, d_mean = {D_MEAN}, seed = {RNG_SEED}, alpha = {ALPHA}")
    print(f"N_H0 = {N_H0}, N_H1 = {N_H1}, clique: m = {CLIQUE_M}, "
          f"density = {DENSITY_FACTOR}x local p_bg")
    print()

    print("0. DEGREE-SEQUENCE FEASIBILITY (no degree-capping)")
    print("-" * 78)
    print(f"   {'beta':>6}   {'d_max (expected)':>18}   {'n-1':>6}   {'capped?':>8}")
    for beta in BETAS:
        w = chung_lu_expected_degrees(N, D_MEAN, beta)
        dmax = float(w.max())
        capped = dmax > (N - 1)
        print(f"   {beta:>6.2f}   {dmax:>18.1f}   {N - 1:>6}   "
              f"{'sí' if capped else 'no':>8}")
    print()

    p_er = D_MEAN / (N - 1)
    vals_er = calibrate(
        lambda rng: sample_sparse(N, make_block_fn(None, N, p_er, None, 1.0), rng),
        N_H0, RNG_SEED)
    models = [("ER", None, vals_er, None)]
    for beta in BETAS:
        w = chung_lu_expected_degrees(N, D_MEAN, beta)
        vals = calibrate(
            lambda rng, w=w: sample_sparse(N, make_block_fn(w, N, None, None, 1.0), rng),
            N_H0, RNG_SEED)
        models.append(("CL", beta, vals, w))

    q99_er = float(np.quantile(vals_er, 1 - ALPHA))
    print("1. H0 NULL CALIBRATION AT n = 5000 (ER baseline recalibrated)")
    print("-" * 78)
    print(f"   {'model':>6} {'beta':>6} {'mean':>8} {'std':>8} {'q99':>8} "
          f"{'SE_q99':>8} {'shift':>8} {'FPR':>7}")
    h0 = []
    for name, beta, vals, _w in models:
        m, s, q99 = summarize(vals)
        se_q99 = bootstrap_q99_se(vals, N_BOOT)
        shift = q99 - q99_er
        fpr = float((vals > q99_er).mean())
        bstr = "--" if beta is None else f"{beta:.2f}"
        print(f"   {name:>6} {bstr:>6} {m:>8.4f} {s:>8.4f} {q99:>8.4f} "
              f"{se_q99:>8.4f} {shift:>8.4f} {fpr:>7.4f}")
        h0.append((q99, fpr))
    print()
    print(f"   ER baseline q99 at n = 5000 = {q99_er:.4f}")
    print(f"   Canonical reference at n = 500 (informational) = {Q99_ER_N500}")
    print()

    print("2. H1 POWER VS ONE PLANTED CLIQUE (m = 20, 10x local density)")
    print("-" * 78)
    print(f"   {'model':>6} {'beta':>6} {'q99_own':>8} {'TPR_own':>8} "
          f"{'CI95_own':>14} {'TPR_ER':>8} {'FPR_ER':>7}")
    tpr_own_list = []
    for (name, beta, _vals, w), (q99_own, fpr_er) in zip(models, h0):
        if name == "ER":
            draw = draw_h1_er
        else:
            draw = (lambda ww: (lambda rng: draw_h1_cl(ww, rng)))(w)
        vals_h1 = calibrate(draw, N_H1, RNG_SEED)
        k_own = int((vals_h1 > q99_own).sum())
        k_er = int((vals_h1 > q99_er).sum())
        lo, hi = wilson_ci(k_own, N_H1)
        tpr_own = k_own / N_H1
        tpr_own_list.append(tpr_own)
        bstr = "--" if beta is None else f"{beta:.2f}"
        print(f"   {name:>6} {bstr:>6} {q99_own:>8.4f} {tpr_own:>8.3f} "
              f"[{lo:.3f},{hi:.3f}] {k_er / N_H1:>8.3f} {fpr_er:>7.4f}")
    print()

    print("3. GATE (C-22)")
    print("-" * 78)
    cl_own = tpr_own_list[1:]
    gate = all(t < 0.5 for t in cl_own)
    print("   TPR_pernull by beta: " + ", ".join("%.3f" % t for t in cl_own))
    if gate:
        print("   ALL Chung-Lu per-null TPRs < 0.5: the heavy-tail failure")
        print("   survives at n = 5000 without degree-capping. Stop and")
        print("   report; do not edit Section 5.4.")
    else:
        print("   At least one Chung-Lu per-null TPR >= 0.5: power recovers")
        print("   at n = 5000. Section 5.4 may be updated.")
    print()
    print("=" * 78)


if __name__ == "__main__":
    main()
