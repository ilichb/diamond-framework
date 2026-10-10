//! The measured table of plan §5.5.6.
//!
//! One run produces every number the M4a note quotes, so the note cannot drift
//! from the code: `scripts/m4a_report.sh` writes this output to
//! `scripts/m4a_output.txt`, the off-chain analogue of M3's
//! `scripts/groth16_fixtures_output.txt`.
//!
//! **Two of those numbers are wall-clock durations and therefore are not in the
//! table.** `render` emits only quantities a re-run reproduces byte for byte —
//! counts, sizes, the digest, `satisfied` flags — while `render_timings` emits
//! `prove`, `verify` and `synthesized` durations on **stderr**, because they
//! depend on machine load: two runs of the same revision produced `3.30 s / 0.27 s`
//! and `5.43 s / 0.44 s` for the same proof. Timing them is still useful (it is
//! what bounds M4b's cost), but a committed table that changes on every run would
//! break the acceptance §5.5.6 states — "every number in the note reproducible by
//! one documented command" — so the durations are reported as a load-dependent
//! observation and the reproducible part is what is pinned.
//!
//! Thresholds: §5.5.4 declares the ones that bind a future re-opening of V1
//! (`c_emu / c_nat ≤ 100` and outer proving `≤ 120 s`). The plan declares **no**
//! numeric threshold for V2 vs V3; `D-M4-0` is decided on the measured cost, and
//! this report states the numbers it will be decided from.

use std::fmt::Write;

use crate::fixture;
use crate::native::{self, CircuitCost, PoseidonNormCircuit};
use crate::range_proof::{self, AggregatedRangeProof};

/// Everything one M4a run measured.
pub struct M4aReport {
    pub fixture_digest: String,
    pub entries: usize,
    pub max_entry: u64,
    pub sum_of_squares: u128,
    pub certified_norm_wad: u64,
    pub range_proof: AggregatedRangeProof,
    /// V3 (§5.5.2): Poseidon commitment + norm in one `Fr` circuit.
    pub v3: CircuitCost,
    /// V3 without the commitment, i.e. the norm alone — the part both variants
    /// share, so the paper's missing number is visible on its own.
    pub v3_norm_only: CircuitCost,
    pub v2_status: &'static str,
}

/// Run every measurement. The aggregated range proof is the slow one: run this
/// under `--release`.
pub fn run() -> M4aReport {
    let tensor = fixture::tensor();
    let range_proof = range_proof::measure(&tensor);

    let entries: Vec<u64> = tensor.entries().to_vec();
    let certified_norm_wad = tensor.wad_norm() as u64;

    let params = native::poseidon_params();
    let commitment = native::poseidon_commitment(&entries, &params);
    let (v3, _) = native::synthesize(PoseidonNormCircuit {
        entries: entries.clone(),
        certified_norm_wad,
        commitment,
        params,
    });
    let (v3_norm_only, _) = native::synthesize(native::NormCircuit {
        entries,
        certified_norm_wad,
    });

    M4aReport {
        fixture_digest: tensor.digest_hex(),
        entries: tensor.entries().len(),
        max_entry: tensor.max_entry(),
        sum_of_squares: tensor.sum_of_squares(),
        certified_norm_wad,
        range_proof,
        v3,
        v3_norm_only,
        v2_status: native::v2::STATUS,
    }
}

impl M4aReport {
    /// The measured table, in the shape §5.5.6 asks for.
    pub fn render(&self) -> String {
        let rp = &self.range_proof;
        let mut s = String::new();
        let _ = writeln!(s, "AVIP M4a — measured table (plan §5.5.6)");
        let _ = writeln!(s, "==========================================");
        let _ = writeln!(s);
        let _ = writeln!(s, "fixture (deterministic, seed {:#x})", fixture::SEED);
        let _ = writeln!(s, "  entries                 : {}", self.entries);
        let _ = writeln!(
            s,
            "  max entry               : {} (< 2^{})",
            self.max_entry,
            fixture::ENTRY_BITS
        );
        let _ = writeln!(s, "  Σ T_i² (WAD²)           : {}", self.sum_of_squares);
        let _ = writeln!(s, "  certifiedNorm (WAD)     : {}", self.certified_norm_wad);
        let _ = writeln!(s, "  keccak256(digest)       : {}", self.fixture_digest);
        let _ = writeln!(s);
        let _ = writeln!(s, "aggregated Bulletproofs range proof (§5.5.3)");
        let _ = writeln!(
            s,
            "  values × bits           : {} × {} = {} bits",
            rp.values, rp.bit_size, rp.aggregate_bits
        );
        let _ = writeln!(
            s,
            "  proof size              : {} bytes ({:.3} KB), {} elements",
            rp.proof_bytes,
            rp.proof_bytes as f64 / 1024.0,
            rp.proof_elements
        );
        let _ = writeln!(
            s,
            "  predicted 2·lg(n)+9     : {} elements ({} bytes)",
            rp.theoretical_elements(),
            rp.theoretical_elements() * 32
        );
        let _ = writeln!(
            s,
            "  paper's estimate        : {} bytes → measured ratio {:.3}×",
            range_proof::PAPER_ESTIMATE_BYTES,
            rp.vs_paper_ratio()
        );
        let _ = writeln!(
            s,
            "  generator set           : {} points; value commitments {} bytes",
            rp.generators_points, rp.commitments_bytes
        );
        let _ = writeln!(s);
        let _ = writeln!(s, "native BN254 circuit, constraint field Fr (§5.5.2)");
        let _ = writeln!(
            s,
            "  V3 norm only            : {} constraints, {} witnesses, {} public, satisfied={}",
            self.v3_norm_only.constraints,
            self.v3_norm_only.witness_variables,
            self.v3_norm_only.instance_variables,
            self.v3_norm_only.satisfied
        );
        let _ = writeln!(
            s,
            "  V3 Poseidon + norm      : {} constraints, {} witnesses, {} public, satisfied={}",
            self.v3.constraints,
            self.v3.witness_variables,
            self.v3.instance_variables,
            self.v3.satisfied
        );
        let _ = writeln!(
            s,
            "  Poseidon share          : {} constraints",
            self.v3
                .constraints
                .saturating_sub(self.v3_norm_only.constraints)
        );
        let _ = writeln!(s);
        let _ = writeln!(s, "V2 status");
        let _ = writeln!(s, "  {}", self.v2_status);
        s
    }

    /// The load-dependent durations, for **stderr**. Deliberately not part of
    /// [`Self::render`]: these change between runs of the same revision, so they
    /// cannot be pinned in the committed table.
    pub fn render_timings(&self) -> String {
        let mut s = String::new();
        let _ = writeln!(
            s,
            "timings (wall-clock, load-dependent — not part of the pinned table):"
        );
        let _ = writeln!(
            s,
            "  range proof prove / verify : {:.3?} / {:.3?}",
            self.range_proof.prove_time, self.range_proof.verify_time
        );
        let _ = writeln!(
            s,
            "  synthesized (norm / full)  : {:.3?} / {:.3?}",
            self.v3_norm_only.synthesize_time, self.v3.synthesize_time
        );
        s
    }
}
