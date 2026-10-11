// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ITeleporterReceiver
/// @notice The receiver side of Avalanche Warp Messaging: the interface a
///         cross-chain application implements so that `TeleporterMessenger` can
///         hand it a delivered message.
///
/// @dev Milestone M7d of `docs/architecture/implementation-plan.md` §5.11 (gap
///      A9, `docs/architecture/avalanche-integration.md` §4). The declaration is
///      the upstream one, **verbatim**, so a deployment against the real
///      `TeleporterMessenger` cannot disagree with this repository about the
///      ABI:
///
///          function receiveTeleporterMessage(
///              bytes32 sourceBlockchainID,
///              address originSenderAddress,
///              bytes calldata message
///          ) external;
///
///      Source: `ava-labs/icm-contracts`, `contracts/teleporter/
///      ITeleporterReceiver.sol` on `main`, read while implementing this
///      milestone (2026-10). Nothing from `icm-contracts` is vendored: this
///      repository has never taken a git dependency, so the ABI is *declared*
///      rather than imported, and `../test/mocks/MockTeleporterMessenger.sol` is
///      the double that exercises it offline.
///
///      Two facts about this signature decide the whole design of
///      `../AVIPMessageEndpoint.sol`:
///
///        - **the caller is the messenger, and only the messenger.** There is no
///          access control to invent: `msg.sender` must be the Teleporter
///          contract instance, and everything else in the message is data the
///          *sender* chose;
///        - **there is no nonce and no message id.** `TeleporterMessage` carries
///          a protocol nonce on the sending side, but a receiver is handed the
///          payload alone, so a message cannot be deduplicated by anything the
///          protocol provides. AVIP messages therefore carry their own nonce in
///          the envelope (`AVIPMessageCodec.encode`), and the receiver refuses a
///          `(source, sender, nonce)` it has already delivered (§5.11).
interface ITeleporterReceiver {
    /// @dev Called by `TeleporterMessenger` on the receiving chain.
    ///
    ///      A solver may re-deliver a message whose execution failed; the
    ///      receiver therefore has to be replay-safe on its own, and it is
    ///      (`AVIPMessageEndpoint.MessageAlreadyDelivered`).
    ///
    /// @param sourceBlockchainID Provided by `TeleporterMessenger`: the chain the
    ///        message came from, i.e. the one the registry's commitment lives on.
    /// @param originSenderAddress Provided by `TeleporterMessenger`: the address
    ///        that called `sendCrossChainMessage` on the source chain. It is the
    ///        only identity the transport offers, and it is what the receiver's
    ///        origin allowlist is keyed on.
    /// @param message The payload the sender passed, opaque to Teleporter.
    function receiveTeleporterMessage(
        bytes32 sourceBlockchainID,
        address originSenderAddress,
        bytes calldata message
    ) external;
}
