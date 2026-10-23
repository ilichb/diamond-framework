// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AVIPBurnSink} from "../contracts/AVIPBurnSink.sol";
import {AVIPRegistry} from "../contracts/AVIPRegistry.sol";
import {AVIPStakeVault} from "../contracts/AVIPStakeVault.sol";
import {AVIPValidatorManager} from "../contracts/AVIPValidatorManager.sol";
import {IAVIPCustody} from "../contracts/interfaces/IAVIPCustody.sol";
import {IAVIPValidatorManager} from "../contracts/interfaces/IAVIPValidatorManager.sol";
import {IERC20Minimal} from "../contracts/interfaces/IERC20Minimal.sol";
import {IFundSink} from "../contracts/interfaces/IFundSink.sol";
import {MockBurnableERC20} from "./mocks/MockBurnableERC20.sol";
import {MockDeafCustody} from "./mocks/MockDeafCustody.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockFundSink} from "./mocks/MockFundSink.sol";
import {MockThresholdVerifier} from "./mocks/MockThresholdVerifier.sol";

/// WHAT IS TESTED
/// --------------
/// 1. The handshake of §5.12: the custody is deployed first, the manager's
///    constructor binds it (`bindManager`) and then *verifies* what it bound
///    (`manager()`), so a vault already bound to somebody else, a vault that
///    accepts the bind and reports nobody, and an address that is not a custody
///    all fail the deployment instead of producing a manager with no custody.
/// 2. `bindManager` is one-shot, and an unbound vault is a plain, harmless
///    escrow: full withdrawals, no fee, no manager-only door. The bind itself is
///    not harmless: it has no access control and needs no code, so an EOA can
///    take it, drain a victim's escrow through `debit` and leave the rest
///    unwithdrawable — asserted, not argued, in the EOA proof below.
/// 3. Escrow accounting in the token's own base units, reported in WAD:
///    deposit credits exactly what arrived, withdraw returns only the caller's
///    own escrow, and the part standing behind `stakeOf` is locked — rounded so
///    that the stake on record can never be withdrawn.
/// 4. Admission bound to custody: `financialStake` must be covered by escrow, one
///    base unit short is enough to refuse, and with `custody == address(0)` the
///    manager behaves exactly like M2 (nothing is checked, nothing is escrowed).
/// 5. A slash moves the funds out of custody into the sink *in the same call*, so
///    record and escrow cannot diverge; a failing token or a refusing sink rolls
///    the whole slash back (the atomicity claim, asserted from both sides).
/// 6. The rounding boundaries: a slash below one base unit moves nothing and
///    still lowers the record (leaving withdrawable surplus), and `withdrawable`
///    ceils what is locked, so the surplus is released exactly when the manager
///    stops admitting the validator.
/// 7. The fee: charged to `msg.sender` only, from its own balance straight to the
///    sink, never touching this contract's balance, refused for a non-admitted
///    payer and for a token too coarse to charge `F_0*` at all; and there is no
///    per-epoch ledger here — paying twice is allowed and documented as the
///    caller's policy.
/// 8. Token behaviour: USDT-style (no return data), a `false` return, a revert
///    with a reason and a revert with no data are all handled, with the vault
///    trusting no boolean and measuring every delta.
/// 9. Reentrancy: a reentrant token and a reentrant sink attempt to withdraw or
///    slash again mid-movement; both attempts fail, because every write precedes
///    the first external call. The mocks record the attempt, so this is asserted
///    rather than argued.
/// 10. Conservation: `totalDeposited == totalEscrowedUnits + totalReleased +
///    totalDebited`, `heldUnits == totalEscrowedUnits` when nothing has been sent
///    here by another route, and `sinkBalance == totalDebited + totalFeesPaid`.
/// 11. `AVIPBurnSink`, the reference sink: it burns what it receives, reports a
///    token that cannot be burned, holds nothing between calls, and leaves a token
///    sent here by any other route untouched (not burned, not counted and not swept).
///
/// WHAT IS NOT TESTED
/// ------------------
/// - No real proof is verified: `IZKThresholdVerifier` is the same mock the M2
///   suite uses, so a passing `admit` says nothing about the pairing check (M3).
/// - No real ERC-20 is deployed. `MockERC20`'s knobs cover the behaviour classes
///   the vault claims to handle; a live token's decimals, metadata or gas are not
///   asserted, and `decimals()` is never called by the vault (the scale is a
///   deployment fact).
/// - The *destination* of the funds is a deployment decision (`IFundSink`,
///   `D-M8-0`): what is asserted here is that the vault transfers to the sink it
///   was constructed with and that `AVIPBurnSink` is a working reference, not
///   that burning is the protocol's choice.
/// - Governance of a slash (M7's data layer and the `slashAuthority` role), the
///   RMT detector (M5), reputation (M6) and gas: not asserted here.
contract M8StakeVaultTest is Test {
    uint256 internal constant ONE = 1e18;
    uint256 internal constant THETA_R = 5e17;
    uint256 internal constant F0_STAR = 5e16;

    /// @dev `S_f*(Theta_r)`, the same closed form the M2 suite pins.
    uint256 internal constant SF_AT_THETA_R = 733_333_333_333_333_334;

    /// @dev The scale of the 6-decimal token used in most tests: `10**(18-6)`.
    uint256 internal constant WAD_PER_UNIT_6 = 1e12;

    /// @dev `F_0*` in base units of that token: `5e16 / 1e12 = 50000`.
    uint256 internal constant FEE_UNITS_6 = 50_000;

    uint256 internal constant PROOF_A0 = 42;
    uint32 internal constant N = 500; // C*D*H, paper "Tensor Compression"

    /// @dev Reasons, declared as `bytes32` constants so no literal is cast
    ///      (which would make `forge lint` emit `unsafe-typecast`).
    bytes32 internal constant REASON_COLLUSION = "collusion";
    bytes32 internal constant REASON_LATE_BLOCK = "late-block";

    MockERC20 internal token;
    MockFundSink internal sink;
    AVIPRegistry internal registry;
    AVIPStakeVault internal vault;
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

        token = new MockERC20("Mock USD", 6);
        sink = new MockFundSink();

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
            uint256(epoch0Root),
            N,
            keccak256("avalanche-c-chain"),
            keccak256("AVIP/fragment-function/v1")
        );

        // The order is the handshake's: custody first, manager second.
        vault = new AVIPStakeVault(address(token), address(sink), WAD_PER_UNIT_6);
        manager = new AVIPValidatorManager(address(registry), slashAuthority, address(vault));

        _setVerifierAtEpoch0(true, THETA_R);
        _fund(validator, 10 * SF_AT_THETA_R / WAD_PER_UNIT_6);
    }

    // ----------------------------------------------------------------- helpers

    /// @dev Installs a verifier that accepts exactly one statement and returns
    ///      `answer` (the M2 suite's double, reused unchanged).
    function _setVerifier(bool answer, bytes32 root, uint256 epoch, uint256 norm) internal {
        // M9a: a verifier is installed by a propose/execute pair now. The mock is
        // deployed *before* the prank (`new` is itself a call, so an inline
        // `_mockVerifier(...)` would consume the prank and the proposal would come
        // from this test contract), the guardian proposes, the delay elapses, and
        // this test — not the guardian — commits the change, which is the
        // permissionless path §12.1.2 describes.
        MockThresholdVerifier mock = _mockVerifier(answer, root, epoch, norm);
        vm.prank(guardian);
        registry.proposeVerifier(address(mock));
        vm.warp(block.timestamp + registry.CHANGE_DELAY());
        registry.executeVerifierChange();
    }

    function _mockVerifier(bool answer, bytes32 root, uint256 epoch, uint256 norm)
        internal
        returns (MockThresholdVerifier)
    {
        return new MockThresholdVerifier(answer, PROOF_A0, _statement(root, epoch, validator, norm));
    }

    function _setVerifierAtEpoch0(bool answer, uint256 norm) internal {
        _setVerifier(answer, epoch0Root, 0, norm);
    }

    function _statement(bytes32 root, uint256 epoch, address who, uint256 norm)
        internal
        pure
        returns (bytes memory)
    {
        uint256[] memory statement = new uint256[](4);
        statement[0] = uint256(root);
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

    /// @dev Mints `units` to `who` and approves the vault to pull them.
    function _fund(address who, uint256 units) internal {
        token.mint(who, units);
        vm.prank(who);
        token.approve(address(vault), units);
    }

    /// @dev Escrows `units` of `who`'s own balance.
    function _deposit(address who, uint256 units) internal returns (uint256) {
        vm.prank(who);
        return vault.deposit(units);
    }

    /// @dev Admits `validator` declaring exactly `declaredWad`.
    function _admit(uint256 declaredWad) internal {
        vm.prank(validator);
        manager.admit(validator, declaredWad, THETA_R, _encodeProof(PROOF_A0));
    }

    /// @dev Slashes `validator`, as the role that carries the decision. Since M9b
    ///      (§12.1.2) there is no amount: the manager takes the whole record, so
    ///      the only decisions left are *who* and *why*.
    function _slash(bytes32 reason) internal {
        vm.prank(slashAuthority);
        manager.slash(validator, reason);
    }

    /// @dev The stake on record converted to base units, rounded down.
    function _stakeUnits(address who) internal view returns (uint256) {
        return manager.stakeOf(who) / WAD_PER_UNIT_6;
    }

    /// @dev Base units that cover `declaredWad` at least: the *smallest* escrow a
    ///      declaration of `declaredWad` can be admitted against, rounded up.
    ///      `S_f*(Theta_r) = 733333333333333334` WAD is not a whole number of
    ///      base units of a 6-decimal token, so a validator that declares the
    ///      paper's number must escrow one unit more than the floor of it. The
    ///      round-up is on the validator's side and lands above the paper's
    ///      requirement, which is the safe direction (§5.12).
    function _unitsCovering(uint256 declaredWad) internal pure returns (uint256) {
        return (declaredWad + WAD_PER_UNIT_6 - 1) / WAD_PER_UNIT_6;
    }

    /// @dev Escrows exactly enough for `declaredWad` and admits at it.
    function _depositAndAdmit(uint256 declaredWad) internal {
        _deposit(validator, _unitsCovering(declaredWad));
        _admit(declaredWad);
    }
    // ------------------------------------------------------------- constructor

    function test_constructor_rejectsAZeroToken() public {
        vm.expectRevert(abi.encodeWithSelector(AVIPStakeVault.ZeroToken.selector, address(0)));
        new AVIPStakeVault(address(0), address(sink), WAD_PER_UNIT_6);
    }

    function test_constructor_rejectsAZeroSink() public {
        vm.expectRevert(abi.encodeWithSelector(AVIPStakeVault.ZeroSink.selector, address(0)));
        new AVIPStakeVault(address(token), address(0), WAD_PER_UNIT_6);
    }

    function test_constructor_rejectsAScaleThatDoesNotDivideWad() public {
        // Zero, a scale that leaves a remainder, and a scale above `1e18` (a token
        // with more than 18 decimals) are all refused: each would mis-price every
        // comparison against `stakeOf`.
        vm.expectRevert(abi.encodeWithSelector(AVIPStakeVault.InvalidWadPerUnit.selector, 0));
        new AVIPStakeVault(address(token), address(sink), 0);

        vm.expectRevert(abi.encodeWithSelector(AVIPStakeVault.InvalidWadPerUnit.selector, 3));
        new AVIPStakeVault(address(token), address(sink), 3);

        vm.expectRevert(abi.encodeWithSelector(AVIPStakeVault.InvalidWadPerUnit.selector, 1e19));
        new AVIPStakeVault(address(token), address(sink), 1e19);
    }

    function test_constructor_fixesTheTokenTheSinkAndTheScale() public view {
        assertEq(address(vault.TOKEN()), address(token), "token");
        assertEq(address(vault.SINK()), address(sink), "sink");
        assertEq(vault.WAD_PER_UNIT(), WAD_PER_UNIT_6, "scale");
        assertEq(vault.ONE(), ONE, "WAD");
        assertEq(vault.FEE_REASON(), keccak256("AVIP:F0_STAR"), "fee tag");

        // Nothing has happened yet, so every aggregate is zero: the counters are
        // only ever moved by the four paths that move escrow.
        assertEq(vault.totalEscrowedUnits(), 0, "escrow");
        assertEq(vault.totalDeposited(), 0, "deposits");
        assertEq(vault.totalReleased(), 0, "releases");
        assertEq(vault.totalDebited(), 0, "debits");
        assertEq(vault.totalFeesPaid(), 0, "fees");
    }

    // --------------------------------------------------------------- handshake

    function test_theManagersConstructorBindsTheCustodyToItself() public view {
        assertEq(vault.manager(), address(manager), "the vault obeys the manager");
        assertEq(address(manager.custody()), address(vault), "the manager points at the vault");

        // The same two facts through the interface the custody boundary is
        // written in, which is how every other contract reaches it.
        IAVIPCustody custody = manager.custody();
        assertEq(custody.escrowed(validator), 0, "an empty escrow to begin with");
        assertEq(custody.manager(), address(manager), "and the custody says the same");
    }

    function test_bindManager_emitsManagerBoundOnce() public {
        AVIPStakeVault fresh = new AVIPStakeVault(address(token), address(sink), WAD_PER_UNIT_6);
        assertEq(fresh.manager(), address(0), "unbound until somebody binds");

        vm.expectEmit(true, false, false, true, address(fresh));
        emit AVIPStakeVault.ManagerBound(address(this));
        fresh.bindManager();

        assertEq(fresh.manager(), address(this), "bound to the caller");
    }

    function test_bindManager_isOneShot() public {
        vm.expectRevert(
            abi.encodeWithSelector(AVIPStakeVault.ManagerAlreadyBound.selector, address(manager))
        );
        vault.bindManager();
    }

    function test_aVaultBoundBySomebodyElseMakesTheManagersDeploymentFail() public {
        // The one race the design accepts, and its mildest cost: anybody can fill
        // the empty hole of a freshly deployed vault, and that alone makes the
        // *real* manager refuse to deploy, which is loud and leaves nothing wired
        // to nothing. The bind is not only a deployment blocker, though:
        // `bindManager` has no access control and `debit` checks nothing but
        // `msg.sender != address(_manager)`, so the address that fills the hole
        // becomes the manager and inherits the manager-only doors — with no
        // contract needed to do it. See
        // `test_aStrangerWhoTakesTheBindWithAnEoaDrainsAndTrapsAVictimsEscrow`.
        AVIPStakeVault hijacked = new AVIPStakeVault(address(token), address(sink), WAD_PER_UNIT_6);
        vm.prank(stranger);
        hijacked.bindManager();
        assertEq(hijacked.manager(), stranger, "the hole was taken");

        vm.expectRevert(
            abi.encodeWithSelector(AVIPStakeVault.ManagerAlreadyBound.selector, stranger)
        );
        new AVIPValidatorManager(address(registry), slashAuthority, address(hijacked));
    }

    function test_aStrangerWhoTakesTheBindWithAnEoaDrainsAndTrapsAVictimsEscrow() public {
        // The severity the header above does *not* claim. While the vault is
        // unbound it is a plain escrow — that much the header says and this test
        // asserts. But the bind needs neither a contract nor access control, so
        // the "manager" can be an EOA, and then the whole manager surface is in
        // the hands of whoever called first:
        //
        //   - `debit` checks only `msg.sender != address(_manager)`, so the EOA
        //     moves a victim's escrow to the constructor-fixed sink;
        //   - `withdrawable` staticcalls `isAdmitted` on that EOA, whose empty
        //     return data cannot be decoded, so the *victim* can no longer take
        //     its own escrow back.
        //
        // The funds are not merely displaced: the remainder is stranded, because
        // no function of the vault moves escrow back except `withdraw`, and
        // `withdraw` is gated by `withdrawable`.
        //
        // This is a *declared limit*, not a bug awaiting a repair: the cheap
        // guard (`msg.sender.code.length > 0` in `bindManager`) is impossible
        // here — the manager binds from its own constructor, where its
        // `EXTCODESIZE` is still 0 — and the `immutable` alternative is the
        // cyclic wiring the handshake exists to avoid. Plan §5.12 records the
        // hazard, the reason the guard cannot exist and the deployment rule that
        // closes it (vault and manager in one transaction).
        AVIPStakeVault hijacked = new AVIPStakeVault(address(token), address(sink), WAD_PER_UNIT_6);

        address victim = makeAddr("pocVictim");
        uint256 victimUnits = 1_000_000;
        token.mint(victim, victimUnits);
        vm.prank(victim);
        token.approve(address(hijacked), victimUnits);
        vm.prank(victim);
        assertEq(hijacked.deposit(victimUnits), victimUnits, "credited in the token's base units");
        assertEq(hijacked.escrowedUnits(victim), victimUnits, "and it sits in the vault");

        // Unbound, the vault is an escrow and behaves like one: everything free.
        assertEq(hijacked.withdrawable(victim), victimUnits, "no manager: the whole escrow is free");

        // The front-run, with no contract and no cooperation: `bindManager` is
        // one-shot, unauthenticated and takes whatever address calls it.
        assertEq(stranger.code.length, 0, "an EOA: no code to bind, none to deploy");
        vm.prank(stranger);
        hijacked.bindManager();
        assertEq(hijacked.manager(), stranger, "an EOA is a perfectly good manager here");

        // The thief takes part of the escrow and leaves the rest: a full sweep
        // would be caught by conservation, and the interesting case is the one
        // where something is left behind and still unreachable.
        uint256 stolen = 400_000;
        uint256 sinkBefore = token.balanceOf(address(sink));
        vm.prank(stranger);
        hijacked.debit(victim, stolen * WAD_PER_UNIT_6, REASON_COLLUSION);

        assertEq(token.balanceOf(address(sink)) - sinkBefore, stolen, "the victim's escrow left");
        assertEq(sink.lastReason(), REASON_COLLUSION, "with the thief's own reason");
        assertEq(hijacked.escrowedUnits(victim), victimUnits - stolen, "the rest is still escrowed");
        assertEq(hijacked.totalDebited(), stolen, "and the vault books it as a slash");

        // What is left is trapped. `withdrawable` cannot read `isAdmitted` from an
        // address with no code...
        (bool ok, bytes memory data) = address(hijacked)
            .staticcall(abi.encodeWithSelector(AVIPStakeVault.withdrawable.selector, victim));
        assertFalse(ok, "withdrawable reverts against an EOA manager");
        assertEq(data.length, 0, "and reverts with no data rather than with a refusal");

        // ...so the victim's own withdrawal reverts, and the escrow stays exactly
        // where it is: 600000 base units, reachable by nobody.
        vm.prank(victim);
        vm.expectRevert();
        hijacked.withdraw(victimUnits - stolen);
        assertEq(hijacked.escrowedUnits(victim), victimUnits - stolen, "still there, unreachable");
    }

    function test_aCustodyThatAcceptsTheBindAndReportsNobodyFailsTheDeployment() public {
        // The verification half of the handshake, and the only reason
        // `CustodyNotBound` exists: `bindManager` returning is not the same as a
        // vault that obeyed, so the constructor reads `manager()` back.
        MockDeafCustody deaf = new MockDeafCustody();

        // The attempt is observable on its own: `bindManager` returns happily and
        // records nothing, which is exactly the state a manager must refuse. (In
        // the deployment below the same attempt is rolled back with the revert —
        // which is the point of reverting.)
        deaf.bindManager();
        assertEq(deaf.binds(), 1, "the double counts the attempt");
        assertEq(deaf.manager(), address(0), "and still reports nobody");

        vm.expectRevert(
            abi.encodeWithSelector(IAVIPValidatorManager.CustodyNotBound.selector, address(deaf))
        );
        new AVIPValidatorManager(address(registry), slashAuthority, address(deaf));
    }

    function test_anAddressThatIsNotACustodyFailsTheDeployment() public {
        // `address(token)` is a contract that does not speak `IAVIPCustody`, and
        // `0x...dEaD` is not a contract at all: neither can answer a bind, so
        // neither can be accepted as custody.
        vm.expectRevert();
        new AVIPValidatorManager(address(registry), slashAuthority, address(token));

        vm.expectRevert();
        new AVIPValidatorManager(address(registry), slashAuthority, address(0xdEaD));
    }

    // ------------------------------------------------------------ unbound state

    function test_anUnboundVaultIsAPlainEscrowAndNothingElse() public {
        AVIPStakeVault unbound = new AVIPStakeVault(address(token), address(sink), WAD_PER_UNIT_6);
        _fund(stranger, 1_000);
        vm.prank(stranger);
        token.approve(address(unbound), 1_000);

        vm.prank(stranger);
        unbound.deposit(1_000);
        assertEq(unbound.escrowedUnits(stranger), 1_000, "escrow is credited");

        // Everything is withdrawable, because no record stands behind it...
        assertEq(unbound.withdrawable(stranger), 1_000, "no lock while unbound");
        assertTrue(unbound.isBacked(stranger), "there is no record to cover");

        // ... the fee has no policy to read and no payer can be charged ...
        assertEq(unbound.feeInUnits(), 0, "no F_0* to read");
        vm.expectRevert(AVIPStakeVault.ManagerNotBound.selector);
        vm.prank(stranger);
        unbound.payFee();

        // ... the manager-only door is shut to everyone ...
        vm.expectRevert(abi.encodeWithSelector(AVIPStakeVault.NotManager.selector, address(this)));
        unbound.debit(stranger, 1e18, REASON_COLLUSION);

        // ... and the escrow comes back whole.
        vm.prank(stranger);
        unbound.withdraw(1_000);
        assertEq(token.balanceOf(stranger), 1_000, "returned");
        assertEq(unbound.heldUnits(), 0, "empty again");
    }

    // ------------------------------------------------------------------- escrow

    function test_deposit_creditsExactlyWhatArrivedAndReportsItInWad() public {
        uint256 units = 2 * ONE / WAD_PER_UNIT_6; // exactly 2.0, in base units

        vm.expectEmit(true, false, false, true, address(vault));
        emit AVIPStakeVault.Deposited(validator, units);
        uint256 credited = _deposit(validator, units);

        assertEq(credited, units, "credited what arrived");
        assertEq(vault.escrowedUnits(validator), units, "in the token's units");
        assertEq(vault.escrowed(validator), 2 * ONE, "and reported in WAD");
        assertEq(vault.totalEscrowedUnits(), units, "aggregate");
        assertEq(vault.totalDeposited(), units, "ever deposited");
        assertEq(vault.heldUnits(), units, "held");
        assertEq(
            token.balanceOf(validator), 10 * SF_AT_THETA_R / WAD_PER_UNIT_6 - units, "payer debited"
        );
    }

    function test_deposit_accountsACentOfASixDecimalTokenExactly() public {
        // One base unit of a 6-decimal token is `1e12` WAD: a round trip must not
        // lose it, and the WAD view is what every comparison against `stakeOf`
        // uses.
        _deposit(validator, 1);
        assertEq(vault.escrowedUnits(validator), 1);
        assertEq(vault.escrowed(validator), 1e12);

        vm.prank(validator);
        vault.withdraw(1);
        assertEq(vault.escrowed(validator), 0, "no dust left behind");
    }

    function test_deposit_rejectsAZeroAmount() public {
        vm.expectRevert(AVIPStakeVault.ZeroAmount.selector);
        _deposit(validator, 0);
    }

    function test_deposit_rejectsATokenThatDeliversLessThanPromised() public {
        token.setFeeBps(100); // 1%
        uint256 before = token.balanceOf(address(vault));

        vm.expectRevert(abi.encodeWithSelector(AVIPStakeVault.InexactTransfer.selector, 1_000, 990));
        _deposit(validator, 1_000);

        assertEq(token.balanceOf(address(vault)), before, "nothing moved");
        assertEq(vault.escrowedUnits(validator), 0, "nothing credited");
        assertEq(vault.totalEscrowedUnits(), 0, "no aggregate to reconcile");
    }

    function test_withdraw_returnsTheCallersOwnEscrow() public {
        uint256 units = 1_000_000;
        _deposit(validator, units);
        uint256 before = token.balanceOf(validator);

        vm.expectEmit(true, false, false, true, address(vault));
        emit AVIPStakeVault.Withdrawn(validator, units);
        vm.prank(validator);
        vault.withdraw(units);

        assertEq(token.balanceOf(validator), before + units, "returned to its owner");
        assertEq(vault.escrowedUnits(validator), 0, "escrow cleared");
        assertEq(vault.totalEscrowedUnits(), 0, "aggregate cleared");
        assertEq(vault.totalReleased(), units, "counted as released");
    }

    function test_withdraw_rejectsAZeroAmount() public {
        vm.expectRevert(AVIPStakeVault.ZeroAmount.selector);
        vm.prank(validator);
        vault.withdraw(0);
    }

    function test_withdraw_cannotTakeMoreThanTheCallerDeposited() public {
        _deposit(validator, 1_000);

        vm.expectRevert(
            abi.encodeWithSelector(AVIPStakeVault.StakeLocked.selector, validator, 1_001, 1_000)
        );
        vm.prank(validator);
        vault.withdraw(1_001);
    }

    function test_withdraw_cannotReachAnotherValidatorsEscrow() public {
        _deposit(validator, 1_000);

        // `stranger` has deposited nothing: `withdrawable` is its own escrow, not
        // the vault's balance, so the validator's funds are unreachable.
        vm.expectRevert(abi.encodeWithSelector(AVIPStakeVault.StakeLocked.selector, stranger, 1, 0));
        vm.prank(stranger);
        vault.withdraw(1);
    }

    function test_withdraw_isCappedByTheStakeTheManagerHasOnRecord() public {
        uint256 units = _unitsCovering(SF_AT_THETA_R);
        _deposit(validator, units);
        _admit(SF_AT_THETA_R);

        // The whole escrow stands behind `stakeOf`, so nothing is withdrawable...
        assertEq(vault.withdrawable(validator), 0, "fully locked");
        vm.expectRevert(
            abi.encodeWithSelector(AVIPStakeVault.StakeLocked.selector, validator, 1, 0)
        );
        vm.prank(validator);
        vault.withdraw(1);

        // ... and a surplus on top is free.
        _fund(validator, 5);
        _deposit(validator, 5);
        assertEq(vault.withdrawable(validator), 5, "only the surplus");
        vm.prank(validator);
        vault.withdraw(5);
        assertEq(vault.escrowedUnits(validator), units, "the stake is untouched");
    }

    function test_withdraw_locksTheStakeRoundedUpSoItCanNeverBeReached() public {
        // A stake that is not a whole number of base units. `S_f*(Theta_r)` is
        // `733333333333333334` WAD = `733333.333...334` base units, so the escrow
        // that just covers it is `733334` units, leaving `666666` WAD of surplus
        // — *less than one base unit*. If the lock rounded down, that surplus
        // would be withdrawable and the stake on record would drop below the
        // minimum the manager admitted. It rounds up, so it is not.
        uint256 units = _unitsCovering(SF_AT_THETA_R);
        _deposit(validator, units);
        _admit(SF_AT_THETA_R);

        assertEq(
            vault.escrowed(validator) - SF_AT_THETA_R,
            666_666_666_666,
            "the remainder the token cannot represent (less than one base unit)"
        );
        assertLt(vault.escrowed(validator) - SF_AT_THETA_R, WAD_PER_UNIT_6, "indeed dust");
        assertEq(vault.withdrawable(validator), 0, "the round-up holds it");
    }

    function test_withdraw_returnsEverythingAfterTheManagerEjectsTheValidator() public {
        _depositAndAdmit(SF_AT_THETA_R);
        assertEq(vault.withdrawable(validator), 0, "locked while admitted");

        // The slash takes the whole record, which ejects the validator (§5.2.3),
        // and the lock goes with the admission. What the escrow kept is the
        // round-up of §5.12: `_unitsCovering` escrowed one unit more than the
        // record's floor, and that unit is the validator's again.
        _slash(REASON_LATE_BLOCK);
        assertFalse(manager.isAdmitted(validator), "ejected");
        assertEq(manager.stakeOf(validator), 0, "record cleared");

        uint256 left = vault.escrowedUnits(validator);
        assertTrue(left > 0, "the round-up is left to return");
        assertEq(vault.withdrawable(validator), left, "everything is free again");
        vm.prank(validator);
        vault.withdraw(left);
        assertEq(vault.escrowedUnits(validator), 0);
    }

    function test_strayTokensAreHeldButNotAttributableToAnyone() public {
        _deposit(validator, 1_000);
        uint256 escrow = vault.totalEscrowedUnits();

        // Somebody sends tokens to the vault by another route. No function here
        // can move them: they are not escrow, so no validator can withdraw them
        // and neither `debit` nor `payFee` ever touches the balance.
        token.mint(address(vault), 777);

        assertEq(vault.heldUnits(), escrow + 777, "held");
        assertEq(vault.totalEscrowedUnits(), escrow, "but not accounted for");
        assertEq(vault.withdrawable(validator), 1_000, "not one unit of it is withdrawable");

        vm.expectRevert(
            abi.encodeWithSelector(AVIPStakeVault.StakeLocked.selector, validator, 1_001, 1_000)
        );
        vm.prank(validator);
        vault.withdraw(1_001);
    }

    // --------------------------------------------------------------- admission

    function test_admit_requiresTheEscrowToCoverTheDeclaration() public {
        // Nothing escrowed, a declaration of the whole minimum: the manager's new
        // check refuses it, before any state is written.
        vm.expectRevert(
            abi.encodeWithSelector(
                IAVIPValidatorManager.FinancialStakeNotBacked.selector, SF_AT_THETA_R, 0
            )
        );
        _admit(SF_AT_THETA_R);

        assertFalse(manager.isAdmitted(validator), "not admitted");
        assertEq(manager.stakeOf(validator), 0, "nothing recorded");
    }

    function test_admit_passesWithExactlyTheRequiredStakeEscrowed() public {
        uint256 units = _unitsCovering(SF_AT_THETA_R);
        _deposit(validator, units);
        _admit(SF_AT_THETA_R);

        assertTrue(manager.isAdmitted(validator), "admitted");
        assertEq(manager.stakeOf(validator), SF_AT_THETA_R, "the declaration, in WAD");
        assertEq(vault.escrowed(validator), units * WAD_PER_UNIT_6, "escrow in WAD");
        assertGe(vault.escrowed(validator), SF_AT_THETA_R, "covering the declaration");
        assertTrue(vault.isBacked(validator), "the invariant, as a view");
    }

    function test_admit_isRefusedWhenTheEscrowIsOneBaseUnitShort() public {
        uint256 units = _unitsCovering(SF_AT_THETA_R) - 1; // one cent short
        _deposit(validator, units);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAVIPValidatorManager.FinancialStakeNotBacked.selector,
                SF_AT_THETA_R,
                units * WAD_PER_UNIT_6
            )
        );
        _admit(SF_AT_THETA_R);
    }

    function test_admit_acceptsADeclarationBelowTheEscrow() public {
        uint256 units = _unitsCovering(SF_AT_THETA_R) + 10;
        _deposit(validator, units);
        _admit(SF_AT_THETA_R);

        assertTrue(manager.isAdmitted(validator), "admitted");
        assertEq(vault.withdrawable(validator), 10, "the surplus stays free");
        assertTrue(vault.isBacked(validator), "escrow above the record is still backing it");
    }

    function test_admit_withoutCustodyBehavesExactlyLikeM2() public {
        // The amendment's compatibility claim: `custody == address(0)` is the
        // original manager, which declares the stake and checks no balance.
        AVIPValidatorManager m2 =
            new AVIPValidatorManager(address(registry), slashAuthority, address(0));
        assertEq(address(m2.custody()), address(0), "no custody");

        vm.prank(validator);
        m2.admit(validator, SF_AT_THETA_R, THETA_R, _encodeProof(PROOF_A0));

        assertTrue(m2.isAdmitted(validator), "admitted with nothing escrowed anywhere");
        assertEq(m2.stakeOf(validator), SF_AT_THETA_R, "declared");

        // And a slash there moves no funds, because there are none to move.
        vm.prank(slashAuthority);
        m2.slash(validator, REASON_COLLUSION);
        assertEq(m2.stakeOf(validator), 0, "the record is the whole amount");
        assertEq(vault.escrowedUnits(validator), 0, "the vault was never involved");
        assertEq(sink.totalReceived(), 0, "and neither was the sink");
    }

    // ------------------------------------------------------------------ slashing

    /// @dev The case M9b's derived amount makes exact: a declaration that *is* a
    ///      whole number of base units, escrowed exactly. The slash moves the
    ///      escrow the record names and the record with it, so nothing is left on
    ///      either side — where the old transported amount could ask for less and
    ///      leave a remainder behind.
    function test_slash_debitsExactlyTheEscrowTheRecordNames() public {
        uint256 declared = 1e18; // 1_000_000 units, exactly
        _depositAndAdmit(declared);
        assertEq(vault.escrowed(validator), declared, "escrow equals the record");
        assertEq(vault.escrowedUnits(validator), declared / WAD_PER_UNIT_6);
        assertEq(vault.withdrawable(validator), 0, "locked while admitted");

        uint256 movedUnits = declared / WAD_PER_UNIT_6;

        vm.expectEmit(true, false, false, true, address(vault));
        emit AVIPStakeVault.StakeDebited(validator, declared, movedUnits, REASON_COLLUSION);
        _slash(REASON_COLLUSION);

        assertEq(manager.stakeOf(validator), 0, "the whole record went");
        assertFalse(manager.isAdmitted(validator), "and the admission with it");
        assertEq(vault.escrowedUnits(validator), 0, "the escrow went too, to the unit");
        assertEq(vault.withdrawable(validator), 0, "nothing is left to withdraw");
        assertEq(vault.totalDebited(), movedUnits, "counted as debited");
        assertEq(sink.totalReceived(), movedUnits, "the sink holds exactly that");
        assertEq(vault.heldUnits(), 0, "the vault holds nothing");
        assertTrue(vault.isBacked(validator), "the invariant holds at zero");
    }

    function test_slash_takesTheFundsOutOfCustodyAndIntoTheSink() public {
        // An escrow *above* the declaration (`admit` allows it): the slash takes
        // the record and the surplus stays the validator's, withdrawable because
        // the same call ejected it.
        uint256 buffer = 1e18;
        uint256 units = _unitsCovering(SF_AT_THETA_R + buffer) + 1_000;
        _deposit(validator, units);
        _admit(SF_AT_THETA_R + buffer);

        uint256 sinkBefore = token.balanceOf(address(sink));
        uint256 movedUnits = (SF_AT_THETA_R + buffer) / WAD_PER_UNIT_6;

        vm.expectEmit(true, false, false, true, address(vault));
        emit AVIPStakeVault.StakeDebited(
            validator, SF_AT_THETA_R + buffer, movedUnits, REASON_COLLUSION
        );
        _slash(REASON_COLLUSION);

        assertEq(
            vault.escrowedUnits(validator), units - movedUnits, "escrow fell by the units moved"
        );
        assertEq(vault.totalEscrowedUnits(), units - movedUnits, "aggregate");
        assertEq(vault.totalDebited(), movedUnits, "counted as debited");
        assertEq(token.balanceOf(address(sink)), sinkBefore + movedUnits, "the sink holds them");
        assertEq(sink.totalReceived(), movedUnits, "and was told");
        assertEq(sink.lastReason(), REASON_COLLUSION, "with the provenance id");
        assertEq(sink.lastAmount(), movedUnits, "and the measured amount");
        assertEq(manager.stakeOf(validator), 0, "the record is emptied, not reduced");
        assertFalse(manager.isAdmitted(validator), "so the validator is out");
        assertEq(
            vault.withdrawable(validator),
            units - movedUnits,
            "and the surplus is the validator's again"
        );
        assertTrue(vault.isBacked(validator), "and the invariant holds");
    }

    function test_debit_belowOneBaseUnitMovesNothingAndTheRecordCanStillFall() public {
        // The manager slashes in WAD; the token has no unit that small. `debit`
        // floors, so nothing moves when it is called with less than one unit —
        // and the record can drop anyway, which leaves the vault holding *more*
        // than the record: the direction that keeps `escrowed >= stakeOf` true
        // (§5.12).
        //
        // Since M9b nothing reaches this boundary through `slash`: the amount is
        // the whole record and `admit` made the escrow cover it, so the floored
        // units a slash moves are always funded. The rounding is asserted where it
        // lives — at `debit`, as the manager calls it.
        _depositAndAdmit(SF_AT_THETA_R + 1);
        uint256 escrowBefore = vault.escrowedUnits(validator);

        vm.prank(address(manager));
        vault.debit(validator, 1, REASON_LATE_BLOCK); // one wei of WAD

        assertEq(vault.escrowedUnits(validator), escrowBefore, "no base unit moved");
        assertEq(sink.totalReceived(), 0, "the sink saw nothing");
        assertEq(vault.totalDebited(), 0, "nothing was debited");

        // The same record, this time through the manager's own slash: the whole
        // record goes and the units that move are its floor, which the escrow
        // covered.
        _slash(REASON_LATE_BLOCK);
        assertEq(manager.stakeOf(validator), 0, "the record fell");
        assertFalse(manager.isAdmitted(validator), "ejected");
        assertEq(
            vault.escrowedUnits(validator),
            escrowBefore - (SF_AT_THETA_R + 1) / WAD_PER_UNIT_6,
            "exactly the floored units left"
        );
        assertTrue(vault.isBacked(validator), "and the invariant holds");
    }

    function test_slash_canTakeTheWholeStakeAndLeavesTheSurplusBehind() public {
        _depositAndAdmit(SF_AT_THETA_R);
        _fund(validator, 5);
        _deposit(validator, 5);

        _slash(REASON_COLLUSION); // the whole record

        assertEq(manager.stakeOf(validator), 0, "record cleared");
        assertFalse(manager.isAdmitted(validator), "ejected");
        assertEq(sink.totalReceived(), SF_AT_THETA_R / WAD_PER_UNIT_6, "what moved");
        // Flooring means the vault kept what the token could not express:
        assertTrue(vault.escrowedUnits(validator) > 0, "a unit of dust stays");
        assertEq(
            vault.withdrawable(validator),
            vault.escrowedUnits(validator),
            "and it belongs to the validator"
        );
        assertTrue(vault.isBacked(validator), "nothing stands behind a cleared record");
    }

    /// @dev M9c (§12.1.2): the ejection count is a record about the validator, not
    ///      about its escrow. Withdrawing everything does not erase it, and it is
    ///      what prices the next admission.
    function test_ejection_theCountSurvivesTheWithdrawalAndPricesTheReEntry() public {
        uint256 kappa = manager.EJECTION_SURCHARGE();

        _depositAndAdmit(SF_AT_THETA_R);
        _slash(REASON_COLLUSION);
        assertEq(manager.ejectionsOf(validator), 1, "one ejection on record");

        uint256 free = vault.withdrawable(validator);
        vm.prank(validator);
        vault.withdraw(free);
        assertEq(vault.escrowedUnits(validator), 0, "the escrow is gone");
        assertEq(manager.ejectionsOf(validator), 1, "the history is not the escrow");

        // The escrow that used to admit this validator is now one surcharge short.
        _deposit(validator, _unitsCovering(SF_AT_THETA_R));
        vm.prank(validator);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAVIPValidatorManager.InsufficientFinancialStake.selector,
                SF_AT_THETA_R,
                SF_AT_THETA_R + kappa
            )
        );
        manager.admit(validator, SF_AT_THETA_R, THETA_R, _encodeProof(PROOF_A0));

        // One surcharge more, and it is admitted again — with the same credit.
        uint256 extra = _unitsCovering(SF_AT_THETA_R + kappa) - _unitsCovering(SF_AT_THETA_R);
        _fund(validator, extra);
        _deposit(validator, extra);
        vm.prank(validator);
        manager.admit(validator, SF_AT_THETA_R + kappa, THETA_R, _encodeProof(PROOF_A0));

        assertTrue(manager.isAdmitted(validator), "back in");
        assertEq(manager.requiredStake(validator), SF_AT_THETA_R + kappa, "priced by history");
        assertEq(
            manager.collateralOf(validator),
            manager.collateralFor(THETA_R),
            "the credit did not move"
        );
        assertTrue(vault.isBacked(validator), "and the escrow covers the new requirement");
    }

    function test_slash_isAtomicWhenTheTokenRefusesTheTransfer() public {
        uint256 buffer = 1e18;
        _deposit(validator, _unitsCovering(SF_AT_THETA_R + buffer));
        _admit(SF_AT_THETA_R + buffer);

        uint256 stakeBefore = manager.stakeOf(validator);
        uint256 escrowBefore = vault.escrowedUnits(validator);
        token.setBlocked(true);

        vm.expectRevert(bytes("mock: token blocked"));
        _slash(REASON_COLLUSION);

        // The manager wrote `stakeOf` before calling custody; the token's revert
        // rolled that write back with everything else. This is the milestone's
        // atomicity claim, asserted rather than argued.
        assertEq(manager.stakeOf(validator), stakeBefore, "record restored");
        assertTrue(manager.isAdmitted(validator), "still admitted");
        assertEq(vault.escrowedUnits(validator), escrowBefore, "escrow untouched");
        assertEq(sink.totalReceived(), 0, "the sink saw nothing");
    }

    function test_slash_isAtomicWhenTheSinkRefusesTheFunds() public {
        uint256 buffer = 1e18;
        _deposit(validator, _unitsCovering(SF_AT_THETA_R + buffer));
        _admit(SF_AT_THETA_R + buffer);

        uint256 stakeBefore = manager.stakeOf(validator);
        uint256 escrowBefore = vault.escrowedUnits(validator);
        sink.setRefuse(true);

        vm.expectRevert(bytes("mock: sink refuses"));
        _slash(REASON_COLLUSION);

        assertEq(manager.stakeOf(validator), stakeBefore, "record restored");
        assertEq(vault.escrowedUnits(validator), escrowBefore, "escrow restored");
        assertEq(token.balanceOf(address(sink)), 0, "and nothing reached the sink");
    }

    function test_debit_isManagerOnly() public {
        // Nobody else, not even another contract in the protocol, can move escrow.
        vm.expectRevert(abi.encodeWithSelector(AVIPStakeVault.NotManager.selector, address(this)));
        vault.debit(validator, 1e18, REASON_COLLUSION);

        vm.expectRevert(abi.encodeWithSelector(AVIPStakeVault.NotManager.selector, stranger));
        vm.prank(stranger);
        vault.debit(validator, 1e18, REASON_COLLUSION);

        vm.expectRevert(abi.encodeWithSelector(AVIPStakeVault.NotManager.selector, address(sink)));
        vm.prank(address(sink));
        vault.debit(validator, 1e18, REASON_COLLUSION);
    }

    function test_debit_refusesMoreThanTheValidatorHasEscrowed() public {
        _deposit(validator, 1_000);

        // Called *as the manager*, so the only thing that can fail is the bound.
        vm.prank(address(manager));
        vm.expectRevert(
            abi.encodeWithSelector(
                AVIPStakeVault.InsufficientEscrow.selector, validator, 1_000_000, 1_000
            )
        );
        vault.debit(validator, 1e18, REASON_COLLUSION);
    }

    function test_debit_obeysTheManagerRecordEvenForANonAdmittedValidator() public {
        // Custody has no opinion of its own: it moves what its manager asks for,
        // bounded only by the escrow. Nothing here is reachable by a validator.
        _deposit(validator, 1_000);

        vm.prank(address(manager));
        vault.debit(validator, 1_000 * WAD_PER_UNIT_6, REASON_COLLUSION);

        assertEq(vault.escrowedUnits(validator), 0, "moved");
        assertEq(token.balanceOf(address(sink)), 1_000, "to the sink");
    }

    /// @dev The invariant and the ledger under the amounts that are left free: how
    ///      much is declared, and how much escrow sits above it. The slash itself
    ///      takes one number — the record — so what a fuzz can vary is the record
    ///      and the surplus around it.
    function testFuzz_slashTakesTheRecordAndKeepsTheInvariant(uint96 declaredWad, uint16 surplus)
        public
    {
        uint256 declared = bound(uint256(declaredWad), SF_AT_THETA_R, 1e24);
        uint256 units = _unitsCovering(declared) + uint256(surplus);
        // The escrow is minted here rather than taken from the setUp balance: a
        // fuzz over the declaration needs an escrow that covers whatever it picks.
        _fund(validator, units);
        _deposit(validator, units);
        _admit(declared);

        uint256 movedUnits = declared / WAD_PER_UNIT_6;

        _slash(REASON_COLLUSION);

        // The invariant, and the books, for every record and every surplus:
        assertTrue(vault.isBacked(validator), "escrowed >= stakeOf");
        assertEq(manager.stakeOf(validator), 0, "the record is emptied");
        assertEq(vault.escrowedUnits(validator), units - movedUnits, "exactly the floored units");
        assertEq(token.balanceOf(address(sink)), movedUnits, "and the sink holds them");
        assertEq(
            vault.totalDeposited(),
            vault.totalEscrowedUnits() + vault.totalReleased() + vault.totalDebited(),
            "the ledger balances"
        );
    }

    // ---------------------------------------------------------------------- fee

    function test_payFee_movesTheFeeStraightFromThePayerToTheSink() public {
        _depositAndAdmit(SF_AT_THETA_R);
        uint256 vaultBalance = token.balanceOf(address(vault));
        uint256 payerBefore = token.balanceOf(validator);

        assertEq(vault.feeInUnits(), FEE_UNITS_6, "F_0*/WAD_PER_UNIT");
        assertEq(vault.feeInUnits() * WAD_PER_UNIT_6, F0_STAR, "and it is the manager's F_0*");

        vm.expectEmit(true, false, false, true, address(vault));
        emit AVIPStakeVault.FeePaid(validator, F0_STAR, FEE_UNITS_6);
        vm.prank(validator);
        uint256 paid = vault.payFee();

        assertEq(paid, FEE_UNITS_6, "charged");
        assertEq(
            token.balanceOf(validator), payerBefore - FEE_UNITS_6, "out of the payer's balance"
        );
        assertEq(token.balanceOf(address(vault)), vaultBalance, "never through the vault");
        assertEq(sink.totalReceived(), FEE_UNITS_6, "at the sink");
        assertEq(sink.lastReason(), vault.FEE_REASON(), "with the fee tag");
        assertEq(vault.totalFeesPaid(), FEE_UNITS_6, "counted as a fee");
        assertEq(vault.totalDebited(), 0, "not as a debited stake");
        assertEq(vault.escrowedUnits(validator), _unitsCovering(SF_AT_THETA_R), "escrow untouched");
    }

    function test_payFee_revertsForANonAdmittedPayer() public {
        vm.expectRevert(abi.encodeWithSelector(AVIPStakeVault.NotAdmitted.selector, stranger));
        vm.prank(stranger);
        vault.payFee();
    }

    function test_payFee_chargesOnlyItsCaller() public {
        _depositAndAdmit(SF_AT_THETA_R);
        uint256 validatorBefore = token.balanceOf(validator);

        // A third party cannot charge a validator: the fee is paid by whoever
        // calls, and only an admitted caller can pay it at all.
        vm.expectRevert(abi.encodeWithSelector(AVIPStakeVault.NotAdmitted.selector, stranger));
        vm.prank(stranger);
        vault.payFee();

        assertEq(token.balanceOf(validator), validatorBefore, "nobody was charged on its behalf");
        assertEq(sink.totalReceived(), 0, "and nothing arrived");
    }

    function test_payFee_hasNoPerEpochLedgerHere() public {
        _depositAndAdmit(SF_AT_THETA_R);

        vm.prank(validator);
        vault.payFee();
        vm.prank(validator);
        vault.payFee();

        // The vault charges, twice, in the same block. Charging once per epoch is
        // the caller's policy, and this contract makes no claim about it (§5.12).
        assertEq(sink.totalReceived(), 2 * FEE_UNITS_6, "charged twice");
        assertEq(vault.totalFeesPaid(), 2 * FEE_UNITS_6, "and counted twice");
    }

    function test_payFee_revertsWhenTheTokenIsTooCoarseToChargeTheFee() public {
        // A one-decimal token: `F_0* = 0.05` is smaller than one base unit
        // (`1e17` WAD), so the fee cannot be charged exactly. The call is refused
        // rather than silently rounded to zero or up to a whole unit.
        MockERC20 coarse = new MockERC20("Coarse", 1);
        MockFundSink coarseSink = new MockFundSink();
        AVIPStakeVault coarseVault = new AVIPStakeVault(address(coarse), address(coarseSink), 1e17);
        AVIPValidatorManager coarseManager =
            new AVIPValidatorManager(address(registry), slashAuthority, address(coarseVault));

        coarse.mint(validator, 100);
        vm.prank(validator);
        coarse.approve(address(coarseVault), 100);
        vm.prank(validator);
        coarseVault.deposit(8); // `ceil(S_f*/1e17)` units

        vm.prank(validator);
        coarseManager.admit(validator, SF_AT_THETA_R, THETA_R, _encodeProof(PROOF_A0));
        assertTrue(coarseManager.isAdmitted(validator), "admitted");

        assertEq(coarseVault.feeInUnits(), 0, "F_0* is below one base unit");
        vm.expectRevert(
            abi.encodeWithSelector(AVIPStakeVault.FeeRoundsToZero.selector, F0_STAR, 1e17)
        );
        vm.prank(validator);
        coarseVault.payFee();
    }

    // -------------------------------------------------------------- token quirks

    function test_aTokenThatReturnsNothingIsAcceptedEndToEnd() public {
        // USDT-style: `transfer` and `transferFrom` return no data at all. Every
        // path of the vault must work anyway, because nothing here reads a
        // boolean — it measures balance deltas.
        token.setReturnsNothing(true);

        _deposit(validator, _unitsCovering(SF_AT_THETA_R));
        _admit(SF_AT_THETA_R);
        assertTrue(manager.isAdmitted(validator), "admitted");

        vm.prank(validator);
        vault.payFee();
        assertEq(sink.totalReceived(), FEE_UNITS_6, "fee arrived");

        // The whole record goes, and the escrow that covered it was
        // `ceil(SF/1e12)`, so the slash moves the floor and the round-up unit is
        // all that comes back.
        _slash(REASON_LATE_BLOCK);
        assertEq(
            sink.totalReceived(),
            FEE_UNITS_6 + SF_AT_THETA_R / WAD_PER_UNIT_6,
            "slash moved the record's floor"
        );
        assertFalse(manager.isAdmitted(validator), "ejected");

        uint256 left = vault.withdrawable(validator);
        assertTrue(left > 0, "the round-up unit is left");
        vm.prank(validator);
        vault.withdraw(left);
        assertEq(vault.escrowedUnits(validator), 0, "everything came back");
    }

    function test_aTokenThatReturnsFalseIsTreatedAsAFailure() public {
        // The harshest shape: the tokens moved and the token still said no. The
        // vault trusts no boolean, so the whole call reverts with the selector it
        // was calling, and the token's own moves are rolled back with it.
        _deposit(validator, 1_000);
        uint256 before = token.balanceOf(validator);
        token.setReturnsFalse(true);

        vm.expectRevert(
            abi.encodeWithSelector(
                AVIPStakeVault.TokenReturnedFalse.selector, IERC20Minimal.transferFrom.selector
            )
        );
        _deposit(validator, 1_000);

        assertEq(token.balanceOf(validator), before, "the token's move was rolled back too");
        assertEq(vault.escrowedUnits(validator), 1_000, "and the escrow is what it was");
    }

    function test_aTokenThatRevertsWithAReasonIsBubbledUnchanged() public {
        _deposit(validator, 1_000);
        token.setBlocked(true);

        // The token's own message survives, which is what makes a failing
        // deployment diagnosable instead of a selector with no story.
        vm.expectRevert(bytes("mock: token blocked"));
        _deposit(validator, 1_000);

        vm.expectRevert(bytes("mock: token blocked"));
        vm.prank(validator);
        vault.withdraw(1_000);

        assertEq(vault.escrowedUnits(validator), 1_000, "the failed withdrawal wrote nothing");
    }

    function test_aTokenThatRevertsWithNoDataIsReportedAsATokenCallFailure() public {
        _deposit(validator, 1_000);
        token.setBlocked(true);
        token.setBlockSilently(true);

        // No story to bubble: the vault says which call failed instead.
        vm.expectRevert(
            abi.encodeWithSelector(
                AVIPStakeVault.TokenCallFailed.selector, IERC20Minimal.transfer.selector
            )
        );
        vm.prank(validator);
        vault.withdraw(1_000);
    }

    // ---------------------------------------------------------------- reentrancy

    function test_aReentrantTokenCannotWithdrawTwice() public {
        _deposit(validator, 1_000);

        // The token re-enters `withdraw` while the vault is transferring out. By
        // then the escrow is already zero, so the inner call has nothing to take.
        token.setReentry(
            address(vault), abi.encodeWithSelector(AVIPStakeVault.withdraw.selector, uint256(1_000))
        );
        vm.prank(validator);
        vault.withdraw(1_000);

        assertEq(token.reentryAttempts(), 1, "the token did try");
        assertFalse(token.lastReentrySucceeded(), "and the attempt failed");
        assertEq(vault.escrowedUnits(validator), 0, "paid out once");
        assertEq(token.balanceOf(validator), 10 * SF_AT_THETA_R / WAD_PER_UNIT_6, "all of it, once");
    }

    function test_aReentrantTokenCannotDebitDuringASlash() public {
        uint256 buffer = 1e18;
        uint256 units = _unitsCovering(SF_AT_THETA_R + buffer);
        _deposit(validator, units);
        _admit(SF_AT_THETA_R + buffer);

        // The token re-enters `debit` while the vault is paying the sink: the
        // caller is the token, not the manager, so the door is shut.
        token.setReentry(
            address(vault),
            abi.encodeWithSelector(
                AVIPStakeVault.debit.selector, validator, uint256(1e18), REASON_COLLUSION
            )
        );
        _slash(REASON_COLLUSION);

        assertFalse(token.lastReentrySucceeded(), "the re-entry failed");
        assertEq(
            sink.totalReceived(),
            (SF_AT_THETA_R + buffer) / WAD_PER_UNIT_6,
            "the sink was paid exactly once"
        );
        assertEq(
            vault.escrowedUnits(validator),
            units - (SF_AT_THETA_R + buffer) / WAD_PER_UNIT_6,
            "escrow moved once"
        );
    }

    function test_aReentrantSinkCannotWithdrawDuringASlash() public {
        uint256 buffer = 1e18;
        uint256 units = _unitsCovering(SF_AT_THETA_R + buffer);
        _deposit(validator, units);
        _admit(SF_AT_THETA_R + buffer);

        // The sink re-enters during its own notification, i.e. after the vault has
        // written everything it was going to write: the escrow is already debited.
        sink.setReentry(
            address(vault), abi.encodeWithSelector(AVIPStakeVault.withdraw.selector, uint256(1_000))
        );
        _slash(REASON_COLLUSION);

        assertEq(sink.reentryAttempts(), 1, "the sink did try");
        assertFalse(sink.lastReentrySucceeded(), "and the attempt failed");
        assertEq(
            vault.escrowedUnits(validator),
            units - (SF_AT_THETA_R + buffer) / WAD_PER_UNIT_6,
            "moved once"
        );
    }

    function test_aReentrantSinkCannotChargeItselfTheFee() public {
        _depositAndAdmit(SF_AT_THETA_R);

        sink.setReentry(address(vault), abi.encodeWithSelector(AVIPStakeVault.payFee.selector));
        vm.prank(validator);
        vault.payFee();

        // The re-entering caller is the sink, which is not admitted: it cannot
        // make the vault charge anybody, itself included.
        assertFalse(sink.lastReentrySucceeded(), "the attempt failed");
        assertEq(vault.totalFeesPaid(), FEE_UNITS_6, "charged once");
    }

    // -------------------------------------------------------------- conservation

    function test_conservation_theLedgerBalancesOverAMixedSequence() public {
        uint256 buffer = 1e18;

        _deposit(validator, 1_000);
        _fund(stranger, 500);
        _deposit(stranger, 500); // a second escrow, never admitted
        _deposit(validator, _unitsCovering(SF_AT_THETA_R + buffer) - 1_000 + 5_000);
        _admit(SF_AT_THETA_R + buffer);
        // The fee is paid while the validator is still admitted: the slash takes
        // the whole record and ejects it (§12.1.2, M9b), so the order is forced by
        // `payFee`'s own rule rather than by preference.
        vm.prank(validator);
        vault.payFee();
        _slash(REASON_COLLUSION);
        // Read the amount before the prank: the getter is an external call and
        // would consume it (the same pitfall the M2 suite documents).
        uint256 free = vault.withdrawable(validator);
        assertTrue(free > 0, "the ejected validator has its escrow back");
        vm.prank(validator);
        vault.withdraw(free);
        vm.prank(stranger);
        vault.withdraw(200);

        // The exact identity: what came in is where it is.
        assertEq(
            vault.totalDeposited(),
            vault.totalEscrowedUnits() + vault.totalReleased() + vault.totalDebited(),
            "deposits = escrow + released + debited"
        );
        assertEq(
            vault.heldUnits(), vault.totalEscrowedUnits(), "the balance is the escrow, exactly"
        );
        assertEq(
            token.balanceOf(address(sink)),
            vault.totalDebited() + vault.totalFeesPaid(),
            "the sink holds exactly what left custody for it"
        );
        assertEq(
            sink.totalReceived(),
            vault.totalDebited() + vault.totalFeesPaid(),
            "and was told about exactly that"
        );
    }

    function test_invariant_isAdmittedImpliesBackedAcrossTheWholeLifecycle() public {
        uint256 buffer = 1e18;
        uint256 units = _unitsCovering(SF_AT_THETA_R + buffer);

        // 1. Escrow first, then admit.
        _deposit(validator, units);
        _admit(SF_AT_THETA_R + buffer);
        assertTrue(vault.isBacked(validator), "admitted and backed");

        // 2. The whole-record slash: the record and the admission go, the escrow
        //    falls by the record's floor, and the invariant never breaks.
        _slash(REASON_COLLUSION);
        assertEq(manager.stakeOf(validator), 0, "record cleared");
        assertFalse(manager.isAdmitted(validator), "ejected");
        assertTrue(vault.isBacked(validator), "backed even so: the round-up covers the zero");

        // 3. The validator takes everything it has left; what the token could not
        //    express comes back with it, so the vault ends empty but consistent.
        uint256 free = vault.withdrawable(validator);
        vm.prank(validator);
        vault.withdraw(free);
        assertEq(vault.escrowedUnits(validator), 0, "empty");
        assertTrue(vault.isBacked(validator), "still trivially backed");
        assertEq(vault.heldUnits(), vault.totalEscrowedUnits(), "no dust anywhere");
    }

    function testFuzz_conservation_theBalanceIsTheLedger(uint96 depositUnits, uint96 withdrawUnits)
        public
    {
        uint256 escrow = bound(uint256(depositUnits), 1, 1_000_000);
        _deposit(validator, escrow);

        // Whatever is asked for, either it leaves or the call reverts; in both
        // cases the two sides of the ledger stay equal.
        uint256 asked = bound(uint256(withdrawUnits), 0, escrow);
        if (asked != 0) {
            vm.prank(validator);
            vault.withdraw(asked);
        }

        assertEq(vault.heldUnits(), vault.totalEscrowedUnits(), "the balance is the escrow");
        assertEq(
            vault.totalDeposited(),
            vault.totalEscrowedUnits() + vault.totalReleased() + vault.totalDebited(),
            "deposits = escrow + released + debited"
        );
    }

    // ------------------------------------------------------- the reference sink

    function test_theReferenceSink_burnsTheSlashedStakeAway() public {
        // `AVIPBurnSink` wired into a live custody: the same path as the tests
        // above, with a sink whose answer to "where do the funds go" is
        // "nowhere — they stop existing".
        MockBurnableERC20 burnToken = new MockBurnableERC20("Burnable", 6);
        AVIPBurnSink burnSink = new AVIPBurnSink(address(burnToken));
        AVIPStakeVault burnVault =
            new AVIPStakeVault(address(burnToken), address(burnSink), WAD_PER_UNIT_6);
        AVIPValidatorManager burnManager =
            new AVIPValidatorManager(address(registry), slashAuthority, address(burnVault));

        // The vault is wired to this sink and to nothing else, through the
        // interface the deployment chose.
        IFundSink wired = burnVault.SINK();
        assertEq(address(wired), address(burnSink), "the sink is the one deployed here");

        uint256 buffer = 1e18;
        uint256 units = _unitsCovering(SF_AT_THETA_R + buffer);
        burnToken.mint(validator, units);
        vm.prank(validator);
        burnToken.approve(address(burnVault), units);
        vm.prank(validator);
        burnVault.deposit(units);
        vm.prank(validator);
        burnManager.admit(validator, SF_AT_THETA_R + buffer, THETA_R, _encodeProof(PROOF_A0));

        uint256 supplyBefore = burnToken.totalSupply();
        uint256 movedUnits = (SF_AT_THETA_R + buffer) / WAD_PER_UNIT_6;

        vm.prank(slashAuthority);
        burnManager.slash(validator, REASON_COLLUSION);

        assertEq(burnSink.totalBurned(), movedUnits, "burned exactly what the slash moved");
        assertEq(burnToken.totalSupply(), supplyBefore - movedUnits, "and the supply fell");
        assertEq(burnToken.balanceOf(address(burnSink)), 0, "the sink holds nothing between calls");
        assertEq(burnVault.escrowedUnits(validator), units - movedUnits, "escrow is the countdown");
        assertTrue(burnVault.isBacked(validator), "the invariant survives a burn");
    }
}

