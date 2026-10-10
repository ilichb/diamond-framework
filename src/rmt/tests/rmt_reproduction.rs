//! Integration tests for M5 (plan §5.6).
//!
//! What is tested here:
//! 1. that the four thresholds [`avip_rmt_detector::detector`] carries still
//!    appear in the sealed reference (`fixtures/sealed_reference.txt`, whose lines
//!    `scripts/m5_report.sh` checks against `verification/rmt/results/`), so a
//!    constant cannot drift away from the calibration it quotes;
//! 2. that the single-draw table (`W`/`A_sym`/`B`) still lands on the sealed
//!    four-decimal values;
//! 3. behind `#[ignore]`, the full sealed protocol — `N_H0 = 2000` plus both power
//!    tables — against those same values. It takes minutes even in release:
//!    `cargo test --release -- --ignored`.
//!
//! What is **not** tested: anything on-chain (the alert is a struct; turning it
//! into slashing is M7/M8), and no real collaboration graph exists to test
//! against (§10, open).

use avip_rmt_detector::detector::{
    ALPHA_0_01, ALPHA_0_05, Calibration, detect, modularity, order_statistics,
};
use avip_rmt_detector::graph::{Graph, bipartite_probabilities};
use avip_rmt_detector::pcg64::Pcg64;
use avip_rmt_detector::reproduce::{
    D_BAR, N, N_H0, N_H1, bipartite_power, clique_power, clique_spectra_table, null_distribution,
};

/// The non-comment lines of the sealed reference.
fn reference_lines() -> Vec<String> {
    let path = concat!(env!("CARGO_MANIFEST_DIR"), "/fixtures/sealed_reference.txt");
    std::fs::read_to_string(path)
        .expect("fixtures/sealed_reference.txt is committed")
        .lines()
        .filter(|l| !l.trim_start().starts_with('#') && !l.trim().is_empty())
        .map(str::to_owned)
        .collect()
}

/// Is `value`, printed to four decimals (the sealed precision), in the reference?
fn in_reference(value: f64) -> bool {
    let token = format!("{value:.4}");
    reference_lines().iter().any(|l| l.contains(&token))
}

fn assert_in_reference(value: f64, what: &str) {
    assert!(
        in_reference(value),
        "{what} = {value:.4} is not among the sealed values"
    );
}

#[test]
fn thresholds_are_the_sealed_ones() {
    for (cal, what) in [(ALPHA_0_01, "alpha = 0.01"), (ALPHA_0_05, "alpha = 0.05")] {
        assert_in_reference(cal.right, &format!("{what} right"));
        assert_in_reference(cal.left, &format!("{what} left"));
    }
    assert_eq!(ALPHA_0_01.alpha, 0.01);
    assert_eq!(ALPHA_0_05.alpha, 0.05);
}

#[test]
fn single_draw_table_matches_the_reference() {
    let table = clique_spectra_table(500, 20.0, 1, 20);
    assert_in_reference(table.w.h0, "W s[-2] H0");
    assert_in_reference(table.w.h1, "W s[-2] H1");
    assert_in_reference(table.w.gap(), "W gap");
    assert_in_reference(table.a_sym.h0, "A_sym s[-2] H0");
    assert_in_reference(table.a_sym.h1, "A_sym s[-2] H1");
    assert_in_reference(table.a_sym.gap(), "A_sym gap");
    assert_in_reference(table.b.h0, "B s[-1] H0");
    assert_in_reference(table.b.h1, "B s[-1] H1");
    assert_in_reference(table.b.gap(), "B gap");
    assert_in_reference(table.b.bulk_edge, "bulk edge");
}

#[test]
fn detector_reaches_the_decisions_the_paper_reports() {
    // The plant draw is above the right-tail threshold, the null draw is not, and
    // a strongly bipartite graph is above the left-tail threshold.
    let mut rng = Pcg64::seeded();
    let h0 = Graph::er_h0(&mut rng, 500, 20.0);
    let h1 = Graph::sbm_cliques(&mut rng, 500, 20.0, 1, 20);
    assert!(!detect(&h0, &ALPHA_0_01).right_alert);
    assert!(detect(&h1, &ALPHA_0_01).right_alert);
    let mut rng = Pcg64::seeded();
    let bipartite = Graph::sbm_bipartite(&mut rng, 500, 250, 250, 10.0, 20.0);
    assert!(detect(&bipartite, &ALPHA_0_01).left_alert);
}

