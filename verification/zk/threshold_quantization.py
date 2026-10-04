#!/usr/bin/env python3
"""
threshold_quantization.py — El bit del circuito (Sec. 4.1) contra el valor que
exige la regla de asignacion (Sec. 6.3). Finding C-01 de la auditoria de contenido.

Modelo:
  - El circuito de umbral prueba unicamente la desigualdad ||T||_F >= Theta_r
    (main.tex:426, eq:threshold). Su salida es un BIT.
  - La regla de asignacion S_f*(T) = max{VaR_tech, Theta - C_R(T)}
    (main.tex:754, eq:allocation) exige C_R(T) como funcion CONTINUA de ||T||.
  - Nada en el paper conecta el bit con el valor. El script cuantifica el error
    de esa desconexion en dos regimenes:
      (i)  k = 1 (solo el bit): todo el intervalo aceptado colapsa a un valor.
      (ii) k umbrales escalonados (prueba por bandas): error de cuantizacion vs k,
           y el costo (gas) de cada umbral adicional.

Procedencia de las cifras (ninguna es propia; todas salen del paper o del script
hermano fee_specification.py):
  - N = C*D*H = 500 entradas del tensor               (main.tex:316)
  - ||T|| en [0, 3]                                   (main.tex:798, T ~ U[0,3])
  - Theta_r = 0.5, unico umbral numerico del paper    (main.tex:444-445)
  - Theta = 1.0, VaR_tech = 0.2, C_R(x) = 0.8x/(1+x)  (fee_specification.py:37-43)
  - gas Groth16 en cadena ~206k                       (main.tex:475)
  - gas recursion ~250k                               (main.tex:506)
  - Bulletproofs N=500: ~6.5M gas, 0.72 KB            (main.tex:498)

Reproducibilidad: calculo determinista (aritmetica cerrada, sin Monte Carlo); no
declara semilla ni tamano de muestra. El barrido de k es exhaustivo sobre K_GRID.
"""

import math


# ------------------------------------------------------------------
# Parametros (procedencia en el docstring)
# ------------------------------------------------------------------
C, D, H = 20, 5, 5
N = C * D * H

T_MAX = 3.0        # cota superior de ||T|| (main.tex:798: T ~ U[0,3])
THETA_R = 0.5      # umbral del circuito (main.tex:444-445)
THETA = 1.0        # stake base del mecanismo (fee_specification.py:37)
VAR_TECH = 0.2     # piso tecnico de stake (fee_specification.py:38)

GAS_GROTH16_VERIFY = 206_000        # main.tex:475 ("~206k", constante)
GAS_RECURSIVE = 250_000             # main.tex:506 ("~250k gas")
GAS_BULLETPROOFS_N500 = 6_500_000   # main.tex:498 (verificacion O(N) off-chain)
KB_BULLETPROOFS_N500 = 0.72         # main.tex:498 (tamano de prueba)

K_GRID = [1, 2, 4, 8, 16, 32, 64]


# ------------------------------------------------------------------
# Mecanismo y circuito
# ------------------------------------------------------------------
def c_r(norm_T):
    """Agregador concavo de reputacion (fee_specification.py:43)."""
    return 0.8 * norm_T / (1.0 + norm_T)


def c_r_inverse(v):
    """Inversa exacta de c_r: v = 0.8x/(1+x) => x = v/(0.8 - v)."""
    return v / (0.8 - v)


def s_f_star(norm_T):
    """Stake financiero requerido (main.tex:754)."""
    return max(VAR_TECH, THETA - c_r(norm_T))


def edges_uniform_norm(k):
    """k umbrales equiespaciados en ||T|| (colocacion ingenua)."""
    h = (T_MAX - THETA_R) / k
    return [THETA_R + j * h for j in range(k + 1)]


def edges_uniform_cr(k):
    """k umbrales equiespaciados en C_R (colocacion optima para el error max)."""
    c_lo, c_hi = c_r(THETA_R), c_r(T_MAX)
    return [c_r_inverse(c_lo + j * (c_hi - c_lo) / k) for j in range(k + 1)]


def quant_error(edges):
    """max_j [C_R(tau_{j+1}) - C_R(tau_j)]: error de cuantizacion en C_R."""
    return max(c_r(edges[j + 1]) - c_r(edges[j]) for j in range(len(edges) - 1))


