// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AVIPRegistry} from "../contracts/AVIPRegistry.sol";
import {Groth16Verifier} from "../contracts/verifiers/Groth16Verifier.sol";
import {M4bGroth16Fixtures as F} from "./fixtures/M4bGroth16Fixtures.sol";

/// WHAT IS TESTED
/// --------------
/// 1. **A real proof, not a shaped one.** `M4bGroth16Fixtures.sol` is emitted by
///    `src/zk` (milestone M4b, `docs/architecture/implementation-plan.md` 5.5.4)
///    from the seeded development setup over the V3 circuit -- Poseidon
///    commitment plus floor norm -- and a seeded proof for the deterministic
///    500-entry fixture of 5.5.6. There is a witness; this is not the M3
///    synthetic instance and it is not solved for.
/// 2. **The frozen contracts accept it, unchanged.** `Groth16Verifier` is built
///    with the real key and returns `true` for it; `AVIPRegistry.verifyThreshold`
///    builds `[root, epoch, certifiedNorm]` from its *own* storage and returns
///    `true`. No contract in `contracts/` was edited to make this pass.
/// 3. **Every component of the statement is bound.** The root, the certified
///    norm and the epoch each flip the answer to `false`. The epoch is the one
///    worth stating: an unused public input would have the identity as its
///    `gamma_abc_g1` entry and would be ignored, so `test_theEpochIsBound` posts
///    the *same* root at epoch 1 and asserts rejection.
/// 4. **The key digest crosses implementations.** `M4bGroth16Fixtures.KEY_DIGEST`
///    is `keccak256(abi.encode(vk))` computed in Rust from the ABI layout; the
///    test compares it with the contract's own `verifyingKeyDigest()`, so a
///    disagreement between the two encoders fails loudly instead of silently.
///
/// WHAT IS NOT TESTED, AND WHY THAT IS THE HONEST BOUNDARY
/// ------------------------------------------------------
/// - **No soundness claim, and this is the important one.** The setup is a
///   *development* setup: one phase-2 contributor, with `SETUP_SEED` committed in
///   `src/zk`, so the toxic waste is derivable by anyone and forgeries are free.
///   What is demonstrated is that the pipeline runs end to end and what it costs
///   (5.5.4); the ceremony that would carry a claim is out of M4's scope (11).
/// - **The statement's root is the Poseidon commitment of the tensor, not its
///   Merkle root.** This test posts the Poseidon value as the registry's root,
///   which shows the arithmetic end to end; tying the two roots together is the
///   Pedersen/Merkle bridge, gap A7, milestone M7 (5.5.7). Nothing here says the
///   committed tensor is the one the entries describe.
/// - **No gas or latency claim**: M3 measures the verification cost
///   (`Groth16Verifier.t.sol`); M4b's proving cost is an off-chain observation
///   reported by `src/zk/scripts/m4b_report.sh`.
/// - **No adversarial-key test**: soundness against a malicious key is a
///   property of the ceremony, not of this wrapper.
contract M4bRealKeyTest is Test {
    uint32 internal constant N = 500;

    Groth16Verifier internal verifier;
    AVIPRegistry internal registry;
    address internal sequencer;
    /// @dev M9a: the only proposer of a change to `sequencer` or `verifier`. This
    ///      suite never changes either role, but the registry refuses a zero
    ///      guardian, so every construction names one.
    address internal guardian;

    function setUp() public {
        verifier = new Groth16Verifier(F.verifyingKey());

        sequencer = makeAddr("sequencer");
        guardian = makeAddr("guardian");
        registry = new AVIPRegistry(sequencer, address(verifier), guardian);

        // Genesis: the registry's own post, with the root the proof certifies.
        vm.prank(sequencer);
        registry.postCommitment(0, bytes32(F.STATEMENT_ROOT), N);
    }

    /// @dev The blob `AVIPRegistry` decodes: `(a, b, c)`, 256 bytes.
    function proof() internal pure returns (bytes memory) {
        return F.proof();
    }

    // ------------------------------------------------------------- the key

    /// @notice The real key installs and the placeholder's shape holds: three
    ///         public inputs, so `ic.length == 4`.
    function test_theKeyIsInstalledWithTheContractsInputCount() public view {
        assertEq(verifier.icLength(), 4);
        assertEq(verifier.numPublicInputs(), 3);
        assertEq(verifier.alpha1()[0], F.verifyingKey().alpha1[0]);
        assertEq(verifier.icAt(3)[1], F.verifyingKey().ic[3][1]);
        assertEq(verifier.verifyingKeyDigest(), F.KEY_DIGEST);
        assertEq(verifier.verifyingKeyDigest(), keccak256(abi.encode(F.verifyingKey())));
    }

    /// @notice Two hypotheses about the fixture, both checkable at a glance.
    function test_theFixtureIsTheOneTheOffChainProverMeasured() public pure {
        // The tensor: the anchor `src/zk/scripts/m4a_output.txt` pins.
        assertEq(
            F.TENSOR_DIGEST,
            bytes32(0xc2309377a00b109a6c44d83a5cc759108977ffe207fba6f83215a9cdf77d9aa9)
        );
        // The statement: epoch 0, and `floor(sqrt(sum T_i^2))` in WAD (5.5.1).
        assertEq(F.STATEMENT_EPOCH, 0);
        assertEq(F.STATEMENT_NORM, 12_793_810_215_743_475_835);
        assertTrue(F.STATEMENT_ROOT != 0);
    }

    // ------------------------------------------------------------ the proof

    /// @notice `Groth16Verifier` accepts the real proof for the statement the
    ///         fixture carries, and the statement is the caller's: the registry's
    ///         own `statement` shape, three elements.
    function test_theRealProofVerifies() public view {
        uint256[] memory statement = F.statement();
        assertEq(statement.length, 3);
        assertEq(statement[0], F.STATEMENT_ROOT);
        assertEq(statement[1], F.STATEMENT_EPOCH);
        assertEq(statement[2], F.STATEMENT_NORM);

        assertTrue(
            verifier.verify(F.proofA(), F.proofB(), F.proofC(), statement),
            "the real Groth16 proof must satisfy the pairing equation"
        );
    }

    /// @notice The integration 5.5.6 asks for: the registry builds the statement
    ///         itself -- the caller passes only the epoch and the norm -- and the
    ///         frozen verifier accepts the proof. `view`, so idempotent.
    function test_theRegistryAcceptsTheProofEndToEnd() public view {
        assertEq(registry.commitmentOf(0), bytes32(F.STATEMENT_ROOT));
        assertTrue(registry.verifyThreshold(0, F.STATEMENT_NORM, proof()));
        assertTrue(registry.verifyThreshold(0, F.STATEMENT_NORM, proof()));
    }

    // ---------------------------------------------------- the binding

    /// @notice Each component of the statement, changed *alone*, flips the
    ///         answer: the proof is bound to all three, not to some of them.
    function test_everyStatementComponentIsBound() public view {
        uint256[] memory statement = F.statement();

        statement[0] = F.STATEMENT_ROOT + 1;
        assertFalse(verifier.verify(F.proofA(), F.proofB(), F.proofC(), statement));

        statement[0] = F.STATEMENT_ROOT;
        statement[1] = F.STATEMENT_EPOCH + 1;
        assertFalse(verifier.verify(F.proofA(), F.proofB(), F.proofC(), statement));

        statement[1] = F.STATEMENT_EPOCH;
        statement[2] = F.STATEMENT_NORM + 1;
        assertFalse(verifier.verify(F.proofA(), F.proofB(), F.proofC(), statement));
    }

    /// @notice The sharpest one, and the reason `epoch` is constrained in the
    ///         circuit rather than merely declared. An *unused* public input has
    ///         the identity as its `gamma_abc_g1` entry, so the pairing equation
    ///         ignores its value entirely: the epoch-0 proof would then verify at
    ///         any epoch the registry had a root for. It does not.
    function test_theSameRootAtTheNextEpochIsRejected() public {
        // The root does not change, so only the epoch differs.
        vm.prank(sequencer);
        registry.postCommitment(1, bytes32(F.STATEMENT_ROOT), 1);

        assertTrue(registry.verifyThreshold(0, F.STATEMENT_NORM, proof()));
        assertFalse(registry.verifyThreshold(1, F.STATEMENT_NORM, proof()));
    }

    /// @notice The registry's own path rejects a norm the proof did not certify,
    ///         in both directions.
    function test_theRegistryRejectsATamperedNorm() public view {
        assertFalse(registry.verifyThreshold(0, F.STATEMENT_NORM + 1, proof()));
        assertFalse(registry.verifyThreshold(0, F.STATEMENT_NORM - 1, proof()));
    }
}
