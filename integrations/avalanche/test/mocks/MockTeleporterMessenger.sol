// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    ITeleporterMessenger,
    TeleporterMessageInput
} from "../../contracts/interfaces/ITeleporterMessenger.sol";
import {ITeleporterReceiver} from "../../contracts/interfaces/ITeleporterReceiver.sol";

/// @title MockTeleporterMessenger
/// @notice The double the M7d suites and the M7d report drive the three AVIP
///         message types through: a switchboard, not a messenger.
///
/// WHAT THIS IS
/// ------------
/// 1. **A routing table.** `registerEndpoint(endpoint, blockchainId)` says which
///    chain a contract lives on. The source chain id of a message is therefore read
///    from that table (`_chainOf[msg.sender]`) and **not** from the caller: a sender
///    cannot claim to be on another chain, which is precisely the field the
///    receiver's allowlist is keyed on. An unregistered sender reverts
///    (`UnknownEndpoint`), and so does an unregistered destination, so a wiring
///    mistake fails at the first message instead of passing silently.
/// 2. **A destination check.** `TeleporterMessageInput` names the destination chain
///    *and* the destination address; the messenger is what makes those two agree.
///    This double refuses a mismatch (`WrongDestinationChain`), so a suite cannot
///    demonstrate a delivery that the real messenger would have rejected.
/// 3. **A synchronous delivery.** `sendCrossChainMessage` calls
///    `receiveTeleporterMessage` on the destination before returning, with the
///    source chain from the routing table and the origin sender as `msg.sender`.
///    That is what makes the receiver's own decision — allowlist, nonce, payload —
///    observable in the caller's transaction, and it is why a receiver's revert
///    bubbles up to the sender here.
/// 4. **A message log.** `messageIds`/`messageIdAt` expose what was sent, so a
///    transcript can print a messenger id without an explorer.
///
/// WHAT THIS IS NOT (and what that means for the claims the suites can make)
/// -----------------------------------------------------------------------
/// - **Not AWM and not Teleporter.** There is no BLS signature, no source-chain
///   quorum, no relayer, no fee, no gas metering, no receipt, no retry queue and no
///   Warp message. Nothing in this milestone measures or claims anything about how
///   the real protocol behaves: `A11`'s Teleporter latency benchmark stays deferred
///   because it needs a live subnet (`implementation-plan.md` §2.2).
/// - **Delivery is synchronous; the real one is not.** Upstream, a receiver that
///   reverts produces a *failed* message (`MessageExecutionFailed`) that can be
///   retried, and the sender's transaction succeeds. Here the revert travels back
///   to the sender instead. Only the *receiver's* decision is a faithful subject of
///   these tests; the propagation of that revert is a property of the double, and
///   the suites say so where they rely on it.
/// - **The message id is not the protocol's.** Real ids fold the messenger's own
///   per-destination nonce; this one is
///   `keccak256(abi.encode(sourceChain, sender, destinationChain, destination,
///   nonce))` with a counter of the double's own. It identifies a line of the
///   transcript, nothing more.
/// - **No fee is transferred and no fee is refused.** `TeleporterFeeInfo` is stored
///   with the message and never acted on, so a suite cannot observe what the real
///   messenger does with a zero-address fee token. The AVIP channels send no fee at
///   all (`AVIPMessageEndpoint._send`), which is the fact under test.
contract MockTeleporterMessenger is ITeleporterMessenger {
    /// @notice What the double remembers about one sent message.
    /// @param sourceBlockchainId From the routing table, never from the caller.
    /// @param originSenderAddress The caller, i.e. the sender-side endpoint.
    /// @param destinationBlockchainId As declared in the input, checked against the
    ///        routing table.
    /// @param destinationAddress The receiving endpoint.
    /// @param requiredGasLimit As declared in the input (not enforced here).
    /// @param message The payload, opaque to the double.
    struct Routed {
        bytes32 sourceBlockchainId;
        address originSenderAddress;
        bytes32 destinationBlockchainId;
        address destinationAddress;
        uint256 requiredGasLimit;
        bytes message;
    }

    /// @notice The endpoint is not in the routing table.
    error UnknownEndpoint(address endpoint);

    /// @notice The input's destination chain is not the one the destination address
    ///         is registered on.
    error WrongDestinationChain(bytes32 registered, bytes32 given);

    /// @notice Emitted by the double for every message it routes. Deliberately not
    ///         Teleporter's own event (that one carries the full `TeleporterMessage`
    ///         struct, which M7d does not declare).
    event MessageSent(
        bytes32 indexed messageId,
        bytes32 indexed sourceBlockchainId,
        bytes32 indexed destinationBlockchainId,
        address originSenderAddress,
        address destinationAddress,
        uint256 nonce
    );

    /// @notice Emitted after the destination has accepted the message.
    event MessageDelivered(bytes32 indexed messageId, bytes32 indexed destinationBlockchainId);

    /// @dev `endpoint → the chain it is registered on`.
    mapping(address => bytes32) private _chainOf;

    /// @dev `messageId → what was sent`.
    mapping(bytes32 => Routed) private _routed;

    /// @dev Every message id, in send order.
    bytes32[] private _messageIds;

    /// @dev The double's own message counter.
    uint256 private _nonce;

    /// @notice How many messages were sent.
    uint256 public sentMessages;

    /// @notice How many messages the destinations accepted.
    uint256 public deliveredMessages;

    // ------------------------------------------------------------- the routing

    /// @notice Puts `endpoint` on `blockchainId` in the routing table.
    function registerEndpoint(address endpoint, bytes32 blockchainId) external {
        require(endpoint != address(0), "MockTeleporterMessenger: zero endpoint");
        require(blockchainId != bytes32(0), "MockTeleporterMessenger: zero chain");
        _chainOf[endpoint] = blockchainId;
    }

    /// @notice The chain `endpoint` is registered on, or zero.
    function chainOf(address endpoint) external view returns (bytes32) {
        return _chainOf[endpoint];
    }

    /// @notice Every message id, in send order.
    function messageIds() external view returns (bytes32[] memory) {
        return _messageIds;
    }

    /// @notice The message id at `index` of the send order.
    function messageIdAt(uint256 index) external view returns (bytes32) {
        return _messageIds[index];
    }

    /// @notice What the double remembers about `messageId`.
    function routedMessage(bytes32 messageId) external view returns (Routed memory) {
        return _routed[messageId];
    }

    // -------------------------------------------------------------- the sending

    /// @inheritdoc ITeleporterMessenger
    /// @dev Fail-closed in three ways before anything is delivered: both endpoints
    ///      must be registered, and the input's destination chain must be the one
    ///      the destination address is registered on.
    function sendCrossChainMessage(TeleporterMessageInput calldata messageInput)
        external
        returns (bytes32 messageId)
    {
        bytes32 sourceChainId = _chainOf[msg.sender];
        if (sourceChainId == bytes32(0)) revert UnknownEndpoint(msg.sender);
        bytes32 registered = _chainOf[messageInput.destinationAddress];
        if (registered == bytes32(0)) revert UnknownEndpoint(messageInput.destinationAddress);
        if (registered != messageInput.destinationBlockchainID) {
            revert WrongDestinationChain(registered, messageInput.destinationBlockchainID);
        }

        uint256 nonce = ++_nonce;
        messageId = keccak256(
            abi.encode(
                sourceChainId,
                msg.sender,
                messageInput.destinationBlockchainID,
                messageInput.destinationAddress,
                nonce
            )
        );

        _routed[messageId] = Routed({
            sourceBlockchainId: sourceChainId,
            originSenderAddress: msg.sender,
            destinationBlockchainId: messageInput.destinationBlockchainID,
            destinationAddress: messageInput.destinationAddress,
            requiredGasLimit: messageInput.requiredGasLimit,
            message: messageInput.message
        });
        _messageIds.push(messageId);
        sentMessages += 1;

        emit MessageSent(
            messageId,
            sourceChainId,
            messageInput.destinationBlockchainID,
            msg.sender,
            messageInput.destinationAddress,
            nonce
        );

        // The delivery. This double is the caller the endpoint sees — which is what
        // every endpoint checks (`NotTeleporter`) — and the sending endpoint is the
        // origin sender, which is what the allowlist checks.
        ITeleporterReceiver(messageInput.destinationAddress)
            .receiveTeleporterMessage(sourceChainId, msg.sender, messageInput.message);
        deliveredMessages += 1;

        emit MessageDelivered(messageId, messageInput.destinationBlockchainID);
    }
}

