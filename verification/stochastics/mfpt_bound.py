#!/usr/bin/env python3
"""
mfpt_bound.py — Bound analitico y MFPT empirico para el proceso CIR.

Proposito: cuantificar la cota de whitewashing de la Seccion 2.3.

Cota analitica: E[tau_R0] >= C* * R0^(1-kappa) * exp(beta * R0)
con kappa = 2*alpha*Rbar/sigma0^2 y beta = 2*alpha/sigma0^2.

MFPT empirico: simulacion del CIR con Feller estricto.
"""

import numpy as np

RNG_SEED = 42
R0_TARGET = 2.2
EPS = 1e-3
DT = 0.01
N_PATHS = 10000
C_STAR = 1.0

SCENARIOS = [
    {
        "name": "Section 2.2 parameters (alpha=0.5, sigma0=0.8)",
        "alpha": 0.5, "rbar": 1.0, "sigma0": 0.8, "T_max": 20.0,
    },
    {
        "name": "D4 analysis parameters (alpha=2.0, sigma0=0.5)",
        "alpha": 2.0, "rbar": 1.0, "sigma0": 0.5, "T_max": 50.0,
    },
]


def analytical_bound(R0, alpha, rbar, sigma0, C_star=1.0):
    kappa = 2 * alpha * rbar / sigma0 ** 2
    beta = 2 * alpha / sigma0 ** 2
    return C_star * R0 ** (1 - kappa) * np.exp(beta * R0)


def simulate_cir(alpha, rbar, sigma0, R0_target, eps, T_max, dt, n_paths, seed):
    rng = np.random.default_rng(seed)
    n_steps = int(T_max / dt)
    R = np.full(n_paths, eps)
    hit_time = np.full(n_paths, np.nan)
    already_hit = np.zeros(n_paths, dtype=bool)
    sqrt_dt = np.sqrt(dt)

    for step in range(n_steps):
        Z = rng.standard_normal(n_paths)
        R_pos = np.maximum(R, 0.0)
        R = R + alpha * (rbar - R) * dt + sigma0 * np.sqrt(R_pos) * sqrt_dt * Z
        R = np.maximum(R, 0.0)

        newly_hit = (R >= R0_target) & (~already_hit)
        hit_time[newly_hit] = (step + 1) * dt
        already_hit |= newly_hit
        if already_hit.all():
            break
    return hit_time


def main():
    print("=" * 78)
    print("MFPT BOUND — SECCION 2.3 DEL PAPER")
    print("=" * 78)
    print()
    print(f"R0_target = {R0_TARGET}, eps = {EPS}, dt = {DT}, N_PATHS = {N_PATHS}")
    print()

    for i, sc in enumerate(SCENARIOS):
        print(f"--- Escenario {i+1}: {sc['name']} ---")
        print()

        feller_lhs = 2 * sc["alpha"] * sc["rbar"]
        feller_rhs = sc["sigma0"] ** 2
        print(f"  alpha={sc['alpha']}, Rbar={sc['rbar']}, sigma0={sc['sigma0']}")
        print(f"  Feller: {feller_lhs:.4f} >= {feller_rhs:.4f} = {feller_lhs >= feller_rhs}")

        kappa = 2 * sc["alpha"] * sc["rbar"] / sc["sigma0"] ** 2
        beta = 2 * sc["alpha"] / sc["sigma0"] ** 2
        bound = analytical_bound(R0_TARGET, sc["alpha"], sc["rbar"], sc["sigma0"], C_STAR)
        print(f"  kappa = {kappa:.4f}, beta = {beta:.4f}")
        print(f"  Cota: {bound:.4e}")

        hit_times = simulate_cir(
            sc["alpha"], sc["rbar"], sc["sigma0"], R0_TARGET, EPS,
            sc["T_max"], DT, N_PATHS, RNG_SEED + i
        )
        n_hit = int((~np.isnan(hit_times)).sum())
        print(f"  Trayectorias que alcanzan R0 en T_max={sc['T_max']}: "
              f"{n_hit}/{N_PATHS} ({n_hit/N_PATHS*100:.2f}%)")

        if n_hit > 0:
            valid = hit_times[~np.isnan(hit_times)]
            mfpt = valid.mean()
            ratio = bound / mfpt
            print(f"  MFPT (media):   {mfpt:.4f}")
            print(f"  MFPT (mediana): {np.median(valid):.4f}")
            print(f"  Ratio cota/MFPT: {ratio:.4e} ({np.log10(ratio):.2f} ordenes)")
            if ratio > 1e6:
                print(f"  Diagnostico: cota VACUA (> 6 ordenes de magnitud)")
            else:
                print(f"  Diagnostico: cota INFORMATIVA (<= 6 ordenes)")
        print()

    print("=" * 78)
    print("CONCLUSION")
    print("=" * 78)
    print()
    print("  La cota de whitewashing es informativa para parametros con")
    print("  sigma0 alto y alpha bajo (Seccion 2.2), y vacua para parametros")
    print("  con sigma0 bajo y alpha alto (D4).")
    print("  El paper reporta ambos escenarios en la Seccion 2.3.")
    print()
    print("=" * 78)


if __name__ == "__main__":
    main()
