#!/usr/bin/env python3
"""
wilson_intervals.py — Wilson 95% confidence intervals for the TPR
comparison between A_sym and B on the same clique configuration.

Data:
  A_sym: 1 detection / 30 replicates  -> TPR = 0.033
  B:     124 detections / 500 replicates -> TPR = 0.248

Verifies that the two intervals do not overlap, which is the
statistical basis for the design decision to use B instead of
A_sym (falsification log entry F-002).
"""

import numpy as np


def wilson_ci(k, n, z=1.96):
    """Wilson score interval for a binomial proportion."""
    p_hat = k / n
    denom = 1 + z**2 / n
    center = (p_hat + z**2 / (2*n)) / denom
    half = z / denom * np.sqrt(p_hat * (1 - p_hat) / n + z**2 / (4 * n**2))
    return center - half, center + half


def main():
    print("=" * 70)
    print("WILSON 95% CONFIDENCE INTERVALS FOR TPR COMPARISON")
    print("=" * 70)
    print()

    configs = [
        ("A_sym", 1, 30),
        ("B", 124, 500),
    ]

    for name, k, n in configs:
        p_hat = k / n
        lo, hi = wilson_ci(k, n)
        print(f"{name}:")
        print(f"  k = {k}, n = {n}")
        print(f"  TPR = {p_hat:.4f}")
        print(f"  Wilson 95% CI = [{lo:.4f}, {hi:.4f}]")
        print()

    lo_a, hi_a = wilson_ci(1, 30)
    lo_b, hi_b = wilson_ci(124, 500)

    print("Comparison:")
    print(f"  A_sym CI upper bound: {hi_a:.4f}")
    print(f"  B CI lower bound:     {lo_b:.4f}")
    print(f"  Overlap: {'yes' if hi_a > lo_b else 'no'}")
    print()
    print(f"  Point estimate ratio: {(124/500)/(1/30):.2f}x")
    print()
    print("=" * 70)
    print("CONCLUSION")
    print("=" * 70)
    print()
    if hi_a < lo_b:
        print("  The intervals do not overlap. The comparison is")
        print("  statistically significant at 95% despite the small")
        print("  sample size of the A_sym measurement (N = 30).")
    else:
        print("  The intervals overlap. The comparison is not")
        print("  statistically significant at 95%.")
    print()
    print("=" * 70)


if __name__ == "__main__":
    main()
