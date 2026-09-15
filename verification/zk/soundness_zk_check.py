#!/usr/bin/env python3
"""
soundness_cost.py — Costo real de soundness para el circuito ZK del Diamond Framework.

Mide, con aritmética verificable, cuántas restricciones R1CS requiere cada diseño
de circuito, y muestra por qué el "146 constraints" del paper no incluye el costo
de vincular el tensor probado a los datos de reputación reales.

No ejecuta Groth16 (eso requiere snarkjs + circom). Cuenta constraints, que es
el factor determinante del costo de prueba y verificación.

Uso:
    python3 soundness_cost.py

Salida:
    Tabla comparativa de los cuatro diseños considerados, más veredicto.
"""

from dataclasses import dataclass


# ------------------------------------------------------------------
# Parámetros del paper (Proposición 5.4, Lema 6.6)
# ------------------------------------------------------------------
C, D, H = 20, 5, 5          # dimensiones del tensor de reputación
N = C * D * H               # = 500 entradas
R1, R2, R3 = 4, 3, 3        # rangos Tucker

# Costos de primitivas criptográficas (valores típicos en R1CS)
POSEIDON_CONSTRAINTS = 240  # hash Poseidon sobre BN254, típico en circom
BULLETPROOF_LOG_FACTOR = 2  # tamaño de prueba ~ 2·log2(n) + O(1) elementos


# ------------------------------------------------------------------
# Diseños de circuito
# ------------------------------------------------------------------
@dataclass
class CircuitDesign:
    name: str
    sound: bool
    constraints: int
    proof_size_kb: float
    notes: str


def design_current():
    """
    Diseño actual del paper: el prover elige T̂ (factores Tucker) y prueba
    Σ T̂² ≥ Θ_r². No hay compromiso a los datos reales.
    Constraints:
      - R1R2R3 productos Tucker: R1R2R3
      - Reconstrucción de T̂: R1R2R3 (una multiplicación por entrada)
      - Cuadrados y suma: N
      - Comparación: 1 (truco δ²)
    """
    tucker = R1 * R2 * R3
    reconstruction = R1 * R2 * R3
    sum_squares = N
    comparison = 1
    total = tucker + reconstruction + sum_squares + comparison
    return CircuitDesign(
        name="Actual (Prover elige T̂)",
        sound=False,
        constraints=total,
        proof_size_kb=0.2,  # Groth16, constante
        notes="Prover puede fabricar T̂ con ||T̂||_F ≥ Θ_r sin actividad real.",
    )


def design_option_a_merkle():
    """
    Opción A: compromiso Merkle a T crudo, y el circuito abre todas las hojas
    para verificar Σ T² ≥ Θ_r².
    Constraints:
      - Apertura de cada hoja: log2(N) hashes Poseidon
      - Suma de cuadrados: N
      - Comparación: 1
    Para N = 500, log2(N) ≈ 9, cada hash Poseidon ≈ 240 constraints.
    """
    import math
    log_n = math.ceil(math.log2(N))
    merkle_openings = N * log_n * POSEIDON_CONSTRAINTS
    sum_squares = N
    comparison = 1
    total = merkle_openings + sum_squares + comparison
    return CircuitDesign(
        name="Opción A (Merkle + apertura total)",
        sound=True,
        constraints=total,
        proof_size_kb=0.2,
        notes=f"Requiere {N} aperturas de Merkle de longitud {log_n}. Sound pero prohibitivo.",
    )


def design_option_a_poseidon():
    """
    Opción A': compromiso Poseidon del tensor completo, y el circuito re-hashea.
    Constraints:
      - Poseidon sobre el tensor completo: N hashes (aprox., en árbol binario)
      - Suma de cuadrados: N
      - Comparación: 1
    Un árbol de Merkle sobre N hojas usa N-1 hashes internos + N hashes de hoja.
    """
    poseidon_tree = (2 * N - 1) * POSEIDON_CONSTRAINTS
    sum_squares = N
    comparison = 1
    total = poseidon_tree + sum_squares + comparison
    return CircuitDesign(
        name="Opción A' (Poseidon del tensor completo)",
        sound=True,
        constraints=total,
        proof_size_kb=0.2,
        notes="Requiere re-hashear el tensor completo dentro del circuito.",
    )


def design_option_b_bulletproofs():
    """
    Opción B: compromiso Pedersen al vector T (aplanado), y prueba de producto
    interno (Bulletproofs) que demuestra ⟨T, T⟩ ≥ Θ_r².
    No hay circuito R1CS. La prueba es O(log N) en tamaño, verificación O(N).
    Constraints R1CS: 0 (es un protocolo interactivo/Fiat-Shamir, no un circuito).
    Tamaño de prueba: ~2·log2(N) + O(1) elementos de grupo ≈ 2·log2(N)·32 bytes.
    """
    import math
    log_n = math.ceil(math.log2(N))
    proof_size_bytes = (2 * log_n + 5) * 32  # elementos de 32 bytes, aprox.
    proof_size_kb = proof_size_bytes / 1024
    return CircuitDesign(
        name="Opción B (Pedersen + Bulletproofs)",
        sound=True,
        constraints=0,
        proof_size_kb=proof_size_kb,
        notes="Sin circuito R1CS. Prueba sub-lineal. Verificación O(N) fuera de cadena.",
    )


