// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {AVIPRegistry} from "../../contracts/AVIPRegistry.sol";
import {AVIPStakeVault} from "../../contracts/AVIPStakeVault.sol";
import {AVIPValidatorManager} from "../../contracts/AVIPValidatorManager.sol";
import {IZKThresholdVerifier} from "../../contracts/interfaces/IZKThresholdVerifier.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockFundSink} from "../mocks/MockFundSink.sol";

/// WHAT THIS FILE IS FOR
/// ---------------------
/// The M8 suite asserts the vault's accounting on *chosen* sequences: one
/// deposit, one withdraw, one slash, one fee. Every unit test in this repository
/// is a hand-picked path. These invariants ask the complementary question —
/// does the accounting survive *arbitrary* sequences of the operations the
/// protocol allows, in any order, by any of several validators?
///
/// That is where money bugs live. A slash that lowers `stakeOf` without
/// ejecting, a withdraw that ignores the locked part, a debit that skips the
/// aggregate: each is a one-line regression that a unit test written against
/// the current code will not notice, because the unit test asserts the same
/// sequence that was written to pass. An invariant asserts the property and
/// lets the fuzzer choose the sequence.
///
/// WHAT IS ASSERTED (see `AVIPInvariants` below for the assertions themselves)
/// ---------------------------------------------------------------------------
/// 1. Conservation: `totalDeposited == totalEscrowedUnits + totalReleased +
///    totalDebited`, always.
/// 2. The vault holds exactly what it owes: `heldUnits() == totalEscrowedUnits`.
/// 3. The aggregate is the sum: `Σ escrowedUnits(actor) == totalEscrowedUnits`.
/// 4. `isBacked(actor)` after every action.
/// 5. `isAdmitted(a) => stakeOf(a) >= requiredStake(a)`.
/// 6. A validator that is not admitted has no stake on record.
/// 7. Ejections never decrease.
/// 8. `withdrawable(a) <= escrowedUnits(a)`.
/// 9. The sink received exactly what left escrow.
///
/// WHAT IS NOT TESTED
/// ------------------
/// - **No proof is verified.** `AcceptAllVerifier` returns `true` for every
///   statement, so an admission here says nothing about the pairing check or
///   about §5.2. It exists so the handler can admit arbitrary actors; the real
///   key is exercised in `M4dRealKey.t.sol` and the generated verifier in
///   `Groth16Verifier.t.sol`.
/// - **No token misbehaviour.** `MockERC20` transfers exactly what it is asked,
///   so the fee-on-transfer, `false`-returning and reverting tokens of M8 are out
///   of scope here. With an exact token invariant 2 is an equality; with an
///   inexact one it would have to be an inequality.
/// - **No reentrancy.** The handler makes ordered calls only; the reentrant
///   token and sink attempts are M8's.
/// - **Not the audit.** This is the same author attacking his own code in a
///   second style. It is evidence that the accounting holds under fuzzing, not
///   evidence that it is correct.
contract AcceptAllVerifier is IZKThresholdVerifier {
    /// @inheritdoc IZKThresholdVerifier
    /// @dev Accepts every statement. See "what is not tested" above.
    function verify(
        uint256[2] calldata,
        uint256[2][2] calldata,
        uint256[2] calldata,
        uint256[] calldata
    ) external pure returns (bool) {
        return true;
    }
}

