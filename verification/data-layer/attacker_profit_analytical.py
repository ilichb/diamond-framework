#!/usr/bin/env python3
"""
attacker_profit_analytical.py - Attacker profit: closed form vs Monte Carlo.

Context: finding C-07 ("-502 not reproducible from declared parameters"). The
paper cites an attacker profit of -502 with S_slash = 10 as verified (table
rows docs/paper/main.tex:914-918, summary row :951, stability paragraph
:1131), all pointing at verification/data-layer/simulate_data_layer_v3.py.
This script separates the two quantities that the citation merges: the
closed-form expectation of the per-epoch attacker profit, and the Monte Carlo
realization that the canonical script actually reports.

The constants have the same names and the same values as the canonical script
verification/data-layer/simulate_data_layer_v3.py (its lines 15-25).

Identity used. Detection coverage is coverage = 1.0 whenever at least one
auditor is active (v3 line 39), and n_detections = rng.binomial(n_frauds,
coverage) (v3 line 51). A binomial draw with p = 1.0 returns n exactly, so
n_detections == n_frauds in every epoch and the per-epoch profit of v3 line 52

    profit = (n_frauds - n_detections) * V_FRAUD - n_detections * S_SLASH

collapses to profit = -S_SLASH * n_frauds. Therefore

    E[profit]   = -S_SLASH * E[n_frauds]
    Var[profit] = S_SLASH ** 2 * Var[n_frauds]

with n_frauds ~ Binomial(n_att_adv, P_FAKE_GIVEN_ADV), where n_att_adv is the
adversarial-aware attestation count of v3 lines 46-48.

No rounding. This file contains no int(), no round() and no floor(). The
integer counts are written with integer literals and integer arithmetic only,
and the asserts below certify by exact equality that they agree with the
float expressions of the canonical script. Nothing on the profit path is
truncated, so no rounding bias can enter between n_frauds and n_detections.

Determinism. One declared seed, no wall-clock and no environment input, fixed
float formatting: two runs print byte-identical output.

Dependencies: numpy and scipy (see verification/requirements.txt).
Output: stdout only; this script writes no file.
"""

import numpy as np
from scipy.stats import norm


# ---------------------------------------------------------------------------
# Constants: same names and same values as simulate_data_layer_v3.py.
# ---------------------------------------------------------------------------
N_ATTESTATIONS = 500
N_EPOCHS = 500
V_FRAUD = 1.0
S_SLASH = 10.0
BETA_ADVERSARIAL = 0.2
P_FAKE_GIVEN_ADV = 0.5
RNG_SEED = 42

# Detection coverage, fixed at the value the canonical script uses for B >= B*.
COVERAGE = 1.0

# Integer percent base and derived counts, mirroring v3 lines 46-48:
#   n_adv     = 100 * BETA_ADVERSARIAL      = 20
#   n_honest  = 100 - n_adv                 = 80
#   n_att_adv = 500 - 500 * n_honest / 100  = 100
N_PCT = 100
PCT_ADV = 20
PCT_HONEST = N_PCT - PCT_ADV
N_ATT_ADV = N_ATTESTATIONS - (N_ATTESTATIONS * PCT_HONEST) // N_PCT

# Exactness certificates: the integer literals above equal the float
# expressions of v3 exactly, and every division on the count path is exact.
assert PCT_ADV * 1.0 == BETA_ADVERSARIAL * N_PCT
assert PCT_HONEST * 1.0 == N_PCT - N_PCT * BETA_ADVERSARIAL
assert N_ATTESTATIONS % N_PCT == 0
assert (N_ATTESTATIONS * PCT_HONEST) % N_PCT == 0
assert N_ATT_ADV * 1.0 == N_ATTESTATIONS * PCT_ADV / N_PCT
assert N_ATT_ADV == N_ATTESTATIONS - N_ATTESTATIONS * PCT_HONEST / N_PCT

# Attacker profit cited by the paper (main.tex:914-918, :951, :1131).
PAPER_CITED_ATTACKER_PROFIT = -502.00

# Label column width of the printed "name = value" lines.
W = 35


def kv(name, value, width=W):
    """Print one 'name = value' line. Fixed width keeps the output stable."""
    print("{:<{w}} = {}".format(name, value, w=width))


def analytic_values():
    """Closed form from the binomial moments: no sampling, no rounding."""
    p = P_FAKE_GIVEN_ADV
    e_frauds = N_ATT_ADV * p
    var_frauds = N_ATT_ADV * p * (1.0 - p)
    var_profit = S_SLASH ** 2 * var_frauds
    return {
        "n_att_adv": N_ATT_ADV,
        "E_frauds": e_frauds,
        "Var_frauds": var_frauds,
        "E_profit": -S_SLASH * e_frauds,
        "Var_profit": var_profit,
        "SE_analytic": np.sqrt(var_profit / N_EPOCHS),
    }


