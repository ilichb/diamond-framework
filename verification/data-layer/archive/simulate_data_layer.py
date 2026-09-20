#!/usr/bin/env python3
"""
[LEGACY — superseded by simulate_data_layer_v3.py]
simulate_data_layer.py

Simula el equilibrio de incentivos del mecanismo de fraud proofs para la
capa de datos del Diamond Framework (Sección 7).

Modelo:
  - N_VALIDATORS validadores en la cadena fuente.
  - Fracción β adversarial.
  - Cada época: N_ATTESTATIONS attestations producidas.
  - Verificadores deciden auditar basándose en el valor esperado.
  - Si fraude encontrado: bounty B al reportero, slashing S al atacante.
  - Frescura: variación entre épocas limitada a γ.

Economía:
  - Atacante maximiza: (1 - p_detect) · V_fraud - p_detect · S
  - Verificador maximiza: p_fraud · B · P(ganar carrera) - C_audit

Salida:
  - Tabla de escenarios con bounty variable.
  - Umbral de indiferencia B*.
  - Barrido de sensibilidad sobre B.
  - Efecto de la frescura γ sobre la integridad.
"""

import numpy as np


# ------------------------------------------------------------------
# Parámetros del sistema
# ------------------------------------------------------------------
N_VALIDATORS = 100
N_ATTESTATIONS = 500
N_EPOCHS = 1000

# Parámetros económicos (unidades adimensionales)
V_FRAUD = 1.0           # valor de una attestation fraudulenta exitosa
S_SLASH = 10.0          # slashing por fraude confirmado
C_AUDIT = 0.1           # costo de auditar una attestation
BETA_ADVERSARIAL = 0.2  # fracción de validadores adversariales
P_FAKE_GIVEN_ADV = 0.5  # prob de que un adversario emita fake

# Verificadores
N_VERIFIERS = 20        # verificadores potenciales

# Frescura
GAMMA = 0.1             # max variación de T entre épocas

RNG_SEED = 42


# ------------------------------------------------------------------
# Simulación de una época
# ------------------------------------------------------------------
def simulate_epoch(rng, b_bounty, s_slash, c_audit,
                    n_validators=N_VALIDATORS,
                    n_attestations=N_ATTESTATIONS,
                    beta_adv=BETA_ADVERSARIAL,
                    p_fake=P_FAKE_GIVEN_ADV,
                    n_verifiers=N_VERIFIERS):
    """
    Simula una época. Retorna métricas de esa época.
    """
    # Número de validadores adversariales y honestos
    n_adv = int(n_validators * beta_adv)
    n_honest = n_validators - n_adv

    # Attestations producidas
    n_att_honest = int(n_attestations * n_honest / n_validators)
    n_att_adv = n_attestations - n_att_honest

    # Fakes producidos
    n_frauds = rng.binomial(n_att_adv, p_fake)
    n_honest_att = n_attestations - n_frauds

    # p_fraud observado en esta época
    p_fraud = n_frauds / n_attestations if n_attestations > 0 else 0.0

    # Decisión de auditoría
    # Cada verificador audita con probabilidad p_audit. El valor esperado
    # por auditoría es: p_fraud · B · P(ganar carrera) - C_audit.
    # P(ganar carrera) = 1/N_auditores_activos (aproximación).
    # En equilibrio, se cumple: p_fraud · B / n_auditores = C_audit.
    # Despejando n_auditores: n_auditores = p_fraud · B / C_audit.
    if c_audit > 0 and p_fraud > 0:
        n_auditores_eq = p_fraud * b_bounty / c_audit
        n_auditores = min(int(round(n_auditores_eq)), n_verifiers)
        n_auditores = max(n_auditores, 0)
    else:
        n_auditores = 0

    # Cobertura de auditoría
    if n_auditores > 0:
        # Cada auditor revisa n_attestations / n_auditores attestations.
        # La probabilidad de cubrir cada fraude es (1 - (1 - k/n)^n_auditores)
        # con k = n / n_auditores. Aproximación: cobertura = 1 - e^(-1) ≈ 0.632.
        coverage = 1 - np.exp(-1)
    else:
        coverage = 0.0

    n_detections = rng.binomial(n_frauds, coverage) if n_frauds > 0 else 0

    # Beneficios
    attacker_profit = (n_frauds - n_detections) * V_FRAUD - n_detections * s_slash

    if n_auditores > 0:
        total_bounty = n_detections * b_bounty
        total_cost = n_auditores * (n_attestations / max(n_auditores, 1)) * c_audit
        verifier_profit = (total_bounty - total_cost) / n_auditores
    else:
        verifier_profit = 0.0

    # Integridad: fracción de attestations válidas en T
    integrity = (n_honest_att + n_detections) / n_attestations

    return {
        "n_frauds": n_frauds,
        "n_detections": n_detections,
        "attacker_profit": attacker_profit,
        "verifier_profit": verifier_profit,
        "integrity": integrity,
        "n_auditores": n_auditores,
    }


