// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/console2.sol";
import {DeployCommon} from "./DeployCommon.sol";
import {AVIPMessageCodec} from "../contracts/AVIPMessageCodec.sol";
import {AVIPMessageEndpoint} from "../contracts/AVIPMessageEndpoint.sol";
import {AVIPCommitmentRelay} from "../contracts/AVIPCommitmentRelay.sol";
import {AVIPCollusionAlertChannel} from "../contracts/AVIPCollusionAlertChannel.sol";
import {AVIPSlashingChannel} from "../contracts/AVIPSlashingChannel.sol";
import {MockTeleporterMessenger} from "../test/mocks/MockTeleporterMessenger.sol";

/// @title DeployTransport
/// @notice Deploys the three message types of
///         `docs/architecture/avalanche-integration.md` §4 on **one** chain:
///         the commitment relay, the collusion alert channel and the slashing
///         channel, wired to the peer of the other chain.
///
/// @dev Milestone M7d of `docs/architecture/implementation-plan.md` §5.11 (gap
///      A9). `M7dReport.s.sol` proved the wire format across two chain ids on a
///      local EVM; this script is the half that was still missing: the same three
///      contracts, deployed for real, one side per invocation.
///
///      **One side per run, because the two sides are two chains.** A message
///      needs a sender and a receiver, and neither chain knows the other's
///      addresses in advance. So `TRANSPORT_SIDE` names which half this run
///      builds:
///
///        - `source`: the chain whose registry commits. The relay reads
///          `registry`/`sequencer`, the alert channel takes `ALERTER`, the
///          slashing channel takes `NOTIFIER`, and each contract gets a
///          **routing table** pointing at the peer on the other chain. The
///          slashing channel has no manager here: a source chain announces, it
///          does not execute (`AVIPSlashingChannel`: a send-only chain has no
///          manager);
///        - `destination`: a subscribed subnet. The three contracts are
///          receive-only (`destinationCount() == 0`) and each gets one
///          **origin** — the peer's address on `PEER_BLOCKCHAIN_ID` — so a
///          message from anywhere else is refused (`UnauthorizedOrigin`). The
///          slashing channel is the only one with a `MANAGER`, the contract whose
///          `slash` it calls.
///
///      **The peer addresses are inputs, not predictions.** A deployment that
///      guessed the other chain's CREATE addresses would be wrong the moment the
///      other side is redeployed; §4's transport is a pair of explicit routing
///      tables for that reason. `PEER_RELAY`, `PEER_COLLUSION` and
///      `PEER_SLASHING` are therefore mandatory on both sides.
///
///      **What this script does not do.** It does not broadcast, does not pick a
///      relayer (`allowedRelayerAddresses` empty means "any", a deployment
///      decision the contracts document), does not pay a fee (`address(0)`, `0`,
///      so no token moves), and makes no liveness claim: a message that is never
///      delivered is a message that never happened.
///
///      **The Teleporter messenger.** On a live chain `TELEPORTER` is mandatory
///      and must have code — the messenger is a deployed contract, and a typo
///      here would wire the transport to an address nothing listens on. On the
///      local chain (31337) an absent `TELEPORTER` deploys
///      `MockTeleporterMessenger` inside this run, which is what makes the dry
///      run possible without pretending a local EVM has a Teleporter.
///
///      Dry run, source side (no network, no keys):
///
///        TRANSPORT_SIDE=source TELEPORTER=0x... LOCAL_BLOCKCHAIN_ID=0x... \
///        PEER_BLOCKCHAIN_ID=0x... PEER_RELAY=0x... PEER_COLLUSION=0x... \
///        PEER_SLASHING=0x... REGISTRY=0x... SEQUENCER=0x... \
///        ALERTER=0x... NOTIFIER=0x... \
///            forge script scripts/DeployTransport.s.sol:DeployTransport --offline
///
///      Fuji: add `--rpc-url "$FUJI_RPC_URL" --broadcast` and a funded
///      `DEPLOYER`. Mainnet (`43114`) reverts with `MainnetRefused`.
contract DeployTransport is DeployCommon {
    /// @notice Which half of the pair this run builds, as `TRANSPORT_SIDE`.
    string internal constant SIDE_SOURCE = "source";
    string internal constant SIDE_DESTINATION = "destination";

    /// @notice The inputs, resolved before anything is deployed. Fields the
    ///         chosen side does not use stay zero and are not read.
    struct Plan {
        address deployer;
        /// @dev `address(0)` is allowed on the local chain only, where the mock
        ///      messenger is deployed by this script.
        address teleporter;
        bytes32 localBlockchainId;
        bytes32 peerBlockchainId;
        bool source;
        address registry;
        address sequencer;
        address alerter;
        address notifier;
        address manager;
        address peerRelay;
        address peerCollusion;
        address peerSlashing;
    }

    /// @notice What the script did: the plan plus the three endpoints.
    struct Deployment {
        address deployer;
        address teleporter;
        bytes32 localBlockchainId;
        bytes32 peerBlockchainId;
        bool source;
        address relay;
        address collusion;
        address slashing;
    }

    /// @notice `TRANSPORT_SIDE` is absent or names neither `source` nor
    ///         `destination`.
    error UnknownSide(string side);

    /// @notice The local and peer chain ids are the same: a transport that sends
    ///         to itself is a routing table with one entry and no second chain.
    error SameChain(bytes32 chainId);

    /// @notice `TELEPORTER` has no code on a live chain: the messenger is a
    ///         deployed contract, and a typo would wire the transport to an
    ///         address nothing listens on.
    error TeleporterIsEOA(address teleporter);

    /// @notice CLI entry point: resolves the environment and deploys.
    function run() external returns (Deployment memory) {
        _refuseMainnet();
        return deploy(plan());
    }

    /// @notice Resolves the side, the chains, the peers and the roles that side
    ///         uses. Nothing here touches the chain.
    function plan() public view returns (Plan memory p) {
        p.deployer = _deployer();
        p.source = _side();
        p.teleporter = _roleOr("TELEPORTER", address(0));
        p.localBlockchainId = _requiredBytes32("LOCAL_BLOCKCHAIN_ID");
        p.peerBlockchainId = _requiredBytes32("PEER_BLOCKCHAIN_ID");
        p.peerRelay = _requiredRole("PEER_RELAY");
        p.peerCollusion = _requiredRole("PEER_COLLUSION");
        p.peerSlashing = _requiredRole("PEER_SLASHING");

        if (p.source) {
            p.registry = _requiredRole("REGISTRY");
            p.sequencer = _requiredRole("SEQUENCER");
            p.alerter = _requiredRole("ALERTER");
            p.notifier = _requiredRole("NOTIFIER");
        } else {
            p.manager = _requiredRole("MANAGER");
        }
    }

    /// @dev `TRANSPORT_SIDE` has no default: which half a run builds is a
    ///      decision, and a default would let a source-chain run wire a
    ///      receive-only deployment (or the reverse) without saying so.
    function _side() internal view returns (bool) {
        string memory raw;
        try vm.envString("TRANSPORT_SIDE") returns (string memory value) {
            raw = value;
        } catch {
            revert MissingRole("TRANSPORT_SIDE");
        }
        if (keccak256(bytes(raw)) == keccak256(bytes(SIDE_SOURCE))) return true;
        if (keccak256(bytes(raw)) == keccak256(bytes(SIDE_DESTINATION))) return false;
        revert UnknownSide(raw);
    }

    /// @dev A `bytes32` input with no default: `LOCAL_BLOCKCHAIN_ID` and
    ///      `PEER_BLOCKCHAIN_ID` are the transport's addressing, and a zero
    ///      would ask the endpoint to answer for a chain that does not exist.
    function _requiredBytes32(string memory name) internal view returns (bytes32 value) {
        value = _bytes32Or(name, bytes32(0));
        if (value == bytes32(0)) revert MissingRole(name);
    }

    /// @dev Deploys from an explicit plan. Every check lives here as well as in
    ///      `plan()`, so a caller that already holds a `Plan` cannot skip them.
    function deploy(Plan memory p) public returns (Deployment memory d) {
        _refuseMainnet();
        if (p.deployer == address(0)) revert MissingRole("DEPLOYER");
        if (p.localBlockchainId == bytes32(0)) revert MissingRole("LOCAL_BLOCKCHAIN_ID");
        if (p.peerBlockchainId == bytes32(0)) revert MissingRole("PEER_BLOCKCHAIN_ID");
        if (p.localBlockchainId == p.peerBlockchainId) revert SameChain(p.localBlockchainId);
        if (p.peerRelay == address(0)) revert MissingRole("PEER_RELAY");
        if (p.peerCollusion == address(0)) revert MissingRole("PEER_COLLUSION");
        if (p.peerSlashing == address(0)) revert MissingRole("PEER_SLASHING");

        if (p.source) {
            if (p.registry == address(0)) revert MissingRole("REGISTRY");
            if (p.sequencer == address(0)) revert MissingRole("SEQUENCER");
            if (p.alerter == address(0)) revert MissingRole("ALERTER");
            if (p.notifier == address(0)) revert MissingRole("NOTIFIER");
        } else if (p.manager == address(0)) {
            revert MissingRole("MANAGER");
        }

        // The public anvil keys are development keys. On a live chain they are
        // live addresses with nonces and balance, so they are refused here too,
        // not only in `plan()` (the same rule `DeployFujiPhase1` applies).
        _refuseAnvilDefault("DEPLOYER", p.deployer);
        if (p.source) {
            _refuseAnvilDefault("SEQUENCER", p.sequencer);
            _refuseAnvilDefault("ALERTER", p.alerter);
            _refuseAnvilDefault("NOTIFIER", p.notifier);
        } else {
            _refuseAnvilDefault("MANAGER", p.manager);
        }

        // The messenger is the transport's only external dependency: on a live
        // chain it must be named and must be a contract. The local chain may
        // leave it empty, and then gets the mock — the dry run's equivalent of
        // "there is no Teleporter on a local EVM".
        if (p.teleporter == address(0)) {
            if (block.chainid != LOCAL_CHAIN) revert MissingRole("TELEPORTER");
        } else if (block.chainid != LOCAL_CHAIN && p.teleporter.code.length == 0) {
            revert TeleporterIsEOA(p.teleporter);
        }

        vm.startBroadcast(p.deployer);
        address teleporter = p.teleporter;
        if (teleporter == address(0)) teleporter = address(new MockTeleporterMessenger());

        AVIPMessageEndpoint.Origin[] memory noOrigins = new AVIPMessageEndpoint.Origin[](0);
        AVIPMessageEndpoint.Destination[] memory noDestinations =
            new AVIPMessageEndpoint.Destination[](0);
        AVIPMessageEndpoint.Origin[] memory origins = new AVIPMessageEndpoint.Origin[](1);
        AVIPMessageEndpoint.Destination[] memory destinations =
            new AVIPMessageEndpoint.Destination[](1);

        address relay;
        address collusion;
        address slashing;
        if (p.source) {
            destinations[0] = AVIPMessageEndpoint.Destination(p.peerBlockchainId, p.peerRelay);
            relay = address(
                new AVIPCommitmentRelay(
                    teleporter,
                    p.localBlockchainId,
                    p.registry,
                    p.sequencer,
                    noOrigins,
                    destinations
                )
            );
            destinations[0] = AVIPMessageEndpoint.Destination(p.peerBlockchainId, p.peerCollusion);
            collusion = address(
                new AVIPCollusionAlertChannel(
                    teleporter, p.localBlockchainId, p.alerter, noOrigins, destinations
                )
            );
            destinations[0] = AVIPMessageEndpoint.Destination(p.peerBlockchainId, p.peerSlashing);
            slashing = address(
                new AVIPSlashingChannel(
                    teleporter, p.localBlockchainId, p.notifier, address(0), noOrigins, destinations
                )
            );
        } else {
            origins[0] = AVIPMessageEndpoint.Origin(
                AVIPMessageCodec.KIND_COMMITMENT_PROPAGATION, p.peerBlockchainId, p.peerRelay
            );
            relay = address(
                new AVIPCommitmentRelay(
                    teleporter, p.localBlockchainId, address(0), address(0), origins, noDestinations
                )
            );
            origins[0] = AVIPMessageEndpoint.Origin(
                AVIPMessageCodec.KIND_COLLUSION_ALERT, p.peerBlockchainId, p.peerCollusion
            );
            collusion = address(
                new AVIPCollusionAlertChannel(
                    teleporter, p.localBlockchainId, address(0), origins, noDestinations
                )
            );
            origins[0] = AVIPMessageEndpoint.Origin(
                AVIPMessageCodec.KIND_SLASHING_NOTIFICATION, p.peerBlockchainId, p.peerSlashing
            );
            slashing = address(
                new AVIPSlashingChannel(
                    teleporter, p.localBlockchainId, address(0), p.manager, origins, noDestinations
                )
            );
        }
        vm.stopBroadcast();

        d = Deployment({
            deployer: p.deployer,
            teleporter: teleporter,
            localBlockchainId: p.localBlockchainId,
            peerBlockchainId: p.peerBlockchainId,
            source: p.source,
            relay: relay,
            collusion: collusion,
            slashing: slashing
        });

        _checkWiring(p, d);
        _report(d);
    }

    /// @dev Reads the wiring back from the three instances. `kind()` and the
    ///      messenger are what the constructor decided; `destinationAt` and
    ///      `originOf` are the two halves of §4's routing table, and they are
    ///      read on the side that owns them: a source chain has destinations and
    ///      no origins, a destination chain the reverse.
    function _checkWiring(Plan memory p, Deployment memory d) internal view {
        AVIPMessageEndpoint relay = AVIPMessageEndpoint(d.relay);
        AVIPMessageEndpoint collusion = AVIPMessageEndpoint(d.collusion);
        AVIPMessageEndpoint slashing = AVIPMessageEndpoint(d.slashing);

        _assertEq("relay.kind", AVIPMessageCodec.KIND_COMMITMENT_PROPAGATION, relay.kind());
        _assertEq("collusion.kind", AVIPMessageCodec.KIND_COLLUSION_ALERT, collusion.kind());
        _assertEq("slashing.kind", AVIPMessageCodec.KIND_SLASHING_NOTIFICATION, slashing.kind());

        _assertAddressEq("relay.teleporter", d.teleporter, address(relay.teleporter()));
        _assertAddressEq("collusion.teleporter", d.teleporter, address(collusion.teleporter()));
        _assertAddressEq("slashing.teleporter", d.teleporter, address(slashing.teleporter()));

        _assertEq(
            "relay.localChain", uint256(d.localBlockchainId), uint256(relay.localBlockchainId())
        );
        _assertEq(
            "collusion.localChain",
            uint256(d.localBlockchainId),
            uint256(collusion.localBlockchainId())
        );
        _assertEq(
            "slashing.localChain",
            uint256(d.localBlockchainId),
            uint256(slashing.localBlockchainId())
        );

        if (d.source) {
            _assertEq("relay.destinations", 1, relay.destinationCount());
            _assertEq("collusion.destinations", 1, collusion.destinationCount());
            _assertEq("slashing.destinations", 1, slashing.destinationCount());

            AVIPMessageEndpoint.Destination memory rd = relay.destinationAt(0);
            _assertEq(
                "relay.destination.chain", uint256(d.peerBlockchainId), uint256(rd.blockchainId)
            );
            _assertAddressEq("relay.destination.receiver", p.peerRelay, rd.receiver);

            AVIPMessageEndpoint.Destination memory cd = collusion.destinationAt(0);
            _assertEq(
                "collusion.destination.chain", uint256(d.peerBlockchainId), uint256(cd.blockchainId)
            );
            _assertAddressEq("collusion.destination.receiver", p.peerCollusion, cd.receiver);

            AVIPMessageEndpoint.Destination memory sd = slashing.destinationAt(0);
            _assertEq(
                "slashing.destination.chain", uint256(d.peerBlockchainId), uint256(sd.blockchainId)
            );
            _assertAddressEq("slashing.destination.receiver", p.peerSlashing, sd.receiver);

            // The other half of "one contract answers for one kind": a source
            // deployment accepts nothing, because it has no origin entry.
            _assertAddressEq(
                "relay.origin",
                address(0),
                relay.originOf(AVIPMessageCodec.KIND_COMMITMENT_PROPAGATION, d.peerBlockchainId)
            );
            _assertAddressEq(
                "collusion.origin",
                address(0),
                collusion.originOf(AVIPMessageCodec.KIND_COLLUSION_ALERT, d.peerBlockchainId)
            );
            _assertAddressEq(
                "slashing.origin",
                address(0),
                slashing.originOf(AVIPMessageCodec.KIND_SLASHING_NOTIFICATION, d.peerBlockchainId)
            );
        } else {
            _assertEq("relay.destinations", 0, relay.destinationCount());
            _assertEq("collusion.destinations", 0, collusion.destinationCount());
            _assertEq("slashing.destinations", 0, slashing.destinationCount());

            _assertAddressEq(
                "relay.origin",
                p.peerRelay,
                relay.originOf(AVIPMessageCodec.KIND_COMMITMENT_PROPAGATION, d.peerBlockchainId)
            );
            _assertAddressEq(
                "collusion.origin",
                p.peerCollusion,
                collusion.originOf(AVIPMessageCodec.KIND_COLLUSION_ALERT, d.peerBlockchainId)
            );
            _assertAddressEq(
                "slashing.origin",
                p.peerSlashing,
                slashing.originOf(AVIPMessageCodec.KIND_SLASHING_NOTIFICATION, d.peerBlockchainId)
            );
        }
    }

    function _report(Deployment memory d) internal view {
        _logHeader("DeployTransport", d.deployer);
        _log("side", d.source ? SIDE_SOURCE : SIDE_DESTINATION);
        _logAddress("teleporter", d.teleporter);
        _logBytes32("localBlockchainId", d.localBlockchainId);
        _logBytes32("peerBlockchainId", d.peerBlockchainId);
        _logAddress("AVIPCommitmentRelay", d.relay);
        _logAddress("AVIPCollusionAlertChannel", d.collusion);
        _logAddress("AVIPSlashingChannel", d.slashing);
        _log("status", "ok");
    }

    /// @dev Its own tag: the dry run filters by tag, so `[m7a]` would
    ///      misattribute the three endpoints to the registry script. `[m7d]` is
    ///      shared with `M7dReport`, which runs in a separate process and whose
    ///      transcript is pinned separately; no line of one is compared with the
    ///      other.
    function _log(string memory key, string memory value) internal pure override {
        console2.log(string.concat("[m7d] ", key, "=", value));
    }
}