def monte_carlo():
    """v3 lines 44-52 with coverage = 1.0 fixed, seed RNG_SEED, N_EPOCHS epochs.

    Same structure as the canonical loop: one binomial draw for the frauds and
    one for the detections, then the profit of v3 line 52. No int(), no
    round(), no floor() anywhere on this path.
    """
    rng = np.random.default_rng(RNG_SEED)
    profits_list, frauds_list, detections_list = [], [], []
    for _ in range(N_EPOCHS):
        n_frauds = rng.binomial(N_ATT_ADV, P_FAKE_GIVEN_ADV)
        n_detections = rng.binomial(n_frauds, COVERAGE)
        assert n_detections == n_frauds, "p = 1.0 must return n exactly"
        profit = (n_frauds - n_detections) * V_FRAUD - n_detections * S_SLASH
        profits_list.append(profit)
        frauds_list.append(n_frauds)
        detections_list.append(n_detections)
    profits = np.array(profits_list)
    std_mc = profits.std(ddof=1)
    return {
        "profits": profits,
        "frauds": np.array(frauds_list),
        "detections": np.array(detections_list),
        "mean_mc": profits.mean(),
        "std_mc": std_mc,
        "SE_mc": std_mc / np.sqrt(N_EPOCHS),
    }


def main():
    a = analytic_values()
    mc = monte_carlo()

    mean_mc = mc["mean_mc"]
    se_analytic = a["SE_analytic"]
    z_vs_analitico = (mean_mc - a["E_profit"]) / se_analytic
    p_bilateral = 2.0 * (1.0 - norm.cdf(abs(z_vs_analitico)))
    z_paper = (PAPER_CITED_ATTACKER_PROFIT - a["E_profit"]) / se_analytic

    print("=" * 78)
    print("ATTACKER PROFIT - CLOSED FORM VS MONTE CARLO (data layer, coverage = 1.0)")
    print("=" * 78)
    print()

    print("Constants (same names and values as simulate_data_layer_v3.py):")
    kv("N_ATTESTATIONS", N_ATTESTATIONS)
    kv("N_EPOCHS", N_EPOCHS)
    kv("V_FRAUD", "{:.1f}".format(V_FRAUD))
    kv("S_SLASH", "{:.1f}".format(S_SLASH))
    kv("BETA_ADVERSARIAL", "{:.1f}".format(BETA_ADVERSARIAL))
    kv("P_FAKE_GIVEN_ADV", "{:.1f}".format(P_FAKE_GIVEN_ADV))
    kv("RNG_SEED", RNG_SEED)
    kv("COVERAGE", "{:.1f}".format(COVERAGE))
    print()

    print("Derived counts (integer arithmetic only, no int()/round()/floor()):")
    kv("N_PCT", N_PCT)
    kv("PCT_ADV", PCT_ADV)
    kv("PCT_HONEST", PCT_HONEST)
    kv("n_att_adv", a["n_att_adv"])
    print()

    print("Analytical values (n_frauds ~ Binomial(n_att_adv, P_FAKE_GIVEN_ADV)):")
    kv("E[n_frauds]", "{:.6f}".format(a["E_frauds"]))
    kv("Var[n_frauds]", "{:.6f}".format(a["Var_frauds"]))
    kv("E[attacker_profit per epoch]", "{:.6f}".format(a["E_profit"]))
    kv("Var[attacker_profit per epoch]", "{:.6f}".format(a["Var_profit"]))
    kv("SE[mean over N_EPOCHS]", "{:.6f}".format(se_analytic))
    print()

    print("Monte Carlo (seed RNG_SEED, N_EPOCHS epochs, coverage = 1.0 fixed):")
    kv("mean_mc", "{:.6f}".format(mean_mc))
    kv("std_mc", "{:.6f}".format(mc["std_mc"]))
    kv("SE_mc", "{:.6f}".format(mc["SE_mc"]))
    kv("z_vs_analitico", "{:.6f}".format(z_vs_analitico))
    kv("p_bilateral", "{:.6f}".format(p_bilateral))
    kv("IC95", "[{:.6f}, {:.6f}]".format(mean_mc - 1.96 * se_analytic,
                                         mean_mc + 1.96 * se_analytic))
    print()

    print("Verdict:")
    kv("atacante_profit_esperado_analitico", "{:.2f}".format(a["E_profit"]))
    kv("atacante_profit_realizacion_mc", "{:.2f}".format(mean_mc))
    kv("paper_cita", "{:.2f}".format(PAPER_CITED_ATTACKER_PROFIT))
    kv("z_del_paper_vs_analitico", "{:.6f}".format(z_paper))
    print()

    print("Cross-checks against the canonical script (coverage = 1.0):")
    kv("n_detections == n_frauds (epochs)",
       "{}/{}".format((mc["detections"] == mc["frauds"]).sum(), N_EPOCHS))
    kv("sum(n_frauds)", mc["frauds"].sum())
    kv("mean(n_frauds)", "{:.6f}".format(mc["frauds"].mean()))
    kv("sum(profits) identity",
       mc["profits"].sum() == -S_SLASH * mc["frauds"].sum())
    kv("paper value minus analytic value",
       "{:.6f}".format(PAPER_CITED_ATTACKER_PROFIT - a["E_profit"]))
    print()

    print("Note:")
    print("  -502.00 is the Monte Carlo realization, equal to -S_SLASH times the")
    print("  realized mean fraud count (10 * 50.2). It is not a closed form. The")
    print("  closed form under the profit formula of v3 line 52 is -500.00; the")
    print("  alternative convention that credits V_FRAUD on detected frauds,")
    print("  n_frauds * (V_FRAUD - S_SLASH) = 50 * (1 - 10), gives -450.00. The")
    print("  52-unit gap decomposes as 50 (profit convention) + 2 (Monte Carlo).")
    print()
    print("=" * 78)


if __name__ == "__main__":
    main()
