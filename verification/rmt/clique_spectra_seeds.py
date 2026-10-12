#!/usr/bin/env python3
"""
clique_spectra_seeds.py - Distribution of the spectral gap over 200 seeds.

Refines finding C-05. Section 5.2 of the paper (main.tex:628-630) reports the
leading non-trivial eigenvalue of W, A_sym and B for a single seed (seed 42).
This script measures the distribution of the same gaps over N_SEEDS = 200
independent seeds and reports the percentile at which the cited value falls.

Parameters (identical to the canonical script):
  N = 500, D_BAR = 20
  clique: CLIQUE_K = 1, CLIQUE_M = 20, intra density DENSITY_FACTOR = 10x
  N_SEEDS = 200, SEED_LIST_RNG = 42
  individual seeds = default_rng(SEED_LIST_RNG).integers(0, 2**31, size=N_SEEDS)
  Q99 = 9.0542: threshold cited at main.tex:637 (not L644; L643-644 is the
  section heading). Q99 is in units of lambda (calibrated bulk-edge
  threshold), not in units of gap. The reported statistic is P(lambda > Q99).

Provenance: generate_h0, generate_h1 and spectra are imported from the
canonical verification/rmt/clique_spectra.py. Nothing is duplicated here and
clique_spectra.py is not modified.

Gap definitions (same bulk edges as the canonical script):
  gap_W    = lambda_2(W)     - 2*sqrt(D_BAR)
  gap_Asym = lambda_2(A_sym) - 2/sqrt(D_BAR)
  gap_B    = lambda_max(B)   - 2*sqrt(D_BAR)

Percentile method: empirical ECDF without interpolation,
  percentile(x) = 100 * mean(gaps <= x).

Paired test: fraction of seeds with gap_B > gap_W (and =, <) plus the mean
  and std of gap_B - gap_W, for the paired claim of main.tex:637.

Output: verification/rmt/results/clique_spectra_seeds_output.txt
"""

import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))

from clique_spectra import generate_h0, generate_h1, spectra  # noqa: E402

N = 500
D_BAR = 20
CLIQUE_K = 1
CLIQUE_M = 20
DENSITY_FACTOR = 10
N_SEEDS = 200
SEED_LIST_RNG = 42
Q99 = 9.0542  # lambda units, cited at main.tex:637; P(lambda > Q99) is reported

CITED = {
    "W": 1.6996,
    "A_sym": -0.0156,
    "B": 1.7569,
}

OUT_PATH = Path(__file__).resolve().parent / "results" / "clique_spectra_seeds_output.txt"
SEP = "=" * 78


def draw_seeds():
    """Deterministic list of N_SEEDS individual seeds."""
    rng_seeds = np.random.default_rng(SEED_LIST_RNG)
    return rng_seeds.integers(0, 2 ** 31, size=N_SEEDS)


def gaps_for_seed(seed):
    """Gaps of W, A_sym and B for one seed.

    H0 is drawn first so that the H1 draw consumes the same rng stream as the
    canonical clique_spectra.py, which makes seed 42 reproduce the paper.
    """
    rng = np.random.default_rng(int(seed))
    generate_h0(N, D_BAR, rng)
    A_h1 = generate_h1(N, D_BAR, CLIQUE_K, CLIQUE_M, rng, density_factor=DENSITY_FACTOR)
    lam2_W, lam2_Asym, lam_max_B = spectra(A_h1)
    bulk_edge = 2.0 * np.sqrt(D_BAR)
    bulk_edge_asym = 2.0 / np.sqrt(D_BAR)
    return (lam2_W - bulk_edge, lam2_Asym - bulk_edge_asym, lam_max_B - bulk_edge)


def collect_gaps(seeds):
    n = len(seeds)
    gap_W = np.empty(n)
    gap_Asym = np.empty(n)
    gap_B = np.empty(n)
    for i, seed in enumerate(seeds):
        gap_W[i], gap_Asym[i], gap_B[i] = gaps_for_seed(seed)
    return gap_W, gap_Asym, gap_B


def percentile_le(value, sample):
    """Empirical percentile: 100 * P(sample <= value). No interpolation."""
    return 100.0 * float(np.mean(np.asarray(sample) <= value))


def matrix_block(label, gaps, cited, with_q99):
    lines = ["Matrix {}".format(label)]
    lines.append(
        "  gap mean = {:+.2f}  std = {:.2f}  min = {:+.2f}  max = {:+.2f}".format(
            float(gaps.mean()), float(gaps.std()), float(gaps.min()), float(gaps.max())
        )
    )
    lines.append("  P(gap > 0)             = {:.3f}".format(float(np.mean(gaps > 0.0))))
    if with_q99:
        lam = gaps + 2.0 * np.sqrt(D_BAR)
        lines.append(
            "  P(lambda > q99 = {:.4f})  = {:.3f}".format(
                Q99, float(np.mean(lam > Q99))
            )
        )
    lines.append(
        "  Paper cited value      = {:+.4f} -> percentile {:.1f}".format(
            cited, percentile_le(cited, gaps)
        )
    )
    return lines


