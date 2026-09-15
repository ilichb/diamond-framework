#!/usr/bin/env python3
"""
calibration_roc.py — Calibración del test de colusión RMT del Diamond Framework.

Genera grafos bajo H0 (sin colusión) y H1 (con cliques plantados) usando
Stochastic Block Model, y mide:
  1. Distribución nula de λ₂(A_sym) y λ_min(A_sym).
  2. Distribución bajo H1 con distintos tamaños de clique.
  3. Curvas ROC: potencia vs falsos positivos.
  4. Umbral empírico para α = 0.01 y 0.05.
  5. Comparación contra Tracy-Widom teórico.

Uso:
    python3 calibration_roc.py

Salida:
    Tabla de umbrales, AUC, y potencia para configuraciones representativas.
"""

import numpy as np
from dataclasses import dataclass


# ------------------------------------------------------------------
# Parámetros
# ------------------------------------------------------------------
N = 500                    # número de validadores
D_MEAN = 20                # grado promedio bajo H0
N_REPLICATES = 30          # replicaciones Monte Carlo por configuración (súper rápido)
ALPHAS = [0.01, 0.05]      # niveles de significancia
RNG_SEED = 42


# ------------------------------------------------------------------
# Generación de grafos (pure numpy)
# ------------------------------------------------------------------
def generate_h0_graph(n, d_mean, rng):
    """Erdős-Rényi con grado promedio d_mean."""
    p = d_mean / (n - 1)
    A = (rng.random((n, n)) < p).astype(float)
    A = np.triu(A, 1)
    return A + A.T


def generate_h1_clique_graph(n, d_mean, k_cliques, clique_size, rng):
    """
    Modelo de bloque estocástico con k cliques de tamaño clique_size.
    Los nodos dentro de un clique se conectan con probabilidad p_in > p_out.
    El resto del grafo se conecta con probabilidad p_out.
    """
    if k_cliques * clique_size >= n:
        raise ValueError("k_cliques * clique_size >= n")

    p_out = d_mean / (n - 1)
    p_in = min(1.0, 10 * p_out)

    P = np.full((n, n), p_out)
    start = 0
    for i in range(k_cliques):
        end = start + clique_size
        P[start:end, start:end] = p_in
        start = end

    A = (rng.random((n, n)) < P).astype(float)
    np.fill_diagonal(A, 0)
    A = np.triu(A, 1)
    return A + A.T


# ------------------------------------------------------------------
# Espectro
# ------------------------------------------------------------------
def compute_spectrum(A):
    """
    Devuelve λ₂(A_sym) y λ_min(A_sym) para la matriz de adyacencia A.
    A_sym = D^{-1/2} A D^{-1/2}.
    """
    d = A.sum(axis=1)
    d_safe = np.where(d > 0, d, 1.0)
    D_inv_sqrt = np.diag(1.0 / np.sqrt(d_safe))
    A_sym = D_inv_sqrt @ A @ D_inv_sqrt

    eigs = np.linalg.eigvalsh(A_sym)  # ordenados ascendente
    mu_min = eigs[0]
    mu_2max = eigs[-2]  # segundo autovalor más grande
    return mu_min, mu_2max


# ------------------------------------------------------------------
# Estadísticos del test
# ------------------------------------------------------------------
def statistic_right(mu_2max, bulk_edge):
    """Cola derecha: detecta cliques."""
    return (mu_2max - bulk_edge) / (1.0 - bulk_edge)


def statistic_left(mu_min, bulk_edge):
    """Cola izquierda: detecta bipartitos."""
    return (-mu_min - bulk_edge) / (1.0 - bulk_edge)


# ------------------------------------------------------------------
# Monte Carlo
# ------------------------------------------------------------------
@dataclass
class Distribution:
    name: str
    stat_right: np.ndarray
    stat_left: np.ndarray


def run_monte_carlo(configs):
    """Ejecuta N_REPLICATES por configuración y devuelve las distribuciones."""
    rng = np.random.default_rng(RNG_SEED)
    results = []
    bulk_edge = 2.0 / np.sqrt(D_MEAN)

    for name, gen_fn in configs:
        stats_right = []
        stats_left = []
        for _ in range(N_REPLICATES):
            G = gen_fn(rng)
            mu_min, mu_2max = compute_spectrum(G)
            stats_right.append(statistic_right(mu_2max, bulk_edge))
            stats_left.append(statistic_left(mu_min, bulk_edge))
        results.append(
            Distribution(
                name=name,
                stat_right=np.array(stats_right),
                stat_left=np.array(stats_left),
            )
        )
    return results


# ------------------------------------------------------------------
# Umbrales y ROC
# ------------------------------------------------------------------
def empirical_thresholds(h0_dist, alphas):
    """Umbrales empíricos para las colas derecha e izquierda."""
    thresholds = {}
    for alpha in alphas:
        # Cola derecha: cuantil (1-alpha)
        t_r = np.quantile(h0_dist.stat_right, 1 - alpha)
        # Cola izquierda: cuantil alpha (más negativo = más anómalo)
        t_l = np.quantile(h0_dist.stat_left, alpha)
        thresholds[alpha] = (t_r, t_l)
    return thresholds


