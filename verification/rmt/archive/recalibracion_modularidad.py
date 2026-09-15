#!/usr/bin/env python3
"""
calibration_modularity.py — Calibración del test de colusión usando
la matriz de modularidad B = W - dd^T/(2m) en lugar de A_sym.

Motivación: A_sym enmascara cliques densos porque la normalización
por grado atenúa las aristas intra-clique. W cruda detecta pero su
bulk no es Wigner bajo H0 para grafos heavy-tailed. La modularidad
elimina el sesgo de grado por construcción y su bulk es Wigner
centrado en 0.
"""

import numpy as np


N = 500
D_MEAN = 20
N_REPLICATES_H0 = 2000     # 2000 réplicas para H0 (estimación precisa del cuantil 99%)
N_REPLICATES_H1 = 500      # 500 réplicas por configuración H1 (IC 95% estrecho para TPR)
RNG_SEED = 42
ALPHAS = [0.01, 0.05]


def generate_h0(n, d_mean, rng):
    p = d_mean / (n - 1)
    A = (rng.random((n, n)) < p).astype(float)
    A = np.triu(A, 1)
    return A + A.T


def generate_h1(n, d_mean, k_cliques, clique_size, rng, density_factor=10):
    p_out = d_mean / (n - 1)
    p_in = min(1.0, density_factor * p_out)
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


def modularity_spectrum(A):
    """Devuelve el espectro de B = W - dd^T/(2m), ordenado ascendente."""
    d = A.sum(axis=1)
    m = A.sum() / 2
    if m == 0:
        return np.zeros(len(A))
    B = A - np.outer(d, d) / (2 * m)
    return np.linalg.eigvalsh(B)


def top_two(B_eigs):
    """Segundo eigenvalor más grande (positivo) y el más negativo."""
    sorted_eigs = np.sort(B_eigs)
    return sorted_eigs[-2], sorted_eigs[0]


def run():
    rng = np.random.default_rng(RNG_SEED)
    bulk_edge = 2 * np.sqrt(D_MEAN)

    configs = [
        ("H0", lambda r: generate_h0(N, D_MEAN, r), N_REPLICATES_H0),
        ("H1 k=1 m=20", lambda r: generate_h1(N, D_MEAN, 1, 20, r), N_REPLICATES_H1),
        ("H1 k=3 m=20", lambda r: generate_h1(N, D_MEAN, 3, 20, r), N_REPLICATES_H1),
        ("H1 k=5 m=20", lambda r: generate_h1(N, D_MEAN, 5, 20, r), N_REPLICATES_H1),
        ("H1 k=3 m=40", lambda r: generate_h1(N, D_MEAN, 3, 40, r), N_REPLICATES_H1),
        ("H1 k=1 m=40", lambda r: generate_h1(N, D_MEAN, 1, 40, r), N_REPLICATES_H1),
    ]

    results = {}
    print("Ejecutando calibración de Monte Carlo con tamaño de muestra riguroso...")
    for name, gen, n_reps in configs:
        print(f"  Simulando {name} ({n_reps} réplicas)...")
        positives, negatives = [], []
        for _ in range(n_reps):
            A = gen(rng)
            eigs = modularity_spectrum(A)
            lam2, lam_min = top_two(eigs)
            positives.append(lam2)
            negatives.append(-lam_min)
        results[name] = {
            "pos": np.array(positives),
            "neg": np.array(negatives),
        }

    h0 = results["H0"]
    print("=" * 78)
    print("CALIBRACIÓN CON MATRIZ DE MODULARIDAD B = W - dd^T/(2m)")
    print("=" * 78)
    print(f"N={N}, d̄={D_MEAN}, bulk edge teórico de B: 2√d̄ = {bulk_edge:.4f}")
    print()

    print("1. DISTRIBUCIÓN NULA (H0)")
    print("-" * 78)
    print(f"   λ₂(B):    media = {h0['pos'].mean():.4f}, "
          f"std = {h0['pos'].std():.4f}")
    print(f"   -λ_min(B): media = {h0['neg'].mean():.4f}, "
          f"std = {h0['neg'].std():.4f}")
    print()

    print("2. UMBRALES EMPÍRICOS")
    print("-" * 78)
    thresholds = {}
    for alpha in ALPHAS:
        t_pos = np.quantile(h0["pos"], 1 - alpha)
        t_neg = np.quantile(h0["neg"], 1 - alpha)
        thresholds[alpha] = (t_pos, t_neg)
        print(f"   α={alpha}: λ₂(B) > {t_pos:.4f}  o  -λ_min(B) > {t_neg:.4f}")
    print()

    print("3. DISTRIBUCIONES BAJO H1 Y POTENCIA DEL TEST (cola derecha)")
    print("-" * 78)
    print(f"   {'Configuración':<18} {'λ₂(B) media':>12} "
          f"{'TPR@α=0.01':>12} {'TPR@α=0.05':>12}")
    print(f"   {'-'*18} {'-'*12} {'-'*12} {'-'*12}")
    for name, data in results.items():
        if name == "H0":
            continue
        t_pos_01 = thresholds[0.01][0]
        t_pos_05 = thresholds[0.05][0]
        tpr_01 = (data["pos"] > t_pos_01).mean()
        tpr_05 = (data["pos"] > t_pos_05).mean()
        print(f"   {name:<18} {data['pos'].mean():>12.4f} "
              f"{tpr_01:>12.4f} {tpr_05:>12.4f}")
    print()

    print("4. COMPARACIÓN CON A_sym Y W CRUDA")
    print("-" * 78)
    print("   Si un clique m=20 con densidad 10× es detectable aquí (TPR > 0.9")
    print("   a α=0.01) pero era indetectable en A_sym, la modularidad")
    print("   resuelve el problema. Si además el bulk de B es estable bajo H0")
    print("   (std pequeño), la calibración es fiable.")
    print()

    print("=" * 78)


if __name__ == "__main__":
    run()