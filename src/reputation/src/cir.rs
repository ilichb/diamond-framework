//! The CIR process with multiplicative jumps, transcribed from `sim_positivity.py`.
//!
//! F-001 is the finding this module answers: with the paper's *additive* slashing
//! jump, `R(t)` can leave `[0, ∞)` even when Feller's condition holds, and Fix 1
//! (a multiplicative jump `R → R·y`, `y ∈ [0.5, 1]`) makes non-negativity a
//! property of the specification. The sealed script that produced the numbers is
//! `verification/stochastics/sim_positivity.py` and it is not M6's to edit.
//!
//! The transcription below keeps every semantic decision, and three of them matter
//! enough to be named:
//!
//! | the sealed script | here |
//! |---|---|
//! | `alive = ~went_negative; if not alive.any(): break` | the same mask, the same early exit |
//! | `Rpos = np.clip(R, 0, None)`; `R_new = R + drift + diff + jump_sizes` (no clip) | the same — the additive branch really may go negative |
//! | `R_new = np.clip(R + drift + diff, 0, None)` **before** `*= y` | the same — this is why the multiplicative branch's `0.000000 %` is bounded by construction, not measured |
//! | `y = rng.uniform(0.5, 1.0, size=k) ** n_jumps[has_jump]` | one uniform per jumping path, raised to its jump count |
//! | draws for all `n_paths` (`size=n_paths`), then masked | the same: the dead paths' draws are still consumed |
//!
//! `n_steps = int(T/dt) = 5000` and `n_paths = 100000`, as sealed. What is *not*
//! sealed is the stream: numpy's `normal`/`exponential` are ziggurat
//! ([`crate::numpy`]), so these runs are the same model with a different stream,
//! and the report prints the deviation with its sampling error instead of claiming
//! the sealed digits.

use crate::numpy::Distributions;

/// The sealed parameter block of `sim_positivity.py`.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Params {
    /// Mean-reversion speed `α`.
    pub alpha: f64,
    /// Long-run mean `R̄`.
    pub r_bar: f64,
    /// Volatility `σ₀`.
    pub sigma_0: f64,
    /// Poisson intensity of slashing events `λ` (per unit time).
    pub lam: f64,
    /// Mean additive jump magnitude (the exponential's scale).
    pub jump_mean: f64,
    /// Initial reputation `R₀`.
    pub r0: f64,
    /// Horizon `T`.
    pub t_horizon: f64,
    /// Euler–Maruyama step `dt`.
    pub dt: f64,
    /// Number of Monte Carlo paths.
    pub n_paths: usize,
}

impl Params {
    /// The sealed defaults, verbatim.
    #[must_use]
    pub fn sealed() -> Self {
        Self {
            alpha: 0.5,
            r_bar: 1.0,
            sigma_0: 0.8,
            lam: 0.8,
            jump_mean: 0.15,
            r0: 0.3,
            t_horizon: 5.0,
            dt: 0.001,
            n_paths: 100_000,
        }
    }

    /// A development mode for `--smoke`: the same model, far fewer paths and a
    /// coarser step. Faster by orders of magnitude and **not** pinnable.
    #[must_use]
    pub fn smoke() -> Self {
        Self {
            n_paths: 2_000,
            dt: 0.02,
            ..Self::sealed()
        }
    }

    /// `n_steps = int(T/dt)`, as sealed.
    #[must_use]
    pub fn n_steps(&self) -> usize {
        (self.t_horizon / self.dt) as usize
    }

    /// `λ·dt`: the per-step jump rate the Poisson draw realises.
    #[must_use]
    pub fn jump_rate(&self) -> f64 {
        self.lam * self.dt
    }

    /// Feller's condition `2αR̄ ≥ σ₀²` (`eq:wellcond`), which the sealed script
    /// asserts before simulating.
    #[must_use]
    pub fn feller_holds(&self) -> bool {
        2.0 * self.alpha * self.r_bar >= self.sigma_0.powf(2.0)
    }
}

/// The sealed script multiplies by `n_jumps` as a float
/// (`* n_jumps[has_jump]`) and raises to it as an integer (`** n_jumps[...]`).
#[inline]
#[must_use]
fn jump_count(k: u64) -> f64 {
    k as f64
}

