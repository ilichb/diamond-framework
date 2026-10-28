// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// TEMPORARY PROBE — kept here as evidence, not as part of the suite.
//
// Copied to `integrations/avalanche/test/`, run, and deleted, exactly as the
// audit's own PoCs were: a test file in that directory is not in the anchor, so
// nothing had to be re-sealed. Its imports are the ones it had while there.
//
// It answers one question for `docs/paper/releases/v0.2.3-errata.md` (E-01):
// which key and statement produced the paper's 286,144 gas.

import {Test} from "forge-std/Test.sol";
import {AVIPRegistry} from "../contracts/AVIPRegistry.sol";
import {Groth16Verifier} from "../contracts/verifiers/Groth16Verifier.sol";
import {M4bGroth16Fixtures as V3} from "./fixtures/M4bGroth16Fixtures.sol";
import {M4dGroth16Fixtures as M4d} from "./fixtures/M4dGroth16Fixtures.sol";

contract TmpV3ColdPathTest is Test {
    function test_thePaperFigureIsV3sKeyAndNotTodays() public {
        Groth16Verifier v3 = new Groth16Verifier(V3.verifyingKey());
        Groth16Verifier m4dVerifier = new Groth16Verifier(M4d.verifyingKey());

        emit log_named_uint("V3 numPublicInputs", v3.numPublicInputs());
        emit log_named_uint("V3 icLength", v3.icLength());
        emit log_named_uint("M4d numPublicInputs", m4dVerifier.numPublicInputs());
        emit log_named_uint("M4d icLength", m4dVerifier.icLength());

        _measureV3(v3);
        _measureM4d(m4dVerifier);
        _registryRejectsV3Key(v3);
    }

    /// @dev Cold then warm, the convention the v0.2.1 note uses for 286,144.
    function _measureV3(Groth16Verifier v3) internal {
        uint256 t0 = gasleft();
        bool coldOk = v3.verify(V3.proofA(), V3.proofB(), V3.proofC(), V3.statement());
        uint256 cold = t0 - gasleft();

        uint256 t1 = gasleft();
        bool warmOk = v3.verify(V3.proofA(), V3.proofB(), V3.proofC(), V3.statement());
        uint256 warm = t1 - gasleft();

        emit log_named_uint("V3 verify (3 inputs, cold) gas", cold);
        emit log_named_uint("V3 verify (3 inputs, warm) gas", warm);
        assertTrue(coldOk && warmOk, "V3's own proof verifies under V3's key");
    }

    function _measureM4d(Groth16Verifier m4dVerifier) internal {
        uint256 t0 = gasleft();
        bool coldOk = m4dVerifier.verify(M4d.proofA(), M4d.proofB(), M4d.proofC(), M4d.statement());
        uint256 cold = t0 - gasleft();

        uint256 t1 = gasleft();
        bool warmOk = m4dVerifier.verify(M4d.proofA(), M4d.proofB(), M4d.proofC(), M4d.statement());
        uint256 warm = t1 - gasleft();

        emit log_named_uint("M4d verify (4 inputs, cold) gas", cold);
        emit log_named_uint("M4d verify (4 inputs, warm) gas", warm);
        assertTrue(coldOk && warmOk, "M4d's own proof verifies under M4d's key");
    }

    /// @dev The registry builds FOUR public inputs today. A three-input key
    ///      cannot be the one behind 286,144 unless the contract also changed.
    function _registryRejectsV3Key(Groth16Verifier v3) internal {
        address sequencer = makeAddr("sequencer");
        AVIPRegistry registry = new AVIPRegistry(
            sequencer,
            address(v3),
            makeAddr("guardian"),
            keccak256("avalanche-c-chain"),
            keccak256("AVIP/fragment-function/v1")
        );
        vm.prank(sequencer);
        registry.postCommitment(
            0,
            keccak256("tensor"),
            V3.STATEMENT_ROOT,
            500,
            keccak256("avalanche-c-chain"),
            keccak256("AVIP/fragment-function/v1")
        );

        vm.expectRevert(abi.encodeWithSelector(Groth16Verifier.PublicInputsMismatch.selector, 3, 4));
        registry.verifyThreshold(
            0,
            address(uint160(V3.STATEMENT_NORM % type(uint160).max)),
            V3.STATEMENT_NORM,
            V3.proof()
        );
    }
}
