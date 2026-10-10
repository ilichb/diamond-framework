//! The pinned table (plan §5.6).
//!
//! `render` prints everything `scripts/m5_output.txt` contains, in the order it
//! contains it, from the reproduced numbers only — nothing here is transcribed
//! from the sealed files. The pinned file is deterministic: durations go to
//! stderr from `main`, and the parallel phases ([`crate::reproduce`]) are
//! stream-seeked so a different thread count cannot change a digit.

use std::io::Write;

use crate::detector::{ALPHA_0_01, ALPHA_0_05, bulk_edge, detect};
use crate::fixture::{M4_TENSOR_DIGEST_HEX, m4_wired_graph};
use crate::graph::{Graph, bipartite_probabilities};
use crate::line;
use crate::pcg64::Pcg64;
use crate::reproduce::{
    D_BAR, Moments, N, N_H0, N_H1, bipartite_power, clique_power, clique_spectra_table,
    null_distribution, quantile_standard_error, wilson_ci,
};

/// The protocol a run uses: the sealed reference configuration, or a small one
/// for development (`--smoke`).
#[derive(Clone, Copy, Debug)]
pub struct Options {
    pub n: usize,
    pub d_bar: f64,
    pub n_h0: usize,
    pub n_h1: usize,
    pub smoke: bool,
}

impl Options {
    /// `n = 500`, `d̄ = 20`, `N_H0 = 2000`, `N_H1 = 500` — the sealed protocol.
    #[must_use]
    pub fn reference() -> Self {
        Self {
            n: N,
            d_bar: D_BAR,
            n_h0: N_H0,
            n_h1: N_H1,
            smoke: false,
        }
    }

    /// Small enough to finish in seconds: for checking a change, never for the
    /// pinned file.
    #[must_use]
    pub fn smoke() -> Self {
        Self {
            n: 120,
            d_bar: 6.0,
            n_h0: 40,
            n_h1: 40,
            smoke: true,
        }
    }
}

/// `%.4f`, the precision the sealed tables print the reproduced quantities with.
fn f4(x: f64) -> String {
    format!("{x:.4}")
}

/// The `(1 − α)`-rejection rate of a sample and its Wilson interval.
fn tpr(sample: &[f64], threshold: f64) -> (f64, (f64, f64)) {
    let k = sample.iter().filter(|x| **x > threshold).count();
    (
        k as f64 / sample.len() as f64,
        wilson_ci(k, sample.len(), 1.96),
    )
}

/// The right-tail configurations of `calibration_modularity.py`.
const CLIQUE_CONFIGS: [(usize, usize); 5] = [(1, 20), (3, 20), (5, 20), (1, 40), (3, 40)];

/// The left-tail configurations of `bipartite_power.py`.
const BIPARTITE_CONFIGS: [(&str, usize, usize, f64); 6] = [
    ("bipartite 250/250, rb=2", 250, 250, 2.0),
    ("bipartite 250/250, rb=5", 250, 250, 5.0),
    ("bipartite 250/250, rb=10", 250, 250, 10.0),
    ("bipartite 100/400, rb=5", 100, 400, 5.0),
    ("bipartite 100/400, rb=10", 100, 400, 10.0),
    ("bipartite 50/450, rb=10", 50, 450, 10.0),
];

/// Render the whole table. Deterministic: no durations, no thread counts.
pub fn render(out: &mut impl Write, opts: &Options) {
    line(
        out,
        "avip_rmt_detector — M5 sealed reproduction (plan §5.6)",
    );
    line(
        out,
        "======================================================",
    );
    line(
        out,
        &format!(
            "protocol: n={}  d_bar={}  N_H0={}  N_H1={}{}",
            opts.n,
            opts.d_bar,
            opts.n_h0,
            opts.n_h1,
            if opts.smoke {
                "   [SMOKE: not the sealed protocol, do not pin]"
            } else {
                ""
            }
        ),
    );
    line(
        out,
        "stream:   numpy.random.default_rng(42) = PCG64, resumed by src/rmt/src/pcg64.rs",
    );
    line(
        out,
        "sealed:   verification/rmt/{calibration_modularity.py,bipartite_power.py,clique_spectra.py}",
    );
    line(out, "");

    reproduce_null(out, opts);
    reproduce_right_tail(out, opts);
    reproduce_left_tail(out, opts);
    reproduce_clique_spectra(out, opts);
    wire_the_m4_fixture(out, opts);
}

