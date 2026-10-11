//! The two fixtures M7b is pinned by, and the transcription verdict computed from
//! them (plan §5.9).
//!
//! Both are read through `include_str!`, so neither `bin/m7b-probe` nor
//! [`crate::report`] can run against a stale file it happens to find on disk:
//!
//! - `numpy_binomial_seed42.txt` holds what **numpy 2.2.6 itself** drew, group by
//!   group (`scripts/gen_fixture.py` is the heredoc that regenerates it). It is
//!   the evidence for the one claim the milestone rests on: that
//!   [`crate::binomial`] is a transcription and not an approximation.
//! - `sealed_reference.txt` holds the verbatim lines of
//!   `verification/data-layer/results/simulate_data_layer_v3_output.txt`, the
//!   sealed script's own output, one block per sealed file. `scripts/m7b_report.sh`
//!   checks it in both directions.
//!
//! Nothing here reads `verification/` at build time: a failure is always readable
//! as "M7b disagrees", never as "the sealed file moved".

use crate::binomial::Binomial;
use crate::pcg64::Pcg64;

/// numpy's own draws, as `scripts/gen_fixture.py` printed them.
pub const NUMPY: &str = include_str!("../fixtures/numpy_binomial_seed42.txt");

/// Verbatim lines copied from the sealed data-layer output.
pub const SEALED: &str = include_str!("../fixtures/sealed_reference.txt");

/// The groups `numpy_binomial_seed42.txt` pins, in the order it prints them:
/// BTPE, inversion, and both mirrored `p > 0.5` branches, plus the sealed
/// script's own interleaving at `coverage = 1.0` and `coverage = 0.0`.
pub const GROUPS: [&str; 10] = [
    "btpe100_05(500)",
    "btpe1000_05(200)",
    "inv3_05(200)",
    "highp100_09(200)",
    "highp1000_09(200)",
    "degenerate(6)",
    "sealed_cov1_frauds(500)",
    "sealed_cov1_detections(500)",
    "sealed_cov0_frauds(500)",
    "sealed_cov0_detections(500)",
];

/// One `key = values` line of [`NUMPY`].
#[must_use]
pub fn values(key: &str) -> Vec<i64> {
    NUMPY
        .lines()
        .filter(|l| !l.trim_start().starts_with('#'))
        .find_map(|l| l.strip_prefix(&format!("{key} =")))
        .unwrap_or_else(|| panic!("fixture has no `{key}`"))
        .split_whitespace()
        .map(|t| t.parse().expect("i64"))
        .collect()
}

/// The sealed script's interleaving: a fraud draw, then a detection draw with the
/// coverage as `p`, from one generator.
#[must_use]
pub fn interleaved(n: i64, p: f64, coverage: f64, count: usize) -> (Vec<i64>, Vec<i64>) {
    let mut rng = Pcg64::seeded();
    let mut binomial = Binomial::new();
    let mut frauds = Vec::with_capacity(count);
    let mut detections = Vec::with_capacity(count);
    for _ in 0..count {
        let nf = binomial.draw(&mut rng, n, p);
        frauds.push(nf);
        detections.push(binomial.draw(&mut rng, nf, coverage));
    }
    (frauds, detections)
}

/// Rebuild one fixture group from the transcribed implementation.
#[must_use]
pub fn reproduce(group: &str) -> Vec<i64> {
    let mut rng = Pcg64::seeded();
    let mut binomial = Binomial::new();
    match group {
        "btpe100_05(500)" => (0..500)
            .map(|_| binomial.draw(&mut rng, 100, 0.5))
            .collect(),
        "btpe1000_05(200)" => (0..200)
            .map(|_| binomial.draw(&mut rng, 1000, 0.5))
            .collect(),
        "inv3_05(200)" => (0..200).map(|_| binomial.draw(&mut rng, 3, 0.5)).collect(),
        "highp100_09(200)" => (0..200)
            .map(|_| binomial.draw(&mut rng, 100, 0.9))
            .collect(),
        "highp1000_09(200)" => (0..200)
            .map(|_| binomial.draw(&mut rng, 1000, 0.9))
            .collect(),
        "degenerate(6)" => [(0, 0.5), (5, 0.0), (5, 1.0), (100, 1.0), (0, 0.0), (1, 0.0)]
            .iter()
            .map(|&(n, p)| binomial.draw(&mut rng, n, p))
            .collect(),
        "sealed_cov1_frauds(500)" => interleaved(100, 0.5, 1.0, 500).0,
        "sealed_cov1_detections(500)" => interleaved(100, 0.5, 1.0, 500).1,
        "sealed_cov0_frauds(500)" => interleaved(100, 0.5, 0.0, 500).0,
        "sealed_cov0_detections(500)" => interleaved(100, 0.5, 0.0, 500).1,
        other => panic!("no reproduction rule for `{other}`"),
    }
}

