// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title M7cBridgeFixtures
/// @notice The words M7c's committed table carries, so a Solidity suite can check
///         the Pedersen ↔ Merkle tie without running the Rust crate.
///
/// @dev **Declared, not generated** — unlike its two neighbours in this directory.
///      Every value below is copied from `src/zk/scripts/m7c_output.txt`, the
///      transcript `src/zk/scripts/m7c_report.sh` pins, and
///      `integrations/avalanche/scripts/m7d_report.sh` checks it in both
///      directions: each word here must appear in that transcript, and the link the
///      contracts compute from these words must be the link the transcript
///      publishes. A copy that is *checked* is the point; a copy that is *trusted*
///      would be exactly the drift the guard exists to catch.
///
///      Provenance, word by word (section 1 of the M7c table):
///        - `TENSOR_DIGEST` is also `M4bGroth16Fixtures.TENSOR_DIGEST` and the seed
///          M5's detector draws its graph from
///          (`src/rmt/scripts/m5_output.txt`), so the three milestones agree on
///          which tensor this is;
///        - `MERKLE_ROOT` is M1's own fold over that tensor, computed by M7c from
///          the crate's `commitment::merkle_root`;
///        - `STATEMENT_ROOT` is the V3 statement's `root` (Poseidon), the value
///          `M4bGroth16Fixtures.STATEMENT_ROOT` pins;
///        - `LINK` is `bridge::link_digest` over the two roots and the epoch.
library M7cBridgeFixtures {
    /// @notice `C·D·H`, the number of entries in the committed tensor.
    uint256 internal constant TENSOR_ENTRIES = 500;

    /// @notice `keccak256` over the tensor's 8-byte little-endian words (M4a).
    bytes32 internal constant TENSOR_DIGEST =
        0xc2309377a00b109a6c44d83a5cc759108977ffe207fba6f83215a9cdf77d9aa9;

    /// @notice M1's Merkle root over that tensor: the `merkleRoot` a commitment
    ///         announcement carries.
    bytes32 internal constant MERKLE_ROOT =
        0x335750970d80b983041b14e06bbae156732061f12882e0bdbe0d1b6d794044f7;

    /// @notice The V3 statement's `root` for the same tensor, as `uint256`.
    uint256 internal constant STATEMENT_ROOT =
        14881564148789680950073164612164838307833922018127128489011700125541095929892;

    /// @notice The epoch the roots describe (M1 epochs are 0-based).
    uint256 internal constant EPOCH = 0;

    /// @notice `certifiedNorm = ||T||_F` in WAD, as the M4b proof certifies it.
    uint256 internal constant CERTIFIED_NORM = 12793810215743475835;

    /// @notice The tie: `bridge::link_digest(MERKLE_ROOT, STATEMENT_ROOT, EPOCH)`.
    bytes32 internal constant LINK =
        0x98dc2959892349bb23bf3c8321ed4107d4010c5a2c0505cf9d4dac8d533dadce;
}
