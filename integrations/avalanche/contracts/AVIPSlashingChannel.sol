// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAVIPValidatorManager} from "./interfaces/IAVIPValidatorManager.sol";
import {AVIPMessageCodec} from "./AVIPMessageCodec.sol";
import {AVIPMessageEndpoint} from "./AVIPMessageEndpoint.sol";

/// @title AVIPSlashingChannel
/// @notice Message type 3 of `docs/architecture/avalanche-integration.md` §4: the
///         slashing notification. On the chain whose data layer proved the fraud it
///         announces the outcome; on a subnet where the validator is registered it
///         executes `IAVIPValidatorManager.slash`.
///
/// @dev Milestone M7d of `docs/architecture/implementation-plan.md` §5.11 (gap
///      A9). Same shape as the other two channels: one contract type, deployed once
///      per chain, with the fields the other side does not use left zero (a
///      send-only chain has no manager, a receive-only chain has no notifier).
///
///      **The `reason` is derived, not carried.** M8's treasury will consume the
///      manager's `ValidatorSlashed(validator, amount, reason)` event, so what
///      `reason` means matters beyond this milestone. It is
///      `AVIPMessageCodec.provenanceId(sourceBlockchainId, nonce)` — a function of
///      *where* the message came from and *which* message it was, not of anything a
///      sender chose. A notifier cannot make two different faults share a reason,
///      cannot reuse a reason for a different fault, and cannot suppress the reason
///      by sending an empty one: the value is recomputed on arrival. The transport
///      is the producer of that provenance id; M8 is its consumer.
///
///      **The notification says what was proven, and the manager bounds what it
///      executes.** The message carries M7b's `Verdict::Fraud` pair
///      (`publishedWad`, `formulaWad`) and the digest of the ingestion instance in
///      force, so the destination records *what* the fraud was; the amount is the
///      data layer's decision and the manager refuses anything above the stake on
///      record (`SlashExceedsStake`). A notification can therefore neither mint nor
///      move funds: it can only ask the manager to slash, and the manager's own
///      rule decides whether there is anything to take.
///
///      **What happens when the destination cannot execute.** The call to
///      `slash` reverts for a validator with no stake, for an amount above it, and
///      if this contract is not the manager's slash authority
///      (`NotSlashAuthority`). The revert propagates out of
///      `receiveTeleporterMessage` — deliberately. Real Teleporter treats a
///      reverting receiver as a *failed* message (`MessageExecutionFailed`) that can
///      be retried, and the double in `../test/mocks/MockTeleporterMessenger.sol`
///      delivers synchronously and lets the revert bubble instead; either way the
///      slashing does not half-happen, and the reason is recorded **before** the
///      manager is called only in the emit order below (a revert rolls it back).
contract AVIPSlashingChannel is AVIPMessageEndpoint {
    /// @notice `notify` was called on a deployment with no notifier (a receive-only
    ///         chain): there is no data layer here to carry a decision from.
    error NotifierNotConfigured();

    /// @notice `notify` was called by an address other than the notifier role.
    error NotNotifier(address caller);

    /// @notice This deployment has no validator manager to execute against (a
    ///         send-only chain, or a misconfigured subnet).
    error ManagerNotConfigured();

    /// @notice Emitted when a slashing notification is sent to the destinations.
    event SlashingNotified(
        address indexed validator,
        uint256 amountWad,
        uint256 indexed epoch,
        bytes32 ingestionDigest,
        uint256 publishedWad,
        uint256 formulaWad,
        uint256 destinations
    );

    /// @notice Emitted when a delivered notification has been executed on this
    ///         chain. `reason` is the provenance id the manager also saw.
    event SlashingExecuted(
        bytes32 indexed sourceBlockchainId,
        uint256 nonce,
        address indexed validator,
        uint256 amountWad,
        bytes32 reason
    );

    /// @notice The only address allowed to `notify`, i.e. to carry the data layer's
    ///         slashing decision (§5.9). Zero on a receive-only chain. No setter.
    address internal immutable NOTIFIER;

    /// @notice The manager that executes the slash (M2). Zero on a send-only chain.
    IAVIPValidatorManager internal immutable MANAGER;

    /// @dev `sourceChain → nonce → the reason that was executed`. Kept so the
    ///      provenance id an auditor recomputes can be compared with the one this
    ///      chain acted on, without replaying the events.
    mapping(bytes32 => mapping(uint256 => bytes32)) private _reasonOf;

    /// @notice How many notifications this chain has executed.
    uint256 public executedSlashes;

    /// @param teleporter_ The Teleporter messenger (shared by every endpoint).
    /// @param localBlockchainId_ This chain's id.
    /// @param notifier_ The only address that may notify, or `address(0)` on a chain
    ///        that only receives.
    /// @param manager_ The M2 manager whose `slash` this deployment executes, or
    ///        `address(0)` on a chain that only sends.
    /// @param origins_ The inbound allowlist: the `(chain, sender)` pairs whose
    ///        notifications this chain executes. This allowlist is the one that
    ///        decides which subnet a validator can be slashed from, which is exactly
    ///        what §4's "all subnets where the slashed validator is registered"
    ///        means once it is written down.
    /// @param destinations_ The outbound routing table (the subnets to tell).
    constructor(
        address teleporter_,
        bytes32 localBlockchainId_,
        address notifier_,
        address manager_,
        Origin[] memory origins_,
        Destination[] memory destinations_
    ) AVIPMessageEndpoint(teleporter_, localBlockchainId_, origins_, destinations_) {
        NOTIFIER = notifier_;
        MANAGER = IAVIPValidatorManager(manager_);
    }

    // --------------------------------------------------------------- the sender

    /// @notice Announces one fraud proof's outcome to every configured subnet.
    /// @dev The payload is validated before it is sent (`EmptyValidator`,
    ///      `ZeroSlashAmount`, `EmptyIngestionDigest`, `NotAFraudProof`): the last
    ///      one is M7b's semantics rather than a formatting rule, because a fraud
    ///      proof *is* a published value that differs from `f_c(events)`.
    /// @param notification The decision, from §5.9's `Verdict::Fraud`.
    /// @return ids The messenger's id for each destination, in routing-table order.
    function notify(AVIPMessageCodec.SlashingNotification memory notification)
        external
        returns (bytes32[] memory ids)
    {
        if (NOTIFIER == address(0)) revert NotifierNotConfigured();
        if (msg.sender != NOTIFIER) revert NotNotifier(msg.sender);
        ids = _send(_kind(), AVIPMessageCodec.encodeSlashing(notification));
        emit SlashingNotified(
            notification.validator,
            notification.amountWad,
            notification.epoch,
            notification.ingestionDigest,
            notification.publishedWad,
            notification.formulaWad,
            ids.length
        );
    }

    // -------------------------------------------------------------- the receiver

    /// @notice This endpoint answers for message type 3.
    function _kind() internal pure override returns (uint8) {
        return AVIPMessageCodec.KIND_SLASHING_NOTIFICATION;
    }

    /// @notice The provenance id `(sourceChain, nonce)` produces, whether or not
    ///         this chain has acted on it. Derived, so it needs no storage to be
    ///         known — and that is the point: an auditor recomputes it.
    function reasonFor(bytes32 sourceChainId, uint256 nonce) external pure returns (bytes32) {
        return AVIPMessageCodec.provenanceId(sourceChainId, nonce);
    }

    /// @notice The reason this chain executed for `(sourceChain, nonce)`, or zero if
    ///         it never acted on that message.
    function reasonOf(bytes32 sourceChainId, uint256 nonce) external view returns (bytes32) {
        return _reasonOf[sourceChainId][nonce];
    }

    /// @dev Decodes, re-validates, derives the reason and asks the manager to slash.
    ///      The order is deliberate: the record is written and then the manager is
    ///      called, so a manager revert (`SlashExceedsStake`, `NotSlashAuthority`)
    ///      rolls the record back with everything else — a chain that cannot execute
    ///      does not leave a reason behind as if it had.
    function _deliver(uint8, bytes32 sourceChainId, address, uint256 nonce, bytes memory payload)
        internal
        override
    {
        AVIPMessageCodec.SlashingNotification memory notification =
            AVIPMessageCodec.decodeSlashing(payload);

        if (address(MANAGER) == address(0)) revert ManagerNotConfigured();

        bytes32 reason = AVIPMessageCodec.provenanceId(sourceChainId, nonce);
        _reasonOf[sourceChainId][nonce] = reason;
        executedSlashes += 1;

        MANAGER.slash(notification.validator, notification.amountWad, reason);

        emit SlashingExecuted(
            sourceChainId, nonce, notification.validator, notification.amountWad, reason
        );
    }
}

