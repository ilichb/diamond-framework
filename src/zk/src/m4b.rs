//! M4b driver (plan §5.5.4, §5.5.9).
//!
//! `cargo run --release --bin m4b-report` runs the whole pipeline over the
//! committed 500-entry fixture; `scripts/m4b_report.sh` writes stdout to
//! `scripts/m4b_output.txt` and the durations to stderr, the way the M4a driver
//! treats its table.
//!
//! `--smoke` runs the same code over the fixture's first 8 entries, so the
//! pipeline can be checked in seconds before paying for the 93k-constraint key.
//! The table keeps its shape; only `N` differs.

use avip_zk_prover::{fixture, groth16};

/// Entries used by `--smoke`: the fixture's head, with the matching floor norm.
const SMOKE_ENTRIES: usize = 8;

fn main() {
    let smoke = std::env::args().skip(1).any(|arg| arg == "--smoke");
    let tensor = fixture::tensor();
    let (entries, certified_norm_wad) = if smoke {
        let head: Vec<u64> = tensor.entries()[..SMOKE_ENTRIES].to_vec();
        let sum: u128 = head.iter().map(|e| (*e as u128) * (*e as u128)).sum();
        (head, fixture::isqrt(sum) as u64)
    } else {
        (tensor.entries().to_vec(), tensor.wad_norm() as u64)
    };
    if smoke {
        eprintln!(
            "smoke run — {} entries, certifiedNorm {}; NOT the §5.5.6 fixture",
            entries.len(),
            certified_norm_wad
        );
    }

    let measurement = groth16::measure(&entries, certified_norm_wad, 0);
    print!("{}", measurement.render());
    eprint!("{}", measurement.render_timings());
}
