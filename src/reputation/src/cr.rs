//! `C_R(r)`, its analytic derivatives, the stationary operator and `π(r)`.
//!
//! Paper: §2.5 fixes the closed form `C_R(r) = 0.8·r/(1+r)` and the stationary
//! integro-differential equation (`eq:fokker`, `eq:integro`,
//! `eq:running-reward`). C-24 was closed by
//! `verification/stochastics/cr_ide_solver.py`, which evaluates the operator on a
//! fixed grid and backs out `π = −L[C_R]`; M6's claim is narrower than that finding
//! and is stated as such: the *same* operator, computed by an independent
//! implementation, on the *same* grid, to the six decimals the sealed file prints.
//!
//! Everything here is the sealed script's own arithmetic, in the sealed script's
//! order — `(1+r)²` via `powf(2.0)` rather than `t*t`, because Python's `x ** 2`
//! calls libm `pow` and this crate has to agree with *it*, not with a
//! mathematically equivalent expression. The tests compare formatted rows against
//! `fixtures/sealed_reference.txt`, so a disagreement in the sixth decimal is a
//! failure, not a tolerance.

/// `C_R^∞ = 0.8`: the saturation of the closed form (`C_INF` in the sealed
/// solver, `CR_INF` in `AVIPValidatorManager`).
pub const C_INF: f64 = 0.8;

/// The deterministic multiplicative jump `y = 0.85` (`Y` in the sealed solver);
/// `E[1 − y] = 0.15`, the paper's mean jump magnitude.
pub const Y: f64 = 0.85;

/// Jump intensity `λ`.
pub const LAM: f64 = 0.8;

/// Long-run mean `R̄`.
pub const R_BAR: f64 = 1.0;

/// One of the solver's two regimes. Both satisfy Feller (`2αR̄ ≥ σ₀²`).
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Regime {
    /// The label the sealed file prints.
    pub name: &'static str,
    /// Mean-reversion speed.
    pub alpha: f64,
    /// Volatility.
    pub sigma_0: f64,
}

impl Regime {
    /// `2αR̄`, the left-hand side of Feller's condition (`eq:wellcond`).
    #[must_use]
    pub fn feller_lhs(&self) -> f64 {
        2.0 * self.alpha * R_BAR
    }

    /// `σ₀²`, the right-hand side.
    #[must_use]
    pub fn feller_rhs(&self) -> f64 {
        self.sigma_0 * self.sigma_0
    }

    /// Whether `2αR̄ ≥ σ₀²` (`eq:wellcond`), which the sealed script asserts.
    #[must_use]
    pub fn feller_holds(&self) -> bool {
        self.feller_lhs() >= self.feller_rhs()
    }
}

/// The sealed regimes, in the sealed order.
pub const REGIMES: [Regime; 2] = [
    Regime {
        name: "Regime 1",
        alpha: 0.5,
        sigma_0: 0.8,
    },
    Regime {
        name: "Regime 2",
        alpha: 2.0,
        sigma_0: 0.5,
    },
];

/// The sealed grid, as `(value, label)` pairs.
pub const GRID: [(f64, &str); 14] = [
    (1e-3, "1e-3"),
    (1e-2, "1e-2"),
    (0.05, "0.05"),
    (0.1, "0.1"),
    (0.2, "0.2"),
    (0.3, "0.3"),
    (0.5, "0.5"),
    (0.7, "0.7"),
    (1.0, "1.0"),
    (2.0, "2.0"),
    (5.0, "5.0"),
    (10.0, "10.0"),
    (20.0, "20.0"),
    (50.0, "50.0"),
];

/// `C_R(r) = C_R^∞ · r/(1+r)`.
#[must_use]
pub fn c_r(r: f64) -> f64 {
    C_INF * r / (1.0 + r)
}

/// `C_R'(r) = C_R^∞/(1+r)²`.
#[must_use]
pub fn d_c_r(r: f64) -> f64 {
    C_INF / (1.0 + r).powf(2.0)
}

/// `C_R''(r) = −2·C_R^∞/(1+r)³`.
#[must_use]
pub fn d2_c_r(r: f64) -> f64 {
    -2.0 * C_INF / (1.0 + r).powf(3.0)
}

