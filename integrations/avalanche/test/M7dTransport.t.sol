// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AVIPMessageCodec} from "../contracts/AVIPMessageCodec.sol";
import {AVIPMessageEndpoint} from "../contracts/AVIPMessageEndpoint.sol";
import {AVIPCommitmentRelay} from "../contracts/AVIPCommitmentRelay.sol";
import {AVIPCollusionAlertChannel} from "../contracts/AVIPCollusionAlertChannel.sol";
import {AVIPSlashingChannel} from "../contracts/AVIPSlashingChannel.sol";
import {AVIPRegistry} from "../contracts/AVIPRegistry.sol";
import {AVIPValidatorManager} from "../contracts/AVIPValidatorManager.sol";
import {IAVIPValidatorManager} from "../contracts/interfaces/IAVIPValidatorManager.sol";
import {Groth16Verifier} from "../contracts/verifiers/Groth16Verifier.sol";
import {MockTeleporterMessenger} from "./mocks/MockTeleporterMessenger.sol";
import {M4bGroth16Fixtures as F4b} from "./fixtures/M4bGroth16Fixtures.sol";
import {M7cBridgeFixtures as F7c} from "./fixtures/M7cBridgeFixtures.sol";
import {M7dProvenanceFixtures} from "./fixtures/M7dProvenanceFixtures.sol";

