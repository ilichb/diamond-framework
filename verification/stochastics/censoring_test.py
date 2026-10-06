#!/usr/bin/env python3
"""
censoring_test.py — Valida si la cola del primer-paso del CIR es geometrica.

Motivacion: cuando T_max es menor que el MFPT verdadero, solo una fraccion
de trayectorias alcanza el objetivo. Estimar E[tau] por extrapolacion
requiere saber si P(tau > t) decae geometricamente.

Metodo:
  Simular CIR con T_max grande. Registrar el tiempo de primer paso a R0.
  Medir P(tau > k*T_0) para k = 1, 2, ..., K.
  Bajo decaimiento geometrico: P(tau > k*T_0) = P(tau > T_0)^k.
  Comparar la fraccion observada con la predicha.

Parametros:
  N_PATHS = 20000, T_0 = 50, K = 6 (T_max = 300), dt = 0.01
  R0_target = 2.2, eps = 1e-3

Escenarios:
  - Section 2.2 parameters (alpha=0.5, sigma0=0.8)
  - D4 analysis parameters (alpha=2.0, sigma0=0.5)
"""

import numpy as np

RNG_SEED = 42
N_PATHS = 20000
T_0 = 50.0
K = 6
T_MAX = T_0 * K
DT = 0.01
R0_TARGET = 2.2
EPS = 1e-3

SCENARIOS = [
    {"name": "Section 2.2 parameters", "alpha": 0.5, "rbar": 1.0, "sigma0": 0.8},
    {"name": "D4 analysis parameters", "alpha": 2.0, "rbar": 1.0, "sigma0": 0.5},
]


