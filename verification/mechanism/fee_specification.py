#!/usr/bin/env python3
"""
fee_specification.py — Verificacion de la regla de pago uniforme del mecanismo (Seccion 6).

Modelo:
  - T (publico, verificado): determina S_f*(T) = max{VaR_tech, Theta - C_R(T)}
  - omega (privado): costo de capital, omega ~ Uniforme[omega_min, omega_max]
  - Regla de pago: F0 uniforme (posted price), NO Myerson
  - Utilidad: U(omega, T) = pi_val(R) - omega * S_f*(T) - F0

Nota: con S_f* independiente de omega, no hay juego de revelacion
sobre omega y el fee optimo es un posted price saturado. Myerson
aplicaria solo si la asignacion dependiera del tipo privado.

Verifica:
  1. IC: ningun tipo quiere desviarse de su asignacion (T es publico, no hay desvio)
  2. IR: U(omega, T) >= 0 para todos los tipos en equilibrio
  3. F0 optimo: satura IR en (omega_max, T con S_f* maximo)
  4. Fee total recaudado vs bounties pagados

Parametros:
  - pi_val = 0.15 (ingreso esperado de validacion por epoca, normalizado)
  - omega ~ U[0.01, 0.10] (costo de capital, fraccion por unidad de stake)
  - Theta = 1.0 (stake base)
  - C_R(T) = 0.8 * ||T||/(1 + ||T||)  (agregador concavo)
  - N_VALIDATORS = 1000 (para Monte Carlo)
"""

import numpy as np


RNG_SEED = 42
N_VALIDATORS = 1000
OMEGA_MIN = 0.01
OMEGA_MAX = 0.10
PI_VAL = 0.15
THETA = 1.0
VAR_TECH = 0.2


def c_r(norm_T):
    """Agregador concavo sobre la norma del tensor."""
    return 0.8 * norm_T / (1.0 + norm_T)


def s_f_star(norm_T):
    """Stake financiero requerido dado el score de reputacion."""
    return max(VAR_TECH, THETA - c_r(norm_T))


def utility(omega, norm_T, F0):
    """Utilidad del validador de tipo omega con reputacion norm_T."""
    return PI_VAL - omega * s_f_star(norm_T) - F0


def find_optimal_fee(omega_max):
    """
    F0* tal que IR se satura en (omega_max, norm_T=0).
    Con norm_T=0: S_f* = Theta.
    U(omega_max, 0) = PI_VAL - omega_max * Theta - F0 = 0
    => F0* = PI_VAL - omega_max * Theta
    """
    return PI_VAL - omega_max * THETA


def main():
    print("=" * 80)
    print("REGLA DE PAGO UNIFORME (POSTED PRICE) — VERIFICACION IC/IR")
    print("=" * 80)
    print()
    print(f"Parametros:")
    print(f"  N_VALIDATORS = {N_VALIDATORS}")
    print(f"  omega ~ Uniforme[{OMEGA_MIN}, {OMEGA_MAX}]")
    print(f"  PI_VAL = {PI_VAL}")
    print(f"  THETA = {THETA}, VAR_TECH = {VAR_TECH}")
    print()

    # F0 optimo
    F0_star = find_optimal_fee(OMEGA_MAX)
    print(f"F0* (fee uniforme optimo) = {F0_star:.4f}")
    print()

    # Generar validadores con omega y norm_T heterogeneos
    rng = np.random.default_rng(RNG_SEED)
    omegas = rng.uniform(OMEGA_MIN, OMEGA_MAX, size=N_VALIDATORS)
    norm_Ts = rng.uniform(0.0, 3.0, size=N_VALIDATORS)  # tensor de reputacion

    # Utilidades con F0*
    utilities = np.array([utility(w, t, F0_star) for w, t in zip(omegas, norm_Ts)])

    print("1. VERIFICACION IR (F0 = F0*)")
    print("-" * 80)
    print(f"   U min  = {utilities.min():.6f}")
    print(f"   U max  = {utilities.max():.6f}")
    print(f"   U mean = {utilities.mean():.6f}")
    print(f"   Fraccion con U >= 0: {(utilities >= -1e-9).mean():.4f}")
    if utilities.min() >= -1e-9:
        print("   IR: OK (todos los tipos tienen U >= 0)")
    else:
        print("   IR: FALLA (algun tipo tiene U < 0)")
    print()

    print("2. SATURACION EN (omega_max, norm_T = 0)")
    print("-" * 80)
    u_sat = utility(OMEGA_MAX, 0.0, F0_star)
    print(f"   U(omega_max, norm_T=0) = {u_sat:.10f}")
    print(f"   Deberia ser 0 por construccion de F0*")
    if abs(u_sat) < 1e-9:
        print("   Saturacion: OK")
    else:
        print(f"   Saturacion: FALLA (residuo {u_sat:.2e})")
    print()

    print("3. VERIFICACION IC (vacua — posted price)")
    print("-" * 80)
    print("   T es publico (verificado on-chain).")
    print("   No hay reporte privado sobre T. IC se cumple trivialmente.")
    print("   El unico tipo privado es omega, y la asignacion S_f*(T)")
    print("   no depende de omega.")
    print("   => IC es vacua (no hay desvio posible).")
    print()

    print("4. RECAUDACION Y DESTINO DEL FEE")
    print("-" * 80)
    total_fee = F0_star * N_VALIDATORS
    print(f"   Fee unitario:          {F0_star:.4f}")
    print(f"   Fee total por epoca:   {total_fee:.4f}")
    print(f"   Uso del fee:")
    print(f"     - Pool de bounties (Seccion 7)")
    print(f"     - Fondo de compensacion (Seccion 9)")
    print()

    print("5. F0 SENSIBILIDAD")
    print("-" * 80)
    print(f"{'F0':>8} {'IR violada':>12} {'Recaudacion':>14}")
    for f0 in [F0_star * 0.5, F0_star * 0.8, F0_star, F0_star * 1.2]:
        utils = np.array([utility(w, t, f0) for w, t in zip(omegas, norm_Ts)])
        viol = (utils < -1e-9).mean()
        print(f"{f0:>8.4f} {viol:>12.4f} {f0 * N_VALIDATORS:>14.2f}")
    print()

    print("=" * 80)
    print("CONCLUSION")
    print("=" * 80)
    print()
    print(f"   Regla de pago: F0 = {F0_star:.4f} (posted price saturado)")
    print(f"   IR: se cumple para todos los tipos")
    print(f"   IC: vacua (T publico, omega no afecta asignacion)")
    print(f"   No es Myerson: no hay reserva dependiente de la distribucion")
    print()
    print("   El paper debe reescribir la Seccion 6 como:")
    print("     - T verificado => no revelacion")
    print("     - omega privado pero asignacion independiente de omega")
    print("     - F0 uniforme saturado en (omega_max, norm_T=0)")
    print()
    print("=" * 80)


if __name__ == "__main__":
    main()
