//! The Solidity half of R5-1: `DatalayerInclusion.sol`.
//!
//! R5-1 was a one-hash disagreement. `AVIPRegistry.verifyEntry` takes a `bytes32
//! leaf` and starts from `keccak256(leaf)`; `avip_datalayer::commitment` folded the
//! leaves directly. Each side was self-consistent and each suite compared only
//! against itself, so no test failed: the contract rejects the honest proof, and
//! nothing noticed because no contract consumes `verifyEntry` yet.
//!
//! The fix is the data layer's (`bottom_node`), because the contract is deployed and
//! changing it would be bytecode and a redeploy. This module emits the *data
//! layer's* answer — payloads, leaves, root and proofs, computed by
//! `avip_datalayer::commitment` — as a Solidity library, so the contract's own
//! `verifyEntry` can be run against it. `test/DatalayerInclusion.t.sol` is the
//! consumer; `tests/datalayer_inclusion.rs` is the drift guard on this end.
//!
//! Two vectors are emitted, for two different reasons:
//!
//! * a **4-entry epoch** with the payloads, so the chain payload → `keccak256` →
//!   leaf → `keccak256` → bottom node → root runs end to end across the language
//!   boundary, and `cast keccak`'s `root(4)` in
//!   `src/datalayer/fixtures/keccak256_vectors.txt` is confirmed by a third
//!   implementation;
//! * the **500-entry bridged tensor** (`bridge::tensor_state` over the §5.5.6
//!   fixture: 500 → 250 → **125** → …), whose level of 125 nodes is odd. There the
//!   two possible rules for an unpaired node — duplicate it and hash the pair, or
//!   promote it unchanged — give different roots, and only promotion is what a
//!   `verifyEntry` proof can describe. That is R5-2, and it was a fixture bug in
//!   `AVIPRegistry.t.sol`'s `_buildTree`, not a contract bug.

use std::fmt::Write as _;

use avip_datalayer::commitment::{Entry, Epoch};

use crate::bridge::tensor_state;
use crate::fixture;

/// Where the generated fixture lives, resolved from this crate rather than from
/// the working directory.
pub const OUTPUT: &str = concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/../../integrations/avalanche/test/fixtures/DatalayerInclusion.sol"
);

/// The tensor positions whose proofs are emitted: the first, one past the odd
/// level's midpoint, and the last.
pub const TENSOR_POSITIONS: [usize; 3] = [0, 250, fixture::N - 1];

/// Lowercase hex, no `0x`.
fn hex(bytes: &[u8]) -> String {
    let mut s = String::with_capacity(2 * bytes.len());
    for b in bytes {
        let _ = write!(s, "{b:02x}");
    }
    s
}

/// `0x`-prefixed lowercase hex of a digest.
fn hex32(bytes: &[u8; 32]) -> String {
    format!("0x{}", hex(bytes))
}

/// The four entries `src/datalayer/fixtures/keccak256_vectors.txt` pins:
/// `0x11..11`, `0x22..22`, `0x33..33` and `0x44..44`, with norms 1, 0.5, 2 and 3
/// WAD. Same entries, same epoch number, so `root(4)` is the same value.
#[must_use]
pub fn four_entry_epoch() -> Epoch {
    Epoch::new(
        7,
        [
            (0x11_u8, 1_000_000_000_000_000_000_u128),
            (0x22, 500_000_000_000_000_000),
            (0x33, 2_000_000_000_000_000_000),
            (0x44, 3_000_000_000_000_000_000),
        ]
        .into_iter()
        .map(|(byte, norm_wad)| Entry {
            validator: [byte; 20],
            norm_wad,
        })
        .collect::<Vec<_>>(),
    )
}

/// The bridged tensor as an `Epoch`: entry `i` = (position `i`, `T[i]` WAD).
#[must_use]
pub fn tensor_epoch() -> Epoch {
    tensor_state(fixture::tensor().entries(), 0)
}

