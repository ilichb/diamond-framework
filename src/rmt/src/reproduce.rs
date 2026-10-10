//! The sealed protocol, reproduced (plan §5.6).
//!
//! This is the module that answers M5's acceptance criterion: `calibration_modularity.py`
//! (null quantiles and right-tail power), `bipartite_power.py` (left-tail power)
//! and `clique_spectra.py` (the single-draw `W`/`A_sym`/`B` table) recomputed in
//! Rust from the same stream, in the same order, with the same estimators:
//!
//! - **stream**: one `Pcg64` per phase, advanced to the position the sealed script
//!   would be at ([`crate::pcg64`]). The H0 phase consumes
//!   `N_H0 × 500 × 500` doubles before the H1 phases start, exactly as the sealed
//!   `run()` does with one shared generator;
//! - **quantile**: numpy's default `method="linear"`, `idx = q·(n−1)`
//!   interpolated between the two neighbouring order statistics;
//! - **spread**: population standard deviation (`ddof = 0`), like `ndarray.std()`;
//! - **interval**: the Wilson score interval, the sealed formula
//!   (`q99_standard_error.py` uses the same one for the SE).
//!
//! Replicates are independent, so the phase runs in **chunks** processed by a
//! thread pool — with chunks mapped to their own stream windows by
//! [`Pcg64::advance`] and results reassembled in replicate order. The output is
//! therefore bit-identical on any machine and under any thread count: parallelism
//! changes the duration, never the pinned file (M4a's rule for durations).

use std::sync::Mutex;
use std::sync::atomic::{AtomicUsize, Ordering};

use crate::detector::{bulk_edge, bulk_edge_normalized, modularity, order_statistics};
use crate::graph::{DegreeStats, Graph};
use crate::pcg64::Pcg64;

/// Reference configuration: nodes (`main.tex` `eq:collab`).
pub const N: usize = 500;
/// Reference configuration: mean degree (`main.tex` `eq:collab`).
pub const D_BAR: f64 = 20.0;
/// Null replicates (`calibration_modularity.py::N_REPLICATES_H0`).
pub const N_H0: usize = 2000;
/// Power replicates per configuration (`N_REPLICATES_H1`).
pub const N_H1: usize = 500;
/// Replicates per work chunk. A constant, not `count/threads`: the *decomposition*
/// must not depend on the machine, only the number of workers that chew it.
pub const CHUNK: usize = 50;

/// Doubles consumed per graph: the sealed scripts draw a full `n × n` block.
#[must_use]
pub fn draws_per_graph(n: usize) -> u128 {
    (n as u128) * (n as u128)
}

/// One tail's summary, in the sealed layout (`mean`, `std`, and the two quantiles
/// the paper's tables quote).
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Moments {
    pub mean: f64,
    pub std: f64,
    pub q99: f64,
    pub q95: f64,
}

/// The null distribution's two statistics.
#[derive(Clone, Debug, PartialEq)]
pub struct Null {
    /// `s[-1] = λ_max(B)`.
    pub lambda_max: Vec<f64>,
    /// `−s[0] = −λ_min(B)`.
    pub neg_lambda_min: Vec<f64>,
}

impl Null {
    /// Summary of the right tail.
    #[must_use]
    pub fn right(&self) -> Moments {
        moments(&self.lambda_max)
    }

    /// Summary of the left tail.
    #[must_use]
    pub fn left(&self) -> Moments {
        moments(&self.neg_lambda_min)
    }
}

/// numpy's default quantile, `method="linear"`.
#[must_use]
pub fn quantile_linear(values: &mut [f64], q: f64) -> f64 {
    values.sort_by(f64::total_cmp);
    let n = values.len();
    assert!(n > 0, "quantile of an empty sample");
    if n == 1 {
        return values[0];
    }
    let pos = q * (n as f64 - 1.0);
    let lo = pos.floor() as usize;
    let hi = (lo + 1).min(n - 1);
    let frac = pos - lo as f64;
    values[lo] + frac * (values[hi] - values[lo])
}

