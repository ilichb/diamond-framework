// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AVIPRegistry} from "../contracts/AVIPRegistry.sol";
import {IAVIPRegistry} from "../contracts/interfaces/IAVIPRegistry.sol";
import {Groth16Verifier} from "../contracts/verifiers/Groth16Verifier.sol";
import {M4dGroth16Fixtures as F} from "./fixtures/M4dGroth16Fixtures.sol";

/// WHAT IS TESTED
/// --------------
/// 1. **A real inclusion proof, not a shaped one.** `M4dGroth16Fixtures.sol` is
///    emitted by `src/zk` (audit 2026-10-20, P-01/P-16) from the seeded
///    development setup over the admission circuit: a Poseidon inclusion tree
///    whose leaves are `Poseidon(validator, norm)`, and a seeded proof for one
///    validator of the deterministic 500-entry fixture. There is a witness.
/// 2. **The statement binds the validator.** `AVIPRegistry.verifyThreshold`
///    builds `[root, epoch, validator, certifiedNorm]` from its own storage and
///    from the address the caller asks about. Changing the address changes a
///    public input, so the proof that admits `STATEMENT_VALIDATOR` cannot be
///    replayed for `STATEMENT_VALIDATOR_OTHER` (P-01).
/// 3. **The two roots have two slots.** The keccak root `verifyEntry` folds and
///    the Poseidon admission root are posted together per epoch, and a proof for
///    epoch 0 is rejected against epoch 1 even when the roots are unchanged
///    (P-16).
/// 4. **The key digest crosses implementations.** `KEY_DIGEST` is
///    `keccak256(abi.encode(vk))` computed in Rust from the ABI layout; the test
///    compares it with the contract's own `verifyingKeyDigest()`.
///
/// WHAT IS NOT TESTED, AND WHY THAT IS THE HONEST BOUNDARY
/// ------------------------------------------------------
/// - **No soundness claim.** The setup is a *development* setup: one phase-2
///   contributor, with `SETUP_SEED` committed in `src/zk`, so the toxic waste is
///   derivable by anyone and forgeries are free.
/// - **No latency claim.** Proving cost is an off-chain observation reported by
///   `src/zk` (4,827 constraints; 0.33 s prove, 0.45 s setup in `--release`).
///   The *on-chain* cost of this statement is measured here, so the fifth `ic`
///   point is priced rather than extrapolated from M3's four-point key.
/// - **No tie between the leaf's norm and the tensor commitment.** The registry
///   sees roots, not entries; `M4dRootSeparation.t.sol` states that boundary and
///   the negative directions it implies.
contract M4dRealKeyTest is Test {
    uint32 internal constant N = 500;

    /// @dev `1.0` in WAD: the circuit's upper bound on a norm is `WAD - 1`.
    uint256 internal constant WAD = 1e18;

    /// @dev Largest norm the framework encodes (`CERTIFIED_BOUND_BITS = 64`).
    uint256 internal constant MAX_NORM = 1 << 64;

    /// @dev Order of the BN254 scalar field `r`, the field the circuit lives in.
    ///      `r - 1` is `-1` there: the norm the one-sided bound lets through.
    uint256 internal constant BN254_R =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    Groth16Verifier internal verifier;
    AVIPRegistry internal registry;
    address internal sequencer;
    /// @dev M9a: the only proposer of a change to `sequencer` or `verifier`.
    address internal guardian;

    address internal validator = address(uint160(F.STATEMENT_VALIDATOR));
    address internal other = address(uint160(F.STATEMENT_VALIDATOR_OTHER));

    function setUp() public {
        verifier = new Groth16Verifier(F.verifyingKey());

        sequencer = makeAddr("sequencer");
        guardian = makeAddr("guardian");
        registry = new AVIPRegistry(sequencer, address(verifier), guardian);

        // Genesis: the registry's own post. The keccak root is deliberately a
        // different value from the admission root -- the two slots are not the
        // same thing, and `verifyThreshold` reads only the latter.
        vm.prank(sequencer);
        registry.postCommitment(0, keccak256("tensor"), F.STATEMENT_ROOT, N);
    }

    /// @dev The blob `AVIPRegistry` decodes: `(a, b, c)`, 256 bytes.
    function proof() internal pure returns (bytes memory) {
        return F.proof();
    }

    // ------------------------------------------------------------- the key

    /// @notice The key is installed by the frozen verifier and publishes the
    ///         digest the Rust emitter computed from the ABI layout.
    function test_theRustKeyDigestMatchesTheContracts() public view {
        assertEq(verifier.numPublicInputs(), 4, "four public inputs");
        assertEq(verifier.icLength(), 5, "four inputs plus the constant term");
        assertEq(verifier.verifyingKeyDigest(), F.KEY_DIGEST);
        assertEq(verifier.verifyingKeyDigest(), keccak256(abi.encode(F.verifyingKey())));
    }

    /// @notice The fixture is the one the off-chain prover measured.
    function test_theFixtureIsTheOneTheOffChainProverMeasured() public pure {
        // The tensor: the anchor `src/zk/scripts/m4a_output.txt` pins.
        assertEq(
            F.TENSOR_DIGEST,
            bytes32(0xc2309377a00b109a6c44d83a5cc759108977ffe207fba6f83215a9cdf77d9aa9)
        );
        assertEq(F.STATEMENT_EPOCH, 0);
        assertEq(
            F.STATEMENT_VALIDATOR, uint256(uint160(0x4C59cFabfc842b37cF6FC9c2301446e584cd01Af))
        );
        assertEq(F.STATEMENT_NORM, 665_564_939_881_284_858);
        assertTrue(F.STATEMENT_ROOT != 0);
    }

    // ------------------------------------------------------------ the proof

    /// @notice `Groth16Verifier` accepts the real proof for the four-element
    ///         statement the fixture carries.
    function test_theRealProofVerifies() public view {
        uint256[] memory statement = F.statement();
        assertEq(statement.length, 4);
        assertEq(statement[0], F.STATEMENT_ROOT);
        assertEq(statement[1], F.STATEMENT_EPOCH);
        assertEq(statement[2], F.STATEMENT_VALIDATOR);
        assertEq(statement[3], F.STATEMENT_NORM);

        assertTrue(
            verifier.verify(F.proofA(), F.proofB(), F.proofC(), statement),
            "the real Groth16 proof must satisfy the pairing equation"
        );
    }

    /// @notice The integration the registry owns: it builds the statement from
    ///         its own storage and the address under test, and the frozen
    ///         verifier accepts the proof. `view`, so idempotent.
    function test_theRegistryAcceptsTheProofEndToEnd() public view {
        assertEq(registry.commitmentOf(0), keccak256("tensor"));
        assertEq(registry.statementRootOf(0), F.STATEMENT_ROOT);

        assertTrue(registry.verifyThreshold(0, validator, F.STATEMENT_NORM, proof()));
        assertTrue(registry.verifyThreshold(0, validator, F.STATEMENT_NORM, proof()));
    }

    /// @notice The norm's encoding, restated at the registry (P-13, P-33).
    ///         `admission.rs` bounds `norm` from above only — `WAD - norm - 1 <
    ///         2^60` also admits a norm within `2^60` of the modulus — and
    ///         `certifiedNorm` is a `uint256` that `Bn254.ecMul` reduces modulo
    ///         the group order. Both families are refused before the blob is
    ///         decoded; the circuit's own `< WAD` is left to the pairing.
    function test_aNormTheFrameworkCannotEncodeIsRejected() public {
        // P-13: `c + k * r` is the same scalar as `c`, so the pairing would
        // accept a proof for `c` with this word.
        uint256 malleated = BN254_R;
        vm.expectRevert(abi.encodeWithSelector(IAVIPRegistry.NormOutOfDomain.selector, malleated));
        registry.verifyThreshold(0, validator, malleated, proof());

        // P-33: `-1` in the scalar field, the value the one-sided circuit check
        // lets through.
        uint256 minusOne = BN254_R - 1;
        vm.expectRevert(abi.encodeWithSelector(IAVIPRegistry.NormOutOfDomain.selector, minusOne));
        registry.verifyThreshold(0, validator, minusOne, proof());

        // The encoding bound, exactly: `2^64` is out (`CERTIFIED_BOUND_BITS`).
        vm.expectRevert(abi.encodeWithSelector(IAVIPRegistry.NormOutOfDomain.selector, MAX_NORM));
        registry.verifyThreshold(0, validator, MAX_NORM, proof());

        // `WAD` is in range: `< WAD` belongs to the circuit, not to the registry,
        // so the word reaches the pairing and fails as a verdict.
        assertFalse(registry.verifyThreshold(0, validator, WAD, proof()));
    }

    /// @notice Each component of the statement, changed *alone*, flips the
    ///         answer: the proof is bound to all four, not to some of them.
    function test_everyStatementComponentIsBound() public view {
        uint256[] memory statement = F.statement();

        statement[0] = F.STATEMENT_ROOT + 1;
        assertFalse(verifier.verify(F.proofA(), F.proofB(), F.proofC(), statement));

        statement[0] = F.STATEMENT_ROOT;
        statement[1] = F.STATEMENT_EPOCH + 1;
        assertFalse(verifier.verify(F.proofA(), F.proofB(), F.proofC(), statement));

        statement[1] = F.STATEMENT_EPOCH;
        statement[2] = F.STATEMENT_VALIDATOR + 1;
        assertFalse(verifier.verify(F.proofA(), F.proofB(), F.proofC(), statement));

        statement[2] = F.STATEMENT_VALIDATOR;
        statement[3] = F.STATEMENT_NORM + 1;
        assertFalse(verifier.verify(F.proofA(), F.proofB(), F.proofC(), statement));
    }

    /// @notice P-01: the bearer-token replay. The proof is made for `validator`;
    ///         asking the registry about `other` changes public input 2 and the
    ///         answer is `false`, even though `other` has a valid proof of its
    ///         own elsewhere.
    function test_aProofForOneValidatorDoesNotAdmitAnother() public view {
        assertTrue(registry.verifyThreshold(0, validator, F.STATEMENT_NORM, proof()));
        assertFalse(registry.verifyThreshold(0, other, F.STATEMENT_NORM, proof()));
        assertFalse(registry.verifyThreshold(0, address(0xBEEF), F.STATEMENT_NORM, proof()));

        // The other validator's proof is bound to its own norm as well.
        assertTrue(registry.verifyThreshold(0, other, F.STATEMENT_NORM_OTHER, F.proofOther()));
        assertFalse(registry.verifyThreshold(0, validator, F.STATEMENT_NORM_OTHER, F.proofOther()));
    }

    /// @notice P-16: the epoch is bound, and it is bound to the same post as the
    ///         statement root. Reposting the same roots at epoch 1 does not make
    ///         the epoch-0 proof valid there.
    function test_theSameRootAtTheNextEpochIsRejected() public {
        vm.prank(sequencer);
        registry.postCommitment(1, keccak256("tensor"), F.STATEMENT_ROOT, 1);

        assertTrue(registry.verifyThreshold(0, validator, F.STATEMENT_NORM, proof()));
        assertFalse(registry.verifyThreshold(1, validator, F.STATEMENT_NORM, proof()));
    }

    /// @notice The registry's own path rejects a norm the proof did not certify,
    ///         in both directions.
    function test_theRegistryRejectsATamperedNorm() public view {
        assertFalse(registry.verifyThreshold(0, validator, F.STATEMENT_NORM + 1, proof()));
        assertFalse(registry.verifyThreshold(0, validator, F.STATEMENT_NORM - 1, proof()));
    }

    // ------------------------------------------------------------------ cost

    /// @notice The four-input statement pays one more `ic` scalar multiplication
    ///         than V3's three-input one. Logged and bounded, so the figure the
    ///         plan quotes comes from a test rather than from memory.
    function test_theAdmissionVerificationCostsFiveIcPoints() public {
        // The first call is the cold path: it pays the cold account and storage
        // touches, which is the convention the v0.2.1 note uses for 286,144 gas.
        uint256 coldBefore = gasleft();
        bool coldAccepted = registry.verifyThreshold(0, validator, F.STATEMENT_NORM, proof());
        uint256 cold = coldBefore - gasleft();
        emit log_named_uint("verifyThreshold (4 inputs, cold) gas", cold);

        // Warm now, for the figure that does not include first-touch charges.
        uint256 before = gasleft();
        bool accepted = registry.verifyThreshold(0, validator, F.STATEMENT_NORM, proof());
        uint256 throughRegistry = before - gasleft();
        emit log_named_uint("verifyThreshold (4 inputs, warm) gas", throughRegistry);

        // The verifier alone, the figure comparable with M3's 223,445: same key
        // and proof, without the registry's statement build and storage reads.
        uint256 beforeVerify = gasleft();
        bool direct = verifier.verify(F.proofA(), F.proofB(), F.proofC(), F.statement());
        uint256 verifierOnly = beforeVerify - gasleft();
        emit log_named_uint("Groth16Verifier.verify (5 ic) gas", verifierOnly);

        assertTrue(coldAccepted && accepted && direct);
        assertGt(cold, throughRegistry, "the cold path pays the first touches");
        assertGt(verifierOnly, 181_000, "the four pairings alone");
        assertLt(verifierOnly, 300_000);
        assertLt(throughRegistry, 320_000, "one IC point above the three-input path");
    }
}
