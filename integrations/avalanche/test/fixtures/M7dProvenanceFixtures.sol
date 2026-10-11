// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title M7dProvenanceFixtures
/// @notice The numbers M7d's payloads carry that come from *other* milestones, in one
///         place: M7b's adjudicated fraud (§5.9) and M5's sealed calibration (§5.6).
///
/// @dev **Declared, not generated** — like `M7cBridgeFixtures.sol`, and unlike the two
///      `*Groth16Fixtures.sol` files next to it. Every value is a literal of a committed
///      transcript, and `integrations/avalanche/scripts/m7d_report.sh` checks each one
///      against it in both directions (the literal must be in the transcript, and the
///      literal must be in the fresh M7d run). The point of one file rather than two
///      copies is that the suite and the transcript cannot disagree about which epoch of
///      M7b or which calibration of M5 they are talking about.
///
///      Provenance:
///        - `M7B_*`: `src/datalayer/scripts/m7b_output.txt`, section 3, the
///          `f_c` instance's genesis digest and the one adjudicated `Verdict::Fraud` —
///          "re-hashed at value + 1 … Fraud: published 138673557278208441, f_c
///          138673557278208440". The epoch is the one that table adjudicates.
///        - `M5_*`: `src/rmt/scripts/m5_output.txt`, `[thresholds]`, the sealed
///          `alpha = 0.01` row — `lambda_max(B) > 9.0542 or -lambda_min(B) > 9.1371` —
///          scaled to the 4 decimals that file prints, plus the protocol's `n = 500`.
library M7dProvenanceFixtures {
    /// @notice The epoch M7b's fraud proof adjudicated.
    uint256 internal constant M7B_EPOCH = 0;

    /// @notice The `f_c` instance's genesis digest
    ///         (`Ingestion::parameters_digest`), i.e. *which* formula was in force.
    bytes32 internal constant M7B_INGESTION_DIGEST =
        0x2fcd03b859e0519cc0c443aa99b879e0f15bb0312047cec8d7541de55acbba0a;

    /// @notice The value M7b's sequencer published (`Verdict::Fraud::published_wad`).
    uint256 internal constant M7B_PUBLISHED_WAD = 138673557278208441;

    /// @notice What `f_c(events)` says (`formula_wad`).
    uint256 internal constant M7B_FORMULA_WAD = 138673557278208440;

    /// @notice M5's right-tail `q99 = 9.0542`, 4-decimal scaled (`90542`).
    uint32 internal constant M5_RIGHT_THRESHOLD_Q = 90542;

    /// @notice M5's left-tail `q99 = 9.1371`, 4-decimal scaled (`91371`).
    uint32 internal constant M5_LEFT_THRESHOLD_Q = 91371;

    /// @notice The protocol's node count, the `n = 500` M5 calibrates on.
    uint32 internal constant M5_NODE_COUNT = 500;
}