#[test]
fn calibration_direction_is_preserved() {
    // The 0.01 thresholds must sit above the 0.05 ones on both tails (checked at
    // compile time, since both sides are constants), and the module API must agree
    // with `detect` on the same draw.
    const _: () = assert!(ALPHA_0_01.right > ALPHA_0_05.right);
    const _: () = assert!(ALPHA_0_01.left > ALPHA_0_05.left);
    let custom: Calibration = ALPHA_0_01;
    let mut rng = Pcg64::seeded();
    let h0 = Graph::er_h0(&mut rng, 500, 20.0);
    let mut b = modularity(&h0);
    let stats = order_statistics(500, &mut b, &[1, 500]);
    let d = detect(&h0, &custom);
    assert!((stats[0] - d.lambda_max).abs() < 1e-12);
    assert!((-stats[1] - d.neg_lambda_min).abs() < 1e-12);
}

/// The full sealed protocol: minutes, not seconds.
/// `cargo test --release -- --ignored` (or `cargo test --release -- --ignored full_sealed`).
#[test]
#[ignore = "the sealed protocol at n = 500 (N_H0 + 5 + 6 configurations); run with --release -- --ignored"]
fn full_sealed_protocol_reproduces_the_quantiles() {
    let null = null_distribution(N_H0, N, D_BAR);
    let right = null.right();
    let left = null.left();
    for (value, what) in [
        (right.mean, "H0 lambda_max mean"),
        (right.std, "H0 lambda_max std"),
        (right.q99, "q99 right tail"),
        (right.q95, "q95 right tail"),
        (left.mean, "H0 -lambda_min mean"),
        (left.std, "H0 -lambda_min std"),
        (left.q99, "q99 left tail"),
        (left.q95, "q95 left tail"),
    ] {
        assert_in_reference(value, what);
    }

    for (i, (k, m)) in [(1usize, 20usize), (3, 20), (5, 20), (1, 40), (3, 40)]
        .iter()
        .enumerate()
    {
        let sample = clique_power(N_H1, N, D_BAR, *k, *m, i);
        let mean = sample.iter().sum::<f64>() / sample.len() as f64;
        assert_in_reference(mean, &format!("k={k} m={m} mean"));
        let k01 = sample.iter().filter(|x| **x > ALPHA_0_01.right).count();
        assert_in_reference(k01 as f64 / N_H1 as f64, &format!("k={k} m={m} TPR@0.01"));
        let k05 = sample.iter().filter(|x| **x > ALPHA_0_05.right).count();
        assert_in_reference(k05 as f64 / N_H1 as f64, &format!("k={k} m={m} TPR@0.05"));
    }

    for (i, (name, m1, m2, rho)) in [
        ("250/250 rb=2", 250usize, 250usize, 2.0),
        ("250/250 rb=5", 250, 250, 5.0),
        ("250/250 rb=10", 250, 250, 10.0),
        ("100/400 rb=5", 100, 400, 5.0),
        ("100/400 rb=10", 100, 400, 10.0),
        ("50/450 rb=10", 50, 450, 10.0),
    ]
    .iter()
    .enumerate()
    {
        let sample = bipartite_power(N_H1, N, *m1, *m2, *rho, D_BAR, i);
        let mean = sample.iter().sum::<f64>() / sample.len() as f64;
        assert_in_reference(mean, &format!("bipartite {name} mean"));
        let (p_within, p_between) = bipartite_probabilities(N, *m1, *m2, *rho, D_BAR);
        assert_in_reference(p_within, &format!("bipartite {name} p_within"));
        assert_in_reference(p_between, &format!("bipartite {name} p_between"));
    }
}