/// `[H0]`: the null distribution, the thresholds derived from it, and the
/// standard error of `q99` recomputed from the reproduced moments.
fn reproduce_null(out: &mut impl Write, opts: &Options) {
    line(
        out,
        "[H0] null distribution of the modularity spectrum B = W - dd^T/(2m)",
    );
    let null = null_distribution(opts.n_h0, opts.n, opts.d_bar);
    let right = null.right();
    let left = null.left();
    line(
        out,
        &format!(
            "  right  s[-1] = lambda_max(B): mean={}  std={}  q99={}  q95={}",
            f4(right.mean),
            f4(right.std),
            f4(right.q99),
            f4(right.q95)
        ),
    );
    line(
        out,
        &format!(
            "  left  -s[0] = -lambda_min(B): mean={}  std={}  q99={}  q95={}",
            f4(left.mean),
            f4(left.std),
            f4(left.q99),
            f4(left.q95)
        ),
    );
    // The SE is *derived*, not measured again: `q99_standard_error.py` recomputes
    // it from the four-decimal moments it printed (its `MEAN`/`STD`/`Q99` are the
    // rounded values), so M5 reports both — the same arithmetic on its own
    // unrounded moments, and on the rounded ones, which is the sealed 0.016802.
    let round4 = |x: f64| (x * 1e4).round() / 1e4;
    let rounded = Moments {
        mean: round4(right.mean),
        std: round4(right.std),
        q99: round4(right.q99),
        q95: round4(right.q95),
    };
    let se = quantile_standard_error(&right, right.q99, opts.n_h0, 0.99);
    let se_sealed = quantile_standard_error(&rounded, rounded.q99, opts.n_h0, 0.99);
    line(
        out,
        &format!(
            "  SE(q99) = {se_sealed:.6} from the sealed four-decimal moments \
             ({se:.6} unrounded; z = {:.4}  SE/q99 = {} %)",
            (right.q99 - right.mean) / right.std,
            f4(100.0 * se_sealed / right.q99)
        ),
    );
    line(
        out,
        &format!("  bulk edge 2*sqrt(d_bar) = {}", f4(bulk_edge(opts.d_bar))),
    );
    line(out, "");
    line(out, "[thresholds] the sealed calibration of detector.rs");
    line(
        out,
        &format!(
            "  alpha=0.01: lambda_max(B) > {}  or  -lambda_min(B) > {}",
            f4(ALPHA_0_01.right),
            f4(ALPHA_0_01.left)
        ),
    );
    line(
        out,
        &format!(
            "  alpha=0.05: lambda_max(B) > {}  or  -lambda_min(B) > {}",
            f4(ALPHA_0_05.right),
            f4(ALPHA_0_05.left)
        ),
    );
    line(
        out,
        "  (the detector reads the 0.01 row; both tails, one rejection each)",
    );
    line(out, "");
}

/// `[right tail]`: `calibration_modularity.py`'s power table.
fn reproduce_right_tail(out: &mut impl Write, opts: &Options) {
    line(out, "[right tail] clique power, s[-1] = lambda_max(B)");
    line(
        out,
        "  config        lambda_max_mean   TPR@0.01   TPR@0.05   CI95(TPR@0.01)",
    );
    for (i, (k, m)) in CLIQUE_CONFIGS.iter().enumerate() {
        let sample = clique_power(opts.n_h1, opts.n, opts.d_bar, *k, *m, i);
        let mean = sample.iter().sum::<f64>() / sample.len() as f64;
        let (t01, ci01) = tpr(&sample, ALPHA_0_01.right);
        let (t05, _) = tpr(&sample, ALPHA_0_05.right);
        line(
            out,
            &format!(
                "  k={k} m={m:<8} {:>12} {:>12} {:>12}   [{}, {}]",
                f4(mean),
                f4(t01),
                f4(t05),
                f4(ci01.0),
                f4(ci01.1)
            ),
        );
    }
    line(out, "");
}

