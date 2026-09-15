"""
Reproduce el contraejemplo del Revisor 2 (Regla 3): dos tensores de reputacion con
la MISMA norma de Frobenius pero riesgo real distinto (uno diversificado entre cadenas,
otro concentrado en una sola cadena), y chequea si el agregador log propuesto en el
Fix 3 (C_R(T) = sum w_cdh * log(1+T_cdh)) efectivamente los distingue donde la norma
de Frobenius no puede.
"""
import numpy as np

# --- Parametros: mismas dimensiones que usa el paper en la Proposicion 5.4 ---
C, D, H = 20, 5, 5
target_norm = 1.0  # presupuesto de "masa" de reputacion, unidades arbitrarias
# -------------------------------------------------------------------------------

N_total = C * D * H
k_concentrated = D * H  # celdas de una sola cadena (concentracion total en 1 de 20)


def frobenius_norm(T):
    return np.sqrt((T ** 2).sum())


def log_aggregator(T, w=None):
    if w is None:
        w = np.ones_like(T)
    return (w * np.log1p(T)).sum()


def build_diversified(total_norm, n_cells):
    v = total_norm / np.sqrt(n_cells)
    return np.full(n_cells, v)


def build_concentrated(total_norm, n_cells_active):
    v = total_norm / np.sqrt(n_cells_active)
    return np.full(n_cells_active, v)


if __name__ == "__main__":
    T1 = build_diversified(target_norm, N_total)          # esparcido en las 20 cadenas
    T2 = build_concentrated(target_norm, k_concentrated)  # concentrado en 1 sola cadena

    print("=== Contraejemplo T1 (diversificado) vs T2 (concentrado en 1 cadena) ===")
    print(f"Dimensiones: C={C}, D={D}, H={H}, norma objetivo: {target_norm}")
    print()
    print(f"T1: {N_total} celdas activas, valor por celda = {T1[0]:.6f}")
    print(f"T2: {k_concentrated} celdas activas (1 cadena), valor por celda = {T2[0]:.6f}")
    print()
    print(f"||T1||_F = {frobenius_norm(T1):.6f}")
    print(f"||T2||_F = {frobenius_norm(T2):.6f}")
    print("-> Si son iguales, la norma de Frobenius NO distingue diversificacion de "
          "concentracion (el punto de la Regla 3).")
    print()
    print(f"C_R log-aggregator(T1) = {log_aggregator(T1):.6f}")
    print(f"C_R log-aggregator(T2) = {log_aggregator(T2):.6f}")
    if log_aggregator(T1) > log_aggregator(T2):
        print("-> El agregador log SI penaliza la concentracion (T1 > T2), "
              "consistente con lo que afirma el Fix 3.")
    else:
        print("-> El agregador log NO distingue en este caso: revisar el Fix 3.")
