// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AVIPRegistry} from "../contracts/AVIPRegistry.sol";
import {AVIPValidatorManager} from "../contracts/AVIPValidatorManager.sol";
import {Groth16Verifier} from "../contracts/verifiers/Groth16Verifier.sol";
import {M4dGroth16Fixtures as F} from "./fixtures/M4dGroth16Fixtures.sol";

/// @dev TEMPORARY probe for errata E-01: what `manager.admit` costs on the
///      current commit with the key the registry actually installs. Deleted
///      after the numbers are recorded in
///      `docs/audit/evidence/2026-10-28-v3-vs-m4d-gas/`; it is not a test of
///      behaviour, so it must not survive as one.
///
///      Conventions, stated because gas numbers are meaningless without them:
///      - `admit` cold = the first call to the manager in its transaction, so it
///        pays the cold account access and the first storage writes, which is the
///        convention `main.tex` uses for 286,144;
///      - `admit` warm = a second admission of a *different* validator in the same
///        transaction: code and the registry's epoch slots are warm, the new
///        validator's own slots are not;
///      - both are call-level (`gasleft()` around the external call), excluding
///        the 21,000 intrinsic and the calldata, same as 286,144 and 306,275.
/// @dev Second contract in this file, deliberately identical to
///      `M4dRealKeyTest.setUp` (no manager deployed) and to its cost test, to
///      bisect the 35-gas difference against the probe above. If this reports
///      306,253, the delta is caused by something the probe's `setUp` adds.
contract TmpMirrorNoManagerTest is Test {
    uint32 internal constant N = 500;

    Groth16Verifier internal verifier;
    AVIPRegistry internal registry;
    address internal sequencer;
    address internal guardian;
    address internal validator = address(uint160(F.STATEMENT_VALIDATOR));

    function setUp() public {
        verifier = new Groth16Verifier(F.verifyingKey());
        sequencer = makeAddr("sequencer");
        guardian = makeAddr("guardian");
        registry = new AVIPRegistry(
            sequencer,
            address(verifier),
            guardian,
            keccak256("avalanche-c-chain"),
            keccak256("AVIP/fragment-function/v1")
        );
        vm.prank(sequencer);
        registry.postCommitment(
            0,
            keccak256("tensor"),
            F.STATEMENT_ROOT,
            N,
            keccak256("avalanche-c-chain"),
            keccak256("AVIP/fragment-function/v1")
        );
    }

    function test_mirrorWithoutManager() public {
        uint256 coldBefore = gasleft();
        bool ok = registry.verifyThreshold(0, validator, F.STATEMENT_NORM, F.proof());
        uint256 cold = coldBefore - gasleft();
        emit log_named_uint("no-manager mirror: verifyThreshold cold", cold);
        assertTrue(ok);
    }

    /// @dev The only remaining difference with `M4dRealKeyTest`: that file builds
    ///      the blob through an internal helper (`proof()`), which runs inside
    ///      the measured window. Same fixture, one extra internal call.
    function proofViaHelper() internal pure returns (bytes memory) {
        return F.proof();
    }

    function test_mirrorWithHelper() public {
        uint256 coldBefore = gasleft();
        bool ok = registry.verifyThreshold(0, validator, F.STATEMENT_NORM, proofViaHelper());
        uint256 cold = coldBefore - gasleft();
        emit log_named_uint("helper mirror: verifyThreshold cold", cold);
        assertTrue(ok);
    }

    /// @dev Same call, but the caller's frame has already allocated memory. If
    ///      this figure moves, the 35-gas spread is caller-side accounting
    ///      (ABI-encode buffers), not a difference inside the registry.
    function test_mirrorWithCallerMemory() public {
        bytes memory pad = new bytes(0x400);
        pad[0] = 0x01;

        uint256 before = gasleft();
        bool ok = registry.verifyThreshold(0, validator, F.STATEMENT_NORM, F.proof());
        uint256 cold = before - gasleft();
        emit log_named_uint("padded mirror: verifyThreshold cold", cold);
        assertTrue(ok);
        assertEq(pad.length, 0x400);
    }
}