def main():
    print("=" * 78)
    print("CUANTIZACION UMBRAL->STAKE — FINDING C-01 (bit del circuito vs valor)")
    print("=" * 78)
    print()

    print("1. PARAMETROS Y CHEQUEOS DE COHERENCIA CON EL PAPER")
    print("-" * 78)
    pairing_k4 = 45_000 + 34_000 * 4 + 142
    print(f"   N = C*D*H = {C}*{D}*{H} = {N}  (main.tex:316)")
    print(f"   Intervalo aceptado por el bit: ||T|| in [{THETA_R}, {T_MAX}]")
    print(f"   Gas pairing Groth16 (k=4) = 45,000 + 34,000*4 + 142 = {pairing_k4:,}"
          f"  (main.tex:467: 181,142)")
    print(f"   C_R({T_MAX}) = {c_r(T_MAX):.4f}"
          f"   (main.tex:798 afirma C_R(T) in [0, 0.6])")
    print(f"   C_R({THETA_R}) = {c_r(THETA_R):.6f}")
    print(f"   Inversa: c_r_inverse({c_r(T_MAX):.4f}) = {c_r_inverse(c_r(T_MAX)):.6f}"
          f"  (debe ser {T_MAX})")
    print()


    print("2. EL BIT SOLO (k = 1): LA ASIGNACION QUEDA INDETERMINADA")
    print("-" * 78)
    c_lo, c_hi = c_r(THETA_R), c_r(T_MAX)
    s_min, s_max = s_f_star(T_MAX), s_f_star(THETA_R)
    print(f"   C_R recorre [{c_lo:.6f}, {c_hi:.6f}] dentro del conjunto aceptado.")
    print(f"   S_f* recorre [{s_min:.6f}, {s_max:.6f}]; rango {s_max - s_min:.6f}"
          f" ({(s_max - s_min) / THETA:.2%} de Theta).")
    print()
    print("   [a] Politica de caso peor (segura): cobrar S_f*(Theta_r) a todos.")
    print(f"       sobre-colateralizacion con ||T||={T_MAX}:"
          f" {s_max / s_min - 1.0:+.2%}")
    print("   [b] Politica intermedia (lo que el bit sugiere): cobrar S_f*(T_max).")
    coa = s_min + c_lo
    print(f"       CoA con ||T||={THETA_R}: {s_min:.6f} + {c_lo:.6f} = {coa:.6f}"
          f" < Theta")
    print(f"       deficit de colateral: {THETA - coa:.6f}"
          f" ({(THETA - coa) / THETA:.2%} de Theta)")
    print()
    print("   => El bit no distingue ||T||=0.5 de ||T||=3.0: el protocolo debe")
    print("      sobre-colateralizar o violar CoA. Ninguna opcion sale del paper.")
    print()

    print("3. UMBRALES ESCALONADOS: ERROR DE CUANTIZACION vs k")
    print("-" * 78)
    print(f"   {'k':>3} {'bits':>4} {'eps(||T||)':>12} {'eps(C_R)':>10}"
          f" {'gas directo':>13} {'recursivo':>12} {'off-chain':>12}")
    for k in K_GRID:
        bits = 0 if k == 1 else int(math.ceil(math.log2(k)))
        e_norm = quant_error(edges_uniform_norm(k))
        e_cr = quant_error(edges_uniform_cr(k))
        print(f"   {k:>3} {bits:>4} {e_norm:>12.6f} {e_cr:>10.6f}"
              f" {GAS_GROTH16_VERIFY * k:>13,} {GAS_RECURSIVE:>12,}"
              f" {GAS_BULLETPROOFS_N500 * k:>12,}")
    print()
    print(f"   Colocacion optima (uniforme en C_R): eps ="
          f" ({c_hi:.6f} - {c_lo:.6f})/k = {(c_hi - c_lo):.6f}/k.")
    print(f"   Prueba Bulletproofs: k x {KB_BULLETPROOFS_N500} KB"
          f" (una prueba de rango por umbral).")
    print(f"   Con recursion el gas on-chain es constante ({GAS_RECURSIVE:,});"
          f" el costo marginal es off-chain.")
    print()

    print("4. k NECESARIO PARA UN ERROR OBJETIVO (colocacion optima)")
    print("-" * 78)
    print(f"   {'eps objetivo':>13} {'k*':>5} {'gas directo':>13} {'off-chain':>12}")
    for target in (0.10, 0.05, 0.01):
        k_req = math.ceil((c_hi - c_lo) / target)
        print(f"   {target:>13.2f} {k_req:>5} {GAS_GROTH16_VERIFY * k_req:>13,}"
              f" {GAS_BULLETPROOFS_N500 * k_req:>12,}")
    print()
    print("   El paper no declara eps objetivo; sin eps no hay k* unico.")
    print()

    print("=" * 78)
    print("CONCLUSION")
    print("=" * 78)
    print()
    print("   1. El bit de la Sec. 4.1 es insuficiente para la regla de la Sec. 6.3:")
    print(f"      deja sin determinar {s_max - s_min:.6f} de stake"
          f" ({(s_max - s_min) / THETA:.1%} de Theta).")
    print("   2. Con k umbrales el error cae como 1/k (colocacion optima en C_R),")
    print("      pero cada umbral anade un bit de salida publica y una prueba.")
    print("   3. La Sec. 4.1 especifica un bit (||T||_F >= Theta_r); la Sec. 6.3")
    print("      requiere C_R(T) como valor. La brecha tiene dos capas:")
    print("      soundness (cerrada por la Opcion B adoptada en Sec. 4.3-4.4:")
    print("      Pedersen + Bulletproofs sobre el vector comprometido, sin abrir")
    print("      el tensor, consistente con Sec. 4.1 L423 'without revealing the")
    print("      full reputation tensor') y allocabilidad (abierta: el paper no")
    print("      especifica como C_R(T) llega a la cadena). C_R = 0.8x/(1+x) es")
    print("      no lineal; Bulletproofs es nativo para enunciados lineales, asi")
    print("      que C_R(T) no es expresable sobre el commitment sin revelar")
    print("      ||T||_F, o sin redisenar C_R como lineal.")
    print("   4. Bloqueo de verificacion: el paper no fija Theta_r, ni VaR_tech,")
    print("      ni la forma funcional de C_R (la Sec. 2.5 la define como una EDP")
    print("      integro-diferencial en un r escalar). Sin esos tres datos, k* no")
    print("      puede derivarse del texto.")
    print()
    print("=" * 78)


if __name__ == "__main__":
    main()