/// `C_R(y·r)` for the deterministic multiplicative jump.
#[must_use]
pub fn c_r_jump(r: f64) -> f64 {
    C_INF * Y * r / (1.0 + Y * r)
}

/// The stationary operator `L[C_R](r)` (`eq:integro`) with `dC_R/dt = 0`.
#[must_use]
pub fn operator(r: f64, alpha: f64, sigma_0: f64) -> f64 {
    let mu = alpha * (R_BAR - r);
    let sigma2 = sigma_0.powf(2.0) * r;
    mu * d_c_r(r) + 0.5 * sigma2 * d2_c_r(r) + LAM * (c_r_jump(r) - c_r(r)) - r * c_r(r)
}

/// The running reward `π(r) = −L[C_R](r)` (`eq:running-reward`).
#[must_use]
pub fn pi(r: f64, alpha: f64, sigma_0: f64) -> f64 {
    -operator(r, alpha, sigma_0)
}

/// The sealed solver's `find_r0`: the smallest `r` with `π(r) > 0`, by 200
/// bisection steps on `[1e-9, 1]` with `π(1e-9) < 0 < π(1)`.
#[must_use]
pub fn find_r0(regime: &Regime) -> f64 {
    let (alpha, sigma_0) = (regime.alpha, regime.sigma_0);
    let (mut lo, mut hi) = (1e-9_f64, 1.0_f64);
    assert!(pi(lo, alpha, sigma_0) < 0.0, "pi(1e-9) must be negative");
    assert!(pi(hi, alpha, sigma_0) > 0.0, "pi(1) must be positive");
    for _ in 0..200 {
        let mid = 0.5 * (lo + hi);
        if pi(mid, alpha, sigma_0) > 0.0 {
            hi = mid;
        } else {
            lo = mid;
        }
    }
    0.5 * (lo + hi)
}

/// The sealed solver's `monotone_from`: `π` non-decreasing on `[r0, r_max]` over
/// `n + 1` points, with the sealed `1e-12` slack.
#[must_use]
pub fn monotone_from(regime: &Regime, r0: f64, r_max: f64, n: usize) -> bool {
    let (alpha, sigma_0) = (regime.alpha, regime.sigma_0);
    let mut prev: Option<f64> = None;
    for i in 0..=n {
        let r = r0 + (r_max - r0) * i as f64 / n as f64;
        let val = pi(r, alpha, sigma_0);
        if let Some(p) = prev
            && val < p - 1e-12
        {
            return false;
        }
        prev = Some(val);
    }
    true
}

/// One grid row: the four analytic quantities plus `L[C_R]` and `π`.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Row {
    /// The grid label as printed (`"1e-3"`, `"0.05"`, …).
    pub label: &'static str,
    /// `C_R(r)`.
    pub c_r: f64,
    /// `C_R'(r)`.
    pub d_c_r: f64,
    /// `C_R''(r)`.
    pub d2_c_r: f64,
    /// `L[C_R](r)`.
    pub l: f64,
    /// `π(r) = −L[C_R](r)`.
    pub pi: f64,
}

/// Evaluate the sealed grid in one regime.
#[must_use]
pub fn rows(regime: &Regime) -> Vec<Row> {
    GRID.iter()
        .map(|&(r, label)| {
            let l = operator(r, regime.alpha, regime.sigma_0);
            Row {
                label,
                c_r: c_r(r),
                d_c_r: d_c_r(r),
                d2_c_r: d2_c_r(r),
                l,
                pi: -l,
            }
        })
        .collect()
}

/// A grid row, in the sealed solver's exact column format.
#[must_use]
pub fn row_line(row: &Row) -> String {
    format!(
        "  {:<7} {:>12.6} {:>12.6} {:>13.6} {:>15.6} {:>15.6}",
        row.label, row.c_r, row.d_c_r, row.d2_c_r, row.l, row.pi
    )
}

/// The sealed summary block of one regime.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Summary {
    /// `r₀`: smallest `r` with `π(r) > 0`.
    pub r0: f64,
    /// `π(0.5)`.
    pub pi_05: f64,
    /// `π(1.0)`.
    pub pi_10: f64,
    /// `min π` over the 14-point grid.
    pub min_pi: f64,
    /// `π` non-decreasing on `[r₀, ∞)` (checked to `r = 1000`).
    pub monotone: bool,
    /// `π(1e5)/1e5`, the `O(r)` slope — `→ 0.8` as `r → ∞`.
    pub limb: f64,
}

