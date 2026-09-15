"""
Verifica la Regla 1 / Fix 1: si el SDE de reputacion original (saltos aditivos,
Definicion 4.1) rompe la positividad de R(t), y si el Fix 1 (saltos multiplicativos)
lo resuelve.

IMPORTANTE: los parametros abajo son un ejemplo razonable que cumple Feller, NO los
parametros reales del sistema (el paper no los fija). Cambialos por los que uses en
produccion antes de citar el resultado como definitivo.
"""
import numpy as np

rng = np.random.default_rng(42)

# --- Parametros: AJUSTAR a los valores reales antes de confiar en el numero ---
alpha = 0.5          # velocidad de reversion a la media
Rbar = 1.0           # media de largo plazo
sigma0 = 0.8         # volatilidad
lam = 0.8            # tasa de Poisson (eventos de slashing por unidad de tiempo)
jump_mean = 0.15     # magnitud media del salto (ver nota abajo por tipo de salto)
R0 = 0.3             # reputacion inicial
T = 5.0              # horizonte de simulacion
dt = 0.001           # paso de tiempo (Euler-Maruyama)
n_paths = 100_000    # numero de trayectorias Monte Carlo
# -------------------------------------------------------------------------------

assert 2 * alpha * Rbar >= sigma0 ** 2, "Feller no se cumple con estos parametros"
n_steps = int(T / dt)


def simulate_additive():
    """SDE original: salto aditivo R -> R - Exp(jump_mean) por evento de Poisson."""
    R = np.full(n_paths, R0)
    went_negative = np.zeros(n_paths, dtype=bool)
    for _ in range(n_steps):
        alive = ~went_negative
        if not alive.any():
            break
        Rpos = np.clip(R, 0, None)
        dW = rng.normal(0, np.sqrt(dt), size=n_paths)
        drift = alpha * (Rbar - R) * dt
        diff = sigma0 * np.sqrt(Rpos) * dW
        n_jumps = rng.poisson(lam * dt, size=n_paths)
        jump_sizes = np.zeros(n_paths)
        has_jump = n_jumps > 0
        if has_jump.any():
            jump_sizes[has_jump] = -rng.exponential(
                jump_mean, size=has_jump.sum()
            ) * n_jumps[has_jump]
        R_new = R + drift + diff + jump_sizes
        went_negative |= (R_new < 0) & alive
        R = R_new
    return went_negative.mean()


def simulate_multiplicative():
    """Fix 1: salto multiplicativo R -> R * y, y ~ U(0.5, 1] por evento (soporte acotado)."""
    R = np.full(n_paths, R0)
    min_R = R.copy()
    for _ in range(n_steps):
        Rpos = np.clip(R, 0, None)
        dW = rng.normal(0, np.sqrt(dt), size=n_paths)
        drift = alpha * (Rbar - R) * dt
        diff = sigma0 * np.sqrt(Rpos) * dW
        n_jumps = rng.poisson(lam * dt, size=n_paths)
        has_jump = n_jumps > 0
        R_new = np.clip(R + drift + diff, 0, None)
        if has_jump.any():
            y = rng.uniform(0.5, 1.0, size=has_jump.sum()) ** n_jumps[has_jump]
            R_new[has_jump] = R_new[has_jump] * y
        R = R_new
        min_R = np.minimum(min_R, R)
    return (min_R < 0).mean(), min_R.min()


if __name__ == "__main__":
    print("=== Verificacion de positividad: SDE original vs Fix 1 ===")
    print(f"Parametros: alpha={alpha}, Rbar={Rbar}, sigma0={sigma0}, lambda={lam}, "
          f"jump_mean={jump_mean}, R0={R0}, T={T}, paths={n_paths}")
    print()
    frac_additive = simulate_additive()
    print(f"SDE original (saltos aditivos): {frac_additive:.4%} de trayectorias tocan R<0")
    frac_mult, min_val = simulate_multiplicative()
    print(f"Fix 1 (saltos multiplicativos):  {frac_mult:.6%} de trayectorias tocan R<0 "
          f"(min observado: {min_val:.6f})")
