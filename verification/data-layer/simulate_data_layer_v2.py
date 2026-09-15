#!/usr/bin/env python3
"""
simulate_data_layer_v2.py

Versión corregida del modelo de capa de datos con:
  - Cobertura dependiente del número de auditores: 1 - e^{-n_auditores}.
  - Verificación de la condición de participación individual (IR) del auditor.
  - Análisis de equilibrio más realista.
"""

import numpy as np


N_VALIDATORS = 100
N_ATTESTATIONS = 500
N_EPOCHS = 1000
V_FRAUD = 1.0
S_SLASH = 10.0
C_AUDIT_PER_ATTESTATION = 0.10
BETA_ADVERSARIAL = 0.2
P_FAKE_GIVEN_ADV = 0.5
N_VERIFIERS = 20

RNG_SEED = 42


def equilibrium_auditors(p_fraud, bounty, c_audit):
    """
    Encuentra el número de auditores en equilibrio por búsqueda de punto fijo.

    Cada auditor decide si auditar basándose en:
        E[revenue] = p_fraud · bounty · P(ganar carrera) − costo_individual
        P(ganar carrera) = 1 / n_auditores
        costo_individual = (n_attestations / n_auditores) · c_audit

    Un auditor entra si E[revenue] > 0, sale si E[revenue] < 0.
    Equilibrio: n_auditores tal que E[revenue] ≈ 0.
    """
    if p_fraud <= 0 or bounty <= 0 or c_audit <= 0:
        return 0

    # Si un solo auditor cubre todo, su costo es n_attestations · c_audit.
    # Ingreso esperado: p_fraud · n_attestations · bounty.
    # Condición IR con 1 auditor: p_fraud · n_attestations · bounty > n_attestations · c_audit
    #   <=>  p_fraud · bounty > c_audit
    #   <=>  bounty > c_audit / p_fraud = B*

    B_star = c_audit / p_fraud
    if bounty < B_star:
        return 0

    # Con múltiples auditores, la cobertura crece pero el beneficio individual cae.
    # Buscamos n tal que el beneficio individual sea aproximadamente cero.
    # Aproximación: cada auditor revisa n_attestations / n, pero la cobertura
    # efectiva del sistema es 1 - e^{-n}.
    # El ingreso esperado por auditor: p_fraud · n_attestations · bounty · coverage(n) / n
    # El costo por auditor: (n_attestations / n) · c_audit
    # Condición IR: p_fraud · bounty · coverage(n) > c_audit

    # Buscamos el n más grande que satisface IR (más auditores, misma cobertura)
    n_max = 0
    for n in range(1, N_VERIFIERS + 1):
        coverage = 1 - np.exp(-n)
        if p_fraud * bounty * coverage > c_audit:
            n_max = n
        else:
            break
    return n_max


def simulate_epoch(rng, bounty, p_fraud_observed, n_auditores):
    """Simula una época con n_auditores ya determinados."""
    n_adv = int(N_VALIDATORS * BETA_ADVERSARIAL)
    n_honest = N_VALIDATORS - n_adv
    n_att_honest = int(N_ATTESTATIONS * n_honest / N_VALIDATORS)
    n_att_adv = N_ATTESTATIONS - n_att_honest
    n_frauds = rng.binomial(n_att_adv, P_FAKE_GIVEN_ADV)
    n_honest_att = N_ATTESTATIONS - n_frauds

    # Cobertura dependiente del número de auditores
    if n_auditores > 0:
        coverage = 1 - np.exp(-n_auditores)
    else:
        coverage = 0.0

    n_detections = rng.binomial(n_frauds, coverage) if n_frauds > 0 else 0

    # Beneficios
    attacker_profit = (n_frauds - n_detections) * V_FRAUD - n_detections * S_SLASH

    if n_auditores > 0:
        total_bounty = n_detections * bounty
        total_cost = N_ATTESTATIONS * C_AUDIT_PER_ATTESTATION
        verifier_profit = (total_bounty - total_cost) / n_auditores
    else:
        verifier_profit = 0.0

    integrity = (n_honest_att + n_detections) / N_ATTESTATIONS

    return {
        "n_frauds": n_frauds,
        "n_detections": n_detections,
        "attacker_profit": attacker_profit,
        "verifier_profit": verifier_profit,
        "integrity": integrity,
        "n_auditores": n_auditores,
        "coverage": coverage,
    }


