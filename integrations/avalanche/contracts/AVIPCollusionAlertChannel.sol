// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVIPMessageCodec} from "./AVIPMessageCodec.sol";
import {AVIPMessageEndpoint} from "./AVIPMessageEndpoint.sol";

/// @title AVIPCollusionAlertChannel
/// @notice Message type 2 of `docs/architecture/avalanche-integration.md` §4: the
///         collusion alert. On the source chain it takes the RMT detector's
///         verdict and announces it; on a subscribed chain it records the flag.
///
/// @dev Milestone M7d of `docs/architecture/implementation-plan.md` §5.11 (gap
///      A9). Same shape as `AVIPCommitmentRelay`: one contract type, deployed once
///      per chain, with the fields the other side does not use left zero.
///
///      **What §4 asks for, and the honest boundary.** §4 says an alert "reduces
///      the effective voting weight of the flagged validators across all
///      subscribed subnets". That reduction is **not** in this contract, and the
///      reason is structural rather than a deferral of effort: M2's manager carries
///      no weights (they are M6's, §5.2), the message carries no node set (only the
///      graph's digest and its size), and which validators a flagged graph names is
///      determined *off-chain* from the graph M5 drew. What a transport can
///      honestly do is deliver the flag and make it impossible to erase; the
///      arithmetic that turns a flag into a weight is a consumer's, and this
///      milestone claims nothing about it (§5.11, "what is NOT tested").
///
///      **The flag is written once and never rewritten.**
///      `flagOf[sourceChain][epoch]` is recorded on first arrival
///      (`FlagAlreadyRecorded` on a second message for the same pair, even with a
///      fresh nonce), so the destination's set of flags only grows: an alert cannot
///      be undone by a later message, and — because the record is keyed by epoch
///      rather than kept as a single "current" slot — an alert that arrives out of
///      order is recorded instead of discarded. That is the property the transport
///      *can* hold, and `../test/M7dTransport.t.sol` measures it.
///
///      **The verdict travels with the calibration that produced it.**
///      `rightAlert` and `leftAlert` are the two decisions behind M5's
///      `Detection::verdict()` (`quiet`/`clique`/`bipartite`/`both`), and the
///      message also carries the `q99` thresholds they were decided against,
///      4-decimal scaled — the same four decimals `src/rmt/scripts/m5_output.txt`
///      prints — so a receiver can tell *which* calibration flagged this graph. The
///      statistics themselves (`λ_max`, `−λ_min`) are `f64` and are not transported
///      at all: the message carries the decision plus the graph's identity
///      (`graphDigest`), never a rounded copy of a real number (the rule M7c's
///      table follows for the four-decimal values it pins).
contract AVIPCollusionAlertChannel is AVIPMessageEndpoint {
    /// @notice What a subscribed chain knows about one flagged epoch.
    /// @param epoch The epoch whose graph was tested.
    /// @param nodeCount The graph's node count.
    /// @param rightThresholdQ The right tail's `q99`, 4-decimal scaled.
    /// @param leftThresholdQ The left tail's `q99`, 4-decimal scaled.
    /// @param graphDigest Which graph was flagged (the tensor digest M5 seeds it
    ///        with), so a consumer that holds the graph can re-run the test.
    /// @param rightAlert `λ_max(B) > q99` fired.
    /// @param leftAlert `−λ_min(B) > q99` fired.
    struct Flag {
        uint256 epoch;
        uint32 nodeCount;
        uint32 rightThresholdQ;
        uint32 leftThresholdQ;
        bytes32 graphDigest;
        bool rightAlert;
        bool leftAlert;
    }

    /// @notice `raise` was called by an address other than the alerter role.
    error NotAlerter(address caller);

    /// @notice Nothing to flag, and nothing was recorded: this deployment has no
    ///         alerter (a receive-only chain).
    error AlerterNotConfigured();

    /// @notice This `(source, epoch)` already carries a flag on this chain.
    error FlagAlreadyRecorded(bytes32 sourceBlockchainId, uint256 epoch);

    /// @notice Emitted when an alert is sent to the destinations.
    event AlertRaised(
        uint256 indexed epoch,
        bytes32 indexed graphDigest,
        bool rightAlert,
        bool leftAlert,
        uint256 destinations
    );

    /// @notice Emitted when a delivered alert is recorded on this chain.
    event AlertFlagged(
        bytes32 indexed sourceBlockchainId,
        uint256 indexed epoch,
        bytes32 graphDigest,
        uint32 nodeCount,
        uint32 rightThresholdQ,
        uint32 leftThresholdQ,
        bool rightAlert,
        bool leftAlert
    );

    /// @notice The only address allowed to `raise`, i.e. to speak for the RMT
    ///         detector (M5). Zero on a receive-only chain. No setter.
    address internal immutable ALERTER;

    /// @dev `sourceChain → epoch → the flag in force`. Append-only; a zero
    ///      `graphDigest` is the "nothing recorded" sentinel, and the codec never
    ///      lets a real alert carry one.
    mapping(bytes32 => mapping(uint256 => Flag)) private _flagOf;

    /// @notice How many flags this chain has recorded, across every source chain.
    uint256 public flagCount;

    /// @param teleporter_ The Teleporter messenger (shared by every endpoint).
    /// @param localBlockchainId_ This chain's id.
    /// @param alerter_ The only address that may raise an alert, or `address(0)` on
    ///        a chain that only receives alerts.
    /// @param origins_ The inbound allowlist.
    /// @param destinations_ The outbound routing table (the subscribed subnets).
    constructor(
        address teleporter_,
        bytes32 localBlockchainId_,
        address alerter_,
        Origin[] memory origins_,
        Destination[] memory destinations_
    ) AVIPMessageEndpoint(teleporter_, localBlockchainId_, origins_, destinations_) {
        ALERTER = alerter_;
    }

    // --------------------------------------------------------------- the sender

    /// @notice Announces one RMT verdict to every subscribed subnet.
    /// @dev The alert is refused before it is sent if it flags nothing
    ///      (`QuietAlert`) or names no graph (`EmptyGraphDigest`): a quiet verdict
    ///      is not §4's alert, and a message that says "something is wrong,
    ///      somewhere" is worse than no message.
    /// @param alert The verdict, as M5 decided it (see `Flag` for the fields).
    /// @return ids The messenger's id for each destination, in routing-table order.
    function raise(AVIPMessageCodec.CollusionAlert memory alert)
        external
        returns (bytes32[] memory ids)
    {
        if (ALERTER == address(0)) revert AlerterNotConfigured();
        if (msg.sender != ALERTER) revert NotAlerter(msg.sender);
        ids = _send(_kind(), AVIPMessageCodec.encodeAlert(alert));
        emit AlertRaised(
            alert.epoch, alert.graphDigest, alert.rightAlert, alert.leftAlert, ids.length
        );
    }

    // -------------------------------------------------------------- the receiver

    /// @notice This endpoint answers for message type 2.
    function _kind() internal pure override returns (uint8) {
        return AVIPMessageCodec.KIND_COLLUSION_ALERT;
    }

    /// @notice The flag recorded for `(sourceChain, epoch)`, zeroed if nothing.
    function flagOf(bytes32 sourceChainId, uint256 epoch) external view returns (Flag memory) {
        return _flagOf[sourceChainId][epoch];
    }

    /// @dev Records one flag, refusing to rewrite one. As in the relay, the payload
    ///      is re-decoded and re-validated here: the sender's copy of the "not a
    ///      quiet alert" rule is a courtesy, this one is the boundary.
    function _deliver(uint8, bytes32 sourceChainId, address, uint256, bytes memory payload)
        internal
        override
    {
        AVIPMessageCodec.CollusionAlert memory alert = AVIPMessageCodec.decodeAlert(payload);

        if (_flagOf[sourceChainId][alert.epoch].graphDigest != bytes32(0)) {
            revert FlagAlreadyRecorded(sourceChainId, alert.epoch);
        }

        _flagOf[sourceChainId][alert.epoch] = Flag({
            epoch: alert.epoch,
            nodeCount: alert.nodeCount,
            rightThresholdQ: alert.rightThresholdQ,
            leftThresholdQ: alert.leftThresholdQ,
            graphDigest: alert.graphDigest,
            rightAlert: alert.rightAlert,
            leftAlert: alert.leftAlert
        });
        flagCount += 1;

        emit AlertFlagged(
            sourceChainId,
            alert.epoch,
            alert.graphDigest,
            alert.nodeCount,
            alert.rightThresholdQ,
            alert.leftThresholdQ,
            alert.rightAlert,
            alert.leftAlert
        );
    }
}