/// `mean`, population `std`, `q99` and `q95` of a sample.
#[must_use]
pub fn moments(sample: &[f64]) -> Moments {
    let n = sample.len() as f64;
    let mean = sample.iter().sum::<f64>() / n;
    let var = sample.iter().map(|x| (x - mean) * (x - mean)).sum::<f64>() / n;
    let mut sorted = sample.to_vec();
    Moments {
        mean,
        std: var.sqrt(),
        q99: quantile_linear(&mut sorted, 0.99),
        q95: quantile_linear(&mut sorted, 0.95),
    }
}

/// Wilson score interval, the sealed formula (`bipartite_power.py::wilson_ci`).
#[must_use]
pub fn wilson_ci(successes: usize, n: usize, z: f64) -> (f64, f64) {
    let p = successes as f64 / n as f64;
    let n = n as f64;
    let denom = 1.0 + z * z / n;
    let centre = (p + z * z / (2.0 * n)) / denom;
    let half = z / denom * (p * (1.0 - p) / n + z * z / (4.0 * n * n)).sqrt();
    ((centre - half).max(0.0), (centre + half).min(1.0))
}

/// Standard error of the `q99` quantile, from the sample's own moments — the
/// derivation `q99_standard_error.py` prints (`z`, `φ(z)`, `f(q99)`, then the
/// binomial SE of the `p`-quantile divided by the density).
#[must_use]
pub fn quantile_standard_error(m: &Moments, q: f64, n_reps: usize, p: f64) -> f64 {
    let z = (q - m.mean) / m.std;
    let phi = (-z * z / 2.0).exp() / (2.0 * std::f64::consts::PI).sqrt();
    let density = phi / m.std;
    (p * (1.0 - p) / n_reps as f64).sqrt() / density
}

/// Run `count` replicates in chunks, each chunk seeking its own stream window.
///
/// `start_draws` is the number of doubles the sequential script would already
/// have consumed when the first replicate starts. Results come back in replicate
/// order, whatever order the workers finished in.
fn run_chunked<T: Send>(
    count: usize,
    start_draws: u128,
    n: usize,
    replicate: impl Fn(&mut Pcg64) -> T + Sync,
) -> Vec<T> {
    let n_chunks = count.div_ceil(CHUNK);
    let slots: Vec<Mutex<Option<Vec<T>>>> = (0..n_chunks).map(|_| Mutex::new(None)).collect();
    let cursor = AtomicUsize::new(0);
    let workers = std::thread::available_parallelism()
        .map_or(1, std::num::NonZeroUsize::get)
        .min(n_chunks);
    std::thread::scope(|scope| {
        for _ in 0..workers {
            scope.spawn(|| {
                loop {
                    let c = cursor.fetch_add(1, Ordering::Relaxed);
                    if c >= n_chunks {
                        break;
                    }
                    let lo = c * CHUNK;
                    let hi = (lo + CHUNK).min(count);
                    let mut rng = Pcg64::seeded();
                    rng.advance(start_draws + lo as u128 * draws_per_graph(n));
                    let mut out = Vec::with_capacity(hi - lo);
                    for _ in lo..hi {
                        out.push(replicate(&mut rng));
                    }
                    *slots[c].lock().expect("no panic while holding the lock") = Some(out);
                }
            });
        }
    });
    let mut flat = Vec::with_capacity(count);
    for (c, slot) in slots.into_iter().enumerate() {
        let chunk = slot
            .into_inner()
            .expect("unpoisoned")
            .unwrap_or_else(|| panic!("chunk {c} was never produced"));
        flat.extend(chunk);
    }
    flat
}

/// The null phase: `n_reps` Erdős–Rényi graphs, both tail statistics per graph —
/// the sealed `run()`'s first loop.
#[must_use]
pub fn null_distribution(n_reps: usize, n: usize, d_bar: f64) -> Null {
    let pairs: Vec<(f64, f64)> = run_chunked(n_reps, 0, n, |rng| {
        let g = Graph::er_h0(rng, n, d_bar);
        let mut b = modularity(&g);
        let stats = order_statistics(n, &mut b, &[1, n]);
        (stats[0], -stats[1])
    });
    Null {
        lambda_max: pairs.iter().map(|p| p.0).collect(),
        neg_lambda_min: pairs.iter().map(|p| p.1).collect(),
    }
}

