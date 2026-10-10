//! The detector: `B = W − ddᵀ/(2m)`, its two tails, and the sealed thresholds.
//!
//! `main.tex` `eq:modularity` defines `B = W − ddᵀ/(2m)` and §collusion fixes the
//! decision rule:
//!
//! | tail | statistic | rejects `H_0` when | detects |
//! |---|---|---|---|
//! | right | `s[-1] = λ_max(B)` | `> 9.0542` (`α = 0.01`) | clique-based collusion |
//! | left | `−s[0] = −λ_min(B)` | `> 9.1371` (`α = 0.01`) | bipartite polarization |
//!
//! The statistic is `s[-1]`, **not** `s[-2]`: `B·1 = 0` puts the trivial
//! eigenvalue at the *center* of the spectrum, so the Perron-skipping convention
//! of the adjacency matrix does not apply (falsification log entry F-018;
//! `verification/rmt/max_statistic.py` and `recalibrate_top.py` measured that
//! `max(s[-1], s[-2]) = s[-1]` identically).
//!
//! Where the numbers come from — none typed without provenance:
//!
//! | constant | value | source |
//! |---|---|---|
//! | [`ALPHA_0_01`]`.right` | `9.0542` | `results/calibration_modularity_output.txt` (`q99` of `λ_max(B)`, `N_H0 = 2000`); `main.tex` §collusion table |
//! | [`ALPHA_0_01`]`.left` | `9.1371` | same line, `q99` of `−λ_min(B)`; `bipartite_power.py` reads it back as `Q99_LEFT` |
//! | [`ALPHA_0_05`] | `8.9663` / `9.0428` | `results/calibration_modularity_output.txt`, `α = 0.05` row |
//! | `d̄`, `n` | `20`, `500` | `main.tex` `eq:collab`; `calibration_modularity.py` constants |
//!
//! `fixtures/sealed_reference.txt` holds the sealed lines these constants and the
//! reproduction table are checked against — verbatim, so `scripts/m5_report.sh`
//! can prove the copy still matches `verification/rmt/results/`, which M5 never
//! edits.

use crate::graph::Graph;
use crate::spectrum::{kth_largest, tridiagonalize};

/// One calibrated rejection region: `right` for `λ_max(B)`, `left` for
/// `−λ_min(B)`, both at level `alpha`.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Calibration {
    /// Tail probability the quantiles were calibrated at.
    pub alpha: f64,
    /// `q_{1−α}` of `λ_max(B)` on the reference ER null.
    pub right: f64,
    /// `q_{1−α}` of `−λ_min(B)` on the reference ER null.
    pub left: f64,
}

/// The `α = 0.01` calibration: the thresholds the protocol quotes.
pub const ALPHA_0_01: Calibration = Calibration {
    alpha: 0.01,
    right: 9.0542,
    left: 9.1371,
};

/// The `α = 0.05` calibration, reproduced for completeness (the paper's table
/// carries both rows).
pub const ALPHA_0_05: Calibration = Calibration {
    alpha: 0.05,
    right: 8.9663,
    left: 9.0428,
};

/// Which tails fired.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Verdict {
    /// Neither tail cleared its threshold.
    Quiet,
    /// Right tail only: a dense subgraph.
    Clique,
    /// Left tail only: bipartite polarization.
    Bipartite,
    /// Both tails.
    Both,
}

impl Verdict {
    /// The word the report prints.
    #[must_use]
    pub fn as_str(self) -> &'static str {
        match self {
            Verdict::Quiet => "quiet",
            Verdict::Clique => "clique",
            Verdict::Bipartite => "bipartite",
            Verdict::Both => "both",
        }
    }
}

/// The detector's output: the two statistics, the two decisions, and the graph
/// summary they were computed on. This is what a caller (M7's slashing path, an
/// epoch monitor) consumes; turning it into an AWM message is M7, not M5.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Detection {
    /// Node count.
    pub n: usize,
    /// Edge count `m`.
    pub edges: f64,
    /// `s[-1] = λ_max(B)`.
    pub lambda_max: f64,
    /// `−s[0] = −λ_min(B)`.
    pub neg_lambda_min: f64,
    /// `λ_max(B) > cal.right`.
    pub right_alert: bool,
    /// `−λ_min(B) > cal.left`.
    pub left_alert: bool,
}

impl Detection {
    /// The combined verdict.
    #[must_use]
    pub fn verdict(&self) -> Verdict {
        match (self.right_alert, self.left_alert) {
            (false, false) => Verdict::Quiet,
            (true, false) => Verdict::Clique,
            (false, true) => Verdict::Bipartite,
            (true, true) => Verdict::Both,
        }
    }
}

/// `B = W − ddᵀ/(2m)`, row-major and dense (`main.tex` `eq:modularity`).
///
/// A graph with no edges has `m = 0`, where the sealed scripts return the zero
/// matrix (and `bipartite_power.py::left_statistic` returns `0.0`) rather than
/// dividing by zero; the same branch is kept here.
#[must_use]
pub fn modularity(w: &Graph) -> Vec<f64> {
    let n = w.n();
    let d = w.degrees();
    let two_m = w.total_degree();
    let mut b = w.weights().to_vec();
    if two_m == 0.0 {
        return b;
    }
    for i in 0..n {
        for j in 0..n {
            b[i * n + j] -= d[i] * d[j] / two_m;
        }
    }
    b
}