def simulate_scenario(bounty, n_epochs=N_EPOCHS, seed=RNG_SEED):
    rng = np.random.default_rng(seed)
    p_fraud = BETA_ADVERSARIAL * P_FAKE_GIVEN_ADV
    n_auditores = equilibrium_auditors(p_fraud, bounty, C_AUDIT_PER_ATTESTATION)

    records = [simulate_epoch(rng, bounty, p_fraud, n_auditores)
               for _ in range(n_epochs)]

    frauds = np.array([r["n_frauds"] for r in records])
    detections = np.array([r["n_detections"] for r in records])
    att_profit = np.array([r["attacker_profit"] for r in records])
    ver_profit = np.array([r["verifier_profit"] for r in records])
    integrity = np.array([r["integrity"] for r in records])
    coverage = records[0]["coverage"]

    return {
        "bounty": bounty,
        "n_auditores": n_auditores,
        "coverage": coverage,
        "frauds_mean": frauds.mean(),
        "detections_mean": detections.mean(),
        "detection_rate": detections.sum() / max(frauds.sum(), 1),
        "attacker_profit": att_profit.mean(),
        "verifier_profit": ver_profit.mean(),
        "integrity_mean": integrity.mean(),
    }


def main():
    print("=" * 78)
    print("SIMULACIÓN CAPA DE DATOS v2 — COBERTURA DEPENDIENTE DE AUDITORES")
    print("=" * 78)
    print()
    print(f"Parámetros: N_ATTESTATIONS={N_ATTESTATIONS}, "
          f"C_AUDIT={C_AUDIT_PER_ATTESTATION}, "
          f"p_fraud={BETA_ADVERSARIAL * P_FAKE_GIVEN_ADV:.2f}")
    print(f"B* teórico = C_AUDIT / p_fraud = "
          f"{C_AUDIT_PER_ATTESTATION / (BETA_ADVERSARIAL * P_FAKE_GIVEN_ADV):.4f}")
    print()

    print("Barrido de bounty:")
    print("-" * 78)
    print(f"{'B':>6} {'Audit':>6} {'Cob':>6} {'Fraude/ép':>10} "
          f"{'Detec/ép':>10} {'Tasa det':>10} {'Profit att':>11} "
          f"{'Profit ver':>11} {'Integridad':>11}")
    print("-" * 78)

    b_values = [0.0, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 5.0, 10.0]
    for b in b_values:
        agg = simulate_scenario(b, n_epochs=500, seed=42)
        print(f"{b:>6.2f} {agg['n_auditores']:>6d} {agg['coverage']:>6.3f} "
              f"{agg['frauds_mean']:>10.1f} {agg['detections_mean']:>10.1f} "
              f"{agg['detection_rate']:>10.3f} {agg['attacker_profit']:>11.2f} "
              f"{agg['verifier_profit']:>11.2f} {agg['integrity_mean']:>11.4f}")

    print()
    print("=" * 78)
    print("NOTAS")
    print("=" * 78)
    print()
    print("1. A diferencia del modelo v1, la cobertura crece con el número")
    print("   de auditores: coverage(n) = 1 - e^{-n}.")
    print("2. El equilibrio n_auditores se calcula por condición IR:")
    print("   p_fraud · bounty · coverage(n) > c_audit.")
    print("3. La detección se satura cuando coverage(n) → 1, no a 0.632.")
    print("4. El profit del verificador se reporta para diagnóstico; si es")
    print("   persistentemente negativo, el modelo tiene un problema.")
    print()
    print("=" * 78)


if __name__ == "__main__":
    main()