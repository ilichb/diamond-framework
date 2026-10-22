// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAVIPRegistry} from "./interfaces/IAVIPRegistry.sol";
import {IZKThresholdVerifier} from "./interfaces/IZKThresholdVerifier.sol";
import {Bn254} from "./verifiers/Bn254.sol";

/// @title AVIPRegistry
/// @notice Reputation registry of the Diamond Framework on the C-Chain: two
///         Merkle roots per epoch over the reputation tensor `T`
///         (`N = C*D*H = 500` entries) — the keccak root `verifyEntry` folds
///         and the Poseidon root the admission proof binds — plus verification
///         of the succinct proof that one validator's committed entry has norm
///         `certifiedNorm`.
///
/// @dev Milestone M1 of `docs/architecture/implementation-plan.md`, amended by
///      M2 §5.2, by M3 §5.4, by M9a §12.1.2 (the authority pair described
///      below) and by M4d (P-01/P-16: the admission statement names the
///      validator and reads its own Poseidon slot). The registry certifies the
///      *exact* per-validator norm `T(v)` and stays `view` (it keeps no
///      per-validator state, so no caller can lock another validator out); the
///      admission threshold `T(v) >= Theta_r` is enforced by
///      `AVIPValidatorManager` (§5.2.2).
///
///      Freshness (paper, Data Layer: "two consecutive epochs cannot differ in
///      more than `gamma * N` entries", `gamma = 0.10`, `N = 500`): the
///      registry enforces the bound on the delta the sequencer *declares* when
///      posting. It does not store the tensor, so it cannot recompute the
///      delta; the paper places soundness on the data layer's fraud proof, not
///      on the committer's honesty.
///
///      Merkle convention, fixed here and reused by the off-chain prover:
///        - leaf hash  `keccak256(abi.encodePacked(leaf))`
///        - pair hash  `keccak256(abi.encodePacked(min, max))`, i.e. pairs are
///          sorted, so an inclusion proof needs no direction bits;
///        - the root of a single-leaf tree is that leaf's hash.
///
///      That is the keccak tree `verifyEntry` uses. The admission proof does
///      **not** reuse it: keccak is not computable inside BN254 at this size, so
///      `statementRoot` is a separate Poseidon tree over leaves
///      `Poseidon(validator, norm)` (audit P-16). The two roots are posted
///      together and stored in different slots; neither is ever read as the
///      other.
///
///      Authority (M9a, §12.1.2). `sequencer` is the only writer of commitments;
///      `guardian` is the only proposer of changes to `sequencer` and to
///      `verifier`. The two roles are separate and neither acts alone on a
///      rotation: the guardian proposes, the proposal waits `CHANGE_DELAY`, and
///      then anyone may execute it. A compromised sitting key can therefore
///      neither rotate itself nor veto the rotation that replaces it, and a
///      compromised guardian cannot install a key without the delay being
///      observable first. The verifier stays *mutable* on purpose: this registry
///      is also the commitment history `admit` depends on (`_roots`,
///      `_statementRoots`, `_changedEntries`), so freezing the verifier would
///      turn a circuit bug into a redeploy that loses that history.
///
///      Deliberately NOT implemented here:
///        - the data layer and its fraud proof (gap A7, milestone M7);
///        - the admission and slashing rules (`AVIPValidatorManager`, M2).
///
///      The pairing check itself is no longer a gap: `Bn254` (M3) decodes the
///      blob and `contracts/verifiers/Groth16Verifier.sol` (M3) runs it. The
///      registry knows the verifier only through `IZKThresholdVerifier`, so the
///      tests can still install the mock.
contract AVIPRegistry is IAVIPRegistry {
    /// @notice Entries per epoch, `C * D * H` (paper, Tensor Compression).
    uint32 public constant TENSOR_SIZE = 500;

    /// @notice Freshness parameter `gamma = 0.10`, in basis points (Data Layer).
    uint32 public constant GAMMA_BPS = 1000;

    /// @notice Denominator of `GAMMA_BPS`.
    uint32 public constant BPS_DENOMINATOR = 10_000;

    /// @notice `gamma * N = 0.10 * 500 = 50` entries.
    uint32 public constant MAX_DELTA_ENTRIES = (TENSOR_SIZE * GAMMA_BPS) / BPS_DENOMINATOR;

    /// @notice Largest norm the framework encodes: `CERTIFIED_BOUND_BITS = 64`
    ///         (`src/zk/src/native.rs`, P-04). Also the anti-malleability bound
    ///         of P-13: the scalar field's order is `~2^254`, so every
    ///         `norm + k * r` is far above this.
    uint256 internal constant MAX_NORM = 1 << 64;

    /// @notice Address allowed to post epoch commitments: the data layer's
    ///         sequencer role.
    address public sequencer;

    /// @notice Verifier of the threshold proof (milestone M3). May be zero
    ///         while no verifier is configured, in which case
    ///         `verifyThreshold` reverts instead of accepting anything.
    IZKThresholdVerifier public verifier;

    /// @notice Authority allowed to *propose* changes to `sequencer` and
    ///         `verifier`. That it is a multisig is a deployment fact, not
    ///         something a contract can check; that it is immutable is not: an
    ///         authority that can rewrite itself is not a second authority
    ///         (§12.1.2).
    /// @dev The name stays lower-case although the lint would like
    ///      `SCREAMING_SNAKE_CASE`: `guardian` is part of the published API
    ///      (`guardian()` is read by the deploy script, its report and its tests),
    ///      and a second spelling for one role is a bug waiting to happen.
    // forge-lint: disable-next-line(screaming-snake-case-immutable)
    address public immutable guardian;

    /// @notice Delay between a proposal and the earliest execution, in seconds.
    /// @dev **A deployment constant, not a model parameter**: it appears in no
    ///      paper equation and in no `verification/` script (§6). Two days is
    ///      long enough for the sitting keys to see `SequencerProposed` and act
    ///      on a rotation they did not ask for, and short enough that an operator
    ///      can still rotate a lost key inside one working session.
    uint256 public constant CHANGE_DELAY = 2 days;

    /// @notice The sequencer the guardian has proposed, or `address(0)` when no
    ///         sequencer change is pending.
    address public pendingSequencer;

    /// @notice Unix time from which `executeSequencerChange` succeeds
    ///         (`0` while nothing is pending).
    uint64 public sequencerChangeEta;

    /// @notice The verifier the guardian has proposed, or `address(0)` when no
    ///         verifier change is pending.
    address public pendingVerifier;

    /// @notice Unix time from which `executeVerifierChange` succeeds
    ///         (`0` while nothing is pending).
    uint64 public verifierChangeEta;

    mapping(uint256 => bytes32) private _roots;
    mapping(uint256 => uint256) private _statementRoots;
    mapping(uint256 => uint32) private _changedEntries;
    uint256 private _latestEpoch;
    bool private _empty = true;

    /// @param sequencer_ The only address allowed to post commitments.
    /// @param verifier_ The threshold verifier, or the zero address to leave it
    ///        unset until M3.
    /// @param guardian_ The only address allowed to propose a change to
    ///        `sequencer` or `verifier`. Rejected when zero (M9a): an authority
    ///        whose only power is to propose must still exist, or both roles are
    ///        frozen forever — the sequencer could never be rotated and a circuit
    ///        fix could never be installed.
    constructor(address sequencer_, address verifier_, address guardian_) {
        if (sequencer_ == address(0)) revert ZeroSequencer();
        if (guardian_ == address(0)) revert ZeroGuardian();
        sequencer = sequencer_;
        verifier = IZKThresholdVerifier(verifier_);
        guardian = guardian_;
    }

    modifier onlySequencer() {
        _checkSequencer();
        _;
    }

    function _checkSequencer() internal view {
        if (msg.sender != sequencer) revert NotSequencer(msg.sender);
    }

    modifier onlyGuardian() {
        _checkGuardian();
        _;
    }

    function _checkGuardian() internal view {
        if (msg.sender != guardian) revert NotGuardian(msg.sender);
    }

    /// @notice Proposes `next` as the sequencer (M9a).
    /// @dev Guardian only, `next` non-zero. Re-proposing while a change is
    ///      pending overwrites it and restarts `CHANGE_DELAY`, so a guardian that
    ///      regrets a proposal can always withdraw it — and can never land a
    ///      change earlier than `CHANGE_DELAY` after it was last announced.
    function proposeSequencer(address next) external onlyGuardian {
        if (next == address(0)) revert ZeroSequencer();

        // casting to 'uint64' is safe because the value is this block's timestamp
        // plus a constant `CHANGE_DELAY`: it stays far below `2**64` for any
        // timestamp a chain will see, and the same width is used by
        // `CommitmentPosted` for the same reason.
        // forge-lint: disable-next-line(unsafe-typecast)
        uint64 eta = uint64(block.timestamp + CHANGE_DELAY);
        pendingSequencer = next;
        sequencerChangeEta = eta;

        emit SequencerProposed(next, eta);
    }

    /// @notice Commits the proposed sequencer change (M9a).
    /// @dev **Permissionless once the delay has elapsed**, and that is the point:
    ///      a sitting key that is compromised or simply lost must not be able to
    ///      block the rotation that replaces it. Anyone can pay the gas; nobody
    ///      can change *what* is committed, because the target was fixed by the
    ///      guardian at proposal time and announced in `SequencerProposed`.
    function executeSequencerChange() external {
        address next = pendingSequencer;
        if (next == address(0)) revert NoPendingSequencerChange();

        uint256 eta = sequencerChangeEta;
        if (block.timestamp < eta) revert ChangeNotReady(eta, block.timestamp);

        address previous = sequencer;
        sequencer = next;
        pendingSequencer = address(0);
        sequencerChangeEta = 0;

        emit SequencerChanged(previous, next);
    }

    /// @notice Drops the pending sequencer change (M9a). Guardian only: the same
    ///         authority that can announce a rotation can call it off.
    function cancelSequencerChange() external onlyGuardian {
        address dropped = pendingSequencer;
        if (dropped == address(0)) revert NoPendingSequencerChange();

        pendingSequencer = address(0);
        sequencerChangeEta = 0;

        emit SequencerChangeCancelled(dropped);
    }

    /// @notice Proposes `next` as the threshold verifier (M9a).
    /// @dev Guardian only and `next` non-zero. The zero address is rejected
    ///      although `verifier == address(0)` is a legal *initial* state (M7a
    ///      deploys no verifier): as a *rotation* it is not a configuration, it
    ///      is the silent disabling of certification, since `verifyThreshold`
    ///      then reverts `VerifierNotSet` for every epoch.
    function proposeVerifier(address next) external onlyGuardian {
        if (next == address(0)) revert ZeroVerifier();

        // casting to 'uint64' is safe for the same reason as in
        // `proposeSequencer`: a block timestamp plus a constant delay.
        // forge-lint: disable-next-line(unsafe-typecast)
        uint64 eta = uint64(block.timestamp + CHANGE_DELAY);
        pendingVerifier = next;
        verifierChangeEta = eta;

        emit VerifierProposed(next, eta);
    }

    /// @notice Commits the proposed verifier change (M9a).
    /// @dev Permissionless once the delay has elapsed, for the same reason as
    ///      `executeSequencerChange`: the party being replaced does not hold a
    ///      veto over its replacement.
    function executeVerifierChange() external {
        address next = pendingVerifier;
        if (next == address(0)) revert NoPendingVerifierChange();

        uint256 eta = verifierChangeEta;
        if (block.timestamp < eta) revert ChangeNotReady(eta, block.timestamp);

        address previous = address(verifier);
        verifier = IZKThresholdVerifier(next);
        pendingVerifier = address(0);
        verifierChangeEta = 0;

        emit VerifierChanged(previous, next);
    }

    /// @notice Drops the pending verifier change (M9a). Guardian only.
    function cancelVerifierChange() external onlyGuardian {
        address dropped = pendingVerifier;
        if (dropped == address(0)) revert NoPendingVerifierChange();

        pendingVerifier = address(0);
        verifierChangeEta = 0;

        emit VerifierChangeCancelled(dropped);
    }

    /// @inheritdoc IAVIPRegistry
    function postCommitment(
        uint256 epoch,
        bytes32 root,
        uint256 statementRoot,
        uint32 changedEntries
    ) external onlySequencer {
        if (root == bytes32(0)) revert ZeroRoot();
        // A zero Poseidon root is not a valid tree root and would let an epoch
        // exist that no admission proof can ever bind to. Reject it here rather
        // than making `verifyThreshold` special-case it (audit P-16).
        if (statementRoot == 0) revert ZeroStatementRoot();

        uint256 expected = _empty ? 0 : _latestEpoch + 1;
        if (epoch != expected) revert NonSequentialEpoch(expected, epoch);

        if (_empty) {
            if (changedEntries != TENSOR_SIZE) revert GenesisDelta(changedEntries, TENSOR_SIZE);
        } else if (changedEntries > MAX_DELTA_ENTRIES) {
            revert FreshnessViolation(changedEntries, MAX_DELTA_ENTRIES);
        }

        _roots[epoch] = root;
        _statementRoots[epoch] = statementRoot;
        _changedEntries[epoch] = changedEntries;
        _latestEpoch = epoch;
        _empty = false;

        emit CommitmentPosted(epoch, root, statementRoot, changedEntries, uint64(block.timestamp));
    }

    /// @inheritdoc IAVIPRegistry
    function commitmentOf(uint256 epoch) external view returns (bytes32) {
        return _roots[epoch];
    }

    /// @inheritdoc IAVIPRegistry
    function statementRootOf(uint256 epoch) external view returns (uint256) {
        return _statementRoots[epoch];
    }

    /// @inheritdoc IAVIPRegistry
    function changedEntriesOf(uint256 epoch) external view returns (uint32) {
        return _changedEntries[epoch];
    }

    /// @inheritdoc IAVIPRegistry
    function tensorSize() external pure returns (uint32) {
        return TENSOR_SIZE;
    }

    /// @inheritdoc IAVIPRegistry
    function maxDeltaEntries() external pure returns (uint32) {
        return MAX_DELTA_ENTRIES;
    }

    /// @inheritdoc IAVIPRegistry
    function latestEpoch() external view returns (uint256) {
        return _empty ? type(uint256).max : _latestEpoch;
    }

    /// @inheritdoc IAVIPRegistry
    function verifyEntry(bytes32 root, bytes32 leaf, bytes32[] calldata proof)
        public
        pure
        returns (bool)
    {
        if (root == bytes32(0)) return false;

        bytes32 node = keccak256(abi.encodePacked(leaf));
        for (uint256 i = 0; i < proof.length; ++i) {
            bytes32 sibling = proof[i];
            node = node < sibling
                ? keccak256(abi.encodePacked(node, sibling))
                : keccak256(abi.encodePacked(sibling, node));
        }
        return node == root;
    }

    /// @inheritdoc IAVIPRegistry
    function verifyThreshold(
        uint256 epoch,
        address validator,
        uint256 certifiedNorm,
        bytes calldata proof
    ) external view returns (bool) {
        uint256 root = _statementRoots[epoch];
        if (root == 0) revert UnknownEpoch(epoch);

        IZKThresholdVerifier currentVerifier = verifier;
        if (address(currentVerifier) == address(0)) revert VerifierNotSet();

        // The norm's encoding, restated where the caller is (P-13, and the
        // one-sided bound of P-33). `admission.rs` enforces `WAD - norm - 1 <
        // 2^60`, which also admits a norm within `2^60` of the modulus — `-1`,
        // for one — and `certifiedNorm` is a `uint256` that `Bn254.ecMul`
        // reduces modulo the group order, so `c` and `c + k * r` would otherwise
        // reach the pairing as the same statement. Neither value is a norm this
        // framework can encode (`CERTIFIED_BOUND_BITS = 64`), so both are
        // refused before the blob is even decoded. The circuit's tighter
        // `< WAD` stays the circuit's: `WAD` is forwarded and the pairing
        // returns the verdict.
        if (certifiedNorm >= MAX_NORM) revert NormOutOfDomain(certifiedNorm);

        // M3 moved the decoding into `Bn254`: the blob must carry at least the
        // eight canonical field elements of `(a, b, c)` (`MalformedProof`
        // otherwise), each below `FIELD_MODULUS` (`CoordinateOutOfRange`
        // otherwise). Trailing bytes are still ignored, never read.
        (uint256[2] memory a, uint256[2][2] memory b, uint256[2] memory c) =
            Bn254.decodeProof(proof);

        // The statement is built here, from this registry's own state: the
        // caller cannot supply the root. `validator` is a public input of the
        // leaf `Poseidon(validator, certifiedNorm)`, so the proof is bound to
        // the address being admitted and cannot be replayed for another
        // (audit P-01). The epoch is bound as well, and the root is the epoch's
        // Poseidon root, never its keccak root (audit P-16).
        uint256[] memory statement = new uint256[](4);
        statement[0] = root;
        statement[1] = epoch;
        statement[2] = uint256(uint160(validator));
        statement[3] = certifiedNorm;

        return currentVerifier.verify(a, b, c, statement);
    }
}