def roc_curves(h0_dist, h1_dist):
    """Curvas ROC para ambas colas."""
    # Cola derecha
    all_scores = np.concatenate([h0_dist.stat_right, h1_dist.stat_right])
    labels = np.concatenate([np.zeros(len(h0_dist.stat_right)),
                              np.ones(len(h1_dist.stat_right))])
    order = np.argsort(-all_scores)
    labels_sorted = labels[order]
    tpr_r = np.cumsum(labels_sorted) / labels_sorted.sum()
    fpr_r = np.cumsum(1 - labels_sorted) / (1 - labels_sorted).sum()

    # Cola izquierda (más negativo = más anómalo, invertir signo)
    all_scores_l = np.concatenate([-h0_dist.stat_left, -h1_dist.stat_left])
    order_l = np.argsort(-all_scores_l)
    labels_l = labels[order_l]
    tpr_l = np.cumsum(labels_l) / labels_l.sum()
    fpr_l = np.cumsum(1 - labels_l) / (1 - labels_l).sum()

    return (fpr_r, tpr_r), (fpr_l, tpr_l)


def auc(fpr, tpr):
    """Área bajo la curva ROC por regla del trapecio."""
    return np.trapz(tpr, fpr)


# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------
def main():
    print("=" * 78)
    print("CALIBRACIÓN RMT — TEST DE COLUSIÓN DEL DIAMOND FRAMEWORK")
    print("=" * 78)
    print()
    print(f"Parámetros: N={N}, d̄={D_MEAN}, replicaciones={N_REPLICATES}")
    print(f"Bulk edge teórico (A_sym): 2/√d̄ = {2/np.sqrt(D_MEAN):.4f}")
    print()

    # Configuraciones
    configs = [
        ("H0 (ER)", lambda rng: generate_h0_graph(N, D_MEAN, rng)),
        ("H1 clique k=1 m=20", lambda rng: generate_h1_clique_graph(N, D_MEAN, 1, 20, rng)),
        ("H1 clique k=3 m=20", lambda rng: generate_h1_clique_graph(N, D_MEAN, 3, 20, rng)),
        ("H1 clique k=5 m=20", lambda rng: generate_h1_clique_graph(N, D_MEAN, 5, 20, rng)),
        ("H1 clique k=3 m=40", lambda rng: generate_h1_clique_graph(N, D_MEAN, 3, 40, rng)),
    ]

    print("Ejecutando Monte Carlo...")
    results = run_monte_carlo(configs)
    h0 = results[0]

    print()
    print("1. DISTRIBUCIÓN NULA (H0)")
    print("-" * 78)
    print(f"   τ⁺ (cola derecha): media={h0.stat_right.mean():.4f}, "
          f"std={h0.stat_right.std():.4f}")
    print(f"   τ⁻ (cola izquierda): media={h0.stat_left.mean():.4f}, "
          f"std={h0.stat_left.std():.4f}")
    print()

    print("2. UMBRALES EMPÍRICOS (α = 0.01, 0.05)")
    print("-" * 78)
    thresholds = empirical_thresholds(h0, ALPHAS)
    for alpha in ALPHAS:
        t_r, t_l = thresholds[alpha]
        print(f"   α={alpha}: τ⁺ > {t_r:.4f}  |  τ⁻ < {t_l:.4f}")
    print()

    print("3. ROC Y AUC (cola derecha, cliques)")
    print("-" * 78)
    print(f"   {'Configuración':<28} {'AUC':>8} {'TPR@FPR=0.01':>15} {'TPR@FPR=0.05':>15}")
    print(f"   {'-'*28} {'-'*8} {'-'*15} {'-'*15}")
    for h1 in results[1:]:
        (fpr, tpr), _ = roc_curves(h0, h1)
        a = auc(fpr, tpr)
        # TPR al FPR más cercano a 0.01 y 0.05
        def tpr_at_fpr(target_fpr):
            idx = np.argmin(np.abs(fpr - target_fpr))
            return tpr[idx]
        print(f"   {h1.name:<28} {a:>8.4f} "
              f"{tpr_at_fpr(0.01):>15.4f} {tpr_at_fpr(0.05):>15.4f}")
    print()

    print("4. COMPARACIÓN CONTRA TRACY-WIDOM TEÓRICO")
    print("-" * 78)
    # Tracy-Widom F1: cuantiles aproximados
    # TW1: F^{-1}(0.99) ≈ 0.45, F^{-1}(0.95) ≈ -0.23
    tw_alpha01 = 0.45
    tw_alpha05 = -0.23
    print(f"   TW1 teórico: F⁻¹(0.99) ≈ {tw_alpha01:.2f}, F⁻¹(0.95) ≈ {tw_alpha05:.2f}")
    for alpha in ALPHAS:
        t_r, _ = thresholds[alpha]
        print(f"   Empírico α={alpha}: τ̂ = {t_r:.4f}")
    print()
    print("   Nota: los umbrales empíricos están normalizados por (1 - bulk_edge),")
    print("   no por la fluctuación Tracy-Widom. Para comparación directa,")
    print("   habría que reescalar por σ_n = n^{-2/3} · factor de corrección.")
    print()

    print("=" * 78)
    print("5. VEREDICTO")
    print("=" * 78)
    # Veredicto basado en AUC de configuraciones representativas
    for h1 in results[1:]:
        (fpr, tpr), _ = roc_curves(h0, h1)
        a = auc(fpr, tpr)
        if a > 0.95:
            verdict = "DETECTABLE"
        elif a > 0.75:
            verdict = "PARCIALMENTE DETECTABLE"
        else:
            verdict = "INDETECTABLE"
        print(f"   {h1.name:<28} AUC={a:.4f}  →  {verdict}")
    print()
    print("   Los cliques con k·m²/n grande son detectables; los pequeños,")
    print("   no. El teorema de imposibilidad Kesten-Stigum fija el límite")
    print("   inferior. La colusión furtiva por debajo de ese límite debe")
    print("   abordarse en la capa económica, no en el test espectral.")
    print()
    print("=" * 78)


if __name__ == "__main__":
    main()