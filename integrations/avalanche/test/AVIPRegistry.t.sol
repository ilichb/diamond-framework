// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AVIPRegistry} from "../contracts/AVIPRegistry.sol";
import {IAVIPRegistry} from "../contracts/interfaces/IAVIPRegistry.sol";
import {IZKThresholdVerifier} from "../contracts/interfaces/IZKThresholdVerifier.sol";

/// WHAT IS TESTED
/// --------------
/// 1. Reference constants trace to the paper: `N = C*D*H = 500` (Tensor
///    Compression) and `gamma * N = 0.10 * 500 = 50` (Data Layer, freshness).
/// 2. Freshness: genesis requires a full-tensor delta; every later epoch
///    accepts 50 declared changes and rejects 51 with `FreshnessViolation`.
/// 3. Epoch discipline: 0-based, strictly sequential, no gaps, no re-posting;
///    an epoch that was never posted reads as root `0` and delta `0`.
/// 4. Access control: only the sequencer posts commitments or rotates roles,
///    and a zero sequencer cannot be installed.
/// 5. Merkle inclusion: the convention documented in `AVIPRegistry.sol` accepts
///    valid proofs for a single-leaf tree, an 8-leaf tree and the full 500-leaf
///    tensor, and rejects a tampered leaf, a foreign proof, a foreign root and
///    root zero.
/// 6. Threshold delegation: the registry binds the proof to `(root, epoch)` via
///    `publicInputs[0..1]`, forwards `(a, b, c)` unchanged, propagates the
///    verifier's answer, records the accepted proof and rejects a replay.
///
/// WHAT IS NOT TESTED
/// ------------------
/// - No real proof is ever verified: `IZKThresholdVerifier` is a mock, so
///   nothing here says the pairing check or the recursive SNARK is correct
///   (milestone M3).
/// - The freshness bound is enforced on the delta the sequencer *declares*.
///   The registry does not hold the tensor, so it cannot recompute that delta:
///   a lying sequencer is not caught here, that is the data layer's fraud proof
///   (gap A7, milestone M7).
/// - No admission, slashing or reputation-weight logic (milestone M2).
/// - No gas or latency claim: these tests assert behaviour only.
contract MockThresholdVerifier is IZKThresholdVerifier {
    bool internal immutable ANSWER;
    uint256 internal immutable EXPECTED_A0;

    constructor(bool answer_, uint256 expectedA0_) {
        ANSWER = answer_;
        EXPECTED_A0 = expectedA0_;
    }

    function verify(
        uint256[2] calldata a,
        uint256[2][2] calldata,
        uint256[2] calldata,
        uint256[] calldata
    ) external view returns (bool) {
        require(a[0] == EXPECTED_A0, "mock: proof not forwarded unchanged");
        return ANSWER;
    }
}

