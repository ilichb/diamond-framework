//! PoC de la continuación de la auditoría (2026-10-20) — addendum de P-12.
//!
//! Demuestra que `Epoch::freshness_ok` del data layer no impone
//! `entries.len() == TENSOR_SIZE` ni la unicidad de `validator`, porque
//! `changed_entries` colapsa las entradas en un `BTreeMap` por dirección.
//!
//! Fuente canónica. La copia ejecutable se coloca en
//! `src/datalayer/tests/tmp_epoch_shape.rs`, se ejecuta con
//! `cargo test --offline --test tmp_epoch_shape` y se borra después; el log
//! queda en `logs/epoch-shape.txt`.

use avip_datalayer::commitment::{Entry, Epoch, TENSOR_SIZE};

fn validator_of(i: u16) -> [u8; 20] {
    let mut address = [0_u8; 20];
    address[18..].copy_from_slice(&i.to_be_bytes());
    address
}

fn entry(i: u16) -> Entry {
    Entry {
        validator: validator_of(i),
        norm_wad: 1,
    }
}

#[test]
fn genesis_with_501_leaves_and_one_duplicate_is_fresh() {
    let mut entries: Vec<Entry> = (0..TENSOR_SIZE as u16).map(entry).collect();
    entries.push(entry(0));

    let epoch = Epoch::new(0, entries);
    let empty = Epoch::new(0, Vec::new());

    assert_eq!(epoch.entries.len(), TENSOR_SIZE as usize + 1);
    assert_eq!(epoch.changed_entries(&empty), TENSOR_SIZE);
    assert!(epoch.freshness_ok(&empty), "the 501-leaf epoch is accepted");
}

#[test]
fn a_thousand_duplicated_leaves_report_zero_changes() {
    let previous = Epoch::new(0, (0..TENSOR_SIZE as u16).map(entry).collect());
    let entries = (0..TENSOR_SIZE as u16)
        .flat_map(|i| [entry(i), entry(i)])
        .collect();
    let epoch = Epoch::new(1, entries);

    assert_eq!(epoch.entries.len(), 2 * TENSOR_SIZE as usize);
    assert_eq!(epoch.changed_entries(&previous), 0);
    assert_ne!(
        epoch.root(),
        previous.root(),
        "the committed tree did change"
    );
    assert!(
        epoch.freshness_ok(&previous),
        "zero declared changes are accepted"
    );
}
