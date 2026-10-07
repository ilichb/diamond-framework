#!/usr/bin/env python3
"""
financial_floor_sensitivity.py — ¿De dónde sale el piso financiero S_min?

La regla de asignación de §6.3 del paper es

    S_f*(T) = max{ S_min, Theta - C_R(T) },

donde Theta es el umbral de admisión, C_R(T) = C_R(||T||_F) es la garantía
reputacional y S_min es un piso financiero mínimo. El paper declaraba
S_min = 0.2 como [CONJECTURE]. Este script muestra que el valor no es
arbitrario: es el complemento de la saturación de la garantía reputacional.

Con Theta = 1.0 y la forma cerrada de referencia C_R(r) = 0.8 r/(1+r):

    C_R_inf = lim_{r->inf} C_R(r) = 0.8
    S_min   = Theta - C_R_inf   = 1.0 - 0.8 = 0.2

El piso es el mayor valor que permanece inerte sobre el rango admisible: el
stake sin piso Theta - C_R(T) tiene ínfimo Theta - C_R_inf = 0.2, que el piso
iguala pero nunca supera. Se barre además C_R_inf en [0.5, 1.0] para mostrar
cómo S_min = Theta - C_R_inf se mueve con la saturación.

Uso:
    python3 financial_floor_sensitivity.py

Salida:
    Tablas de saturación, piso implicado y sensibilidad; veredicto.
"""

# ------------------------------------------------------------------
# Parámetros de referencia (§6.3, §6.4)
# ------------------------------------------------------------------
THETA = 1.0                      # umbral de admisión
C_R_REF_SATURATION = 0.8         # C_R(r) = 0.8 r/(1+r)  ->  saturación 0.8
S_MIN_VALUES = [0.0, 0.1, 0.2]   # pisos a comparar
C_R_INF_SWEEP = [0.5, 0.6, 0.7, 0.8, 0.9, 1.0]


def cr(r):
    """Forma cerrada de referencia de la garantía reputacional (§2.5)."""
    return C_R_REF_SATURATION * r / (1.0 + r)


def main():
    print("=" * 78)
    print("C-21: EL PISO FINANCIERO S_min — ¿CONJETURA O DERIVADO?")
    print("=" * 78)
    print()
    print(f"Parámetros de referencia: Theta = {THETA:.1f}, "
          f"C_R(r) = {C_R_REF_SATURATION} r/(1+r)")
    print()

    print("1. SATURACIÓN DE LA GARANTÍA REPUTACIONAL")
    print("-" * 78)
    print(f"   C_R_inf = lim_{{r->inf}} C_R(r) = {C_R_REF_SATURATION:.3f}")
    print(f"   (Verificación numérica: C_R(1e9) = {cr(1e9):.6f})")
    unfloored_inf = THETA - C_R_REF_SATURATION
    print(f"   Stake sin piso: Theta - C_R(T) en ({unfloored_inf:.3f}, {THETA:.3f}]")
    print(f"   Ínfimo = Theta - C_R_inf = {unfloored_inf:.3f}")
    print()

    print("2. PISO S_min Y SU CAP DE REPUTACIÓN")
    print("-" * 78)
    print(f"   {'S_min':>6}   {'Cap rep. (Theta-S_min)':>24}   {'Rep. share':>11}   "
          f"{'¿Ata? (C_R_inf=0.8)':>20}")
    print(f"   {'-'*6}   {'-'*24}   {'-'*11}   {'-'*20}")
    for s in S_MIN_VALUES:
        cap = THETA - s
        share = cap / THETA
        binds = s > unfloored_inf + 1e-12
        binds_str = "sí" if binds else "no"
        print(f"   {s:>6.2f}   {cap:>24.3f}   {share*100:>10.0f}%   {binds_str:>20}")
    print()
    print(f"   El piso ata si S_min > Theta - C_R_inf = {unfloored_inf:.3f}.")
    print(f"   El valor de referencia {S_MIN_VALUES[-1]:.1f} es el mayor piso que")
    print(f"   permanece inerte bajo la saturación {C_R_REF_SATURATION:.1f} del modelo.")
    print()

    print("3. SENSIBILIDAD A LA SATURACIÓN C_R_inf")
    print("-" * 78)
    print(f"   {'C_R_inf':>8}   {'Piso S_min = Theta - C_R_inf':>30}   {'Rep. share':>11}")
    print(f"   {'-'*8}   {'-'*30}   {'-'*11}")
    for cr_inf in C_R_INF_SWEEP:
        s_implied = THETA - cr_inf
        print(f"   {cr_inf:>8.1f}   {s_implied:>30.3f}   {cr_inf/THETA*100:>10.0f}%")
    print()

    print("4. VEREDICTO")
    print("-" * 78)
    print(f"   El S_min = 0.2 del paper NO es una conjetura arbitraria: es")
    print(f"   Theta - C_R_inf = {THETA:.1f} - {C_R_REF_SATURATION:.1f} = "
          f"{THETA - C_R_REF_SATURATION:.1f}, el complemento")
    print(f"   exacto de la saturación de la garantía reputacional del modelo.")
    print()
    print(f"   Para C_R_inf en [0.5, 1.0] el piso implicado barre [0.0, 0.5];")
    print(f"   0.2 corresponde a la saturación de referencia 0.8, es decir,")
    print(f"   la reputación aporta como máximo el 80% del umbral de admisión.")
    print()
    print("=" * 78)


if __name__ == "__main__":
    main()
