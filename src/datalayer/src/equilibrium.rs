//! The audit equilibrium of `main.tex` `sec:datalayer`, as the sealed script
//! computes it (plan §5.9).
//!
//! `verification/data-layer/simulate_data_layer_v3.py` is sealed: M7b may not
//! edit it, and its output
//! (`results/simulate_data_layer_v3_output.txt`) is the number the paper quotes.
//! This module reproduces that model in Rust, so the equilibrium the paper leans
//! on is carried by code that can be tested and re-run rather than by a script
//! nobody may touch.
//!
//! The model, verbatim from the script and mapped to the paper:
//!
//! | quantity | formula | paper |
//! |---|---|---|
//! | `p_fraud` | `β · p_fake = 0.2 · 0.5 = 0.10` | `p_fraud` in `eq:bstar` |
//! | `B*` | `c_audit / p_fraud = 0.10 / 0.10 = 1.0` | `eq:bstar` |
//! | `n*(B)` | `B < B* ? 0 : min(⌊B/B*⌋, N_VERIFIERS)` | `eq:equilibrium` |
//! | coverage | `n* ≥ 1 ? 1.0 : 0.0` | the script's "every auditor reviews every attestation" |
//! | attacker profit | `(frauds − detections)·v_fraud − detections·S_slash` | `eq:revenue` |
//! | verifier profit | `(detections·B − n*·N·c_audit) / n*` | `eq:revenue` |
//! | integrity | `(N − frauds + detections) / N` | `sec:datalayer` prose |
//!
//! Two things about this module are the point of the milestone, and both are
//! easy to get wrong by accident:
//!
//! 1. **The stream is not reset between the two draws of an epoch.** Each of the
//!    eleven rows starts a fresh `default_rng(42)` (`seed=RNG_SEED` inside
//!    `simulate_scenario`), and within a row the fraud draw and the detection
//!    draw consume from the same stream — which is why the two groups of rows
//!    print *different* fraud means, 49.9 and 50.2, for an identical fraud
//!    model. [`crate::binomial`] reproduces that displacement, and the standard
//!    here is "identical to the sealed file, digit for digit", not
//!    "statistically similar".
//! 2. **`n*` is floored, not rounded.** The script says so in a comment
//!    (`int(B / B_STAR)  # floor, sin round()`), and the cap at `N_VERIFIERS`
//!    shows up as the flat `n* = 20` for `B = 20` and `B = 25`, with the
//!    verifier profit rising again at 25 because the revenue scales with `B`
//!    while the cost stays pinned to `n*`.
//!
//! **Not here.** The bounty and the slash are model parameters; no funds move,
//! and the code that escrows or burns is M8. The `T → W` map is not here either
//! (plan §10 D-7, option (b), open); [`crate::ingestion`] states that as an
//! interface with the paper's properties.

use crate::binomial::Binomial;
use crate::pcg64::Pcg64;

/// Attestations per epoch, `N_ATTESTATIONS`.
pub const N_ATTESTATIONS: i64 = 500;

/// Epochs per scenario, `N_EPOCHS`.
pub const N_EPOCHS: usize = 500;

/// `V_FRAUD`, the value the attacker keeps per undetected fraud.
pub const V_FRAUD: f64 = 1.0;

/// `S_SLASH`, the stake a detected fraud forfeits.
pub const S_SLASH: f64 = 10.0;

/// `C_AUDIT`, the per-attestation audit cost.
pub const C_AUDIT: f64 = 0.10;

/// `BETA_ADVERSARIAL`, the share of the population that is adversarial.
pub const BETA_ADVERSARIAL: f64 = 0.2;

/// `P_FAKE_GIVEN_ADV`, the probability an adversarial attestation is fake.
pub const P_FAKE_GIVEN_ADV: f64 = 0.5;

/// `N_VERIFIERS`, the cap on the equilibrium auditor count.
pub const N_VERIFIERS: i64 = 20;

/// `RNG_SEED`: the stream every row restarts from.
pub const RNG_SEED: u64 = 42;

/// The eleven `B` values the sealed table walks, in order.
pub const B_GRID: [f64; 11] = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 5.0, 10.0, 20.0, 25.0];

