#!/usr/bin/env python3
# Run with: python3 -u bipartite_power.py (unbuffered output)
"""
bipartite_power.py — Power of the left-tail test against two-block SBM.

The right tail of the modularity spectrum (lambda_2(B)) detects cliques.
The left tail (-lambda_min(B)) is calibrated at q99 = 9.1371 (from
calibration_modularity.py) but its detection power has not been measured.
This script fills the gap.

Model: disassortative (bipartite) two-block stochastic block model with
block sizes (m1, m2) and p_between = rho_between * p_within, where
rho_between >= 1. Edges are denser BETWEEN the two blocks than within
them; this is the structure the left tail is calibrated to detect.
Average degree d_bar = 20, matching the null calibration.

The statistic is -lambda_min(B), where B = W - dd^T/(2m). Reject H0
if -lambda_min(B) > Q99_LEFT = 9.1371.

Configurations:
  - Balanced m=250/250, rho_between in {2, 5, 10}
  - Unbalanced m=100/400, rho_between in {5, 10}
  - Unbalanced m=50/450, rho_between = 10

Reference null distribution (from calibration_modularity.py, seed 42,
N_H0 = 2000):
  -lambda_min(B): mean = 8.8601, std = 0.1101, q99 = 9.1371

This script does not recalibrate the null; it uses the threshold from
the previous calibration to keep runtime bounded.
"""

import numpy as np

RNG_SEED = 42
N = 500
D_BAR = 20
N_H1 = 500
Q99_LEFT = 9.1371       # from calibration_modularity.py
Q95_LEFT = 9.0428       # from calibration_modularity.py

CONFIGS = [
    ("bipartite 250/250, rb=2",  250, 250, 2),
    ("bipartite 250/250, rb=5",  250, 250, 5),
    ("bipartite 250/250, rb=10", 250, 250, 10),
    ("bipartite 100/400, rb=5",  100, 400, 5),
    ("bipartite 100/400, rb=10", 100, 400, 10),
    ("bipartite 50/450, rb=10",   50, 450, 10),
]


def compute_probabilities(n, m1, m2, d_bar, rho_between):
    """Two-block SBM: p_between = rho_between * p_within, mean degree d_bar."""
    intra = m1 * (m1 - 1) / 2 + m2 * (m2 - 1) / 2
    inter = m1 * m2
    target_edges = n * d_bar / 2
    p_within = target_edges / (intra + inter * rho_between)
    p_between = rho_between * p_within
    if p_between > 1.0:
        p_between = 1.0
        p_within = max(0.0, (target_edges - inter * p_between) / intra)
    return p_within, p_between


def generate_bipartite(n, m1, m2, rho_between, d_bar, rng):
    """Two-block SBM with p_between = rho_between * p_within."""
    # average degree d_bar = (n/2) * p_within + (n/2) * p_between
    # for balanced: d_bar = (n/2) * (p_within + p_between)
    # = (n/2) * (1 + rho_between) * p_within
    # p_within = d_bar / ((n/2) * (1 + rho_between))
    # But for unbalanced it's more complex.
    # Simplification for now: assume balanced case (m1 = m2 = n/2)
    # General: for two blocks of size m1, m2, expected degree:
    #   d = m1 * p_bb' / n + ...
    # Use: p_within chosen such that average degree equals d_bar.
    assert m1 + m2 == n
    # For disassortative: p_between = rho * p_within, rho >= 1
    # Average edges = intra_within * p_within + intra_between * p_between
    # = (m1*(m1-1)/2 + m2*(m2-1)/2) * p_within + m1*m2 * rho * p_within
    intra = m1*(m1-1)/2 + m2*(m2-1)/2
    inter = m1 * m2
    target_edges = n * d_bar / 2
    p_within = target_edges / (intra + inter * rho_between)
    p_between = rho_between * p_within
    if p_between > 1.0:
        p_between = 1.0
        p_within = max(0.0, (target_edges - inter * p_between) / intra)
    P = np.full((n, n), p_between)
    P[:m1, :m1] = p_within
    P[m1:, m1:] = p_within
    np.fill_diagonal(P, 0.0)
    A = (rng.random((n, n)) < P).astype(np.float64)
    A = np.triu(A, 1)
    return A + A.T


def left_statistic(A):
    """Return -lambda_min(B) where B = A - dd^T/(2m)."""
    d = A.sum(axis=1)
    m = A.sum() / 2.0
    if m == 0:
        return 0.0
    B = A - np.outer(d, d) / (2.0 * m)
    eigs = np.linalg.eigvalsh(B)
    return -eigs[0]


def wilson_ci(k, n, z=1.96):
    p = k / n
    denom = 1 + z * z / n
    center = (p + z * z / (2 * n)) / denom
    half = z / denom * np.sqrt(p * (1 - p) / n + z * z / (4 * n * n))
    return max(0.0, center - half), min(1.0, center + half)


def main():
    print("=" * 80)
    print("BIPARTITE POLARIZATION — POWER OF THE LEFT TAIL")
    print("=" * 80)
    print()
    print(f"N = {N}, d_bar = {D_BAR}, N_H1 = {N_H1}")
    print(f"Threshold alpha=0.01: -lambda_min(B) > {Q99_LEFT}")
    print(f"Threshold alpha=0.05: -lambda_min(B) > {Q95_LEFT}")
    print()

    rng = np.random.default_rng(RNG_SEED)

    print(f"{'Config':<24} {'p_within':>8} {'p_between':>9} "
          f"{'-l_min mean':>12} {'TPR@0.01':>10} {'CI 95%':>18}")
    print("-" * 86)

    results = []
    for name, m1, m2, rho_between in CONFIGS:
        p_within, p_between = compute_probabilities(N, m1, m2, D_BAR, rho_between)
        stats = np.empty(N_H1)
        for i in range(N_H1):
            A = generate_bipartite(N, m1, m2, rho_between, D_BAR, rng)
            stats[i] = left_statistic(A)
        tpr_01 = (stats > Q99_LEFT).mean()
        k = int((stats > Q99_LEFT).sum())
        lo, hi = wilson_ci(k, N_H1)
        print(f"{name:<24} {p_within:>8.4f} {p_between:>9.4f} "
              f"{stats.mean():>12.4f} {tpr_01:>10.3f} "
              f"  [{lo:.3f}, {hi:.3f}]")
        results.append({
            "name": name, "p_within": p_within, "p_between": p_between,
            "mean_stat": stats.mean(),
            "tpr_01": tpr_01, "ci": (lo, hi),
        })

    print()
    print("=" * 80)
    print("INTERPRETATION")
    print("=" * 80)
    print()
    for r in results:
        verdict = (
            "strong" if r["tpr_01"] > 0.9 else
            "moderate" if r["tpr_01"] > 0.5 else
            "weak" if r["tpr_01"] > 0.1 else
            "indistinguishable from noise"
        )
        print(f"  {r['name']:<24} TPR = {r['tpr_01']:.3f}  → {verdict}")
    print()
    print("The detection threshold for -lambda_min(B) is "
          f"{Q99_LEFT:.4f}.")
    print("Compare against the null mean of 8.8601 (std 0.1101).")
    print()
    print("=" * 80)


if __name__ == "__main__":
    main()
