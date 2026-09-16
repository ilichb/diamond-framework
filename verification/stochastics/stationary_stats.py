#!/usr/bin/env python3
"""
stationary_stats.py — Propiedades estacionarias del proceso CIR.

Verifica numericamente las premisas analiticas de la Seccion 2.3:
  P8:  E[R_inf] = Rbar
  P9:  Var[R_inf] = sigma0^2 * Rbar / (2*alpha)
  P10: R0 = 2.2 es ~4.8 sigma sobre la media estacionaria

Distribucion estacionaria teorica:
  R_inf ~ Gamma(k, theta) con
    k = 2*alpha*Rbar / sigma0^2
    theta = sigma0^2 / (2*alpha)
  E[R_inf] = k*theta = Rbar
  Var[R_inf] = k*theta^2 = sigma0^2 * Rbar / (2*alpha)

Metodo:
  Simular CIR con Feller estricto durante T_long desde R(0)=Rbar.
  Descartar burn-in. Medir momentos empiricos.
  Comparar con teoria.
"""

import numpy as np

RNG_SEED = 42
N_PATHS = 50000
T_LONG = 50.0
DT = 0.01
BURN_IN = 0.5  # fraction to discard

SCENARIOS = [
    {"name": "Section 2.2 parameters", "alpha": 0.5, "rbar": 1.0, "sigma0": 0.8},
    {"name": "D4 analysis parameters", "alpha": 2.0, "rbar": 1.0, "sigma0": 0.5},
]


def simulate_cir_stationary(alpha, rbar, sigma0, T_long, dt, n_paths, seed):
    """Simula CIR desde R(0)=Rbar durante T_long. Retorna la serie completa."""
    rng = np.random.default_rng(seed)
    n_steps = int(T_long / dt)
    R = np.full(n_paths, rbar)
    sqrt_dt = np.sqrt(dt)
    R_history = np.empty((n_steps, n_paths))
    for step in range(n_steps):
        Z = rng.standard_normal(n_paths)
        R_pos = np.maximum(R, 0.0)
        R = R + alpha * (rbar - R) * dt + sigma0 * np.sqrt(R_pos) * sqrt_dt * Z
        R = np.maximum(R, 0.0)
        R_history[step] = R
    return R_history


def ks_2samp(a, b):
    """KS de dos muestras, versión estándar."""
    n1, n2 = len(a), len(b)
    a_s = np.sort(a)
    b_s = np.sort(b)
    grid = np.concatenate([a_s, b_s])
    Fa = np.searchsorted(a_s, grid, side="right") / n1
    Fb = np.searchsorted(b_s, grid, side="right") / n2
    D = np.max(np.abs(Fa - Fb))
    ne = n1 * n2 / (n1 + n2)
    lam = (np.sqrt(ne) + 0.12 + 0.11 / np.sqrt(ne)) * D
    p = 2 * sum((-1) ** (j - 1) * np.exp(-2 * j * j * lam * lam)
                for j in range(1, 101))
    return D, p


def main():
    print("=" * 78)
    print("STATIONARY STATS — CIR PROCESS")
    print("=" * 78)
    print()
    print(f"N_PATHS = {N_PATHS}, T_LONG = {T_LONG}, dt = {DT}, "
          f"burn-in = {BURN_IN*100:.0f}%")
    print()

    for i, sc in enumerate(SCENARIOS):
        alpha, rbar, sigma0 = sc["alpha"], sc["rbar"], sc["sigma0"]
        print(f"--- {sc['name']} ---")
        print(f"  alpha={alpha}, Rbar={rbar}, sigma0={sigma0}")
        print(f"  Feller: 2*alpha*Rbar = {2*alpha*rbar:.4f} >= "
              f"sigma0^2 = {sigma0**2:.4f} = {2*alpha*rbar >= sigma0**2}")

        # Theory
        k_theory = 2 * alpha * rbar / sigma0 ** 2
        theta_theory = sigma0 ** 2 / (2 * alpha)
        mean_theory = rbar
        var_theory = sigma0 ** 2 * rbar / (2 * alpha)
        std_theory = np.sqrt(var_theory)

        print(f"  Theory: R_inf ~ Gamma(k={k_theory:.4f}, theta={theta_theory:.4f})")
        print(f"    E[R_inf] = {mean_theory:.6f}")
        print(f"    Var[R_inf] = {var_theory:.6f}, std = {std_theory:.6f}")
        print()

        # Simulate
        R_hist = simulate_cir_stationary(alpha, rbar, sigma0, T_LONG, DT,
                                         N_PATHS, RNG_SEED + i)
        burn_steps = int(BURN_IN * R_hist.shape[0])
        R_stationary = R_hist[burn_steps:].flatten()

        mean_emp = R_stationary.mean()
        var_emp = R_stationary.var()
        std_emp = np.sqrt(var_emp)

        print(f"  Empirical (burn-in discarded):")
        print(f"    E[R_inf] = {mean_emp:.6f}  (|diff| = {abs(mean_emp-mean_theory):.6f}, "
              f"rel = {abs(mean_emp-mean_theory)/mean_theory*100:.3f}%)")
        print(f"    Var[R_inf] = {var_emp:.6f}  (|diff| = {abs(var_emp-var_theory):.6f}, "
              f"rel = {abs(var_emp-var_theory)/var_theory*100:.3f}%)")
        print(f"    std = {std_emp:.6f}")

        # Z-score of R0=2.2
        R0 = 2.2
        z_theory = (R0 - mean_theory) / std_theory
        z_emp = (R0 - mean_emp) / std_emp
        print()
        print(f"  Z-score of R0 = {R0}:")
        print(f"    Theory: {z_theory:.4f} sigma")
        print(f"    Empirical: {z_emp:.4f} sigma")

        # Kolmogorov-Smirnov vs Gamma
        # Muestreo: empirica (sin reemplazo) y Gamma teorica del mismo tamano
        rng_ks = np.random.default_rng(RNG_SEED + 100 + i)
        n_ks = min(len(R_stationary), 100000)
        sample_emp = rng_ks.choice(R_stationary, size=n_ks, replace=False)
        sample_theory = rng_ks.gamma(k_theory, theta_theory, size=n_ks)
        # NOTA: la rejilla "quantiles" que habia aqui se elimino; no se usaba y el
        # estadistico anterior (max|orden_emp - orden_teo|/std) no era un KS.
        # Ahora se usa el KS de dos muestras estandar, ks_2samp().
        D, p_ks = ks_2samp(sample_emp, sample_theory)
        print()
        print(f"  KS test vs Gamma(k, theta):")
        print(f"    KS statistic D: {D:.6f}")
        print(f"    p-value: {p_ks:.6f}")
        print(f"    Reject at 95%: {p_ks < 0.05}")
        print(f"    NOTE: samples are autocorrelated; p-value is indicative only.")
        print()

    print("=" * 78)
    print("CONCLUSION")
    print("=" * 78)
    print()
    print("  Si los momentos empiricos coinciden con la teoria y el KS test")
    print("  no rechaza, las premisas P8, P9, P10 estan verificadas.")
    print("  Si no coinciden, la ecuacion del CIR simulada o los parametros")
    print("  estan mal, y todos los analisis basados en ellos quedan en duda.")
    print()
    print("=" * 78)


if __name__ == "__main__":
    main()
