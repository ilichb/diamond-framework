// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/console2.sol";
import {Vm} from "forge-std/Vm.sol";
import {DeployCommon} from "./DeployCommon.sol";
import {AVIPMessageCodec} from "../contracts/AVIPMessageCodec.sol";
import {AVIPMessageEndpoint} from "../contracts/AVIPMessageEndpoint.sol";
import {AVIPCommitmentRelay} from "../contracts/AVIPCommitmentRelay.sol";
import {AVIPCollusionAlertChannel} from "../contracts/AVIPCollusionAlertChannel.sol";
import {AVIPSlashingChannel} from "../contracts/AVIPSlashingChannel.sol";
import {AVIPRegistry} from "../contracts/AVIPRegistry.sol";
import {AVIPValidatorManager} from "../contracts/AVIPValidatorManager.sol";
import {IAVIPValidatorManager} from "../contracts/interfaces/IAVIPValidatorManager.sol";
import {Groth16Verifier} from "../contracts/verifiers/Groth16Verifier.sol";
import {MockTeleporterMessenger} from "../test/mocks/MockTeleporterMessenger.sol";
import {M4dGroth16Fixtures as F4d} from "../test/fixtures/M4dGroth16Fixtures.sol";
import {M7cBridgeFixtures as F7c} from "../test/fixtures/M7cBridgeFixtures.sol";
import {M7dProvenanceFixtures as F7d} from "../test/fixtures/M7dProvenanceFixtures.sol";

