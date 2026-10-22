// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IAVIPRegistry
/// @notice Reputation registry on the C-Chain: stores two roots per epoch over
///         the reputation tensor `T` — the keccak Merkle root used by inclusion
///         proofs and the Poseidon Merkle root used by the admission proof — and
///         validates the zero-knowledge admission proof.
///
/// @dev Implemented by `AVIPRegistry.sol` (milestone M1, amended by M2 §5.2,
///      M4d and audit finding P-16). The two roots are distinct values with
///      distinct verifiers; neither slot is ever interpreted as the other.
///      The boundary below is derived from
///      `docs/architecture/avalanche-integration.md` §1-§3 and from the paper:
///
///        - admission rule      `CoA(i) = S_f(i) + C_R(T(i)) >= Theta(t)`
///                              (main.tex, section "Payment Rule"); enforced by
///                              `AVIPValidatorManager`, NOT by the registry.
///        - certified norm      `T(v) = certifiedNorm`
///                              (main.tex, section "Zero-Knowledge Threshold
///                              Proof"). The registry certifies one validator's
///                              exact committed norm; the threshold
///                              `T(v) >= Theta_r` is enforced by
///                              `AVIPValidatorManager` (§5.2.2).
///
///      Reference parameters (design constants, not measured here):
///        - `Theta   = 1.0`            admission threshold, frozen at genesis
///        - `C*D*H   = 500` entries    reference tensor configuration
///        - `gamma   = 0.10`           epoch freshness bound (Data Layer)
///
///      `Theta_r = 0.5` [CONJECTURE] is deliberately NOT a registry parameter:
///      the circuit proves equality (`T(v) = certifiedNorm`) and the economic
///      threshold lives in `AVIPValidatorManager`, so changing it does not
///      require a new trusted-setup ceremony (§5.2.2).
///
///      The registry does NOT store the tensor: it stores roots and verifies
///      inclusion proofs for the entries the admission rule needs
///      (avalanche-integration.md §2).
interface IAVIPRegistry {
    /// @notice Emitted when the epoch commitment is posted.
    /// @param epoch The epoch index.
    /// @param root Keccak Merkle root over the reputation tensor of that epoch,
    ///        the root `verifyEntry` folds against.
    /// @param statementRoot Poseidon Merkle root over the same entries, the root
    ///        the admission circuit's public input names. A separate slot on
    ///        purpose: keccak cannot be computed inside BN254 at this size, so
    ///        the two trees are different objects even though they commit to the
    ///        same leaves (audit P-16).
    /// @param changedEntries Entries that differ from the previous epoch, as
    ///        declared by the sequencer (genesis declares the whole tensor).
    /// @param timestamp Block timestamp of the posting.
    event CommitmentPosted(
        uint256 indexed epoch,
        bytes32 root,
        uint256 statementRoot,
        uint32 changedEntries,
        uint64 timestamp
    );

    /// @notice Emitted when the guardian proposes a new sequencer. The proposal
    ///         is not yet the change: `executeSequencerChange` commits it, and
    ///         not before `eta`.
    /// @param next The proposed sequencer.
    /// @param eta Unix time from which the change may be executed.
    event SequencerProposed(address indexed next, uint64 eta);

    /// @notice Emitted when a proposed sequencer change is committed.
    event SequencerChanged(address indexed previous, address indexed next);

    /// @notice Emitted when the guardian drops a pending sequencer change.
    event SequencerChangeCancelled(address indexed dropped);

    /// @notice Emitted when the guardian proposes a new threshold verifier.
    /// @param next The proposed verifier.
    /// @param eta Unix time from which the change may be executed.
    event VerifierProposed(address indexed next, uint64 eta);

    /// @notice Emitted when a proposed verifier change is committed.
    event VerifierChanged(address indexed previous, address indexed next);

    /// @notice Emitted when the guardian drops a pending verifier change.
    event VerifierChangeCancelled(address indexed dropped);

    error NotSequencer(address caller);
    error ZeroSequencer();
    error ZeroRoot();
    error NonSequentialEpoch(uint256 expected, uint256 got);
    error GenesisDelta(uint32 changedEntries, uint32 tensorSize);
    error FreshnessViolation(uint32 changedEntries, uint32 maxDeltaEntries);
    error UnknownEpoch(uint256 epoch);
    error ZeroStatementRoot();
    error VerifierNotSet();
    error NotGuardian(address caller);
    error ZeroGuardian();

    /// @notice The guardian proposed `address(0)` as the verifier. Rejected
    ///         because a zero verifier is not a rotation: it silently turns
    ///         certification off, since `verifyThreshold` reverts
    ///         `VerifierNotSet` and no admission can be certified afterwards.
    error ZeroVerifier();
    error NoPendingSequencerChange();
    error NoPendingVerifierChange();

    /// @notice The proposed change was executed before its `eta` (`now` is the
    ///         block timestamp that tried).
    error ChangeNotReady(uint256 eta, uint256 now);

    /// @notice A proof that fails the pairing check is a *verdict*, not a
    ///         registry error: `verifyThreshold` returns `false` for it, the
    ///         same shape as `verifyEntry`. This error is how the admission
    ///         layer turns that verdict into a revert:
    ///         `AVIPValidatorManager.admit` raises it (§5.2.4). Declared here
    ///         because it names a property of the proof, and raised there
    ///         because admission, not verification, is the decision.
    error InvalidZKProof();

