// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAVIPRegistry} from "./interfaces/IAVIPRegistry.sol";
import {IZKThresholdVerifier} from "./interfaces/IZKThresholdVerifier.sol";

/// @title AVIPRegistry
/// @notice Reputation registry of the Diamond Framework on the C-Chain: one
///         Merkle root per epoch over the reputation tensor `T`
///         (`N = C*D*H = 500` entries), plus validation of the threshold proof
///         `||T||_F >= Theta_r`.
///
/// @dev Milestone M1 of `docs/architecture/implementation-plan.md`.
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
///      Deliberately NOT implemented here:
///        - the data layer and its fraud proof (gap A7, milestone M7);
///        - the admission and slashing rules (`AVIPValidatorManager`, M2);
///        - the pairing check itself (`IZKThresholdVerifier`, M3).
contract AVIPRegistry is IAVIPRegistry {
    /// @notice Entries per epoch, `C * D * H` (paper, Tensor Compression).
    uint32 public constant TENSOR_SIZE = 500;

    /// @notice Freshness parameter `gamma = 0.10`, in basis points (Data Layer).
    uint32 public constant GAMMA_BPS = 1000;

    /// @notice Denominator of `GAMMA_BPS`.
    uint32 public constant BPS_DENOMINATOR = 10_000;

    /// @notice `gamma * N = 0.10 * 500 = 50` entries.
    uint32 public constant MAX_DELTA_ENTRIES = (TENSOR_SIZE * GAMMA_BPS) / BPS_DENOMINATOR;

    /// @notice Address allowed to post epoch commitments: the data layer's
    ///         sequencer role.
    address public sequencer;

    /// @notice Verifier of the threshold proof (milestone M3). May be zero
    ///         while no verifier is configured, in which case
    ///         `verifyThreshold` reverts instead of accepting anything.
    IZKThresholdVerifier public verifier;

    /// @notice Whether `(epoch, validator)` already produced an accepted
    ///         threshold proof.
    mapping(uint256 => mapping(address => bool)) public thresholdProven;

    mapping(uint256 => bytes32) private _roots;
    mapping(uint256 => uint32) private _changedEntries;
    uint256 private _latestEpoch;
    bool private _empty = true;

    /// @param sequencer_ The only address allowed to post commitments.
    /// @param verifier_ The threshold verifier, or the zero address to leave it
    ///        unset until M3.
    constructor(address sequencer_, address verifier_) {
        if (sequencer_ == address(0)) revert ZeroSequencer();
        sequencer = sequencer_;
        verifier = IZKThresholdVerifier(verifier_);
    }

    modifier onlySequencer() {
        _checkSequencer();
        _;
    }

    function _checkSequencer() internal view {
        if (msg.sender != sequencer) revert NotSequencer(msg.sender);
    }

    /// @notice Hands the sequencer role to `newSequencer`. Testnet-stage
    ///         governance: the sequencer rotates itself.
    function setSequencer(address newSequencer) external onlySequencer {
        if (newSequencer == address(0)) revert ZeroSequencer();
        sequencer = newSequencer;
    }

    /// @notice Sets the threshold verifier (M3).
    function setVerifier(address newVerifier) external onlySequencer {
        verifier = IZKThresholdVerifier(newVerifier);
    }

    /// @inheritdoc IAVIPRegistry
    function postCommitment(uint256 epoch, bytes32 root, uint32 changedEntries)
        external
        onlySequencer
    {
        if (root == bytes32(0)) revert ZeroRoot();

        uint256 expected = _empty ? 0 : _latestEpoch + 1;
        if (epoch != expected) revert NonSequentialEpoch(expected, epoch);

        if (_empty) {
            if (changedEntries != TENSOR_SIZE) revert GenesisDelta(changedEntries, TENSOR_SIZE);
        } else if (changedEntries > MAX_DELTA_ENTRIES) {
            revert FreshnessViolation(changedEntries, MAX_DELTA_ENTRIES);
        }

        _roots[epoch] = root;
        _changedEntries[epoch] = changedEntries;
        _latestEpoch = epoch;
        _empty = false;

        emit CommitmentPosted(epoch, root, changedEntries, uint64(block.timestamp));
    }

    /// @inheritdoc IAVIPRegistry
    function commitmentOf(uint256 epoch) external view returns (bytes32) {
        return _roots[epoch];
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
    function verifyThreshold(uint256 epoch, address validator, bytes calldata proof)
        external
        returns (bool)
    {
        bytes32 root = _roots[epoch];
        if (root == bytes32(0)) revert UnknownEpoch(epoch);
        if (validator == address(0)) revert ZeroValidator();
        if (thresholdProven[epoch][validator]) revert ThresholdAlreadyProven(epoch, validator);

        IZKThresholdVerifier currentVerifier = verifier;
        if (address(currentVerifier) == address(0)) revert VerifierNotSet();

        (
            uint256[2] memory a,
            uint256[2][2] memory b,
            uint256[2] memory c,
            uint256[] memory publicInputs
        ) = abi.decode(proof, (uint256[2], uint256[2][2], uint256[2], uint256[]));

        // Bind the proof to this epoch's commitment: a proof for one root
        // cannot be replayed against another epoch's root.
        if (publicInputs.length < 2) revert PublicInputMismatch();
        if (publicInputs[0] != uint256(root) || publicInputs[1] != epoch) {
            revert PublicInputMismatch();
        }

        if (!currentVerifier.verify(a, b, c, publicInputs)) return false;

        thresholdProven[epoch][validator] = true;
        emit ThresholdProven(epoch, validator);
        return true;
    }
}