def paired_block(gap_b, gap_w):
    """Paired comparison of gap_B and gap_W on the same seeds."""
    diff = gap_b - gap_w
    lines = []
    lines.append("    P(gap_B > gap_W)    = {:.3f}".format(float(np.mean(gap_b > gap_w))))
    lines.append("    P(gap_B = gap_W)    = {:.3f}".format(float(np.mean(gap_b == gap_w))))
    lines.append("    P(gap_B < gap_W)    = {:.3f}".format(float(np.mean(gap_b < gap_w))))
    lines.append(
        "    mean(gap_B - gap_W) = {:+.4f}   std = {:.4f}".format(
            float(diff.mean()), float(diff.std())
        )
    )
    return lines


def report():
    seeds = draw_seeds()
    gap_W, gap_Asym, gap_B = collect_gaps(seeds)

    lines = []
    lines.append(SEP)
    lines.append("CLIQUE SPECTRA SEEDS - N=200 seeds, H1 = k=1, m=20, density 10x")
    lines.append(SEP)
    lines.append("")
    lines.append("N = {}, D_BAR = {}".format(N, D_BAR))
    lines.append(
        "Clique: CLIQUE_K = {}, CLIQUE_M = {}, DENSITY_FACTOR = {}x background".format(
            CLIQUE_K, CLIQUE_M, DENSITY_FACTOR
        )
    )
    lines.append("N_SEEDS = {}, SEED_LIST_RNG = {}".format(N_SEEDS, SEED_LIST_RNG))
    lines.append(
        "seeds = default_rng({}).integers(0, 2**31, size={})".format(
            SEED_LIST_RNG, N_SEEDS
        )
    )
    lines.append("first 5 seeds = {}".format(", ".join(str(int(s)) for s in seeds[:5])))
    lines.append("last 5 seeds  = {}".format(", ".join(str(int(s)) for s in seeds[-5:])))
    lines.append(
        "Bulk edges: W and B use 2*sqrt(d_bar) = {:.4f}; A_sym uses 2/sqrt(d_bar) = {:.4f}".format(
            2.0 * np.sqrt(D_BAR), 2.0 / np.sqrt(D_BAR)
        )
    )
    lines.append(
        "Percentile method: empirical ECDF, percentile(x) = 100 * mean(gaps <= x)"
    )
    lines.append("")

    lines.append(SEP)
    lines.append("ALL SEEDS (1..{})".format(N_SEEDS))
    lines.append(SEP)
    lines.append("")
    lines.extend(matrix_block("W", gap_W, CITED["W"], True))
    lines.append("")
    lines.extend(matrix_block("A_sym", gap_Asym, CITED["A_sym"], False))
    lines.append("")
    lines.extend(matrix_block("B", gap_B, CITED["B"], True))
    lines.append("")

    tail = slice(10, None)
    lines.append(SEP)
    lines.append("ROBUSTNESS - seeds 11..{} (first 10 excluded)".format(N_SEEDS))
    lines.append(SEP)
    lines.append("")
    lines.extend(matrix_block("W", gap_W[tail], CITED["W"], True))
    lines.append("")
    lines.extend(matrix_block("A_sym", gap_Asym[tail], CITED["A_sym"], False))
    lines.append("")
    lines.extend(matrix_block("B", gap_B[tail], CITED["B"], True))
    lines.append("")

    gap_W_42, gap_Asym_42, gap_B_42 = gaps_for_seed(42)
    lines.append(SEP)
    lines.append("CROSS-CHECK - seed 42 must reproduce the canonical single-seed run")
    lines.append(SEP)
    lines.append("")
    check = (
        ("W", gap_W_42, CITED["W"]),
        ("A_sym", gap_Asym_42, CITED["A_sym"]),
        ("B", gap_B_42, CITED["B"]),
    )
    for label, value, cited in check:
        same = "{:+.4f}".format(value) == "{:+.4f}".format(cited)
        verdict = "MATCH" if same else "MISMATCH"
        lines.append(
            "  {:5s} gap = {:+.4f}  canonical = {:+.4f}  {}".format(
                label, value, cited, verdict
            )
        )
    lines.append("")

    lines.append(SEP)
    lines.append("PAIRED TEST - B vs W on the same seed")
    lines.append(SEP)
    lines.append("")
    lines.append("  All seeds (1..{}):".format(N_SEEDS))
    lines.extend(paired_block(gap_B, gap_W))
    lines.append("")
    lines.append("  Robustness (seeds 11..{}):".format(N_SEEDS))
    lines.extend(paired_block(gap_B[tail], gap_W[tail]))
    lines.append("")
    lines.append("  main.tex:637 claims gap_B > gap_W (+1.7569 vs +1.6996) on the same")
    lines.append("  seed. The inequality is structural: B = W - dd^T/(2m) with dd^T/(2m)")
    lines.append("  positive semidefinite of rank 1, so lambda_1(W) >= lambda_max(B) >=")
    lines.append("  lambda_2(W) for every graph (Weyl interlacing). The paired test is")
    lines.append("  therefore not informative; the empirical content is the mean")
    lines.append("  difference (reported above), small against the per-seed std.")
    lines.append("")

    return "\n".join(lines) + "\n"


def main():
    text = report()
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT_PATH, "w", encoding="ascii", newline="\n") as fh:
        fh.write(text)
    sys.stdout.write(text)


if __name__ == "__main__":
    main()
