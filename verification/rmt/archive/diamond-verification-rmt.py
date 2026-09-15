#!/usr/bin/env python3
"""
diagnostic_wsym_vs_w.py — Compara detección de cliques en W cruda vs A_sym.
"""
import numpy as np

def generate_h0(n, d_mean, rng):
    p = d_mean / (n - 1)
    A = (rng.random((n, n)) < p).astype(float)
    A = np.triu(A, 1)
    return A + A.T

def generate_h1(n, d_mean, k_cliques, clique_size, rng):
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

def spectra(A):
    d = A.sum(axis=1)
    d_safe = np.where(d > 0, d, 1.0)
    D_inv_sqrt = np.diag(1.0 / np.sqrt(d_safe))
    A_sym = D_inv_sqrt @ A @ D_inv_sqrt
    eig_W = np.linalg.eigvalsh(A)
    eig_Asym = np.linalg.eigvalsh(A_sym)
    return eig_W, eig_Asym

def main():
    n, d_mean = 500, 20
    rng = np.random.default_rng(42)
    print(f"n={n}, d̄={d_mean}")
    print(f"{'Config':<28} {'λ₂(W)':>10} {'λ₂(A_sym)':>12} {'gap W':>10} {'gap A_sym':>12}")
    print("-" * 76)
    for name, k, m in [
        ("H0", 0, 0),
        ("H1 k=1 m=20", 1, 20),
        ("H1 k=3 m=20", 3, 20),
        ("H1 k=5 m=20", 5, 20),
        ("H1 k=3 m=40", 3, 40),
    ]:
        if k == 0:
            A = generate_h0(n, d_mean, rng)
        else:
            A = generate_h1(n, d_mean, k, m, rng)
        eig_W, eig_Asym = spectra(A)
        # Para W: eigenvalor máximo = Perron, segundo = λ₂
        lam2_W = np.sort(eig_W)[-2]
        lam2_Asym = np.sort(eig_Asym)[-2]
        # Gap con el bulk
        gap_W = lam2_W - 2 * np.sqrt(d_mean)
        gap_Asym = lam2_Asym - 2 / np.sqrt(d_mean)
        print(f"{name:<28} {lam2_W:>10.4f} {lam2_Asym:>12.4f} "
              f"{gap_W:>10.4f} {gap_Asym:>12.4f}")

if __name__ == "__main__":
    main()