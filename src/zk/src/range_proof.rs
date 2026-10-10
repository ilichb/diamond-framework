//! The aggregated Bulletproofs range proof of plan §5.5.3.
//!
//! §5.5.3 derives the width (`k = 60` bits per entry, `N·k = 30,000` bits) and
//! asks M4a for the real size of that aggregated proof, because the `0.72 KB`
//! of `main.tex` L498 is a literature figure quoted for `N = 500` that the plan
//! already treats as **per threshold**. This module produces that number — and
//! finds that neither of the plan's two parameters is available in the
//! aggregated API, which is why the measured object is `512 × 64` bits:
//!
//! - the width must be one of `n ∈ {8, 16, 32, 64}` (`range_proof/dealer.rs`
//!   L45 and `party.rs` L44 reject anything else, for proving *and* verifying),
//!   so the derived `k = 60` is rounded up to 64;
//! - the value count must be a power of two (`dealer.rs` L48), and `N = 500` is
//!   not one, so the aggregation pads to 512.
//!
//! Both findings are pinned by the fast tests at the bottom of this file.

use std::time::{Duration, Instant};

use bulletproofs::{BulletproofGens, PedersenGens, RangeProof};
use curve25519_dalek::scalar::Scalar;
use merlin::Transcript;

use crate::fixture::Tensor;

/// `0.72 KB`, the figure `main.tex` L498 quotes, in bytes.
pub const PAPER_ESTIMATE_BYTES: usize = 736;
/// Bytes per element of `RangeProof::to_bytes` (a compressed point or scalar).
const ELEMENT_BYTES: usize = 32;

/// The width actually available. §5.5.3 derives `k = 60` from WAD
/// (`2^60 > 1e18`), but the aggregated API of `bulletproofs 5.0.0` accepts only
/// `n ∈ {8, 16, 32, 64}` (`range_proof/dealer.rs` L45, `party.rs` L44 — proving
/// and verifying alike), so the nearest supported width above the derived one is
/// 64. No security is lost: §5.5.3 shows any `k ≤ 122` is wraparound-free, and
/// the wider width costs 6.7% more bits.
pub const RANGE_PROOF_BITS: usize = 64;

/// The value count one aggregated proof can cover here. `Dealer::new` rejects a
/// non-power-of-two count (`m.is_power_of_two()`, `dealer.rs` L48), and `N = 500`
/// is not one: the aggregation pads to 512, so the measured proof covers
/// `512 × 64 = 32,768` bits instead of the `30,000 = 500 × 60` the plan writes
/// down. The padding values are zeros, hence in range and part of no statement;
/// a production deployment would need a defined padding rule.
pub const AGGREGATION_PARTIES: usize = 512;

/// One aggregated range proof over the whole tensor.
#[derive(Clone, Debug)]
pub struct AggregatedRangeProof {
    /// Values proven in range (the `N` entries).
    pub values: usize,
    /// Bits per value (`k`).
    pub bit_size: usize,
    /// `values · bit_size`: the number of secret bits one proof covers.
    pub aggregate_bits: usize,
    /// Serialized proof size, measured.
    pub proof_bytes: usize,
    /// Serialized proof size in 32-byte elements, measured.
    pub proof_elements: usize,
    pub prove_time: Duration,
    pub verify_time: Duration,
    /// Points in the generator set `BulletproofGens::new(k, N)`.
    pub generators_points: usize,
    /// Bytes of the `N` value commitments (one compressed point each).
    pub commitments_bytes: usize,
}

impl AggregatedRangeProof {
    /// `2·lg(n) + 9` elements: 4 points + 3 scalars + `lg n` `L`/`R` pairs + 2
    /// scalars (`RangeProof::to_bytes` docs, crate `range_proof/mod.rs`
    /// L477–487).
    pub fn theoretical_elements(&self) -> usize {
        let lg = (self.aggregate_bits as f64).log2().ceil() as usize;
        2 * lg + 9
    }

    /// Measured size against the paper's `0.72 KB`.
    pub fn vs_paper_ratio(&self) -> f64 {
        self.proof_bytes as f64 / PAPER_ESTIMATE_BYTES as f64
    }
}