contract AVIPRegistryTest is Test {
    uint32 internal constant N = 500; // C*D*H, paper "Tensor Compression"
    uint32 internal constant GAMMA_N = 50; // 0.10 * 500, paper "Data Layer"
    uint256 internal constant PROOF_A0 = 42;

    AVIPRegistry internal registry;
    address internal sequencer;
    address internal validator;
    address internal stranger;

    bytes32[] internal tensor;
    bytes32 internal epoch0Root;
    bytes32[][] internal epoch0Proofs;

    function setUp() public {
        vm.warp(1_700_000_000);
        sequencer = makeAddr("sequencer");
        validator = makeAddr("validator");
        stranger = makeAddr("stranger");

        registry = new AVIPRegistry(sequencer, address(0));

        // Reference tensor of the paper: N = C*D*H = 500 entries.
        bytes32[] memory entries = new bytes32[](N);
        for (uint256 i = 0; i < N; ++i) {
            entries[i] = keccak256(abi.encodePacked("entry", i));
        }
        tensor = entries;
        (bytes32 root, bytes32[][] memory proofs) = _buildTree(entries);
        epoch0Root = root;
        epoch0Proofs = proofs;

        vm.prank(sequencer);
        registry.postCommitment(0, epoch0Root, N);
    }

    // ---------------------------------------------------------------- reference

    function test_referenceConstantsMatchThePaper() public view {
        assertEq(registry.tensorSize(), N, "C*D*H");
        assertEq(registry.maxDeltaEntries(), GAMMA_N, "gamma * N");
    }

    // --------------------------------------------------------------- freshness

    function test_postCommitment_acceptsTheFullGammaBound() public {
        vm.prank(sequencer);
        registry.postCommitment(1, keccak256("epoch-1"), GAMMA_N);

        assertEq(registry.changedEntriesOf(1), GAMMA_N);
        assertEq(registry.latestEpoch(), 1);
        assertEq(registry.commitmentOf(1), keccak256("epoch-1"));
    }

    function test_postCommitment_rejectsOneEntryAboveTheGammaBound() public {
        vm.prank(sequencer);
        vm.expectRevert(
            abi.encodeWithSelector(IAVIPRegistry.FreshnessViolation.selector, GAMMA_N + 1, GAMMA_N)
        );
        registry.postCommitment(1, keccak256("epoch-1"), GAMMA_N + 1);
    }

    function test_postCommitment_genesisRequiresTheWholeTensor() public {
        AVIPRegistry fresh = new AVIPRegistry(sequencer, address(0));
        vm.prank(sequencer);
        vm.expectRevert(abi.encodeWithSelector(IAVIPRegistry.GenesisDelta.selector, N - 1, N));
        fresh.postCommitment(0, keccak256("genesis"), N - 1);
    }

    function test_postCommitment_emitsTheCommitment() public {
        vm.prank(sequencer);
        vm.expectEmit(true, false, false, true, address(registry));
        emit IAVIPRegistry.CommitmentPosted(
            1, keccak256("epoch-1"), GAMMA_N, uint64(block.timestamp)
        );
        registry.postCommitment(1, keccak256("epoch-1"), GAMMA_N);
    }

    // ------------------------------------------------------------ epoch order

    function test_postCommitment_rejectsASkippedEpoch() public {
        vm.prank(sequencer);
        vm.expectRevert(abi.encodeWithSelector(IAVIPRegistry.NonSequentialEpoch.selector, 1, 2));
        registry.postCommitment(2, keccak256("epoch-2"), 1);
    }

    function test_postCommitment_rejectsRePostingAnEpoch() public {
        vm.prank(sequencer);
        vm.expectRevert(abi.encodeWithSelector(IAVIPRegistry.NonSequentialEpoch.selector, 1, 0));
        registry.postCommitment(0, epoch0Root, N);
    }

    function test_unpostedEpochReadsAsEmpty() public view {
        assertEq(registry.commitmentOf(7), bytes32(0));
        assertEq(registry.changedEntriesOf(7), 0);
    }

    function test_latestEpochIsMaxBeforeGenesis() public {
        AVIPRegistry fresh = new AVIPRegistry(sequencer, address(0));
        assertEq(fresh.latestEpoch(), type(uint256).max);
    }

    // --------------------------------------------------------- access control

    function test_postCommitment_rejectsAnUnauthorisedCaller() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IAVIPRegistry.NotSequencer.selector, stranger));
        registry.postCommitment(1, keccak256("epoch-1"), 1);
    }

    function test_postCommitment_rejectsTheZeroRoot() public {
        vm.prank(sequencer);
        vm.expectRevert(IAVIPRegistry.ZeroRoot.selector);
        registry.postCommitment(1, bytes32(0), 1);
    }

    function test_constructor_rejectsTheZeroSequencer() public {
        vm.expectRevert(IAVIPRegistry.ZeroSequencer.selector);
        new AVIPRegistry(address(0), address(0));
    }

    function test_setSequencer_rotatesOnlyThroughTheSequencer() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IAVIPRegistry.NotSequencer.selector, stranger));
        registry.setSequencer(stranger);

        vm.prank(sequencer);
        registry.setSequencer(stranger);
        assertEq(registry.sequencer(), stranger);

        vm.prank(stranger);
        vm.expectRevert(IAVIPRegistry.ZeroSequencer.selector);
        registry.setSequencer(address(0));
    }

    // ------------------------------------------------------- merkle inclusion

    function test_verifyEntry_acceptsTheFullTensorTree() public view {
        for (uint256 i = 0; i < 4; ++i) {
            uint256 index = i == 3 ? N - 1 : i;
            assertTrue(registry.verifyEntry(epoch0Root, tensor[index], epoch0Proofs[index]));
        }
    }

    function test_verifyEntry_rejectsATamperedLeaf() public view {
        bytes32 tampered = keccak256("not-an-entry");
        assertFalse(registry.verifyEntry(epoch0Root, tampered, epoch0Proofs[0]));
    }

    function test_verifyEntry_rejectsAProofFromAnotherLeaf() public view {
        assertFalse(registry.verifyEntry(epoch0Root, tensor[0], epoch0Proofs[1]));
    }

    function test_verifyEntry_rejectsAForeignRoot() public view {
        assertFalse(registry.verifyEntry(keccak256("foreign"), tensor[0], epoch0Proofs[0]));
    }

    function test_verifyEntry_rejectsTheZeroRoot() public view {
        assertFalse(registry.verifyEntry(bytes32(0), tensor[0], epoch0Proofs[0]));
    }

    function test_verifyEntry_singleLeafTree() public view {
        bytes32[] memory one = new bytes32[](1);
        one[0] = keccak256("only");
        bytes32[] memory emptyProof = new bytes32[](0);
        (bytes32 root,) = _buildTree(one);

        assertTrue(registry.verifyEntry(root, one[0], emptyProof));
    }

    function test_verifyEntry_eightLeafTree() public view {
        bytes32[] memory eight = new bytes32[](8);
        for (uint256 i = 0; i < 8; ++i) {
            eight[i] = keccak256(abi.encodePacked(i));
        }
        (bytes32 root, bytes32[][] memory proofs) = _buildTree(eight);

        for (uint256 i = 0; i < 8; ++i) {
            assertTrue(registry.verifyEntry(root, eight[i], proofs[i]), "every leaf must verify");
        }
        assertFalse(registry.verifyEntry(root, eight[3], proofs[4]));
    }

    // ------------------------------------------------------ threshold proofs

    function test_verifyThreshold_forwardsAndRecordsTheProof() public {
        _setVerifier(true);

        assertTrue(registry.verifyThreshold(0, validator, _encodeProof(PROOF_A0, epoch0Root, 0, 3)));
        assertTrue(registry.thresholdProven(0, validator));
    }

    function test_verifyThreshold_propagatesARejection() public {
        _setVerifier(false);

        assertFalse(
            registry.verifyThreshold(0, validator, _encodeProof(PROOF_A0, epoch0Root, 0, 3))
        );
        assertFalse(registry.thresholdProven(0, validator));
    }

    function test_verifyThreshold_emitsTheEvent() public {
        _setVerifier(true);
        bytes memory proof = _encodeProof(PROOF_A0, epoch0Root, 0, 3);

        vm.expectEmit(true, true, false, false, address(registry));
        emit IAVIPRegistry.ThresholdProven(0, validator);
        registry.verifyThreshold(0, validator, proof);
    }

    function test_verifyThreshold_rejectsAProofBoundToAnotherRoot() public {
        _setVerifier(true);

        bytes memory proof = _encodeProof(PROOF_A0, keccak256("another-root"), 0, 3);
        vm.expectRevert(IAVIPRegistry.PublicInputMismatch.selector);
        registry.verifyThreshold(0, validator, proof);
    }

    function test_verifyThreshold_rejectsAProofBoundToAnotherEpoch() public {
        _setVerifier(true);

        bytes memory proof = _encodeProof(PROOF_A0, epoch0Root, 1, 3);
        vm.expectRevert(IAVIPRegistry.PublicInputMismatch.selector);
        registry.verifyThreshold(0, validator, proof);
    }

    function test_verifyThreshold_rejectsTruncatedPublicInputs() public {
        _setVerifier(true);

        vm.expectRevert(IAVIPRegistry.PublicInputMismatch.selector);
        registry.verifyThreshold(0, validator, _encodeProof(PROOF_A0, epoch0Root, 0, 1));
    }

    function test_verifyThreshold_revertsOnAnUnknownEpoch() public {
        _setVerifier(true);

        vm.expectRevert(abi.encodeWithSelector(IAVIPRegistry.UnknownEpoch.selector, 9));
        registry.verifyThreshold(9, validator, _encodeProof(PROOF_A0, epoch0Root, 9, 3));
    }

    function test_verifyThreshold_revertsWithoutAVerifier() public {
        vm.expectRevert(IAVIPRegistry.VerifierNotSet.selector);
        registry.verifyThreshold(0, validator, _encodeProof(PROOF_A0, epoch0Root, 0, 3));
    }

    function test_verifyThreshold_rejectsAZeroValidator() public {
        _setVerifier(true);

        vm.expectRevert(IAVIPRegistry.ZeroValidator.selector);
        registry.verifyThreshold(0, address(0), _encodeProof(PROOF_A0, epoch0Root, 0, 3));
    }

    function test_verifyThreshold_rejectsAReplay() public {
        _setVerifier(true);
        bytes memory proof = _encodeProof(PROOF_A0, epoch0Root, 0, 3);

        assertTrue(registry.verifyThreshold(0, validator, proof));
        vm.expectRevert(
            abi.encodeWithSelector(IAVIPRegistry.ThresholdAlreadyProven.selector, 0, validator)
        );
        registry.verifyThreshold(0, validator, proof);
    }

    // ----------------------------------------------------------------- helpers

    function _setVerifier(bool answer) internal {
        MockThresholdVerifier mock = new MockThresholdVerifier(answer, PROOF_A0);
        vm.prank(sequencer);
        registry.setVerifier(address(mock));
    }

    function _encodeProof(uint256 a0, bytes32 root, uint256 epoch, uint256 inputCount)
        internal
        pure
        returns (bytes memory)
    {
        uint256[2] memory a = [a0, uint256(2)];
        uint256[2][2] memory b = [[uint256(3), uint256(4)], [uint256(5), uint256(6)]];
        uint256[2] memory c = [uint256(7), uint256(8)];
        uint256[] memory publicInputs = new uint256[](inputCount);
        if (inputCount > 0) publicInputs[0] = uint256(root);
        if (inputCount > 1) publicInputs[1] = epoch;
        return abi.encode(a, b, c, publicInputs);
    }

    function _hashLeaf(bytes32 leaf) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(leaf));
    }

    function _hashPair(bytes32 left, bytes32 right) internal pure returns (bytes32) {
        return left < right
            ? keccak256(abi.encodePacked(left, right))
            : keccak256(abi.encodePacked(right, left));
    }

    /// @dev Full binary tree over `leaves`. Odd levels duplicate their last node
    ///      (the same rule the inclusion proof of `AVIPRegistry` assumes).
    ///      `proofs[i]` is the inclusion proof of leaf `i`.
    function _buildTree(bytes32[] memory leaves)
        internal
        pure
        returns (bytes32 root, bytes32[][] memory proofs)
    {
        uint256 n = leaves.length;

        uint256 depth = 0;
        while ((uint256(1) << depth) < n) {
            depth++;
        }

        bytes32[][] memory levels = new bytes32[][](depth + 1);
        bytes32[] memory base = new bytes32[](n);
        for (uint256 i = 0; i < n; ++i) {
            base[i] = _hashLeaf(leaves[i]);
        }
        levels[0] = base;

        for (uint256 d = 0; d < depth; ++d) {
            bytes32[] memory current = levels[d];
            uint256 size = current.length;
            bytes32[] memory next = new bytes32[]((size + 1) / 2);
            for (uint256 p = 0; p < next.length; ++p) {
                bytes32 left = current[2 * p];
                bytes32 right = (2 * p + 1 < size) ? current[2 * p + 1] : left;
                next[p] = _hashPair(left, right);
            }
            levels[d + 1] = next;
        }

        root = levels[depth][0];
        proofs = new bytes32[][](n);
        for (uint256 i = 0; i < n; ++i) {
            bytes32[] memory path = new bytes32[](depth);
            uint256 pos = i;
            for (uint256 d = 0; d < depth; ++d) {
                bytes32[] memory current = levels[d];
                uint256 sibling = pos ^ 1;
                path[d] = (sibling < current.length) ? current[sibling] : current[pos];
                pos /= 2;
            }
            proofs[i] = path;
        }
    }
}
