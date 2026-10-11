// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AVIPRegistry} from "../contracts/AVIPRegistry.sol";
import {AVIPStakeVault} from "../contracts/AVIPStakeVault.sol";
import {AVIPValidatorManager} from "../contracts/AVIPValidatorManager.sol";
import {IAVIPRegistry} from "../contracts/interfaces/IAVIPRegistry.sol";
import {DeployCommon} from "../scripts/DeployCommon.sol";
import {DeployRegistry} from "../scripts/DeployRegistry.s.sol";
import {DeployStakeVault} from "../scripts/DeployStakeVault.s.sol";
import {DeployValidatorManager} from "../scripts/DeployValidatorManager.s.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockFundSink} from "./mocks/MockFundSink.sol";
import {MockThresholdVerifier} from "./mocks/MockThresholdVerifier.sol";

/// @dev Exposes the one piece of `DeployCommon` that is otherwise only reachable
///      through a script: role resolution.
contract DeployCommonHarness is DeployCommon {
    function roleOr(string memory name, address fallbackTo) external view returns (address) {
        return _roleOr(name, fallbackTo);
    }
}

/// WHAT IS TESTED
/// --------------
/// 1. **Role resolution** (`DeployCommon._roleOr`, exercised on the harness): an
///    *absent* variable and an *empty* one both fall back to the documented
///    default, a well-formed one is used, and a malformed one **reverts** rather
///    than silently deploying a protocol wired to the default.
/// 2. **The two M7a scripts** (`scripts/DeployRegistry.s.sol`,
///    `scripts/DeployValidatorManager.s.sol`) deploy the frozen M1/M2 contracts
///    with no contract change and wire what they were given: the sequencer and an
///    optional verifier on the registry, the registry address and the slash
///    authority on the manager. `deploy` — the only function that creates state,
///    and therefore the home of the chain guard and of the plan validation — is
///    driven here directly, so no test in this file lets the environment decide
///    what gets deployed (see the note below).
/// 3. **The pair the scripts deploy interoperates**: the script's sequencer posts
///    the genesis epoch and installs the threshold verifier, and a validator then
///    `admit`s itself against the manager, with the statement bound to the root
///    the registry holds. With no verifier installed the registry refuses to
///    certify (`VerifierNotSet`) instead of returning a verdict.
/// 4. **The M8 vault script** (`scripts/DeployStakeVault.s.sol`, §5.12) deploys the
///    custody half of the handshake, refuses the three inputs it cannot invent
///    (`TOKEN`, `SINK`, `WAD_PER_UNIT`) and leaves the vault **unbound**; the
///    manager script then completes the handshake by deploying the manager that
///    binds it, and refuses a vault that somebody else bound first.
///
/// WHAT IS NOT TESTED, AND WHY
/// ---------------------------
/// - **Nothing is broadcast.** A dry run is not a deployment: no script here
///   touches an RPC endpoint, so "this is deployed to Fuji" is claimed nowhere in
///   this repository. The *wire format* is exercised (`vm.startBroadcast` inside
///   a test behaves as a prank); the chain is not.
/// - **The environment → plan mapping is asserted out of process.** `run()` and
///   `plan()` are thin: they read the five role variables and hand a `Plan` to
///   `deploy`. They are covered by `../scripts/deploy_dryrun.sh`, which runs the
///   real CLI with a pinned environment — the public defaults with none,
///   `MissingRole` with no `REGISTRY`, and a revert on a malformed address — one
///   fresh process per case. That is deliberate: see the note on `vm.setEnv`.
/// - **The verifier is a double.** `MockThresholdVerifier` is the M1/M2 double,
///   so `admit` is exercised up to, not through, the pairing; M3/M4b cover the
///   real equation separately. M7a deploys no verifier by design, so the double
///   stands in for the `VERIFIER` address an operator installs.
/// - **No gas and no latency claim.** The dry-run transcript deliberately excludes
///   both, so it stays byte-stable across machines.
///
/// A NOTE ON THE ENVIRONMENT (`vm.setEnv`), learned the hard way
/// ------------------------------------------------------------
/// `vm.setEnv` writes are **process-wide and outlive the test that made them**,
/// and the precedence of a later write over an earlier one is *not* something a
/// test can rely on: a test that pins `SEQUENCER` and then rewrites it can still
/// resolve the pinned value, depending on which tests ran before it (observed
/// here, twice, before this file was written this way). Nothing resets the store
/// between tests, and a variable that has been written once cannot be un-written.
///
/// So this suite never lets the environment decide what a script deploys: the
/// scripts are driven through `deploy(Plan)`, which is env-free. The only
/// `setEnv` calls in this file live in the role-resolution tests, and **every
/// name there is written by exactly one test** (`M7A_PROBE_*`), which is correct
/// under either precedence rule. Do not add a second writer for one of those
/// names: add a new name instead.
contract DeployScriptsTest is Test {
    address internal constant ANVIL_0 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address internal constant ANVIL_1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address internal constant ANVIL_2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

    uint256 internal constant THETA_R = 5e17; // 0.5, the worst admissible type
    uint256 internal constant PROOF_A0 = 42; // arbitrary; the double only checks it is forwarded

    DeployRegistry internal registryScript;
    DeployStakeVault internal vaultScript;
    DeployValidatorManager internal managerScript;
    DeployCommonHarness internal harness;

    function setUp() public {
        // Instruments only. No `setEnv` here: this suite cannot clear what an
        // earlier test wrote (see the note above), so it does not pretend to.
        registryScript = new DeployRegistry();
        vaultScript = new DeployStakeVault();
        managerScript = new DeployValidatorManager();
        harness = new DeployCommonHarness();
    }

    // -------------------------------------------------------- role resolution

    function test_roleResolution_absentVariableFallsBackToTheDefault() public view {
        // No test writes `M7A_PROBE_ABSENT`, and a variable that has been written
        // once cannot be un-written, so this is the only honest way to observe
        // the genuinely-absent case.
        assertEq(harness.roleOr("M7A_PROBE_ABSENT", ANVIL_2), ANVIL_2);
    }

    function test_roleResolution_emptyVariableFallsBackToTheDefault() public {
        vm.setEnv("M7A_PROBE_EMPTY", "");
        assertEq(harness.roleOr("M7A_PROBE_EMPTY", ANVIL_2), ANVIL_2, "empty must mean unset");
    }

    function test_roleResolution_validVariableWinsOverTheDefault() public {
        vm.setEnv("M7A_PROBE_VALID", vm.toString(ANVIL_1));
        assertEq(harness.roleOr("M7A_PROBE_VALID", ANVIL_2), ANVIL_1, "the variable wins");
    }

    function test_roleResolution_malformedVariableRevertsInsteadOfFallingBack() public {
        vm.setEnv("M7A_PROBE_TYPO", "0xnot-an-address");

        bool reverted;
        try harness.roleOr("M7A_PROBE_TYPO", ANVIL_2) returns (address) {
            reverted = false;
        } catch {
            reverted = true;
        }

        // `vm.envOr` — the obvious cheatcode — would have returned the default
        // here, silently wiring the protocol to an anvil account after a typo.
        // `_roleOr` parses the string itself precisely so that this reverts.
        assertTrue(reverted, "a malformed address must revert, not fall back to the default");
    }

    function test_roleResolution_truncatedAddressReverts() public {
        vm.setEnv("M7A_PROBE_SHORT", "0x70997970C51812dc3A010C7d01b50e0d17dc79");

        bool reverted;
        try harness.roleOr("M7A_PROBE_SHORT", ANVIL_1) returns (address) {
            reverted = false;
        } catch {
            reverted = true;
        }

        assertTrue(reverted, "a 39-hex-digit address must revert, not be padded");
    }

    // -------------------------------------------------------- DeployRegistry
    //
    // The scripts are driven through `deploy(Plan)`: an explicit plan, no
    // environment, and the same bytes the CLI hands over after `plan()`.

    function test_registryScript_deploysThePlanAndWiresIt() public {
        DeployRegistry.Deployment memory d = registryScript.deploy(_registryPlan(ANVIL_1, ANVIL_2));

        assertEq(d.deployer, ANVIL_0, "deployer, from the plan");
        assertEq(d.sequencer, ANVIL_1, "sequencer, from the plan");
        assertEq(d.verifier, ANVIL_2, "verifier, from the plan");
        assertGt(d.registry.code.length, 0, "registry deployed");

        AVIPRegistry registry = AVIPRegistry(d.registry);
        assertEq(registry.sequencer(), ANVIL_1, "sequencer wired");
        assertEq(address(registry.verifier()), ANVIL_2, "verifier wired");
        assertTrue(registry.sequencer() != d.deployer, "the writer is not the deployer");
    }

    function test_registryScript_installsNoVerifierWhenThePlanHasNone() public {
        // M7a deploys no verifier: `VERIFIER` defaults to the zero address, and
        // the registry accepts that as "none yet".
        DeployRegistry.Deployment memory d =
            registryScript.deploy(_registryPlan(ANVIL_1, address(0)));

        AVIPRegistry registry = AVIPRegistry(d.registry);
        vm.prank(d.sequencer);
        registry.postCommitment(0, keccak256("epoch-0"), 500);

        // That is not a hole: `verifyThreshold` reverts instead of returning a
        // verdict nobody checked.
        assertEq(address(registry.verifier()), address(0), "no verifier installed");
        vm.expectRevert(IAVIPRegistry.VerifierNotSet.selector);
        registry.verifyThreshold(0, THETA_R, _proof(PROOF_A0));
    }

    function test_registryScript_pinsTheFrozenConstants() public {
        AVIPRegistry registry =
            AVIPRegistry(registryScript.deploy(_registryPlan(ANVIL_1, address(0))).registry);

        assertEq(registry.TENSOR_SIZE(), 500, "N = C*D*H = 500");
        assertEq(registry.MAX_DELTA_ENTRIES(), 50, "gamma * N = 0.10 * 500 = 50");
    }

    function test_registryScript_refusesAZeroSequencerPlan() public {
        // A registry whose sequencer is nobody accepts no commitment at all, so
        // the plan is refused even though the caller supplied it explicitly.
        vm.expectRevert(abi.encodeWithSelector(DeployCommon.MissingRole.selector, "SEQUENCER"));
        registryScript.deploy(_registryPlan(address(0), address(0)));
    }

    function test_registryScript_refusesCChainMainnet() public {
        // `run()` is the CLI entry point: its guard must fire before it reads a
        // single role, so a misconfigured shell cannot mask the refusal.
        vm.chainId(43_114);
        vm.expectRevert(abi.encodeWithSelector(DeployCommon.MainnetRefused.selector, 43_114));
        registryScript.run();
    }

    function test_registryScript_allowsFujiCChain() public {
        vm.chainId(43_113); // Fuji: the only chain M7 targets
        assertGt(
            registryScript.deploy(_registryPlan(ANVIL_1, address(0))).registry.code.length,
            0,
            "Fuji must not be refused"
        );
    }

    // ----------------------------------------------- DeployValidatorManager

    function test_managerScript_deploysThePlanAndWiresIt() public {
        address registry = _fixtureRegistry();

        DeployValidatorManager.Deployment memory d = managerScript.deploy(_managerPlan(registry));

        assertEq(d.deployer, ANVIL_0, "deployer, from the plan");
        assertEq(d.registry, registry, "registry, from the plan");
        assertEq(d.slashAuthority, ANVIL_2, "slash authority, from the plan");
        assertGt(d.manager.code.length, 0, "manager deployed");

        AVIPValidatorManager manager = AVIPValidatorManager(d.manager);
        assertEq(address(manager.registry()), registry, "registry wired");
        assertEq(manager.slashAuthority(), ANVIL_2, "slash authority wired");
        assertTrue(manager.slashAuthority() != d.deployer, "the slasher is not the deployer");
    }

    function test_managerScript_pinsThePaperPolicyConstants() public {
        AVIPValidatorManager manager =
            AVIPValidatorManager(managerScript.deploy(_managerPlan(_fixtureRegistry())).manager);

        assertEq(manager.ONE(), 1e18, "WAD");
        assertEq(manager.THETA(), 1e18, "Theta (Payment Rule)");
        assertEq(manager.CR_INF(), 8e17, "C_R^inf = 0.8");
        assertEq(manager.S_MIN(), 2e17, "S_min = 0.2");
        assertEq(manager.THETA_R(), THETA_R, "Theta_r = 0.5");
        assertEq(manager.F0_STAR(), 5e16, "F_0* = 0.05");
        assertEq(
            manager.collateralFor(THETA_R), 266_666_666_666_666_666, "C_R(Theta_r) = 0.2666..."
        );
        assertEq(
            manager.requiredStakeFor(THETA_R), 733_333_333_333_333_334, "S_f*(Theta_r) = 0.7333..."
        );
    }

    function test_managerScript_refusesAZeroRegistryPlan() public {
        // `REGISTRY` has no default *and* the zero address is refused: a manager
        // wired to nobody enforces `Theta_r` against nothing. The variable-level
        // half of this (unset `REGISTRY` in a fresh process) is asserted by
        // `../scripts/deploy_dryrun.sh`.
        vm.expectRevert(abi.encodeWithSelector(DeployCommon.MissingRole.selector, "REGISTRY"));
        managerScript.deploy(_managerPlan(address(0)));
    }

    function test_managerScript_refusesCChainMainnet() public {
        vm.chainId(43_114);
        vm.expectRevert(abi.encodeWithSelector(DeployCommon.MainnetRefused.selector, 43_114));
        managerScript.run();
    }

    // ------------------------------------------------------- DeployStakeVault

    function test_vaultScript_deploysThePlanAndLeavesItUnbound() public {
        (address token, address sink) = _fixtureTokenAndSink();

        DeployStakeVault.Deployment memory d = vaultScript.deploy(_vaultPlan(token, sink, 1e12));

        assertEq(d.deployer, ANVIL_0, "deployer, from the plan");
        assertEq(d.token, token, "token, from the plan");
        assertEq(d.sink, sink, "sink, from the plan");
        assertEq(d.wadPerUnit, 1e12, "scale, from the plan");
        assertGt(d.vault.code.length, 0, "vault deployed");

        AVIPStakeVault vault = AVIPStakeVault(d.vault);
        assertEq(address(vault.TOKEN()), token, "token wired");
        assertEq(address(vault.SINK()), sink, "sink wired");
        assertEq(vault.WAD_PER_UNIT(), 1e12, "scale wired");
        assertEq(vault.manager(), address(0), "unbound: the manager does not exist yet");
        assertEq(vault.totalEscrowedUnits(), 0, "nothing escrowed");
        assertEq(vault.feeInUnits(), 0, "and no fee policy to read");
    }

    function test_vaultScript_refusesAPlanItCannotInventTheRestOf() public {
        (address token, address sink) = _fixtureTokenAndSink();

        vm.expectRevert(abi.encodeWithSelector(DeployCommon.MissingRole.selector, "TOKEN"));
        vaultScript.deploy(_vaultPlan(address(0), sink, 1e12));

        vm.expectRevert(abi.encodeWithSelector(DeployCommon.MissingRole.selector, "SINK"));
        vaultScript.deploy(_vaultPlan(token, address(0), 1e12));

        // The scale is the third input the script must be told: `decimals()` is
        // never read from the token, so a wrong (or absent) `WAD_PER_UNIT` would
        // mis-price every comparison against `stakeOf` (§5.12).
        vm.expectRevert(abi.encodeWithSelector(DeployCommon.MissingRole.selector, "WAD_PER_UNIT"));
        vaultScript.deploy(_vaultPlan(token, sink, 0));
    }

    function test_vaultScript_refusesCChainMainnet() public {
        vm.chainId(43_114);
        vm.expectRevert(abi.encodeWithSelector(DeployCommon.MainnetRefused.selector, 43_114));
        vaultScript.run();
    }

    // ------------------------------------------------ the M8 handshake, chained

    function test_theVaultAndManagerScriptsCompleteTheHandshake() public {
        // The order of §5.12, exactly as a deployment would run it: the vault first
        // (it cannot know the manager's address), then the manager, handed the vault
        // as `CUSTODY`, which binds it from its own constructor and verifies it.
        (address token, address sink) = _fixtureTokenAndSink();
        DeployStakeVault.Deployment memory v = vaultScript.deploy(_vaultPlan(token, sink, 1e12));
        AVIPStakeVault vault = AVIPStakeVault(v.vault);

        DeployValidatorManager.Deployment memory m =
            managerScript.deploy(_managerPlanWith(_fixtureRegistry(), v.vault));

        assertEq(vault.manager(), m.manager, "the vault obeys the manager the script deployed");
        assertEq(address(AVIPValidatorManager(m.manager).custody()), v.vault, "and back");
        assertEq(m.custody, v.vault, "the deployment reports the same address");
    }

    function test_managerScript_refusesACustodyBoundBySomebodyElse() public {
        (address token, address sink) = _fixtureTokenAndSink();
        DeployStakeVault.Deployment memory v = vaultScript.deploy(_vaultPlan(token, sink, 1e12));

        // A stranger fills the vault's hole first. The manager script then cannot
        // deploy against it at all — which is the failure the handshake is designed
        // to produce, instead of a manager wired to a vault it does not control.
        vm.prank(ANVIL_1);
        AVIPStakeVault(v.vault).bindManager();

        // Read the registry *before* `expectRevert`: it is an external call and
        // would otherwise consume the expectation (the pitfall the M2 suite notes).
        address registry = _fixtureRegistry();
        vm.expectRevert(
            abi.encodeWithSelector(AVIPStakeVault.ManagerAlreadyBound.selector, ANVIL_1)
        );
        managerScript.deploy(_managerPlanWith(registry, v.vault));
    }

    // ------------------------------------------------------- the deployed pair

    function test_theDeployedPair_interoperatesWithoutContractChange() public {
        // 1. The registry script, exactly as a Fuji deployment would run it: a
        //    plan with a sequencer and no verifier yet.
        DeployRegistry.Deployment memory r =
            registryScript.deploy(_registryPlan(ANVIL_1, address(0)));
        AVIPRegistry registry = AVIPRegistry(r.registry);
        assertEq(registry.sequencer(), ANVIL_1, "the sequencer the script installed");

        // 2. The manager script, chained on the address the registry script
        //    created: the same hand-off `deploy_dryrun.sh` performs.
        DeployValidatorManager.Deployment memory m = managerScript.deploy(_managerPlan(r.registry));
        AVIPValidatorManager manager = AVIPValidatorManager(m.manager);

        // 3. The sequencer posts the genesis epoch: the first commitment carries
        //    the whole tensor, delta = N = 500.
        bytes32 root = keccak256("epoch-0");
        vm.prank(r.sequencer);
        registry.postCommitment(0, root, 500);
        assertEq(registry.latestEpoch(), 0, "genesis epoch");

        // 4. ... and installs the threshold verifier. M7a deploys no verifier, so
        //    the M1/M2 double stands in for the address an operator installs. The
        //    double is deployed *before* the prank on purpose: a `new` inside the
        //    pranked statement would consume the prank (the CREATE is the next
        //    call) and `setVerifier` would then run as the test contract.
        bytes memory proof = _proof(PROOF_A0);
        MockThresholdVerifier verifier =
            new MockThresholdVerifier(true, PROOF_A0, _statement(root, 0, THETA_R));
        assertEq(address(registry.verifier()), address(0), "no verifier while unset");
        vm.prank(r.sequencer);
        registry.setVerifier(address(verifier));
        assertEq(address(registry.verifier()), address(verifier), "verifier installed");

        // 5. A validator admits itself against the pair the scripts deployed.
        address validator = makeAddr("validator");
        uint256 stake = manager.requiredStakeFor(THETA_R);
        vm.prank(validator);
        manager.admit(validator, stake, THETA_R, proof);

        assertTrue(manager.isAdmitted(validator), "admitted");
        assertEq(manager.stakeOf(validator), stake, "stake recorded");
        assertEq(manager.requiredStake(validator), stake, "minimum stake recorded");
        assertEq(
            manager.collateralOf(validator), manager.collateralFor(THETA_R), "collateral = C_R"
        );
    }

    // ------------------------------------------------------------- helpers

    /// @dev The plan the registry script would build from `DEPLOYER`, `SEQUENCER`
    ///      and `VERIFIER`: the deployer is `anvil` account 0 in every test here.
    function _registryPlan(address sequencer, address verifier)
        internal
        pure
        returns (DeployRegistry.Plan memory)
    {
        return DeployRegistry.Plan({deployer: ANVIL_0, sequencer: sequencer, verifier: verifier});
    }

    /// @dev A token and a sink for the vault script's plan: it needs two addresses
    ///      that exist and do nothing else.
    function _fixtureTokenAndSink() internal returns (address token, address sink) {
        token = address(new MockERC20("Mock USD", 6));
        sink = address(new MockFundSink());
    }

    /// @dev The plan the vault script would build from `DEPLOYER`, `TOKEN`, `SINK`
    ///      and `WAD_PER_UNIT` (§5.12).
    function _vaultPlan(address token, address sink, uint256 wadPerUnit)
        internal
        pure
        returns (DeployStakeVault.Plan memory)
    {
        return DeployStakeVault.Plan({
            deployer: ANVIL_0, token: token, sink: sink, wadPerUnit: wadPerUnit
        });
    }

    /// @dev The plan the manager script would build from `DEPLOYER`,
    ///      `SLASH_AUTHORITY`, the required `REGISTRY` and the optional
    ///      `CUSTODY` (§5.12). No custody by default: that is the M2 mode.
    function _managerPlan(address registry)
        internal
        pure
        returns (DeployValidatorManager.Plan memory)
    {
        return _managerPlanWith(registry, address(0));
    }

    /// @dev The same plan with a custody contract supplied, which is the shape
    ///      M8's phase uses after it deploys the vault.
    function _managerPlanWith(address registry, address custody)
        internal
        pure
        returns (DeployValidatorManager.Plan memory)
    {
        return DeployValidatorManager.Plan({
            deployer: ANVIL_0, registry: registry, slashAuthority: ANVIL_2, custody: custody
        });
    }

    /// @dev A registry the manager script can point at. The scripts deploy their
    ///      own instances; this one is a fixture for the manager tests.
    function _fixtureRegistry() internal returns (address) {
        return address(new AVIPRegistry(ANVIL_1, address(0)));
    }

    /// @dev The statement the registry is expected to build itself from its own
    ///      state: `[uint256(root), epoch, certifiedNorm]` (§5.2.1). Mirrors
    ///      `AVIPRegistry.t.sol`, so the double asserts the same binding here.
    function _statement(bytes32 root, uint256 epoch, uint256 norm)
        internal
        pure
        returns (bytes memory)
    {
        uint256[] memory statement = new uint256[](3);
        statement[0] = uint256(root);
        statement[1] = epoch;
        statement[2] = norm;
        return abi.encode(statement);
    }

    /// @dev The eight canonical field elements of a Groth16 proof, as small
    ///      scalars (trivially inside the BN254 scalar field): exactly what
    ///      `Bn254.decodeProof` reads. Only `a[0]` is inspected by the double.
    function _proof(uint256 a0) internal pure returns (bytes memory) {
        uint256[2] memory a = [a0, uint256(1)];
        uint256[2] memory b0 = [uint256(2), uint256(3)];
        uint256[2] memory b1 = [uint256(4), uint256(5)];
        uint256[2] memory c = [uint256(6), uint256(7)];
        return abi.encode(a, b0, b1, c);
    }
}