/// Right-tail power: `k` planted cliques of size `m`, `n_reps` replicates,
/// starting at the stream position the sealed script reaches after the null phase
/// and the configurations before this one.
#[must_use]
pub fn clique_power(
    n_reps: usize,
    n: usize,
    d_bar: f64,
    k_cliques: usize,
    clique_size: usize,
    config_index: usize,
) -> Vec<f64> {
    let start = (N_H0 + config_index * n_reps) as u128 * draws_per_graph(n);
    run_chunked(n_reps, start, n, |rng| {
        let g = Graph::sbm_cliques(rng, n, d_bar, k_cliques, clique_size);
        let mut b = modularity(&g);
        order_statistics(n, &mut b, &[1])[0]
    })
}

/// Left-tail power: bipartite polarization, `n_reps` replicates. This script
/// (`bipartite_power.py`) re-seeds its own generator, so its stream starts at 0
/// and its configurations follow one another.
#[must_use]
pub fn bipartite_power(
    n_reps: usize,
    n: usize,
    m1: usize,
    m2: usize,
    rho_between: f64,
    d_bar: f64,
    config_index: usize,
) -> Vec<f64> {
    let start = (config_index * n_reps) as u128 * draws_per_graph(n);
    run_chunked(n_reps, start, n, |rng| {
        let g = Graph::sbm_bipartite(rng, n, m1, m2, rho_between, d_bar);
        let mut b = modularity(&g);
        -order_statistics(n, &mut b, &[n])[0]
    })
}

/// One row of the paper's `W` vs `A_sym` vs `B` table: the statistic on the null
/// draw and on the plant draw, against the theoretical bulk edge.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct SpectraRow {
    pub statistic: &'static str,
    pub h0: f64,
    pub h1: f64,
    pub bulk_edge: f64,
}

impl SpectraRow {
    /// `λ(H1) − 2√d̄`, the gap column of the sealed table.
    #[must_use]
    pub fn gap(&self) -> f64 {
        self.h1 - self.bulk_edge
    }
}

/// `clique_spectra.py`'s table plus the degree summaries it prints. One stream:
/// H0 is drawn first, then the plant, so the H1 draw consumes the same window the
/// sealed script's does.
#[derive(Clone, Debug, PartialEq)]
pub struct SpectraTable {
    pub w: SpectraRow,
    pub a_sym: SpectraRow,
    pub b: SpectraRow,
    /// `s[0]` of `B` on the null draw — the left tail at the same draw, which M5
    /// prints because the sealed table only carries the right one.
    pub b_min_h0: f64,
    pub h0_degrees: DegreeStats,
    pub h1_inside_degree: f64,
    pub h1_outside_degree: f64,
}