/// The additive branch: the paper's original jump, `R → R − Exp(jump_mean)·N`.
///
/// Returns the fraction of paths that *touched* `R < 0` at any step, i.e.
/// `went_negative.mean()` — not the fraction that ends below zero.
///
/// # Panics
/// If Feller's condition fails, exactly as the sealed script's `assert` does.
#[must_use]
pub fn simulate_additive(p: &Params, rng: &mut Distributions) -> f64 {
    assert!(
        p.feller_holds(),
        "Feller does not hold with these parameters"
    );
    let (n, steps) = (p.n_paths, p.n_steps());
    let sqrt_dt = p.dt.sqrt();
    let mut r = vec![p.r0; n];
    let mut went_negative = vec![false; n];
    let mut alive = n;
    let mut d_w = vec![0.0; n];
    let mut n_jumps = vec![0_u64; n];
    let mut jump_sizes = vec![0.0; n];
    let mut exp_draws: Vec<f64> = Vec::with_capacity(n);
    for _ in 0..steps {
        if alive == 0 {
            break;
        }
        rng.fill_normal(&mut d_w, 0.0, sqrt_dt);
        rng.fill_poisson(&mut n_jumps, p.jump_rate());
        let jumping = n_jumps.iter().filter(|&&k| k > 0).count();
        exp_draws.clear();
        exp_draws.resize(jumping, 0.0);
        rng.fill_exponential(&mut exp_draws, p.jump_mean);
        let mut k = 0;
        for i in 0..n {
            jump_sizes[i] = if n_jumps[i] > 0 {
                let size = -exp_draws[k] * jump_count(n_jumps[i]);
                k += 1;
                size
            } else {
                0.0
            };
        }
        alive = 0;
        for i in 0..n {
            let rpos = if r[i] > 0.0 { r[i] } else { 0.0 };
            let drift = p.alpha * (p.r_bar - r[i]) * p.dt;
            let diff = p.sigma_0 * rpos.sqrt() * d_w[i];
            let r_new = r[i] + drift + diff + jump_sizes[i];
            if r_new < 0.0 && !went_negative[i] {
                went_negative[i] = true;
            }
            r[i] = r_new;
            if !went_negative[i] {
                alive += 1;
            }
        }
    }
    let touched = went_negative.iter().filter(|&&neg| neg).count();
    touched as f64 / n as f64
}

