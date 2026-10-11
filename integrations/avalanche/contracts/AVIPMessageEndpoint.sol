// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    ITeleporterMessenger,
    TeleporterMessageInput,
    TeleporterFeeInfo
} from "./interfaces/ITeleporterMessenger.sol";
import {ITeleporterReceiver} from "./interfaces/ITeleporterReceiver.sol";
import {AVIPMessageCodec} from "./AVIPMessageCodec.sol";

/// @title AVIPMessageEndpoint
/// @notice The floor every AVIP transport contract stands on: who may speak
///         (origin allowlist), which message may be spoken once (the envelope's
///         nonce), and how a message leaves (Teleporter).
///
/// @dev Milestone M7d of `docs/architecture/implementation-plan.md` §5.11 (gap A9,
///      `docs/architecture/avalanche-integration.md` §4). The three message types
///      of §4 are *not* distinguished here — this contract is kind-agnostic on
///      purpose, so the two facts that protect every type are implemented once:
///
///      1. **the caller is the messenger.** `receiveTeleporterMessage` is the only
///         entry point and it is callable by `TELEPORTER` alone (`NotTeleporter`).
///         Everything else inside the call is data a sender chose, so the contract
///         treats all of it as hostile, including the origin address;
///      2. **the origin is an allowlist entry, per kind and per source chain.** One
///         contract answers for exactly one kind (`_kind()`, enforced at
///         construction and again at delivery), and that kind's allowlist maps
///         `sourceBlockchainId → originSenderAddress`. An unknown chain reverts
///         `UnknownOrigin`; a known chain with another sender reverts
///         `UnauthorizedOrigin`. The allowlist is fixed by the constructor: there
///         is no setter, in the same spirit as M2's `slashAuthority` (§5.2.4), so
///         "who may slash on this subnet" is a deployment fact and not a
///         governance surface. An **empty** allowlist is allowed and means
///         "accepts nothing", which is how a send-only endpoint is wired;
///      3. **a message is delivered at most once.** The envelope carries a nonce
///         (`AVIPMessageCodec`) *because Teleporter does not hand one to a
///         receiver* — see `./interfaces/ITeleporterReceiver.sol` — so the receiver
///         keeps its own `(sourceChain, originSender, nonce)` set and refuses a
///         repeat with `MessageAlreadyDelivered`. Teleporter may legitimately hand
///         the same message over twice (a solver retries a message whose execution
///         failed), so this is not defensive programming: it is the only thing
///         standing between a re-delivery and a second slash.
///
///      Two mechanisms that look similar are kept apart deliberately:
///
///        - the **nonce** guards *identity* (one message is one message), and it is
///          per `(source, sender)` so two senders from one chain cannot collide;
///        - **ordering** is *not* enforced here. Teleporter relayers do not promise
///          an order, so an endpoint that required nonces to arrive in sequence
///          would refuse messages that are perfectly valid. A message whose
///          *effect* needs ordering enforces that in `_deliver`, over its own
///          quantity: `AVIPCommitmentRelay` requires a strictly increasing epoch,
///          which is a property of the commitment and not of the transport.
///
///      What this contract does NOT do, and why: it does not pay a fee
///      (`feeTokenAddress = address(0)`, `amount = 0`, so no token is transferred —
///      the transport carries no funds, consistent with M2's "no custody",
///      §5.2.3); it does not restrict the relayer (`allowedRelayerAddresses` is
///      empty, which Teleporter reads as "any relayer"; picking one is a
///      deployment decision, not a transport rule); and it makes **no liveness or
///      ordering claim** about the destination chain — a message that is never
///      delivered is a message that never happened, which is what `A11`'s deferred
///      Teleporter latency benchmark would have to measure.
abstract contract AVIPMessageEndpoint is ITeleporterReceiver {
    /// @notice The gas the *destination* execution of an AVIP message is allowed to
    ///         consume: an `abi.decode` of one payload, one to three stores, and —
    ///         for a slashing notification — one call into the validator manager.
    ///         Teleporter charges the sender for this budget, so it is an
    ///         engineering parameter and **not** a protocol constant from the
    ///         paper: the value below is the one M7d pins for the reference wiring,
    ///         and a deployment that changes `_deliver` must raise it.
    uint256 internal constant REQUIRED_GAS_LIMIT = 300_000;

    /// @notice One entry of the inbound allowlist: which chain, which sender, for
    ///         which kind.
    /// @param kind The message kind this entry authorises.
    /// @param sourceBlockchainId The chain the message comes from.
    /// @param originSenderAddress The only address on that chain that may send it.
    struct Origin {
        uint8 kind;
        bytes32 sourceBlockchainId;
        address originSenderAddress;
    }

    /// @notice One entry of the outbound routing table: where a message goes.
    /// @param blockchainId The destination chain.
    /// @param receiver The endpoint contract on it. The transport never sends to
    ///        `address(this)`: two chains are two deployments, and an implicit
    ///        "same address everywhere" rule is the kind of wiring that breaks the
    ///        moment one of the two is redeployed.
    struct Destination {
        bytes32 blockchainId;
        address receiver;
    }

    /// @notice `receiveTeleporterMessage` was called by something other than the
    ///         messenger.
    error NotTeleporter(address caller);

    /// @notice The message carries a kind this endpoint does not answer for.
    error UnexpectedMessageKind(uint8 kind, uint8 expected);

    /// @notice No allowlist entry for this kind on that chain.
    error UnknownOrigin(uint8 kind, bytes32 sourceBlockchainId);

    /// @notice The chain is allowed, the sender is not.
    error UnauthorizedOrigin(uint8 kind, bytes32 sourceBlockchainId, address expected, address got);

    /// @notice This `(source, sender, nonce)` was already delivered.
    error MessageAlreadyDelivered(
        bytes32 sourceBlockchainId, address originSenderAddress, uint256 nonce
    );

    /// @notice A constructor argument is empty or zero.
    error EmptyConfiguration(string field);

    /// @notice An allowlist entry names a kind this contract does not answer for.
    error ForeignOriginKind(uint8 kind, uint8 expected);

    /// @notice `_send` was called with no destination configured.
    error NoDestination();

    /// @notice The messenger this contract sends through. `internal` and
    ///         SCREAMING_SNAKE_CASE because that is the repository's shape for a
    ///         constructor-fixed immutable (`Groth16Verifier`'s
    ///         `VERIFYING_KEY_DIGEST`); `teleporter()` exposes the value.
    ITeleporterMessenger internal immutable TELEPORTER;

    /// @notice The chain this deployment lives on, in the messenger's own
    ///         encoding. Kept as state because Teleporter's *sending* side never
    ///         tells a contract its own chain id: the receiving side learns it from
    ///         the message, the sending side has to be told.
    bytes32 internal immutable LOCAL_BLOCKCHAIN_ID;

    /// @dev `kind → sourceChain → originSender`. The kind is part of the key rather
    ///      than implied by the deployment, so a future endpoint that answers for
    ///      two kinds cannot silently widen this one's trust.
    mapping(uint8 => mapping(bytes32 => address)) private _originOf;

    /// @dev `sourceChain → originSender → nonce → delivered`.
    mapping(bytes32 => mapping(address => mapping(uint256 => bool))) private _delivered;

    /// @dev The outbound routing table, read by `_send`.
    Destination[] private _destinations;

    /// @dev The sender's nonce, per destination chain. Monotone and never reused: a
    ///      revert rolls the whole transaction back, so the counter cannot leak a
    ///      value that was never sent.
    mapping(bytes32 => uint256) private _nextNonce;

    /// @notice How many messages this endpoint has delivered. A counter rather than
    ///         an event, so a transcript can print one line that moves.
    uint256 public deliveredMessages;

    // -------------------------------------------------------------- construction

    /// @param teleporter_ The Teleporter messenger on this chain.
    /// @param localBlockchainId_ This chain's id.
    /// @param origins_ The inbound allowlist. It may be **empty**, and an empty
    ///        allowlist means what it says: this deployment accepts nothing from
    ///        anyone, which is exactly the right configuration for a send-only
    ///        endpoint (a source chain announces; it does not listen). A non-empty
    ///        entry must name this contract's kind, so a copy-paste from another
    ///        message type fails here instead of quietly authorising nothing.
    /// @param destinations_ The outbound routing table. May be empty as well: a
    ///        receiving endpoint does not send.
    constructor(
        address teleporter_,
        bytes32 localBlockchainId_,
        Origin[] memory origins_,
        Destination[] memory destinations_
    ) {
        if (teleporter_ == address(0)) {
            revert EmptyConfiguration("teleporter");
        }
        if (localBlockchainId_ == bytes32(0)) revert EmptyConfiguration("localBlockchainId");
        TELEPORTER = ITeleporterMessenger(teleporter_);
        LOCAL_BLOCKCHAIN_ID = localBlockchainId_;

        uint8 expected = _kind();
        for (uint256 i = 0; i < origins_.length; ++i) {
            Origin memory origin = origins_[i];
            if (origin.kind != expected) revert ForeignOriginKind(origin.kind, expected);
            if (origin.sourceBlockchainId == bytes32(0)) {
                revert EmptyConfiguration("origin.sourceBlockchainId");
            }
            if (origin.originSenderAddress == address(0)) {
                revert EmptyConfiguration("origin.originSenderAddress");
            }
            _originOf[origin.kind][origin.sourceBlockchainId] = origin.originSenderAddress;
        }

        for (uint256 i = 0; i < destinations_.length; ++i) {
            Destination memory destination = destinations_[i];
            if (destination.blockchainId == bytes32(0)) {
                revert EmptyConfiguration("destination.blockchainId");
            }
            if (destination.receiver == address(0)) {
                revert EmptyConfiguration("destination.receiver");
            }
            _destinations.push(destination);
        }
    }

    // ------------------------------------------------------------------- views

    /// @notice The message kind this endpoint answers for.
    function kind() external pure returns (uint8) {
        return _kind();
    }

    /// @notice The Teleporter messenger this endpoint sends through.
    function teleporter() external view returns (ITeleporterMessenger) {
        return TELEPORTER;
    }

    /// @notice The chain this deployment lives on.
    function localBlockchainId() external view returns (bytes32) {
        return LOCAL_BLOCKCHAIN_ID;
    }

    /// @notice The allowlist entry for `(kind, sourceChain)`, or the zero address.
    function originOf(uint8 kind_, bytes32 sourceBlockchainId) external view returns (address) {
        return _originOf[kind_][sourceBlockchainId];
    }

    /// @notice How many destinations this endpoint sends to.
    function destinationCount() external view returns (uint256) {
        return _destinations.length;
    }

    /// @notice The destination at `index` of the routing table.
    function destinationAt(uint256 index) external view returns (Destination memory) {
        return _destinations[index];
    }

    /// @notice The next nonce this endpoint will use for `destinationChain`.
    function nextNonce(bytes32 destinationChain) external view returns (uint256) {
        return _nextNonce[destinationChain];
    }

    /// @notice True iff `(sourceChain, originSender, nonce)` was already delivered.
    function isDelivered(bytes32 sourceBlockchainId, address originSenderAddress, uint256 nonce)
        external
        view
        returns (bool)
    {
        return _delivered[sourceBlockchainId][originSenderAddress][nonce];
    }

    // ------------------------------------------------------------ the boundary

    /// @inheritdoc ITeleporterReceiver
    /// @dev The order of the checks is the order of the trust boundary: caller,
    ///      then the message's own shape, then identity, then the replay guard, and
    ///      only then the effect.
    function receiveTeleporterMessage(
        bytes32 sourceBlockchainId,
        address originSenderAddress,
        bytes calldata message
    ) external {
        if (msg.sender != address(TELEPORTER)) {
            revert NotTeleporter(msg.sender);
        }

        (uint8 messageKind, uint256 nonce, bytes memory payload) =
            AVIPMessageCodec.decodeEnvelope(message);
        if (messageKind != _kind()) revert UnexpectedMessageKind(messageKind, _kind());

        address expected = _originOf[messageKind][sourceBlockchainId];
        if (expected == address(0)) revert UnknownOrigin(messageKind, sourceBlockchainId);
        if (expected != originSenderAddress) {
            revert UnauthorizedOrigin(
                messageKind, sourceBlockchainId, expected, originSenderAddress
            );
        }

        if (_delivered[sourceBlockchainId][originSenderAddress][nonce]) {
            revert MessageAlreadyDelivered(sourceBlockchainId, originSenderAddress, nonce);
        }
        _delivered[sourceBlockchainId][originSenderAddress][nonce] = true;
        deliveredMessages += 1;

        _deliver(messageKind, sourceBlockchainId, originSenderAddress, nonce, payload);
    }

    // ------------------------------------------------------------------- hooks

    /// @dev The kind this contract answers for. Declared abstract rather than taken
    ///      as a constructor argument so that a new message type cannot be deployed
    ///      while staying silent about which type it is.
    function _kind() internal pure virtual returns (uint8);

    /// @dev The effect of one message, after the boundary above has passed. The
    ///      payload must be re-validated here: the sender's checks are a courtesy,
    ///      not a guarantee (`AVIPMessageCodec`). `sourceBlockchainId` and `nonce`
    ///      are passed on because a notification's `reason` is derived from them.
    function _deliver(
        uint8 kind_,
        bytes32 sourceBlockchainId,
        address originSenderAddress,
        uint256 nonce,
        bytes memory payload
    ) internal virtual;

    // ------------------------------------------------------------------ sending

    /// @dev Sends one message of `kind` to every configured destination, returning
    ///      the messenger's ids in the same order. One `sendCrossChainMessage` call
    ///      per destination: Teleporter's payload is a single `bytes`
    ///      (`TeleporterMessageInput.message`), so three subscribers are three
    ///      messages, each with its own nonce for that destination.
    function _send(uint8 kind_, bytes memory payload) internal returns (bytes32[] memory ids) {
        uint256 count = _destinations.length;
        if (count == 0) revert NoDestination();
        ids = new bytes32[](count);
        address[] memory noRelayers = new address[](0);
        for (uint256 i = 0; i < count; ++i) {
            Destination memory destination = _destinations[i];
            uint256 nonce = _nextNonce[destination.blockchainId]++;
            ids[i] = TELEPORTER.sendCrossChainMessage(
                TeleporterMessageInput({
                    destinationBlockchainID: destination.blockchainId,
                    destinationAddress: destination.receiver,
                    feeInfo: TeleporterFeeInfo({feeTokenAddress: address(0), amount: 0}),
                    requiredGasLimit: REQUIRED_GAS_LIMIT,
                    allowedRelayerAddresses: noRelayers,
                    message: AVIPMessageCodec.encode(kind_, nonce, payload)
                })
            );
        }
    }
}