/// Evaluate one regime's summary exactly as the sealed solver does.
#[must_use]
pub fn summary(regime: &Regime) -> Summary {
    let grid = rows(regime);
    let min_pi = grid.iter().map(|row| row.pi).fold(f64::INFINITY, f64::min);
    let r0 = find_r0(regime);
    Summary {
        r0,
        pi_05: pi(0.5, regime.alpha, regime.sigma_0),
        pi_10: pi(1.0, regime.alpha, regime.sigma_0),
        min_pi,
        monotone: monotone_from(regime, r0, 1000.0, 20_000),
        limb: pi(1e5, regime.alpha, regime.sigma_0) / 1e5,
    }
}

/// The sealed summary lines of one regime, in the sealed format.
#[must_use]
pub fn summary_lines(regime: &Regime, s: &Summary) -> Vec<String> {
    vec![
        format!("  {} summary:", regime.name),
        format!("    r_0  (smallest r with pi > 0)  = {:.6}", s.r0),
        format!("    pi(0.5)                        = {:+.6}", s.pi_05),
        format!("    pi(1.0)                        = {:+.6}", s.pi_10),
        format!("    min pi(r) over the grid        = {:+.6}", s.min_pi),
        format!(
            "    monotone increasing on [r_0,.) = {}",
            if s.monotone { "yes" } else { "NO" }
        ),
        format!("    pi(r)/r at r = 1e5 (O(r))      = {:.6}", s.limb),
    ]
}

/// The finite-`r` saturation check the floor sensitivity needs: the largest
/// `C_R` on a very large argument. `C_R(1e9) = 0.7999999992` prints as `0.800000`.
#[must_use]
pub fn c_r_at_large_r() -> f64 {
    c_r(1e9)
}

