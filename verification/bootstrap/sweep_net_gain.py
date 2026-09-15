#!/usr/bin/env python3
"""
sweep_net_gain.py — Barrido de mu y g para el modelo net_gain.

Modelo: R' = g * a * (1-R) - mu * R
Estado estacionario: R* = g*a / (g*a + mu)

Objetivo: encontrar (g, mu) que maximicen R_std sujeto a:
  - R_mean > 0.30 (evitar colapso)
  - Gini < 0.30 (evitar captura)
  - S_f_reduction > 0.15 (reduccion de stake util)
  - corr(a, R) > 0.5 (discriminacion por contribucion)

Nota sobre direccion: aumentar mu reduce R* y reduce dispersion.
La direccion correcta para maximizar R_std es DISMINUIR mu hacia
mu/g = 1, donde la sensibilidad a la actividad es maxima.

Parametros por defecto:
  - g = 0.01
  - mu in {0.002, 0.005, 0.008, 0.010, 0.015, 0.020, 0.030, 0.050, 0.100}
  - N_SEEDS = 5 (promedio sobre 5 semillas para robustez)
"""

import numpy as np


N_EPOCHS = 500
N_MAX = 100
N_INIT = 10
ENTRY_RATE = 0.03
THETA = 1.0
VAR_TECH = 0.2
ACTIVITY_SIGMA = 0.7
ACTIVITY_PERSISTENCE = 0.95
RNG_SEED = 42
N_SEEDS = 5


def gini(x):
    if len(x) == 0 or x.sum() == 0:
        return 0.0
    x_sorted = np.sort(x)
    n = len(x_sorted)
    cum = np.cumsum(x_sorted)
    return (n + 1 - 2 * cum.sum() / cum[-1]) / n


def c_r(R):
    return 0.8 * R / (1.0 + R)


def simulate(g, mu, seed):
    rng = np.random.default_rng(seed)
    R = np.zeros(N_MAX)
    activity = np.zeros(N_MAX)
    active = np.zeros(N_MAX, dtype=bool)

    active[:N_INIT] = True
    activity[:N_INIT] = rng.lognormal(0.0, ACTIVITY_SIGMA, size=N_INIT)

    for t in range(1, N_EPOCHS + 1):
        n_slots = N_MAX - int(active.sum())
        n_new = rng.binomial(n_slots, ENTRY_RATE)
        if n_new > 0:
            new_idx = np.where(~active)[0][:n_new]
            active[new_idx] = True
            activity[new_idx] = rng.lognormal(0.0, ACTIVITY_SIGMA, size=n_new)

        log_a = np.log(np.maximum(activity, 1e-9))
        noise = rng.normal(0.0, 0.1, size=N_MAX)
        log_a = ACTIVITY_PERSISTENCE * log_a + noise
        activity = np.where(active, np.exp(log_a), activity)

        delta_R = (g * activity * (1.0 - R) - mu * R) * active.astype(float)
        R = np.clip(R + delta_R, 0.0, 1.0)

    active_R = R[active]
    active_a = activity[active]

    if active_R.sum() > 0 and active_R.std() > 0:
        corr = np.corrcoef(active_a, active_R)[0, 1]
    else:
        corr = 0.0

    s_f = np.maximum(VAR_TECH, THETA - c_r(active_R))

    return {
        "R_mean": active_R.mean(),
        "R_median": np.median(active_R),
        "R_std": active_R.std(),
        "gini": gini(active_R),
        "s_f_median": np.median(s_f),
        "s_f_reduction": 1.0 - np.median(s_f) / THETA,
        "corr": corr,
    }


def aggregate(g, mu):
    results = [simulate(g, mu, RNG_SEED + i) for i in range(N_SEEDS)]
    keys = results[0].keys()
    return {k: np.mean([r[k] for r in results]) for k in keys}