/// WHAT IS TESTED
/// --------------
/// M7d, the Teleporter/AWM transport of `docs/architecture/implementation-plan.md`
/// §5.11 (gap A9, `docs/architecture/avalanche-integration.md` §4). Five groups:
///
/// 1. **The codec is exact and fail-closed.** The envelope round-trips for all
///    three kinds; an unknown kind, an empty message, an empty payload and a
///    message that is *not* the canonical encoding of its own decoded value are
///    refused; and the slashing payload's four predicates (validator, amount,
///    ingestion digest, `published != formula`) hold at both ends.
/// 2. **`linkDigest` reproduces M7c's committed link.** The M7c table's five words
///    are `test/fixtures/M7cBridgeFixtures.sol` (declared, guarded against the
///    transcript in both directions by `scripts/m7d_report.sh`), and the Solidity
///    digest of the two roots and the epoch equals the link the Rust crate
///    published — so the wire format and `src/zk/src/bridge.rs` agree on the tie
///    rather than on a description of it. The tie is also checked to be positional
///    and epoch-bound, which are M7c's own rejections read in Solidity.
/// 3. **The boundary is the messenger plus the allowlist.** Only the messenger may
///    deliver (`NotTeleporter`); an unlisted source chain (`UnknownOrigin`), another
///    sender on a listed chain (`UnauthorizedOrigin`), another kind
///    (`UnexpectedMessageKind`) and a repeated nonce (`MessageAlreadyDelivered`)
///    are all refused; a deployment with an origin of another kind, with a zero
///    messenger or chain id, or half-wired on the sender side cannot be
///    constructed; and an *empty* allowlist is accepted and then refuses every
///    delivery, which is how a send-only endpoint is wired.
/// 4. **Each of the three §4 message types travels, and its effect is the one the
///    architecture names.** A commitment is announced from the registry's own root
///    and recorded on the subscriber with M7c's link intact, once per epoch, in any
///    arrival order; an alert carries both tail decisions and the calibration they
///    were decided against, and cannot be rewritten; a slashing notification
///    reaches `AVIPValidatorManager.slash` with a `reason` **derived from the
///    envelope**, demotes the validator's stake and ejects it, and a replay or a
///    notification the manager refuses leaves no trace.
/// 5. **`provenanceId` is a function of the envelope, not of the sender.** Two
///    notifications from one notifier produce two different reasons for the same
///    validator and amount, and the reason the manager's `ValidatorSlashed` event
///    carries is the same value the destination recorded.
///
/// WHAT IS NOT TESTED, AND WHY THAT IS THE HONEST BOUNDARY
/// ------------------------------------------------------
/// - **Nothing about AWM or Teleporter itself.** The messenger is
///   `test/mocks/MockTeleporterMessenger.sol`: a routing table with synchronous
///   delivery. No BLS signature, no source-chain quorum, no relayer, no fee, no gas
///   metering, no Warp message, no retry queue and **no latency**: `A11` stays
///   deferred because it needs a live subnet (§2.2). Where a test depends on a
///   property the double invented rather than the protocol's (the synchronous
///   bubbling of `sendCrossChainMessage`, the shape of the message id), it says so
///   at the assertion.
/// - **The link is checked for agreement, not for proof.** `linkDigest` is compared
///   against M7c's committed value and against itself; nothing here shows that the
///   tensor behind the two roots is the tensor M5 tested, because that requires the
///   tensor, which is off-chain by construction (§5.4 item 4, §5.10).
/// - **A collusion alert does not touch a voting weight**, because no on-chain
///   weight exists in this milestone: M2's manager holds none (§5.2 defers them to
///   M6) and the §4 message carries no node set. What is tested is that the flag
///   arrives, is complete, and cannot be erased — not that anything is discounted.
/// - **The transport does not check whether what it carries is true.** A compromised
///   sequencer can announce a committed root over a lying tensor, a compromised
///   alerter can flag a graph that is fine, and a compromised notifier can ask for a
///   slash that no proof supports (`NotAFraudProof` catches only the self-refuting
///   case). The claim is *provenance and at-most-once delivery*; soundness lives in
///   M7b's fraud proof and in the data layer, not here.
/// - **No funds are involved.** No escrow, no token, no fee, no burn: `S_slash` is a
///   model parameter of §5.9 and the treasury is M8.
contract M7dTransportTest is Test {
    /// @dev `C·D·H` of the committed fixture tensor.
    uint32 internal constant N = 500;

    /// @dev The two chains of the suite. The "source" chain is where the data layer
    ///      and the registry live (the C-Chain of `avalanche-integration.md` §6
    ///      phase 1); the "destination" is the subscribed subnet. The ids are
    ///      arbitrary 32-byte words: a chain id is opaque to the transport, which is
    ///      the point of the allowlist being keyed on it.
    bytes32 internal constant CHAIN_SOURCE = bytes32(uint256(0xA11CE));
    bytes32 internal constant CHAIN_DESTINATION = bytes32(uint256(0xB0B));

    /// @dev The stake the slashed validator declares, and the amount the data layer
    ///      asks for. `1.0` and `0.9` WAD: the amount is a decision of §5.9's data
    ///      layer, not a constant of the paper (`S_slash = 10` is a *model*
    ///      parameter and is not transported), and 0.9 of the stake is chosen so the
    ///      slash also ejects — which is the effect M2 defines (§5.2.4).
    uint256 internal constant STAKE_WAD = 1e18;
    uint256 internal constant SLASH_WAD = 9e17;

    /// @dev M5's calibration, 4-decimal scaled: `q99 = 9.0542` right and `9.1371`
    ///      left (`src/rmt/scripts/m5_output.txt`), and `n = 500` for the protocol the
    ///      detector is calibrated on. Declared in `fixtures/M7dProvenanceFixtures.sol`
    ///      and guarded against that transcript by `scripts/m7d_report.sh`.
    uint32 internal constant RIGHT_THRESHOLD_Q = M7dProvenanceFixtures.M5_RIGHT_THRESHOLD_Q;
    uint32 internal constant LEFT_THRESHOLD_Q = M7dProvenanceFixtures.M5_LEFT_THRESHOLD_Q;
    uint32 internal constant NODE_COUNT = M7dProvenanceFixtures.M5_NODE_COUNT;

    /// @dev M7b's §5.9 instance and its adjudicated fraud, from the same fixture: the
    ///      instantiated `f_c` has genesis digest `0x2fcd03b8…`, and against a committed
    ///      value re-hashed at `+1` the proof returns `Fraud: published
    ///      138673557278208441, f_c 138673557278208440`. Those are the values M7d
    ///      transports, so the notification carries a real adjudication rather than an
    ///      invented pair.
    bytes32 internal constant INGESTION_DIGEST = M7dProvenanceFixtures.M7B_INGESTION_DIGEST;
    uint256 internal constant PUBLISHED_WAD = M7dProvenanceFixtures.M7B_PUBLISHED_WAD;
    uint256 internal constant FORMULA_WAD = M7dProvenanceFixtures.M7B_FORMULA_WAD;

    MockTeleporterMessenger internal teleporter;

    /// @dev The library's own reverts need a call frame to be observable (see the
    ///      harness at the end of this file).
    AVIPMessageCodecHarness internal codec;

    Groth16Verifier internal verifier;
    /// @dev The registry the *manager* reads: M4b's recipe, i.e. epoch 0 committed
    ///      with the statement's own root, which is what its proof verifies against
    ///      (`test/M4bRealKey.t.sol`; M7c's table says exactly that this root is the
    ///      *statement's*, not M1's fold).
    AVIPRegistry internal registryForAdmission;
    /// @dev The registry the *relay* reads: the same tensor as M1 commits it, so
    ///      epoch 0 holds `F7c.MERKLE_ROOT`. The two registries are two deployment
    ///      scenarios of one chain, and the reason they cannot be a single instance
    ///      is the gap M7c closed: M4b's proof is bound to the statement's root and
    ///      M1's fold produces the Merkle root, and only the *link* ties them.
    AVIPRegistry internal registryForCommitment;

    AVIPValidatorManager internal manager;

    AVIPCommitmentRelay internal relaySource;
    AVIPCommitmentRelay internal relayDestination;
    AVIPCollusionAlertChannel internal alertSource;
    AVIPCollusionAlertChannel internal alertDestination;
    AVIPSlashingChannel internal slashingSource;
    AVIPSlashingChannel internal slashingDestination;

    address internal sequencer;
    address internal alerter;
    address internal notifier;
    address internal validator;

    function setUp() public {
        // Every pair of endpoints is mutually referential: a source's routing table
        // names its destination, and the destination's allowlist names the source.
        // Both are constructor-fixed (no setter, by design), so the three destination
        // addresses are predicted from the CREATE nonce before anything is deployed
        // and checked the moment the contracts exist (`assertEq` at the end). The same
        // cycle fixes the executor: the manager's only slasher is the slashing
        // channel, and the channel's manager is the manager. A wrong guess fails
        // loudly here instead of wiring a transport nobody can use; a real deployment
        // reaches the same end with CREATE2 or with nonces it knows.
        //
        // The deployment order is therefore part of the wiring, and it is:
        //   0 messenger · 1 verifier · 2 admission registry · 3 commitment registry ·
        //   4 manager · 5 relaySource · 6 relayDestination · 7 alertSource ·
        //   8 alertDestination · 9 slashingSource · 10 slashingDestination
        address predictedRelayDestination = _predictDeployment(6);
        address predictedAlertDestination = _predictDeployment(8);
        address predictedSlashingDestination = _predictDeployment(10);

        teleporter = new MockTeleporterMessenger();

        verifier = new Groth16Verifier(F4b.verifyingKey());
        sequencer = makeAddr("sequencer");
        alerter = makeAddr("alerter");
        notifier = makeAddr("notifier");
        validator = makeAddr("validator");

        registryForAdmission = new AVIPRegistry(sequencer, address(verifier));
        registryForCommitment = new AVIPRegistry(sequencer, address(verifier));
        manager = new AVIPValidatorManager(
            address(registryForAdmission), predictedSlashingDestination, address(0)
        );

        // Sources first: a destination's allowlist names the source contract, so the
        // order is forced by the wiring itself and not by taste.
        relaySource = new AVIPCommitmentRelay(
            address(teleporter),
            CHAIN_SOURCE,
            address(registryForCommitment),
            sequencer,
            _noOrigins(),
            _destination(CHAIN_DESTINATION, predictedRelayDestination)
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
            alerter,
            _noOrigins(),
            _destination(CHAIN_DESTINATION, predictedAlertDestination)
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
            notifier,
            address(0),
            _noOrigins(),
            _destination(CHAIN_DESTINATION, predictedSlashingDestination)
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

        assertEq(address(relayDestination), predictedRelayDestination, "CREATE prediction 1");
        assertEq(address(alertDestination), predictedAlertDestination, "CREATE prediction 2");
        assertEq(address(slashingDestination), predictedSlashingDestination, "CREATE prediction 3");

        // Routing table, then the two committed epochs of the relay's registry.
        teleporter.registerEndpoint(address(relaySource), CHAIN_SOURCE);
        teleporter.registerEndpoint(address(relayDestination), CHAIN_DESTINATION);
        teleporter.registerEndpoint(address(alertSource), CHAIN_SOURCE);
        teleporter.registerEndpoint(address(alertDestination), CHAIN_DESTINATION);
        teleporter.registerEndpoint(address(slashingSource), CHAIN_SOURCE);
        teleporter.registerEndpoint(address(slashingDestination), CHAIN_DESTINATION);

        // Genesis at M1's own fold over the fixture tensor, then one more epoch so
        // the suite can show that arrival order does not decide what is recorded.
        _commit(0, F7c.MERKLE_ROOT, N);
        _commit(1, bytes32(uint256(F7c.MERKLE_ROOT) ^ 1), 7);

        // Last, so the three predictions above stay about the wiring and not about
        // this test-only helper.
        codec = new AVIPMessageCodecHarness();
    }

    // ------------------------------------------------------------------ helpers

    /// @dev The address the `offset`-th `new` of `setUp` will land on.
    function _predictDeployment(uint256 offset) internal view returns (address) {
        return vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + offset);
    }

    /// @dev A one-entry inbound allowlist. On the source side the sender address is
    ///      not used (`address(0)`), because a source only sends; the destination
    ///      side names the source contract, so the helper is called with it there.
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

    /// @dev A one-entry outbound routing table. The receiver names the destination
    ///      endpoint, which `setUp` predicts before it exists (the pair is mutually
    ///      referential and both sides are constructor-fixed).
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

    /// @dev A send-only endpoint listens to nobody: an empty allowlist is the
    ///      honest wiring for "this chain announces, it does not listen", and the
    ///      transport refuses every delivery to it rather than pretending.
    function _noOrigins() internal pure returns (AVIPMessageEndpoint.Origin[] memory) {
        return new AVIPMessageEndpoint.Origin[](0);
    }

    /// @dev Commits an epoch in the relay's registry, as the sequencer.
    function _commit(uint256 epoch, bytes32 root, uint32 changedEntries) internal {
        vm.prank(sequencer);
        registryForCommitment.postCommitment(epoch, root, changedEntries);
    }

    /// @dev Admits `validator` with M4b's real key over V3 and its proof, so the
    ///      slashing leg ends in a real `AVIPValidatorManager.slash` against a real
    ///      stake. The recipe is `test/M4bRealKey.t.sol`'s, unchanged.
    function _admitValidator() internal {
        vm.prank(sequencer);
        registryForAdmission.postCommitment(0, bytes32(F4b.STATEMENT_ROOT), N);
        vm.prank(validator);
        manager.admit(validator, STAKE_WAD, F4b.STATEMENT_NORM, F4b.proof());
    }

    /// @dev Delivers `message` to `endpoint` as the messenger would, with an
    ///      arbitrary `(sourceChainId, originSender)`. Used by the tests that need a
    ///      message the allowlist must refuse: the double cannot send one.
    function _deliverFromMessenger(
        address endpoint,
        bytes32 sourceChainId,
        address originSender,
        bytes memory message
    ) internal {
        vm.prank(address(teleporter));
        AVIPMessageEndpoint(endpoint).receiveTeleporterMessage(sourceChainId, originSender, message);
    }

    /// @dev M7c's commitment, as the source chain would announce it: M1's root out of
    ///      the registry, the statement's root from the prover, and the tie M7c
    ///      pinned.
    function _m7cCommitment()
        internal
        pure
        returns (AVIPMessageCodec.CommitmentPropagation memory)
    {
        return AVIPMessageCodec.CommitmentPropagation({
                epoch: F7c.EPOCH,
                merkleRoot: F7c.MERKLE_ROOT,
                changedEntries: N,
                statementRoot: F7c.STATEMENT_ROOT,
                link: F7c.LINK
            });
    }

    /// @dev M5's verdict, a right-tail flag at the sealed `alpha = 0.01` calibration.
    function _m5Alert() internal pure returns (AVIPMessageCodec.CollusionAlert memory) {
        return AVIPMessageCodec.CollusionAlert({
            epoch: 0,
            nodeCount: NODE_COUNT,
            rightThresholdQ: RIGHT_THRESHOLD_Q,
            leftThresholdQ: LEFT_THRESHOLD_Q,
            graphDigest: F7c.TENSOR_DIGEST,
            rightAlert: true,
            leftAlert: false
        });
    }

    /// @dev M7b's adjudicated fraud (§5.9), as the data layer would notify it.
    function _m7bNotification(address v)
        internal
        pure
        returns (AVIPMessageCodec.SlashingNotification memory)
    {
        return AVIPMessageCodec.SlashingNotification({
            validator: v,
            amountWad: SLASH_WAD,
            epoch: 0,
            ingestionDigest: INGESTION_DIGEST,
            publishedWad: PUBLISHED_WAD,
            formulaWad: FORMULA_WAD
        });
    }

    /// @dev An envelope round trip for one kind: the same triple comes back out.
    function _roundTrip(uint8 kind, bytes memory payload) private pure {
        uint256 nonce = 7;
        (uint8 decodedKind, uint256 decodedNonce, bytes memory decodedPayload) =
            AVIPMessageCodec.decodeEnvelope(AVIPMessageCodec.encode(kind, nonce, payload));
        assertEq(decodedKind, kind);
        assertEq(decodedNonce, nonce);
        assertEq(keccak256(decodedPayload), keccak256(payload));
    }

    // ================================================================ the codec

    function test_theEnvelopeRoundTripsEveryKind() public pure {
        _roundTrip(AVIPMessageCodec.KIND_COMMITMENT_PROPAGATION, abi.encode(_m7cCommitment()));
        _roundTrip(AVIPMessageCodec.KIND_COLLUSION_ALERT, abi.encode(_m5Alert()));
        _roundTrip(
            AVIPMessageCodec.KIND_SLASHING_NOTIFICATION,
            abi.encode(_m7bNotification(address(0xBEEF)))
        );
    }

    function test_theEnvelopeRefusesAnUnknownKind() public {
        bytes memory payload = abi.encode(_m7cCommitment());
        vm.expectRevert(abi.encodeWithSelector(AVIPMessageCodec.UnknownMessageKind.selector, 0));
        codec.encode(0, 1, payload);
        vm.expectRevert(abi.encodeWithSelector(AVIPMessageCodec.UnknownMessageKind.selector, 4));
        codec.encode(4, 1, payload);

        // And on arrival, where it matters: a hand-built envelope of a kind nobody
        // answers for, with an origin the allowlist *does* allow, is refused before
        // the payload is looked at.
        vm.expectRevert(abi.encodeWithSelector(AVIPMessageCodec.UnknownMessageKind.selector, 4));
        _deliverFromMessenger(
            address(relayDestination), CHAIN_SOURCE, address(relaySource), abi.encode(4, 0, payload)
        );
    }

    function test_theEnvelopeRefusesEmptyMessagesAndPayloads() public {
        vm.expectRevert(AVIPMessageCodec.EmptyMessage.selector);
        codec.decodeEnvelope("");
        vm.expectRevert(AVIPMessageCodec.EmptyPayload.selector);
        codec.encode(AVIPMessageCodec.KIND_COLLUSION_ALERT, 0, "");
    }

    /// @dev `abi.decode` accepts a blob with a well-formed prefix; the envelope is
    ///      stricter than that on purpose, because a replay guard keyed on the
    ///      envelope must not see two encodings of one message.
    function test_theEnvelopeRefusesANonCanonicalMessage() public {
        bytes memory canonical = AVIPMessageCodec.encode(
            AVIPMessageCodec.KIND_COLLUSION_ALERT, 0, abi.encode(_m5Alert())
        );
        vm.expectRevert(AVIPMessageCodec.NonCanonicalMessage.selector);
        codec.decodeEnvelope(bytes.concat(canonical, bytes32(0)));
    }

    /// @notice The Solidity digest of M7c's two roots and epoch is M7c's own link.
    function test_linkDigestReproducesM7csCommittedLink() public pure {
        assertEq(
            AVIPMessageCodec.linkDigest(F7c.MERKLE_ROOT, F7c.STATEMENT_ROOT, F7c.EPOCH), F7c.LINK
        );
    }

    /// @notice The tie binds both roots *and* the epoch: M7c's rejection table read
    ///         in Solidity, where a moved root or another epoch is another link.
    function test_theLinkIsPositionalAndEpochBound() public pure {
        assertTrue(
            AVIPMessageCodec.linkDigest(
                    bytes32(uint256(F7c.MERKLE_ROOT) ^ 1), F7c.STATEMENT_ROOT, 0
                ) != F7c.LINK
        );
        assertTrue(
            AVIPMessageCodec.linkDigest(F7c.MERKLE_ROOT, F7c.STATEMENT_ROOT ^ 1, 0) != F7c.LINK
        );
        assertTrue(AVIPMessageCodec.linkDigest(F7c.MERKLE_ROOT, F7c.STATEMENT_ROOT, 1) != F7c.LINK);
    }

    /// @dev The epoch is a *word* in the preimage, not a packed `uint64`: M7c's
    ///      `bridge::link_digest` writes 96 bytes with the epoch right-aligned, and
    ///      `abi.encode` is the Solidity spelling of that. A 72-byte
    ///      `abi.encodePacked(merkleRoot, bytes32(statementRoot), uint64(epoch))` is
    ///      a different (and equally unambiguous) digest — this pins which one is in
    ///      force, so nobody quietly "optimises" it later.
    function test_theLinkIsThreeWordsNotAPackedEpoch() public pure {
        assertEq(
            AVIPMessageCodec.linkDigest(F7c.MERKLE_ROOT, F7c.STATEMENT_ROOT, 0),
            keccak256(abi.encode(F7c.MERKLE_ROOT, F7c.STATEMENT_ROOT, uint256(0)))
        );
        assertTrue(
            keccak256(abi.encodePacked(F7c.MERKLE_ROOT, bytes32(F7c.STATEMENT_ROOT), uint64(0)))
                != F7c.LINK
        );
    }

    function test_aCommitmentWhoseLinkDoesNotTieItsWordsIsRefusedAtBothEnds() public {
        AVIPMessageCodec.CommitmentPropagation memory lying = _m7cCommitment();
        lying.link = bytes32(uint256(F7c.LINK) ^ 1);
        bytes32 expected =
            AVIPMessageCodec.linkDigest(lying.merkleRoot, lying.statementRoot, lying.epoch);

        vm.expectRevert(
            abi.encodeWithSelector(AVIPMessageCodec.LinkMismatch.selector, expected, lying.link)
        );
        codec.encodeCommitment(lying);

        vm.expectRevert(
            abi.encodeWithSelector(AVIPMessageCodec.LinkMismatch.selector, expected, lying.link)
        );
        codec.decodeCommitment(abi.encode(lying));
    }

    /// @dev §4's alert exists because a test *flagged* something; a quiet verdict is
    ///      not a message, and the check is on both sides of the wire.
    function test_aQuietAlertIsRefusedAtBothEnds() public {
        AVIPMessageCodec.CollusionAlert memory quiet = _m5Alert();
        quiet.rightAlert = false;
        quiet.leftAlert = false;

        vm.expectRevert(AVIPMessageCodec.QuietAlert.selector);
        codec.encodeAlert(quiet);
        vm.expectRevert(AVIPMessageCodec.QuietAlert.selector);
        codec.decodeAlert(abi.encode(quiet));
    }

    function test_anAlertWithoutAGraphToPointAtIsRefusedAtBothEnds() public {
        AVIPMessageCodec.CollusionAlert memory ungrounded = _m5Alert();
        ungrounded.graphDigest = bytes32(0);

        vm.expectRevert(AVIPMessageCodec.EmptyGraphDigest.selector);
        codec.encodeAlert(ungrounded);
        vm.expectRevert(AVIPMessageCodec.EmptyGraphDigest.selector);
        codec.decodeAlert(abi.encode(ungrounded));
    }

    /// @dev M7b's semantics, not a formatting rule: `adjudicate` returns
    ///      `Verdict::Fraud` exactly when the published value is not `f_c(events)`,
    ///      so a notification whose two values agree is a slash with no proof.
    function test_aNotificationThatIsNotAFraudIsRefusedAtBothEnds() public {
        AVIPMessageCodec.SlashingNotification memory consistent = _m7bNotification(validator);
        consistent.formulaWad = consistent.publishedWad;

        vm.expectRevert(
            abi.encodeWithSelector(
                AVIPMessageCodec.NotAFraudProof.selector,
                consistent.publishedWad,
                consistent.formulaWad
            )
        );
        codec.encodeSlashing(consistent);
        vm.expectRevert(
            abi.encodeWithSelector(
                AVIPMessageCodec.NotAFraudProof.selector,
                consistent.publishedWad,
                consistent.formulaWad
            )
        );
        codec.decodeSlashing(abi.encode(consistent));
    }

    function test_aNotificationWithoutAValidatorAnAmountOrAnInstanceIsRefused() public {
        AVIPMessageCodec.SlashingNotification memory nameless = _m7bNotification(address(0));
        vm.expectRevert(AVIPMessageCodec.EmptyValidator.selector);
        codec.encodeSlashing(nameless);

        AVIPMessageCodec.SlashingNotification memory free = _m7bNotification(validator);
        free.amountWad = 0;
        vm.expectRevert(AVIPMessageCodec.ZeroSlashAmount.selector);
        codec.encodeSlashing(free);

        AVIPMessageCodec.SlashingNotification memory unbound = _m7bNotification(validator);
        unbound.ingestionDigest = bytes32(0);
        vm.expectRevert(AVIPMessageCodec.EmptyIngestionDigest.selector);
        codec.encodeSlashing(unbound);
    }

    /// @notice The provenance id is a function of *where* and *which*: the same
    ///         envelope gives the same reason, another chain or another nonce does not.
    function test_provenanceIdIsAFunctionOfTheEnvelope() public pure {
        bytes32 source = AVIPMessageCodec.provenanceId(CHAIN_SOURCE, 0);
        assertEq(source, keccak256(abi.encodePacked(CHAIN_SOURCE, uint256(0))));
        assertTrue(source != AVIPMessageCodec.provenanceId(CHAIN_DESTINATION, 0));
        assertTrue(source != AVIPMessageCodec.provenanceId(CHAIN_SOURCE, 1));
    }

    /// @dev The envelope is the replay guard's key, so two encodings of one message
    ///      would be two messages: the digest of an envelope is a function of
    ///      `(kind, nonce, payload)` and of nothing else, which is what the nonce
    ///      guard reads.
    function testFuzz_theEnvelopeIsInjectiveInItsNonce(uint256 nonceA, uint256 nonceB) public {
        vm.assume(nonceA != nonceB);
        bytes memory payload = abi.encode(_m5Alert());
        assertTrue(
            keccak256(
                    AVIPMessageCodec.encode(AVIPMessageCodec.KIND_COLLUSION_ALERT, nonceA, payload)
                )
                != keccak256(
                    AVIPMessageCodec.encode(AVIPMessageCodec.KIND_COLLUSION_ALERT, nonceB, payload)
                )
        );
    }

    // ============================================================== the boundary

    /// @dev Type 1's committed message, as the relay would send it: the boundary
    ///      tests need a *well-formed* message that is refused for who sent it rather
    ///      than for what it says.
    function _committedMessage() internal pure returns (bytes memory) {
        return AVIPMessageCodec.encode(
            AVIPMessageCodec.KIND_COMMITMENT_PROPAGATION, 0, abi.encode(_m7cCommitment())
        );
    }

    function test_onlyTheMessengerMayDeliver() public {
        vm.expectRevert(
            abi.encodeWithSelector(AVIPMessageEndpoint.NotTeleporter.selector, address(this))
        );
        relayDestination.receiveTeleporterMessage(
            CHAIN_SOURCE, address(relaySource), _committedMessage()
        );
    }

    function test_anUnlistedSourceChainCannotDeliver() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                AVIPMessageEndpoint.UnknownOrigin.selector,
                AVIPMessageCodec.KIND_COMMITMENT_PROPAGATION,
                CHAIN_DESTINATION
            )
        );
        _deliverFromMessenger(
            address(relayDestination), CHAIN_DESTINATION, address(relaySource), _committedMessage()
        );
    }

    function test_anotherSenderOnAListedChainCannotDeliver() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                AVIPMessageEndpoint.UnauthorizedOrigin.selector,
                AVIPMessageCodec.KIND_COMMITMENT_PROPAGATION,
                CHAIN_SOURCE,
                address(relaySource),
                address(0xBAD5EED)
            )
        );
        _deliverFromMessenger(
            address(relayDestination), CHAIN_SOURCE, address(0xBAD5EED), _committedMessage()
        );
    }

    function test_aMessageOfAnotherKindIsRefused() public {
        bytes memory alertMessage = AVIPMessageCodec.encode(
            AVIPMessageCodec.KIND_COLLUSION_ALERT, 0, abi.encode(_m5Alert())
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                AVIPMessageEndpoint.UnexpectedMessageKind.selector,
                AVIPMessageCodec.KIND_COLLUSION_ALERT,
                AVIPMessageCodec.KIND_COMMITMENT_PROPAGATION
            )
        );
        _deliverFromMessenger(
            address(relayDestination), CHAIN_SOURCE, address(relaySource), alertMessage
        );
    }

    /// @dev A send-only endpoint is wired with an empty allowlist, and its answer to
    ///      every delivery is the one an unlisted chain gets.
    function test_aSendOnlyEndpointRefusesEveryDelivery() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                AVIPMessageEndpoint.UnknownOrigin.selector,
                AVIPMessageCodec.KIND_COMMITMENT_PROPAGATION,
                CHAIN_SOURCE
            )
        );
        _deliverFromMessenger(
            address(relaySource), CHAIN_SOURCE, address(relaySource), _committedMessage()
        );
    }

    /// @notice The same envelope, delivered twice, is delivered once. Teleporter is
    ///         allowed to hand a message over again (a solver retries a failed
    ///         execution), so the receiver's own nonce set is the only thing between a
    ///         re-delivery and a second effect.
    function test_aMessageIsDeliveredAtMostOnce() public {
        vm.prank(sequencer);
        bytes32[] memory ids = relaySource.publish(F7c.EPOCH, F7c.STATEMENT_ROOT, F7c.LINK);
        bytes memory message = teleporter.routedMessage(ids[0]).message;

        assertEq(relayDestination.deliveredMessages(), 1);
        assertTrue(relayDestination.isDelivered(CHAIN_SOURCE, address(relaySource), 0));

        vm.expectRevert(
            abi.encodeWithSelector(
                AVIPMessageEndpoint.MessageAlreadyDelivered.selector,
                CHAIN_SOURCE,
                address(relaySource),
                uint256(0)
            )
        );
        _deliverFromMessenger(
            address(relayDestination), CHAIN_SOURCE, address(relaySource), message
        );
        assertEq(relayDestination.deliveredMessages(), 1);
    }

    function test_anEndpointWithoutAMessengerOrAChainIdIsRefused() public {
        vm.expectRevert(
            abi.encodeWithSelector(AVIPMessageEndpoint.EmptyConfiguration.selector, "teleporter")
        );
        new AVIPCommitmentRelay(
            address(0), CHAIN_SOURCE, address(0), address(0), _noOrigins(), _noDestinations()
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                AVIPMessageEndpoint.EmptyConfiguration.selector, "localBlockchainId"
            )
        );
        new AVIPCommitmentRelay(
            address(teleporter), bytes32(0), address(0), address(0), _noOrigins(), _noDestinations()
        );
    }

    function test_anAllowlistEntryOfAnotherKindIsRefused() public {
        AVIPMessageEndpoint.Origin[] memory foreign = new AVIPMessageEndpoint.Origin[](1);
        foreign[0] = AVIPMessageEndpoint.Origin({
            kind: AVIPMessageCodec.KIND_COLLUSION_ALERT,
            sourceBlockchainId: CHAIN_SOURCE,
            originSenderAddress: address(relaySource)
        });
        vm.expectRevert(
            abi.encodeWithSelector(
                AVIPMessageEndpoint.ForeignOriginKind.selector,
                AVIPMessageCodec.KIND_COLLUSION_ALERT,
                AVIPMessageCodec.KIND_COMMITMENT_PROPAGATION
            )
        );
        new AVIPCommitmentRelay(
            address(teleporter),
            CHAIN_DESTINATION,
            address(0),
            address(0),
            foreign,
            _noDestinations()
        );
    }

    /// @dev A registry without a sequencer (or the reverse) is a wiring mistake, not a
    ///      receive-only chain: the two are one side of the wire and come together.
    function test_aHalfWiredRelayIsRefused() public {
        vm.expectRevert(AVIPCommitmentRelay.PartialConfiguration.selector);
        new AVIPCommitmentRelay(
            address(teleporter),
            CHAIN_DESTINATION,
            address(registryForCommitment),
            address(0),
            _origin(
                AVIPMessageCodec.KIND_COMMITMENT_PROPAGATION, CHAIN_SOURCE, address(relaySource)
            ),
            _noDestinations()
        );

        vm.expectRevert(AVIPCommitmentRelay.PartialConfiguration.selector);
        new AVIPCommitmentRelay(
            address(teleporter),
            CHAIN_DESTINATION,
            address(0),
            sequencer,
            _noOrigins(),
            _noDestinations()
        );
    }

    /// @notice What was wired is readable, which is what makes a deployment checkable
    ///         without an explorer: the kind, the messenger, the chain, the allowlist
    ///         and the routing table.
    function test_theWiringIsReadable() public view {
        assertEq(relayDestination.kind(), AVIPMessageCodec.KIND_COMMITMENT_PROPAGATION);
        assertEq(alertDestination.kind(), AVIPMessageCodec.KIND_COLLUSION_ALERT);
        assertEq(slashingDestination.kind(), AVIPMessageCodec.KIND_SLASHING_NOTIFICATION);
        assertEq(address(relayDestination.teleporter()), address(teleporter));
        assertEq(relayDestination.localBlockchainId(), CHAIN_DESTINATION);
        assertEq(
            relayDestination.originOf(AVIPMessageCodec.KIND_COMMITMENT_PROPAGATION, CHAIN_SOURCE),
            address(relaySource)
        );
        assertEq(
            relayDestination.originOf(AVIPMessageCodec.KIND_COLLUSION_ALERT, CHAIN_SOURCE),
            address(0)
        );
        assertEq(relayDestination.destinationCount(), 0);
        assertEq(relaySource.destinationCount(), 1);
        assertEq(relaySource.destinationAt(0).blockchainId, CHAIN_DESTINATION);
        assertEq(relaySource.destinationAt(0).receiver, address(relayDestination));
        assertEq(relaySource.nextNonce(CHAIN_DESTINATION), 0);
        assertEq(relayDestination.deliveredMessages(), 0);
    }

    // ==================================== type 1: commitment propagation (§4)

    /// @notice The whole round trip: the registry's own root leaves the source chain
    ///         and is recorded on the subscriber with M7c's link intact.
    function test_aCommitmentTravelsFromTheRegistryToTheSubscriber() public {
        vm.prank(sequencer);
        bytes32[] memory ids = relaySource.publish(F7c.EPOCH, F7c.STATEMENT_ROOT, F7c.LINK);

        assertEq(ids.length, 1);
        MockTeleporterMessenger.Routed memory routed = teleporter.routedMessage(ids[0]);
        assertEq(routed.sourceBlockchainId, CHAIN_SOURCE);
        assertEq(routed.originSenderAddress, address(relaySource));
        assertEq(routed.destinationBlockchainId, CHAIN_DESTINATION);
        assertEq(routed.destinationAddress, address(relayDestination));
        // The value `AVIPMessageEndpoint` pins for the reference wiring; an engineering
        // parameter, not a paper constant, asserted here so changing it is a visible
        // decision rather than a silent one.
        assertEq(routed.requiredGasLimit, 300_000);

        AVIPCommitmentRelay.Propagated memory record =
            relayDestination.propagatedOf(CHAIN_SOURCE, F7c.EPOCH);
        assertEq(record.merkleRoot, F7c.MERKLE_ROOT);
        assertEq(record.merkleRoot, registryForCommitment.commitmentOf(F7c.EPOCH));
        assertEq(record.statementRoot, F7c.STATEMENT_ROOT);
        assertEq(record.link, F7c.LINK);
        assertEq(record.changedEntries, N);

        assertEq(relayDestination.latestEpochOf(CHAIN_SOURCE), F7c.EPOCH);
        assertTrue(relayDestination.hasPropagated(CHAIN_SOURCE));
        assertEq(relayDestination.deliveredMessages(), 1);
        assertEq(relaySource.nextNonce(CHAIN_DESTINATION), 1);
        assertEq(teleporter.sentMessages(), 1);
        assertEq(teleporter.deliveredMessages(), 1);
    }

    function test_anUncommittedEpochIsNotPropagated() public {
        vm.expectRevert(abi.encodeWithSelector(AVIPCommitmentRelay.UncommittedEpoch.selector, 9));
        vm.prank(sequencer);
        relaySource.publish(9, F7c.STATEMENT_ROOT, F7c.LINK);
        assertEq(teleporter.sentMessages(), 0);
    }

    /// @dev For every epoch the registry never posted: the root comes from the registry
    ///      and not from the caller, so there is nothing to announce.
    function testFuzz_anyUncommittedEpochIsRefused(uint256 epoch) public {
        vm.assume(epoch != 0 && epoch != 1);
        vm.expectRevert(
            abi.encodeWithSelector(AVIPCommitmentRelay.UncommittedEpoch.selector, epoch)
        );
        vm.prank(sequencer);
        relaySource.publish(epoch, F7c.STATEMENT_ROOT, F7c.LINK);
    }

    function test_theSenderRefusesALinkThatDoesNotTieItsWords() public {
        bytes32 wrong = bytes32(uint256(F7c.LINK) ^ 1);
        bytes32 expected =
            AVIPMessageCodec.linkDigest(F7c.MERKLE_ROOT, F7c.STATEMENT_ROOT, F7c.EPOCH);
        vm.expectRevert(
            abi.encodeWithSelector(AVIPMessageCodec.LinkMismatch.selector, expected, wrong)
        );
        vm.prank(sequencer);
        relaySource.publish(F7c.EPOCH, F7c.STATEMENT_ROOT, wrong);
        assertEq(teleporter.sentMessages(), 0);
    }

    function test_onlyTheSequencerMayAnnounce() public {
        vm.expectRevert(
            abi.encodeWithSelector(AVIPCommitmentRelay.NotSequencer.selector, address(this))
        );
        relaySource.publish(F7c.EPOCH, F7c.STATEMENT_ROOT, F7c.LINK);
    }

    function test_aReceiveOnlyRelayCannotAnnounce() public {
        vm.expectRevert(AVIPCommitmentRelay.RegistryNotConfigured.selector);
        relayDestination.publish(F7c.EPOCH, F7c.STATEMENT_ROOT, F7c.LINK);
    }

    /// @notice A hand-built message that lies about the tie is refused on arrival, and
    ///         what refuses it is the payload's *own words*, not the sender's good
    ///         behaviour.
    function test_aHandBuiltCommitmentWithALyingLinkIsRefusedOnArrival() public {
        AVIPMessageCodec.CommitmentPropagation memory lying = _m7cCommitment();
        lying.link = bytes32(uint256(F7c.LINK) ^ 1);
        bytes memory message = AVIPMessageCodec.encode(
            AVIPMessageCodec.KIND_COMMITMENT_PROPAGATION, 0, abi.encode(lying)
        );
        bytes32 expected =
            AVIPMessageCodec.linkDigest(lying.merkleRoot, lying.statementRoot, lying.epoch);

        vm.expectRevert(
            abi.encodeWithSelector(AVIPMessageCodec.LinkMismatch.selector, expected, lying.link)
        );
        _deliverFromMessenger(
            address(relayDestination), CHAIN_SOURCE, address(relaySource), message
        );

        assertFalse(relayDestination.hasPropagated(CHAIN_SOURCE));
        assertEq(relayDestination.deliveredMessages(), 0);
    }

    /// @notice An epoch is recorded once. The second message carries a fresh nonce, so
    ///         the nonce guard does not catch it: the record itself does.
    function test_anEpochIsRecordedOnce() public {
        vm.startPrank(sequencer);
        relaySource.publish(F7c.EPOCH, F7c.STATEMENT_ROOT, F7c.LINK);
        vm.expectRevert(
            abi.encodeWithSelector(
                AVIPCommitmentRelay.EpochAlreadyPropagated.selector, CHAIN_SOURCE, F7c.EPOCH
            )
        );
        relaySource.publish(F7c.EPOCH, F7c.STATEMENT_ROOT, F7c.LINK);
        vm.stopPrank();
        assertEq(relayDestination.deliveredMessages(), 1);
    }

    /// @dev The transport promises no order, so an older epoch arriving after a newer
    ///      one is *recorded* rather than discarded — and it cannot drag the
    ///      destination's "latest" backwards.
    function test_anOutOfOrderEpochIsRecordedRatherThanDiscarded() public {
        bytes32 secondRoot = bytes32(uint256(F7c.MERKLE_ROOT) ^ 1);
        vm.startPrank(sequencer);
        relaySource.publish(
            1, F7c.STATEMENT_ROOT, AVIPMessageCodec.linkDigest(secondRoot, F7c.STATEMENT_ROOT, 1)
        );
        relaySource.publish(F7c.EPOCH, F7c.STATEMENT_ROOT, F7c.LINK);
        vm.stopPrank();

        assertEq(relayDestination.propagatedOf(CHAIN_SOURCE, 1).merkleRoot, secondRoot);
        assertEq(relayDestination.propagatedOf(CHAIN_SOURCE, F7c.EPOCH).link, F7c.LINK);
        assertEq(relayDestination.latestEpochOf(CHAIN_SOURCE), 1);
        assertEq(relayDestination.deliveredMessages(), 2);
    }

    // ========================================== type 2: collusion alert (§4)

    /// @notice The alert arrives complete: both tail decisions and the calibration they
    ///         were decided against, with the graph's identity M5 seeds itself with.
    function test_anAlertTravelsWithBothDecisionsAndItsCalibration() public {
        vm.prank(alerter);
        bytes32[] memory ids = alertSource.raise(_m5Alert());

        assertEq(ids.length, 1);
        assertEq(teleporter.routedMessage(ids[0]).originSenderAddress, address(alertSource));

        AVIPCollusionAlertChannel.Flag memory flag = alertDestination.flagOf(CHAIN_SOURCE, 0);
        assertEq(flag.epoch, 0);
        assertEq(flag.nodeCount, NODE_COUNT);
        assertEq(flag.rightThresholdQ, RIGHT_THRESHOLD_Q);
        assertEq(flag.leftThresholdQ, LEFT_THRESHOLD_Q);
        assertEq(flag.graphDigest, F7c.TENSOR_DIGEST);
        assertTrue(flag.rightAlert);
        assertFalse(flag.leftAlert);

        assertEq(alertDestination.flagCount(), 1);
        assertEq(alertDestination.deliveredMessages(), 1);
    }

    function test_onlyTheAlerterMayRaise() public {
        vm.expectRevert(
            abi.encodeWithSelector(AVIPCollusionAlertChannel.NotAlerter.selector, address(this))
        );
        alertSource.raise(_m5Alert());
    }

    function test_aReceiveOnlyAlertChannelCannotRaise() public {
        vm.expectRevert(AVIPCollusionAlertChannel.AlerterNotConfigured.selector);
        alertDestination.raise(_m5Alert());
    }

    function test_aQuietVerdictCannotBeRaised() public {
        AVIPMessageCodec.CollusionAlert memory quiet = _m5Alert();
        quiet.rightAlert = false;
        vm.expectRevert(AVIPMessageCodec.QuietAlert.selector);
        vm.prank(alerter);
        alertSource.raise(quiet);
        assertEq(teleporter.sentMessages(), 0);
    }

    /// @notice A second alert for one epoch cannot rewrite the first one, even though
    ///         it is a different message with a fresh nonce: the flag is written once,
    ///         so the destination's set of flags only grows.
    function test_aFlagCannotBeRewritten() public {
        vm.startPrank(alerter);
        alertSource.raise(_m5Alert());

        AVIPMessageCodec.CollusionAlert memory retraction = _m5Alert();
        retraction.leftAlert = true;
        retraction.rightAlert = false;
        vm.expectRevert(
            abi.encodeWithSelector(
                AVIPCollusionAlertChannel.FlagAlreadyRecorded.selector, CHAIN_SOURCE, uint256(0)
            )
        );
        alertSource.raise(retraction);
        vm.stopPrank();

        AVIPCollusionAlertChannel.Flag memory flag = alertDestination.flagOf(CHAIN_SOURCE, 0);
        assertTrue(flag.rightAlert);
        assertFalse(flag.leftAlert);
        assertEq(alertDestination.flagCount(), 1);
    }

    /// @dev Two epochs, newest first: both are recorded, because a message about epoch
    ///      0 is a fact about epoch 0 and not a claim about "now".
    function test_alertsArrivingOutOfOrderAreBothRecorded() public {
        AVIPMessageCodec.CollusionAlert memory later = _m5Alert();
        later.epoch = 1;
        later.rightAlert = false;
        later.leftAlert = true;

        vm.startPrank(alerter);
        alertSource.raise(later);
        alertSource.raise(_m5Alert());
        vm.stopPrank();

        assertTrue(alertDestination.flagOf(CHAIN_SOURCE, 0).rightAlert);
        assertTrue(alertDestination.flagOf(CHAIN_SOURCE, 1).leftAlert);
        assertEq(alertDestination.flagCount(), 2);
    }

    // ===================================== type 3: slashing notification (§4)

    /// @notice The deepest end-to-end in the milestone: M4b's real proof admits a
    ///         validator, M7b's adjudicated fraud travels as a §4 message, and the
    ///         manager slashes with a `reason` derived from the envelope — the same
    ///         value the destination recorded.
    function test_aSlashingNotificationReachesTheManagerWithADerivedReason() public {
        _admitValidator();
        assertTrue(manager.isAdmitted(validator));

        bytes32 reason = AVIPMessageCodec.provenanceId(CHAIN_SOURCE, 0);

        // The manager's own event, with the reason the transport derived and the amount
        // the data layer asked for: `ValidatorSlashed(address indexed, uint256, bytes32)`.
        vm.expectEmit(true, false, false, true, address(manager));
        emit IAVIPValidatorManager.ValidatorSlashed(validator, SLASH_WAD, reason);

        vm.prank(notifier);
        slashingSource.notify(_m7bNotification(validator));

        uint256 required = manager.requiredStake(validator);
        assertEq(manager.stakeOf(validator), STAKE_WAD - SLASH_WAD);
        assertTrue(manager.stakeOf(validator) < required);
        assertFalse(manager.isAdmitted(validator));

        assertEq(slashingDestination.reasonOf(CHAIN_SOURCE, 0), reason);
        assertEq(slashingDestination.reasonFor(CHAIN_SOURCE, 0), reason);
        assertEq(slashingDestination.executedSlashes(), 1);
        assertEq(slashingDestination.deliveredMessages(), 1);
        assertEq(slashingSource.nextNonce(CHAIN_DESTINATION), 1);
    }

    /// @notice Two notifications from one notifier produce two different reasons for
    ///         the same validator and the same amount: the reason identifies the
    ///         *message*, so no sender can make two faults share one.
    function test_theReasonIsNotSomethingTheNotifierChooses() public {
        _admitValidator();

        AVIPMessageCodec.SlashingNotification memory first = _m7bNotification(validator);
        AVIPMessageCodec.SlashingNotification memory second = _m7bNotification(validator);
        second.amountWad = 1e17;

        vm.startPrank(notifier);
        slashingSource.notify(first);
        slashingSource.notify(second);
        vm.stopPrank();

        bytes32 reasonZero = slashingDestination.reasonOf(CHAIN_SOURCE, 0);
        bytes32 reasonOne = slashingDestination.reasonOf(CHAIN_SOURCE, 1);
        assertEq(reasonZero, AVIPMessageCodec.provenanceId(CHAIN_SOURCE, 0));
        assertEq(reasonOne, AVIPMessageCodec.provenanceId(CHAIN_SOURCE, 1));
        assertTrue(reasonZero != reasonOne);
        assertEq(manager.stakeOf(validator), STAKE_WAD - SLASH_WAD - 1e17);
        assertEq(slashingDestination.executedSlashes(), 2);
    }

    /// @notice A notification the manager refuses leaves no trace. The revert travels
    ///         out of `notify` because the double delivers synchronously (real
    ///         Teleporter would record a failed message instead — see
    ///         `test/mocks/MockTeleporterMessenger.sol`); the *receiver's* decision is
    ///         the same either way, and that is what this asserts: no stake moved, no
    ///         reason recorded, nothing counted.
    function test_aNotificationTheManagerRefusesLeavesNoTrace() public {
        assertEq(manager.stakeOf(validator), 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAVIPValidatorManager.SlashExceedsStake.selector, validator, SLASH_WAD, uint256(0)
            )
        );
        vm.prank(notifier);
        slashingSource.notify(_m7bNotification(validator));

        assertEq(slashingDestination.reasonOf(CHAIN_SOURCE, 0), bytes32(0));
        assertEq(slashingDestination.executedSlashes(), 0);
        assertEq(slashingDestination.deliveredMessages(), 0);
    }

    /// @dev The transport can only *ask* the manager to slash: whether the caller is
    ///      allowed to is the manager's own rule (M2 §5.2.4).
    function test_anExecutorThatIsNotTheSlashAuthorityCannotSlash() public {
        _admitValidator();

        AVIPValidatorManager other =
            new AVIPValidatorManager(address(registryForAdmission), address(this), address(0));
        AVIPSlashingChannel executor = new AVIPSlashingChannel(
            address(teleporter),
            CHAIN_DESTINATION,
            address(0),
            address(other),
            _origin(
                AVIPMessageCodec.KIND_SLASHING_NOTIFICATION, CHAIN_SOURCE, address(slashingSource)
            ),
            _noDestinations()
        );

        bytes memory message = AVIPMessageCodec.encode(
            AVIPMessageCodec.KIND_SLASHING_NOTIFICATION, 0, abi.encode(_m7bNotification(validator))
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IAVIPValidatorManager.NotSlashAuthority.selector, address(executor)
            )
        );
        _deliverFromMessenger(address(executor), CHAIN_SOURCE, address(slashingSource), message);
        assertEq(other.stakeOf(validator), 0);
        assertEq(executor.executedSlashes(), 0);
    }

    /// @dev An endpoint wired to execute but with no manager to execute against refuses
    ///      the delivery instead of recording a slash that did not happen.
    function test_anExecutorWithoutAManagerRefusesTheDelivery() public {
        AVIPSlashingChannel headless = new AVIPSlashingChannel(
            address(teleporter),
            CHAIN_DESTINATION,
            notifier,
            address(0),
            _origin(
                AVIPMessageCodec.KIND_SLASHING_NOTIFICATION, CHAIN_SOURCE, address(slashingSource)
            ),
            _noDestinations()
        );
        bytes memory message = AVIPMessageCodec.encode(
            AVIPMessageCodec.KIND_SLASHING_NOTIFICATION, 0, abi.encode(_m7bNotification(validator))
        );
        vm.expectRevert(AVIPSlashingChannel.ManagerNotConfigured.selector);
        _deliverFromMessenger(address(headless), CHAIN_SOURCE, address(slashingSource), message);
    }

    function test_onlyTheNotifierMayNotify() public {
        vm.expectRevert(
            abi.encodeWithSelector(AVIPSlashingChannel.NotNotifier.selector, address(this))
        );
        slashingSource.notify(_m7bNotification(validator));
    }

    function test_aReceiveOnlySlashingChannelCannotNotify() public {
        vm.expectRevert(AVIPSlashingChannel.NotifierNotConfigured.selector);
        slashingDestination.notify(_m7bNotification(validator));
    }

    /// @notice A re-delivered notification cannot slash twice, which is the invariant
    ///         the whole nonce mechanism exists for.
    function test_aReplayedNotificationCannotSlashTwice() public {
        _admitValidator();
        vm.prank(notifier);
        bytes32[] memory ids = slashingSource.notify(_m7bNotification(validator));
        uint256 afterFirst = manager.stakeOf(validator);
        bytes memory message = teleporter.routedMessage(ids[0]).message;

        vm.expectRevert(
            abi.encodeWithSelector(
                AVIPMessageEndpoint.MessageAlreadyDelivered.selector,
                CHAIN_SOURCE,
                address(slashingSource),
                uint256(0)
            )
        );
        _deliverFromMessenger(
            address(slashingDestination), CHAIN_SOURCE, address(slashingSource), message
        );
        assertEq(manager.stakeOf(validator), afterFirst);
        assertEq(slashingDestination.executedSlashes(), 1);
    }

    /// @dev The provenance id is injective in the envelope it is derived from: two
    ///      different `(chain, nonce)` pairs producing one id would let a message claim
    ///      another's provenance.
    function testFuzz_theProvenanceIdIsInjective(
        bytes32 chainA,
        bytes32 chainB,
        uint256 nonceA,
        uint256 nonceB
    ) public {
        vm.assume(chainA != chainB || nonceA != nonceB);
        bytes32 idA = AVIPMessageCodec.provenanceId(chainA, nonceA);
        bytes32 idB = AVIPMessageCodec.provenanceId(chainB, nonceB);
        assertTrue(idA != idB);
    }
}