/// Reproduce `clique_spectra.py`: `n = 500`, `d̄ = 20`, one clique of 20 at
/// density 10×, seed 42.
#[must_use]
pub fn clique_spectra_table(
    n: usize,
    d_bar: f64,
    k_cliques: usize,
    clique_size: usize,
) -> SpectraTable {
    let mut rng = Pcg64::seeded();
    let h0 = Graph::er_h0(&mut rng, n, d_bar);
    let h1 = Graph::sbm_cliques(&mut rng, n, d_bar, k_cliques, clique_size);

    // Each row carries the bulk edge the sealed script uses for it: the
    // semicircle edge for `W` and `B`, `2/√d̄` for the normalized `A_sym`.
    let semicircle = bulk_edge(d_bar);
    let normalized_edge = bulk_edge_normalized(d_bar);
    let row = |statistic: &'static str, h0: f64, h1: f64, edge: f64| SpectraRow {
        statistic,
        h0,
        h1,
        bulk_edge: edge,
    };
    let mut a = h0.weights().to_vec();
    let w_h0 = order_statistics(n, &mut a, &[2])[0];
    let mut a = h1.weights().to_vec();
    let w_h1 = order_statistics(n, &mut a, &[2])[0];

    let mut a = h0.symmetric_normalized();
    let asym_h0 = order_statistics(n, &mut a, &[2])[0];
    let mut a = h1.symmetric_normalized();
    let asym_h1 = order_statistics(n, &mut a, &[2])[0];

    let mut b = modularity(&h0);
    let stats = order_statistics(n, &mut b, &[1, n]);
    let (b_h0, b_min_h0) = (stats[0], stats[1]);
    let mut b = modularity(&h1);
    let b_h1 = order_statistics(n, &mut b, &[1])[0];

    let inside_n = k_cliques * clique_size;
    let d1 = h1.degrees();
    SpectraTable {
        w: row("s[-2]", w_h0, w_h1, semicircle),
        a_sym: row("s[-2]", asym_h0, asym_h1, normalized_edge),
        b: row("s[-1]", b_h0, b_h1, semicircle),
        b_min_h0,
        h0_degrees: h0.degree_stats(),
        h1_inside_degree: d1[..inside_n].iter().sum::<f64>() / inside_n as f64,
        h1_outside_degree: d1[inside_n..].iter().sum::<f64>() / (n - inside_n) as f64,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn quantile_matches_numpy_linear_interpolation() {
        // numpy: np.quantile([1, 2, 3, 4], [0.95, 0.99]) = [3.85, 3.97]
        let mut v = vec![1.0, 2.0, 3.0, 4.0];
        assert!((quantile_linear(&mut v, 0.95) - 3.85).abs() < 1e-12);
        assert!((quantile_linear(&mut v, 0.99) - 3.97).abs() < 1e-12);
    }

    #[test]
    fn wilson_interval_matches_the_sealed_formula() {
        // bipartite_power.py, first row: k/n = 0.990 at n = 500 -> [0.977, 0.996]
        let (lo, hi) = wilson_ci(495, 500, 1.96);
        assert!((lo - 0.977).abs() < 5e-4, "lo = {lo}");
        assert!((hi - 0.996).abs() < 5e-4, "hi = {hi}");
    }

    #[test]
    fn quantile_standard_error_reproduces_the_sealed_value() {
        // q99_standard_error.py: mean 8.7679, std 0.1115, q99 9.0542, N = 2000,
        // p = 0.99 -> SE = 0.016802.
        let m = Moments {
            mean: 8.7679,
            std: 0.1115,
            q99: 9.0542,
            q95: 8.9663,
        };
        assert!((quantile_standard_error(&m, 9.0542, 2000, 0.99) - 0.016802).abs() < 5e-6);
    }

    /// The cheap end-to-end check of the machinery: chunked generation (parallel,
    /// stream-seeked) must equal a sequential run of the same phase.
    #[test]
    fn chunked_run_equals_sequential_run() {
        let sequential: Vec<f64> = {
            let mut rng = Pcg64::seeded();
            (0..120)
                .map(|_| {
                    let g = Graph::er_h0(&mut rng, 40, 6.0);
                    let mut b = modularity(&g);
                    -order_statistics(40, &mut b, &[40])[0]
                })
                .collect()
        };
        let via_chunks = run_chunked(120, 0, 40, |rng| {
            let g = Graph::er_h0(rng, 40, 6.0);
            let mut b = modularity(&g);
            -order_statistics(40, &mut b, &[40])[0]
        });
        assert_eq!(sequential, via_chunks, "a chunk sought the wrong window");
    }

    #[test]
    fn clique_spectra_table_reproduces_the_sealed_row() {
        let table = clique_spectra_table(500, 20.0, 1, 20);
        assert!((table.b.h0 - 8.6896).abs() < 1e-4, "B s[-1] H0");
        assert!((table.b.h1 - 10.7011).abs() < 1e-4, "B s[-1] H1");
        assert!((table.w.h1 - 10.6439).abs() < 1e-4, "W s[-2] H1");
        assert!((table.w.h0 - 8.6896).abs() < 1e-4, "W s[-2] H0");
        assert!((table.a_sym.h1 - 0.4316).abs() < 1e-4, "A_sym s[-2] H1");
        assert!((table.a_sym.h0 - 0.4254).abs() < 1e-4, "A_sym s[-2] H0");
        assert!((table.b_min_h0 + 8.8786).abs() < 1e-4, "B s[0] H0");
        assert!((table.a_sym.gap() + 0.0156).abs() < 1e-4, "A_sym gap");
        assert!(table.b.h1 > table.b.bulk_edge);
        // `main.tex`: on the almost regular null graph `λ_max(B) = λ₂(W)` holds
        // "to within 1e-5"; the two sides are different matrices, so this is a
        // tolerance, not an identity.
        assert!(
            (table.b.h0 - table.w.h0).abs() < 1e-4,
            "λ_max(B) = {} vs λ₂(W) = {}",
            table.b.h0,
            table.w.h0
        );
    }
}
