#!/usr/bin/env python3
"""
simulate_bootstrap.py — Bootstrap del protocolo híbrido desde génesis (R=0).

Pregunta: ¿se concentra la reputación en validadores tempranos, y cómo
mitigarlo?

Políticas:
  1. pure_pos: S_f = Θ siempre.
  2. hybrid_no_decay: S_f = max{VaR, Θ - α(t)·C_R(R)}, R persistente.
  3. hybrid_decay: igual, con R decayendo (half-life H).

Modelo de reputación: gain = k · activity · (1 - R), saturación en R=1.
Heterogeneidad de validadores vía activity ~ LogNormal(0, 0.5).
"""

import numpy as np


# Parámetros
N_EPOCHS = 500
N_MAX = 100
N_INIT = 10
ENTRY_RATE = 0.03
THETA = 1.0
VAR_TECH = 0.2
R_GAIN_BASE = 0.005
ALPHA_HALF_TIME = 100
DECAY_HALF_LIFE = 50
RNG_SEED = 42


def c_r(R):
    """C_R(R) = 0.8 · R/(1+R). Concava, saturante."""
    return 0.8 * R / (1.0 + R)


def alpha(t, policy):
    if policy == "pure_pos":
        return 0.0
    return min(1.0, t / (2.0 * ALPHA_HALF_TIME))


def simulate(policy, seed=RNG_SEED):
    rng = np.random.default_rng(seed)
    R = np.zeros(N_MAX)
    activity = np.zeros(N_MAX)
    active = np.zeros(N_MAX, dtype=bool)

    active[:N_INIT] = True
    activity[:N_INIT] = 1.0

    history = []
    for t in range(1, N_EPOCHS + 1):
        n_slots = N_MAX - int(active.sum())
        n_new = rng.binomial(n_slots, ENTRY_RATE)
        if n_new > 0:
            new_idx = np.where(~active)[0][:n_new]
            active[new_idx] = True
            activity[new_idx] = rng.lognormal(0.0, 0.5, size=n_new)

        gain = R_GAIN_BASE * activity * (1.0 - R) * active.astype(float)
        R = R + gain

        if policy == "hybrid_decay":
            decay = 0.5 ** (1.0 / DECAY_HALF_LIFE)
            R = R * decay

        R = np.clip(R, 0.0, 1.0)
        a = alpha(t, policy)

        active_R = R[active]
        s_f = np.maximum(VAR_TECH, THETA - a * c_r(active_R))

        sorted_R = np.sort(active_R)
        n = len(sorted_R)
        if sorted_R.sum() > 0:
            cum = np.cumsum(sorted_R)
            gini = (n + 1 - 2 * cum.sum() / cum[-1]) / n
        else:
            gini = 0.0
        top_10 = np.sort(active_R)[-10:].sum() / max(active_R.sum(), 1e-9)

        history.append({
            "t": t,
            "n": int(active.sum()),
            "alpha": a,
            "gini": gini,
            "top_10_share": top_10,
            "s_f_mean": s_f.mean(),
            "R_mean": active_R.mean(),
            "R_max": active_R.max(),
        })

    return history


def summarize(history, policy):
    final = history[-1]
    t_alpha_1 = next((h["t"] for h in history if h["alpha"] >= 1.0), N_EPOCHS)
    return {
        "policy": policy,
        "t_alpha_1": t_alpha_1,
        "gini_final": final["gini"],
        "top_10_final": final["top_10_share"],
        "n_final": final["n"],
        "s_f_final": final["s_f_mean"],
        "R_mean_final": final["R_mean"],
        "R_max_final": final["R_max"],
    }


def main():
    print("=" * 90)
    print("BOOTSTRAP DEL PROTOCOLO HÍBRIDO DESDE GÉNESIS (R=0)")
    print("=" * 90)
    print()
    print(f"N_EPOCHS={N_EPOCHS}, N_MAX={N_MAX}, N_INIT={N_INIT}, "
          f"ENTRY_RATE={ENTRY_RATE}")
    print(f"THETA={THETA}, VAR_TECH={VAR_TECH}, R_GAIN_BASE={R_GAIN_BASE}")
    print(f"ALPHA_HALF_TIME={ALPHA_HALF_TIME}, "
          f"DECAY_HALF_LIFE={DECAY_HALF_LIFE}")
    print()

    policies = ["pure_pos", "hybrid_no_decay", "hybrid_decay"]
    results = {}
    for policy in policies:
        print(f"Simulando: {policy}")
        hist = simulate(policy)
        results[policy] = summarize(hist, policy)

    print()
    print("=" * 90)
    print("MÉTRICAS FINALES")
    print("=" * 90)
    print(f"{'Política':<20} {'t(α=1)':>8} {'Gini':>8} {'Top10':>8} "
          f"{'N':>5} {'S_f med':>10} {'R med':>10} {'R max':>10}")
    print("-" * 90)
    for policy in policies:
        r = results[policy]
        print(f"{policy:<20} {r['t_alpha_1']:>8d} {r['gini_final']:>8.4f} "
              f"{r['top_10_final']:>8.4f} {r['n_final']:>5d} "
              f"{r['s_f_final']:>10.4f} {r['R_mean_final']:>10.4f} "
              f"{r['R_max_final']:>10.4f}")

    print()
    print("=" * 90)
    print("LECTURA ESPERADA")
    print("=" * 90)
    print()
    print("1. pure_pos: S_f = Θ durante todo el período. Sin reducción.")
    print()
    print("2. hybrid_no_decay: S_f cae con α(t). Gini de R crece con el")
    print("   tiempo porque validadores tempranos acumulan ventaja.")
    print()
    print("3. hybrid_decay: el decaimiento limita la acumulación. Gini")
    print("   final inferior a hybrid_no_decay. Trade-off: menor")
    print("   reducción de S_f porque R decae.")
    print()
    print("=" * 90)


if __name__ == "__main__":
    main()