/// @notice Drives the vault and the manager with random, bounded actions.
/// @dev Every action checks its own preconditions and returns silently when they
///      do not hold, so `fail_on_revert = false` is not hiding contract reverts:
///      the handler does not issue a call it has not already established is
///      legal. If the contract's rules and the handler's preconditions ever
///      disagree, the action is skipped — never silently accepted.
contract Handler is Test {
    uint256 internal constant UNIT = 1e12; // 6-decimal token

    MockERC20 public immutable TOKEN;
    AVIPStakeVault public immutable VAULT;
    AVIPValidatorManager public immutable MANAGER;
    address public immutable AUTHORITY;

    address[] public actors;

    /// @notice Revert reasons seen from `admit`, by selector, so a discarded
    ///         action is never invisible (see the catch in `admit`).
    mapping(bytes4 => uint256) public admitReverts;

    bytes32 internal constant REASON = "invariant-run";

    /// @notice How many times each path actually changed state. Read by
    ///         `test_handlerReachesEveryPath`, which is what keeps the invariants
    ///         from passing over a handler that only ever deposits.
    uint256 public deposits;
    uint256 public withdrawals;
    uint256 public admissions;
    uint256 public slashes;
    uint256 public fees;

    constructor(
        MockERC20 token_,
        AVIPStakeVault vault_,
        AVIPValidatorManager manager_,
        address authority_,
        address[] memory actors_
    ) {
        TOKEN = token_;
        VAULT = vault_;
        MANAGER = manager_;
        AUTHORITY = authority_;
        actors = actors_;
    }

    // --------------------------------------------------------------- actions

    function deposit(uint256 actorSeed, uint256 units) external {
        address a = _actor(actorSeed);
        uint256 balance = TOKEN.balanceOf(a);
        if (balance == 0) return;
        units = bound(units, 1, balance);
        vm.prank(a);
        VAULT.deposit(units);
        deposits += 1;
    }

    function withdraw(uint256 actorSeed, uint256 units) external {
        address a = _actor(actorSeed);
        uint256 free = VAULT.withdrawable(a);
        if (free == 0) return;
        units = bound(units, 1, free);
        vm.prank(a);
        VAULT.withdraw(units);
        withdrawals += 1;
    }

    function admit(uint256 actorSeed, uint256 norm) external {
        address a = _actor(actorSeed);
        if (MANAGER.isAdmitted(a)) return;

        norm = bound(norm, MANAGER.THETA_R(), 1e18);
        uint256 stake = MANAGER.requiredStakeFor(norm) + _surcharge(a);

        // Top up to the requirement instead of skipping: without this the action
        // would bail out on an underfunded actor most of the time and the deep
        // states (admitted, then slashed, then re-admitted at a surcharge) would
        // never be reached.
        uint256 have = VAULT.escrowed(a);
        if (have < stake) {
            uint256 needUnits = (stake - have + UNIT - 1) / UNIT;
            if (TOKEN.balanceOf(a) < needUnits) return;
            vm.prank(a);
            VAULT.deposit(needUnits);
            deposits += 1;
            if (VAULT.escrowed(a) < stake) return;
        }

        vm.prank(a);
        try MANAGER.admit(a, stake, norm, _wellFormedProof()) {
            admissions += 1;
        } catch (bytes memory err) {
            // Safe: the branch is only reached when the selector is the first
            // word, and the length is checked before the cast.
            // forge-lint: disable-next-line(unsafe-typecast)
            bytes4 selector = err.length >= 4 ? bytes4(err) : bytes4(0);
            if (admitReverts[selector] == 0) {
                console2.log("admit reverted, selector:");
                console2.logBytes4(selector);
            }
            admitReverts[selector] += 1;
        }
    }

    function slash(uint256 actorSeed) external {
        address a = _actor(actorSeed);
        if (MANAGER.stakeOf(a) == 0) return;
        vm.prank(AUTHORITY);
        MANAGER.slash(a, REASON);
        slashes += 1;
    }

    function payFee(uint256 actorSeed) external {
        address a = _actor(actorSeed);
        if (!MANAGER.isAdmitted(a)) return;
        uint256 fee = VAULT.feeInUnits();
        if (fee == 0) return;
        if (TOKEN.balanceOf(a) < fee) return;
        vm.prank(a);
        VAULT.payFee();
        fees += 1;
    }

    // -------------------------------------------------------------- internal

    /// @dev The surcharge `admit` will add for this actor, in WAD.
    function _surcharge(address a) internal view returns (uint256) {
        return MANAGER.ejectionsOf(a) * MANAGER.EJECTION_SURCHARGE();
    }

    /// @dev A Groth16-shaped proof of the right length. `verifyThreshold` checks
    ///      the encoding before it consults the verifier (`MalformedProof`), and
    ///      the accept-all verifier ignores the contents — so what varies in this
    ///      suite is the state, not the proof.
    function _wellFormedProof() internal pure returns (bytes memory) {
        uint256[2] memory a = [uint256(1), uint256(2)];
        uint256[2][2] memory b = [[uint256(3), uint256(4)], [uint256(5), uint256(6)]];
        uint256[2] memory c = [uint256(7), uint256(8)];
        return abi.encode(a, b, c);
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }
}