/// `[left tail]`: `bipartite_power.py`'s table, densities included.
fn reproduce_left_tail(out: &mut impl Write, opts: &Options) {
    line(
        out,
        "[left tail] bipartite polarization, -s[0] = -lambda_min(B)",
    );
    line(
        out,
        "  config                    p_within  p_between      mean   TPR@0.01          CI95",
    );
    for (i, (name, m1, m2, rho)) in BIPARTITE_CONFIGS.iter().enumerate() {
        // In `--smoke` the node count is smaller than the reference one, so the
        // blocks are scaled to keep the model well defined; the pinned file is
        // only ever produced in the reference configuration.
        let (m1, m2) = if opts.smoke {
            let scaled = m1 * opts.n / N;
            (scaled, opts.n - scaled)
        } else {
            (*m1, *m2)
        };
        let sample = bipartite_power(opts.n_h1, opts.n, m1, m2, *rho, opts.d_bar, i);
        let mean = sample.iter().sum::<f64>() / sample.len() as f64;
        let (t01, ci01) = tpr(&sample, ALPHA_0_01.left);
        let (p_within, p_between) = bipartite_probabilities(opts.n, m1, m2, *rho, opts.d_bar);
        line(
            out,
            &format!(
                "  {name:<24} {:>8} {:>10} {:>9} {:>9}   [{}, {}]",
                f4(p_within),
                f4(p_between),
                f4(mean),
                f4(t01),
                f4(ci01.0),
                f4(ci01.1)
            ),
        );
    }
    line(out, "");
}

/// `[clique_spectra]`: the paper's `W` vs `A_sym` vs `B` table, recomputed on the
/// sealed single draw, plus the detector's decision on both draws.
fn reproduce_clique_spectra(out: &mut impl Write, opts: &Options) {
    line(
        out,
        "[clique_spectra] one draw of the sealed generator (seed 42)",
    );
    let table = clique_spectra_table(opts.n, opts.d_bar, 1, 20);
    let d = table.h0_degrees;
    line(
        out,
        &format!(
            "  H0 degrees: min={:.0} max={:.0} mean={:.2} std={:.2}",
            d.min, d.max, d.mean, d.std
        ),
    );
    line(
        out,
        "  matrix   stat     lambda(H0)   lambda(H1)   bulk_edge   gap(H1)",
    );
    for (name, row) in [("W", &table.w), ("A_sym", &table.a_sym), ("B", &table.b)] {
        line(
            out,
            &format!(
                "  {name:<8} {:<8} {:>10} {:>12} {:>11}   {:>+9.4}",
                row.statistic,
                f4(row.h0),
                f4(row.h1),
                f4(row.bulk_edge),
                row.gap()
            ),
        );
    }
    line(
        out,
        &format!(
            "  B s[0] on the null draw (left tail, not in the sealed table) = {}",
            f4(table.b_min_h0)
        ),
    );
    line(
        out,
        &format!(
            "  H1 degrees: inside={:.2} outside={}",
            table.h1_inside_degree,
            f4(table.h1_outside_degree)
        ),
    );
    // The detector's decision on both draws, through the public API.
    let mut rng = Pcg64::seeded();
    let h0 = Graph::er_h0(&mut rng, opts.n, opts.d_bar);
    let h1 = Graph::sbm_cliques(&mut rng, opts.n, opts.d_bar, 1, 20);
    for (label, g) in [("null draw", &h0), ("plant draw", &h1)] {
        let det = detect(g, &ALPHA_0_01);
        line(
            out,
            &format!(
                "  detector/{label}: m={:.0}  lambda_max(B)={}  -lambda_min(B)={}  -> {}",
                det.edges,
                f4(det.lambda_max),
                f4(det.neg_lambda_min),
                det.verdict().as_str()
            ),
        );
    }
    line(out, "");
}

/// `[M4 fixture]`: the detector wired to M4's committed digest — the only
/// integration M5 claims, since the paper defines no tensor→graph map (§10).
fn wire_the_m4_fixture(out: &mut impl Write, opts: &Options) {
    line(
        out,
        "[M4 fixture] detector wired to src/zk/fixtures/tensor_digest.txt",
    );
    line(out, &format!("  digest = {}", M4_TENSOR_DIGEST_HEX.trim()));
    line(
        out,
        "  (the paper defines no T -> W map; the digest seeds the graph, see §10)",
    );
    let g = m4_wired_graph(opts.n, opts.d_bar);
    let det = detect(&g, &ALPHA_0_01);
    line(
        out,
        &format!(
            "  graph: n={}  m={:.0}  lambda_max(B)={}  -lambda_min(B)={}  -> {}",
            det.n,
            det.edges,
            f4(det.lambda_max),
            f4(det.neg_lambda_min),
            det.verdict().as_str()
        ),
    );
    // A digest-derived graph is a null-like graph, so the detector should be
    // quiet; if a digest ever lands on a graph above the threshold, that is a
    // finding about the wiring, not a failure of the run — the verdict prints
    // either way.
    line(out, "");
}
