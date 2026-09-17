#!/usr/bin/env python3
"""
clique_spectra.py — Espectros de W, A_sym, B para un grafo con clique
plantado.

Verifica la afirmacion de la Seccion 5.2: la matriz de adyacencia cruda
W detecta un clique, la matriz de adyacencia normalizada A_sym no, y la
matriz de modularidad B si.

Parametros:
  n = 500, d_bar = 20
  clique: k=1, m=20, densidad intra 10x la de fondo
  seed = 42
"""

import numpy as np

RNG_SEED = 42
N = 500
D_BAR = 20


def generate_h0(n, d_bar, rng):
    p = d_bar / (n - 1)
    A = (rng.random((n, n)) < p).astype(np.float64)
    A = np.triu(A, 1)
    return A + A.T


def generate_h1(n, d_bar, k_cliques, clique_size, rng, density_factor=10):
    p_out = d_bar / (n - 1)
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


def spectra(A):
    """Devuelve lambda_2(W), lambda_2(A_sym), lambda_2(B)."""
    d = A.sum(axis=1)
    d_safe = np.where(d > 0, d, 1.0)

    # W cruda
    eigs_W = np.linalg.eigvalsh(A)
    lam2_W = np.sort(eigs_W)[-2]

    # A_sym = D^{-1/2} W D^{-1/2}
    D_inv_sqrt = np.diag(1.0 / np.sqrt(d_safe))
    A_sym = D_inv_sqrt @ A @ D_inv_sqrt
    eigs_Asym = np.linalg.eigvalsh(A_sym)
    lam2_Asym = np.sort(eigs_Asym)[-2]

    # B = W - dd^T/(2m)
    m = A.sum() / 2.0
    B = A - np.outer(d, d) / (2.0 * m)
    eigs_B = np.linalg.eigvalsh(B)
    lam2_B = np.sort(eigs_B)[-2]

    return lam2_W, lam2_Asym, lam2_B


def main():
    print("=" * 78)
    print("CLIQUE SPECTRA — W vs A_sym vs B")
    print("=" * 78)
    print()
    print(f"n = {N}, d_bar = {D_BAR}")
    print(f"Clique: k=1, m=20, density 10x background")
    print()

    rng = np.random.default_rng(RNG_SEED)
    A_h0 = generate_h0(N, D_BAR, rng)
    A_h1 = generate_h1(N, D_BAR, 1, 20, rng, density_factor=10)

    lam2_W_h0, lam2_Asym_h0, lam2_B_h0 = spectra(A_h0)
    lam2_W_h1, lam2_Asym_h1, lam2_B_h1 = spectra(A_h1)

    bulk_edge_W = 2 * np.sqrt(D_BAR)
    bulk_edge_Asym = 2 / np.sqrt(D_BAR)
    bulk_edge_B = 2 * np.sqrt(D_BAR)

    print(f"{'Matrix':<12} {'lambda_2 (H0)':>15} {'lambda_2 (H1)':>15} "
          f"{'bulk edge':>12} {'gap (H1)':>10}")
    print("-" * 78)
    print(f"{'W':<12} {lam2_W_h0:>15.4f} {lam2_W_h1:>15.4f} "
          f"{bulk_edge_W:>12.4f} {lam2_W_h1 - bulk_edge_W:>10.4f}")
    print(f"{'A_sym':<12} {lam2_Asym_h0:>15.4f} {lam2_Asym_h1:>15.4f} "
          f"{bulk_edge_Asym:>12.4f} {lam2_Asym_h1 - bulk_edge_Asym:>10.4f}")
    print(f"{'B':<12} {lam2_B_h0:>15.4f} {lam2_B_h1:>15.4f} "
          f"{bulk_edge_B:>12.4f} {lam2_B_h1 - bulk_edge_B:>10.4f}")
    print()

    print("=" * 78)
    print("INTERPRETATION")
    print("=" * 78)
    print()
    print(f"W:     gap H1 vs bulk edge = {lam2_W_h1 - bulk_edge_W:+.4f}")
    print(f"       H1 lambda_2 = {lam2_W_h1:.4f} vs H0 = {lam2_W_h0:.4f}")
    print(f"A_sym: gap H1 vs bulk edge = {lam2_Asym_h1 - bulk_edge_Asym:+.4f}")
    print(f"       H1 lambda_2 = {lam2_Asym_h1:.4f} vs H0 = {lam2_Asym_h0:.4f}")
    print(f"B:     gap H1 vs bulk edge = {lam2_B_h1 - bulk_edge_B:+.4f}")
    print(f"       H1 lambda_2 = {lam2_B_h1:.4f} vs H0 = {lam2_B_h0:.4f}")
    print()


if __name__ == "__main__":
    main()