/// @notice The invariants themselves, over the handler's random action streams.
contract AVIPInvariants is Test {
    uint256 internal constant UNIT = 1e12; // 6-decimal token
    uint32 internal constant N = 500; // C*D*H, the tensor the paper commits
    uint256 internal constant ACTOR_FUNDING = 1e9; // 1,000 tokens each

    bytes32 internal constant CHAIN_ID = keccak256("avalanche-c-chain");
    bytes32 internal constant FORMULA = keccak256("AVIP/fragment-function/v1");

    MockERC20 internal token;
    MockFundSink internal sink;
    AVIPRegistry internal registry;
    AVIPStakeVault internal vault;
    AVIPValidatorManager internal manager;
    AcceptAllVerifier internal verifier;
    Handler internal handler;

    address internal sequencer;
    address internal slashAuthority;
    address internal guardian;
    address[] internal actors;

    /// @dev Ghost state for invariant 7. Not a fuzz target, see the note there.
    mapping(address => uint256) private _lastEjections;
    mapping(address => bool) private _seen;

    function setUp() public {
        vm.warp(1_700_000_000);
        sequencer = makeAddr("sequencer");
        slashAuthority = makeAddr("slashAuthority");
        guardian = makeAddr("guardian");

        token = new MockERC20("Mock USD", 6);
        sink = new MockFundSink();

        registry = new AVIPRegistry(sequencer, address(0), guardian, CHAIN_ID, FORMULA);
        bytes32 root = keccak256("tensor");
        vm.prank(sequencer);
        registry.postCommitment(0, root, uint256(root), N, CHAIN_ID, FORMULA);

        // The handshake order: custody first, manager second.
        vault = new AVIPStakeVault(address(token), address(sink), UNIT);
        manager = new AVIPValidatorManager(address(registry), slashAuthority, address(vault));

        // The verifier goes in through the same propose/execute path as on chain.
        verifier = new AcceptAllVerifier();
        vm.prank(guardian);
        registry.proposeVerifier(address(verifier));
        vm.warp(block.timestamp + registry.CHANGE_DELAY());
        registry.executeVerifierChange();

        for (uint256 i = 0; i < 5; i++) {
            address a = makeAddr(string.concat("actor", vm.toString(i)));
            actors.push(a);
            token.mint(a, ACTOR_FUNDING);
            vm.prank(a);
            token.approve(address(vault), type(uint256).max);
        }

        handler = new Handler(token, vault, manager, slashAuthority, actors);
        targetContract(address(handler));
    }

    // ------------------------------------------------------------- the handler

    /// @notice The handler is not a machine for doing nothing.
    /// @dev The invariants in this file can only fail if the actions they fuzz
    ///      actually change state. This drives one ordered pass through every path
    ///      and asserts each one landed, so a handler that silently bailed out of
    ///      `admit` (which it did, on a malformed proof, until this was added)
    ///      cannot leave nine green invariants asserting nothing.
    function test_handlerReachesEveryPath() public {
        // 10 tokens: 1e6 base units per token at 6 decimals, against a 1,000-token
        // endowment. (`UNIT` is the WAD factor 1e12, not a token.)
        handler.deposit(0, 10 * 1e6);
        handler.admit(0, 0.5e18);
        handler.payFee(0);
        handler.slash(0);
        handler.withdraw(0, 1);

        assertGt(handler.deposits(), 0, "no deposit landed");
        assertGt(handler.admissions(), 0, "no admission landed");
        assertGt(handler.fees(), 0, "no fee landed");
        assertGt(handler.slashes(), 0, "no slash landed");
        assertGt(handler.withdrawals(), 0, "no withdrawal landed");

        // The surcharge accumulates across ejections (M9c): the first slash
        // ejects and counts one, and the next admission must clear the raised
        // requirement before the second slash counts another.
        address actor = actors[0];
        assertEq(manager.ejectionsOf(actor), 1, "first ejection not counted");
        handler.admit(0, 0.5e18);
        assertTrue(manager.isAdmitted(actor), "re-admission after ejection failed");
        handler.slash(0);
        assertEq(manager.ejectionsOf(actor), 2, "second ejection not counted");
    }

    // ------------------------------------------------------------ invariants

    /// @notice 1. Units are conserved across every path.
    function invariant_conservationOfUnits() public view {
        assertEq(
            vault.totalDeposited(),
            vault.totalEscrowedUnits() + vault.totalReleased() + vault.totalDebited(),
            "deposited != escrowed + released + debited"
        );
    }

    /// @notice 2. The vault holds exactly what it says it owes.
    function invariant_vaultHoldsExactlyItsEscrow() public view {
        assertEq(vault.heldUnits(), vault.totalEscrowedUnits(), "held != totalEscrowedUnits");
    }

    /// @notice 3. The stored aggregate equals the sum over validators.
    function invariant_aggregateIsTheSumOfValidators() public view {
        uint256 sum;
        for (uint256 i = 0; i < actors.length; i++) {
            sum += vault.escrowedUnits(actors[i]);
        }
        assertEq(sum, vault.totalEscrowedUnits(), "sum(escrowedUnits) != totalEscrowedUnits");
    }

    /// @notice 4. Escrow always covers the record the manager holds.
    function invariant_everyValidatorIsBacked() public view {
        for (uint256 i = 0; i < actors.length; i++) {
            assertTrue(vault.isBacked(actors[i]), "escrow does not cover stakeOf");
        }
    }

    /// @notice 5. An admitted validator still satisfies its own requirement.
    function invariant_admissionImpliesRequirement() public view {
        for (uint256 i = 0; i < actors.length; i++) {
            address a = actors[i];
            if (manager.isAdmitted(a)) {
                assertGe(
                    manager.stakeOf(a),
                    manager.requiredStake(a),
                    "admitted but under-collateralised"
                );
            }
        }
    }

    /// @notice 6. A validator that is not admitted has no stake on record.
    function invariant_unadmittedHasNoStake() public view {
        for (uint256 i = 0; i < actors.length; i++) {
            address a = actors[i];
            if (!manager.isAdmitted(a)) {
                assertEq(manager.stakeOf(a), 0, "not admitted but stakeOf != 0");
            }
        }
    }

    /// @notice 7. Ejections never decrease: the count prices the next admission.
    /// @dev The ghost lives here and not in the handler on purpose: Foundry fuzzes
    ///      every public function of the handler, so a recording function there
    ///      would itself be callable with an inflated count and the assertion
    ///      would pass vacuously. The test contract is not a fuzz target.
    function invariant_ejectionsNeverDecrease() public {
        for (uint256 i = 0; i < actors.length; i++) {
            address a = actors[i];
            uint256 current = manager.ejectionsOf(a);
            if (_seen[a]) {
                assertGe(current, _lastEjections[a], "ejections decreased");
            }
            _seen[a] = true;
            _lastEjections[a] = current;
        }
    }

    /// @notice 8. What the vault offers to release never exceeds the escrow.
    function invariant_withdrawableIsWithinEscrow() public view {
        for (uint256 i = 0; i < actors.length; i++) {
            address a = actors[i];
            assertLe(vault.withdrawable(a), vault.escrowedUnits(a), "withdrawable > escrowed");
        }
    }

    /// @notice 9. The sink received exactly what left escrow, in the token too.
    function invariant_sinkReceivedWhatLeftEscrow() public view {
        uint256 expected = vault.totalDebited() + vault.totalFeesPaid();
        assertEq(sink.totalReceived(), expected, "sink reported a different total");
        assertEq(token.balanceOf(address(sink)), expected, "sink holds a different total");
    }
}

