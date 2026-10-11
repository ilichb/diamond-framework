#!/usr/bin/env python3
"""Regenerates `src/datalayer/fixtures/numpy_binomial_seed42.txt` (M7b, plan §5.9).

The file pins numpy 2.2.6's `Generator.binomial` draws from `np.random.default_rng(42)`,
one *fresh* generator per group, so each group can be compared in isolation.

Why binomial and not something easier: the sealed data-layer script
`verification/data-layer/simulate_data_layer_v3.py` draws
`rng.binomial(n_att_adv, P_FAKE_GIVEN_ADV)` (n=100, p=0.5) and, when at least one
auditor is active, a *second* `rng.binomial(n_frauds, coverage)` with
`coverage = 1.0`. numpy 2.2.6's `random_binomial` consumes no draw for `p == 0`,
one for `p == 1` (the `q = 1-p` branch lands in `random_binomial_inversion` with
`p = 0`), and BTPE's ≥2-with-rejection for `n*p = 50 > 30`. Both medians the sealed
output prints (49.9 below the threshold, 50.2 at or above it) come from the same
PCG64 stream displaced by exactly that difference, which is why M7b has to
transcribe the algorithm instead of approximating it.

Groups (n, p, count):
  btpe100_05      100, 0.5, 500   n*p = 50 > 30 → BTPE (the sealed first draw)
  btpe1000_05    1000, 0.5, 200   BTPE, wider support
  inv3_05           3, 0.5, 200   n*p = 1.5 ≤ 30 → inversion
  highp100_09     100, 0.9, 200   p > 0.5, q*n = 10 ≤ 30 → n - inversion
  highp1000_09   1000, 0.9, 200   p > 0.5, q*n = 100 > 30 → n - BTPE
  degenerate          6 draws     n=0, p=0.0, p=1.0 in both orders
  sealed_cov1        pair-wise     the sealed script's interleaved pair at B ≥ B*
  sealed_cov0        pair-wise     the same pair at B < B* (second draw consumes 0)

Usage:  python3 src/datalayer/scripts/gen_fixture.py
"""

import pathlib

import numpy as np

SEED = 42


def sequence(n, p, count):
    rng = np.random.default_rng(SEED)
    return [int(rng.binomial(n, p)) for _ in range(count)]


def interleaved(n, p, coverage, count):
    """The sealed script's two draws per epoch: frauds, then detections."""
    rng = np.random.default_rng(SEED)
    pairs = []
    for _ in range(count):
        n_frauds = int(rng.binomial(n, p))
        n_detections = int(rng.binomial(n_frauds, coverage))
        pairs.append((n_frauds, n_detections))
    return pairs


def degenerate():
    rng = np.random.default_rng(SEED)
    return [
        int(rng.binomial(0, 0.5)),    # n == 0 → 0
        int(rng.binomial(5, 0.0)),    # p == 0 → 0, consumes nothing
        int(rng.binomial(5, 1.0)),    # p == 1 → n, consumes one double
        int(rng.binomial(100, 1.0)),  # p == 1 at the sealed n
        int(rng.binomial(0, 0.0)),
        int(rng.binomial(1, 0.0)),
    ]


def main():
    cov1 = interleaved(100, 0.5, 1.0, 500)
    cov0 = interleaved(100, 0.5, 0.0, 500)

    lines = [
        "# numpy 2.2.6 binomial draws from `np.random.default_rng(42)` — the reference",
        "# for `src/binomial.rs` (M7b, plan §5.9). One *fresh* generator per group, so the",
        "# groups can be compared in isolation; the sealed script interleaves two draws per",
        "# epoch (frauds, then detections) and that interleaving is pinned here as well.",
        "#",
        "# The sealed output `verification/data-layer/results/simulate_data_layer_v3_output.txt`",
        "# prints two different fraud means: 49.9 for B < B* and 50.2 for B >= B* (B* = 1.0).",
        "# They are the same stream: `binomial(n, 0.0)` consumes no draw, while `binomial(n, 1.0)`",
        "# consumes one — numpy 2.2.6 `distributions.c` takes the `q = 1 - p` branch and calls",
        "# `random_binomial_inversion` with `p = 0`, which reads a single `next_double`.",
        "# `n * p = 50 > 30` sends the fraud draw to BTPE, so each of its draws is two doubles",
        "# plus rejection. Regenerate with:",
        "#",
        "#   python3 src/datalayer/scripts/gen_fixture.py",
        "#",
        "# Every group below is printed with one `key = values` line, integers separated by",
        "# single spaces, so `include_str!` parsing stays a two-line function.",
        "",
    ]

    def emit(key, values):
        lines.append(f"{key} = {' '.join(str(v) for v in values)}")

    emit("btpe100_05(500)", sequence(100, 0.5, 500))
    emit("btpe1000_05(200)", sequence(1000, 0.5, 200))
    emit("inv3_05(200)", sequence(3, 0.5, 200))
    emit("highp100_09(200)", sequence(100, 0.9, 200))
    emit("highp1000_09(200)", sequence(1000, 0.9, 200))
    emit("degenerate(6)", degenerate())
    emit("sealed_cov1_frauds(500)", [nf for nf, _ in cov1])
    emit("sealed_cov1_detections(500)", [nd for _, nd in cov1])
    emit("sealed_cov0_frauds(500)", [nf for nf, _ in cov0])
    emit("sealed_cov0_detections(500)", [nd for _, nd in cov0])

    out = pathlib.Path(__file__).resolve().parents[1] / "fixtures" / "numpy_binomial_seed42.txt"
    out.write_text("\n".join(lines) + "\n")
    print(f"wrote {out} ({out.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