/// @title M7dReport
/// @notice The one documented command of M7d: it wires the three AVIP message types of
///         `docs/architecture/avalanche-integration.md` §4 across two chain ids, runs
///         each type end to end, and prints one machine-readable line per fact —
///         including the line per *refusal*.
///
/// @dev Milestone M7d of `docs/architecture/implementation-plan.md` §5.11 (gap A9).
///      `scripts/m7d_report.sh` runs this script and pins its `[m7d]` lines to
///      `scripts/m7d_output.txt`, then checks the numbers against the transcripts of
///      the milestones they come from (M5's calibration, M7b's adjudicated fraud, M7c's
///      link) in both directions.
///
///      **Nothing is broadcast and nothing is live.** `forge script` without
///      `--broadcast` simulates locally, so no RPC endpoint is touched, no key is used
///      and no funds exist. The messenger is
///      `../test/mocks/MockTeleporterMessenger.sol` — a routing table with synchronous
///      delivery — because there is no Teleporter on a local EVM and M7d deliberately
///      does not pretend otherwise: the claims are about the *wire format* and the
///      endpoints' own decisions, and every line below is reproducible byte for byte.
///
///      **The addresses are this script's own CREATEs**, not a network's. They repeat
///      from run to run (a fresh EVM, the same order) and must not be presented as Fuji
///      addresses: the Fuji deployment is A8's remaining half, with a funded key and a
///      real Teleporter address, and this milestone does not automate it.
///
///      **The roles are the first four `anvil` accounts, hard-coded.** This script is
///      not a deployment, so it has no environment to read: the environment → plan
///      mapping is asserted by `deploy_dryrun.sh` for the M7a scripts, and the *wire* is
///      what is under test here. What it does inherit from `DeployCommon` is the one
///      rule no script may forget — C-Chain mainnet is refused before anything else
///      happens.
contract M7dReport is DeployCommon {
    /// @dev The two chain ids of the report: the chain whose registry commits (the
    ///      C-Chain of `avalanche-integration.md` §6 phase 1) and a subscribed subnet.
    bytes32 internal constant CHAIN_SOURCE = bytes32(uint256(0xA11CE));
    bytes32 internal constant CHAIN_DESTINATION = bytes32(uint256(0xB0B));

    /// @dev `C·D·H` of the committed fixture tensor.
    uint32 internal constant N = 500;

    /// @dev The four roles, as `anvil` accounts 0-3: four public, valueless addresses,
    ///      which is what makes "these are four different roles" visible in the
    ///      transcript rather than assumed.
    address internal constant SEQUENCER = ANVIL_0;
    /// @dev M9a: the registry's only proposer of a role change. Never the
    ///      sequencer above, which is what §12.1.2 requires of the pair.
    address internal constant GUARDIAN = ANVIL_3;
    address internal constant ALERTER = ANVIL_1;
    address internal constant NOTIFIER = ANVIL_2;
    address internal constant VALIDATOR = address(uint160(F4d.STATEMENT_VALIDATOR));

    /// @dev The stake the validator declares: a choice of this *run* (the manager
    ///      takes that record in full), not a constant of the paper — M7b's
    ///      `S_slash = 10` is a model parameter, and since M9b no amount is
    ///      transported for it to bound.
    uint256 internal constant STAKE_WAD = 1e18;

    MockTeleporterMessenger internal teleporter;
    Groth16Verifier internal verifier;
    AVIPRegistry internal registryForAdmission;
    AVIPRegistry internal registryForCommitment;
    AVIPValidatorManager internal manager;
    AVIPCommitmentRelay internal relaySource;
    AVIPCommitmentRelay internal relayDestination;
    AVIPCollusionAlertChannel internal alertSource;
    AVIPCollusionAlertChannel internal alertDestination;
    AVIPSlashingChannel internal slashingSource;
    AVIPSlashingChannel internal slashingDestination;

    /// @dev How many refusals the report exercised. Printed as one line, so a section
    ///      that stops refusing anything is visible in the transcript itself.
    uint256 internal _rejections;

    function run() external {
        // The M7a floor, first: a script that can be pointed at the chain holding real
        // value is a hazard, and this one creates state.
        _refuseMainnet();

        // A script contract's own address must not be relied on (forge refuses
        // `address(this)` in a script for exactly that reason), so the deployments are
        // broadcast from `DEPLOYER` — an `anvil` account by default — and the predictions
        // are that account's CREATE nonces. Nothing leaves the process: without
        // `--broadcast` this is a local simulation, and `--offline` keeps it hermetic.
        address deployer = _deployer();
        vm.startBroadcast(deployer);
        address relayDestinationAddress = _predictDeployment(deployer, 6);
        address alertDestinationAddress = _predictDeployment(deployer, 8);
        address slashingDestinationAddress = _predictDeployment(deployer, 10);

        teleporter = new MockTeleporterMessenger();
        verifier = new Groth16Verifier(F4d.verifyingKey());
        registryForAdmission = new AVIPRegistry(SEQUENCER, address(verifier), GUARDIAN);
        registryForCommitment = new AVIPRegistry(SEQUENCER, address(verifier), GUARDIAN);
        manager = new AVIPValidatorManager(
            address(registryForAdmission), slashingDestinationAddress, address(0)
        );

        relaySource = new AVIPCommitmentRelay(
            address(teleporter),
            CHAIN_SOURCE,
            address(registryForCommitment),
            SEQUENCER,
            _noOrigins(),
            _destination(CHAIN_DESTINATION, relayDestinationAddress)
        );
        relayDestination = new AVIPCommitmentRelay(
            address(teleporter),
            CHAIN_DESTINATION,
            address(0),
            address(0),
            _origin(
                AVIPMessageCodec.KIND_COMMITMENT_PROPAGATION, CHAIN_SOURCE, address(relaySource)
            ),
            _noDestinations()
        );
        alertSource = new AVIPCollusionAlertChannel(
            address(teleporter),
            CHAIN_SOURCE,
            ALERTER,
            _noOrigins(),
            _destination(CHAIN_DESTINATION, alertDestinationAddress)
        );
        alertDestination = new AVIPCollusionAlertChannel(
            address(teleporter),
            CHAIN_DESTINATION,
            address(0),
            _origin(AVIPMessageCodec.KIND_COLLUSION_ALERT, CHAIN_SOURCE, address(alertSource)),
            _noDestinations()
        );
        slashingSource = new AVIPSlashingChannel(
            address(teleporter),
            CHAIN_SOURCE,
            NOTIFIER,
            address(0),
            _noOrigins(),
            _destination(CHAIN_DESTINATION, slashingDestinationAddress)
        );
        slashingDestination = new AVIPSlashingChannel(
            address(teleporter),
            CHAIN_DESTINATION,
            address(0),
            address(manager),
            _origin(
                AVIPMessageCodec.KIND_SLASHING_NOTIFICATION, CHAIN_SOURCE, address(slashingSource)
            ),
            _noDestinations()
        );

        _assertAddressEq("relayDestination", relayDestinationAddress, address(relayDestination));
        _assertAddressEq("alertDestination", alertDestinationAddress, address(alertDestination));
        _assertAddressEq(
            "slashingDestination", slashingDestinationAddress, address(slashingDestination)
        );

        teleporter.registerEndpoint(address(relaySource), CHAIN_SOURCE);
        teleporter.registerEndpoint(address(relayDestination), CHAIN_DESTINATION);
        teleporter.registerEndpoint(address(alertSource), CHAIN_SOURCE);
        teleporter.registerEndpoint(address(alertDestination), CHAIN_DESTINATION);
        teleporter.registerEndpoint(address(slashingSource), CHAIN_SOURCE);
        teleporter.registerEndpoint(address(slashingDestination), CHAIN_DESTINATION);
        vm.stopBroadcast();

        // The three endpoint pairs are mutually referential (a source's routing table
        // names its destination and the destination's allowlist names the source), and so
        // are the manager and the executor; both sides are constructor-fixed, which is why
        // the three addresses above were predicted and then checked the moment the
        // contracts existed. From here on the report only *calls* things, as the roles:
        // the broadcast above was the deployment, and this half is the wire.

        // Genesis at M1's own fold over the fixture tensor (M7c's Merkle root), then one
        // more epoch so the report can show that arrival order does not decide what is
        // recorded. The admission registry is separate on purpose: M4d's proof is bound
        // to the per-epoch statement root, and only M7c's link ties that root to the
        // fold — the gap §5.10 closed.
        _commit(0, F7c.MERKLE_ROOT, N);
        _commit(1, bytes32(uint256(F7c.MERKLE_ROOT) ^ 1), 7);

        _wiring();
        _commitmentPropagation();
        _collusionAlert();
        _slashingNotification();

        _m7d("reject.count", vm.toString(_rejections));
        _m7d("status", "ok");
    }

    // ---------------------------------------------------------------- the wiring

    /// @dev One line per fact a reader needs for the rest, plus the check that makes the
    ///      report answerable to M7c: the link is recomputed by the *contract* from the
    ///      two roots and the epoch, and compared with the value M7c's transcript
    ///      publishes.
    function _wiring() internal {
        _m7d("chain.source", vm.toString(CHAIN_SOURCE));
        _m7d("chain.destination", vm.toString(CHAIN_DESTINATION));
        _m7d("endpoint.relay.source", vm.toString(address(relaySource)));
        _m7d("endpoint.relay.destination", vm.toString(address(relayDestination)));
        _m7d("endpoint.alert.source", vm.toString(address(alertSource)));
        _m7d("endpoint.alert.destination", vm.toString(address(alertDestination)));
        _m7d("endpoint.slashing.source", vm.toString(address(slashingSource)));
        _m7d("endpoint.slashing.destination", vm.toString(address(slashingDestination)));
        _m7d(
            "kind.commitment.propagation",
            vm.toString(uint256(AVIPMessageCodec.KIND_COMMITMENT_PROPAGATION))
        );
        _m7d("kind.collusion.alert", vm.toString(uint256(AVIPMessageCodec.KIND_COLLUSION_ALERT)));
        _m7d(
            "kind.slashing.notification",
            vm.toString(uint256(AVIPMessageCodec.KIND_SLASHING_NOTIFICATION))
        );
        _m7d("wiring.destinations.relay", vm.toString(relaySource.destinationCount()));
        _m7d(
            "wiring.origins.relay",
            vm.toString(
                relayDestination.originOf(
                    AVIPMessageCodec.KIND_COMMITMENT_PROPAGATION, CHAIN_SOURCE
                )
            )
        );

        bytes32 recomputed =
            AVIPMessageCodec.linkDigest(F7c.MERKLE_ROOT, F7c.STATEMENT_ROOT, F7c.EPOCH);
        _m7d("link.recomputed", vm.toString(recomputed));
        _m7d("link.declared", vm.toString(F7c.LINK));
        require(recomputed == F7c.LINK, "M7dReport: the contract's link is not M7c's");
    }

    // --------------------------------------- type 1: commitment propagation (§4)

    function _commitmentPropagation() internal {
        vm.prank(SEQUENCER);
        bytes32[] memory ids = relaySource.publish(F7c.EPOCH, F7c.STATEMENT_ROOT, F7c.LINK);
        MockTeleporterMessenger.Routed memory routed = teleporter.routedMessage(ids[0]);

        _m7d("commit.epoch", vm.toString(F7c.EPOCH));
        _m7d("commit.merkleRoot", vm.toString(F7c.MERKLE_ROOT));
        _m7d("commit.statementRoot", vm.toString(F7c.STATEMENT_ROOT));
        _m7d("commit.link", vm.toString(F7c.LINK));
        _m7d("commit.changedEntries", vm.toString(uint256(N)));
        _m7d("commit.sourceChain", vm.toString(routed.sourceBlockchainId));
        _m7d("commit.origin", vm.toString(routed.originSenderAddress));

        AVIPCommitmentRelay.Propagated memory record =
            relayDestination.propagatedOf(CHAIN_SOURCE, F7c.EPOCH);
        _m7d("record.merkleRoot", vm.toString(record.merkleRoot));
        _m7d("record.link", vm.toString(record.link));
        _m7d("record.changedEntries", vm.toString(uint256(record.changedEntries)));
        _m7d("record.latestEpoch", vm.toString(relayDestination.latestEpochOf(CHAIN_SOURCE)));
        _m7d("record.delivered", vm.toString(relayDestination.deliveredMessages()));

        // What was recorded is the registry's own root, not a value the sender chose.
        require(
            record.merkleRoot == registryForCommitment.commitmentOf(F7c.EPOCH)
                && record.link == F7c.LINK && record.statementRoot == F7c.STATEMENT_ROOT,
            "M7dReport: the record is not the announcement"
        );

        bytes memory committed = _committedMessage();

        vm.prank(SEQUENCER);
        try relaySource.publish(9, F7c.STATEMENT_ROOT, F7c.LINK) {
            revert("M7dReport: an uncommitted epoch was announced");
        } catch (bytes memory reason) {
            _reject("uncommittedEpoch", reason);
        }

        vm.prank(SEQUENCER);
        try relaySource.publish(F7c.EPOCH, F7c.STATEMENT_ROOT, bytes32(uint256(F7c.LINK) ^ 1)) {
            revert("M7dReport: a link that does not tie its words was announced");
        } catch (bytes memory reason) {
            _reject("lyingLink", reason);
        }

        vm.prank(NOTIFIER);
        try relaySource.publish(1, F7c.STATEMENT_ROOT, F7c.LINK) {
            revert("M7dReport: a caller other than the sequencer announced");
        } catch (bytes memory reason) {
            _reject("notTheSequencer", reason);
        }

        // The refusals on arrival are driven the way a solver would: as the messenger.
        vm.prank(address(teleporter));
        try relayDestination.receiveTeleporterMessage(
            CHAIN_DESTINATION, address(relaySource), committed
        ) {
            revert("M7dReport: an unlisted source chain delivered");
        } catch (bytes memory reason) {
            _reject("unknownOrigin", reason);
        }

        vm.prank(address(teleporter));
        try relayDestination.receiveTeleporterMessage(CHAIN_SOURCE, NOTIFIER, committed) {
            revert("M7dReport: an unlisted sender on a listed chain delivered");
        } catch (bytes memory reason) {
            _reject("unauthorizedOrigin", reason);
        }

        vm.prank(address(teleporter));
        try relayDestination.receiveTeleporterMessage(
            CHAIN_SOURCE, address(relaySource), _alertMessage()
        ) {
            revert("M7dReport: a message of another kind was accepted");
        } catch (bytes memory reason) {
            _reject("wrongKind", reason);
        }

        vm.prank(address(teleporter));
        try relayDestination.receiveTeleporterMessage(
            CHAIN_SOURCE, address(relaySource), committed
        ) {
            revert("M7dReport: a message was delivered twice");
        } catch (bytes memory reason) {
            _reject("replay", reason);
        }

        vm.prank(SEQUENCER);
        try relaySource.publish(F7c.EPOCH, F7c.STATEMENT_ROOT, F7c.LINK) {
            revert("M7dReport: a recorded epoch was rewritten");
        } catch (bytes memory reason) {
            _reject("epochRewrite", reason);
        }
    }

    // -------------------------------------------- type 2: collusion alert (§4)

    function _collusionAlert() internal {
        AVIPMessageCodec.CollusionAlert memory alert = _m5Alert();

        vm.prank(ALERTER);
        alertSource.raise(alert);

        AVIPCollusionAlertChannel.Flag memory flag = alertDestination.flagOf(CHAIN_SOURCE, 0);
        _m7d("alert.epoch", vm.toString(flag.epoch));
        _m7d("alert.n", vm.toString(uint256(flag.nodeCount)));
        _m7d("alert.q99.right", vm.toString(uint256(flag.rightThresholdQ)));
        _m7d("alert.q99.left", vm.toString(uint256(flag.leftThresholdQ)));
        _m7d("alert.graphDigest", vm.toString(flag.graphDigest));
        _m7d("alert.right", flag.rightAlert ? "true" : "false");
        _m7d("alert.left", flag.leftAlert ? "true" : "false");
        _m7d("flag.count", vm.toString(alertDestination.flagCount()));

        // The graph the alert points at is the tensor M5 draws from, so the three
        // milestones that touch this tensor name the same digest.
        require(
            flag.graphDigest == F7c.TENSOR_DIGEST && flag.rightAlert && !flag.leftAlert,
            "M7dReport: the flag is not the verdict"
        );

        AVIPMessageCodec.CollusionAlert memory quiet = alert;
        quiet.rightAlert = false;
        vm.prank(ALERTER);
        try alertSource.raise(quiet) {
            revert("M7dReport: a quiet verdict was raised");
        } catch (bytes memory reason) {
            _reject("quietAlert", reason);
        }

        vm.prank(NOTIFIER);
        try alertSource.raise(alert) {
            revert("M7dReport: a caller other than the alerter raised");
        } catch (bytes memory reason) {
            _reject("notTheAlerter", reason);
        }

        AVIPMessageCodec.CollusionAlert memory retraction = alert;
        retraction.rightAlert = false;
        retraction.leftAlert = true;
        vm.prank(ALERTER);
        try alertSource.raise(retraction) {
            revert("M7dReport: a recorded flag was rewritten");
        } catch (bytes memory reason) {
            _reject("flagRewrite", reason);
        }
    }

    // ------------------------------------- type 3: slashing notification (§4)

    function _slashingNotification() internal {
        // M4d's real admission proof, against the registry state it was made for: the same
        // recipe `test/M4dRealKey.t.sol` uses, unchanged.
        vm.prank(SEQUENCER);
        registryForAdmission.postCommitment(0, keccak256("tensor"), F4d.STATEMENT_ROOT, N);
        vm.prank(VALIDATOR);
        manager.admit(VALIDATOR, STAKE_WAD, F4d.STATEMENT_NORM, F4d.proof());
        _m7d("admit.validator", vm.toString(VALIDATOR));
        _m7d("admit.stake", vm.toString(manager.stakeOf(VALIDATOR)));
        _m7d("admit.certifiedNorm", vm.toString(F4d.STATEMENT_NORM));

        AVIPMessageCodec.SlashingNotification memory notification = _m7bNotification();

        // The manager's own event is the end of the chain: `ValidatorSlashed(address
        // indexed, uint256, bytes32)` carries the reason M8 will audit.
        vm.recordLogs();
        vm.prank(NOTIFIER);
        slashingSource.notify(notification);
        bytes32 logged = _reasonFromLogs(vm.getRecordedLogs());

        bytes32 reason = AVIPMessageCodec.provenanceId(CHAIN_SOURCE, 0);
        _m7d("notify.publishedWad", vm.toString(notification.publishedWad));
        _m7d("notify.formulaWad", vm.toString(notification.formulaWad));
        _m7d("notify.ingestionDigest", vm.toString(notification.ingestionDigest));
        _m7d("slash.reason", vm.toString(reason));
        _m7d("slash.managerEvent.reason", vm.toString(logged));
        _m7d("slash.stakeAfter", vm.toString(manager.stakeOf(VALIDATOR)));
        _m7d("slash.requiredStake", vm.toString(manager.requiredStake(VALIDATOR)));
        _m7d("slash.admitted", manager.isAdmitted(VALIDATOR) ? "true" : "false");
        _m7d("slash.executed", vm.toString(slashingDestination.executedSlashes()));

        require(
            logged == reason && slashingDestination.reasonOf(CHAIN_SOURCE, 0) == reason,
            "M7dReport: the manager saw a different reason"
        );
        require(
            manager.stakeOf(VALIDATOR) == 0 && !manager.isAdmitted(VALIDATOR),
            "M7dReport: the whole record was not taken"
        );

        vm.prank(NOTIFIER);
        try slashingSource.notify(notification) {
            revert("M7dReport: the second notification found something to take");
        } catch (bytes memory reasonData) {
            _reject("nothingToSlash", reasonData);
        }

        vm.prank(SEQUENCER);
        try slashingSource.notify(notification) {
            revert("M7dReport: a caller other than the notifier notified");
        } catch (bytes memory reasonData) {
            _reject("notTheNotifier", reasonData);
        }
    }

    // --------------------------------------------------------------- the helpers

    /// @dev The address the `offset`-th `new` of `run` will land on. `run` deploys, in
    ///      order: 0 messenger · 1 verifier · 2 admission registry · 3 commitment
    ///      registry · 4 manager · 5 relaySource · 6 relayDestination · 7 alertSource ·
    ///      8 alertDestination · 9 slashingSource · 10 slashingDestination. The three
    ///      predictions are the offsets 6, 8 and 10, and each is asserted in `run`.
    function _predictDeployment(address deployer, uint256 offset) internal view returns (address) {
        return vm.computeCreateAddress(deployer, vm.getNonce(deployer) + offset);
    }

    function _origin(uint8 kind, bytes32 sourceChainId, address sender)
        internal
        pure
        returns (AVIPMessageEndpoint.Origin[] memory list)
    {
        list = new AVIPMessageEndpoint.Origin[](1);
        list[0] = AVIPMessageEndpoint.Origin({
            kind: kind, sourceBlockchainId: sourceChainId, originSenderAddress: sender
        });
    }

    function _noOrigins() internal pure returns (AVIPMessageEndpoint.Origin[] memory) {
        return new AVIPMessageEndpoint.Origin[](0);
    }

    function _destination(bytes32 chainId, address receiver)
        internal
        pure
        returns (AVIPMessageEndpoint.Destination[] memory list)
    {
        list = new AVIPMessageEndpoint.Destination[](1);
        list[0] = AVIPMessageEndpoint.Destination({blockchainId: chainId, receiver: receiver});
    }

    function _noDestinations() internal pure returns (AVIPMessageEndpoint.Destination[] memory) {
        return new AVIPMessageEndpoint.Destination[](0);
    }

    function _commit(uint256 epoch, bytes32 root, uint32 changedEntries) internal {
        vm.prank(SEQUENCER);
        registryForCommitment.postCommitment(epoch, root, uint256(root), changedEntries);
    }

    /// @dev M7c's commitment as a wire message, built exactly as
    ///      `AVIPCommitmentRelay.publish` builds it, so the replay and lying-link rows
    ///      exercise the receiver's own checks rather than a differently shaped message.
    function _committedMessage() internal pure returns (bytes memory) {
        return AVIPMessageCodec.encode(
            AVIPMessageCodec.KIND_COMMITMENT_PROPAGATION,
            0,
            AVIPMessageCodec.encodeCommitment(
                AVIPMessageCodec.CommitmentPropagation({
                    epoch: F7c.EPOCH,
                    merkleRoot: F7c.MERKLE_ROOT,
                    changedEntries: N,
                    statementRoot: F7c.STATEMENT_ROOT,
                    link: F7c.LINK
                })
            )
        );
    }

    function _alertMessage() internal pure returns (bytes memory) {
        return AVIPMessageCodec.encode(
            AVIPMessageCodec.KIND_COLLUSION_ALERT, 0, AVIPMessageCodec.encodeAlert(_m5Alert())
        );
    }

    /// @dev M5's verdict: a right-tail flag at the sealed `alpha = 0.01` calibration, on
    ///      the graph M5 seeds from the tensor digest.
    function _m5Alert() internal pure returns (AVIPMessageCodec.CollusionAlert memory) {
        return AVIPMessageCodec.CollusionAlert({
            epoch: F7d.M7B_EPOCH,
            nodeCount: F7d.M5_NODE_COUNT,
            rightThresholdQ: F7d.M5_RIGHT_THRESHOLD_Q,
            leftThresholdQ: F7d.M5_LEFT_THRESHOLD_Q,
            graphDigest: F7c.TENSOR_DIGEST,
            rightAlert: true,
            leftAlert: false
        });
    }

    /// @dev M7b's adjudicated fraud, as the data layer would notify it.
    function _m7bNotification()
        internal
        pure
        returns (AVIPMessageCodec.SlashingNotification memory)
    {
        return AVIPMessageCodec.SlashingNotification({
                validator: VALIDATOR,
                epoch: F7d.M7B_EPOCH,
                ingestionDigest: F7d.M7B_INGESTION_DIGEST,
                publishedWad: F7d.M7B_PUBLISHED_WAD,
                formulaWad: F7d.M7B_FORMULA_WAD
            });
    }

    /// @dev The `reason` the manager's `ValidatorSlashed(validator, amount, reason)` event
    ///      carried, read back out of the logs: the event's data is `(uint256, bytes32)`
    ///      and its first topic is the indexed validator.
    function _reasonFromLogs(Vm.Log[] memory logs) internal pure returns (bytes32) {
        bytes32 signature = keccak256("ValidatorSlashed(address,uint256,bytes32)");
        for (uint256 i = 0; i < logs.length; ++i) {
            if (logs[i].topics.length == 2 && logs[i].topics[0] == signature) {
                (, bytes32 reason) = abi.decode(logs[i].data, (uint256, bytes32));
                return reason;
            }
        }
        revert("M7dReport: the manager did not emit ValidatorSlashed");
    }

    // ------------------------------------------------------ the transcript helpers

    /// @dev One machine-readable line per fact, so `m7d_report.sh` can pin the transcript
    ///      without pinning gas or timings. The prefix is this script's own: `[m7a]` is
    ///      `deploy_dryrun.sh`'s, and the two must not be able to absorb each other's
    ///      lines.
    function _m7d(string memory key, string memory value) internal pure {
        console2.log(string.concat("[m7d] ", key, "=", value));
    }

    /// @dev One refusal row. `reason.length == 0` means the call did *not* revert, which
    ///      is a failure of the report rather than a row: the whole point of these
    ///      sections is that the call is refused.
    function _reject(string memory key, bytes memory reason) internal {
        require(reason.length >= 4, "M7dReport: an expected refusal did not happen");
        _rejections += 1;
        // The first four bytes of revert data are the error's selector (that is what the
        // ABI says), and `reason.length >= 4` is checked above.
        // forge-lint: disable-next-line(unsafe-typecast)
        bytes4 selector = bytes4(reason);
        _m7d(string.concat("reject.", key), _errorName(selector));
    }

    /// @dev The name of the error a revert's data names, or the raw selector. Mapping
    ///      selectors back to names is what makes the transcript readable without an ABI
    ///      decoder; an unmapped one prints as `unknown(0x…)` and is visible rather than
    ///      silent.
    function _errorName(bytes4 selector) internal pure returns (string memory) {
        if (selector == AVIPMessageCodec.UnknownMessageKind.selector) return "UnknownMessageKind";
        if (selector == AVIPMessageCodec.NonCanonicalMessage.selector) {
            return "NonCanonicalMessage";
        }
        if (selector == AVIPMessageCodec.EmptyMessage.selector) return "EmptyMessage";
        if (selector == AVIPMessageCodec.EmptyPayload.selector) return "EmptyPayload";
        if (selector == AVIPMessageCodec.EmptyMerkleRoot.selector) return "EmptyMerkleRoot";
        if (selector == AVIPMessageCodec.LinkMismatch.selector) return "LinkMismatch";
        if (selector == AVIPMessageCodec.EmptyGraphDigest.selector) return "EmptyGraphDigest";
        if (selector == AVIPMessageCodec.QuietAlert.selector) return "QuietAlert";
        if (selector == AVIPMessageCodec.EmptyValidator.selector) return "EmptyValidator";
        if (selector == AVIPMessageCodec.EmptyIngestionDigest.selector) {
            return "EmptyIngestionDigest";
        }
        if (selector == AVIPMessageCodec.NotAFraudProof.selector) return "NotAFraudProof";
        if (selector == AVIPMessageEndpoint.NotTeleporter.selector) return "NotTeleporter";
        if (selector == AVIPMessageEndpoint.UnexpectedMessageKind.selector) {
            return "UnexpectedMessageKind";
        }
        if (selector == AVIPMessageEndpoint.UnknownOrigin.selector) return "UnknownOrigin";
        if (selector == AVIPMessageEndpoint.UnauthorizedOrigin.selector) {
            return "UnauthorizedOrigin";
        }
        if (selector == AVIPMessageEndpoint.MessageAlreadyDelivered.selector) {
            return "MessageAlreadyDelivered";
        }
        if (selector == AVIPMessageEndpoint.EmptyConfiguration.selector) {
            return "EmptyConfiguration";
        }
        if (selector == AVIPMessageEndpoint.ForeignOriginKind.selector) return "ForeignOriginKind";
        if (selector == AVIPMessageEndpoint.NoDestination.selector) return "NoDestination";
        if (selector == AVIPCommitmentRelay.NotSequencer.selector) return "NotSequencer";
        if (selector == AVIPCommitmentRelay.RegistryNotConfigured.selector) {
            return "RegistryNotConfigured";
        }
        if (selector == AVIPCommitmentRelay.UncommittedEpoch.selector) return "UncommittedEpoch";
        if (selector == AVIPCommitmentRelay.PartialConfiguration.selector) {
            return "PartialConfiguration";
        }
        if (selector == AVIPCommitmentRelay.EpochAlreadyPropagated.selector) {
            return "EpochAlreadyPropagated";
        }
        if (selector == AVIPCollusionAlertChannel.NotAlerter.selector) return "NotAlerter";
        if (selector == AVIPCollusionAlertChannel.AlerterNotConfigured.selector) {
            return "AlerterNotConfigured";
        }
        if (selector == AVIPCollusionAlertChannel.FlagAlreadyRecorded.selector) {
            return "FlagAlreadyRecorded";
        }
        if (selector == AVIPSlashingChannel.NotNotifier.selector) return "NotNotifier";
        if (selector == AVIPSlashingChannel.NotifierNotConfigured.selector) {
            return "NotifierNotConfigured";
        }
        if (selector == AVIPSlashingChannel.ManagerNotConfigured.selector) {
            return "ManagerNotConfigured";
        }
        if (selector == IAVIPValidatorManager.NothingToSlash.selector) {
            return "NothingToSlash";
        }
        if (selector == IAVIPValidatorManager.NotSlashAuthority.selector) {
            return "NotSlashAuthority";
        }
        return string.concat("unknown(", vm.toString(selector), ")");
    }
}