def simulate_cir_first_passage(alpha, rbar, sigma0, R0, eps, T_max, dt,
                                n_paths, seed):
    """Simula trayectorias y registra el tiempo de primer paso a R0.

    Retorna hit_time por trayectoria (inf si no alcanza).
    """
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
    print("CENSORING TEST — GEOMETRIC TAIL HYPOTHESIS FOR CIR FIRST-PASSAGE")
    print("=" * 78)
    print()
    print(f"N_PATHS = {N_PATHS}, T_0 = {T_0}, K = {K}, T_max = {T_MAX}, dt = {DT}")
    print(f"R0_target = {R0_TARGET}, eps = {EPS}")
    print()

    for i, sc in enumerate(SCENARIOS):
        alpha, rbar, sigma0 = sc["alpha"], sc["rbar"], sc["sigma0"]
        print(f"--- {sc['name']} ---")
        print(f"  alpha={alpha}, Rbar={rbar}, sigma0={sigma0}")
        print()

        hit_time = simulate_cir_first_passage(
            alpha, rbar, sigma0, R0_TARGET, EPS, T_MAX, DT, N_PATHS,
            RNG_SEED + i
        )

        n_hit_total = int((hit_time < np.inf).sum())
        print(f"  Trayectorias que alcanzan R0 en T_max={T_MAX}: "
              f"{n_hit_total}/{N_PATHS} ({n_hit_total/N_PATHS*100:.2f}%)")
        print()

        # Fraction censored at k*T_0
        print(f"  {'k':>4} {'T = k*T_0':>10} {'P(tau > T)':>12} "
              f"{'P_geo(T)':>12} {'E[count]':>12} {'ratio':>10}")
        print(f"  {'-'*4} {'-'*10} {'-'*12} {'-'*12} {'-'*12} {'-'*10}")

        # P(tau > T_0) is the empirical baseline for the geometric model
        p_survive_T0 = (hit_time > T_0).mean()
        print(f"  {1:>4} {T_0:>10.1f} {p_survive_T0:>12.6f} "
              f"{p_survive_T0:>12.6f} {N_PATHS*p_survive_T0:>12.2f} "
              f"{1.0:>10.4f}")

        for k in range(2, K + 1):
            T_k = k * T_0
            p_emp = (hit_time > T_k).mean()
            p_geo = p_survive_T0 ** k
            ratio = p_emp / p_geo if p_geo > 0 else np.inf
            expected_count = N_PATHS * p_geo
            print(f"  {k:>4} {T_k:>10.1f} {p_emp:>12.6f} "
                  f"{p_geo:>12.6f} {expected_count:>12.2f} {ratio:>10.4f}")

        # MFPT estimates
        finite_hits = hit_time[hit_time < np.inf]
        mfpt_cond = finite_hits.mean() if len(finite_hits) > 0 else np.inf

        # Trivial bound: E[tau] >= T_max * (1 - hit_fraction)
        hit_fraction = n_hit_total / N_PATHS
        trivial_bound = T_MAX * (1 - hit_fraction)

        # Geometric extrapolation: E[tau] if geometric with rate p_survive_T0.
        # No aplica sin censura: en ese caso el MFPT es directo.
        if hit_fraction < 1.0 and p_survive_T0 < 1 and p_survive_T0 > 0:
            mfpt_geo = T_0 / (1 - p_survive_T0)
        else:
            mfpt_geo = np.nan

        print()
        print(f"  MFPT (condicional sobre hits): {mfpt_cond:.4f}")
        if hit_fraction == 1.0:
            print(f"  MFPT directo (sin censura): {mfpt_cond:.4f}")
            print(f"  Extrapolacion no aplicable: no hay censura.")
        else:
            print(f"  Bound trivial E[tau] >= T_max*(1-hit_frac): {trivial_bound:.4f}")
            print(f"  Extrapolacion geometrica (sobreestima si la cola es "
                  f"sub-geometrica): {mfpt_geo:.4f}")
        print()

        # Geometricity check at each k
        # The ratio p_emp / p_geo should be ~1 for geometric tail.
        # Solo se computan ratios con conteo esperado suficiente (>= 10):
        # por debajo de eso la medida es piso de resolucion digital.
        ratios = []
        n_sufficient = 0
        for k in range(2, K + 1):
            T_k = k * T_0
            p_emp = (hit_time > T_k).mean()
            p_geo = p_survive_T0 ** k
            expected_count = N_PATHS * p_geo
            if expected_count >= 10:
                n_sufficient += 1
                ratios.append(p_emp / p_geo)
        if ratios:
            mean_ratio = np.mean(ratios)
            std_ratio = np.std(ratios)
            print(f"  Ratios p_emp/p_geo (k con E[count]>=10: {n_sufficient} de "
                  f"{K-1}): mean={mean_ratio:.4f}, std={std_ratio:.4f}")
            if abs(mean_ratio - 1.0) < 0.1 and std_ratio < 0.1:
                print(f"  Veredicto: cola aproximadamente geometrica. La "
                      f"extrapolacion T_0/(1-p)")
                print(f"  sobreestima el MFPT porque la cola es "
                      f"sub-geometrica (ratios < 1 en")
                print(f"  todas las ventanas medidas).")
            else:
                print(f"  Veredicto: cola NO geometrica (extrapolacion invalida)")
        else:
            print(f"  Veredicto: INSUFICIENTE — ningun k alcanza E[count] >= 10; "
                  f"la cola no es medible a esta resolucion (N_PATHS={N_PATHS}).")
        print()

    print("=" * 78)
    print("CONCLUSION")
    print("=" * 78)
    print()
    print("  Si la cola es geometrica: E[tau] ~ T_0/(1-p) es una estimacion")
    print("  valida y se puede usar para clasificar la cota como tight, ")
    print("  informativa, o vacua.")
    print()
    print("  Si la cola NO es geometrica (p_emp/p_geo != 1), la extrapolacion")
    print("  sobreestima o subestima E[tau], y solo tenemos el bound trivial")
    print("  E[tau] >= T_max*(1-hit_frac).")
    print()
    print("=" * 78)


if __name__ == "__main__":
    main()