/// WHAT IS TESTED
/// --------------
/// `AVIPBurnSink` on its own: it burns what it holds through the token's own
/// `burn`, records the reason it was told, reports the two ways a token can be
/// unusable (no `burn`, or a `burn` that answers `false`), refuses a zero amount
/// and refuses to burn more than it holds. It holds nothing between calls, and a
/// token sent here by any other route is left untouched: not burned, not counted
/// and not swept.
///
/// WHAT IS NOT TESTED
/// ------------------
/// - That the supply of a real token falls: the sink calls the token's `burn` and
///   the *token* decides what that means (§5.12). No supply is asserted for any
///   deployment.
/// - Where the vault sends funds is `IFundSink`'s contract, not this one's: the
///   vault-side wiring is asserted by `M8StakeVaultTest`.
contract AVIPBurnSinkTest is Test {
    MockBurnableERC20 internal token;
    AVIPBurnSink internal sink;

    address internal caller;

    bytes32 internal constant REASON = "collusion";

    function setUp() public {
        token = new MockBurnableERC20("Burnable", 6);
        sink = new AVIPBurnSink(address(token));
        caller = makeAddr("caller");
        token.mint(address(sink), 1_000);
    }

    function test_burnSink_rejectsAZeroToken() public {
        vm.expectRevert(AVIPBurnSink.ZeroToken.selector);
        new AVIPBurnSink(address(0));
    }

    function test_burnSink_burnsWhatItHoldsAndRecordsTheReason() public {
        // Permissionless on purpose: the only thing a stranger can do here is
        // destroy what the sink already holds. There is no owner, no sweep and no
        // way to move a token out of it.
        vm.expectEmit(false, false, false, true, address(sink));
        emit AVIPBurnSink.FundsBurned(400, REASON, 400);
        vm.prank(caller);
        sink.receiveFunds(400, REASON);

        assertEq(sink.totalBurned(), 400, "counted");
        assertEq(token.totalBurned(), 400, "and destroyed by the token");
        assertEq(token.balanceOf(address(sink)), 600, "the rest is untouched");

        vm.prank(caller);
        sink.receiveFunds(600, REASON);
        assertEq(sink.totalBurned(), 1_000, "accumulated");
        assertEq(token.balanceOf(address(sink)), 0, "nothing left to misread");
    }

    function test_burnSink_rejectsAZeroAmount() public {
        vm.expectRevert(AVIPBurnSink.ZeroAmount.selector);
        sink.receiveFunds(0, REASON);
    }

    function test_burnSink_refusesToBurnMoreThanItHolds() public {
        vm.expectRevert(abi.encodeWithSelector(AVIPBurnSink.BurnFailed.selector, 1_001));
        sink.receiveFunds(1_001, REASON);
    }

    function test_burnSink_reportsATokenThatHasNoBurn() public {
        // The bare `MockERC20` has no `burn(uint256)`: the low-level call has no
        // function to land on. This is the signal that a deployment must pick
        // another sink, and it is a revert rather than a silent no-op.
        MockERC20 plain = new MockERC20("Plain", 6);
        AVIPBurnSink strictSink = new AVIPBurnSink(address(plain));
        plain.mint(address(strictSink), 10);

        vm.expectRevert(abi.encodeWithSelector(AVIPBurnSink.BurnFailed.selector, 10));
        strictSink.receiveFunds(10, REASON);
        assertEq(strictSink.totalBurned(), 0, "and nothing is recorded");
    }

    function test_burnSink_reportsABurnThatAnswersFalse() public {
        token.setBurnReturnsFalse(true);

        vm.expectRevert(abi.encodeWithSelector(AVIPBurnSink.BurnFailed.selector, 10));
        sink.receiveFunds(10, REASON);
        assertEq(sink.totalBurned(), 0, "a false is a failure, not a burn");
    }

    function test_burnSink_strangersTokensAreNotBurnedNotCountedAndNotSwept() public {
        // 500 base units arrive by a route that is not the vault: a plain transfer.
        // The sink has no `receive` hook, no sweep and no function that reads a
        // balance it was not told about, so this changes nothing it records.
        token.mint(address(sink), 500);
        assertEq(sink.totalBurned(), 0, "a stray transfer burns nothing");
        assertEq(token.balanceOf(address(sink)), 1_500, "and it stays where it landed");

        // Only an explicit `receiveFunds` moves the counter, and it burns exactly
        // what it is told — never the unstamped remainder.
        sink.receiveFunds(400, REASON);
        assertEq(sink.totalBurned(), 400, "the counter moves only on a notification");
        assertEq(token.balanceOf(address(sink)), 1_100, "the stray 500 is still unattributed");
    }
}
