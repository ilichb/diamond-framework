#!/usr/bin/env python3
"""
compare_reputation_models.py — Compara seis modelos de ganancia de reputación
bajo condiciones idénticas de entrada.

Objetivo: encontrar un modelo con heterogeneidad persistente que refleje
contribución real (activity), sin decaimiento global que deprima R.

Modelos:
  1. lineal:      k · a · (1-R)
  2. decreciente: k · a · (1-R)²
  3. net_gain:    k · a · (1-R) - μ · R
  4. michaelis:   k · a · (1-R) / (K + a)
  5. power:       k · a^γ · (1-R)
  6. threshold:   k · max(0, a - a_min) · (1-R)
"""

import numpy as np


# ------------------------------------------------------------------
# Parámetros
# ------------------------------------------------------------------
N_EPOCHS = 500
N_MAX = 100
N_INIT = 10
ENTRY_RATE = 0.03
THETA = 1.0
VAR_TECH = 0.2
R_GAIN_BASE = 0.01
ACTIVITY_SIGMA = 0.7        # dispersión de activity
ACTIVITY_PERSISTENCE = 0.95 # autocorrelación de activity entre épocas

# Parámetros específicos de cada modelo
MU_NET = 0.05               # costo de mantenimiento en net_gain
K_MICHAELIS = 1.0           # constante de saturación en michaelis
GAMMA_POWER = 0.5           # exponente en power
A_MIN_THRESHOLD = 0.5       # umbral mínimo en threshold

RNG_SEED = 42


# ------------------------------------------------------------------
# Utilidades
# ------------------------------------------------------------------
def gini(x):
    """Coeficiente de Gini de un array no negativo."""
    if len(x) == 0 or x.sum() == 0:
        return 0.0
    x_sorted = np.sort(x)
    n = len(x_sorted)
    cum = np.cumsum(x_sorted)
    return (n + 1 - 2 * cum.sum() / cum[-1]) / n


def c_r(R):
    """C_R(R) = 0.8 · R/(1+R). Concava, saturante."""
    return 0.8 * R / (1.0 + R)


# ------------------------------------------------------------------
# Modelos de ganancia
# ------------------------------------------------------------------
def gain_lineal(R, a, active):
    return R_GAIN_BASE * a * (1.0 - R) * active


def gain_decreciente(R, a, active):
    return R_GAIN_BASE * a * (1.0 - R) ** 2 * active


def gain_net_gain(R, a, active):
    return (R_GAIN_BASE * a * (1.0 - R) - MU_NET * R) * active


def gain_michaelis(R, a, active):
    return R_GAIN_BASE * a * (1.0 - R) / (K_MICHAELIS + a) * active


def gain_power(R, a, active):
    return R_GAIN_BASE * (a ** GAMMA_POWER) * (1.0 - R) * active


def gain_threshold(R, a, active):
    effective_a = np.maximum(0.0, a - A_MIN_THRESHOLD)
    return R_GAIN_BASE * effective_a * (1.0 - R) * active


GAIN_FUNCTIONS = {
    "lineal": gain_lineal,
    "decreciente": gain_decreciente,
    "net_gain": gain_net_gain,
    "michaelis": gain_michaelis,
    "power": gain_power,
    "threshold": gain_threshold,
}


# ------------------------------------------------------------------
# Simulación
# ------------------------------------------------------------------
def simulate(model_name, seed=RNG_SEED):
    rng = np.random.default_rng(seed)
    gain_fn = GAIN_FUNCTIONS[model_name]

    R = np.zeros(N_MAX)
    activity = np.zeros(N_MAX)
    active = np.zeros(N_MAX, dtype=bool)

    active[:N_INIT] = True
    activity[:N_INIT] = rng.lognormal(0.0, ACTIVITY_SIGMA, size=N_INIT)

    for t in range(1, N_EPOCHS + 1):
        # Entrada de nuevos validadores
        n_slots = N_MAX - int(active.sum())
        n_new = rng.binomial(n_slots, ENTRY_RATE)
        if n_new > 0:
            new_idx = np.where(~active)[0][:n_new]
            active[new_idx] = True
            activity[new_idx] = rng.lognormal(0.0, ACTIVITY_SIGMA, size=n_new)

        # Evolución de activity (AR(1) en log-espacio, persistente)
        log_a = np.log(np.maximum(activity, 1e-9))
        noise = rng.normal(0.0, 0.1, size=N_MAX)
        log_a = ACTIVITY_PERSISTENCE * log_a + noise
        # Solo actualizar los activos
        activity_new = np.exp(log_a)
        activity = np.where(active, activity_new, activity)

        # Ganancia de reputación
        delta_R = gain_fn(R, activity, active.astype(float))
        R = R + delta_R
        R = np.clip(R, 0.0, 1.0)

    # Métricas finales
    active_R = R[active]
    active_a = activity[active]

    if active_R.sum() > 0:
        # Correlación entre activity y R final
        corr = np.corrcoef(active_a, active_R)[0, 1]
    else:
        corr = 0.0

    s_f = np.maximum(VAR_TECH, THETA - c_r(active_R))

    return {
        "model": model_name,
        "R_mean": active_R.mean(),
        "R_median": np.median(active_R),
        "R_std": active_R.std(),
        "R_max": active_R.max(),
        "R_min": active_R.min(),
        "gini": gini(active_R),
        "top_10_share": np.sort(active_R)[-10:].sum() / max(active_R.sum(), 1e-9),
        "s_f_median": np.median(s_f),
        "s_f_reduction": 1.0 - np.median(s_f) / THETA,
        "corr_activity_R": corr,
    }


# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------
def main():
    print("=" * 100)
    print("COMPARACIÓN DE MODELOS DE REPUTACIÓN")
    print("=" * 100)
    print()
    print(f"N_EPOCHS={N_EPOCHS}, N_MAX={N_MAX}, N_INIT={N_INIT}")
    print(f"R_GAIN_BASE={R_GAIN_BASE}, ACTIVITY_SIGMA={ACTIVITY_SIGMA}")
    print(f"Parámetros específicos: MU_NET={MU_NET}, K_MICHAELIS={K_MICHAELIS}, "
          f"GAMMA_POWER={GAMMA_POWER}, A_MIN_THRESHOLD={A_MIN_THRESHOLD}")
    print()

    models = list(GAIN_FUNCTIONS.keys())
    results = [simulate(m) for m in models]

    print("=" * 100)
    print("MÉTRICAS FINALES")
    print("=" * 100)
    print(f"{'Modelo':<14} {'R_mean':>8} {'R_med':>8} {'R_std':>8} "
          f"{'R_max':>8} {'Gini':>8} {'Top10':>8} "
          f"{'S_f_med':>9} {'S_f_red':>8} {'corr(a,R)':>10}")
    print("-" * 100)
    for r in results:
        print(f"{r['model']:<14} {r['R_mean']:>8.4f} {r['R_median']:>8.4f} "
              f"{r['R_std']:>8.4f} {r['R_max']:>8.4f} "
              f"{r['gini']:>8.4f} {r['top_10_share']:>8.4f} "
              f"{r['s_f_median']:>9.4f} {r['s_f_reduction']:>8.4f} "
              f"{r['corr_activity_R']:>10.4f}")

    print()
    print("=" * 100)
    print("CRITERIOS DE SELECCIÓN")
    print("=" * 100)
    print()
    print("Un modelo es adecuado si cumple simultáneamente:")
    print("  1. Heterogeneidad persistente:  R_std > 0.05")
    print("  2. Sin captura:                 Gini < 0.30")
    print("  3. Reducción de stake real:     S_f_reduction > 0.10")
    print("  4. Reputación refleja contribución: corr(a,R) > 0.5")
    print()

    print("=" * 100)
    print("VEREDICTO POR MODELO")
    print("=" * 100)
    for r in results:
        c1 = r["R_std"] > 0.05
        c2 = r["gini"] < 0.30
        c3 = r["s_f_reduction"] > 0.10
        c4 = r["corr_activity_R"] > 0.5
        passes = sum([c1, c2, c3, c4])
        verdict = ["FAIL", "WEAK", "PARTIAL", "GOOD", "EXCELLENT"][passes]
        print(f"  {r['model']:<14} "
              f"het={'Y' if c1 else 'N'} "
              f"capture={'Y' if c2 else 'N'} "
              f"reduction={'Y' if c3 else 'N'} "
              f"corr={'Y' if c4 else 'N'}  "
              f"→ {verdict} ({passes}/4)")

    print()
    print("=" * 100)
    print("LECTURA ESPERADA")
    print("=" * 100)
    print()
    print("1. Modelos lineales (lineal, decreciente, power, threshold):")
    print("   R converge a 1 para todos. R_std ≈ 0, Gini ≈ 0, correlación baja.")
    print("   No producen heterogeneidad. La reputación no discrimina.")
    print()
    print("2. Modelos con estado estacionario (net_gain, michaelis):")
    print("   R* depende de activity. R_std > 0, Gini > 0,")
    print("   correlación alta con activity. La reputación discrimina.")
    print()
    print("3. Criterio de diseño:")
    print("   El modelo debe tener un estado estacionario que dependa")
    print("   de la contribución, no un límite universal.")
    print()
    print("=" * 100)


if __name__ == "__main__":
    main()