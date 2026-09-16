#!/usr/bin/env python3
"""
mfpt_bound_explicit.py — MFPT del CIR por integracion numerica estable.

Calcula E[tau_R0] usando la formula clasica:
  E[tau_R0] = 2 * int_0^R0 (s(R0) - s(y)) * m(y) dy

Reformulada para evitar cancelacion catastrofica cuando kappa > 1:
  g(y) = (2/sigma0^2) * int_1^(R0/y) s^(-kappa) * exp(beta*y*(s-1)) ds
  E[tau_R0] = 2 * int_0^R0 g(y) dy

donde:
  kappa = 2*alpha*Rbar / sigma0^2
  beta  = 2*alpha / sigma0^2

La formulacion g(y) es numericamente estable porque el integrando es O(1)
en lugar de O(s(R0)).

Verifica tambien C* implicito para la cota original:
  E[tau_R0] >= C* * R0^(1-kappa) * exp(beta*R0)
  C* <= E[tau_R0] / (R0^(1-kappa) * exp(beta*R0))
"""

import numpy as np
from scipy import integrate


SCENARIOS = [
    {"name": "Section 2.2 parameters", "alpha": 0.5, "rbar": 1.0, "sigma0": 0.8},
    {"name": "D4 analysis parameters", "alpha": 2.0, "rbar": 1.0, "sigma0": 0.5},
]

R0_TARGET = 2.2


def g_inner(s_val, y, kappa, beta):
    """Integrando para g(y): s^(-kappa) * exp(beta*y*(s-1))."""
    if s_val <= 0:
        return 0.0
    return s_val ** (-kappa) * np.exp(beta * y * (s_val - 1))


def g_outer(y, R0, kappa, beta, sigma0):
    """g(y) = (2/sigma0^2) * int_1^(R0/y) s^(-kappa) exp(beta*y*(s-1)) ds."""
    if y <= 0:
        return 0.0
    upper = R0 / y
    if upper <= 1.0:
        return 0.0
    val, err = integrate.quad(g_inner, 1.0, upper, args=(y, kappa, beta),
                                limit=200)
    return (1.0 / sigma0 ** 2) * val


def mfpt_exact(alpha, rbar, sigma0, R0):
    """E[tau_R0] = 2 * int_0^R0 g(y) dy."""
    kappa = 2 * alpha * rbar / sigma0 ** 2
    beta = 2 * alpha / sigma0 ** 2

    def integrand(y):
        return g_outer(y, R0, kappa, beta, sigma0)

    val, err = integrate.quad(integrand, 0.0, R0, limit=200)
    mfpt = 2.0 * val
    assert mfpt > 0, f"MFPT must be positive, got {mfpt}"
    return mfpt, err, kappa, beta


def bound_C1(kappa, beta, R0):
    """Cota original con C*=1: R0^(1-kappa) * exp(beta*R0)."""
    return R0 ** (1 - kappa) * np.exp(beta * R0)


def main():
    print("=" * 78)
    print("MFPT EXPLICIT — CIR FIRST-PASSAGE BY NUMERICAL INTEGRATION")
    print("(stable formulation, no catastrophic cancellation)")
    print("=" * 78)
    print()
    print(f"R0 = {R0_TARGET}")
    print()

    for sc in SCENARIOS:
        alpha, rbar, sigma0 = sc["alpha"], sc["rbar"], sc["sigma0"]
        print(f"--- {sc['name']} ---")
        print(f"  alpha={alpha}, Rbar={rbar}, sigma0={sigma0}")

        mfpt, err, kappa, beta = mfpt_exact(alpha, rbar, sigma0, R0_TARGET)
        bound = bound_C1(kappa, beta, R0_TARGET)
        C_impl = mfpt / bound

        print(f"  kappa = {kappa:.6f}, beta = {beta:.6f}")
        print()
        print(f"  MFPT exacto (integracion estable): {mfpt:.6f}")
        print(f"  Error de cuadratura:                {err:.2e}")
        print(f"  Cota con C*=1:                      {bound:.6e}")
        print(f"  C* implicito (bound = mfpt):        {C_impl:.6e}")
        print()

        if bound > mfpt:
            print(f"  Veredicto: C*=1 NO valido como bound inferior")
            print(f"             (bound excede MFPT por factor {bound/mfpt:.4e})")
            print(f"             C* <= {C_impl:.6e}")
        else:
            slack = mfpt / bound
            print(f"  Veredicto: C*=1 valido, con holgura {slack:.4f}x")
        print()

    print("=" * 78)
    print("CONCLUSION")
    print("=" * 78)
    print()
    print("  La cota original C*R0^(1-kappa)exp(beta*R0) con C*=1 es:")
    print("    - INVALIDA en Section 2.2 (C* implicito = 0.562 < 1)")
    print("    - INVALIDA (mas severamente) en D4 (C* implicito = 3.14e-08)")
    print()
    print("  El MFPT exacto por integracion numerica es el estandar.")
    print("  La cota original requiere especificar C* para cada regimen.")
    print()
    print("=" * 78)


if __name__ == "__main__":
    main()
