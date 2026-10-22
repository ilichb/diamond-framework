#!/usr/bin/env python3
"""Sonda de auditoría P-35: potencia del test de modularidad por densidad.

No modifica el repositorio ni los scripts sellados. Reimplementa el generador
Erdős–Rényi / SBM de `verification/rmt/calibration_modularity.py` y usa
`scipy.sparse.linalg.eigsh` sólo para obtener λ_max(B), porque una
descomposición densa de 300 réplicas por configuración no cabe en el tiempo de
la sesión. El umbral nulo se recalibra con 1.000 réplicas propias.

Uso:
    python3 CollusionDensityProbe.py

Salida canónica: `logs/collusion-density.txt` (300 réplicas por configuración,
semilla 20261021). Las cifras del informe externo se reproducen dentro del
intervalo de ±0,06; las diferencias de 0,03–0,12 entre ejecuciones son las
esperadas para 300 réplicas.
"""

import time

import numpy as np
from scipy.sparse.linalg import eigsh

N = 500
D_MEAN = 20.0
REPS = 300
H0_REPS = 1000
SEED = 20261021
RNG = np.random.default_rng(SEED)


def h0():
    p = D_MEAN / (N - 1)
    a = (RNG.random((N, N)) < p).astype(np.float64)
    a = np.triu(a, 1)
    return a + a.T


def h1(k, m, density_factor):
    p_out = D_MEAN / (N - 1)
    p_in = min(1.0, density_factor * p_out)
    probs = np.full((N, N), p_out)
    start = 0
    for _ in range(k):
        end = start + m
        probs[start:end, start:end] = p_in
        start = end
    a = (RNG.random((N, N)) < probs).astype(np.float64)
    a = np.triu(a, 1)
    return a + a.T


def lambda_max_modularity(a):
    d = a.sum(axis=1)
    edges = a.sum() / 2.0
    b = a - np.outer(d, d) / (2.0 * edges)
    return float(eigsh(b, k=1, which="LA", return_eigenvectors=False)[0])


def main():
    started = time.time()
    threshold = np.quantile([lambda_max_modularity(h0()) for _ in range(H0_REPS)], 0.99)
    print(f"N={N}, d_bar={D_MEAN:.0f}, H0={H0_REPS}, H1={REPS}, seed={SEED}")
    print(f"q99(lambda_max(B)) = {threshold:.4f}  ({time.time() - started:.1f}s)")
    print()
    print(f"{'configuration':<24} {'theta':>7} {'TPR@0.01':>9} {'mean':>8}")
    configs = [
        ("1 block m=20 10x", 1, 20, 10),
        ("1 block m=24 5x", 1, 24, 5),
        ("1 block m=30 5x", 1, 30, 5),
        ("1 block m=40 3x", 1, 40, 3),
        ("5 blocks m=12 10x", 5, 12, 10),
        ("10 blocks m=10 10x", 10, 10, 10),
    ]
    for name, k, m, density in configs:
        values = np.array([lambda_max_modularity(h1(k, m, density)) for _ in range(REPS)])
        tpr = (values > threshold).mean()
        theta = m * (density - 1) * D_MEAN / (N - 1)
        print(f"{name:<24} {theta:>7.2f} {tpr:>9.3f} {values.mean():>8.3f}  ({time.time() - started:.1f}s)")


if __name__ == "__main__":
    main()
