#!/usr/bin/env python3
"""
m05_attack_model.py - Deterrence as a function of detection latency (M-05).

Context: findings A-18 and A-21 of the external-review triage. The paper's
Section 7.5 states the attacker profit of a *worksheet*: the gain is a scalar
constant of simulate_data_layer_v3.py (V_FRAUD = 1.0, its line 17) multiplied by
the attack's own sample (N_ATT * p_fraud), and the loss is S_SLASH = 10.0 (its
line 18). Neither constant has a counterpart in the protocol: no contract
carries a fraud value, and the manager's slash takes the whole posted stake
rather than a caller-supplied number (M9b, plan 12.1.2 / DEC-4). A-21 asks for
the declared model; A-18 for the deterrence condition the paper never writes:

    E = (1 - q) * G - q * L < 0        <=>        q > G / (G + L)

with G the gain if undetected, L the loss if detected and q the per-epoch
detection probability. The delivered step convention (paper lines 999-1000) is
q = 1 whenever an auditor is active; what this script adds is that under the
*declared* quantities the detection latency k, in epochs, is the binding
parameter, and the freshness parameter gamma bounds it from the other side.

The declared model, term by term:

  gain  G(k, omega) = k * omega * DeltaS       capital cost the inflated norm
                                               avoids, per undetected epoch
  loss  L = S_f*(r_fraud) + n * kappa          the escrow actually debited on
                                               detection (the whole posted
                                               stake, DEC-4) plus the ejection
                                               surcharge of the n-th re-entry
                                               (DEC-5 / M9c)

DeltaS is the stake the declared norm buys: publishing a fraudulent leaf
inflates the certified norm from r_true = 0 to r_fraud, and the admission rule
charges S_f*(r_fraud) instead of S_f*(0) = Theta, so the attacker avoids locking
C_R(r_fraud) of capital. omega is the private cost of capital of Section 5.3 and
kappa = 0.1 is the delivered EJECTION_SURCHARGE of the validator manager (M9c),
the price of the n-th re-entry.

Scope: this script computes and prints only; it writes to stdout and touches no
other file. It does not replace simulate_data_layer_v3.py: that script measures
the audit equilibrium n*(B) of Section 7.4, and its constants stay where they
are. What changes is the *attacker* of the model, not the equilibrium.

Sample and seed (log rules 2 and 3): the analytic tables are exact rational
arithmetic (fractions.Fraction, no rounding); the population block samples
omega ~ Uniform[0.01, 0.10] with N_REPLICATES draws under RNG_SEED, the same
population and seed as fee_specification.py.

Dependencies: numpy only.
Exit status: 0 on success. A failing assert aborts the run (nonzero exit) and
prints its message on stderr.
"""

from fractions import Fraction as F

import numpy as np


# ---- declared sample, seed and protocol parameters -------------------------

RNG_SEED = 42
N_REPLICATES = 10000

THETA = F(1)                # admission threshold (Section 5.1)
CR_INF = F(8, 10)           # C_R^inf = 0.8: saturation of C_R(r) = 0.8r/(1+r)
S_MIN = THETA - CR_INF      # floor S_min = Theta - C_R^inf = 0.2
GAMMA = F(1, 10)            # freshness reference pair gamma = 0.10 (Section 7.6)
KAPPA = F(1, 10)            # EJECTION_SURCHARGE of AVIPValidatorManager (M9c)
OMEGA_MIN = F(1, 100)       # 0.01
OMEGA_MAX = F(1, 10)        # 0.10

R_GRID = [F(1, 4), F(1, 2), F(1), F(2), F(4)]   # certified norms r_fraud
K_GRID = [1, 2, 3, 5, 10, 20]                    # detection latency in epochs
Q_GRID = [F(1), F(1, 2), F(1, 10)]               # detection probabilities
R_REF = F(1)                                     # reference inflation
R_BIG = F(10**9)                                 # a large norm, for limits
N_EJECTIONS = [1, 2, 3]                          # repeat offences (DEC-5)

# ---- the declared quantities ----------------------------------------------

def c_r(r):
    """Reputational collateral C_R(r) = C_R^inf * r / (1 + r)."""
    return CR_INF * r / (1 + r)


def s_f_star(r):
    """Required stake S_f*(r) = max{ S_min, Theta - C_R(r) } (eq: allocation)."""
    return max(S_MIN, THETA - c_r(r))


def delta_s(r):
    """Stake the declared norm buys: S_f*(0) - S_f*(r). Equals C_R(r) unfloored."""
    return s_f_star(F(0)) - s_f_star(r)


