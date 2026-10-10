//! The collaboration graph `W` and the sealed generators (plan §5.6).
//!
//! `main.tex` `eq:collab` defines `W ∈ R^{n×n}` as the symmetric weighted graph
//! of validator interactions, `n = 500` and mean degree `d̄ = 20` in the reference
//! configuration. The three ensembles M5 must reproduce are the ones the sealed
//! scripts build, transcribed call for call — including the detail that matters
//! most for stream reproduction: `numpy` draws a **full `n × n`** block of
//! uniforms per replicate and the scripts then keep `i < j`, so a generator that
//! drew only the upper triangle would resume the wrong stream position.
//!
//! | method | sealed source |
//! |---|---|
//! | [`Graph::er_h0`] | `calibration_modularity.py::generate_h0` |
//! | [`Graph::sbm_cliques`] | `calibration_modularity.py::generate_h1` (`p_in = 10·p_out`) |
//! | [`Graph::sbm_bipartite`] | `bipartite_power.py::generate_bipartite` (`p_between = ρ·p_within`) |
//!
//! Entries are `f64` because that is what the sealed scripts carry (`W` counts
//! interactions; the calibration uses 0/1). Nothing here rounds or normalizes:
//! the detector reads `W` exactly as `B = W − ddᵀ/(2m)` requires.

use crate::pcg64::Pcg64;

/// A symmetric weighted graph with zero diagonal, row-major.
#[derive(Clone, Debug, PartialEq)]
pub struct Graph {
    n: usize,
    w: Vec<f64>,
}

/// The two block densities of the disassortative model, exactly as
/// `bipartite_power.py::compute_probabilities` computes them: `p_between =
/// ρ·p_within` with `p_within` solving
/// `intra·p_within + m₁m₂·p_between = n·d̄/2`, and the sealed saturation when the
/// solution would push `p_between` past 1.
///
/// Kept separate from [`Graph::sbm_bipartite`] because the sealed table *prints*
/// both densities: reproducing that column means reproducing the same arithmetic.
#[must_use]
pub fn bipartite_probabilities(
    n: usize,
    m1: usize,
    m2: usize,
    rho_between: f64,
    d_bar: f64,
) -> (f64, f64) {
    let intra = m1 as f64 * (m1 as f64 - 1.0) / 2.0 + m2 as f64 * (m2 as f64 - 1.0) / 2.0;
    let inter = m1 as f64 * m2 as f64;
    let target_edges = n as f64 * d_bar / 2.0;
    let mut p_within = target_edges / (intra + inter * rho_between);
    let mut p_between = rho_between * p_within;
    if p_between > 1.0 {
        p_between = 1.0;
        p_within = ((target_edges - inter * p_between) / intra).max(0.0);
    }
    (p_within, p_between)
}

/// Degree summary, in the shape `clique_spectra.py` prints it: `min`/`max` are
/// integers in the sealed table, `mean`/`std` carry two decimals, and `std` is
/// the *population* standard deviation (`numpy.ndarray.std()`, `ddof = 0`).
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct DegreeStats {
    pub min: f64,
    pub max: f64,
    pub mean: f64,
    pub std: f64,
}

impl Graph {
    /// The empty graph on `n` nodes.
    #[must_use]
    pub fn zeros(n: usize) -> Self {
        Self {
            n,
            w: vec![0.0; n * n],
        }
    }

    /// Node count (`n = 500` in the reference configuration).
    #[must_use]
    pub fn n(&self) -> usize {
        self.n
    }

    /// `W[i][j]`.
    #[must_use]
    pub fn weight(&self, i: usize, j: usize) -> f64 {
        self.w[i * self.n + j]
    }

    /// Set `W[i][j] = W[j][i] = v`. Node order is part of the reproducibility
    /// contract: the sealed scripts label nodes by index.
    pub fn set_weight(&mut self, i: usize, j: usize, v: f64) {
        self.w[i * self.n + j] = v;
        self.w[j * self.n + i] = v;
    }

    /// Add the unit edge `{i, j}` (the `A[i][j] = 1` of the calibration).
    pub fn add_edge(&mut self, i: usize, j: usize) {
        self.set_weight(i, j, 1.0);
    }

    /// The `n × n` matrix, row-major.
    #[must_use]
    pub fn weights(&self) -> &[f64] {
        &self.w
    }

    /// The degree vector `d = W·1`.
    #[must_use]
    pub fn degrees(&self) -> Vec<f64> {
        (0..self.n)
            .map(|i| self.w[i * self.n..(i + 1) * self.n].iter().sum())
            .collect()
    }

    /// `2m = Σ_ij W_ij = Σ_i d_i`.
    #[must_use]
    pub fn total_degree(&self) -> f64 {
        self.w.iter().sum()
    }

    /// `m = ½ Σ_ij W_ij`, the number of edges (weighted).
    #[must_use]
    pub fn edges(&self) -> f64 {
        self.total_degree() / 2.0
    }