/// `p_fraud = β · p_fake`, computed exactly as the script does so the arithmetic
/// is the same arithmetic (`0.2 * 0.5` is `0.1` in binary floating point because
/// halving only shifts the exponent).
#[must_use]
pub fn p_fraud() -> f64 {
    BETA_ADVERSARIAL * P_FAKE_GIVEN_ADV
}

/// `B* = c_audit / p_fraud`: the bounty at which auditing first pays.
#[must_use]
pub fn b_star() -> f64 {
    C_AUDIT / p_fraud()
}

/// `n*(B)`: auditors in equilibrium, floored and capped.
#[must_use]
pub fn equilibrium_auditors(b: f64, b_star: f64) -> i64 {
    if b < b_star {
        0
    } else {
        ((b / b_star) as i64).min(N_VERIFIERS)
    }
}

/// The adversarial share of an epoch, as the script computes it: population
/// share → adversarial attestations. Returned as `(n_adv, n_honest, n_att_adv)`.
#[must_use]
pub fn adversarial_attestations() -> (i64, i64, i64) {
    let n_adv = (100.0 * BETA_ADVERSARIAL) as i64;
    let n_honest = 100 - n_adv;
    let n_att_adv = N_ATTESTATIONS - ((N_ATTESTATIONS as f64) * (n_honest as f64) / 100.0) as i64;
    (n_adv, n_honest, n_att_adv)
}

/// The per-row aggregate the sealed table prints.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Scenario {
    /// The bounty this row was run at.
    pub b: f64,
    /// `n*(B)`.
    pub n_auditors: i64,
    /// `n* ≥ 1 ? 1.0 : 0.0`.
    pub coverage: f64,
    /// Mean frauds per epoch.
    pub frauds_mean: f64,
    /// Mean detections per epoch.
    pub detections_mean: f64,
    /// `Σ detections / max(Σ frauds, 1)`.
    pub detection_rate: f64,
    /// Mean attacker profit per epoch.
    pub attacker_profit: f64,
    /// Mean verifier profit per epoch.
    pub verifier_profit: f64,
    /// Mean integrity, `(N − frauds + detections) / N`.
    pub integrity: f64,
}

/// Run one row of the table: 500 epochs at bounty `b`, from a fresh
/// `default_rng(42)`, exactly as `simulate_scenario(B)` does.
#[must_use]
pub fn simulate(b: f64) -> Scenario {
    simulate_with(b, N_EPOCHS)
}

/// The same, with an explicit epoch count, so tests can pin the first epochs.
#[must_use]
pub fn simulate_with(b: f64, n_epochs: usize) -> Scenario {
    let n_auditors = equilibrium_auditors(b, b_star());
    let coverage = if n_auditors >= 1 { 1.0 } else { 0.0 };
    let (_, _, n_att_adv) = adversarial_attestations();

    let mut rng = Pcg64::seeded();
    let mut binomial = Binomial::new();

    let mut frauds_sum = 0_i64;
    let mut detections_sum = 0_i64;
    let mut attacker_sum = 0.0_f64;
    let mut verifier_sum = 0.0_f64;
    let mut integrity_sum = 0.0_f64;

    for _ in 0..n_epochs {
        let n_frauds = binomial.draw(&mut rng, n_att_adv, P_FAKE_GIVEN_ADV);
        let n_detections = binomial.draw(&mut rng, n_frauds, coverage);
        let attacker_profit =
            (n_frauds - n_detections) as f64 * V_FRAUD - n_detections as f64 * S_SLASH;

        let verifier_profit = if n_auditors > 0 {
            let total_revenue = n_detections as f64 * b;
            let total_cost = (n_auditors * N_ATTESTATIONS) as f64 * C_AUDIT;
            (total_revenue - total_cost) / n_auditors as f64
        } else {
            0.0
        };

        frauds_sum += n_frauds;
        detections_sum += n_detections;
        attacker_sum += attacker_profit;
        verifier_sum += verifier_profit;
        integrity_sum += (N_ATTESTATIONS - n_frauds + n_detections) as f64 / N_ATTESTATIONS as f64;
    }

    let n = n_epochs as f64;
    Scenario {
        b,
        n_auditors,
        coverage,
        frauds_mean: frauds_sum as f64 / n,
        detections_mean: detections_sum as f64 / n,
        detection_rate: detections_sum as f64 / frauds_sum.max(1) as f64,
        attacker_profit: attacker_sum / n,
        verifier_profit: verifier_sum / n,
        integrity: integrity_sum / n,
    }
}