/// The sealed floor sweep: `C_R^∞ ∈ {0.5, …, 1.0}` → `S_min = Θ − C_R^∞`.
#[must_use]
pub fn floor_sweep() -> Vec<(f64, f64)> {
    (5..=10)
        .map(|i| {
            let c_inf = i as f64 / 10.0;
            (c_inf, 1.0 - c_inf)
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The sealed outputs, copied line for line. The four blocks that came from
    /// the C-24 solver are, in file order: Regime 1's grid, Regime 1's summary,
    /// Regime 2's grid, Regime 2's summary.
    const REFERENCE: &str = include_str!("../fixtures/sealed_reference.txt");

    /// The solver's blocks of the fixture, comments dropped.
    fn solver_blocks() -> Vec<Vec<String>> {
        let mut blocks: Vec<(bool, Vec<String>)> = Vec::new();
        for line in REFERENCE.lines() {
            if line.starts_with("# ---") {
                blocks.push((line.contains("cr_ide_solver_output.txt"), Vec::new()));
            } else if line.starts_with('#') || line.trim().is_empty() {
                // the fixture's own header prose, not data
            } else if let Some((_, data)) = blocks.last_mut() {
                data.push(line.to_string());
            }
        }
        blocks
            .into_iter()
            .filter(|(is_solver, data)| *is_solver && !data.is_empty())
            .map(|(_, data)| data)
            .collect()
    }

    #[test]
    fn the_grid_rows_are_the_sealed_ones_to_six_decimals() {
        let blocks = solver_blocks();
        assert_eq!(blocks.len(), 4, "two grids and two summaries");
        for (regime, want) in REGIMES.iter().zip([&blocks[0], &blocks[2]]) {
            let got: Vec<String> = rows(regime).iter().map(row_line).collect();
            assert_eq!(got.len(), GRID.len(), "the sealed grid is 14 points");
            assert_eq!(&got, want, "{}", regime.name);
        }
    }

    #[test]
    fn the_summaries_are_the_sealed_ones_to_six_decimals() {
        let blocks = solver_blocks();
        for (regime, want) in REGIMES.iter().zip([&blocks[1], &blocks[3]]) {
            let got = summary_lines(regime, &summary(regime));
            // the fixture copies the six numbers; the heading is M6's own
            assert_eq!(got[0], format!("  {} summary:", regime.name));
            assert_eq!(&got[1..], &want[..], "{}", regime.name);
        }
    }

    #[test]
    fn find_r0_is_the_sign_change_of_pi() {
        for regime in REGIMES {
            let r0 = find_r0(&regime);
            assert!(r0 > 0.0 && r0 < 1.0, "the sealed bracket");
            assert!(
                pi(r0, regime.alpha, regime.sigma_0).abs() < 1e-9,
                "{}: pi(r_0) must vanish",
                regime.name
            );
            assert!(pi(0.9 * r0, regime.alpha, regime.sigma_0) < 0.0);
            assert!(pi(1.1 * r0, regime.alpha, regime.sigma_0) > 0.0);
        }
    }

    #[test]
    fn the_closed_form_and_its_derivatives_agree_with_finite_differences() {
        let h = 1e-5;
        for r in [0.01_f64, 0.2, 0.5, 1.0, 3.0, 20.0] {
            let first = (c_r(r + h) - c_r(r - h)) / (2.0 * h);
            let second = (c_r(r + h) - 2.0 * c_r(r) + c_r(r - h)) / (h * h);
            assert!((first - d_c_r(r)).abs() < 1e-8, "C_R'({r})");
            assert!((second - d2_c_r(r)).abs() < 1e-4, "C_R''({r})");
        }
        // the analytic values the table's first row prints
        assert!((d_c_r(1e-3) - 0.798402).abs() < 5e-7);
        assert!((d2_c_r(1e-3) + 1.595210).abs() < 5e-7);
    }

    #[test]
    fn c_r_rises_to_its_saturation_without_reaching_it() {
        assert_eq!(c_r(0.0), 0.0);
        let mut previous = 0.0;
        for r in [1e-3_f64, 0.5, 1.0, 10.0, 1e3, 1e6] {
            let c = c_r(r);
            assert!(c > previous, "C_R must rise at {r}");
            assert!(c < C_INF, "C_R({r}) must stay below C_R^inf");
            previous = c;
        }
        // `C_R(1e9) = 0.7999999992` is what the table prints as 0.800000
        assert!(c_r_at_large_r() < C_INF);
        assert_eq!(format!("{:.6}", c_r_at_large_r()), "0.800000");
    }

    #[test]
    fn the_jump_lowers_c_r_and_costs_0_15_on_average() {
        for r in [0.1_f64, 0.5, 1.0, 10.0] {
            assert!(c_r_jump(r) > 0.0);
            assert!(c_r_jump(r) < c_r(r), "y = 0.85 must lower C_R at {r}");
        }
        assert!((1.0 - Y - 0.15).abs() < 1e-15, "E[1 - y] is the mean jump");
        assert!((LAM - 0.8).abs() < 1e-15);
        assert!((R_BAR - 1.0).abs() < 1e-15);
    }

    #[test]
    fn feller_holds_for_both_sealed_regimes() {
        for regime in REGIMES {
            assert!(regime.feller_holds(), "{}", regime.name);
        }
        assert_eq!(REGIMES[0].feller_lhs(), 1.0, "2 * 0.5 * 1.0");
        assert_eq!(REGIMES[1].feller_lhs(), 4.0, "2 * 2.0 * 1.0");
        assert!((REGIMES[0].feller_rhs() - 0.64).abs() < 1e-15);
        assert!((REGIMES[1].feller_rhs() - 0.25).abs() < 1e-15);
    }

    #[test]
    fn the_floor_sweep_is_the_sealed_sensitivity() {
        let sweep = floor_sweep();
        assert_eq!(sweep.len(), 6, "C_R^inf in 0.5, ..., 1.0");
        assert_eq!(sweep[0], (0.5, 0.5));
        assert_eq!(sweep[5], (1.0, 0.0));
        let mut previous = f64::INFINITY;
        for (c_inf, s_min) in sweep {
            assert!(
                (c_inf + s_min - 1.0).abs() < 1e-15,
                "S_min = Theta - C_R^inf"
            );
            assert!(s_min < previous, "the floor falls as C_R^inf rises");
            previous = s_min;
        }
    }
}