def main():
    print("=" * 100)
    print("BARRIDO DE MU PARA NET_GAIN (con g fijo = 0.01)")
    print("=" * 100)
    print()
    print(f"N_SEEDS={N_SEEDS}, N_EPOCHS={N_EPOCHS}, ACTIVITY_SIGMA={ACTIVITY_SIGMA}")
    print()

    g = 0.01
    mu_values = [0.002, 0.005, 0.008, 0.010, 0.015, 0.020, 0.030, 0.050, 0.100]

    print(f"{'mu':>7} {'mu/g':>6} {'R_mean':>8} {'R_std':>8} {'Gini':>8} "
          f"{'S_f_red':>8} {'corr':>8} {'Score':>6}")
    print("-" * 100)

    best = None
    for mu in mu_values:
        r = aggregate(g, mu)
        c1 = r["R_mean"] > 0.30
        c2 = r["gini"] < 0.30
        c3 = r["s_f_reduction"] > 0.15
        c4 = r["corr"] > 0.5
        score = sum([c1, c2, c3, c4])
        objective = r["R_std"] if score == 4 else -1

        print(f"{mu:>7.3f} {mu/g:>6.2f} {r['R_mean']:>8.4f} {r['R_std']:>8.4f} "
              f"{r['gini']:>8.4f} {r['s_f_reduction']:>8.4f} "
              f"{r['corr']:>8.4f} {score:>6d}")

        if best is None or objective > best[1]:
            best = (mu, objective, r)

    print()
    print("=" * 100)
    print("MEJOR CONFIGURACION (maximiza R_std con score=4/4)")
    print("=" * 100)
    if best and best[1] >= 0:
        mu, _, r = best
        print(f"  mu = {mu:.3f}  (mu/g = {mu/g:.2f})")
        print(f"  R_mean = {r['R_mean']:.4f}")
        print(f"  R_std  = {r['R_std']:.4f}")
        print(f"  Gini   = {r['gini']:.4f}")
        print(f"  S_f_reduction = {r['s_f_reduction']:.4f}")
        print(f"  corr(a, R) = {r['corr']:.4f}")
    else:
        print("  Ninguna configuracion del barrido satisface los 4 criterios.")
        print("  Hay que relajar algun criterio o ampliar el barrido.")

    print()
    print("=" * 100)
    print("BARRIDO DE g (con mu = 0.01)")
    print("=" * 100)
    print()

    mu_fixed = 0.010
    g_values = [0.002, 0.005, 0.010, 0.020, 0.050]

    best_g = None

    print(f"{'g':>7} {'mu/g':>6} {'R_mean':>8} {'R_std':>8} {'Gini':>8} "
          f"{'S_f_red':>8} {'corr':>8} {'Score':>6}")
    print("-" * 100)

    for g_test in g_values:
        r = aggregate(g_test, mu_fixed)
        c1 = r["R_mean"] > 0.30
        c2 = r["gini"] < 0.30
        c3 = r["s_f_reduction"] > 0.15
        c4 = r["corr"] > 0.5
        score = sum([c1, c2, c3, c4])
        print(f"{g_test:>7.3f} {mu_fixed/g_test:>6.2f} {r['R_mean']:>8.4f} "
              f"{r['R_std']:>8.4f} {r['gini']:>8.4f} "
              f"{r['s_f_reduction']:>8.4f} {r['corr']:>8.4f} {score:>6d}")

        objective = r["R_std"] if score == 4 else -1
        if best_g is None or objective > best_g[1]:
            best_g = (g_test, objective, r)

    print()
    print("=" * 100)
    print("MEJOR CONFIGURACION DE g (maximiza R_std con score=4/4)")
    print("=" * 100)
    if best_g and best_g[1] >= 0:
        g_best, _, r = best_g
        print(f"  g = {g_best:.3f}  (mu/g = {mu_fixed/g_best:.2f})")
        print(f"  R_mean = {r['R_mean']:.4f}")
        print(f"  R_std  = {r['R_std']:.4f}")
        print(f"  Gini   = {r['gini']:.4f}")
        print(f"  S_f_reduction = {r['s_f_reduction']:.4f}")
        print(f"  corr(a, R) = {r['corr']:.4f}")
    else:
        print("  Ninguna configuracion del barrido satisface los 4 criterios.")
        print("  Hay que relajar algun criterio o ampliar el barrido.")

    print()
    print("=" * 100)


if __name__ == "__main__":
    main()
