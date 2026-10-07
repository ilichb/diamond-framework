#!/usr/bin/env python3
"""
succinctness_comparison.py — ¿Por qué verificar la prueba en vez de enviar T?

El tensor de reputación T es público (main.tex §4.1: "the proof exists for
succinctness, not for privacy"). Un revisor puede entonces preguntar: si T
ya es público, ¿por qué no transmitirlo a la cadena destino y calcular su
norma de Frobenius en cadena en lugar de verificar una prueba ZK?

Este script compone el costo de esa alternativa nativa y lo compara con el
costo constante de verificar la prueba. La ingesta nativa tiene dos términos:

  1. Costo de calldata (EIP-2028): 4 gas por byte cero, 16 gas por byte
     distinto de cero. Cuando las entradas del tensor se transmiten como
     elementos de campo de 254 bits (una palabra de 32 bytes cada una), este
     término domina y es proporcional al tamaño del tensor.
  2. Costo de cómputo del bucle sum T[i]^2, medido con Foundry.

Entrada (medición no derivable por sí sola): la salida cruda de Foundry, en
    integrations/avalanche/benchmarks/results/gas_ingest_output.txt
producida por
    forge test --match-test test_ingest -vv

Uso:
    python3 succinctness_comparison.py

Salida:
    Tabla comparativa de costos on-chain y veredicto.
"""

import re
from pathlib import Path

# ------------------------------------------------------------------
# Localización de la medición cruda de Foundry
# ------------------------------------------------------------------
ROOT = Path(__file__).resolve().parents[2]  # raíz del repositorio
RAW = ROOT / "integrations/avalanche/benchmarks/results/gas_ingest_output.txt"

# ------------------------------------------------------------------
# Parámetros del paper
# ------------------------------------------------------------------
C, D, H = 20, 5, 5                 # dimensiones del tensor de reputación
N = C * D * H                      # = 500 entradas
WORD_BYTES = 32                    # cada entrada transmitida como field element (254 bits)

# EIP-2028: costo de calldata por byte
GAS_NONZERO_BYTE = 16
GAS_ZERO_BYTE = 4

# Costos de verificación citados por el paper (ver §4.5 y §8.3)
GROTH16_DIRECT = 206_000           # verificación Groth16 directa, constante (~ecPairing k=4 + lógica)
ECPAIRING_K4 = 181_142             # paso de pairing k=4, medido (EIP-197)
BULLETPROOFS_DIRECT = 6_500_000    # verificación directa de Bulletproofs para N=500 (estimado)
RECURSIVE_SNARK = 250_000          # SNARK recursivo on-chain (estimado)


def parse_foundry(path):
    """Extrae de la salida cruda de Foundry el gas medido del bucle de ingesta.

    Devuelve (exec_unopt, exec_opt, loop_unopt, loop_opt, calib_unopt, calib_opt).
    `exec_*` es el gas del cargador de la función externa; `loop_*` el del
    bucle aislado. El archivo trae dos bloques, sin optimizador y optimizado.
    """
    text = path.read_text(encoding="utf-8")
    parts = re.split(r"^##\s+", text, flags=re.MULTILINE)

    def first(section, pattern):
        m = re.search(pattern, section)
        return int(m.group(1)) if m else None

    unopt = next(p for p in parts if p.lower().startswith("unoptimized"))
    opt = next(p for p in parts if p.lower().startswith("optimized"))
    vals = (
        first(unopt, r"exec gas:\s*(\d+)"),
        first(opt, r"exec gas:\s*(\d+)"),
        first(unopt, r"inline loop only gas:\s*(\d+)"),
        first(opt, r"inline loop only gas:\s*(\d+)"),
        first(unopt, r"minimal 500-loop gas:\s*(\d+)"),
        first(opt, r"minimal 500-loop gas:\s*(\d+)"),
    )
    if None in vals:
        raise SystemExit(f"No se pudo parsear la salida de Foundry en {path}")
    return vals


def calldata_cost():
    """Costo de calldata (EIP-2028) de transmitir el tensor completo.

    Cota superior: una palabra de 32 bytes por entrada, todos los bytes
    distintos de cero. Los field elements de BN254 son < 2^254, de modo que
    cada entrada ocupa de hecho 31 bytes llenos más un byte de orden superior
    (casi siempre no nulo); el total redondea a la misma cota.
    """
    total_bytes = N * WORD_BYTES
    return {"bytes": total_bytes, "nonzero": total_bytes * GAS_NONZERO_BYTE}