    /// @notice Posts the two Merkle roots of the reputation tensor for `epoch`.
    /// @dev `root` is the keccak tree `verifyEntry` verifies; `statementRoot` is
    ///      the Poseidon tree the admission circuit commits to. They are
    ///      different roots of the same leaves and are stored in different
    ///      slots, so a caller cannot mistake one for the other (audit P-16).
    ///      The off-chain bridge recomputes both from the same entries and links
    ///      them for the data layer; the registry cannot recompute either and
    ///      therefore trusts the sequencer for the pair exactly as it already
    ///      trusts it for `changedEntries`.
    ///
    ///      Enforces the freshness constraint of the paper's Data Layer section
    ///      ("two consecutive epochs cannot differ in more than `gamma * N`
    ///      entries", `gamma = 0.10`, `N = C*D*H = 500`, so at most 50).
    ///      The registry does not hold the tensor: the bound is checked against
    ///      `changedEntries`, the delta *declared* by the sequencer, so it is a
    ///      protocol rule rather than a cryptographic enforcement. Soundness
    ///      rests on the data layer's fraud proof, not on the committer's
    ///      honesty (main.tex, Data Layer).
    ///      Epochs are 0-based and strictly sequential; genesis (epoch 0) must
    ///      declare `changedEntries == tensorSize()`.
    function postCommitment(
        uint256 epoch,
        bytes32 root,
        uint256 statementRoot,
        uint32 changedEntries
    ) external;

    /// @notice Keccak Merkle root of the reputation tensor for `epoch`
    ///         (`bytes32(0)` if the epoch was never committed). This is the root
    ///         `verifyEntry` takes and the one `AVIPMessageCodec` carries.
    function commitmentOf(uint256 epoch) external view returns (bytes32);

    /// @notice Poseidon Merkle root of the reputation tensor for `epoch`
    ///         (`0` if the epoch was never committed). This is the root the
    ///         admission statement carries, never the keccak root.
    function statementRootOf(uint256 epoch) external view returns (uint256);

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

    /// @notice Verifies that `validator`'s committed entry for `epoch` has norm
    ///         exactly `certifiedNorm`.
    /// @dev `proof` decodes to the Groth16 shape `(a, b, c)` only: there is no
    ///      caller-supplied public-input array. The registry reads
    ///      `root = statementRootOf(epoch)` from its own state and builds the
    ///      statement itself,
    ///
    ///          statement = [root, epoch, uint256(uint160(validator)), certifiedNorm]
    ///
    ///      so all four values are bound arithmetically: a false value changes
    ///      `vk_x` and the pairing fails. The leaf the circuit proves is
    ///      `Poseidon(validator, certifiedNorm)`, so a proof is not a bearer
    ///      token: it admits the address that appears in its statement and no
    ///      other (audit P-01). The epoch is a public input as well, which is why
    ///      a proof for one epoch cannot pass at another even if the root were
    ///      re-posted.
    ///
    ///      A `false` return means the verifier rejected the proof; the only
    ///      reverts are configuration errors (`UnknownEpoch`, `VerifierNotSet`).
    ///      `view` on purpose: the registry keeps no per-validator state, so no
    ///      caller can consume another validator's proof slot. Anti-replay lives
    ///      in `AVIPValidatorManager` (`!isAdmitted[validator]`), §5.2.4.
    function verifyThreshold(
        uint256 epoch,
        address validator,
        uint256 certifiedNorm,
        bytes calldata proof
    ) external view returns (bool);

    /// @notice Authority that may propose changes to `sequencer` and to
    ///         `verifier` (M9a, §12.1.2). Read-only here: the registry never
    ///         calls it, it only checks `msg.sender` against it.
    function guardian() external view returns (address);

    /// @notice The sequencer proposed by the guardian and not yet committed, or
    ///         `address(0)` when no sequencer change is pending.
    function pendingSequencer() external view returns (address);

    /// @notice Unix time from which `executeSequencerChange` succeeds
    ///         (`0` when no sequencer change is pending).
    function sequencerChangeEta() external view returns (uint64);

    /// @notice The verifier proposed by the guardian and not yet committed, or
    ///         `address(0)` when no verifier change is pending.
    function pendingVerifier() external view returns (address);

    /// @notice Unix time from which `executeVerifierChange` succeeds
    ///         (`0` when no verifier change is pending).
    function verifierChangeEta() external view returns (uint64);

    /// @notice Proposes `next` as the sequencer. Guardian only, `next` non-zero.
    ///         Overwrites any pending proposal and restarts the delay.
    /// @dev The proposal is inert until `executeSequencerChange`. A zero address
    ///      is rejected because a registry whose sequencer is nobody accepts no
    ///      commitment at all: that is a bug, not a policy.
    function proposeSequencer(address next) external;

    /// @notice Commits the pending sequencer change, once
    ///         `block.timestamp >= sequencerChangeEta()`.
    /// @dev **Permissionless on purpose.** The sitting sequencer must not be
    ///      able to veto a rotation it is losing, and the guardian must not be
    ///      the only party able to complete one: after the delay, anyone can.
    function executeSequencerChange() external;

    /// @notice Drops the pending sequencer change. Guardian only.
    function cancelSequencerChange() external;

    /// @notice Proposes `next` as the threshold verifier. Guardian only,
    ///         `next` non-zero. Overwrites any pending proposal and restarts the
    ///         delay.
    function proposeVerifier(address next) external;

    /// @notice Commits the pending verifier change, once
    ///         `block.timestamp >= verifierChangeEta()`. Permissionless, for the
    ///         same reason as `executeSequencerChange`.
    function executeVerifierChange() external;

    /// @notice Drops the pending verifier change. Guardian only.
    function cancelVerifierChange() external;
}