    /// Degree summary in the sealed layout.
    #[must_use]
    pub fn degree_stats(&self) -> DegreeStats {
        let d = self.degrees();
        let n = self.n as f64;
        let mean = d.iter().sum::<f64>() / n;
        let var = d.iter().map(|x| (x - mean) * (x - mean)).sum::<f64>() / n;
        DegreeStats {
            min: d.iter().copied().fold(f64::INFINITY, f64::min),
            max: d.iter().copied().fold(f64::NEG_INFINITY, f64::max),
            mean,
            std: var.sqrt(),
        }
    }

    /// `A_sym = D^{-1/2} W D^{-1/2}` (`main.tex` `eq:asym`), the matrix the paper
    /// rejects in favour of `B`; kept because its row of the table is one of the
    /// numbers M5 reproduces.
    #[must_use]
    pub fn symmetric_normalized(&self) -> Vec<f64> {
        let d = self.degrees();
        let inv: Vec<f64> = d
            .iter()
            .map(|x| 1.0 / if *x > 0.0 { x.sqrt() } else { 1.0 })
            .collect();
        let mut a = vec![0.0; self.n * self.n];
        for i in 0..self.n {
            for j in 0..self.n {
                a[i * self.n + j] = inv[i] * self.w[i * self.n + j] * inv[j];
            }
        }
        a
    }
}

impl Graph {
    /// `calibration_modularity.py::generate_h0` — Erdős–Rényi with mean degree
    /// `d_bar`, i.e. `p = d_bar/(n−1)` per pair, one `n × n` block of uniforms
    /// consumed per graph.
    #[must_use]
    pub fn er_h0(rng: &mut Pcg64, n: usize, d_bar: f64) -> Self {
        let p = d_bar / (n as f64 - 1.0);
        Self::from_thresholds(rng, n, |i, j| if i == j { 0.0 } else { p })
    }

    /// `calibration_modularity.py::generate_h1` — `k` dense blocks of size
    /// `clique_size` planted at the front, each pair inside a block with
    /// probability `min(1, 10·p_out)`, every other pair with `p_out`.
    #[must_use]
    pub fn sbm_cliques(
        rng: &mut Pcg64,
        n: usize,
        d_bar: f64,
        k_cliques: usize,
        clique_size: usize,
    ) -> Self {
        let p_out = d_bar / (n as f64 - 1.0);
        let p_in = (10.0 * p_out).min(1.0);
        let in_block =
            |i: usize, j: usize| i / clique_size == j / clique_size && i < k_cliques * clique_size;
        Self::from_thresholds(rng, n, |i, j| {
            if i == j {
                0.0
            } else if in_block(i, j) {
                p_in
            } else {
                p_out
            }
        })
    }

    /// `bipartite_power.py::generate_bipartite` — two blocks with
    /// `p_between = ρ·p_within` and `ρ ≥ 1`, the disassortative case the left
    /// tail is calibrated for. `p_within` solves
    /// `intra·p_within + m₁m₂·p_between = n·d̄/2`, with the sealed script's
    /// saturation when `p_between` would exceed 1.
    #[must_use]
    pub fn sbm_bipartite(
        rng: &mut Pcg64,
        n: usize,
        m1: usize,
        m2: usize,
        rho_between: f64,
        d_bar: f64,
    ) -> Self {
        assert_eq!(m1 + m2, n, "blocks must tile the nodes");
        let (p_within, p_between) = bipartite_probabilities(n, m1, m2, rho_between, d_bar);
        Self::from_thresholds(rng, n, |i, j| {
            if i == j {
                0.0
            } else if (i < m1) == (j < m1) {
                p_within
            } else {
                p_between
            }
        })
    }

    /// The shared loop of the sealed generators: draw the full `n × n` block of
    /// uniforms (row-major, as `rng.random((n, n))` does), keep the upper
    /// triangle, mirror it. The threshold of the *diagonal* pair is never used,
    /// but its uniform is still consumed — that is what keeps the stream aligned.
    // The loop is deliberately index-based: it needs the pair `(i, j)` for the
    // threshold *and* `row[j]` for the uniform, which an iterator form obscures.
    #[allow(clippy::needless_range_loop)]
    fn from_thresholds(rng: &mut Pcg64, n: usize, threshold: impl Fn(usize, usize) -> f64) -> Self {
        let mut g = Self::zeros(n);
        let mut row = vec![0.0; n];
        for i in 0..n {
            rng.fill(&mut row);
            for j in (i + 1)..n {
                if row[j] < threshold(i, j) {
                    g.add_edge(i, j);
                }
            }
        }
        g
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The first H0 draw of the sealed stream, as `numpy` computes it: the
    /// checksum is pinned in the fixture and covers the generator *and* the
    /// stream position (edges, degree moments).
    #[test]
    fn first_h0_draw_matches_numpy_checksum() {
        let path = concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/fixtures/numpy_pcg64_seed42.txt"
        );
        let text = std::fs::read_to_string(path).expect("fixture is committed");
        let field = |key: &str| -> f64 {
            text.lines()
                .find_map(|l| l.strip_prefix(&format!("{key} =")))
                .unwrap_or_else(|| panic!("fixture has no `{key}`"))
                .trim()
                .parse()
                .expect("number")
        };
        let mut rng = Pcg64::seeded();
        let g = Graph::er_h0(&mut rng, 500, 20.0);
        assert_eq!(g.edges(), field("h0_draw1_edges"), "edge count diverges");
        let s = g.degree_stats();
        assert_eq!(s.min, field("h0_draw1_deg_min"));
        assert_eq!(s.max, field("h0_draw1_deg_max"));
        assert!((s.mean - field("h0_draw1_deg_mean")).abs() < 5e-3);
        assert!((s.std - field("h0_draw1_deg_std")).abs() < 5e-3);
    }