/// The requested order statistics of a dense symmetric matrix: `ks[i] = 1` is
/// the largest eigenvalue, `ks[i] = n` the smallest. One tridiagonalization
/// serves every `k` in the slice.
///
/// `matrix` is destroyed (the reduction is in place).
#[must_use]
pub fn order_statistics(n: usize, matrix: &mut [f64], ks: &[usize]) -> Vec<f64> {
    let (mut d, mut e) = (vec![0.0; n], vec![0.0; n]);
    tridiagonalize(n, matrix, &mut d, &mut e);
    ks.iter().map(|&k| kth_largest(&d, &e, k)).collect()
}

/// The theoretical bulk edge of the null, `2√d̄`: `8.9443` at `d̄ = 20`.
///
/// Derived, never typed: it is the semicircle edge the calibration compares
/// against (`calibration_modularity.py` prints it, `clique_spectra.py` uses it
/// as the `bulk edge` column of the `W` and `B` rows).
#[must_use]
pub fn bulk_edge(d_bar: f64) -> f64 {
    2.0 * d_bar.sqrt()
}

/// The bulk edge of the *normalized* adjacency matrix, `2/√d̄`: `0.4472` at
/// `d̄ = 20`.
///
/// `clique_spectra.py` uses this one for the `A_sym` row
/// (`bulk_edge_Asym = 2 / sqrt(d_bar)`), which is why each row of the paper's
/// table carries its own edge.
#[must_use]
pub fn bulk_edge_normalized(d_bar: f64) -> f64 {
    2.0 / d_bar.sqrt()
}

/// Run the detector on one graph.
#[must_use]
pub fn detect(w: &Graph, cal: &Calibration) -> Detection {
    let n = w.n();
    let mut b = modularity(w);
    let stats = order_statistics(n, &mut b, &[1, n]);
    let (lambda_max, lambda_min) = (stats[0], stats[1]);
    Detection {
        n,
        edges: w.edges(),
        lambda_max,
        neg_lambda_min: -lambda_min,
        right_alert: lambda_max > cal.right,
        left_alert: -lambda_min > cal.left,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::pcg64::Pcg64;

    /// `B·1 = 0` exactly, so zero is always an eigenvalue: the identity that
    /// makes `s[-1]` (not `s[-2]`) the signal (F-018).
    #[test]
    fn modularity_annihilates_the_all_ones_vector() {
        let mut rng = Pcg64::seeded();
        let g = Graph::er_h0(&mut rng, 120, 8.0);
        let b = modularity(&g);
        for i in 0..120 {
            let row_sum: f64 = b[i * 120..(i + 1) * 120].iter().sum();
            assert!(row_sum.abs() < 1e-10, "row {i} sums to {row_sum}");
        }
    }

    /// On a `d`-regular graph `B = A − (d/n)J`, and since `1 ⊥ ` every other
    /// eigenvector, `spec(B) = {0} ∪ spec(A) \ {d}`: so `λ_max(B) = λ₂(W)`
    /// exactly. This is `main.tex`'s structural identity, checked numerically.
    #[test]
    fn regular_graph_identity_lambda_max_b_equals_lambda_2_w() {
        let n = 40;
        let mut g = Graph::zeros(n);
        for i in 0..n {
            g.add_edge(i, (i + 1) % n);
            g.add_edge(i, (i + 2) % n);
        }
        let mut a = g.weights().to_vec();
        let lambda2_w = order_statistics(n, &mut a, &[2])[0];
        let mut b = modularity(&g);
        let lambda_max_b = order_statistics(n, &mut b, &[1])[0];
        assert!(
            (lambda2_w - lambda_max_b).abs() < 1e-10,
            "λ₂(W) = {lambda2_w} vs λ_max(B) = {lambda_max_b}"
        );
    }

    #[test]
    fn empty_graph_is_quiet() {
        let g = Graph::zeros(50);
        let d = detect(&g, &ALPHA_0_01);
        assert_eq!(d.edges, 0.0);
        assert_eq!(d.lambda_max, 0.0);
        assert_eq!(d.verdict(), Verdict::Quiet);
    }

    #[test]
    fn planted_clique_alerts_on_the_right_tail() {
        let mut rng = Pcg64::seeded();
        // Discard the first H0 draw so this reads the same stream position as the
        // sealed H1 in `clique_spectra.py` (H0 first, then H1).
        let _ = Graph::er_h0(&mut rng, 500, 20.0);
        let g = Graph::sbm_cliques(&mut rng, 500, 20.0, 1, 20);
        let d = detect(&g, &ALPHA_0_01);
        assert!(d.right_alert, "λ_max(B) = {} must alert", d.lambda_max);
        assert!(!d.left_alert);
        assert_eq!(d.verdict(), Verdict::Clique);
        assert!((d.lambda_max - 10.7011).abs() < 1e-4, "sealed H1 value");
    }

    #[test]
    fn bipartite_polarization_alerts_on_the_left_tail() {
        let mut rng = Pcg64::seeded();
        let g = Graph::sbm_bipartite(&mut rng, 500, 250, 250, 10.0, 20.0);
        let d = detect(&g, &ALPHA_0_01);
        assert!(d.left_alert, "−λ_min(B) = {} must alert", d.neg_lambda_min);
        assert_eq!(d.verdict(), Verdict::Bipartite);
    }

    #[test]
    fn null_draw_stays_below_the_sealed_thresholds() {
        let mut rng = Pcg64::seeded();
        let g = Graph::er_h0(&mut rng, 500, 20.0);
        let d = detect(&g, &ALPHA_0_01);
        assert!((d.lambda_max - 8.6896).abs() < 1e-4, "sealed H0 value");
        assert_eq!(d.verdict(), Verdict::Quiet);
    }

    #[test]
    fn bulk_edge_is_two_sqrt_d_bar() {
        assert!((bulk_edge(20.0) - 8.9442719).abs() < 1e-6);
    }
}
