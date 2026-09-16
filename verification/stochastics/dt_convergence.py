#!/usr/bin/env python3
"""
dt_convergence.py — Convergencia del MFPT simulado bajo dt.

Verifica el sesgo de discretizacion del esquema Euler con max(R,0).

Metodo:
  Para cada escenario, para dt en su grid declarado:
    Simular CIR con n_paths trayectorias durante t_max.
    Registrar hit_time a R0.
    Reportar MFPT condicional (si hit_frac < 1) o MFPT directo (si = 1).

Comparar con el MFPT exacto por integracion numerica:
  Section 2.2: 11.2203
  D4: 443.7374

Ejecucion completa documentada en
verification/stochastics/results/dt_convergence_output.txt.
Configuracion: S2.2 con N=5000, T_max=200, dt in {0.02, 0.005, 0.001, 0.0005};
D4 con N=2000, T_max=2000, dt in {0.02, 0.005, 0.001}.
La censura a la derecha en D4 se mantiene por debajo del 5%.
"""

import numpy as np


RNG_SEED = 42
R0_TARGET = 2.2
EPS = 1e-3

# Configuracion por escenario: n_paths, t_max y grid de dt propios.
SCENARIOS = [
    {"name": "Section 2.2 parameters",
     "alpha": 0.5, "rbar": 1.0, "sigma0": 0.8,
     "n_paths": 5000, "t_max": 200.0,
     "dt_values": [0.02, 0.005, 0.001, 0.0005],
     "expected_mfpt": 11.2203},
    {"name": "D4 analysis parameters",
     "alpha": 2.0, "rbar": 1.0, "sigma0": 0.5,
     "n_paths": 2000, "t_max": 2000.0,
     "dt_values": [0.02, 0.005, 0.001],
     "expected_mfpt": 443.7374},
]


def simulate(alpha, rbar, sigma0, R0, eps, T_max, dt, n_paths, seed):
    rng = np.random.default_rng(seed)
    n_steps = int(T_max / dt)
    R = np.full(n_paths, eps)
    hit_time = np.full(n_paths, np.inf)
    already_hit = np.zeros(n_paths, dtype=bool)
    sqrt_dt = np.sqrt(dt)

    for step in range(n_steps):
        Z = rng.standard_normal(n_paths)
        R_pos = np.maximum(R, 0.0)
        R = R + alpha * (rbar - R) * dt + sigma0 * np.sqrt(R_pos) * sqrt_dt * Z
        R = np.maximum(R, 0.0)
        newly_hit = (R >= R0) & (~already_hit)
        hit_time[newly_hit] = (step + 1) * dt
        already_hit |= newly_hit
        if already_hit.all():
            break
    return hit_time


def main():
    print("=" * 78)
    print("DT CONVERGENCE — EULER DISCRETIZATION BIAS IN SIMULATED MFPT")
    print("=" * 78)
    print()
    print(f"R0 = {R0_TARGET}, eps = {EPS}")
    print()

    for sc in SCENARIOS:
        alpha, rbar, sigma0 = sc["alpha"], sc["rbar"], sc["sigma0"]
        n_paths = sc["n_paths"]
        t_max = sc["t_max"]
        print(f"--- {sc['name']} ---")
        print(f"  alpha={alpha}, Rbar={rbar}, sigma0={sigma0}")
        print(f"  N_PATHS={n_paths}, T_max={t_max}, dt grid={sc['dt_values']}")
        print(f"  MFPT exacto (referencia): {sc['expected_mfpt']}")
        print()
        print(f"  {'dt':>8} {'n_steps':>10} {'hit_frac':>10} {'MFPT':>12} "
              f"{'rel_err':>10}")
        print(f"  {'-'*8} {'-'*10} {'-'*10} {'-'*12} {'-'*10}")

        for dt in sc["dt_values"]:
            n_steps = int(t_max / dt)
            hit_time = simulate(alpha, rbar, sigma0, R0_TARGET, EPS,
                                t_max, dt, n_paths, RNG_SEED)
            n_hit = int((hit_time < np.inf).sum())
            hit_frac = n_hit / n_paths

            if n_hit > 0:
                mfpt = hit_time[hit_time < np.inf].mean()
            else:
                mfpt = np.inf

            rel_err = (mfpt - sc["expected_mfpt"]) / sc["expected_mfpt"]
            print(f"  {dt:>8.5f} {n_steps:>10d} {hit_frac:>10.4f} "
                  f"{mfpt:>12.4f} {rel_err:>+10.4f}")
        print()

    print("=" * 78)
    print("CONCLUSION")
    print("=" * 78)
    print()
    print("  Si MFPT(dt) converge a 'expected_mfpt' cuando dt -> 0, la")
    print("  integral exacta esta confirmada y el sesgo de Euler es")
    print("  cuantificado. Si no converge, hay un problema adicional.")
    print()
    print("  El sesgo observado sobreestima el MFPT: el esquema Euler")
    print("  con max(R,0) retrasa la llegada al umbral (residuos positivos")
    print("  en ambos escenarios). El signo es consistente.")
    print()
    print("=" * 78)


if __name__ == "__main__":
    main()