/// Every row of the sealed table, in order.
#[must_use]
pub fn table() -> Vec<Scenario> {
    B_GRID.iter().copied().map(simulate).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The parameters are the paper's, not the script's guesses.
    #[test]
    fn parameters_match_the_sealed_script() {
        assert_eq!(p_fraud(), 0.1);
        assert_eq!(b_star(), 1.0);
    }

    /// The equilibrium is floored at `B*` and capped at `N_VERIFIERS`.
    #[test]
    fn equilibrium_is_floored_at_bstar_and_capped_at_n_verifiers() {
        let bs = b_star();
        assert_eq!(equilibrium_auditors(0.25, bs), 0);
        assert_eq!(equilibrium_auditors(0.75, bs), 0);
        assert_eq!(equilibrium_auditors(1.0, bs), 1, "entry allowed at B = B*");
        assert_eq!(equilibrium_auditors(1.99, bs), 1, "floored, not rounded");
        assert_eq!(equilibrium_auditors(2.0, bs), 2);
        assert_eq!(equilibrium_auditors(20.0, bs), N_VERIFIERS);
        assert_eq!(equilibrium_auditors(25.0, bs), N_VERIFIERS, "capped");
    }

    /// The adversarial share collapses to `n_att_adv = 100`, as the script does.
    #[test]
    fn adversarial_attestations_match_the_script() {
        assert_eq!(adversarial_attestations(), (20, 80, 100));
    }

    /// Below `B*` there is no auditor, so no detection and no verifier revenue —
    /// and the fraud draw is the *first* draw of the stream, unshifted.
    #[test]
    fn below_bstar_the_attacker_keeps_every_fraud() {
        let row = simulate(0.25);
        assert_eq!(row.n_auditors, 0);
        assert_eq!(row.coverage, 0.0);
        assert_eq!(row.detections_mean, 0.0);
        assert_eq!(row.verifier_profit, 0.0);
        assert_eq!(row.frauds_mean, 49.914, "the unshifted stream");
        assert_eq!(row.attacker_profit, 49.914);
        assert_eq!(row.detection_rate, 0.0);
    }

    /// At and above `B*` the second draw enters the stream, the coverage is 1,
    /// every fraud is detected and the attacker's profit flips sign.
    #[test]
    fn at_bstar_coverage_is_total_and_the_stream_shifts() {
        let row = simulate(1.0);
        assert_eq!(row.n_auditors, 1);
        assert_eq!(row.coverage, 1.0);
        assert_eq!(
            row.frauds_mean, 50.2,
            "the same stream, shifted by one draw"
        );
        assert_eq!(row.detections_mean, 50.2);
        assert_eq!(row.detection_rate, 1.0);
        assert_eq!(row.integrity, 1.0);
        assert_eq!(row.attacker_profit, -502.0);
        assert_eq!(row.verifier_profit, 0.2, "(50.2·1 − 1·500·0.1) / 1");
    }

    /// The cap makes the verifier's profit rise again: revenue scales with `B`,
    /// cost is pinned to the capped `n*`.
    #[test]
    fn above_the_cap_revenue_scales_but_cost_does_not() {
        let row = simulate(25.0);
        assert_eq!(row.n_auditors, N_VERIFIERS);
        assert_eq!(row.verifier_profit, 12.75, "(50.2·25 − 20·500·0.1) / 20");
        assert_eq!(row.attacker_profit, -502.0);
    }

    /// No epoch prints a different mean by accident: the whole grid is pinned.
    #[test]
    fn the_whole_grid_matches_the_sealed_table() {
        let expected_frauds = [
            49.914, 49.914, 49.914, 50.2, 50.2, 50.2, 50.2, 50.2, 50.2, 50.2, 50.2,
        ];
        let expected_verifier = [0.0, 0.0, 0.0, 0.2, 25.3, 0.2, 0.2, 0.2, 0.2, 0.2, 12.75];
        let expected = expected_frauds.into_iter().zip(expected_verifier);
        for (row, (frauds, verifier)) in table().iter().zip(expected) {
            assert_eq!(row.frauds_mean, frauds, "B = {}", row.b);
            assert_eq!(row.verifier_profit, verifier, "B = {}", row.b);
        }
    }
}
