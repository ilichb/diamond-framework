#!/usr/bin/env python3
"""
asym_weights.py - Expected per-pair weight under W and A_sym (part (a)).

Context: finding C-05. The paper explains the failure of A_sym with a degree
argument (weights divided by 27.2 instead of 20), but the expected per-pair
weight of an intra-clique pair is DENSITY_FACTOR times the expected per-pair
weight of a background pair. Part (a) quantifies both weights and their
ratio, in closed form, from the parameters of the canonical script.

Two rows are reported for A_sym: one with the H1 expected background degree
(d_bg = 27.214, the model-consistent denominator) and one with the null-model
degree (d_bg = 20.000, the value cited by section 5.2). The comparison
decides whether the clique contrast survives degree normalization, so both
denominators are reported side by side.

Part (b) (first-order BBP predictions: theta, detection threshold, margin,
normalization factor, predicted gaps) is NOT implemented. Stop rule applied:
norm_factor = D_BAR / (D_BAR + theta) and gap_Asym_pred have no verifiable
reference and no self-contained derivation, and theta / sqrt(D_BAR) does not
reproduce the observed gap within a factor of 2. Part (b) is left as
[CONJECTURE] in the worksheet.

Parameters (identical to the canonical clique_spectra.py):
  N = 500, D_BAR = 20, CLIQUE_M = 20, DENSITY_FACTOR = 10

Data dependency: closed form from the parameters above. This script does not
read clique_spectra_seeds_output.txt or any other file.

Output: verification/rmt/results/asym_weights_output.txt
"""

import sys
from pathlib import Path

N = 500
D_BAR = 20
CLIQUE_M = 20
DENSITY_FACTOR = 10

OUT_PATH = Path(__file__).resolve().parent / "results" / "asym_weights_output.txt"
SEP = "=" * 78


def expected_weights():
    """Return p_out, p_in, both expected degrees and the four pair weights.

    Inline derivations (no external reference is required for part (a)):

    p_out = D_BAR / (N - 1).
      The background is Erdos-Renyi G(N, p_out): each of the N - 1 other
      nodes is a neighbour with probability p_out, so the mean degree is
      (N - 1) * p_out = D_BAR.

    p_in = min(1.0, DENSITY_FACTOR * p_out).
      The clique has intra-clique edge probability DENSITY_FACTOR times the
      background one, capped at 1.

    d_clique = (CLIQUE_M - 1) * p_in + (N - CLIQUE_M) * p_out.
      A clique node has CLIQUE_M - 1 intra-clique pairs (probability p_in)
      and N - CLIQUE_M background pairs (probability p_out).

    d_bg = CLIQUE_M * p_in + (N - CLIQUE_M - 1) * p_out.
      A background node has CLIQUE_M pairs towards the clique and
      N - CLIQUE_M - 1 pairs towards the rest of the background; the -1
      removes the self-pair.

    Expected weight of a pair:
      W_ij     = A_ij, so E[W_ij] = P(ij is an edge).
      A_sym_ij = A_ij / sqrt(d_i d_j), so E[A_sym_ij] is approximated by
                 P(ij is an edge) / sqrt(E[d_i] E[d_j]) (mean field: the
                 realized weight fluctuates with the realized degrees).
      intra-clique: i and j are both clique nodes.
      background:   i and j are both background nodes.
    """
    p_out = D_BAR / (N - 1)
    p_in = min(1.0, DENSITY_FACTOR * p_out)
    d_clique = (CLIQUE_M - 1) * p_in + (N - CLIQUE_M) * p_out
    d_bg = CLIQUE_M * p_in + (N - CLIQUE_M - 1) * p_out
    return {
        "p_out": p_out,
        "p_in": p_in,
        "d_clique": d_clique,
        "d_bg": d_bg,
        "w_clique_W": p_in,
        "w_bg_W": p_out,
        "w_clique_Asym": p_in / d_clique,
        "w_bg_Asym": p_out / d_bg,
    }


def report():
    v = expected_weights()
    lines = []
    lines.append(SEP)
    lines.append("ASYM WEIGHTS - expected per-pair weight, W vs A_sym")
    lines.append(SEP)
    lines.append("")
    lines.append(
        "N = {}, D_BAR = {}, CLIQUE_M = {}, DENSITY_FACTOR = {}".format(
            N, D_BAR, CLIQUE_M, DENSITY_FACTOR
        )
    )
    lines.append("")
    lines.append(
        "p_out    = D_BAR / (N - 1)                         = {:.6f}".format(
            v["p_out"]
        )
    )
    lines.append(
        "p_in     = min(1, DENSITY_FACTOR * p_out)          = {:.6f}".format(
            v["p_in"]
        )
    )
    lines.append(
        "d_clique = (CLIQUE_M-1)*p_in + (N-CLIQUE_M)*p_out  = {:.4f}".format(
            v["d_clique"]
        )
    )
    lines.append(
        "d_bg     = CLIQUE_M*p_in + (N-CLIQUE_M-1)*p_out    = {:.4f}".format(
            v["d_bg"]
        )
    )
    lines.append("")
    lines.append("Expected weight of one pair")
    header = "  {:<22} {:>16} {:>16} {:>14}".format(
        "Matrix", "intra-clique", "background", "ratio intra/bg"
    )
    lines.append(header)
    lines.append("  " + "-" * (len(header) - 2))
    rows = (
        ("W   (raw)", v["w_clique_W"], v["w_bg_W"]),
        ("A_sym (d_bg = 27.214)", v["w_clique_Asym"], v["w_bg_Asym"]),
        ("A_sym (d_bg = 20.000)", v["w_clique_Asym"], v["p_out"] / D_BAR),
    )
    for label, w_intra, w_bg in rows:
        lines.append(
            "  {:<22} {:>16.6f} {:>16.6f} {:>14.4f}".format(
                label, w_intra, w_bg, w_intra / w_bg
            )
        )
    lines.append("")
    lines.append("Notes:")
    lines.append("- d_bg = 27.214 is the expected degree of a background node in the")
    lines.append("  H1 graph (clique present). This is the model-consistent denominator.")
    lines.append("- d_bg = 20.000 is the null-model degree, cited by section 5.2 as the")
    lines.append("  background degree.")
    lines.append("- Under either denominator the clique's expected per-pair weight")
    lines.append("  exceeds the background's by more than 7, contradicting the")
    lines.append('  "cancelled by degree increase" claim.')
    lines.append("")
    lines.append(
        "DENSITY_FACTOR = {} is the ratio of the underlying edge".format(
            DENSITY_FACTOR
        )
    )
    lines.append("probabilities; compare it with the ratios above.")
    lines.append("")
    lines.append("Method: closed form, mean-field expected weights. A_sym divides")
    lines.append("by the expected degrees, so the realized weight of one pair")
    lines.append("fluctuates with the realized degree sequence.")
    lines.append("")
    lines.append("Part (b) of the task (first-order BBP predictions) is not")
    lines.append("implemented; see the docstring for the stop rule applied.")
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
