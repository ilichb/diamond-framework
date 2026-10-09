// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IAVIPRegistry
/// @notice Reputation registry on the C-Chain: stores one Merkle root per
///         epoch over the reputation tensor `T` and validates the
///         zero-knowledge threshold proof.
///
/// @dev Implemented by `AVIPRegistry.sol` (milestone M1, amended by M2 §5.2 of
///      `docs/architecture/implementation-plan.md`). The boundary below is
///      derived from `docs/architecture/avalanche-integration.md` §1-§3 and
///      from the paper:
///
///        - admission rule      `CoA(i) = S_f(i) + C_R(T(i)) >= Theta(t)`
///                              (main.tex, section "Payment Rule"); enforced by
///                              `AVIPValidatorManager`, NOT by the registry.
///        - certified norm      `||T||_F = certifiedNorm`
///                              (main.tex, section "Zero-Knowledge Threshold
///                              Proof"). The registry certifies the exact norm;
///                              the threshold `||T||_F >= Theta_r` is enforced
///                              by `AVIPValidatorManager` (§5.2.2).
///
///      Reference parameters (design constants, not measured here):
///        - `Theta   = 1.0`            admission threshold, frozen at genesis
///        - `C*D*H   = 500` entries    reference tensor configuration
///        - `gamma   = 0.10`           epoch freshness bound (Data Layer)
///
///      `Theta_r = 0.5` [CONJECTURE] is deliberately NOT a registry parameter:
///      the circuit proves equality (`||T||_F = certifiedNorm`) and the economic
///      threshold lives in `AVIPValidatorManager`, so changing it does not
///      require a new trusted-setup ceremony (§5.2.2).
///
///      The registry does NOT store the tensor: it stores roots and verifies
///      inclusion proofs for the entries the admission rule needs
///      (avalanche-integration.md §2).
interface IAVIPRegistry {
    /// @notice Emitted when the epoch commitment is posted.
    /// @param epoch The epoch index.
    /// @param root Merkle root over the reputation tensor of that epoch.
    /// @param changedEntries Entries that differ from the previous epoch, as
    ///        declared by the sequencer (genesis declares the whole tensor).
    /// @param timestamp Block timestamp of the posting.
    event CommitmentPosted(
        uint256 indexed epoch, bytes32 root, uint32 changedEntries, uint64 timestamp
    );

    error NotSequencer(address caller);
    error ZeroSequencer();
    error ZeroRoot();
    error NonSequentialEpoch(uint256 expected, uint256 got);
    error GenesisDelta(uint32 changedEntries, uint32 tensorSize);
    error FreshnessViolation(uint32 changedEntries, uint32 maxDeltaEntries);
    error UnknownEpoch(uint256 epoch);
    error VerifierNotSet();

    /// @notice A proof that fails the pairing check is a *verdict*, not a
    ///         registry error: `verifyThreshold` returns `false` for it, the
    ///         same shape as `verifyEntry`. This error is how the admission
    ///         layer turns that verdict into a revert:
    ///         `AVIPValidatorManager.admit` raises it (§5.2.4). Declared here
    ///         because it names a property of the proof, and raised there
    ///         because admission, not verification, is the decision.
    error InvalidZKProof();

    /// @notice Posts the Merkle root of the reputation tensor for `epoch`.
    /// @dev Enforces the freshness constraint of the paper's Data Layer section
    ///      ("two consecutive epochs cannot differ in more than `gamma * N`
    ///      entries", `gamma = 0.10`, `N = C*D*H = 500`, so at most 50).
    ///      The registry does not hold the tensor: the bound is checked against
    ///      `changedEntries`, the delta *declared* by the sequencer, so it is a
    ///      protocol rule rather than a cryptographic enforcement. Soundness
    ///      rests on the data layer's fraud proof, not on the committer's
    ///      honesty (main.tex, Data Layer).
    ///      Epochs are 0-based and strictly sequential; genesis (epoch 0) must
    ///      declare `changedEntries == tensorSize()`.
    function postCommitment(uint256 epoch, bytes32 root, uint32 changedEntries) external;

    /// @notice Merkle root of the reputation tensor for `epoch`
    ///         (`bytes32(0)` if the epoch was never committed).
    function commitmentOf(uint256 epoch) external view returns (bytes32);

    /// @notice Number of entries per epoch (`C*D*H`; 500 in the reference
    ///         configuration).
    function tensorSize() external view returns (uint32);

    /// @notice `gamma * N`, the largest number of entries by which two
    ///         consecutive epochs may differ (50 in the reference
    ///         configuration).
    function maxDeltaEntries() external view returns (uint32);

    /// @notice Entries that differ from the previous epoch in `epoch`, as
    ///         declared when it was posted (`0` if `epoch` was never posted).
    function changedEntriesOf(uint256 epoch) external view returns (uint32);

    /// @notice Highest committed epoch, or `type(uint256).max` while no epoch
    ///         has been committed.
    function latestEpoch() external view returns (uint256);

    /// @notice True iff `leaf` is in the tree committed by `root`.
    /// @dev Leaf hashing and pair combination are fixed by the implementation
    ///      and documented in `AVIPRegistry.sol`.
    function verifyEntry(bytes32 root, bytes32 leaf, bytes32[] calldata proof)
        external
        view
        returns (bool);

    /// @notice Verifies that the reputation tensor committed for `epoch` has
    ///         Frobenius norm exactly `certifiedNorm`.
    /// @dev `proof` decodes to the Groth16 shape `(a, b, c)` only: there is no
    ///      caller-supplied public-input array. The registry reads
    ///      `root = commitmentOf(epoch)` from its own state and builds the
    ///      statement itself,
    ///
    ///          statement = [uint256(root), epoch, certifiedNorm]
    ///
    ///      so `certifiedNorm` is bound to the proof arithmetically in M3: it is
    ///      a public input, a false value changes `vk_x` and the pairing fails.
    ///      A `false` return means the verifier rejected the proof; the only
    ///      reverts are configuration errors (`UnknownEpoch`, `VerifierNotSet`).
    ///      `view` on purpose: the registry keeps no per-validator state, so no
    ///      caller can consume another validator's proof slot. Anti-replay lives
    ///      in `AVIPValidatorManager` (`!isAdmitted[validator]`), §5.2.4.
    function verifyThreshold(uint256 epoch, uint256 certifiedNorm, bytes calldata proof)
        external
        view
        returns (bool);
}