    #[test]
    fn graph_invariants_hold() {
        let mut rng = Pcg64::seeded();
        let g = Graph::er_h0(&mut rng, 60, 6.0);
        assert_eq!(g.n(), 60);
        for i in 0..60 {
            assert_eq!(g.weight(i, i), 0.0, "diagonal must stay empty");
            for j in 0..60 {
                assert_eq!(g.weight(i, j), g.weight(j, i), "W must be symmetric");
            }
        }
        let d = g.degrees();
        assert!((d.iter().sum::<f64>() - g.total_degree()).abs() < 1e-12);
    }

    #[test]
    fn normalized_adjacency_is_symmetric_and_bounded() {
        let mut rng = Pcg64::seeded();
        let g = Graph::er_h0(&mut rng, 80, 6.0);
        let a = g.symmetric_normalized();
        for i in 0..80 {
            for j in 0..80 {
                assert!((a[i * 80 + j] - a[j * 80 + i]).abs() < 1e-15);
                assert!(a[i * 80 + j].abs() <= 1.0 + 1e-12);
            }
        }
    }

    #[test]
    fn bipartite_blocks_match_numpy_counts() {
        let path = concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/fixtures/numpy_pcg64_seed42.txt"
        );
        let text = std::fs::read_to_string(path).expect("fixture is committed");
        let field = |key: &str| -> f64 {
            text.lines()
                .find_map(|l| l.strip_prefix(&format!("{key} =")))
                .unwrap_or_else(|| panic!("fixture has no `{key}`"))
                .trim()
                .parse()
                .expect("number")
        };
        let mut rng = Pcg64::seeded();
        let g = Graph::sbm_bipartite(&mut rng, 200, 100, 100, 10.0, 20.0);
        let within: f64 = (0..100)
            .flat_map(|i| ((i + 1)..100).map(move |j| (i, j)))
            .map(|(i, j)| g.weight(i, j))
            .sum();
        let between: f64 = (0..100)
            .flat_map(|i| (100..200).map(move |j| (i, j)))
            .map(|(i, j)| g.weight(i, j))
            .sum();
        assert_eq!(within, field("bipartite_draw1_within"));
        assert_eq!(between, field("bipartite_draw1_between"));
        // The ensemble is disassortative whatever the realized fluctuation: the
        // density across blocks is several times the density inside them.
        let ratio = (between / 10_000.0) / (within / (100.0 * 99.0 / 2.0));
        assert!(
            ratio > 5.0,
            "ρ_between/ρ_within = {ratio} is not disassortative"
        );
    }

    #[test]
    fn clique_draw_follows_the_null_draw_on_the_same_stream() {
        let path = concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/fixtures/numpy_pcg64_seed42.txt"
        );
        let text = std::fs::read_to_string(path).expect("fixture is committed");
        let field = |key: &str| -> f64 {
            text.lines()
                .find_map(|l| l.strip_prefix(&format!("{key} =")))
                .unwrap_or_else(|| panic!("fixture has no `{key}`"))
                .trim()
                .parse()
                .expect("number")
        };
        // `clique_spectra.py` draws H0 first, then H1, on one stream.
        let mut rng = Pcg64::seeded();
        let _h0 = Graph::er_h0(&mut rng, 500, 20.0);
        let g = Graph::sbm_cliques(&mut rng, 500, 20.0, 1, 20);
        let clique: f64 = (0..20)
            .flat_map(|i| ((i + 1)..20).map(move |j| (i, j)))
            .map(|(i, j)| g.weight(i, j))
            .sum();
        assert_eq!(g.edges(), field("h1_draw1_edges"));
        assert_eq!(clique, field("h1_draw1_clique_edges"));
        let d = g.degrees();
        let inside = d[..20].iter().sum::<f64>() / 20.0;
        let outside = d[20..].iter().sum::<f64>() / 480.0;
        assert!((inside - field("h1_draw1_deg_inside_mean")).abs() < 5e-3);
        assert!((outside - field("h1_draw1_deg_outside_mean")).abs() < 1e-4);
    }

    #[test]
    fn cliques_raise_the_degree_of_their_members() {
        let mut rng = Pcg64::seeded();
        let g = Graph::sbm_cliques(&mut rng, 500, 20.0, 1, 20);
        let d = g.degrees();
        let inside = d[..20].iter().sum::<f64>() / 20.0;
        let outside = d[20..].iter().sum::<f64>() / 480.0;
        assert!(
            inside > outside + 5.0,
            "clique degree {inside} vs {outside}"
        );
    }
}
