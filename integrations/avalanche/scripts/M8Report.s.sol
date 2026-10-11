// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/console2.sol";
import {DeployCommon} from "./DeployCommon.sol";
import {AVIPBurnSink} from "../contracts/AVIPBurnSink.sol";
import {AVIPRegistry} from "../contracts/AVIPRegistry.sol";
import {AVIPStakeVault} from "../contracts/AVIPStakeVault.sol";
import {AVIPValidatorManager} from "../contracts/AVIPValidatorManager.sol";
import {Groth16Verifier} from "../contracts/verifiers/Groth16Verifier.sol";
import {IAVIPValidatorManager} from "../contracts/interfaces/IAVIPValidatorManager.sol";
import {MockBurnableERC20} from "../test/mocks/MockBurnableERC20.sol";
import {M4bGroth16Fixtures as F4b} from "../test/fixtures/M4bGroth16Fixtures.sol";
import {M8CustodyFixtures as F8} from "../test/fixtures/M8CustodyFixtures.sol";

/// @title M8Report
/// @notice The one documented command of M8 (§5.12): it builds the custody pair
///         (vault, manager, sink) and walks a validator through the whole
///         lifecycle — escrow, admission bound to that escrow, the `F_0*` fee, a
///         slash that leaves custody for the sink — printing one machine-readable
///         line per fact, and one per *refusal*.
///
/// @dev `scripts/m8_report.sh` runs this script and pins its `[m8]` lines to
///      `scripts/m8_output.txt`, then checks the numbers against the transcripts
///      of the milestones they come from (M7a's policy read-back, M7d's stake
///      trajectory and slashing reason, M4b's certified norm) in both directions.
///
///      **Nothing is broadcast and nothing is live.** `forge script` without
///      `--broadcast` simulates locally; `--offline` keeps it hermetic. There is no
///      RPC endpoint, no key and no funds. The token and the sink are the test
///      doubles (`../test/mocks/MockBurnableERC20.sol`), because the subject here
///      is the custody boundary and its accounting, not a live ERC-20 — while the
///      **proof is real**: admission goes through the frozen `Groth16Verifier` with
///      M4b's development key and fixture, exactly as `test/M4bRealKey.t.sol` and
///      M7d's report do.
///
///      **The addresses are this script's own CREATEs**, identical from run to run
///      (a fresh EVM, the same order) and not to be presented as Fuji addresses:
///      the Fuji deployment is the remaining half of
///      `docs/architecture/avalanche-integration.md` §6, with a funded key.
///
///      **What it deliberately does not decide.** Where the funds go is a
///      deployment fact (`IFundSink`, decision `D-M8-0`); this report wires the
///      reference sink, which burns them, so the facts it prints are "the vault
///      moved X to the sink, and the sink destroyed X".
contract M8Report is DeployCommon {
    /// @dev `C·D·H` of the committed fixture tensor, the same `N` the M1/M2 suite
    ///      and `DeployRegistry.s.sol` use.
    uint32 internal constant N = 500;

    /// @dev The roles, as literals: this script is not a deployment, so it has no
    ///      environment to read (the same reasoning M7d's report documents). The
    ///      first three are `DeployCommon`'s, the last two are `anvil` accounts 3
    ///      and 4.
    address internal constant SEQUENCER = ANVIL_1;
    address internal constant SLASH_AUTHORITY = ANVIL_2;
    address internal constant VALIDATOR = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
    address internal constant STRANGER = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;

    MockBurnableERC20 internal token;
    AVIPBurnSink internal sink;
    AVIPStakeVault internal vault;
    AVIPRegistry internal registry;
    Groth16Verifier internal verifier;
    AVIPValidatorManager internal manager;

    /// @dev How many refusals the report observed. Printed as `reject.count`, so a
    ///      report that stopped refusing is visible in the pinned transcript.
    uint256 internal rejections;

    function run() external {
        _refuseMainnet();
        _layer();
        _escrowAndAdmission();
        _fee();
        _slash();
        _refusals();
        _conservation();
        _m8("reject.count", vm.toString(rejections));
        _m8("status", "ok");
    }

    // ------------------------------------------------------------- the layer

    /// @dev The wiring §5.12 describes, in the order the handshake forces: the
    ///      sink, then the vault (which cannot know the manager), then the manager,
    ///      which binds the vault from its own constructor and verifies it.
    function _layer() internal {
        vm.startBroadcast(_deployer());
        token = new MockBurnableERC20("Mock USD", 6);
        sink = new AVIPBurnSink(address(token));
        vault = new AVIPStakeVault(address(token), address(sink), F8.WAD_PER_UNIT);
        verifier = new Groth16Verifier(F4b.verifyingKey());
        registry = new AVIPRegistry(SEQUENCER, address(verifier));
        manager = new AVIPValidatorManager(address(registry), SLASH_AUTHORITY, address(vault));
        vm.stopBroadcast();

        _m8("vault", vm.toString(address(vault)));
        _m8("vault.token", vm.toString(address(token)));
        _m8("vault.sink", vm.toString(address(sink)));
        _m8("vault.wadPerUnit", vm.toString(vault.WAD_PER_UNIT()));
        _m8("vault.manager", vm.toString(vault.manager()));
        _m8("manager.custody", vm.toString(address(manager.custody())));
        _m8("policy.ONE", vm.toString(manager.ONE()));
        _m8("policy.F0_STAR", vm.toString(manager.F0_STAR()));
        _m8(
            "policy.requiredStakeAtThetaR", vm.toString(manager.requiredStakeFor(manager.THETA_R()))
        );
        _m8("custody.feeInUnits", vm.toString(vault.feeInUnits()));

        // The handshake, from both ends. A manager whose custody is not this vault
        // (or a vault that obeys a different manager) would make the whole report
        // meaningless, so it is checked before anything else happens.
        require(
            vault.manager() == address(manager), "M8Report: the vault does not obey the manager"
        );
        require(
            address(manager.custody()) == address(vault),
            "M8Report: the manager's custody is not this vault"
        );
    }

    // -------------------------------------------------- escrow and admission

    /// @dev A validator escrows first and is admitted against it. The declaration
    ///      and the slash that follows are M7d's own numbers
    ///      (`FA8.M7D_ADMIT_STAKE`, `F8.M7D_SLASH_STAKE_AFTER`), which is what makes
    ///      the two milestones commensurable.
    function _escrowAndAdmission() internal {
        vm.prank(SEQUENCER);
        registry.postCommitment(0, bytes32(F4b.STATEMENT_ROOT), N);

        // Fund and approve the *whole* lifecycle in one go: the deposit (pulled
        // into escrow) and the fee (pulled straight to the sink). The reads happen
        // before the `prank`, because an external getter here would consume it —
        // the pitfall the M2 suite documents, hit once in this very script.
        uint256 feeUnits = vault.feeInUnits();
        uint256 funded = F8.ESCROW_UNITS + feeUnits;

        token.mint(VALIDATOR, funded);
        vm.prank(VALIDATOR);
        token.approve(address(vault), funded);
        vm.prank(VALIDATOR);
        uint256 credited = vault.deposit(F8.ESCROW_UNITS);

        vm.prank(VALIDATOR);
        manager.admit(VALIDATOR, F8.M7D_ADMIT_STAKE, F4b.STATEMENT_NORM, F4b.proof());

        _m8("admit.certifiedNorm", vm.toString(F4b.STATEMENT_NORM));
        _m8("admit.declared", vm.toString(manager.stakeOf(VALIDATOR)));
        _m8("admit.collateral", vm.toString(manager.collateralOf(VALIDATOR)));
        _m8("escrow.credited", vm.toString(credited));
        _m8("custody.escrowed", vm.toString(vault.escrowed(VALIDATOR)));
        _m8("custody.backed", vault.isBacked(VALIDATOR) ? "true" : "false");

        require(credited == F8.ESCROW_UNITS, "M8Report: the deposit credited something else");
        require(manager.isAdmitted(VALIDATOR), "M8Report: the validator was not admitted");
        // The invariant, in the direction that matters: what was admitted is
        // covered by what is held.
        require(
            vault.escrowed(VALIDATOR) >= manager.stakeOf(VALIDATOR),
            "M8Report: escrow does not cover the declaration"
        );
    }

    // ------------------------------------------------------------------ fee

    /// @dev `F_0*` charged to its own payer and pushed straight to the sink: it
    ///      never becomes the vault's balance.
    function _fee() internal {
        uint256 burnedBefore = sink.totalBurned();
        uint256 vaultBalanceBefore = token.balanceOf(address(vault));
        uint256 feeUnits = vault.feeInUnits();

        vm.prank(VALIDATOR);
        uint256 paid = vault.payFee();

        _m8("fee.units", vm.toString(paid));
        _m8("fee.reason", vm.toString(vault.FEE_REASON()));
        _m8("fee.burned", vm.toString(sink.totalBurned() - burnedBefore));
        _m8("fee.vaultDelta", vm.toString(token.balanceOf(address(vault)) - vaultBalanceBefore));

        require(paid == feeUnits, "M8Report: the fee is not F_0*/WAD_PER_UNIT");
        require(
            sink.totalBurned() - burnedBefore == paid, "M8Report: the fee did not reach the sink"
        );
        require(
            token.balanceOf(address(vault)) == vaultBalanceBefore,
            "M8Report: the fee passed through the vault"
        );
    }

    // ----------------------------------------------------------------- slash

    /// @dev M7d's own slash, executed against real escrow: the record and the
    ///      funds move in the same call, so they cannot diverge.
    function _slash() internal {
        uint256 burnedBefore = sink.totalBurned();

        vm.prank(SLASH_AUTHORITY);
        manager.slash(VALIDATOR, F8.M7D_SLASHED_STAKE, F8.M7D_SLASH_REASON);

        _m8("slash.amount", vm.toString(F8.M7D_SLASHED_STAKE));
        _m8("slash.units", vm.toString(F8.SLASH_UNITS));
        _m8("slash.reason", vm.toString(F8.M7D_SLASH_REASON));
        _m8("slash.stakeAfter", vm.toString(manager.stakeOf(VALIDATOR)));
        _m8("slash.escrowedAfter", vm.toString(vault.escrowed(VALIDATOR)));
        _m8("slash.admittedAfter", manager.isAdmitted(VALIDATOR) ? "true" : "false");
        _m8("sink.totalBurned", vm.toString(sink.totalBurned()));

        require(
            sink.totalBurned() - burnedBefore == F8.SLASH_UNITS,
            "M8Report: the slash did not reach the sink"
        );
        require(
            vault.escrowed(VALIDATOR) == F8.M7D_SLASH_STAKE_AFTER,
            "M8Report: the escrow is not the value M7d's notification implies"
        );
        require(
            manager.stakeOf(VALIDATOR) == F8.M7D_SLASH_STAKE_AFTER,
            "M8Report: the record and the escrow disagree"
        );
        require(vault.isBacked(VALIDATOR), "M8Report: the invariant broke on the slash");
        require(!manager.isAdmitted(VALIDATOR), "M8Report: the validator should have been ejected");
    }

    // -------------------------------------------------------------- refusals

    /// @dev One line per refusal, the M7d pattern: each of these is a call the
    ///      custody boundary must reject, and a report that stopped rejecting one of
    ///      them is a visible change in the pinned transcript.
    function _refusals() internal {
        // 1. The handshake is one-shot: a second bind, from anybody, reverts.
        try vault.bindManager() {
            revert("M8Report: a second bind succeeded");
        } catch (bytes memory reason) {
            _reject("secondBind", reason);
        }

        // 2. A custody that is already bound fails the manager's deployment: the
        //    constructor binds it and then verifies the result.
        try new AVIPValidatorManager(address(registry), SLASH_AUTHORITY, address(vault)) {
            revert("M8Report: a manager deployed against a bound custody");
        } catch (bytes memory reason) {
            _reject("alreadyBoundCustody", reason);
        }

        // 3. Admission without escrow: the declaration must be covered. The prank
        //    applies to the call inside `try` (a script must not call back into
        //    itself: `address(this)` is ephemeral by definition).
        vm.prank(STRANGER);
        try manager.admit(STRANGER, F8.M7D_ADMIT_STAKE, F4b.STATEMENT_NORM, F4b.proof()) {
            revert("M8Report: an unbacked declaration was admitted");
        } catch (bytes memory reason) {
            _reject("unbackedAdmission", reason);
        }

        // 4. `debit` from anybody but the manager.
        try vault.debit(VALIDATOR, 1, F8.M7D_SLASH_REASON) {
            revert("M8Report: a stranger moved escrow");
        } catch (bytes memory reason) {
            _reject("debitByStranger", reason);
        }

        // 5. The fee, from an address the manager does not admit.
        vm.prank(STRANGER);
        try vault.payFee() {
            revert("M8Report: a non-admitted address paid the fee");
        } catch (bytes memory reason) {
            _reject("feeByNonAdmitted", reason);
        }

        // 6. A token that delivers less than promised: refused, never silently
        //    accepted, because the conservation identity here is exact.
        token.setFeeBps(100);
        token.mint(STRANGER, 1_000);
        vm.prank(STRANGER);
        token.approve(address(vault), 1_000);
        vm.prank(STRANGER);
        try vault.deposit(1_000) {
            revert("M8Report: a fee-on-transfer token was accepted");
        } catch (bytes memory reason) {
            _reject("inexactTransfer", reason);
        }
        token.setFeeBps(0);
    }

    // ----------------------------------------------------------- conservation

    /// @dev The milestone's identity, printed as its parts and then asserted: the
    ///      escrow ledger balances exactly, the vault holds nothing that is not
    ///      escrow, and the sink destroyed exactly what left custody for it.
    function _conservation() internal view {
        _m8("conservation.deposited", vm.toString(vault.totalDeposited()));
        _m8("conservation.escrow", vm.toString(vault.totalEscrowedUnits()));
        _m8("conservation.released", vm.toString(vault.totalReleased()));
        _m8("conservation.debited", vm.toString(vault.totalDebited()));
        _m8("conservation.fees", vm.toString(vault.totalFeesPaid()));
        _m8("conservation.heldUnits", vm.toString(vault.heldUnits()));

        require(
            vault.totalDeposited()
                == vault.totalEscrowedUnits() + vault.totalReleased() + vault.totalDebited(),
            "M8Report: the escrow ledger does not balance"
        );
        require(
            vault.heldUnits() == vault.totalEscrowedUnits(),
            "M8Report: the vault holds something that is not escrow"
        );
        require(
            sink.totalBurned() == vault.totalDebited() + vault.totalFeesPaid(),
            "M8Report: the sink burned something other than what left custody"
        );
    }

    // ---------------------------------------------------------------- logging

    /// @dev The M7d pattern: `[m8] key=value`, one fact per line, so
    ///      `scripts/m8_report.sh` can pin the transcript and check each number
    ///      against the milestone it came from.
    function _m8(string memory key, string memory value) internal pure {
        console2.log(string.concat("[m8] ", key, "=", value));
    }

    /// @dev One refusal row. `reason.length < 4` means the call did not revert — the
    ///      report's own failure, since these sections exist to observe a refusal.
    function _reject(string memory key, bytes memory reason) internal {
        require(reason.length >= 4, "M8Report: an expected refusal did not happen");
        rejections += 1;
        // The first four bytes of revert data are the error's selector, and
        // `reason.length >= 4` is checked above.
        // forge-lint: disable-next-line(unsafe-typecast)
        bytes4 selector = bytes4(reason);
        _m8(string.concat("reject.", key), _errorName(selector));
    }

    /// @dev Selector → name, so the transcript reads without an ABI decoder. An
    ///      unmapped selector prints as `unknown(0x…)`: visible, never silent.
    function _errorName(bytes4 selector) internal pure returns (string memory) {
        if (selector == AVIPStakeVault.ManagerAlreadyBound.selector) return "ManagerAlreadyBound";
        if (selector == AVIPStakeVault.NotManager.selector) return "NotManager";
        if (selector == AVIPStakeVault.NotAdmitted.selector) return "NotAdmitted";
        if (selector == AVIPStakeVault.InexactTransfer.selector) return "InexactTransfer";
        if (selector == IAVIPValidatorManager.FinancialStakeNotBacked.selector) {
            return "FinancialStakeNotBacked";
        }
        return string.concat("unknown(", vm.toString(bytes32(selector)), ")");
    }
}
