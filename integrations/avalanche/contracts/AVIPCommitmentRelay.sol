// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAVIPRegistry} from "./interfaces/IAVIPRegistry.sol";
import {AVIPMessageCodec} from "./AVIPMessageCodec.sol";
import {AVIPMessageEndpoint} from "./AVIPMessageEndpoint.sol";

/// @title AVIPCommitmentRelay
/// @notice Message type 1 of `docs/architecture/avalanche-integration.md` §4:
///         commitment propagation. On the source chain it announces
///         `AVIPRegistry.commitmentOf(epoch)` together with the statement's root
///         and M7c's link; on a subscribed chain it records what it was told.
///
/// @dev Milestone M7d of `docs/architecture/implementation-plan.md` §5.11 (gap
///      A9). One contract type for both sides of the wire, deployed once per
///      chain: the fields a side does not use are left zero at construction, so
///      the bytecode that announces and the bytecode that records are the same
///      bytecode — which is what makes the report's round trip a round trip of one
///      contract rather than of two look-alikes.
///
///      **What the sender checks before spending a message.** `publish` reads the
///      root out of the registry instead of taking it from the caller
///      (`UncommittedEpoch` for an epoch M1 never posted, so an epoch that is not
///      on record cannot be propagated — §5.11's third invariant), reads the
///      declared delta from it too, and then refuses to send unless the link the
///      caller supplied is the link *its own words* compute
///      (`AVIPMessageCodec.LinkMismatch`). The sender therefore cannot announce a
///      tie it did not check, and the receiver re-checks the same thing: a message
///      is re-derived from its payload at both ends.
///
///      **What the receiver records.** `propagatedOf[sourceChain][epoch]` — the
///      root, the statement root, the link and the delta — plus `latestEpochOf`,
///      the freshest epoch seen. An epoch is recorded **once**
///      (`EpochAlreadyPropagated`): a second message for the same
///      `(source, epoch)` is refused even if it carries a fresh nonce, so a
///      recorded root cannot be rewritten and `latestEpochOf` can only move
///      forward. What is *not* enforced is arrival order: the transport does not
///      promise one (`AVIPMessageEndpoint`), and a destination that receives epoch
///      4 after epoch 5 records both rather than losing a fact — a fresher message
///      must not be able to erase an older one, and an older one must not be able
///      to overwrite a fresher one either.
///
///      **The limit, stated where it bites.** The link is *carried*, not proven:
///      M7c chose option (c) precisely because the tie is off-chain and
///      recomputable, so a peer that holds the tensor can check it and a peer that
///      holds only the message cannot. The relay enforces internal consistency
///      (`link == linkDigest(merkleRoot, statementRoot, epoch)`) and nothing about
///      the tensor itself. The announcement also carries **no proof**: the §4
///      message is the root, `AVIPRegistry.verifyThreshold` is what certifies a
///      norm, and the proof path is M2's admission.
contract AVIPCommitmentRelay is AVIPMessageEndpoint {
    /// @notice What a destination chain knows about one announced epoch.
    /// @param merkleRoot M1's root over the tensor, as announced.
    /// @param statementRoot The statement's `root` for the same epoch.
    /// @param link M7c's tie, re-checked on arrival.
    /// @param changedEntries The delta the source sequencer declared.
    struct Propagated {
        bytes32 merkleRoot;
        uint256 statementRoot;
        bytes32 link;
        uint32 changedEntries;
    }

    /// @notice `publish` was called by an address other than the sequencer role.
    error NotSequencer(address caller);

    /// @notice The registry to read commitments from is not configured on this
    ///         deployment (a receive-only chain).
    error RegistryNotConfigured();

    /// @notice `publish` named an epoch the registry has no commitment for.
    error UncommittedEpoch(uint256 epoch);

    /// @notice The sender's roles are half-wired: a registry without a sequencer
    ///         (or the reverse) is a deployment mistake, not a receive-only chain.
    error PartialConfiguration();

    /// @notice This `(source, epoch)` was already recorded.
    error EpochAlreadyPropagated(bytes32 sourceBlockchainId, uint256 epoch);

    /// @notice Emitted when a commitment is announced to the destinations.
    event CommitmentAnnounced(
        uint256 indexed epoch,
        bytes32 merkleRoot,
        uint256 statementRoot,
        bytes32 link,
        uint256 destinations
    );

    /// @notice Emitted when an announced commitment is recorded on this chain.
    event CommitmentPropagated(
        bytes32 indexed sourceBlockchainId,
        uint256 indexed epoch,
        bytes32 merkleRoot,
        uint256 statementRoot,
        bytes32 link,
        uint32 changedEntries
    );

    /// @notice The registry the sender reads (M1). Zero on a receive-only chain.
    IAVIPRegistry internal immutable REGISTRY;

    /// @notice The only address allowed to `publish`, i.e. to say "this epoch is
    ///         committed". Zero on a receive-only chain. No setter, in the same
    ///         spirit as M2's `slashAuthority` (§5.2.4).
    address internal immutable SEQUENCER;

    /// @dev `sourceChain → epoch → what was announced`. Append-only.
    mapping(bytes32 => mapping(uint256 => Propagated)) private _propagatedOf;

    /// @dev `sourceChain → the freshest epoch recorded`. Only moves forward.
    mapping(bytes32 => uint256) private _latestEpochOf;

    /// @dev `sourceChain → whether anything was recorded at all`. Kept apart from
    ///      `_latestEpochOf` because epoch 0 is a valid epoch and would otherwise
    ///      be indistinguishable from "nothing seen".
    mapping(bytes32 => bool) private _hasPropagated;

    /// @param teleporter_ The Teleporter messenger (shared by every endpoint).
    /// @param localBlockchainId_ This chain's id.
    /// @param registry_ The M1 registry this deployment reads, or `address(0)` on a
    ///        chain that only receives commitment announcements.
    /// @param sequencer_ The only address that may announce, or `address(0)` on a
    ///        chain that only receives. Exactly one of `registry_`/`sequencer_`
    ///        being set is refused: it is a wiring bug, not a role.
    /// @param origins_ The inbound allowlist (`(chain, sender)` pairs that may
    ///        announce to this deployment).
    /// @param destinations_ The outbound routing table (the subscribers).
    constructor(
        address teleporter_,
        bytes32 localBlockchainId_,
        address registry_,
        address sequencer_,
        Origin[] memory origins_,
        Destination[] memory destinations_
    ) AVIPMessageEndpoint(teleporter_, localBlockchainId_, origins_, destinations_) {
        if ((registry_ == address(0)) != (sequencer_ == address(0))) revert PartialConfiguration();
        REGISTRY = IAVIPRegistry(registry_);
        SEQUENCER = sequencer_;
    }

    // --------------------------------------------------------------- the sender

    /// @notice Announces the commitment of `epoch` — as the registry holds it — to
    ///         every configured subscriber.
    /// @dev The root and the delta are read from the registry, never from the
    ///      caller: a sender can decide *when* to announce, not *what* is on
    ///      record. `statementRoot` and `link` do come from the caller, because
    ///      they are computed off-chain (M4b, M7c); the link is checked here.
    /// @param epoch The epoch to announce. Must be committed in the registry.
    /// @param statementRoot The statement's root for the same tensor.
    /// @param link `AVIPMessageCodec.linkDigest(merkleRoot, statementRoot, epoch)`,
    ///        with `merkleRoot` the registry's own.
    /// @return ids The messenger's id for each destination, in routing-table order.
    function publish(uint256 epoch, uint256 statementRoot, bytes32 link)
        external
        returns (bytes32[] memory ids)
    {
        if (address(REGISTRY) == address(0)) revert RegistryNotConfigured();
        if (msg.sender != SEQUENCER) revert NotSequencer(msg.sender);

        bytes32 merkleRoot = REGISTRY.commitmentOf(epoch);
        if (merkleRoot == bytes32(0)) revert UncommittedEpoch(epoch);

        ids = _send(
            _kind(),
            AVIPMessageCodec.encodeCommitment(
                AVIPMessageCodec.CommitmentPropagation({
                    epoch: epoch,
                    merkleRoot: merkleRoot,
                    changedEntries: REGISTRY.changedEntriesOf(epoch),
                    statementRoot: statementRoot,
                    link: link
                })
            )
        );
        emit CommitmentAnnounced(epoch, merkleRoot, statementRoot, link, ids.length);
    }

    // -------------------------------------------------------------- the receiver

    /// @notice This endpoint answers for message type 1.
    function _kind() internal pure override returns (uint8) {
        return AVIPMessageCodec.KIND_COMMITMENT_PROPAGATION;
    }

    /// @notice What was announced for `(sourceChain, epoch)`, zeroed if nothing.
    function propagatedOf(bytes32 sourceChainId, uint256 epoch)
        external
        view
        returns (Propagated memory)
    {
        return _propagatedOf[sourceChainId][epoch];
    }

    /// @notice The freshest epoch recorded from `sourceChain`.
    /// @dev Read `hasPropagated` first: epoch 0 is a valid answer.
    function latestEpochOf(bytes32 sourceChainId) external view returns (uint256) {
        return _latestEpochOf[sourceChainId];
    }

    /// @notice Whether anything at all was recorded from `sourceChain`.
    function hasPropagated(bytes32 sourceChainId) external view returns (bool) {
        return _hasPropagated[sourceChainId];
    }

    /// @dev Records one announced commitment, refusing to rewrite an epoch. The
    ///      payload is decoded here rather than trusted: the sender's own checks
    ///      live in another process, on another chain, in another version of the
    ///      codec, and `decodeCommitment` re-derives the link from the payload's
    ///      own words (a hand-built message that lies about the tie reverts with
    ///      `LinkMismatch` and never reaches the record).
    function _deliver(uint8, bytes32 sourceChainId, address, uint256, bytes memory payload)
        internal
        override
    {
        AVIPMessageCodec.CommitmentPropagation memory commitment =
            AVIPMessageCodec.decodeCommitment(payload);

        if (_propagatedOf[sourceChainId][commitment.epoch].merkleRoot != bytes32(0)) {
            revert EpochAlreadyPropagated(sourceChainId, commitment.epoch);
        }

        _propagatedOf[sourceChainId][commitment.epoch] = Propagated({
            merkleRoot: commitment.merkleRoot,
            statementRoot: commitment.statementRoot,
            link: commitment.link,
            changedEntries: commitment.changedEntries
        });

        if (!_hasPropagated[sourceChainId] || commitment.epoch > _latestEpochOf[sourceChainId]) {
            _latestEpochOf[sourceChainId] = commitment.epoch;
            _hasPropagated[sourceChainId] = true;
        }

        emit CommitmentPropagated(
            sourceChainId,
            commitment.epoch,
            commitment.merkleRoot,
            commitment.statementRoot,
            commitment.link,
            commitment.changedEntries
        );
    }
}

