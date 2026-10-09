// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IAVIPRegistry
/// @notice Reputation registry on the C-Chain: stores one Merkle root per
///         epoch over the reputation tensor `T` and validates the
///         zero-knowledge threshold proof.
///
/// @dev PROVISIONAL INTERFACE. There is no implementation yet (milestone M1).
///      The boundary below is derived from
///      `docs/architecture/avalanche-integration.md` §1-§3 and from the paper:
///
///        - admission rule      `CoA(i) = S_f(i) + C_R(T(i)) >= Theta(t)`
///                              (main.tex, section "Payment Rule")
///        - threshold predicate `||T||_F >= Theta_r`
///                              (main.tex, section "Zero-Knowledge Threshold Proof")
///
///      Reference parameters (design constants, not measured here):
///        - `Theta   = 1.0`            admission threshold, frozen at genesis
///        - `Theta_r = 0.5`            [CONJECTURE], main.tex
///        - `C*D*H   = 500` entries    reference tensor configuration
///        - `gamma   = 0.10`           epoch freshness bound (Data Layer)
///
///      The registry does NOT store the tensor: it stores roots and verifies
///      inclusion proofs for the entries the admission rule needs
///      (avalanche-integration.md §2).
interface IAVIPRegistry {
    /// @notice Emitted when the epoch commitment is posted.
    /// @param epoch The epoch index.
    /// @param root Merkle root over the reputation tensor of that epoch.
    /// @param timestamp Block timestamp of the posting.
    event CommitmentPosted(uint256 indexed epoch, bytes32 root, uint64 timestamp);

    /// @notice Emitted when a threshold proof is accepted for a validator.
    event ThresholdProven(uint256 indexed epoch, address indexed validator);

    /// @notice Posts the Merkle root of the reputation tensor for `epoch`.
    /// @dev Must reject a root that violates the freshness constraint
    ///      `|epoch_t \ epoch_{t-1}| <= gamma * len` (main.tex, Data Layer).
    function postCommitment(uint256 epoch, bytes32 root) external;

    /// @notice Merkle root of the reputation tensor for `epoch`
    ///         (`bytes32(0)` if the epoch was never committed).
    function commitmentOf(uint256 epoch) external view returns (bytes32);

    /// @notice Number of entries per epoch (`C*D*H`; 500 in the reference
    ///         configuration).
    function tensorSize() external view returns (uint32);

    /// @notice True iff `leaf` is in the tree committed by `root`.
    function verifyEntry(bytes32 root, bytes32 leaf, bytes32[] calldata proof)
        external
        view
        returns (bool);

    /// @notice Validates the threshold proof `||T||_F >= Theta_r` for
    ///         `validator` against the commitment of `epoch`.
    /// @dev Delegates the pairing check to `IZKThresholdVerifier`.
    function verifyThreshold(uint256 epoch, address validator, bytes calldata proof)
        external
        view
        returns (bool);
}