/// Prove and verify the aggregated range proof of the fixture, timing both.
///
/// The blindings are derived from the fixture index, not from an RNG, so the
/// statement is reproducible: the same tensor yields the same commitments.
pub fn measure(t: &Tensor) -> AggregatedRangeProof {
    let bp_gens = BulletproofGens::new(RANGE_PROOF_BITS, AGGREGATION_PARTIES);
    let pc_gens = PedersenGens::default();
    // Zero padding to a power-of-two party count: in range, part of no statement.
    let mut values: Vec<u64> = t.entries().to_vec();
    values.resize(AGGREGATION_PARTIES, 0);
    let blindings: Vec<Scalar> = (0..values.len())
        .map(|i| Scalar::from(i as u64 + 1))
        .collect();

    let mut prover_transcript = Transcript::new(b"AVIP-M4a-aggregated-range-proof");
    let started = Instant::now();
    let (proof, commitments) = RangeProof::prove_multiple(
        &bp_gens,
        &pc_gens,
        &mut prover_transcript,
        &values,
        &blindings,
        RANGE_PROOF_BITS,
    )
    .expect("aggregated range proof");
    let prove_time = started.elapsed();

    let bytes = proof.to_bytes();

    let mut verifier_transcript = Transcript::new(b"AVIP-M4a-aggregated-range-proof");
    let started = Instant::now();
    proof
        .verify_multiple(
            &bp_gens,
            &pc_gens,
            &mut verifier_transcript,
            &commitments,
            RANGE_PROOF_BITS,
        )
        .expect("aggregated range proof verifies");
    let verify_time = started.elapsed();

    AggregatedRangeProof {
        values: values.len(),
        bit_size: RANGE_PROOF_BITS,
        aggregate_bits: values.len() * RANGE_PROOF_BITS,
        proof_bytes: bytes.len(),
        proof_elements: bytes.len() / ELEMENT_BYTES,
        prove_time,
        verify_time,
        // `G_vec`/`H_vec` are per party, namespaced by party index.
        generators_points: 2 * bp_gens.gens_capacity * bp_gens.party_capacity,
        commitments_bytes: commitments.len() * ELEMENT_BYTES,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::fixture;
    use crate::fixture::{ENTRY_BITS, N};
    use bulletproofs::ProofError;

    /// §5.5.3 derives `k = 60`, and the aggregated API of `bulletproofs 5.0.0`
    /// offers only `{8, 16, 32, 64}`. Fast and re-runnable: the dealer rejects
    /// the width before any proof work happens.
    #[test]
    fn the_derived_width_is_not_offered_by_the_aggregated_api() {
        assert_eq!(ENTRY_BITS, 60, "the plan's derived width");
        assert!(!matches!(ENTRY_BITS, 8 | 16 | 32 | 64));
        const { assert!(RANGE_PROOF_BITS > ENTRY_BITS) }; // the available width is wider
        let bp = BulletproofGens::new(ENTRY_BITS, 1);
        let pc = PedersenGens::default();
        let mut transcript = Transcript::new(b"AVIP-M4a-width-probe");
        let result = RangeProof::prove_multiple(
            &bp,
            &pc,
            &mut transcript,
            &[1u64],
            &[Scalar::ONE],
            ENTRY_BITS,
        );
        assert!(
            matches!(result, Err(ProofError::InvalidBitsize)),
            "k = {ENTRY_BITS} must be rejected by the aggregated API"
        );
    }

    /// `N = 500` is not a power of two, and `Dealer::new` requires one, so the
    /// `30,000`-bit aggregate §5.5.3 writes down is not constructible.
    #[test]
    fn the_value_count_must_be_a_power_of_two() {
        assert_eq!(N, 500);
        assert!(!N.is_power_of_two());
        assert!(AGGREGATION_PARTIES.is_power_of_two());
        const { assert!(AGGREGATION_PARTIES > N) }; // padding, not truncation
        let bp = BulletproofGens::new(8, 4);
        let pc = PedersenGens::default();
        let mut transcript = Transcript::new(b"AVIP-M4a-aggregation-probe");
        let values = [1u64, 2, 3];
        let blindings = [Scalar::ONE; 3];
        let result = RangeProof::prove_multiple(&bp, &pc, &mut transcript, &values, &blindings, 8);
        assert!(
            matches!(result, Err(ProofError::InvalidAggregation)),
            "three values must be rejected: m has to be a power of two"
        );
    }

    /// Heavy: one 32,768-bit proof. Run with
    /// `cargo test --release -- --ignored --nocapture`.
    #[test]
    #[ignore = "32,768-bit proof: needs --release"]
    fn aggregated_range_proof_is_measured() {
        let m = measure(&fixture::tensor());
        println!("{m:#?}");
        println!(
            "theoretical elements {} -> {} bytes; measured {} bytes ({:.3} x paper's {})",
            m.theoretical_elements(),
            m.theoretical_elements() * ELEMENT_BYTES,
            m.proof_bytes,
            m.vs_paper_ratio(),
            PAPER_ESTIMATE_BYTES
        );
        assert_eq!(m.values, AGGREGATION_PARTIES);
        assert_eq!(m.aggregate_bits, 512 * 64, "the constructible aggregate");
        assert_eq!(m.proof_elements, m.theoretical_elements());
        assert!(m.verify_time.as_secs() < 120);
    }
}