def loss(r_fraud, n_ejections=0):
    """Escrow debited (DEC-4) plus the n-th re-entry surcharge (DEC-5)."""
    return s_f_star(r_fraud) + n_ejections * KAPPA


def q_min(k, omega, r_fraud, n_ejections=0):
    """Smallest per-epoch detection probability that deters: G / (G + L)."""
    g = k * omega * delta_s(r_fraud)
    l = loss(r_fraud, n_ejections)
    return g / (g + l)


def k_break_even(q, omega, r_fraud, n_ejections=0):
    """Latency at which E = 0: q * L / ((1 - q) * omega * DeltaS)."""
    g1 = omega * delta_s(r_fraud)          # gain per undetected epoch
    return q * loss(r_fraud, n_ejections) / ((1 - q) * g1)


def freshness_window():
    """Largest integer k with gamma * k < 1: beyond it the bound is vacuous."""
    k = 0
    while GAMMA * (k + 1) < 1:
        k += 1
    return k


def main():
    window = freshness_window()
    ref_ds = delta_s(R_REF)

    print("=" * 78)
    print("M-05 - DETERRENCE VERSUS DETECTION LATENCY (findings A-18 / A-21)")
    print("=" * 78)
    print()
    print("Declared model (not the worksheet's scalars V_FRAUD / S_SLASH):")
    print("  gain  G(k, omega) = k * omega * DeltaS    (capital cost avoided)")
    print("  loss  L = S_f*(r_fraud) + n * kappa       (escrow debited + surcharge)")
    print("  deterrence: E = (1 - q) * G - q * L < 0  <=>  q > G / (G + L)")
    print()
    print("Parameters:")
    print("  THETA = {}, CR_INF = {} -> S_MIN = {}".format(THETA, CR_INF, S_MIN))
    print("  omega in [{}, {}] (private cost of capital, Section 5.3)".format(
        OMEGA_MIN, OMEGA_MAX))
    print("  GAMMA = {} (freshness), KAPPA = {} (EJECTION_SURCHARGE, M9c)".format(
        GAMMA, KAPPA))
    print("  sample: N_REPLICATES = {}, RNG_SEED = {}".format(
        N_REPLICATES, RNG_SEED))
    print("  reference inflation: r_true = 0 -> r_fraud = {}".format(R_REF))
    print()

    print("Table 1. The stake the inflated norm buys, by certified norm")
    print("{:>10} {:>12} {:>12} {:>12} {:>12}".format(
        "r_fraud", "C_R(r)", "S_f*(r)", "DeltaS", "L (n=0)"))
    print("-" * 62)
    for r in R_GRID:
        print("{:>10.4f} {:>12.6f} {:>12.6f} {:>12.6f} {:>12.6f}".format(
            float(r), float(c_r(r)), float(s_f_star(r)),
            float(delta_s(r)), float(loss(r))))
    print("{:>10} {:>12.6f} {:>12.6f} {:>12.6f} {:>12.6f}".format(
        "limit", float(CR_INF), float(S_MIN), float(CR_INF), float(S_MIN)))
    print("(limit as r -> inf, reached from above: at r = 1e9 the unfloored")
    print(" allocation is S_MIN + {:.1e}, the infimum the floor meets but".format(
        float(THETA - c_r(R_BIG) - S_MIN)))
    print(" never exceeds -- paper line 840)")
    print("(the loss over the admissible range is S_f*(r) in [{:.1f}, {:.1f}])".format(
        float(S_MIN), float(s_f_star(F(0)))))
    print()

    print("Table 2. Required detection probability q_min at k epochs (r_fraud = {})".format(
        R_REF))
    print("{:>6} {:>14} {:>14}".format("k", "omega = 0.01", "omega = 0.10"))
    print("-" * 36)
    for k in K_GRID:
        print("{:>6} {:>14.6f} {:>14.6f}".format(
            k, float(q_min(k, OMEGA_MIN, R_REF)), float(q_min(k, OMEGA_MAX, R_REF))))
    print()

    print("Table 3. Break-even latency k_be(q, omega), epochs (r_fraud = {}, n = 0)".format(
        R_REF))
    print("{:>6} {:>16} {:>16}".format("q", "omega = 0.01", "omega = 0.10"))
    print("-" * 40)
    for q in Q_GRID:
        if q == 1:
            print("{:>6.2f} {:>16} {:>16}".format(
                float(q), "no bound (E < 0)", "no bound (E < 0)"))
            continue
        print("{:>6.2f} {:>16.4f} {:>16.4f}".format(
            float(q), float(k_break_even(q, OMEGA_MIN, R_REF)),
            float(k_break_even(q, OMEGA_MAX, R_REF))))
    print()

    print("Table 4. The ejection surcharge inside the loss (r_fraud = {}, q = 0.10)".format(
        R_REF))
    print("{:>4} {:>10} {:>18} {:>18}".format(
        "n", "L_eff", "q_min(k=1, 0.10)", "k_be(0.10, 0.10)"))
    print("-" * 54)
    for n in N_EJECTIONS:
        print("{:>4} {:>10.6f} {:>18.6f} {:>18.4f}".format(
            n, float(loss(R_REF, n)), float(q_min(1, OMEGA_MAX, R_REF, n)),
            float(k_break_even(F(1, 10), OMEGA_MAX, R_REF, n))))
    print("(kappa = {} is added per ejection, never folded into S_f*: DEC-5)".format(
        KAPPA))
    print()

    # ---- population block: omega ~ U[0.01, 0.10], declared sample and seed ----
    rng = np.random.default_rng(RNG_SEED)
    omegas = rng.uniform(float(OMEGA_MIN), float(OMEGA_MAX), N_REPLICATES)
    ds = float(ref_ds)
    l0 = float(loss(R_REF))
    g1 = omegas * ds                     # gain per undetected epoch
    q1 = g1 / (g1 + l0)                  # q_min at k = 1
    q5 = (5 * g1) / (5 * g1 + l0)        # q_min at k = 5
    kbe = 0.1 * l0 / (0.9 * g1)          # k_be at q = 0.10

    print("Population omega ~ Uniform[{}, {}], N = {}, seed = {}".format(
        float(OMEGA_MIN), float(OMEGA_MAX), N_REPLICATES, RNG_SEED))
    print("{:>26} {:>12} {:>12} {:>12}".format(
        "statistic", "q_min(k=1)", "q_min(k=5)", "k_be(q=0.10)"))
    print("-" * 66)
    print("{:>26} {:>12.6f} {:>12.6f} {:>12.4f}".format(
        "min", q1.min(), q5.min(), kbe.max()))
    print("{:>26} {:>12.6f} {:>12.6f} {:>12.4f}".format(
        "median", float(np.median(q1)), float(np.median(q5)),
        float(np.median(kbe))))
    print("{:>26} {:>12.6f} {:>12.6f} {:>12.4f}".format(
        "max", q1.max(), q5.max(), kbe.min()))
    print("{:>26} {:>12.6f} {:>12.6f} {:>12.4f}".format(
        "exact at omega_max", float(q_min(1, OMEGA_MAX, R_REF)),
        float(q_min(5, OMEGA_MAX, R_REF)),
        float(k_break_even(F(1, 10), OMEGA_MAX, R_REF))))
    print()

    print("=" * 78)
    print("VERIFICATION")
    print("=" * 78)
    print()
    print("{:<44} = {:<11} (expected {})".format(
        "freshness window (gamma*k < 1)",
        "{} epochs".format(window), "9 epochs"))
    print("{:<44} = {:<11} (expected 0.200000)".format(
        "S_f*(r) -> S_MIN, unfloored at r = 1e9",
        "{:.6f}".format(float(THETA - c_r(R_BIG)))))
    print("{:<44} = {:<11} (expected 0.800000)".format(
        "DeltaS -> C_R^inf, value at r = 1e9",
        "{:.6f}".format(float(delta_s(R_BIG)))))
    print("{:<44} = {:<11} (expected 0.062500)".format(
        "q_min(k=1, omega=0.10)",
        "{:.6f}".format(float(q_min(1, OMEGA_MAX, R_REF)))))
    print("{:<44} = {:<11} (expected 0.250000)".format(
        "q_min(k=5, omega=0.10)",
        "{:.6f}".format(float(q_min(5, OMEGA_MAX, R_REF)))))
    print("{:<44} = {:<11} (expected 1.666667)".format(
        "k_be(0.10, omega=0.10)",
        "{:.6f}".format(float(k_break_even(F(1, 10), OMEGA_MAX, R_REF)))))
    print("{:<44} = {:<11} (expected 16.666667)".format(
        "k_be(0.10, omega=0.01)",
        "{:.6f}".format(float(k_break_even(F(1, 10), OMEGA_MIN, R_REF)))))
    print("{:<44} = {:<11} (expected 15.000000)".format(
        "ratio L/G at the worst-case type (k=1)",
        "{:.6f}".format(float(loss(R_REF) / (OMEGA_MAX * ref_ds)))))
    print("{:<44} = {:<11} (expected True)".format(
        "k_be(0.10, omega=0.01) exceeds the window",
        "{}".format(k_break_even(F(1, 10), OMEGA_MIN, R_REF) > window)))
    print()

    # ---- the declared model's own consistency, on exact arithmetic -----------
    for r in R_GRID:
        assert delta_s(r) == c_r(r), "DeltaS(r) != C_R(r) at r = {}".format(r)
        assert loss(r) == max(S_MIN, THETA - c_r(r)), (
            "L is neither Theta - C_R(r) nor S_MIN at r = {}".format(r))
    assert S_MIN == F(1, 5) and CR_INF == F(4, 5), "S_MIN / C_R^inf drifted"
    assert S_MIN == THETA - CR_INF, "the floor is not Theta - C_R^inf"
    # The floor is the *infimum* of the unfloored allocation (paper line 840):
    # approached from above as 1/r, met in the limit, never exceeded.
    assert THETA - c_r(R_BIG) > S_MIN, "the floor is reached at a finite norm"
    assert THETA - c_r(R_BIG) - S_MIN < F(1, 10**8), "C_R -> C_R^inf as 1/r"
    assert CR_INF - c_r(R_BIG) < F(1, 10**8), "DeltaS -> C_R^inf as 1/r"
    assert s_f_star(R_BIG) == THETA - c_r(R_BIG), "the floor branch engaged early"
    assert delta_s(R_BIG) == c_r(R_BIG), "DeltaS != C_R at r = 1e9"
    assert window == 9, "gamma * k < 1 should hold up to k = 9 for gamma = 0.10"
    assert GAMMA * (window + 1) >= 1 > GAMMA * window, "freshness window wrong"

    # q_min increases in k and in omega, and the gain never reaches the loss
    for r in R_GRID:
        for w in (OMEGA_MIN, OMEGA_MAX):
            qs = [q_min(k, w, r) for k in K_GRID]
            assert all(a < b for a, b in zip(qs, qs[1:])), (
                "q_min not increasing in k (r = {}, omega = {})".format(r, w))
        assert q_min(1, OMEGA_MIN, r) < q_min(1, OMEGA_MAX, r), (
            "q_min not increasing in omega at r = {}".format(r))
        assert q_min(K_GRID[-1], OMEGA_MAX, r) < 1, (
            "q_min reached 1 at r = {}".format(r))
        assert loss(r) / (OMEGA_MAX * delta_s(r)) > 1, (
            "the gain exceeds the loss at r = {}: the attack pays".format(r))

    # the step convention (q = 1) against the delivered freshness pair
    assert q_min(1, OMEGA_MAX, R_REF) < F(1, 10), (
        "the worst-case type needs q > 0.10 at k = 1")
    assert k_break_even(F(1, 10), OMEGA_MAX, R_REF) < 2, (
        "the worst-case type sustains 2 undetected epochs at q = 0.10")
    assert k_break_even(F(1, 10), OMEGA_MIN, R_REF) > window, (
        "at the cheapest capital the economics, not gamma, would bind")

    # the surcharge only ever raises the loss: the n-th re-entry is strictly worse
    for n in N_EJECTIONS:
        assert loss(R_REF, n) == loss(R_REF) + n * KAPPA, "surcharge is not linear"
        assert q_min(1, OMEGA_MAX, R_REF, n) < q_min(1, OMEGA_MAX, R_REF, n - 1), (
            "the surcharge does not lower q_min at n = {}".format(n))
        assert k_break_even(F(1, 10), OMEGA_MAX, R_REF, n) > \
            k_break_even(F(1, 10), OMEGA_MAX, R_REF, n - 1), (
            "the surcharge does not raise k_be at n = {}".format(n))

    # the population block reproduces the exact worst case from below
    assert q1.max() < float(q_min(1, OMEGA_MAX, R_REF)), (
        "the sampled population exceeds the worst-case type")
    midpoint = 0.5 * (float(q_min(1, OMEGA_MIN, R_REF)) +
                      float(q_min(1, OMEGA_MAX, R_REF)))
    assert abs(float(np.median(q1)) - midpoint) < 0.01, (
        "the sampled median is not near the midpoint of the exact range")
    assert kbe.min() == float(0.1 * l0 / (0.9 * g1.max())), "k_be is not q*L/((1-q)*G)"

    print("All assertions passed (Tables 1-4 in exact rational arithmetic).")


if __name__ == "__main__":
    main()