# ------------------------------------------------------------------
# Exploit: demostración lógica de la no-soundness del diseño actual
# ------------------------------------------------------------------
def demo_exploit():
    """
    Ilustra que el prover puede elegir arbitrariamente los factores Tucker
    para producir un T̂ con norma alta, sin relación con actividad real.
    """
    import numpy as np

    rng = np.random.default_rng(42)

    # T real del validador: reputación baja en todas partes
    T_real = np.full((C, D, H), 0.01)
    norm_real = np.linalg.norm(T_real)

    # T̂ fabricado por el prover: factores Tucker elegidos para que ||T̂||_F = 1
    G = rng.standard_normal((R1, R2, R3))
    A_C = rng.standard_normal((C, R1))
    A_D = rng.standard_normal((D, R2))
    A_H = rng.standard_normal((H, R3))

    # Reconstrucción Tucker: T̂ = G ×₁ A_C ×₂ A_D ×₃ A_H
    T_hat = np.einsum("ijk,ci,dj,hk->cdh", G, A_C, A_D, A_H)
    T_hat = T_hat / np.linalg.norm(T_hat)  # normalizar a norma 1
    norm_hat = np.linalg.norm(T_hat)

    return {
        "norm_real": norm_real,
        "norm_hat": norm_hat,
        "threshold": 0.5,  # ejemplo de umbral Θ_r
        "real_passes": norm_real >= 0.5,
        "fake_passes": norm_hat >= 0.5,
    }


# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------
def main():
    print("=" * 78)
    print("COSTO REAL DE SOUNDNESS — DIAMOND FRAMEWORK ZK CIRCUIT")
    print("=" * 78)
    print()

    # 1. Exploit
    print("1. EXPLOIT DEL DISEÑO ACTUAL")
    print("-" * 78)
    exploit = demo_exploit()
    print(f"   ||T_real||_F  = {exploit['norm_real']:.6f}  "
          f"(¿pasa umbral {exploit['threshold']}? {exploit['real_passes']})")
    print(f"   ||T_hat||_F   = {exploit['norm_hat']:.6f}  "
          f"(¿pasa umbral {exploit['threshold']}? {exploit['fake_passes']})")
    print()
    print("   El prover elige los factores Tucker para producir un T̂ con")
    print("   norma alta, sin que exista actividad real detrás. El circuito")
    print("   verifica una propiedad sobre el tensor fabricado, no sobre el")
    print("   tensor de reputación real. El exploit es trivial.")
    print()

    # 2. Diseños
    print("2. CONSTRAINTS R1CS POR DISEÑO")
    print("-" * 78)
    designs = [
        design_current(),
        design_option_a_merkle(),
        design_option_a_poseidon(),
        design_option_b_bulletproofs(),
    ]

    print(f"   {'Diseño':<42} {'Sound':<7} {'R1CS':>15} {'Prueba':>10}")
    print(f"   {'-'*42} {'-'*7} {'-'*15} {'-'*10}")
    for d in designs:
        sound_str = "sí" if d.sound else "NO"
        print(f"   {d.name:<42} {sound_str:<7} {d.constraints:>15,} "
              f"{d.proof_size_kb:>8.2f} KB")

    print()

    # 3. Análisis
    print("3. ANÁLISIS")
    print("-" * 78)
    current = designs[0]
    opt_a_merkle = designs[1]
    opt_a_poseidon = designs[2]
    opt_b = designs[3]

    print(f"   El '146 constraints' del paper es solo la parte de Tucker.")
    print(f"   El circuito real ({current.constraints:,} constraints) no es sound.")
    print()
    print(f"   Añadir soundness via Merkle (Opción A) cuesta")
    print(f"   {opt_a_merkle.constraints:,} constraints, un factor de")
    print(f"   {opt_a_merkle.constraints / current.constraints:.0f}× sobre el diseño actual.")
    print()
    print(f"   Añadir soundness via Poseidon (Opción A') cuesta")
    print(f"   {opt_a_poseidon.constraints:,} constraints, un factor de")
    print(f"   {opt_a_poseidon.constraints / current.constraints:.0f}× sobre el diseño actual.")
    print()
    print(f"   Opción B (Bulletproofs) no usa R1CS. Prueba de")
    print(f"   {opt_b.proof_size_kb:.2f} KB, verificación O(N) fuera de cadena.")
    print()
    print("   Conclusión: el ahorro del 70.8% del paper es real como")
    print("   ahorro de almacenamiento del tensor, pero no como ahorro")
    print("   del circuito ZK en la ruta de seguridad. La compresión Tucker")
    print("   no puede vivir dentro del circuito sound sin pagar O(N·log N)")
    print("   constraints de apertura, o sin abandonar Groth16 por Bulletproofs.")
    print()

    # 4. Veredicto
    print("4. VEREDICTO")
    print("-" * 78)
    print("   Diseño recomendado: Opción B (Pedersen + Bulletproofs).")
    print()
    print("   Razones:")
    print("   - Sound sin necesidad de comprometer la totalidad del tensor")
    print("     dentro de un circuito R1CS.")
    print("   - Prueba sub-lineal: O(log N) elementos de grupo.")
    print("   - Verificación O(N) off-chain, recursible a O(1) on-chain")
    print("     vía un SNARK envolvente.")
    print("   - Tucker se conserva como herramienta de almacenamiento y")
    print("     transmisión off-chain, no como claim de seguridad.")
    print()
    print("   El paper debe reescribir la Proposición 5.4 como:")
    print("   'Tucker reduce el tamaño del tensor transmitido en un 70.8%',")
    print("   'pero no reduce el costo del circuito ZK sound. La prueba de'")
    print("   'umbral se realiza vía Bulletproofs sobre el tensor crudo.'")
    print()
    print("=" * 78)


if __name__ == "__main__":
    main()