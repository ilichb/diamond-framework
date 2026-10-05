#!/usr/bin/env python3
"""
fee_specification_net.py - Net revenue column for the F0 sensitivity table.

Context: finding C-08(b). The canonical script fee_specification.py prints the
gross revenue column f0 * N_VALIDATORS (its line 139) without discounting the
validators that violate Individual Rationality once the fee exceeds F0*. This
script adds the net column

    net_revenue = f0 * (N_VALIDATORS - n_excluded)

where n_excluded is the number of sampled validators with U < -1e-9, the same
tolerance the canonical script uses (its line 138). At F0 = 1.2 * F0* this
gives n_excluded = 2 and net_revenue = 59.88 against a gross 60.00, which is
the arithmetic of C-08(b).

Sample, RNG call order and tolerance are identical to the canonical script, so
the utilities computed here coincide with the canonical ones term by term
(U min = 0.009747 at F0 = F0*). The five constants and the four helper
functions are copies of the canonical ones, with the same names and values.

Scope: this script computes and prints only. It does not modify
fee_specification.py, its canonical output, or any other file; it writes to
stdout only. No int(), round() or floor() is applied to the revenues: the
asserts check exact equality of the printed rows against the raw expressions.

Dependencies: numpy only.
Exit status: 0 on success. A failing assert aborts the run (nonzero exit) and
prints its message on stderr.
"""

import numpy as np


RNG_SEED = 42
N_VALIDATORS = 1000
OMEGA_MIN = 0.01
OMEGA_MAX = 0.10
PI_VAL = 0.15
THETA = 1.0
VAR_TECH = 0.2

# IR tolerance, identical to fee_specification.py line 138.
IR_TOL = -1e-9


def c_r(norm_T):
    """Agregador concavo sobre la norma del tensor."""
    return 0.8 * norm_T / (1.0 + norm_T)


def s_f_star(norm_T):
    """Stake financiero requerido dado el score de reputacion."""
    return max(VAR_TECH, THETA - c_r(norm_T))


def utility(omega, norm_T, F0):
    """Utilidad del validador de tipo omega con reputacion norm_T."""
    return PI_VAL - omega * s_f_star(norm_T) - F0


def find_optimal_fee(omega_max):
    """
    F0* tal que IR se satura en (omega_max, norm_T=0).
    Con norm_T=0: S_f* = Theta.
    U(omega_max, 0) = PI_VAL - omega_max * Theta - F0 = 0
    => F0* = PI_VAL - omega_max * Theta
    """
    return PI_VAL - omega_max * THETA


def utilities_at(omegas, norm_Ts, f0):
    """Utilidades de la poblacion muestreada con fee f0 (formula canonica)."""
    return np.array([utility(w, t, f0) for w, t in zip(omegas, norm_Ts)])


def count_excluded(omegas, norm_Ts, f0):
    """Validadores con U < -1e-9 (tolerancia canonica, fee_specification.py:138)."""
    return (utilities_at(omegas, norm_Ts, f0) < IR_TOL).sum()


def build_rows(omegas, norm_Ts, f0_grid):
    """Filas brutas de la tabla. gross/net se guardan sin redondeo intermedio."""
    rows = []
    for f0 in f0_grid:
        n_exc = count_excluded(omegas, norm_Ts, f0)
        rows.append({
            "F0": f0,
            "N_VALIDATORS": N_VALIDATORS,
            "n_excluded": n_exc,
            "gross_revenue": f0 * N_VALIDATORS,
            "net_revenue": f0 * (N_VALIDATORS - n_exc),
            "viol_frac": n_exc / N_VALIDATORS,
        })
    return rows


