//! P-33 — temporary audit probe (source only; not part of the crate).
//!
//! Question: does `NormCircuit` reject an entry above 1 WAD?
//!
//! To run: copy this file to `src/zk/tests/tmp_entry_upper_bound.rs` and run
//! `cargo test --offline --test tmp_entry_upper_bound -- --nocapture` from
//! `src/zk`. The copy in the crate was deleted after the run; this source is
//! kept so the probe can be repeated.

use avip_zk_prover::{fixture, native};

#[test]
fn an_entry_above_one_wad_satisfies_the_norm_circuit() {
    let entry = (1u64 << fixture::ENTRY_BITS) - 1;
    assert_eq!(fixture::ENTRY_BITS, 60);
    assert!(
        entry > fixture::WAD,
        "entry {entry} must exceed WAD {}",
        fixture::WAD
    );

    let (cost, synthesis) = native::synthesize(native::NormCircuit {
        entries: vec![entry],
        certified_norm_wad: entry,
    });
    synthesis.expect("synthesis");
    assert!(
        cost.satisfied,
        "entry {entry} = {:.6} WAD satisfies the circuit",
        entry as f64 / fixture::WAD as f64
    );
}