def main():
    exec_unopt, exec_opt, loop_unopt, loop_opt, calib_unopt, calib_opt = parse_foundry(RAW)
    cd = calldata_cost()

    # Ingesta nativa = calldata (EIP-2028) + cómputo on-chain del bucle.
    # Se usa la medición de referencia del paper (optimizador desactivado),
    # consistente con la medición de las precompiladas (poseidon 104,963).
    ingest_unopt = cd["nonzero"] + exec_unopt
    ingest_opt = cd["nonzero"] + exec_opt

    print("=" * 78)
    print("SUCCINCTNESS: INGESTA NATIVA DE T vs VERIFICACIÓN DE PRUEBA")
    print("=" * 78)
    print()
    print(f"Tensor de reputación: (C,D,H)=({C},{D},{H})  ->  N = {N} entradas")
    print(f"Transmisión como field elements de 254 bits: {WORD_BYTES} bytes por entrada")
    print()

    print("1. MEDICIÓN FOUNDRY (integrations/avalanche/benchmarks)")
    print("-" * 78)
    print(f"   Gas del cargador de la función, sin optimizador : {exec_unopt:>10,}")
    print(f"   Gas del cargador de la función, con optimizador: {exec_opt:>10,}")
    print(f"   Bucle aislado (sum T[i]^2), sin opt.            : {loop_unopt:>10,}")
    print(f"   Bucle aislado (sum T[i]^2), con opt.            : {loop_opt:>10,}")
    print(f"   Calibración: bucle trivial de 500 pasos, sin opt: {calib_unopt:>10,}")
    print(f"   Calibración: bucle trivial de 500 pasos, con opt: {calib_opt:>10,}")
    print()
    print("   El gas del cargador es insensible al patrón de bytes de T")
    print("   (T[i]=1 y T[i]=2^64-1 dan idéntico resultado), luego mide el")
    print("   costo del bucle y del marco de test, no el payload de calldata.")
    print()

    print("2. COSTO DE CALLDATA (EIP-2028) DE TRANSMITIR T")
    print("-" * 78)
    print(f"   {N} entradas x {WORD_BYTES} bytes = {cd['bytes']:,} bytes")
    print(f"   Cota superior (16 gas/byte no-cero) : {cd['nonzero']:>10,} gas")
    print()

    print("3. COMPOSICIÓN DE LA ALTERNATIVA NATIVA")
    print("-" * 78)
    print(f"   Ingesta = calldata + cómputo = {cd['nonzero']:,} + {exec_unopt:,} "
          f"= {ingest_unopt:,} gas  (sin opt.)")
    print(f"   Ingesta = calldata + cómputo = {cd['nonzero']:,} + {exec_opt:,} "
          f"= {ingest_opt:,} gas  (con opt.)")
    print()

    print("4. COMPARACIÓN ON-CHAIN")
    print("-" * 78)
    rows = [
        ("Ingesta nativa de T (calldata + bucle)", ingest_unopt, "derivado"),
        ("Verificar Groth16 directo (constante)", GROTH16_DIRECT, "constante"),
        ("Paso ecPairing k=4 aislado", ECPAIRING_K4, "medido"),
        ("SNARK recursivo on-chain", RECURSIVE_SNARK, "estimado"),
        ("Verificar Bulletproofs directo (N=500)", BULLETPROOFS_DIRECT, "estimado"),
    ]
    print(f"   {'Método':<44}{'Gas':>14}   Naturaleza")
    print(f"   {'-'*44}{'-'*14}   ----------")
    for name, gas, nature in rows:
        print(f"   {name:<44}{gas:>14,}   {nature}")
    print()

    print("5. VEREDICTO")
    print("-" * 78)
    print(f"   Ingesta nativa ({ingest_unopt:,} gas) supera:")
    print(f"     - la verificación Groth16 directa ({GROTH16_DIRECT:,}),")
    print(f"     - el paso ecPairing k=4 ({ECPAIRING_K4:,}), y")
    print(f"     - el SNARK recursivo ({RECURSIVE_SNARK:,}).")
    print()
    print(f"   Solo la verificación directa de Bulletproofs ({BULLETPROOFS_DIRECT:,})")
    print("   es más cara que ingerir T; y ésa es precisamente la ruta que el")
    print("   paper descarta en favor de la recursión.")
    print()
    print("   Conclusión: transmitir T y computar ||T||_F en cadena NO es más")
    print("   barato que verificar la prueba. La prueba es succinct y la")
    print("   ingesta nativa es el camino caro. La premisa del revisor no se")
    print("   sostiene para el tensor de referencia.")
    print()
    print("=" * 78)


if __name__ == "__main__":
    main()
