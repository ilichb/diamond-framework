#!/usr/bin/env python3
"""
simulate_data_layer_v3.py

Modelo corregido con equilibrio interior.
Equilibrio: n* = B / B* = p_fraud * B / c_audit (capped at N_VERIFIERS).

Asume: cada auditor revisa TODAS las attestations y compite por el bounty.
Cobertura de detección = 100% si n >= 1 (todos los fraudes son vistos).
"""

import numpy as np


N_ATTESTATIONS = 500
N_EPOCHS = 500
V_FRAUD = 1.0
S_SLASH = 10.0
C_AUDIT = 0.10
BETA_ADVERSARIAL = 0.2
P_FAKE_GIVEN_ADV = 0.5
N_VERIFIERS = 20
P_FRAUD = BETA_ADVERSARIAL * P_FAKE_GIVEN_ADV
B_STAR = C_AUDIT / P_FRAUD  # = 1.0
RNG_SEED = 42


def equilibrium_auditors(B):
    """n* = floor(B / B*), capped por N_VERIFIERS. IR débil: entrada permitida en B = B*."""
    if B < B_STAR:
        return 0
    n_star = int(B / B_STAR)  # floor, sin round()
    return min(n_star, N_VERIFIERS)


def simulate_scenario(B, n_epochs=N_EPOCHS, seed=RNG_SEED):
    rng = np.random.default_rng(seed)
    n_auditors = equilibrium_auditors(B)
    coverage = 1.0 if n_auditors >= 1 else 0.0

    frauds_list, detections_list = [], []
    attacker_profits, verifier_profits = [], []

    for _ in range(n_epochs):
        # Número de frauds en esta época
        n_adv = int(100 * BETA_ADVERSARIAL)
        n_honest = 100 - n_adv
        n_att_adv = N_ATTESTATIONS - int(N_ATTESTATIONS * n_honest / 100)
        n_frauds = rng.binomial(n_att_adv, P_FAKE_GIVEN_ADV)

        n_detections = rng.binomial(n_frauds, coverage)
        attacker_profit = (n_frauds - n_detections) * V_FRAUD - n_detections * S_SLASH

        if n_auditors > 0:
            # Ingreso esperado por auditor: p_fraud · N · B / n
            # Con n = n*, esto es N · c_audit por construcción
            total_revenue = n_detections * B
            total_cost = n_auditors * N_ATTESTATIONS * C_AUDIT
            verifier_profit = (total_revenue - total_cost) / n_auditors
        else:
            verifier_profit = 0.0

        frauds_list.append(n_frauds)
        detections_list.append(n_detections)
        attacker_profits.append(attacker_profit)
        verifier_profits.append(verifier_profit)

    frauds = np.array(frauds_list)
    detections = np.array(detections_list)
    integrity = (N_ATTESTATIONS - frauds + detections) / N_ATTESTATIONS

    return {
        "B": B,
        "n_auditors": n_auditors,
        "coverage": coverage,
        "frauds_mean": frauds.mean(),
        "detections_mean": detections.mean(),
        "detection_rate": detections.sum() / max(frauds.sum(), 1),
        "attacker_profit": np.mean(attacker_profits),
        "verifier_profit": np.mean(verifier_profits),
        "integrity": integrity.mean(),
    }


def main():
    print("=" * 78)
    print("CAPA DE DATOS v3 — EQUILIBRIO INTERIOR n* = B / B*")
    print("=" * 78)
    print()
    print(f"Parámetros: N_ATTESTATIONS={N_ATTESTATIONS}, C_AUDIT={C_AUDIT}")
    print(f"p_fraud={P_FRAUD:.2f}, B* = C_AUDIT / p_fraud = {B_STAR:.4f}")
    print(f"N_VERIFIERS cap = {N_VERIFIERS}")
    print()

    print(f"{'B':>6} {'n*':>5} {'Cob':>5} {'Fraude/ép':>10} "
          f"{'Detec/ép':>10} {'Tasa det':>10} {'Profit att':>11} "
          f"{'Profit ver':>11} {'Integridad':>11}")
    print("-" * 78)

    for B in [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 5.0, 10.0, 20.0, 25.0]:
        agg = simulate_scenario(B, n_epochs=500)
        print(f"{B:>6.2f} {agg['n_auditors']:>5d} {agg['coverage']:>5.2f} "
              f"{agg['frauds_mean']:>10.1f} {agg['detections_mean']:>10.1f} "
              f"{agg['detection_rate']:>10.3f} "
              f"{agg['attacker_profit']:>11.2f} "
              f"{agg['verifier_profit']:>11.2f} "
              f"{agg['integrity']:>11.4f}")

    print()
    print("=" * 78)
    print("NOTAS")
    print("=" * 78)
    print()
    print("1. El equilibrio n* = B / B* es interior para B ∈ (B*, 20·B*].")
    print("2. Para B < B*: sin auditores, sin detección.")
    print("3. Para B ≥ B*: al menos un auditor. Cobertura = 100%.")
    print("4. El profit del verificador es cercano a cero en equilibrio.")
    print("   Valores positivos residuales son artefactos de redondeo en n*.")
    print("5. La integridad es 1.0 siempre que n ≥ 1.")
    print()
    print("=" * 78)


if __name__ == "__main__":
    main()