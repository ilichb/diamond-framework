// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice The fee attached to a Teleporter message: the asset the fee is paid
///         in and the amount of it.
/// @dev Declared verbatim from `icm-contracts`
///      (`contracts/teleporter/ITeleporterMessenger.sol`).
struct TeleporterFeeInfo {
    address feeTokenAddress;
    uint256 amount;
}

/// @notice Everything required to submit a Teleporter message: where it goes,
///         who pays the relayer, how much gas the destination execution may
///         consume, which relayers may deliver it, and the payload itself.
/// @dev Declared verbatim from `icm-contracts`, field order and types included.
///      Note that `message` is a **single** `bytes`, not an array: one
///      `sendCrossChainMessage` carries exactly one payload, so a channel that
///      has three recipients makes three calls.
struct TeleporterMessageInput {
    bytes32 destinationBlockchainID;
    address destinationAddress;
    TeleporterFeeInfo feeInfo;
    uint256 requiredGasLimit;
    address[] allowedRelayerAddresses;
    bytes message;
}

/// @title ITeleporterMessenger
/// @notice The sending side of Avalanche Warp Messaging, as far as this
///         repository calls it.
///
/// @dev Milestone M7d of `docs/architecture/implementation-plan.md` §5.11 (gap
///      A9). This file declares the **subset** of the upstream interface that
///      M7d calls — `sendCrossChainMessage` and the two structs it needs — taken
///      verbatim from `ava-labs/icm-contracts`,
///      `contracts/teleporter/ITeleporterMessenger.sol` on `main` (read while
///      implementing this milestone, 2026-10):
///
///          function sendCrossChainMessage(
///              TeleporterMessageInput calldata messageInput
///          ) external returns (bytes32);
///
///      A subset is not a different ABI: an omitted member cannot be called by
///      accident, and the members that *are* declared keep the upstream spelling
///      and order. Nothing from `icm-contracts` is vendored — this repository has
///      never carried a git dependency, and the whole milestone is validated
///      against `../test/mocks/MockTeleporterMessenger.sol` offline rather than
///      against a live messenger.
///
///      Two properties of the real contract are load-bearing here and are
///      carried in the declarations rather than in prose:
///
///        - **`sendCrossChainMessage` is not `payable`.** Fees travel as an
///          ERC-20 through `feeInfo.feeTokenAddress` (`transferFrom` inside the
///          messenger), not as `msg.value`. No AVIP channel ever sends value, so
///          the transport carries no funds — consistent with M2's "no custody"
///          (§5.2.3);
///        - **the destination is a `(chain, address)` pair that the sender
///          chooses.** Teleporter does not route by chain and does not know the
///          receiving contract; it is the *receiver's* allowlist that decides
///          which `(sourceChain, originSender)` pairs may speak, which is why
///          `AVIPMessageEndpoint` holds one (`NoOrigin` / `UnauthorizedOrigin`).
interface ITeleporterMessenger {
    /// @notice Emitted when a Teleporter message is sent cross-chain.
    /// @param messageID The messenger's own id for the message.
    /// @param destinationBlockchainID The destination chain id.
    /// @param messageNonce The messenger's per-destination nonce.
    /// @param originSenderAddress The caller; the destination sees this address
    ///        as the message's origin.
    /// @param destinationAddress The receiving contract.
    /// @param feeInfo The fee attached to the message.
    /// @param requiredGasLimit The gas the destination execution may consume.
    /// @param message The payload, opaque to the messenger.
    /// @dev The upstream event carries the full `TeleporterMessage` struct
    ///      instead; it is flattened here because M7d declares neither
    ///      `TeleporterMessage` nor `TeleporterMessageReceipt` (the subset rule
    ///      above). The field list is the one an explorer shows.
    event SendCrossChainMessage(
        bytes32 indexed messageID,
        bytes32 indexed destinationBlockchainID,
        uint256 messageNonce,
        address indexed originSenderAddress,
        address destinationAddress,
        TeleporterFeeInfo feeInfo,
        uint256 requiredGasLimit,
        bytes message
    );

    /// @notice Initiates the sending of one cross-chain message.
    /// @param messageInput Where the message goes, who may deliver it, how much
    ///        gas the destination may spend, and the payload.
    /// @return The message ID of the newly sent message.
    function sendCrossChainMessage(TeleporterMessageInput calldata messageInput)
        external
        returns (bytes32);
}