# ------------------------------------------------------------------
# Simulación de un escenario
# ------------------------------------------------------------------
def simulate_scenario(b_bounty, n_epochs=N_EPOCHS, seed=RNG_SEED):
    rng = np.random.default_rng(seed)
    records = [simulate_epoch(rng, b_bounty, S_SLASH, C_AUDIT)
               for _ in range(n_epochs)]

    frauds = np.array([r["n_frauds"] for r in records])
    detections = np.array([r["n_detections"] for r in records])
    att_profit = np.array([r["attacker_profit"] for r in records])
    ver_profit = np.array([r["verifier_profit"] for r in records])
    integrity = np.array([r["integrity"] for r in records])
    auditors = np.array([r["n_auditores"] for r in records])

    return {
        "frauds_mean": frauds.mean(),
        "detections_mean": detections.mean(),
        "detection_rate": detections.sum() / max(frauds.sum(), 1),
        "attacker_profit": att_profit.mean(),
        "verifier_profit": ver_profit.mean(),
        "integrity_mean": integrity.mean(),
        "auditors_mean": auditors.mean(),
    }


# ------------------------------------------------------------------
# Bounty de indiferencia
# ------------------------------------------------------------------
def find_B_star():
    """
    B* tal que el verificador es indiferente:
    p_fraud · B* / n_auditores = C_audit con n_auditores = 1 (un solo auditor).
    Simplificación: B* = C_audit / p_fraud.
    """
    p_fraud = BETA_ADVERSARIAL * P_FAKE_GIVEN_ADV
    return C_AUDIT / p_fraud


# ------------------------------------------------------------------
# Barrido de sensibilidad
# ------------------------------------------------------------------
def sensitivity_sweep():
    b_values = np.linspace(0.0, 3.0, 13)
    print("Barrido de sensibilidad sobre B:")
    print("-" * 78)
    print(f"{'B':>6} {'Fraude/ép':>11} {'Detec/ép':>10} {'Tasa det':>10} "
          f"{'Auditores':>10} {'Profit att':>11} {'Integridad':>11}")
    print("-" * 78)
    for b in b_values:
        agg = simulate_scenario(b, n_epochs=200, seed=42)
        print(f"{b:>6.2f} {agg['frauds_mean']:>11.1f} "
              f"{agg['detections_mean']:>10.1f} "
              f"{agg['detection_rate']:>10.3f} "
              f"{agg['auditors_mean']:>10.2f} "
              f"{agg['attacker_profit']:>11.2f} "
              f"{agg['integrity_mean']:>11.4f}")


