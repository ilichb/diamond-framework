#!/usr/bin/env python3
"""
recalibrate_top.py — Calibration and power for s[-1] vs s[-2] on B.

Run with: python3 -u recalibrate_top.py

Motivation: the paper uses s[-2] (second-largest eigenvalue) as the
right-tail statistic. This skips s[-1], which for the modularity
matrix B is the actual signal (the trivial eigenvalue 0 is in the
middle of the spectrum, not at the top).

This script measures:
  1. The null distribution of s[-1], s[-2] on ER graphs (N_H0 = 2000)
  2. The power of s[-1] and s[-2] against:
     - Cliques (k=1,3,5, m=20; k=1,3, m=40)
     - Balanced assortative communities (250/250, rho=5, 10)
     - Unbalanced assortative communities (100/400, rho=10)

The output is the comparison needed to decide whether to switch the
paper's statistic from s[-2] to s[-1].
"""

import numpy as np

RNG_SEED = 42
N = 500
D_BAR = 20
N_H0 = 2000
N_H1 = 200


def generate_h0(n, d_bar, rng):
    p = d_bar / (n - 1)
    A = (rng.random((n, n)) < p).astype(np.float64)
    A = np.triu(A, 1)
    return A + A.T


def generate_clique(n, d_bar, k, m, rng):
    p_out = d_bar / (n - 1)
    p_in = min(1.0, 10 * p_out)
    P = np.full((n, n), p_out)
    start = 0
    for _ in range(k):
        end = start + m
        P[start:end, start:end] = p_in
        start = end
    A = (rng.random((n, n)) < P).astype(np.float64)
    A = np.triu(A, 1)
    return A + A.T


def generate_assortative(n, m1, m2, rho, d_bar, rng):
    """Two blocks, p_within = rho * p_between. Assortative structure."""
    assert m1 + m2 == n
    intra = m1 * (m1 - 1) / 2 + m2 * (m2 - 1) / 2
    inter = m1 * m2
    target_edges = n * d_bar / 2
    p_between = target_edges / (intra * rho + inter)
    p_within = rho * p_between
    if p_within > 1.0:
        p_within = 1.0
        p_between = max(0.0, (target_edges - p_within * intra) / inter)
    P = np.full((n, n), p_between)
    P[:m1, :m1] = p_within
    P[m1:, m1:] = p_within
    np.fill_diagonal(P, 0.0)
    A = (rng.random((n, n)) < P).astype(np.float64)
    A = np.triu(A, 1)
    return A + A.T


def spectrum_stats(A):
    """Return (s[-1], s[-2]) of B = A - dd^T/(2m)."""
    d = A.sum(axis=1)
    m = A.sum() / 2.0
    if m == 0:
        return 0.0, 0.0
    B = A - np.outer(d, d) / (2.0 * m)
    eigs = np.linalg.eigvalsh(B)
    return eigs[-1], eigs[-2]


def summarize(stats):
    return {
        "mean_s1": stats[:, 0].mean(),
        "std_s1": stats[:, 0].std(),
        "q99_s1": np.quantile(stats[:, 0], 0.99),
        "mean_s2": stats[:, 1].mean(),
        "std_s2": stats[:, 1].std(),
        "q99_s2": np.quantile(stats[:, 1], 0.99),
    }


def main():
    print("=" * 90)
    print("RECALIBRATE TOP — s[-1] vs s[-2] on MODULARITY B")
    print("=" * 90)
    print()
    print(f"N = {N}, d_bar = {D_BAR}, N_H0 = {N_H0}, N_H1 = {N_H1}")
    print()

    rng = np.random.default_rng(RNG_SEED)

    # Null
    print("Calibrating null distribution (N_H0 = %d)..." % N_H0)
    null = np.empty((N_H0, 2))
    for i in range(N_H0):
        A = generate_h0(N, D_BAR, rng)
        null[i, 0], null[i, 1] = spectrum_stats(A)
        if (i + 1) % 500 == 0:
            print(f"  null: {i+1}/{N_H0}")
    null_stats = summarize(null)
    print()
    print("NULL DISTRIBUTION")
    print(f"  s[-1]: mean = {null_stats['mean_s1']:.4f}, "
          f"std = {null_stats['std_s1']:.4f}, "
          f"q99 = {null_stats['q99_s1']:.4f}")
    print(f"  s[-2]: mean = {null_stats['mean_s2']:.4f}, "
          f"std = {null_stats['std_s2']:.4f}, "
          f"q99 = {null_stats['q99_s2']:.4f}")
    print()

    # Power configurations
    configs = [
        ("clique k=1 m=20",   lambda r: generate_clique(N, D_BAR, 1, 20, r)),
        ("clique k=3 m=20",   lambda r: generate_clique(N, D_BAR, 3, 20, r)),
        ("clique k=5 m=20",   lambda r: generate_clique(N, D_BAR, 5, 20, r)),
        ("clique k=1 m=40",   lambda r: generate_clique(N, D_BAR, 1, 40, r)),
        ("clique k=3 m=40",   lambda r: generate_clique(N, D_BAR, 3, 40, r)),
        ("assortative 250/250, rho=5",  lambda r: generate_assortative(N, 250, 250, 5, D_BAR, r)),
        ("assortative 250/250, rho=10", lambda r: generate_assortative(N, 250, 250, 10, D_BAR, r)),
        ("assortative 100/400, rho=10", lambda r: generate_assortative(N, 100, 400, 10, D_BAR, r)),
    ]

    print("POWER COMPARISON")
    print("-" * 90)
    print(f"{'Config':<30} {'TPR_s1@0.01':>12} {'TPR_s2@0.01':>12} "
          f"{'mean_s1':>10} {'mean_s2':>10}")
    print("-" * 90)

    results = []
    for name, gen in configs:
        stats = np.empty((N_H1, 2))
        for i in range(N_H1):
            A = gen(rng)
            stats[i, 0], stats[i, 1] = spectrum_stats(A)
        tpr_s1 = (stats[:, 0] > null_stats["q99_s1"]).mean()
        tpr_s2 = (stats[:, 1] > null_stats["q99_s2"]).mean()
        print(f"{name:<30} {tpr_s1:>12.3f} {tpr_s2:>12.3f} "
              f"{stats[:, 0].mean():>10.4f} {stats[:, 1].mean():>10.4f}")
        results.append({
            "name": name,
            "tpr_s1": tpr_s1,
            "tpr_s2": tpr_s2,
            "mean_s1": stats[:, 0].mean(),
            "mean_s2": stats[:, 1].mean(),
        })

    print()
    print("=" * 90)
    print("VERDICT")
    print("=" * 90)
    print()
    better_s1 = sum(1 for r in results if r["tpr_s1"] > r["tpr_s2"] + 0.1)
    better_s2 = sum(1 for r in results if r["tpr_s2"] > r["tpr_s1"] + 0.1)
    tie = len(results) - better_s1 - better_s2
    print(f"  Configs where s[-1] is clearly better:  {better_s1}")
    print(f"  Configs where s[-2] is clearly better:  {better_s2}")
    print(f"  Ties (within 0.1):                      {tie}")
    print()
    if better_s1 > better_s2:
        print("  RECOMMENDATION: switch right-tail statistic to s[-1].")
    elif better_s2 > better_s1:
        print("  RECOMMENDATION: keep s[-2].")
    else:
        print("  RECOMMENDATION: use max(s[-1], s[-2]) as the statistic.")
    print()
    print("=" * 90)


if __name__ == "__main__":
    main()
