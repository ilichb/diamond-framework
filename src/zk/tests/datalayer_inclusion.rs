//! The drift guard for `integrations/avalanche/test/fixtures/DatalayerInclusion.sol`
//! (R5-1 and R5-2).
//!
//! The fixture is *generated* by `src/zk/scripts/merkle_fixture.sh`, which writes
//! whatever [`merkle_fixture::solidity`] returns and then runs `forge fmt`. So this
//! file cannot compare bytes: it extracts every hex literal the Solidity library
//! carries and requires each value this revision computes to be among them, and it
//! pins the two roots to the values the deployed `verifyEntry` accepts on-chain
//! (`test/DatalayerInclusion.t.sol`). A Rust change without a regeneration — or a
//! regeneration from a reverted convention — fails here.

use std::collections::BTreeSet;

use avip_datalayer::commitment::Entry;
use avip_zk_prover::merkle_fixture::{self, TENSOR_POSITIONS};

/// The emitted fixture, as committed.
fn fixture() -> String {
    let path = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../integrations/avalanche/test/fixtures/DatalayerInclusion.sol");
    std::fs::read_to_string(&path)
        .unwrap_or_else(|e| panic!("the fixture is committed at {}: {e}", path.display()))
}

/// `0x`-prefixed lowercase hex, for comparison with the fixture's literals.
fn hex32(bytes: &[u8; 32]) -> String {
    let mut s = String::from("0x");
    for b in bytes {
        s.push_str(&format!("{b:02x}"));
    }
    s
}

/// Every 64-hex-digit literal in the fixture: `0x…` constants and the proofs.
fn digests(source: &str) -> BTreeSet<String> {
    let mut out = BTreeSet::new();
    let bytes = source.as_bytes();
    let mut i = 0;
    while i + 2 < bytes.len() {
        if bytes[i] == b'0' && (bytes[i + 1] == b'x' || bytes[i + 1] == b'X') {
            let mut j = i + 2;
            while j < bytes.len() && bytes[j].is_ascii_hexdigit() && j - i < 66 {
                j += 1;
            }
            if j - i == 66 {
                out.insert(source[i..j].to_ascii_lowercase());
            }
            i = j;
        } else {
            i += 1;
        }
    }
    out
}

/// Every `hex"…"` payload in the fixture.
fn payloads(source: &str) -> BTreeSet<String> {
    source
        .match_indices("hex\"")
        .filter_map(|(at, needle)| {
            let rest = &source[at + needle.len()..];
            rest.find('"').map(|end| rest[..end].to_ascii_lowercase())
        })
        .collect()
}

/// The 4-entry epoch must reach the contract's own root. `0x6d7dbeea…` is what the
/// deployed `verifyEntry` computes for these four leaves — asserted on-chain, not
/// derived here — so this is the R5-1 pin: one hash fewer and it is a different
/// value.
#[test]
fn the_four_entry_root_is_the_contracts_own() {
    assert_eq!(
        hex32(&merkle_fixture::four_entry_epoch().root()),
        "0x6d7dbeead031ce88ee6f534d9c2fef6063ab9471b1fe3cde38bd0b26555eed36",
        "keccak256(leaf) at the bottom, ordered pairs above it"
    );
}

/// No computed value is missing from the committed fixture, and the fixture has the
/// sizes it declares.
#[test]
fn the_committed_fixture_carries_what_this_revision_computes() {
    let source = fixture();
    let digests = digests(&source);
    let payloads = payloads(&source);

    let four = merkle_fixture::four_entry_epoch();
    let leaves = four.leaves();
    assert!(
        digests.contains(&hex32(&four.root())),
        "the epoch root is missing from the fixture"
    );
    for leaf in &leaves {
        assert!(
            digests.contains(&hex32(leaf)),
            "leaf {} is missing from the fixture",
            hex32(leaf)
        );
    }
    for entry in &four.entries {
        let mut payload = String::new();
        for b in entry.payload() {
            payload.push_str(&format!("{b:02x}"));
        }
        assert!(
            payloads.contains(&payload),
            "a payload is missing from the fixture"
        );
    }
    for i in 0..leaves.len() {
        for sibling in four.inclusion_proof(i).expect("a published leaf") {
            assert!(
                digests.contains(&hex32(&sibling)),
                "a sibling of entry {i} is missing from the fixture"
            );
        }
    }

    let tensor = merkle_fixture::tensor_epoch();
    let tensor_leaves = tensor.leaves();
    assert!(
        digests.contains(&hex32(&tensor.root())),
        "the tensor root is missing from the fixture"
    );
    // The tensor's 500 leaves dominate the file; a single absent one is enough.
    let missing = tensor_leaves
        .iter()
        .filter(|leaf| !digests.contains(&hex32(leaf)))
        .count();
    assert_eq!(
        missing, 0,
        "{missing} tensor leaves are missing from the fixture"
    );
    for position in TENSOR_POSITIONS {
        for sibling in tensor
            .inclusion_proof(position)
            .expect("an emitted position")
        {
            assert!(
                digests.contains(&hex32(&sibling)),
                "a sibling of position {position} is missing from the fixture"
            );
        }
    }

    assert!(
        source.contains(&format!("EPOCH_ENTRIES = {}", leaves.len())),
        "the fixture declares the epoch's size"
    );
    assert!(
        source.contains(&format!("TENSOR_ENTRIES = {}", tensor_leaves.len())),
        "the fixture declares the tensor's size"
    );
}

/// The emitted proofs are the ones `verify_entry` accepts: the same check the
/// Solidity suite makes through the contract, made here through the payloads.
#[test]
fn every_emitted_proof_verifies_against_its_root() {
    let four = merkle_fixture::four_entry_epoch();
    let root = four.root();
    for (i, entry) in four.entries.iter().enumerate() {
        let proof = four.inclusion_proof(i).expect("a published leaf");
        assert!(
            avip_datalayer::commitment::verify_entry(&root, &entry.payload(), &proof),
            "entry {i}"
        );
    }

    let tensor = merkle_fixture::tensor_epoch();
    let tensor_root = tensor.root();
    for position in TENSOR_POSITIONS {
        let entry: &Entry = &tensor.entries[position];
        let proof = tensor
            .inclusion_proof(position)
            .expect("an emitted position");
        assert!(
            avip_datalayer::commitment::verify_entry(&tensor_root, &entry.payload(), &proof),
            "position {position}"
        );
    }
}
