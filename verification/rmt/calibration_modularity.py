#!/usr/bin/env python3
"""
calibration_modularity.py — Calibración del test de colusión usando
la matriz de modularidad B = W - dd^T/(2m).

Sin networkx. Generación directa con numpy. Replicas suficientes para
intervalos de confianza estrechos a α=0.01.
"""

import numpy as np

N = 500
D_MEAN = 20
N_REPLICATES_H0 = 2000
N_REPLICATES_H1 = 500
RNG_SEED = 42
ALPHAS = [0.01, 0.05]


def generate_h0(n, d_mean, rng):
    """Erdős–Rényi con grado promedio d_mean, matriz simétrica sin diagonal."""
    p = d_mean / (n - 1)
    A = (rng.random((n, n)) < p).astype(np.float64)
    A = np.triu(A, 1)
    return A + A.T


def generate_h1(n, d_mean, k_cliques, clique_size, rng, density_factor=10):
    """SBM con k cliques densos y fondo Erdős–Rényi."""
    p_out = d_mean / (n - 1)
    p_in = min(1.0, density_factor * p_out)
    P = np.full((n, n), p_out)
    start = 0
    for _ in range(k_cliques):
        end = start + clique_size
        P[start:end, start:end] = p_in
        start = end
    A = (rng.random((n, n)) < P).astype(np.float64)
    A = np.triu(A, 1)
    return A + A.T


def modularity_spectrum(A):
    """Espectro de B = A - dd^T/(2m), ordenado ascendente."""
    d = A.sum(axis=1)
    m = A.sum() / 2.0
    if m == 0:
        return np.zeros(len(A))
    B = A - np.outer(d, d) / (2.0 * m)
    return np.linalg.eigvalsh(B)


def top_two(eigs):
    """Segundo más grande (positivo) y más negativo."""
    s = np.sort(eigs)
    return s[-2], s[0]


def run():
    rng = np.random.default_rng(RNG_SEED)
    bulk_edge = 2.0 * np.sqrt(D_MEAN)

    print("=" * 78)
    print("CALIBRACIÓN CON MATRIZ DE MODULARIDAD B = W - dd^T/(2m)")
    print("=" * 78)
    print(f"N={N}, d̄={D_MEAN}, bulk edge teórico: 2√d̄ = {bulk_edge:.4f}")
    print(f"H0 replicas: {N_REPLICATES_H0}, H1 replicas: {N_REPLICATES_H1}")
    print()

    # H0: distribución nula
    print("Corriendo H0...")
    h0_pos = np.empty(N_REPLICATES_H0)
    h0_neg = np.empty(N_REPLICATES_H0)
    for i in range(N_REPLICATES_H0):
        A = generate_h0(N, D_MEAN, rng)
        eigs = modularity_spectrum(A)
        lam2, lam_min = top_two(eigs)
        h0_pos[i] = lam2
        h0_neg[i] = -lam_min

    print(f"   λ₂(B):    media={h0_pos.mean():.4f}, std={h0_pos.std():.4f}, "
          f"q99={np.quantile(h0_pos, 0.99):.4f}")
    print(f"   -λ_min(B): media={h0_neg.mean():.4f}, std={h0_neg.std():.4f}, "
          f"q99={np.quantile(h0_neg, 0.99):.4f}")
    print()

    thresholds = {}
    for alpha in ALPHAS:
        t_pos = np.quantile(h0_pos, 1 - alpha)
        t_neg = np.quantile(h0_neg, 1 - alpha)
        thresholds[alpha] = (t_pos, t_neg)
        print(f"   Umbral α={alpha}: λ₂(B) > {t_pos:.4f}  ó  -λ_min(B) > {t_neg:.4f}")
    print()

    # H1: potencia por configuración
    configs = [
        ("k=1 m=20", 1, 20),
        ("k=3 m=20", 3, 20),
        ("k=5 m=20", 5, 20),
        ("k=1 m=40", 1, 40),
        ("k=3 m=40", 3, 40),
    ]

    print("POTENCIA DEL TEST (cola derecha, λ₂(B))")
    print("-" * 78)
    print(f"{'Config':<12} {'λ₂ medio':>10} {'TPR@0.01':>12} {'TPR@0.05':>12} "
          f"{'CI95 TPR@0.01':>18}")
    print("-" * 78)

    for name, k, m in configs:
        h1_pos = np.empty(N_REPLICATES_H1)
        for i in range(N_REPLICATES_H1):
            A = generate_h1(N, D_MEAN, k, m, rng)
            eigs = modularity_spectrum(A)
            lam2, _ = top_two(eigs)
            h1_pos[i] = lam2

        t01 = thresholds[0.01][0]
        t05 = thresholds[0.05][0]
        tpr01 = (h1_pos > t01).mean()
        tpr05 = (h1_pos > t05).mean()

        # IC 95% por Wilson
        n = len(h1_pos)
        z = 1.96
        denom = 1 + z**2 / n
        center = (tpr01 + z**2 / (2 * n)) / denom
        margin = z * np.sqrt(tpr01 * (1 - tpr01) / n + z**2 / (4 * n**2)) / denom
        ci_lo = max(0.0, center - margin)
        ci_hi = min(1.0, center + margin)

        print(f"{name:<12} {h1_pos.mean():>10.4f} {tpr01:>12.4f} {tpr05:>12.4f} "
              f"  [{ci_lo:.3f}, {ci_hi:.3f}]")

    print()
    print("=" * 78)
    print("NOTA: la matriz de modularidad se comporta como se espera para")
    print("cliques k≥3, m=20 (TPR ≈ 1). Para k=1, m=20 la detección es")
    print("parcial y el CI es informativo.")
    print("=" * 78)


if __name__ == "__main__":
    run()