/// @dev A library's `internal` functions are inlined into their caller, so a revert
///      inside one has no call frame of its own and `vm.expectRevert` cannot observe
///      it — the M3 suites hit this with `Bn254` and `test/README.md` records the
///      wrapper. This harness is the one call frame `AVIPMessageCodec`'s reverts need.
///      It adds no logic of its own: every member forwards to the library.
contract AVIPMessageCodecHarness {
    function encode(uint8 kind, uint256 nonce, bytes memory payload)
        external
        pure
        returns (bytes memory)
    {
        return AVIPMessageCodec.encode(kind, nonce, payload);
    }

    function decodeEnvelope(bytes memory message)
        external
        pure
        returns (uint8, uint256, bytes memory)
    {
        return AVIPMessageCodec.decodeEnvelope(message);
    }

    function encodeCommitment(AVIPMessageCodec.CommitmentPropagation memory commitment)
        external
        pure
        returns (bytes memory)
    {
        return AVIPMessageCodec.encodeCommitment(commitment);
    }

    function decodeCommitment(bytes memory payload)
        external
        pure
        returns (AVIPMessageCodec.CommitmentPropagation memory)
    {
        return AVIPMessageCodec.decodeCommitment(payload);
    }

    function encodeAlert(AVIPMessageCodec.CollusionAlert memory alert)
        external
        pure
        returns (bytes memory)
    {
        return AVIPMessageCodec.encodeAlert(alert);
    }

    function decodeAlert(bytes memory payload)
        external
        pure
        returns (AVIPMessageCodec.CollusionAlert memory)
    {
        return AVIPMessageCodec.decodeAlert(payload);
    }

    function encodeSlashing(AVIPMessageCodec.SlashingNotification memory notification)
        external
        pure
        returns (bytes memory)
    {
        return AVIPMessageCodec.encodeSlashing(notification);
    }

    function decodeSlashing(bytes memory payload)
        external
        pure
        returns (AVIPMessageCodec.SlashingNotification memory)
    {
        return AVIPMessageCodec.decodeSlashing(payload);
    }
}