def main():
    F0_star = find_optimal_fee(OMEGA_MAX)
    F0_stress = F0_star * 1.2

    # Orden de consumo del RNG identico a fee_specification.py lineas 84-86.
    rng = np.random.default_rng(RNG_SEED)
    omegas = rng.uniform(OMEGA_MIN, OMEGA_MAX, size=N_VALIDATORS)
    norm_Ts = rng.uniform(0.0, 3.0, size=N_VALIDATORS)

    f0_grid = [F0_star * 0.5, F0_star * 0.8, F0_star, F0_star * 1.2]
    rows = build_rows(omegas, norm_Ts, f0_grid)

    # Igualdad exacta: lo impreso coincide con las expresiones crudas.
    for row in rows:
        assert row["gross_revenue"] == row["F0"] * row["N_VALIDATORS"], (
            "gross_revenue != f0 * N_VALIDATORS at {}".format(row["F0"]))
        assert row["net_revenue"] == row["F0"] * (row["N_VALIDATORS"] - row["n_excluded"]), (
            "net_revenue != f0 * (N_VALIDATORS - n_excluded) at {}".format(row["F0"]))
        assert row["viol_frac"] == row["n_excluded"] / row["N_VALIDATORS"], (
            "viol_frac != n_excluded / N_VALIDATORS at {}".format(row["F0"]))

    u_star = utilities_at(omegas, norm_Ts, F0_star)
    u_stress = utilities_at(omegas, norm_Ts, F0_stress)
    n_exc_star = (u_star < IR_TOL).sum()
    n_exc_stress = (u_stress < IR_TOL).sum()
    gross_stress = F0_stress * N_VALIDATORS
    net_stress = F0_stress * (N_VALIDATORS - n_exc_stress)

    print("=" * 78)
    print("FEE SPECIFICATION - GROSS VS NET REVENUE (finding C-08(b))")
    print("=" * 78)
    print()
    print("Parametros (mismos nombres y valores que fee_specification.py):")
    print("  N_VALIDATORS = {}".format(N_VALIDATORS))
    print("  omega ~ Uniforme[{}, {}]".format(OMEGA_MIN, OMEGA_MAX))
    print("  PI_VAL = {}, THETA = {}, VAR_TECH = {}".format(PI_VAL, THETA, VAR_TECH))
    print("  RNG_SEED = {}, tolerancia IR: U < {}".format(RNG_SEED, IR_TOL))
    print()
    print("Recaudacion por epoca segun el fee:")
    print("{:>8} {:>13} {:>11} {:>14} {:>13} {:>10}".format(
        "F0", "N_VALIDATORS", "n_excluded",
        "gross_revenue", "net_revenue", "viol_frac"))
    print("-" * 74)
    for row in rows:
        print("{:>8.4f} {:>13d} {:>11d} {:>14.2f} {:>13.2f} {:>10.4f}".format(
            row["F0"], row["N_VALIDATORS"], row["n_excluded"],
            row["gross_revenue"], row["net_revenue"], row["viol_frac"]))
    print()
    print("=" * 78)
    print("VERIFICACION")
    print("=" * 78)
    print()
    # Bloque de verificacion: etiqueta y valor alineados, referencia entre parentesis.
    f0_star_s = "{:.4f}".format(F0_star)
    f0_stress_s = "{:.4f}".format(F0_stress)
    u_min_star_s = "{:.6f}".format(u_star.min())
    u_min_stress_s = "{:.6f}".format(u_stress.min())
    n_exc_star_s = "{}".format(n_exc_star)
    n_exc_stress_s = "{}".format(n_exc_stress)
    gross_stress_s = "{:.2f}".format(gross_stress)
    net_stress_s = "{:.2f}".format(net_stress)

    print("{:<37} = {:<9} (esperado 0.0500)".format(
        "F0_star (find_optimal_fee)", f0_star_s))
    print("{:<37} = {:<9}".format(
        "F0 tensionado (1.2 * F0_star)", f0_stress_s))
    print("{:<37} = {:<9} (esperado 0.009747, identico al canonico)".format(
        "U min con F0 = F0_star", u_min_star_s))
    print("{:<37} = {:<9} (esperado negativo)".format(
        "U min con F0 = 1.2 * F0_star", u_min_stress_s))
    print("{:<37} = {:<9} (esperado 0)".format(
        "n_excluded con F0 = F0_star", n_exc_star_s))
    print("{:<37} = {:<9} (esperado 2)".format(
        "n_excluded con F0 = 1.2 * F0_star", n_exc_stress_s))
    print("{:<37} = {:<9} (esperado 60.00)".format(
        "gross_revenue con F0 = 1.2 * F0_star", gross_stress_s))
    print("{:<37} = {:<9} (esperado 59.88)".format(
        "net_revenue con F0 = 1.2 * F0_star", net_stress_s))
    print()

    # Igualdad exacta exigida por la especificacion de C-08(b).
    assert n_exc_star == 0, "n_excluded(F0_star) = {} (esperado 0)".format(n_exc_star)
    assert n_exc_stress == 2, "n_excluded(1.2 * F0_star) = {} (esperado 2)".format(n_exc_stress)
    assert u_stress.min() < 0.0, "U min(1.2 * F0_star) = {} no es negativo".format(u_stress.min())

    print("Todos los asserts pasaron (igualdad exacta, sin redondeo intermedio).")


if __name__ == "__main__":
    main()