/// `k` doubles after the first: the smallest `advance(k)` that lands on the
/// generator's state after `f`. `None` if the draw consumed more than 64, which
/// BTPE's rejection loop makes possible in principle and never in this fixture.
///
/// This is how the crate states its consumption claims (0 doubles for `p = 0`,
/// 1 for `p = 1`, 2 for a BTPE attempt) as *measurements* rather than as
/// folklore about numpy's C code.
#[must_use]
pub fn consumed(f: impl FnOnce(&mut Pcg64)) -> Option<u128> {
    let mut rng = Pcg64::seeded();
    f(&mut rng);
    let after = rng.state();
    (0..=64).find(|&k| {
        let mut probe = Pcg64::seeded();
        probe.advance(k);
        probe.state() == after
    })
}

/// What the transcription check found: how many groups matched, how many draws
/// were compared, and the first divergence, if any.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Transcription {
    /// Groups whose draws matched numpy's, group by group.
    pub groups_ok: usize,
    /// Draws compared across all [`GROUPS`].
    pub draws: usize,
    /// `(group, index, numpy, rust)` of the first divergence, if there is one.
    pub divergence: Option<(String, usize, i64, i64)>,
}

impl Transcription {
    /// Whether every group matched.
    #[must_use]
    pub fn holds(&self) -> bool {
        self.divergence.is_none()
    }
}

/// Compare every group of [`GROUPS`] against [`NUMPY`], draw by draw.
#[must_use]
pub fn transcription() -> Transcription {
    let mut groups_ok = 0;
    let mut draws = 0;
    let mut divergence = None;
    for group in GROUPS {
        let expected = values(group);
        let got = reproduce(group);
        draws += expected.len();
        let first = expected
            .iter()
            .zip(&got)
            .position(|(a, b)| a != b)
            .unwrap_or_else(|| expected.len().min(got.len()));
        if first == expected.len() && first == got.len() {
            groups_ok += 1;
        } else if divergence.is_none() {
            divergence = Some((
                group.to_string(),
                first,
                expected.get(first).copied().unwrap_or(-1),
                got.get(first).copied().unwrap_or(-1),
            ));
        }
    }
    Transcription {
        groups_ok,
        draws,
        divergence,
    }
}

/// The `n = 50`, `p ∈ {0, 1}` and BTPE draws, as `(call, doubles consumed)`.
///
/// The first two are the milestone's headline: they are the reason two rows of the
/// sealed table print *different* fraud means for an identical fraud model.
#[must_use]
pub fn consumption() -> [(&'static str, Option<u128>); 4] {
    [
        (
            "binomial(50, 0.0)",
            consumed(|rng| {
                Binomial::new().draw(rng, 50, 0.0);
            }),
        ),
        (
            "binomial(50, 1.0)",
            consumed(|rng| {
                Binomial::new().draw(rng, 50, 1.0);
            }),
        ),
        (
            "binomial(100, 0.5)",
            consumed(|rng| {
                Binomial::new().draw(rng, 100, 0.5);
            }),
        ),
        (
            "two cached draws",
            consumed(|rng| {
                let mut b = Binomial::new();
                b.draw(rng, 100, 0.5);
                b.draw(rng, 100, 0.5);
            }),
        ),
    ]
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The claim the milestone rests on: every group matches numpy, draw by draw.
    #[test]
    fn the_transcription_holds_on_every_group() {
        let verdict = transcription();
        assert!(verdict.holds(), "divergence: {:?}", verdict.divergence);
        assert_eq!(verdict.groups_ok, GROUPS.len());
        assert_eq!(verdict.draws, 3306, "the fixture's total draw count");
    }

    /// The consumption claims, measured against `advance(k)`.
    #[test]
    fn the_degenerate_cases_consume_nothing_and_one() {
        let measured = consumption();
        assert_eq!(measured[0].1, Some(0), "p = 0 returns before the stream");
        assert_eq!(measured[1].1, Some(1), "p = 1 lands in inversion");
        assert_eq!(measured[2].1, Some(2), "one BTPE attempt, no rejection");
        assert_eq!(measured[3].1, Some(4), "the second draw reuses the cache");
    }
}
