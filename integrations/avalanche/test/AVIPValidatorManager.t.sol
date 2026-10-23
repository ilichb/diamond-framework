// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AVIPRegistry} from "../contracts/AVIPRegistry.sol";
import {AVIPValidatorManager} from "../contracts/AVIPValidatorManager.sol";
import {IAVIPRegistry} from "../contracts/interfaces/IAVIPRegistry.sol";
import {IAVIPValidatorManager} from "../contracts/interfaces/IAVIPValidatorManager.sol";
import {MockThresholdVerifier} from "./mocks/MockThresholdVerifier.sol";
import {M4dGroth16Fixtures as F4d} from "./fixtures/M4dGroth16Fixtures.sol";

/// WHAT IS TESTED
/// --------------
/// 1. Parameter provenance, all in WAD: `Theta = 1.0`, `C_R^inf = 0.8`,
///    `S_min = 0.2` (`verification/mechanism/financial_floor_sensitivity.py`),
///    `Theta_r = 0.5` [CONJECTURE] and `F_0* = 0.05` (paper §6.4, Payment Rule).
/// 2. Exact arithmetic at the worst admissible type `(omega_max, ||T||_F =
///    Theta_r)` of plan §5.2.3: `C_R(0.5) = 266666666666666666` and
///    `S_f*(0.5) = 733333333333333334`.
/// 3. Shape of the policy: `C_R` increasing, concave and bounded by `C_R^inf`;
///    `S_f*` decreasing, with `S_f*(0) = Theta`; and the floor `S_min` is
///    **inert** — `S_f*(r) > S_min` for every norm tested up to 1e30, so `S_f*`
///    is never the floor standing alone (§5.2.4).
/// 4. The threshold `Theta_r` is enforced **here**, not in the registry: `admit`
///    at exactly `Theta_r` passes, one wei below reverts with
///    `NormBelowThreshold`, and the check happens before the registry is touched
///    at all (§5.2.2, §5.2.3).
/// 5. Admission: a self-admission sets `isAdmitted`, stores the declared stake
///    and the required stake, emits `AdmissionEvaluated` and
///    `ValidatorAdmitted`, and uses the epoch the registry is on, so a proof for
///    an older epoch cannot be replayed (§5.2.1).
/// 6. Anti-replay lives here: a second `admit` reverts with `AlreadyAdmitted`, a
///    third-party `admit` reverts with `NotValidator`, and a rejected proof
///    reverts with `InvalidZKProof` without admitting anyone (§5.2.4).
/// 7. `collateralOf` is derived (`Theta - requiredStake`) and is zero while the
///    validator is not admitted (§5.2.4).
/// 8. Slashing: authority-only, and the amount is the **whole record** — a
///    validator loses everything it has on record and, because `S_f* > 0`, is
///    ejected with it — so the invariant `isAdmitted => stakeOf >= requiredStake`
///    is preserved. An address with nothing on record reverts `NothingToSlash`
///    (§12.1.2, M9b).
///
/// WHAT IS NOT TESTED
/// ------------------
/// - No real proof is verified: `IZKThresholdVerifier` is a mock, so a passing
///   `admit` says nothing about the pairing check or the recursive SNARK (M3).
/// - No custody: `financialStake` is declared, not escrowed. No test asserts a
///   balance change, because M2 moves no value (§5.2.3).
/// - The economic claim that `F_0* = 0.05` is a safe lower bound on the
///   admissible domain is *recorded* in the plan (§5.2.3), not asserted here:
///   the sealed `verification/mechanism/` scripts describe the unrestricted
///   domain, and no fee is collected on-chain in M2.
/// - Reputation weights and voting power dynamics (M6), the RMT detector (M5),
///   the data layer that decides a slash (M7), custody and fund movement (M8),
///   and gas or latency: not asserted.
contract AVIPValidatorManagerTest is Test {
    uint256 internal constant ONE = 1e18;
    uint256 internal constant THETA = 1e18;
    uint256 internal constant CR_INF = 8e17;
    uint256 internal constant S_MIN = 2e17;
    uint256 internal constant THETA_R = 5e17;
    uint256 internal constant F0_STAR = 5e16;

    /// @dev `C_R(0.5) = 0.8 * 0.5 / 1.5 = 266666666666666666` (plan §5.2.3).
    uint256 internal constant CR_AT_THETA_R = 266_666_666_666_666_666;
    /// @dev `S_f*(0.5) = 1 - C_R(0.5) = 733333333333333334` (plan §5.2.3).
    uint256 internal constant SF_AT_THETA_R = 733_333_333_333_333_334;

    uint256 internal constant PROOF_A0 = 42;
    /// @dev Poseidon root of epoch 0 (M4d). Arbitrary here: the mock only
    ///      compares the statement the manager causes the registry to build.
    uint256 internal constant STATEMENT_ROOT = 0x1234_5678;
    uint32 internal constant N = 500; // C*D*H, paper "Tensor Compression"

    /// @dev Slash reasons. Declared as `bytes32` constants so the literal is
    ///      *assigned*, never cast: `bytes32("x")` is an explicit typecast and
    ///      makes `forge lint` emit `unsafe-typecast` (§7 of the plan keeps the
    ///      lint silent).
    bytes32 internal constant REASON_COLLUSION = "collusion";
    bytes32 internal constant REASON_LATE_BLOCK = "late-block";
    bytes32 internal constant REASON_NA = "n/a";

    AVIPRegistry internal registry;
    AVIPValidatorManager internal manager;

    address internal sequencer;
    address internal slashAuthority;
    address internal validator;
    address internal stranger;
    /// @dev M9a: the only proposer of a change to `sequencer` or `verifier`.
    address internal guardian;

    bytes32 internal epoch0Root;

    function setUp() public {
        vm.warp(1_700_000_000);
        sequencer = makeAddr("sequencer");
        slashAuthority = makeAddr("slashAuthority");
        validator = makeAddr("validator");
        stranger = makeAddr("stranger");
        guardian = makeAddr("guardian");

        registry = new AVIPRegistry(
            sequencer,
            address(0),
            guardian,
            keccak256("avalanche-c-chain"),
            keccak256("AVIP/fragment-function/v1")
        );
        epoch0Root = keccak256("tensor");
        vm.prank(sequencer);
        registry.postCommitment(
            0,
            epoch0Root,
            STATEMENT_ROOT,
            N,
            keccak256("avalanche-c-chain"),
            keccak256("AVIP/fragment-function/v1")
        );

        manager = new AVIPValidatorManager(address(registry), slashAuthority, address(0));
    }

    // ----------------------------------------------------------------- helpers

    /// @dev Installs a verifier that accepts exactly one statement and returns
    ///      `answer`. The registry builds `[statementRoot, epoch, validator, norm]`
    ///      itself, so the
    ///      double has to be told which statement to expect (§5.2.1).
    function _setVerifier(bool answer, uint256 root, uint256 epoch, uint256 norm) internal {
        _setVerifierFor(answer, root, epoch, norm, validator);
    }

    /// @dev The same, for a verifier statement that binds another validator:
    ///      the mock is exact, so a second validator needs its own statement.
    function _setVerifierFor(bool answer, uint256 root, uint256 epoch, uint256 norm, address who)
        internal
    {
        // M9a: a verifier is installed by a propose/execute pair now. The mock is
        // deployed *before* the prank (`new` is itself a call, so an inline
        // `_mockVerifier(...)` would consume the prank and the proposal would come
        // from this test contract), the guardian proposes, the delay elapses, and
        // this test — not the guardian — commits the change, which is the
        // permissionless path §12.1.2 describes.
        MockThresholdVerifier mock = _mockVerifier(answer, root, epoch, norm, who);
        vm.prank(guardian);
        registry.proposeVerifier(address(mock));
        vm.warp(block.timestamp + registry.CHANGE_DELAY());
        registry.executeVerifierChange();
    }

    function _mockVerifier(bool answer, uint256 root, uint256 epoch, uint256 norm, address who)
        internal
        returns (MockThresholdVerifier)
    {
        return new MockThresholdVerifier(answer, PROOF_A0, _statement(root, epoch, who, norm));
    }

    /// @dev The verifier for the statement the manager builds at epoch 0.
    function _setVerifierAtEpoch0(bool answer, uint256 norm) internal {
        _setVerifier(answer, STATEMENT_ROOT, 0, norm);
    }

    function _statement(uint256 root, uint256 epoch, address who, uint256 norm)
        internal
        view
        returns (bytes memory)
    {
        uint256[] memory statement = new uint256[](4);
        statement[0] = root;
        statement[1] = epoch;
        statement[2] = uint256(uint160(who));
        statement[3] = norm;
        return abi.encode(statement);
    }

    function _encodeProof(uint256 a0) internal pure returns (bytes memory) {
        uint256[2] memory a = [a0, uint256(2)];
        uint256[2][2] memory b = [[uint256(3), uint256(4)], [uint256(5), uint256(6)]];
        uint256[2] memory c = [uint256(7), uint256(8)];
        return abi.encode(a, b, c);
    }

    /// @dev Admits `validator` at `norm`, with exactly the minimum stake.
    function _admitAt(uint256 norm) internal {
        _setVerifierAtEpoch0(true, norm);
        // Read the policy *before* the prank: `requiredStakeFor` is an external
        // call and would otherwise consume it.
        uint256 stake = manager.requiredStakeFor(norm);
        vm.prank(validator);
        manager.admit(validator, stake, norm, _encodeProof(PROOF_A0));
    }

    // ------------------------------------------------------------- parameters

    function test_parametersTraceToThePaper() public view {
        assertEq(manager.ONE(), ONE);
        assertEq(manager.THETA(), THETA);
        assertEq(manager.CR_INF(), CR_INF);
        assertEq(manager.S_MIN(), S_MIN);
        assertEq(manager.THETA_R(), THETA_R);
        assertEq(manager.F0_STAR(), F0_STAR);
        // `S_min` is exactly the floor implied by `Theta - C_R^inf`
        // (`verification/mechanism/financial_floor_sensitivity.py`).
        assertEq(manager.S_MIN(), manager.THETA() - manager.CR_INF());
    }

    function test_collateralAtTheWorstAdmissibleType() public view {
        // `omega_max` with `||T||_F = Theta_r` is the admissible type that
        // demands the most stake; if any type can be admitted, this one can
        // (plan §5.2.3).
        assertEq(manager.collateralFor(THETA_R), CR_AT_THETA_R);
    }

    function test_requiredStakeAtTheWorstAdmissibleType() public view {
        assertEq(manager.requiredStakeFor(THETA_R), SF_AT_THETA_R);
    }

    function test_requiredStakeIsTheComplementOfTheCollateral() public view {
        assertEq(manager.requiredStakeFor(THETA_R), THETA - manager.collateralFor(THETA_R));
        // At `||T||_F = 0` the collateral is 0 and the stake is the whole
        // threshold; `T = 0` is inadmissible (below `Theta_r`) but the policy is
        // still defined there.
        assertEq(manager.requiredStakeFor(0), THETA);
        assertEq(manager.collateralFor(0), 0);
    }

    function test_collateralIsIncreasingConcaveAndSaturated() public view {
        assertLt(manager.collateralFor(ONE), manager.collateralFor(2 * ONE));
        assertLt(manager.collateralFor(2 * ONE), manager.collateralFor(4 * ONE));

        // Concavity: equal multiplicative steps give shrinking increments.
        assertLt(
            manager.collateralFor(4 * ONE) - manager.collateralFor(2 * ONE),
            manager.collateralFor(2 * ONE) - manager.collateralFor(ONE)
        );

        // Saturation: `C_R(r) < C_R^inf` for every finite `r`, and it reaches it.
        assertLt(manager.collateralFor(1e30), CR_INF);
        assertGt(manager.collateralFor(1e30), CR_INF - 1e11);
    }

    function test_requiredStakeDecreasesWithTheNorm() public view {
        uint256[6] memory norms = [uint256(0), 1e17, THETA_R, ONE, 10 * ONE, 1e30];
        for (uint256 i = 1; i < norms.length; ++i) {
            assertLt(manager.requiredStakeFor(norms[i]), manager.requiredStakeFor(norms[i - 1]));
        }
    }

    /// @dev The `max{ S_min, ... }` of the paper is inert under these parameters:
    ///      `Theta - C_R(r) = 0.2 + 0.2/(1 + r) > S_min` for every finite `r`, so
    ///      the floor never binds on its own (§5.2.4).
    function test_theFloorIsInert() public view {
        uint256[8] memory norms = [uint256(0), 1, 1e17, THETA_R, ONE, 10 * ONE, 1e21, 1e30];
        for (uint256 i = 0; i < norms.length; ++i) {
            assertGt(manager.requiredStakeFor(norms[i]), S_MIN);
            assertEq(manager.requiredStakeFor(norms[i]), THETA - manager.collateralFor(norms[i]));
        }
    }

    function testFuzz_policyIsBoundedAndComplementary(uint256 norm) public view {
        norm = bound(norm, 0, 1e30);

        uint256 collateral = manager.collateralFor(norm);
        assertLt(collateral, CR_INF); // saturation at finite norms
        assertEq(manager.requiredStakeFor(norm), THETA - collateral); // floor inert
        assertGt(manager.requiredStakeFor(norm), S_MIN);
    }

    // -------------------------------------------------------------- admission

    function test_admit_acceptsTheWorstAdmissibleType() public {
        _setVerifierAtEpoch0(true, THETA_R);

        vm.expectEmit(true, false, false, true, address(manager));
        emit IAVIPValidatorManager.AdmissionEvaluated(
            validator, 0, THETA_R, CR_AT_THETA_R, SF_AT_THETA_R, 0
        );
        vm.expectEmit(true, false, false, true, address(manager));
        emit IAVIPValidatorManager.ValidatorAdmitted(validator, SF_AT_THETA_R, CR_AT_THETA_R);

        vm.prank(validator);
        manager.admit(validator, SF_AT_THETA_R, THETA_R, _encodeProof(PROOF_A0));

        assertTrue(manager.isAdmitted(validator));
        assertEq(manager.stakeOf(validator), SF_AT_THETA_R);
        assertEq(manager.requiredStake(validator), SF_AT_THETA_R);
        assertEq(manager.collateralOf(validator), CR_AT_THETA_R);
    }

    function test_admit_acceptsAStakeAboveTheMinimum() public {
        _setVerifierAtEpoch0(true, THETA_R);

        vm.prank(validator);
        manager.admit(validator, SF_AT_THETA_R + 1e18, THETA_R, _encodeProof(PROOF_A0));

        assertEq(manager.stakeOf(validator), SF_AT_THETA_R + 1e18);
        // `requiredStake` stays at the policy value: it is not whatever the
        // validator chose to declare.
        assertEq(manager.requiredStake(validator), SF_AT_THETA_R);
    }

    function test_admit_usesTheLatestEpoch() public {
        bytes32 epoch1Root = keccak256("tensor-epoch-1");
        vm.prank(sequencer);
        registry.postCommitment(
            1,
            epoch1Root,
            STATEMENT_ROOT + 1,
            1,
            keccak256("avalanche-c-chain"),
            keccak256("AVIP/fragment-function/v1")
        );
        _setVerifier(true, STATEMENT_ROOT + 1, 1, THETA_R);

        vm.expectEmit(true, false, false, true, address(manager));
        emit IAVIPValidatorManager.AdmissionEvaluated(
            validator, 1, THETA_R, CR_AT_THETA_R, SF_AT_THETA_R, 0
        );
        vm.prank(validator);
        manager.admit(validator, SF_AT_THETA_R, THETA_R, _encodeProof(PROOF_A0));

        assertTrue(manager.isAdmitted(validator));
    }

    function test_admit_rejectsAProofForAnOlderEpoch() public {
        bytes32 epoch1Root = keccak256("tensor-epoch-1");
        vm.prank(sequencer);
        registry.postCommitment(
            1,
            epoch1Root,
            STATEMENT_ROOT + 1,
            1,
            keccak256("avalanche-c-chain"),
            keccak256("AVIP/fragment-function/v1")
        );
        // The verifier knows the epoch 0 statement, but the manager asks the
        // registry for its latest epoch, which is 1: different statement.
        _setVerifier(true, STATEMENT_ROOT, 0, THETA_R);

        vm.prank(validator);
        vm.expectRevert("mock: unexpected statement");
        manager.admit(validator, SF_AT_THETA_R, THETA_R, _encodeProof(PROOF_A0));

        assertFalse(manager.isAdmitted(validator));
    }

    function test_admit_revertsWithoutACommitment() public {
        AVIPRegistry empty = new AVIPRegistry(
            sequencer,
            address(0),
            guardian,
            keccak256("avalanche-c-chain"),
            keccak256("AVIP/fragment-function/v1")
        );
        AVIPValidatorManager fresh =
            new AVIPValidatorManager(address(empty), slashAuthority, address(0));
        _setVerifierAtEpoch0(true, THETA_R);

        // On a registry with no commitment, `latestEpoch()` is
        // `type(uint256).max`, so the epoch the manager asks about does not
        // exist and the registry says so.
        vm.prank(validator);
        vm.expectRevert(
            abi.encodeWithSelector(IAVIPRegistry.UnknownEpoch.selector, type(uint256).max)
        );
        fresh.admit(validator, SF_AT_THETA_R, THETA_R, _encodeProof(PROOF_A0));
    }

    function test_admit_revertsBelowThetaR() public {
        // No verifier is installed: the threshold is checked first, so the
        // registry is never reached. `Theta_r` is a parameter of this contract,
        // not of the circuit (§5.2.2).
        vm.prank(validator);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAVIPValidatorManager.NormBelowThreshold.selector, THETA_R - 1, THETA_R
            )
        );
        manager.admit(validator, SF_AT_THETA_R, THETA_R - 1, _encodeProof(PROOF_A0));
    }

    function test_admit_revertsOnZeroNorm() public {
        // `T = 0` is no longer an admissible type: the registry would certify it
        // happily and the manager is the one that says no (§5.2.3).
        vm.prank(validator);
        vm.expectRevert(
            abi.encodeWithSelector(IAVIPValidatorManager.NormBelowThreshold.selector, 0, THETA_R)
        );
        manager.admit(validator, SF_AT_THETA_R, 0, _encodeProof(PROOF_A0));
    }

    function test_admit_revertsOnAnInsufficientStake() public {
        vm.prank(validator);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAVIPValidatorManager.InsufficientFinancialStake.selector,
                SF_AT_THETA_R - 1,
                SF_AT_THETA_R
            )
        );
        manager.admit(validator, SF_AT_THETA_R - 1, THETA_R, _encodeProof(PROOF_A0));
    }

    function test_admit_revertsWhenTheVerifierRejectsTheProof() public {
        _setVerifierAtEpoch0(false, THETA_R);

        vm.prank(validator);
        vm.expectRevert(IAVIPRegistry.InvalidZKProof.selector);
        manager.admit(validator, SF_AT_THETA_R, THETA_R, _encodeProof(PROOF_A0));

        assertFalse(manager.isAdmitted(validator));
        assertEq(manager.stakeOf(validator), 0);
    }

    function test_admit_revertsWhenTheProofCertifiesAnotherNorm() public {
        // The double expects the statement for `THETA_R + 1`; the manager asks
        // about `THETA_R`. The norm the proof certifies and the norm used for
        // `C_R` cannot diverge (§5.2.1).
        _setVerifierAtEpoch0(true, THETA_R + 1);

        vm.prank(validator);
        vm.expectRevert("mock: unexpected statement");
        manager.admit(validator, SF_AT_THETA_R, THETA_R, _encodeProof(PROOF_A0));
    }

    function test_admit_rejectsAThirdParty() public {
        _setVerifierAtEpoch0(true, THETA_R);

        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(IAVIPValidatorManager.NotValidator.selector, stranger)
        );
        manager.admit(validator, SF_AT_THETA_R, THETA_R, _encodeProof(PROOF_A0));

        assertFalse(manager.isAdmitted(validator));
    }

    function test_admit_rejectsTheZeroAddress() public {
        vm.prank(stranger);
        vm.expectRevert(IAVIPValidatorManager.ZeroValidator.selector);
        manager.admit(address(0), SF_AT_THETA_R, THETA_R, _encodeProof(PROOF_A0));
    }

    function test_admit_rejectsADoubleAdmission() public {
        _admitAt(THETA_R);
        _setVerifierAtEpoch0(true, THETA_R);

        vm.prank(validator);
        vm.expectRevert(
            abi.encodeWithSelector(IAVIPValidatorManager.AlreadyAdmitted.selector, validator)
        );
        manager.admit(validator, SF_AT_THETA_R, THETA_R, _encodeProof(PROOF_A0));

        // The first admission is untouched.
        assertTrue(manager.isAdmitted(validator));
        assertEq(manager.stakeOf(validator), SF_AT_THETA_R);
    }

    function testFuzz_admissionInvariant(uint256 norm, uint256 stake) public {
        norm = bound(norm, 0, 1e30);
        stake = bound(stake, 0, 1e30);

        _setVerifierAtEpoch0(true, norm);
        vm.prank(validator);
        try manager.admit(validator, stake, norm, _encodeProof(PROOF_A0)) {
            // Admitted => the rule held: `stake >= S_f*(norm)` and `norm >= Theta_r`.
            assertGe(stake, manager.requiredStakeFor(norm));
            assertGe(norm, THETA_R);
            assertEq(manager.requiredStake(validator), manager.requiredStakeFor(norm));
            assertEq(manager.stakeOf(validator), stake);
        } catch {
            // Nothing was written on the way out.
            assertFalse(manager.isAdmitted(validator));
            assertEq(manager.stakeOf(validator), 0);
        }
    }

    // ------------------------------------------------------------------ views

    function test_viewsAreZeroBeforeAdmission() public view {
        assertFalse(manager.isAdmitted(validator));
        assertEq(manager.stakeOf(validator), 0);
        assertEq(manager.requiredStake(validator), 0);
        assertEq(manager.collateralOf(validator), 0);
    }

    function test_collateralOfIsDerivedFromTheRequiredStake() public {
        _admitAt(THETA_R);

        assertEq(manager.collateralOf(validator), THETA - manager.requiredStake(validator));
        assertEq(manager.collateralOf(validator), CR_AT_THETA_R);
    }

    // --------------------------------------------------------------- slashing

    function test_slash_isAuthorityOnly() public {
        _admitAt(THETA_R);

        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(IAVIPValidatorManager.NotSlashAuthority.selector, stranger)
        );
        manager.slash(validator, REASON_COLLUSION);

        assertEq(manager.stakeOf(validator), SF_AT_THETA_R);
        assertTrue(manager.isAdmitted(validator));
    }

    /// @dev M9b (§12.1.2): the amount is the record, so a validator with a buffer
    ///      loses the buffer too — there is no argument left for "how much", and
    ///      therefore no way for a caller to ask for less than everything.
    function test_slash_takesTheWholeRecordEvenWhenThereIsABuffer() public {
        uint256 buffer = 1e18;
        _setVerifierAtEpoch0(true, THETA_R);
        vm.prank(validator);
        manager.admit(validator, SF_AT_THETA_R + buffer, THETA_R, _encodeProof(PROOF_A0));

        vm.expectEmit(true, false, false, true, address(manager));
        emit IAVIPValidatorManager.ValidatorSlashed(
            validator, SF_AT_THETA_R + buffer, REASON_LATE_BLOCK
        );
        vm.prank(slashAuthority);
        manager.slash(validator, REASON_LATE_BLOCK);

        assertEq(manager.stakeOf(validator), 0);
        assertFalse(manager.isAdmitted(validator));
        assertEq(manager.collateralOf(validator), 0);
    }

    function test_slash_aValidatorStakedAtTheExactMinimumIsEjected() public {
        _admitAt(THETA_R); // exactly `S_f*`: no buffer

        // The ejection reports the record the slash leaves, which is empty, and
        // the requirement it is now below: `0 < S_f*` for every admitted
        // validator, because `requiredStakeFor` is never below `S_min > 0`.
        vm.expectEmit(true, false, false, true, address(manager));
        emit IAVIPValidatorManager.ValidatorEjected(validator, 0, SF_AT_THETA_R);
        vm.prank(slashAuthority);
        manager.slash(validator, REASON_LATE_BLOCK);

        // Admission is a rule on the stake, not a status that survives the stake
        // being taken.
        assertFalse(manager.isAdmitted(validator));
        assertEq(manager.stakeOf(validator), 0);
        assertLt(manager.stakeOf(validator), manager.requiredStake(validator));
    }

    /// @dev The case M9b's derived amount makes possible and the transported one
    ///      made an arithmetic exercise: an address that never staked has nothing
    ///      to take, so the instruction cannot execute.
    function test_slash_rejectsAnAddressThatNeverStaked() public {
        vm.prank(slashAuthority);
        vm.expectRevert(
            abi.encodeWithSelector(IAVIPValidatorManager.NothingToSlash.selector, stranger)
        );
        manager.slash(stranger, REASON_NA);
    }

    function test_slash_rejectsASecondSlashOfTheSameRecord() public {
        _admitAt(THETA_R);

        vm.prank(slashAuthority);
        manager.slash(validator, REASON_COLLUSION);

        // The record is empty now, so the same instruction — the one a replayed
        // notification would carry — finds nothing instead of slashing zero.
        vm.prank(slashAuthority);
        vm.expectRevert(
            abi.encodeWithSelector(IAVIPValidatorManager.NothingToSlash.selector, validator)
        );
        manager.slash(validator, REASON_COLLUSION);

        assertEq(manager.stakeOf(validator), 0);
    }

    /// @dev Taking one record whole must not reach the neighbour: `_stakes` is per
    ///      validator, and the whole-record rule is about *which* number is taken,
    ///      not about who else is admitted.
    function test_slash_doesNotTouchAnotherValidatorsRecord() public {
        address other = address(uint160(F4d.STATEMENT_VALIDATOR_OTHER));
        _admitAt(THETA_R);
        _setVerifierFor(true, STATEMENT_ROOT, 0, THETA_R, other);
        vm.prank(other);
        manager.admit(other, SF_AT_THETA_R, THETA_R, _encodeProof(PROOF_A0));

        vm.prank(slashAuthority);
        manager.slash(validator, REASON_COLLUSION);

        assertEq(manager.stakeOf(other), SF_AT_THETA_R);
        assertTrue(manager.isAdmitted(other));
        assertEq(manager.stakeOf(validator), 0);
    }

    // --------------------------------------------------- ejection surcharge (M9c)

    /// @dev Ejects `who` by taking its whole record (M9b), which is the only path
    ///      that increments the counter.
    function _eject(address who) internal {
        vm.prank(slashAuthority);
        manager.slash(who, REASON_COLLUSION);
    }

    function test_ejection_theSecondAdmissionCostsTheSurcharge() public {
        uint256 kappa = manager.EJECTION_SURCHARGE();
        _admitAt(THETA_R);
        _eject(validator);
        assertEq(manager.ejectionsOf(validator), 1, "one ejection on record");

        // The image alone is no longer enough...
        _setVerifierAtEpoch0(true, THETA_R);
        vm.prank(validator);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAVIPValidatorManager.InsufficientFinancialStake.selector,
                SF_AT_THETA_R,
                SF_AT_THETA_R + kappa
            )
        );
        manager.admit(validator, SF_AT_THETA_R, THETA_R, _encodeProof(PROOF_A0));

        // ...the requirement is the image plus the surcharge, and the collateral
        // the norm earns is what it was before.
        vm.prank(validator);
        manager.admit(validator, SF_AT_THETA_R + kappa, THETA_R, _encodeProof(PROOF_A0));

        assertTrue(manager.isAdmitted(validator));
        assertEq(manager.requiredStake(validator), SF_AT_THETA_R + kappa);
        assertEq(manager.collateralOf(validator), CR_AT_THETA_R, "the credit is unchanged");
    }

    function test_ejection_theThirdAdmissionCostsTwiceTheSurcharge() public {
        uint256 kappa = manager.EJECTION_SURCHARGE();
        uint256 surcharge = 2 * kappa;

        // Eject twice: the first admission, its ejection, a re-admission at `+κ`,
        // and that one's ejection.
        _admitAt(THETA_R);
        _eject(validator);
        _setVerifierAtEpoch0(true, THETA_R);
        vm.prank(validator);
        manager.admit(validator, SF_AT_THETA_R + kappa, THETA_R, _encodeProof(PROOF_A0));
        _eject(validator);
        assertEq(manager.ejectionsOf(validator), 2, "two ejections on record");

        _setVerifierAtEpoch0(true, THETA_R);
        vm.prank(validator);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAVIPValidatorManager.InsufficientFinancialStake.selector,
                SF_AT_THETA_R + kappa,
                SF_AT_THETA_R + surcharge
            )
        );
        manager.admit(validator, SF_AT_THETA_R + kappa, THETA_R, _encodeProof(PROOF_A0));

        vm.prank(validator);
        manager.admit(validator, SF_AT_THETA_R + surcharge, THETA_R, _encodeProof(PROOF_A0));

        assertEq(manager.requiredStake(validator), SF_AT_THETA_R + surcharge);
        assertEq(manager.collateralOf(validator), CR_AT_THETA_R, "still the same credit");
        assertEq(
            manager.collateralOf(validator) + manager.requiredStake(validator),
            THETA + surcharge,
            "the surcharge sits on top of `S_f*`, not inside it"
        );
        assertEq(
            manager.requiredStakeFor(THETA_R),
            SF_AT_THETA_R,
            "the policy function is blind to history"
        );
    }

    function test_ejection_theEventCarriesTheSurchargeAndTheLargerRequirement() public {
        uint256 kappa = manager.EJECTION_SURCHARGE();
        _admitAt(THETA_R);
        _eject(validator);
        _setVerifierAtEpoch0(true, THETA_R);

        vm.expectEmit(true, false, false, true, address(manager));
        emit IAVIPValidatorManager.AdmissionEvaluated(
            validator, 0, THETA_R, CR_AT_THETA_R, SF_AT_THETA_R + kappa, kappa
        );
        vm.prank(validator);
        manager.admit(validator, SF_AT_THETA_R + kappa, THETA_R, _encodeProof(PROOF_A0));
    }

    function test_ejection_theCounterIsPerValidatorAndSurvivesReAdmission() public {
        address other = address(uint160(F4d.STATEMENT_VALIDATOR_OTHER));
        _admitAt(THETA_R);
        _setVerifierFor(true, STATEMENT_ROOT, 0, THETA_R, other);
        vm.prank(other);
        manager.admit(other, SF_AT_THETA_R, THETA_R, _encodeProof(PROOF_A0));

        _eject(validator);

        // The neighbour's history is its own, and a re-admission does not reset
        // the count: the surcharge is about the *record*, not the sitting session.
        assertEq(manager.ejectionsOf(other), 0, "untouched");
        assertEq(manager.requiredStake(other), SF_AT_THETA_R, "and so is its requirement");
        // Read the constant before the prank (an external call consumes it).
        uint256 kappa = manager.EJECTION_SURCHARGE();
        _setVerifierAtEpoch0(true, THETA_R);
        vm.prank(validator);
        manager.admit(validator, SF_AT_THETA_R + kappa, THETA_R, _encodeProof(PROOF_A0));
        assertEq(manager.ejectionsOf(validator), 1, "one, after the second admission");
    }

    // ------------------------------------------------------------ constructor

    function test_constructor_rejectsAZeroRegistry() public {
        vm.expectRevert(IAVIPValidatorManager.ZeroRegistry.selector);
        new AVIPValidatorManager(address(0), slashAuthority, address(0));
    }

    function test_constructor_rejectsAZeroSlashAuthority() public {
        vm.expectRevert(IAVIPValidatorManager.ZeroSlashAuthority.selector);
        new AVIPValidatorManager(address(registry), address(0), address(0));
    }

    function test_constructor_wiresTheRegistry() public view {
        assertEq(address(manager.registry()), address(registry));
        assertEq(manager.slashAuthority(), slashAuthority);
    }
}