contract TmpManagerAdmitM4dTest is Test {
    uint32 internal constant N = 500;

    Groth16Verifier internal verifier;
    AVIPRegistry internal registry;
    AVIPValidatorManager internal manager;

    address internal sequencer;
    address internal guardian;
    address internal slashAuthority;

    address internal validator = address(uint160(F.STATEMENT_VALIDATOR));
    address internal other = address(uint160(F.STATEMENT_VALIDATOR_OTHER));

    function setUp() public {
        verifier = new Groth16Verifier(F.verifyingKey());

        sequencer = makeAddr("sequencer");
        guardian = makeAddr("guardian");
        slashAuthority = makeAddr("slashAuthority");

        registry = new AVIPRegistry(
            sequencer,
            address(verifier),
            guardian,
            keccak256("avalanche-c-chain"),
            keccak256("AVIP/fragment-function/v1")
        );

        vm.prank(sequencer);
        registry.postCommitment(
            0,
            keccak256("tensor"),
            F.STATEMENT_ROOT,
            N,
            keccak256("avalanche-c-chain"),
            keccak256("AVIP/fragment-function/v1")
        );

        manager = new AVIPValidatorManager(address(registry), slashAuthority, address(0));
    }

    /// @notice Mirror of `M4dRealKey.t.sol`'s cost test, in this contract, to
    ///         find out whether the 306,218/306,253 delta is the callee or the
    ///         caller. Same body, same order, no extra state read.
    function test_mirrorTheM4dCostTest() public {
        uint256 coldBefore = gasleft();
        bool coldAccepted = registry.verifyThreshold(0, validator, F.STATEMENT_NORM, F.proof());
        uint256 cold = coldBefore - gasleft();
        emit log_named_uint("mirror: verifyThreshold cold", cold);

        uint256 before = gasleft();
        bool accepted = registry.verifyThreshold(0, validator, F.STATEMENT_NORM, F.proof());
        uint256 warm = before - gasleft();
        emit log_named_uint("mirror: verifyThreshold warm", warm);

        uint256 beforeVerify = gasleft();
        bool direct = verifier.verify(F.proofA(), F.proofB(), F.proofC(), F.statement());
        uint256 verifierOnly = beforeVerify - gasleft();
        emit log_named_uint("mirror: Groth16Verifier.verify", verifierOnly);

        assertTrue(coldAccepted && accepted && direct);
    }

    /// @notice The verification half alone, cold: the figure the paper quotes.
    function test_verifyThresholdCold() public {
        uint256 before = gasleft();
        bool ok = registry.verifyThreshold(0, validator, F.STATEMENT_NORM, F.proof());
        uint256 gas = before - gasleft();

        emit log_named_uint("verifyThreshold (4 inputs, cold) gas", gas);
        assertTrue(ok);
    }

    /// @notice The whole admission, cold and then warm.
    function test_admitColdThenWarm() public {
        uint256 stake = manager.requiredStakeFor(F.STATEMENT_NORM);
        uint256 stakeOther = manager.requiredStakeFor(F.STATEMENT_NORM_OTHER);

        uint256 before = gasleft();
        vm.prank(validator);
        manager.admit(validator, stake, F.STATEMENT_NORM, F.proof());
        uint256 cold = before - gasleft();
        emit log_named_uint("manager.admit (cold) gas", cold);
        emit log_named_uint("manager.admit stake (WAD)", stake);

        uint256 before2 = gasleft();
        vm.prank(other);
        manager.admit(other, stakeOther, F.STATEMENT_NORM_OTHER, F.proofOther());
        uint256 warm = before2 - gasleft();
        emit log_named_uint("manager.admit (warm, other validator) gas", warm);

        assertTrue(manager.isAdmitted(validator));
        assertTrue(manager.isAdmitted(other));
        assertGt(cold, warm, "the cold admission pays the first touches");
    }

    /// @notice The same admission, built through the internal helper, so that the
    ///         figure is the same *convention* as the committed
    ///         `M4dRealKeyTest`'s 306,253 (blob construction inside the window).
    function proofViaHelper() internal pure returns (bytes memory) {
        return F.proof();
    }

    function test_admitColdWithHelper() public {
        uint256 stake = manager.requiredStakeFor(F.STATEMENT_NORM);

        uint256 before = gasleft();
        vm.prank(validator);
        manager.admit(validator, stake, F.STATEMENT_NORM, proofViaHelper());
        uint256 cold = before - gasleft();
        emit log_named_uint("manager.admit (cold, helper convention) gas", cold);

        assertTrue(manager.isAdmitted(validator));
    }
}