# ------------------------------------------------------------------
# Efecto de la frescura
# ------------------------------------------------------------------
def freshness_analysis():
    """
    Modela cómo la frescura γ limita el daño de fraude no detectado.
    Si la variación entre épocas se limita a γ, un atacante que inyecta
    fraude en época t no puede propagarlo más allá de γ por época.
    """
    print()
    print("Efecto de la frescura γ sobre la propagación de fraude:")
    print("-" * 78)
    print(f"{'γ':>6} {'Épocas para 50%':>18} {'Épocas para 90%':>18} "
          f"{'Fracción residual':>18}")
    print("-" * 78)

    p_fraud = BETA_ADVERSARIAL * P_FAKE_GIVEN_ADV
    for gamma in [0.01, 0.05, 0.1, 0.2, 0.5]:
        # Aproximación: el fraude decae exponencialmente con γ por época.
        # Fracción residual después de t épocas: (1-γ)^t
        # t_50: (1-γ)^t = 0.5 → t = log(0.5)/log(1-γ)
        if gamma < 1:
            t_50 = np.log(0.5) / np.log(1 - gamma)
            t_90 = np.log(0.1) / np.log(1 - gamma)
        else:
            t_50 = 1
            t_90 = 1
        residual = (1 - gamma) ** 10  # después de 10 épocas
        print(f"{gamma:>6.2f} {t_50:>18.2f} {t_90:>18.2f} {residual:>18.6f}")


# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------
def main():
    print("=" * 78)
    print("SIMULACIÓN DE LA CAPA DE DATOS — EQUILIBRIO DE INCENTIVOS")
    print("=" * 78)
    print()

    print("Parámetros:")
    print(f"  N_VALIDATORS         = {N_VALIDATORS}")
    print(f"  N_ATTESTATIONS/epoch = {N_ATTESTATIONS}")
    print(f"  N_EPOCHS             = {N_EPOCHS}")
    print(f"  N_VERIFIERS          = {N_VERIFIERS}")
    print(f"  β adversarial        = {BETA_ADVERSARIAL}")
    print(f"  P(fake|adversarial)  = {P_FAKE_GIVEN_ADV}")
    print(f"  V_FRAUD              = {V_FRAUD}")
    print(f"  S_SLASH              = {S_SLASH}")
    print(f"  C_AUDIT              = {C_AUDIT}")
    print()

    B_star = find_B_star()
    print(f"Bounty de indiferencia B* = C_AUDIT / (β·p_fake) = {B_star:.4f}")
    print()

    print("Escenarios:")
    print("-" * 78)
    print(f"{'Escenario':<26} {'Fraude/ép':>10} {'Detec/ép':>10} "
          f"{'Tasa det':>10} {'Profit att':>11} {'Integridad':>11}")
    print("-" * 78)

    scenarios = [
        ("Sin bounty (B=0)", 0.0),
        ("B bajo (B=0.25)", 0.25),
        ("B óptimo (B*)", B_star),
        ("B medio (B=1.0)", 1.0),
        ("B alto (B=2.0)", 2.0),
        ("B excesivo (B=10)", 10.0),
    ]

    for name, b in scenarios:
        agg = simulate_scenario(b)
        print(f"{name:<26} {agg['frauds_mean']:>10.1f} "
              f"{agg['detections_mean']:>10.1f} "
              f"{agg['detection_rate']:>10.3f} "
              f"{agg['attacker_profit']:>11.2f} "
              f"{agg['integrity_mean']:>11.4f}")

    print()
    sensitivity_sweep()
    freshness_analysis()

    print()
    print("=" * 78)
    print("LECTURA DE RESULTADOS")
    print("=" * 78)
    print()
    print("1. El umbral B* = C_AUDIT / p_fraud marca la frontera entre")
    print("   'nadie audita' y 'al menos un auditor está dispuesto'.")
    print()
    print("2. Para B < B*, la detección es nula y el atacante opera sin")
    print("   riesgo. Para B ≈ B*, la detección empieza a activarse.")
    print()
    print("3. Para B >> B*, múltiples verificadores compiten por el mismo")
    print("   bounty, y el beneficio individual se diluye. Este es el")
    print("   problema de la carrera (race), análogo al de los MEV bots.")
    print()
    print("4. La frescura γ actúa como segunda línea de defensa: incluso")
    print("   si el fraude no se detecta, su propagación entre épocas está")
    print("   acotada. γ=0.1 da decaimiento a 50% en ~7 épocas, γ=0.01 en")
    print("   ~69 épocas.")
    print()
    print("5. El diseño recomendado: B ≈ 2·B* con un período de gracia")
    print("   para reportes, y γ moderado (0.05-0.1) para limitar daño.")
    print()
    print("=" * 78)


if __name__ == "__main__":
    main()