/// The emitted Solidity library.
#[must_use]
pub fn solidity() -> String {
    let four = four_entry_epoch();
    let four_leaves = four.leaves();
    let four_proofs: Vec<Vec<[u8; 32]>> = (0..four_leaves.len())
        .map(|i| {
            four.inclusion_proof(i)
                .expect("a published leaf is provable")
        })
        .collect();

    let tensor = tensor_epoch();
    let tensor_leaves = tensor.leaves();
    let tensor_proofs: Vec<Vec<[u8; 32]>> = TENSOR_POSITIONS
        .iter()
        .map(|&position| {
            tensor
                .inclusion_proof(position)
                .expect("a position inside the tensor is provable")
        })
        .collect();

    let mut w = String::new();
    let _ = write!(
        w,
        r#"// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title DatalayerInclusion
/// @notice The data layer's own answer to the inclusion question, emitted by
///         `src/zk/src/merkle_fixture.rs` (`src/zk/scripts/merkle_fixture.sh`) and
///         consumed by `test/DatalayerInclusion.t.sol`.
/// @dev **Generated — do not edit.** Regenerate with the script, which also runs
///      `forge fmt`; `src/zk/tests/datalayer_inclusion.rs` fails if any value here
///      is not the one the Rust crate computes. Two vectors, for two findings:
///        - `EPOCH_ROOT`/`payloads`/`leaves`/`proofs`: a 4-entry epoch, so payload
///          → `keccak256` → leaf → `keccak256` → bottom node → root is checked
///          across the language boundary (R5-1);
///        - `TENSOR_ROOT`/`tensor*`: the 500-entry bridged tensor, whose 125-node
///          level is odd and therefore separates promotion from duplication
///          (R5-2).
library DatalayerInclusion {{
    /// @notice The number of entries in the 4-entry vector.
    uint256 internal constant EPOCH_ENTRIES = {epoch_entries};

    /// @notice `verifyEntry`'s root for that epoch: `keccak256(leaf)` at the
    ///         bottom, ordered pairs above it, odd node promoted.
    bytes32 internal constant EPOCH_ROOT = {epoch_root};

    /// @notice The number of entries in the bridged tensor.
    uint256 internal constant TENSOR_ENTRIES = {tensor_entries};

    /// @notice The same root over the tensor: 500 → 250 → 125 → …
    bytes32 internal constant TENSOR_ROOT = {tensor_root};

    /// @notice The entries' `abi.encodePacked(address, uint256)` payloads, in
    ///         entry order: 52 bytes each.
    function payloads() internal pure returns (bytes[] memory p) {{
        p = new bytes[](EPOCH_ENTRIES);
"#,
        epoch_entries = four_leaves.len(),
        epoch_root = hex32(&four.root()),
        tensor_entries = tensor_leaves.len(),
        tensor_root = hex32(&tensor.root()),
    );
    for (i, entry) in four.entries.iter().enumerate() {
        let _ = writeln!(w, "        p[{i}] = hex\"{}\";", hex(&entry.payload()));
    }

    let _ = write!(
        w,
        r#"    }}

    /// @notice `keccak256(payload)` per entry: the leaf the tree hashes.
    function leaves() internal pure returns (bytes32[] memory l) {{
        l = new bytes32[](EPOCH_ENTRIES);
"#
    );
    for (i, leaf) in four_leaves.iter().enumerate() {
        let _ = writeln!(w, "        l[{i}] = {};", hex32(leaf));
    }

    let _ = write!(
        w,
        r#"    }}

    /// @notice The inclusion proof of each entry, bottom-up, in `verifyEntry`'s
    ///         order: the sibling per level, none for an unpaired node.
    function proofs() internal pure returns (bytes32[][] memory p) {{
        p = new bytes32[][](EPOCH_ENTRIES);
"#
    );
    for (i, proof) in four_proofs.iter().enumerate() {
        let _ = writeln!(w, "        p[{i}] = new bytes32[]({});", proof.len());
        for (level, sibling) in proof.iter().enumerate() {
            let _ = writeln!(w, "        p[{i}][{level}] = {};", hex32(sibling));
        }
    }

    let _ = write!(
        w,
        r#"    }}

    /// @notice The tensor's leaves, `keccak256(abi.encodePacked(position, T[i]))`,
    ///         in position order.
    function tensorLeaves() internal pure returns (bytes32[] memory l) {{
        l = new bytes32[](TENSOR_ENTRIES);
"#
    );
    for (i, leaf) in tensor_leaves.iter().enumerate() {
        let _ = writeln!(w, "        l[{i}] = {};", hex32(leaf));
    }

    let _ = write!(
        w,
        r#"    }}

    /// @notice The positions whose proofs are emitted, ascending.
    function tensorPositions() internal pure returns (uint256[] memory p) {{
        p = new uint256[]({});
"#,
        TENSOR_POSITIONS.len()
    );
    for (i, position) in TENSOR_POSITIONS.iter().enumerate() {
        let _ = writeln!(w, "        p[{i}] = {position};");
    }

    let _ = write!(
        w,
        r#"    }}

    /// @notice The proof of each of `tensorPositions()`.
    function tensorProofs() internal pure returns (bytes32[][] memory p) {{
        p = new bytes32[][]({});
"#,
        TENSOR_POSITIONS.len()
    );
    for (i, proof) in tensor_proofs.iter().enumerate() {
        let _ = writeln!(w, "        p[{i}] = new bytes32[]({});", proof.len());
        for (level, sibling) in proof.iter().enumerate() {
            let _ = writeln!(w, "        p[{i}][{level}] = {};", hex32(sibling));
        }
    }

    let _ = write!(w, "    }}\n}}\n");
    w
}
