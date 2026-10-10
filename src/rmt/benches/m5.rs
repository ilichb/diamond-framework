//! Detection time on one graph (plan §5.6: the benchmark half of the milestone).
//!
//! `harness = false`, like M4a's bench: this is a measurement, not an assertion.
//! Run with `cargo bench --offline` (release by default); the numbers are
//! load-dependent and are *not* pinned anywhere — only the durations go to
//! stderr in `scripts/m5_report.sh`.

use std::time::Instant;

use avip_rmt_detector::detector::{ALPHA_0_01, detect};
use avip_rmt_detector::graph::Graph;
use avip_rmt_detector::pcg64::Pcg64;

/// Repeats per graph; the minimum is reported, the mean is not (a scheduler
/// hiccup inflates a mean and says nothing about the detector).
const REPS: usize = 5;

fn main() {
    let mut rng = Pcg64::seeded();
    let null = Graph::er_h0(&mut rng, 500, 20.0);
    let plant = Graph::sbm_cliques(&mut rng, 500, 20.0, 1, 20);
    for (label, graph) in [
        ("null    (n=500, d_bar=20)", &null),
        ("plant   (n=500, one clique of 20)", &plant),
    ] {
        let mut best = f64::INFINITY;
        let mut verdict = String::new();
        for _ in 0..REPS {
            let started = Instant::now();
            let detection = detect(graph, &ALPHA_0_01);
            best = best.min(started.elapsed().as_secs_f64());
            verdict = format!(
                "lambda_max={:.4} -lambda_min={:.4} -> {}",
                detection.lambda_max,
                detection.neg_lambda_min,
                detection.verdict().as_str()
            );
        }
        println!("{label}: detect() = {best:.3} s (min of {REPS})  [{verdict}]");
    }
}