/// Fix 1: the multiplicative jump `R → R·y`, `y = U(0.5, 1]^N`.
///
/// Returns `(fraction of paths whose minimum R went below 0, the minimum R seen)`.
/// The fraction is `0` *by construction* whenever the clip is applied before the
/// multiplicative factor — which is what the sealed script does — so the
/// informative outputs here are the minimum (which must be `≥ 0`) and Feller's
/// condition `2αR̄ ≥ σ₀²`.
///
/// # Panics
/// If Feller's condition fails, exactly as the sealed script's `assert` does.
#[must_use]
pub fn simulate_multiplicative(p: &Params, rng: &mut Distributions) -> (f64, f64) {
    assert!(
        p.feller_holds(),
        "Feller does not hold with these parameters"
    );
    let (n, steps) = (p.n_paths, p.n_steps());
    let sqrt_dt = p.dt.sqrt();
    let mut r = vec![p.r0; n];
    let mut min_r = vec![p.r0; n];
    let mut d_w = vec![0.0; n];
    let mut n_jumps = vec![0_u64; n];
    let mut uniform_draws: Vec<f64> = Vec::with_capacity(n);
    for _ in 0..steps {
        rng.fill_normal(&mut d_w, 0.0, sqrt_dt);
        rng.fill_poisson(&mut n_jumps, p.jump_rate());
        let jumping = n_jumps.iter().filter(|&&k| k > 0).count();
        uniform_draws.clear();
        uniform_draws.resize(jumping, 0.0);
        rng.fill_uniform(&mut uniform_draws, 0.5, 1.0);
        let mut k = 0;
        for i in 0..n {
            let rpos = if r[i] > 0.0 { r[i] } else { 0.0 };
            let drift = p.alpha * (p.r_bar - r[i]) * p.dt;
            let diff = p.sigma_0 * rpos.sqrt() * d_w[i];
            let mut r_new = r[i] + drift + diff;
            if r_new < 0.0 {
                r_new = 0.0;
            }
            if n_jumps[i] > 0 {
                let y = uniform_draws[k].powi(jump_count(n_jumps[i]) as i32);
                k += 1;
                r_new *= y;
            }
            r[i] = r_new;
            if r_new < min_r[i] {
                min_r[i] = r_new;
            }
        }
    }
    let negative = min_r.iter().filter(|&&m| m < 0.0).count();
    let min = min_r.iter().fold(f64::INFINITY, |acc, &m| acc.min(m));
    (negative as f64 / n as f64, min)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A parameter block small enough to run inside a unit test but with exactly
    /// the sealed semantics: no diffusion, no mean reversion, pure jumps.
    fn jumps_only() -> Params {
        Params {
            alpha: 0.0,
            r_bar: 0.0,
            sigma_0: 0.0,
            lam: 1.0,
            jump_mean: 1.0,
            r0: 0.05,
            t_horizon: 5.0,
            dt: 0.5,
            n_paths: 1_000,
        }
    }

    #[test]
    fn the_sealed_parameter_block_is_verbatim() {
        let p = Params::sealed();
        assert_eq!(p.n_steps(), 5_000, "int(T/dt)");
        assert_eq!(
            Params::smoke().n_steps(),
            250,
            "the coarse development step"
        );
        assert!(
            (p.jump_rate() - 0.0008).abs() < f64::EPSILON,
            "lambda*dt = 0.8 * 1e-3"
        );
        assert!(p.feller_holds(), "2*0.5*1.0 >= 0.8^2");
        assert!((2.0 * p.alpha * p.r_bar - p.sigma_0 * p.sigma_0 - 0.36).abs() < 1e-12);
    }

    #[test]
    fn feller_is_a_strict_boundary() {
        let holds = Params {
            sigma_0: 1.0,
            ..Params::smoke()
        };
        assert!(holds.feller_holds(), "2*0.5*1.0 == 1.0");
        let breaks = Params {
            sigma_0: 1.000_001,
            ..Params::smoke()
        };
        assert!(!breaks.feller_holds());
    }

    #[test]
    #[should_panic(expected = "Feller")]
    fn the_additive_branch_refuses_to_run_without_feller() {
        let p = Params {
            sigma_0: 2.0,
            ..Params::smoke()
        };
        let mut rng = Distributions::seeded();
        let _ = simulate_additive(&p, &mut rng);
    }

    #[test]
    #[should_panic(expected = "Feller")]
    fn the_multiplicative_branch_refuses_to_run_without_feller() {
        let p = Params {
            sigma_0: 2.0,
            ..Params::smoke()
        };
        let mut rng = Distributions::seeded();
        let _ = simulate_multiplicative(&p, &mut rng);
    }

    /// F-001 itself, on a block where both branches see the same jumps and the
    /// only difference is additive versus multiplicative.
    #[test]
    fn the_additive_jump_leaves_the_positive_orthant_and_the_multiplicative_one_does_not() {
        let p = jumps_only();
        let mut additive = Distributions::seeded();
        let touched = simulate_additive(&p, &mut additive);
        assert!(
            touched >= 0.9,
            "a 0.05 cushion cannot absorb a mean-1 exponential jump, got {touched}"
        );

        let mut multiplicative = Distributions::seeded();
        let (negative, min) = simulate_multiplicative(&p, &mut multiplicative);
        assert_eq!(negative, 0.0, "the clip before the product bounds R below");
        assert!(min >= 0.0, "min R = {min} must stay in [0, inf)");
        assert!(min < p.r0, "and the jumps must still move it, min = {min}");
    }

    #[test]
    fn the_multiplicative_branch_never_goes_negative_at_the_sealed_parameters() {
        let p = Params::smoke();
        let mut rng = Distributions::seeded();
        let (negative, min) = simulate_multiplicative(&p, &mut rng);
        assert_eq!(negative, 0.0);
        assert!(min >= 0.0);
        assert!(min <= p.r0);
    }

    #[test]
    fn a_jump_count_enters_the_size_linearly_and_the_factor_exponentially() {
        assert_eq!(jump_count(0), 0.0);
        assert_eq!(jump_count(3), 3.0);
        // one uniform per jumping path, raised to that path's jump count
        let y = 0.5_f64;
        assert_eq!(y.powi(3), 0.125);
        assert_eq!(y * 3.0, 1.5);
    }
}
