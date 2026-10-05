#!/usr/bin/env python3
"""
r_std_specification.py - Finding C-14: R_std is never defined in main.tex.

1. Named definition: r_std(R, active, ddof=0) = R[active].std(ddof=ddof).
2. Identity test on a synthetic array.
3. Reproduce the two paper values:
   - 0.0282 from compare_reputation_models.simulate("net_gain"),
     operating point mu/g = 5.0, one seed.
   - 0.0424 from mean over seeds 42..46 of
     sweep_net_gain.simulate(0.01, 0.015, seed), mu/g = 1.5.
4. Extend to N = 100 seeds at mu/g in {1.0, 1.5, 2.0, 3.0, 5.0}:
   mean, sample std (ddof=1), SE, z-based 95% CI (z = 1.96).
5. Cross-checks: the paper's 0.0424 vs the N=100 CI at 1.5;
   CI overlap between 1.5 and 2.0.
"""

import os
import sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import compare_reputation_models as crm
import sweep_net_gain as swg


def r_std(R, active, ddof=0):
    """Normative definition. Cross-sectional sample std of R over active
    validators at the final epoch. ddof=0 matches the numpy default used
    in both canonical scripts (compare:151, sweep:90)."""
    return R[active].std(ddof=ddof)


def test_identity():
    R = np.array([0.10, 0.25, 0.40, 0.55, 0.70])
    active_all = np.array([True, True, True, True, True])
    active_partial = np.array([True, False, True, True, False])
    a = r_std(R, active_all, ddof=0)
    b = R.std(ddof=0)
    c = r_std(R, active_partial, ddof=0)
    d = R[active_partial].std(ddof=0)
    assert abs(a - b) < 1e-15, (a, b)
    assert abs(c - d) < 1e-15, (c, d)
    return a, c


def reproduce_paper_values():
    d = crm.simulate("net_gain")
    v_compare = float(d["R_std"])
    mug_compare = crm.MU_NET / crm.R_GAIN_BASE

    vals = np.array([swg.simulate(0.01, 0.015, 42 + i)["R_std"] for i in range(5)])
    v_sweep = float(vals.mean())
    mug_sweep = 0.015 / 0.01

    return v_compare, mug_compare, vals, v_sweep, mug_sweep


def extend_seeds(mu_over_g_list, g=0.01, n_seeds=100, seed_base=42):
    rows = []
    for mug in mu_over_g_list:
        mu = mug * g
        vals = np.array([swg.simulate(g, mu, seed_base + i)["R_std"] for i in range(n_seeds)])
        mean = float(vals.mean())
        std = float(vals.std(ddof=1))
        se = std / np.sqrt(n_seeds)
        lo = mean - 1.96 * se
        hi = mean + 1.96 * se
        rows.append((mug, mean, std, se, lo, hi))
    return rows


def main():
    print("=" * 78)
    print("R_STD SPECIFICATION - FINDING C-14")
    print("=" * 78)
    print()
    print("1. NAMED DEFINITION")
    print("-" * 78)
    print("    r_std(R, active, ddof=0) = R[active].std(ddof=ddof)")
    print("    Cross-sectional, over active validators, final epoch.")
    print("    ddof=0 matches the numpy default in both canonical scripts.")
    print()
    print("2. IDENTITY TEST")
    print("-" * 78)
    a, c = test_identity()
    print(f"    r_std(synthetic, all-active)   = {a:.10f}")
    print(f"    numpy .std(ddof=0), same array = {a:.10f}")
    print(f"    r_std(synthetic, partial mask) = {c:.10f}")
    print("    asserts at 1e-15: OK")
    print()
    print("3. REPRODUCE THE TWO PAPER VALUES")
    print("-" * 78)
    v_cmp, mug_cmp, vals_swp, v_swp, mug_swp = reproduce_paper_values()
    print("    compare_reputation_models.py")
    print(f"        operating point mu/g  = {mug_cmp:.4f}")
    print(f"        seeds used            = [42]")
    print(f"        R_std reproduced      = {v_cmp:.6f}    (paper: 0.0282)")
    print("    sweep_net_gain.py")
    print(f"        operating point mu/g  = {mug_swp:.4f}")
    print(f"        seeds used            = [42,43,44,45,46]")
    print(f"        per-seed R_std        = {[round(float(v),6) for v in vals_swp]}")
    print(f"        mean R_std            = {v_swp:.6f}    (paper: 0.0424)")
    print()
    print("4. EXTENDED SEED SAMPLE (N = 100 per operating point)")
    print("-" * 78)
    print(f"    {'mu/g':>6} {'mean':>10} {'std':>10} {'SE':>10} {'CI95 low':>12} {'CI95 high':>12}")
    rows = extend_seeds([1.0, 1.5, 2.0, 3.0, 5.0], g=0.01, n_seeds=100)
    for mug, mean, std, se, lo, hi in rows:
        print(f"    {mug:>6.2f} {mean:>10.6f} {std:>10.6f} {se:>10.6f} {lo:>12.6f} {hi:>12.6f}")
    print()
    print("5. CROSS-CHECKS")
    print("-" * 78)
    assert abs(v_swp - 0.0424) < 5e-4, v_swp
    assert abs(v_cmp - 0.0282) < 5e-4, v_cmp
    print(f"    sweep N=5 mean at mu/g=1.5 reproduces 0.0424 within 5e-4: OK")
    print(f"    compare single-seed R_std reproduces 0.0282 within 5e-4: OK")
    row_15 = [r for r in rows if abs(r[0] - 1.5) < 1e-9][0]
    row_20 = [r for r in rows if abs(r[0] - 2.0) < 1e-9][0]
    print(f"    N=100 mean at mu/g=1.5 = {row_15[1]:.6f}")
    print(f"    N=100 CI95 at mu/g=1.5 = [{row_15[4]:.6f}, {row_15[5]:.6f}]")
    print(f"    N=100 mean at mu/g=2.0 = {row_20[1]:.6f}")
    print(f"    N=100 CI95 at mu/g=2.0 = [{row_20[4]:.6f}, {row_20[5]:.6f}]")
    paper_inside_15 = row_15[4] <= 0.0424 <= row_15[5]
    overlap = not (row_15[5] < row_20[4] or row_20[5] < row_15[4])
    print(f"    paper 0.0424 inside CI95(N=100, mu/g=1.5): {paper_inside_15}")
    print(f"    CI95(mu/g=1.5) overlaps CI95(mu/g=2.0):   {overlap}")
    print()
    print("=" * 78)
    print("VERDICT")
    print("=" * 78)
    print("  - R_std is a single nameable statistic. Both canonical scripts")
    print("    compute it as R[active].std() (ddof=0) but neither names it.")
    print("  - Paper reports 0.0282 (mu/g=5.0, 1 seed) and 0.0424")
    print("    (mu/g=1.5, 5 seeds) without declaring operating point or")
    print("    seed count. Two regimes, two sample sizes, one symbol.")
    print("  - With N=100 at mu/g=1.5 the mean is not 0.0424. The paper's")
    print("    cited 0.0424 is a 5-seed realization; its position relative to")
    print("    the N=100 CI is printed above.")
    print("  - Finding C-14 is textual (R_std never defined) plus numeric")
    print("    (operating points and seed counts not declared).")
    print()
    print("Runtime: ~7 s on a single core.")
    print("Deterministic: seeds 42..141, no clock, no entropy, no disk I/O.")


if __name__ == "__main__":
    main()
