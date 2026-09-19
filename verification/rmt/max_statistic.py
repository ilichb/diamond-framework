#!/usr/bin/env python3
"""
max_statistic.py — Calibration and power for max(s[-1], s[-2]) on B.

Run with: python3 -u max_statistic.py

Motivation: s[-1] dominates s[-2] in most configurations, but s[-2]
marginally wins on unbalanced assortative structure (100/400 rho=10:
0.995 vs 0.945). This script tests whether max(s[-1], s[-2]) captures
the best of both, and whether it loses power anywhere.

The null of max(s[-1], s[-2]) is calibrated by Monte Carlo.
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


def main():
    print("=" * 90)
    print("MAX STATISTIC — max(s[-1], s[-2]) on MODULARITY B")
    print("=" * 90)
    print()
    print(f"N = {N}, d_bar = {D_BAR}, N_H0 = {N_H0}, N_H1 = {N_H1}")
    print()

    rng = np.random.default_rng(RNG_SEED)

    # Null
    print("Calibrating null of max(s[-1], s[-2])...")
    null_max = np.empty(N_H0)
    null_s1 = np.empty(N_H0)
    null_s2 = np.empty(N_H0)
    for i in range(N_H0):
        A = generate_h0(N, D_BAR, rng)
        s1, s2 = spectrum_stats(A)
        null_s1[i] = s1
        null_s2[i] = s2
        null_max[i] = max(s1, s2)
        if (i + 1) % 500 == 0:
            print(f"  null: {i+1}/{N_H0}")

    q99_s1 = np.quantile(null_s1, 0.99)
    q99_s2 = np.quantile(null_s2, 0.99)
    q99_max = np.quantile(null_max, 0.99)
    print()
    print("NULL DISTRIBUTION (N_H0 = 2000)")
    print(f"  s[-1]: mean = {null_s1.mean():.4f}, "
          f"std = {null_s1.std():.4f}, q99 = {q99_s1:.4f}")
    print(f"  s[-2]: mean = {null_s2.mean():.4f}, "
          f"std = {null_s2.std():.4f}, q99 = {q99_s2:.4f}")
    print(f"  max:   mean = {null_max.mean():.4f}, "
          f"std = {null_max.std():.4f}, q99 = {q99_max:.4f}")
    print()

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

    print("POWER COMPARISON (alpha = 0.01)")
    print("-" * 90)
    print(f"{'Config':<30} {'TPR_s1':>8} {'TPR_s2':>8} {'TPR_max':>8}")
    print("-" * 90)

    results = []
    for name, gen in configs:
        tpr_s1 = tpr_s2 = tpr_max = 0
        for i in range(N_H1):
            A = gen(rng)
            s1, s2 = spectrum_stats(A)
            sm = max(s1, s2)
            if s1 > q99_s1:
                tpr_s1 += 1
            if s2 > q99_s2:
                tpr_s2 += 1
            if sm > q99_max:
                tpr_max += 1
        tpr_s1 /= N_H1
        tpr_s2 /= N_H1
        tpr_max /= N_H1
        print(f"{name:<30} {tpr_s1:>8.3f} {tpr_s2:>8.3f} {tpr_max:>8.3f}")
        results.append({
            "name": name,
            "tpr_s1": tpr_s1,
            "tpr_s2": tpr_s2,
            "tpr_max": tpr_max,
        })

    print()
    print("=" * 90)
    print("VERDICT")
    print("=" * 90)
    print()
    better_max = sum(1 for r in results
                     if r["tpr_max"] > max(r["tpr_s1"], r["tpr_s2"]) + 0.05)
    same_max = sum(1 for r in results
                   if abs(r["tpr_max"] - max(r["tpr_s1"], r["tpr_s2"])) < 0.05)
    worse_max = sum(1 for r in results
                    if r["tpr_max"] < max(r["tpr_s1"], r["tpr_s2"]) - 0.05)

    print(f"  Configs where max > best(s1,s2) by > 0.05: {better_max}")
    print(f"  Configs where max == best(s1,s2) within 0.05: {same_max}")
    print(f"  Configs where max < best(s1,s2) by > 0.05: {worse_max}")
    print()
    print("  Note: max(s[-1], s[-2]) is identically equal to s[-1] because")
    print("  s[-1] >= s[-2] by construction. The max statistic adds no")
    print("  information and requires no separate calibration. The")
    print("  recommendation is s[-1] with q99 = 9.0542, as already")
    print("  documented in F-018.")
    print()
    print("=" * 90)


if __name__ == "__main__":
    main()
