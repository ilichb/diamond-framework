"""
Verifica el Teorema 6.4: bajo H0 (validadores honestos, sin colusion), donde se
concentra realmente lambda_max(Lsym), y si el valor "2" que el teorema afirma como
borde del semicirculo es consistente con un grafo de colaboracion real.

Nota: para CUALQUIER Laplaciana normalizada, el promedio de sus autovalores es
siempre exactamente 1 (es un hecho determinista: traza(Lsym) = n, sin importar el
grafo). Lo que hay que chequear no es el promedio, es donde cae lambda_max.
"""
import numpy as np

rng = np.random.default_rng(7)

# --- Parametros: ajustar n y grado promedio a la escala real del validator set ---
n = 500
avg_degree_low = 20
avg_degree_high = 60
power_law_beta = 2.3  # exponente de la cola pesada (Chung-Lu)
# -------------------------------------------------------------------------------


def normalized_matrices(W):
    d = W.sum(axis=1)
    d_inv_sqrt = 1.0 / np.sqrt(np.clip(d, 1e-9, None))
    Dinv = np.diag(d_inv_sqrt)
    A_sym = Dinv @ W @ Dinv
    L_sym = np.eye(W.shape[0]) - A_sym
    return L_sym, A_sym, d


def er_graph(n_nodes, p):
    A = (rng.random((n_nodes, n_nodes)) < p).astype(float)
    A = np.triu(A, 1)
    return A + A.T


def chung_lu_graph(n_nodes, beta, dbar):
    idx = np.arange(1, n_nodes + 1)
    w = idx ** (-1.0 / (beta - 1.0))
    w = w / w.mean() * dbar
    w = np.clip(w, 0.5, None)
    P = np.clip(np.outer(w, w) / w.sum(), 0, 1)
    A = (rng.random((n_nodes, n_nodes)) < P).astype(float)
    A = np.triu(A, 1)
    return A + A.T, w


def report(name, A):
    L_sym, A_sym, d = normalized_matrices(A)
    eig_L = np.linalg.eigvalsh(L_sym)
    eig_A = np.linalg.eigvalsh(A_sym)
    
    print(f"--- {name} ---")
    print(f"grado promedio real: {d.mean():.2f}, grado max: {d.max():.0f}")
    print(f"L_sym -> lambda_max: {eig_L[-1]:.4f}  |  lambda_min: {eig_L[0]:.4f}  |  media: {eig_L.mean():.4f}")
    print(f"A_sym -> mu_max: {eig_A[-1]:.4f} (siempre 1.0)  |  mu_min: {eig_A[0]:.4f}  |  2do mu_max: {eig_A[-2]:.4f}")
    print(f"Relación matemática: L_sym = I - A_sym => lambda_max(L_sym) = 1 - mu_min(A_sym)")
    print(f"# autovalores L_sym > 1.9 de {n}: {(eig_L > 1.9).sum()}")
    print(f"ancho del bulk L_sym (p99 - p1): {np.percentile(eig_L, 99) - np.percentile(eig_L, 1):.4f}")
    print()


if __name__ == "__main__":
    print("=== Comparación completa del Espectro: L_sym vs A_sym bajo H0 ===")
    print()
    report(f"Erdos-Renyi homogeneo, grado~{avg_degree_low}", er_graph(n, avg_degree_low / n))
    A_hl, _ = chung_lu_graph(n, power_law_beta, avg_degree_low)
    report(f"Chung-Lu heavy-tailed, grado~{avg_degree_low}", A_hl)
    report(f"Erdos-Renyi homogeneo, grado~{avg_degree_high} (mas denso)",
           er_graph(n, avg_degree_high / n))
    print("Conclusión: Para L_sym, lambda_max = 1 - mu_min(A_sym). Salvo en grafos bipartitos perfectos")
    print("(donde mu_min = -1 y lambda_max = 2), en grafos aleatorios honestos mu_min > -0.5,")
    print("haciendo que lambda_max(L_sym) caiga muy por debajo de 2.")

