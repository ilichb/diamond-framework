// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AVIPMessageCodec} from "../contracts/AVIPMessageCodec.sol";
import {AVIPRegistry} from "../contracts/AVIPRegistry.sol";
import {Groth16Verifier} from "../contracts/verifiers/Groth16Verifier.sol";
import {M4dGroth16Fixtures as F4d} from "./fixtures/M4dGroth16Fixtures.sol";
import {M7cBridgeFixtures as F7c} from "./fixtures/M7cBridgeFixtures.sol";

/// WHAT IS TESTED
/// --------------
/// P-16 says one `_roots[epoch]` could not be both the Poseidon root admission
/// consumes and the keccak root `verifyEntry` folds. The remediation is **two
/// slots in one registry**, written by one `postCommitment` -- not two
/// deployments and not a convention about not mixing them. This suite holds the
/// registry to that reading, with the two *real* roots of one epoch:
///
/// 1. **One instance serves both legs.** `commitmentOf(0) == F7c.MERKLE_ROOT`
///    (M1's fold, the root a commitment announcement carries) and
///    `statementRootOf(0) == F4d.STATEMENT_ROOT` (the admission tree), posted in
///    the same transaction, and the admission proof verifies from that storage.
/// 2. **The admission proof does not verify against the tensor statement root.**
///    An epoch posted with M7c's roots cannot admit the M4d proof: the two
///    statements are different circuits and different values.
/// 3. **Swapping the slots breaks both legs.** With M4d's root in the keccak slot
///    the fold is not M1's, and with M7c's root in the statement slot the proof
///    fails; neither direction is silently tolerated.
/// 4. **The relay link names the tensor statement root.** `linkDigest` is
///    injective in its three words, so substituting the admission root in either
///    position -- or moving the epoch -- recomputes away from M7c's pinned
///    `LINK`. A peer checking an announcement against that link rejects an
///    admission root in the relay's message.
/// 5. **The two fixtures are one tensor, two quantities.** `TENSOR_DIGEST` is the
///    same `c2309377…` in both, but `CERTIFIED_NORM` is `‖T‖₂` over the 500
///    entries (`12.79…`, M4b's global statement) while `STATEMENT_NORM` is one
///    entry (`0.6655…`, the per-validator scalar M4d's leaf commits to). They are
///    not two spellings of one number, and the suite says so with both.
///
/// WHAT IS NOT TESTED, AND WHY THAT IS THE HONEST BOUNDARY
/// ------------------------------------------------------
/// - **No on-chain tie between the two roots.** `postCommitment` takes both from
///   the sequencer; the registry never sees the entries and cannot recompute
///   either root, so "they came from one entry set" is an assertion, not a
///   proof. What the admission proof buys is membership of `(validator, norm)`
///   in the tree whose root was posted, plus the validator and epoch bindings;
///   it does not buy "this norm is the tensor's entry" beyond the publisher
///   having built both trees from one epoch. The fixture is coherent because both
///   sides read `fixture::tensor()` and `TENSOR_DIGEST` is pinned, which is a
///   reproducibility property, not an on-chain one.
/// - **No soundness claim.** The key is a development key with committed seeds
///   (`SETUP_SEED`, `PROOF_SEED`), so anyone can forge; §11 holds the ceremony.
/// - **No claim that the per-validator norm is the paper's `‖T‖_F`.** That is
///   audit P-03, and this suite pins the two numbers instead of blending them.
contract M4dRootSeparationTest is Test {
    uint32 internal constant N = 500;

    Groth16Verifier internal verifier;
    AVIPRegistry internal registry;
    address internal sequencer;
    /// @dev M9a: the only proposer of a change to `sequencer` or `verifier`.
    address internal guardian;

    address internal validator = address(uint160(F4d.STATEMENT_VALIDATOR));

    function setUp() public {
        verifier = new Groth16Verifier(F4d.verifyingKey());

        sequencer = makeAddr("sequencer");
        guardian = makeAddr("guardian");
        registry = new AVIPRegistry(
            sequencer,
            address(verifier),
            guardian,
            keccak256("avalanche-c-chain"),
            keccak256("AVIP/fragment-function/v1")
        );

        // One post, both roots, one epoch: M1's fold of the tensor and M4d's
        // admission tree. This is the deployment P-16's remediation describes.
        vm.prank(sequencer);
        registry.postCommitment(
            F7c.EPOCH,
            F7c.MERKLE_ROOT,
            F4d.STATEMENT_ROOT,
            N,
            keccak256("avalanche-c-chain"),
            keccak256("AVIP/fragment-function/v1")
        );
    }

    /// @dev A registry that committed a chosen pair, for the negative cases.
    function registryWith(bytes32 commitment, uint256 statementRoot)
        internal
        returns (AVIPRegistry made)
    {
        made = new AVIPRegistry(
            sequencer,
            address(verifier),
            guardian,
            keccak256("avalanche-c-chain"),
            keccak256("AVIP/fragment-function/v1")
        );
        vm.prank(sequencer);
        made.postCommitment(
            F7c.EPOCH,
            commitment,
            statementRoot,
            N,
            keccak256("avalanche-c-chain"),
            keccak256("AVIP/fragment-function/v1")
        );
    }

    // ------------------------------------------------- the two slots, one post

    /// @notice The real pair, in one instance: the relay's root and the admission
    ///         root coexist, and each leg reads its own slot.
    function test_oneInstanceCarriesBothLegsOfTheSameEpoch() public view {
        assertEq(registry.commitmentOf(F7c.EPOCH), F7c.MERKLE_ROOT, "M1's fold");
        assertEq(registry.statementRootOf(F7c.EPOCH), F4d.STATEMENT_ROOT, "the admission tree");
        assertTrue(registry.commitmentOf(F7c.EPOCH) != bytes32(F4d.STATEMENT_ROOT));

        assertTrue(registry.verifyThreshold(F7c.EPOCH, validator, F4d.STATEMENT_NORM, F4d.proof()));
    }

    /// @notice The admission proof is bound to its own statement root: an epoch
    ///         that committed M7c's statement root cannot admit anyone with it.
    function test_theAdmissionProofDoesNotVerifyAgainstTheTensorsStatementRoot() public {
        AVIPRegistry relayOnly = registryWith(F7c.MERKLE_ROOT, F7c.STATEMENT_ROOT);

        assertFalse(
            relayOnly.verifyThreshold(F7c.EPOCH, validator, F4d.STATEMENT_NORM, F4d.proof())
        );
    }

    /// @notice The old shape, one value for both meanings, fails in both
    ///         directions -- which is exactly what P-16 reported.
    function test_swappingTheSlotsBreaksBothLegs() public {
        AVIPRegistry swapped = registryWith(bytes32(F4d.STATEMENT_ROOT), F7c.STATEMENT_ROOT);

        // The admission leg fails: the statement slot does not hold the tree
        // root the proof was made against.
        assertFalse(swapped.verifyThreshold(F7c.EPOCH, validator, F4d.STATEMENT_NORM, F4d.proof()));

        // The relay leg fails too: the keccak slot is not M1's fold, so the link
        // an announcement would recompute is not the one M7c published.
        assertTrue(swapped.commitmentOf(F7c.EPOCH) != F7c.MERKLE_ROOT);
        assertTrue(
            AVIPMessageCodec.linkDigest(
                swapped.commitmentOf(F7c.EPOCH), swapped.statementRootOf(F7c.EPOCH), F7c.EPOCH
            ) != F7c.LINK
        );
    }

    // ------------------------------------------------------------ the relay

    /// @notice `linkDigest` names *the tensor's* statement root, so an
    ///         announcement carrying the admission root -- in either word -- is
    ///         not the link M7c pinned.
    function test_theRelayLinkNamesTheTensorStatementRoot() public pure {
        assertEq(
            AVIPMessageCodec.linkDigest(F7c.MERKLE_ROOT, F7c.STATEMENT_ROOT, F7c.EPOCH), F7c.LINK
        );

        // Admission root where M1's fold belongs.
        assertTrue(
            AVIPMessageCodec.linkDigest(bytes32(F4d.STATEMENT_ROOT), F7c.STATEMENT_ROOT, F7c.EPOCH)
                != F7c.LINK
        );
        // Admission root where the tensor's statement root belongs.
        assertTrue(
            AVIPMessageCodec.linkDigest(F7c.MERKLE_ROOT, F4d.STATEMENT_ROOT, F7c.EPOCH) != F7c.LINK
        );
        // And the epoch is positional, not decoration.
        assertTrue(
            AVIPMessageCodec.linkDigest(F7c.MERKLE_ROOT, F7c.STATEMENT_ROOT, F7c.EPOCH + 1)
                != F7c.LINK
        );
    }

    // ------------------------------------------- two numbers, not one

    /// @notice Both fixtures are over the one committed tensor, but the quantity
    ///         each statement carries is different: M4b/M7c certify `‖T‖₂` over
    ///         the 500 entries, M4d certifies one validator's entry. Pinned here
    ///         so a reader cannot take one for the other (audit P-03).
    function test_theTwoStatementsCarryDifferentQuantitiesOfOneTensor() public pure {
        assertEq(F4d.TENSOR_DIGEST, F7c.TENSOR_DIGEST, "one tensor");
        assertEq(F4d.STATEMENT_NORM, 665_564_939_881_284_858, "entry 4");
        assertEq(F7c.CERTIFIED_NORM, 12_793_810_215_743_475_835, "||T||_2 over 500 entries");
        assertLt(F4d.STATEMENT_NORM, F7c.CERTIFIED_NORM);
    }

    // --------------------------------------------- the documented residual

    /// @notice The boundary, encoded rather than implied: nothing in the registry
    ///         relates the statement root to the commitment, so a sequencer can
    ///         post a well-formed root that no tensor produced. The post succeeds
    ///         and the admission silently stops verifying. This is the trust the
    ///         data layer and §7 already carry; it is not a bug in P-16, and the
    ///         test exists so that a future change cannot claim otherwise.
    function test_noOnChainTieBetweenTheTwoRoots() public {
        AVIPRegistry lying = registryWith(F7c.MERKLE_ROOT, F4d.STATEMENT_ROOT + 1);

        assertFalse(lying.verifyThreshold(F7c.EPOCH, validator, F4d.STATEMENT_NORM, F4d.proof()));
    }
}
