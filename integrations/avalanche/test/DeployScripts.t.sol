// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AVIPRegistry} from "../contracts/AVIPRegistry.sol";
import {AVIPStakeVault} from "../contracts/AVIPStakeVault.sol";
import {AVIPValidatorManager} from "../contracts/AVIPValidatorManager.sol";
import {IAVIPRegistry} from "../contracts/interfaces/IAVIPRegistry.sol";
import {DeployCommon} from "../scripts/DeployCommon.sol";
import {DeployRegistry} from "../scripts/DeployRegistry.s.sol";
import {DeployVerifier} from "../scripts/DeployVerifier.s.sol";
import {ProposeVerifier} from "../scripts/ProposeVerifier.s.sol";
import {Groth16Verifier} from "../contracts/verifiers/Groth16Verifier.sol";
import {M4dGroth16Fixtures as F} from "./fixtures/M4dGroth16Fixtures.sol";
import {DeployFujiPhase1} from "../scripts/DeployFujiPhase1.s.sol";
import {DeployStakeVault} from "../scripts/DeployStakeVault.s.sol";
import {DeployTransport} from "../scripts/DeployTransport.s.sol";
import {DeployValidatorManager} from "../scripts/DeployValidatorManager.s.sol";
import {AVIPMessageCodec} from "../contracts/AVIPMessageCodec.sol";
import {AVIPMessageEndpoint} from "../contracts/AVIPMessageEndpoint.sol";
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
///    `scripts/DeployValidatorManager.s.sol`) deploy the M1/M2 contracts (M1
///    amended by M9a's authority pair) and wire what they were given: the
///    sequencer, an optional verifier and the role-change guardian on the
///    registry, the registry address and the slash authority on the manager.
///    `deploy` — the only function that creates state,
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
    address internal constant ANVIL_3 = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;

    uint256 internal constant THETA_R = 5e17; // 0.5, the worst admissible type
    uint256 internal constant PROOF_A0 = 42; // arbitrary; the double only checks it is forwarded
    uint256 internal constant STATEMENT_ROOT = 0x1234_5678;

    DeployRegistry internal registryScript;
    DeployVerifier internal verifierScript;
    ProposeVerifier internal proposeScript;
    DeployStakeVault internal vaultScript;
    DeployValidatorManager internal managerScript;
    DeployFujiPhase1 internal fujiPhase1Script;
    DeployTransport internal transportScript;
    DeployCommonHarness internal harness;

    function setUp() public {
        // Instruments only. No `setEnv` here: this suite cannot clear what an
        // earlier test wrote (see the note above), so it does not pretend to.
        registryScript = new DeployRegistry();
        verifierScript = new DeployVerifier();
        proposeScript = new ProposeVerifier();
        vaultScript = new DeployStakeVault();
        managerScript = new DeployValidatorManager();
        fujiPhase1Script = new DeployFujiPhase1();
        transportScript = new DeployTransport();
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
        assertEq(d.guardian, ANVIL_3, "guardian, from the plan");
        assertGt(d.registry.code.length, 0, "registry deployed");

        AVIPRegistry registry = AVIPRegistry(d.registry);
        assertEq(registry.sequencer(), ANVIL_1, "sequencer wired");
        assertEq(address(registry.verifier()), ANVIL_2, "verifier wired");
        assertEq(registry.guardian(), ANVIL_3, "guardian wired");
        assertEq(registry.CHANGE_DELAY(), 2 days, "the delay the script installs");
        assertTrue(registry.sequencer() != d.deployer, "the writer is not the deployer");
        assertTrue(registry.guardian() != registry.sequencer(), "the proposer is not the writer");
    }

    function test_registryScript_installsNoVerifierWhenThePlanHasNone() public {
        // M7a deploys no verifier: `VERIFIER` defaults to the zero address, and
        // the registry accepts that as "none yet".
        DeployRegistry.Deployment memory d =
            registryScript.deploy(_registryPlan(ANVIL_1, address(0)));

        AVIPRegistry registry = AVIPRegistry(d.registry);
        vm.prank(d.sequencer);
        registry.postCommitment(
            0,
            keccak256("epoch-0"),
            STATEMENT_ROOT,
            500,
            keccak256("avalanche-c-chain"),
            keccak256("AVIP/fragment-function/v1")
        );

        // That is not a hole: `verifyThreshold` reverts instead of returning a
        // verdict nobody checked.
        assertEq(address(registry.verifier()), address(0), "no verifier installed");
        vm.expectRevert(IAVIPRegistry.VerifierNotSet.selector);
        registry.verifyThreshold(0, ANVIL_2, THETA_R, _proof(PROOF_A0));
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

    function test_registryScript_refusesAZeroGuardianPlan() public {
        // M9a. A guardian of zero is not "ungoverned": it is frozen. Neither role
        // could ever be replaced, so the plan is refused before anything exists.
        DeployRegistry.Plan memory plan = DeployRegistry.Plan({
            deployer: ANVIL_0,
            sequencer: ANVIL_1,
            verifier: address(0),
            guardian: address(0),
            sourceChainId: keccak256("avalanche-c-chain"),
            formulaDigest: keccak256("AVIP/fragment-function/v1")
        });
        vm.expectRevert(abi.encodeWithSelector(DeployCommon.MissingRole.selector, "GUARDIAN"));
        registryScript.deploy(plan);
    }

    function test_registryScript_refusesAGuardianThatIsTheSequencer() public {
        // The capture §12.1.2 closes: one key that both posts commitments and
        // proposes its own continuation. The delay would then only *announce* the
        // capture, so the plan is refused rather than deployed with a warning.
        DeployRegistry.Plan memory plan = DeployRegistry.Plan({
            deployer: ANVIL_0,
            sequencer: ANVIL_1,
            verifier: address(0),
            guardian: ANVIL_1,
            sourceChainId: keccak256("avalanche-c-chain"),
            formulaDigest: keccak256("AVIP/fragment-function/v1")
        });
        vm.expectRevert(
            abi.encodeWithSelector(DeployCommon.RolesCollapsed.selector, "GUARDIAN", "SEQUENCER")
        );
        registryScript.deploy(plan);
    }

    function test_registryScript_theDeployedRegistryCanRotateItsOwnSequencer() public {
        // What the deployed pair is for: the instance the script hands over is
        // governable after the deployment ends. The guardian proposes, the delay
        // the same script installed elapses, and the rotation lands — while the
        // guardian itself cannot write a commitment, and the old sequencer cannot
        // block the change.
        AVIPRegistry registry =
            AVIPRegistry(registryScript.deploy(_registryPlan(ANVIL_1, ANVIL_2)).registry);

        vm.prank(ANVIL_2);
        vm.expectRevert(abi.encodeWithSelector(IAVIPRegistry.NotGuardian.selector, ANVIL_2));
        registry.proposeSequencer(ANVIL_2);

        vm.prank(ANVIL_3);
        registry.proposeSequencer(ANVIL_2);
        vm.warp(block.timestamp + registry.CHANGE_DELAY());
        registry.executeSequencerChange();

        assertEq(registry.sequencer(), ANVIL_2, "rotated");
        vm.prank(ANVIL_1);
        vm.expectRevert(abi.encodeWithSelector(IAVIPRegistry.NotSequencer.selector, ANVIL_1));
        registry.postCommitment(
            0,
            keccak256("tensor"),
            STATEMENT_ROOT,
            500,
            keccak256("avalanche-c-chain"),
            keccak256("AVIP/fragment-function/v1")
        );

        vm.prank(ANVIL_2);
        registry.postCommitment(
            0,
            keccak256("tensor"),
            STATEMENT_ROOT,
            500,
            keccak256("avalanche-c-chain"),
            keccak256("AVIP/fragment-function/v1")
        );
        assertEq(registry.latestEpoch(), 0, "the new sequencer posts");
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
        // M9c: the ejection surcharge is a deployment constant, so the script's
        // plan is where the deployed value is pinned (it has no paper value).
        assertEq(manager.EJECTION_SURCHARGE(), 1e17, "kappa = 0.1");
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

    function test_managerScript_refusesACustodylessManagerOffTheLocalChain() public {
        // M-12/T-1. On a live chain a manager with no custody accepts a stake it
        // cannot slash (§5.2.3), which is a declaration, not a bond. The local
        // chain keeps the M2 mode on purpose — every other test here deploys that
        // way — so the guard is asserted where it can fire: on Fuji.
        vm.chainId(43_113);
        vm.expectRevert(abi.encodeWithSelector(DeployCommon.MissingRole.selector, "CUSTODY"));
        managerScript.deploy(_managerPlanWith(address(this), address(0)));
    }

    function test_managerScript_acceptsACustodylessManagerOnTheLocalChain() public {
        // The other half of the guard: refusing `address(0)` everywhere would
        // delete the M2 mode that phase 1 deploys and that §5.2.3 documents.
        DeployValidatorManager.Deployment memory d =
            managerScript.deploy(_managerPlan(_fixtureRegistry()));
        assertEq(d.custody, address(0), "M2 mode: stake declared, not backed");
    }

    function test_managerScript_refusesAnEOASlasherOffTheLocalChain() public {
        // M9b. `slashAuthority` is immutable and has no proposal pair, so one
        // key holding it decides every slash the manager will ever execute. On
        // Fuji the script refuses an address without code; the local chain
        // keeps the `anvil` default the dry run uses.
        vm.chainId(43_113);
        address eoa = address(0x1234_5678);
        address registry = _fixtureRegistry();

        // The plan is built before `expectRevert`: building it allocates a
        // fixture, and `expectRevert` applies to the *next* call.
        DeployValidatorManager.Plan memory p = DeployValidatorManager.Plan({
            deployer: address(0xBEEF),
            registry: registry,
            slashAuthority: eoa,
            // Non-zero, so the custody guard lets the slasher guard fire: the
            // revert must be about the key, not about the missing vault.
            custody: address(this)
        });

        vm.expectRevert(
            abi.encodeWithSelector(DeployCommon.SlashAuthorityIsEOA.selector, eoa, uint256(43_113))
        );
        managerScript.deploy(p);
    }

    function test_managerScript_acceptsAContractSlasherOffTheLocalChain() public {
        // The other half: a contract is not proof of a threshold, but it is
        // what a deployment can require. The vault is a convenient contract
        // that also satisfies the custody handshake.
        (address token, address sink) = _fixtureTokenAndSink();
        address vault = vaultScript.deploy(_vaultPlan(token, sink, 1e12)).vault;

        vm.chainId(43_113);
        address liveDeployer = makeAddr("liveDeployer");
        vm.deal(liveDeployer, 1 ether);

        DeployValidatorManager.Deployment memory d = managerScript.deploy(
            DeployValidatorManager.Plan({
                deployer: liveDeployer,
                registry: _fixtureRegistry(),
                slashAuthority: vault,
                custody: vault
            })
        );

        assertEq(
            AVIPValidatorManager(d.manager).slashAuthority(),
            vault,
            "the slasher is a contract, not one key"
        );
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
        registry.postCommitment(
            0,
            root,
            STATEMENT_ROOT,
            500,
            keccak256("avalanche-c-chain"),
            keccak256("AVIP/fragment-function/v1")
        );
        assertEq(registry.latestEpoch(), 0, "genesis epoch");

        // 4. ... and installs the threshold verifier. M7a deploys no verifier, so
        //    the M1/M2 double stands in for the address an operator installs. The
        //    double is deployed *before* any prank on purpose: a `new` inside a
        //    pranked statement would consume the prank (the CREATE is the next
        //    call), so the mock would be deployed by the wrong sender.
        //
        //    M9a changed the shape of this step: installing a verifier is now a
        //    guardian proposal plus a delayed, permissionless execution. Both are
        //    performed here, because the pair the scripts deploy must remain
        //    governable after the deployment ends — that is what the delay is for.
        bytes memory proof = _proof(PROOF_A0);
        address validator = makeAddr("validator");
        MockThresholdVerifier verifier = new MockThresholdVerifier(
            true, PROOF_A0, _statement(STATEMENT_ROOT, 0, validator, THETA_R)
        );
        assertEq(address(registry.verifier()), address(0), "no verifier while unset");
        vm.prank(r.guardian);
        registry.proposeVerifier(address(verifier));
        vm.warp(block.timestamp + registry.CHANGE_DELAY());
        registry.executeVerifierChange();
        assertEq(address(registry.verifier()), address(verifier), "verifier installed");

        // 5. A validator admits itself against the pair the scripts deployed.
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

    // ------------------------------------------- DeployVerifier / ProposeVerifier
    //
    // The pair that closes the hole `DeployCommon` documents: M7a deploys no
    // verifier, so `verifyThreshold` reverts `VerifierNotSet`; these two scripts
    // install one and announce it through the M9a proposal pair.

    function test_verifierScript_installsTheDevelopmentKey() public {
        DeployVerifier.Deployment memory d = verifierScript.deploy(ANVIL_0);

        assertGt(d.verifier.code.length, 0, "verifier deployed");
        Groth16Verifier verifier = Groth16Verifier(d.verifier);

        // Two independent implementations of the same digest: the fixture's is
        // computed in Rust from the ABI layout, the contract's in its constructor.
        assertEq(d.keyDigest, F.KEY_DIGEST, "the digest the script reports");
        assertEq(verifier.verifyingKeyDigest(), F.KEY_DIGEST, "the digest on chain");
        assertEq(d.numPublicInputs, 4, "statementRoot, epoch, validator, norm");
        assertEq(d.icLength, 5, "four inputs plus the constant term");
        assertEq(verifier.numPublicInputs(), 4, "read back");
        assertEq(verifier.icLength(), 5, "read back");

        // The key is the fixture's, point by point, not a re-derivation of it.
        uint256[2] memory chainAlpha = verifier.alpha1();
        uint256[2] memory fixtureAlpha = F.verifyingKey().alpha1;
        assertEq(chainAlpha[0], fixtureAlpha[0], "alpha1.x");
        assertEq(chainAlpha[1], fixtureAlpha[1], "alpha1.y");
    }

    function test_verifierScript_refusesMainnet() public {
        vm.chainId(43_114);
        vm.expectRevert(abi.encodeWithSelector(DeployCommon.MainnetRefused.selector, 43_114));
        verifierScript.deploy(ANVIL_0);
    }

    function test_proposeVerifier_announcesAndWaitsTheChangeDelay() public {
        AVIPRegistry registry =
            AVIPRegistry(registryScript.deploy(_registryPlan(ANVIL_1, address(0))).registry);
        address verifier = verifierScript.deploy(ANVIL_0).verifier;

        assertEq(address(registry.verifier()), address(0), "no verifier yet");

        ProposeVerifier.Announcement memory a = proposeScript.propose(
            ProposeVerifier.Plan({guardian: ANVIL_3, registry: address(registry), verifier: verifier})
        );

        assertEq(a.previous, address(0), "nothing was installed before");
        assertEq(a.pending, verifier, "the announcement is the script's verifier");
        assertEq(a.eta, block.timestamp + 2 days, "exactly CHANGE_DELAY, not less");
        assertEq(registry.pendingVerifier(), verifier, "read back from the registry");

        // The delay is the protection: the change cannot land early.
        vm.expectRevert(
            abi.encodeWithSelector(
                IAVIPRegistry.ChangeNotReady.selector, a.eta, block.timestamp
            )
        );
        registry.executeVerifierChange();

        // Once elapsed it is permissionless: any account can send it.
        vm.warp(a.eta);
        registry.executeVerifierChange();

        assertEq(address(registry.verifier()), verifier, "installed");
        assertEq(registry.pendingVerifier(), address(0), "no pending change left");
        assertEq(registry.verifierChangeEta(), 0, "eta cleared");
    }

    function test_proposeVerifier_refusesAVerifierWithoutCode() public {
        AVIPRegistry registry =
            AVIPRegistry(registryScript.deploy(_registryPlan(ANVIL_1, address(0))).registry);

        vm.expectRevert(abi.encodeWithSelector(DeployCommon.MissingRole.selector, "VERIFIER"));
        proposeScript.propose(
            ProposeVerifier.Plan({
                guardian: ANVIL_3,
                registry: address(registry),
                verifier: ANVIL_2 // an EOA: an announcement that would disable nothing
            })
        );
    }

    function test_proposeVerifier_refusesAGuardianTheRegistryDoesNotHave() public {
        AVIPRegistry registry =
            AVIPRegistry(registryScript.deploy(_registryPlan(ANVIL_1, address(0))).registry);
        address verifier = verifierScript.deploy(ANVIL_0).verifier;

        vm.expectRevert(
            abi.encodeWithSelector(
                DeployCommon.WiringMismatch.selector, "guardian", uint256(uint160(ANVIL_3)), uint256(uint160(ANVIL_2))
            )
        );
        proposeScript.propose(
            ProposeVerifier.Plan({
                guardian: ANVIL_2,
                registry: address(registry),
                verifier: verifier
            })
        );
    }

    // ------------------------------------------------------------- helpers

    /// @dev The plan the registry script would build from `DEPLOYER`, `SEQUENCER`,
    ///      `VERIFIER` and `GUARDIAN`: the deployer and the guardian are `anvil`
    ///      accounts 0 and 3 in every test here, and the guardian is deliberately
    ///      not the sequencer, which the script refuses (`RolesCollapsed`).
    function _registryPlan(address sequencer, address verifier)
        internal
        pure
        returns (DeployRegistry.Plan memory)
    {
        return DeployRegistry.Plan({
            deployer: ANVIL_0,
            sequencer: sequencer,
            verifier: verifier,
            guardian: ANVIL_3,
            sourceChainId: keccak256("avalanche-c-chain"),
            formulaDigest: keccak256("AVIP/fragment-function/v1")
        });
    }

    /// @dev A token and a sink for the vault script's plan: it needs two addresses
    ///      that exist and do nothing else.
    function test_fujiPhase1Script_refusesAnEOASlasher() public {
        // The phase-1 runbook is the deployment that actually happened on Fuji
        // (2026-10-18), and it wired `slashAuthority` to an EOA. The script now
        // refuses that shape before broadcasting, so the next phase cannot
        // repeat it. `MissingRole` keeps the zero address on its own error; this
        // is the case between "nobody" and "a contract".
        vm.chainId(43_113);
        address eoa = address(0x1234_5678);

        DeployFujiPhase1.Plan memory p = DeployFujiPhase1.Plan({
            deployer: address(0xBEEF),
            sequencer: address(0xCAFE),
            slashAuthority: eoa,
            guardian: address(0xF00D),
            token: address(0x701E),
            sink: address(0x510C),
            wadPerUnit: 1e12,
            sourceChainId: keccak256("avalanche-c-chain"),
            formulaDigest: keccak256("AVIP/fragment-function/v1")
        });

        vm.expectRevert(
            abi.encodeWithSelector(DeployCommon.SlashAuthorityIsEOA.selector, eoa, uint256(43_113))
        );
        fujiPhase1Script.deploy(p);
    }

    // ------------------------------------------------------- DeployTransport

    function test_transportScript_deploysTheSourceSide() public {
        DeployTransport.Deployment memory d = transportScript.deploy(_transportPlan(true));

        assertGt(d.teleporter.code.length, 0, "local: the script deploys the mock messenger");
        assertEq(d.localBlockchainId, keccak256("fuji"), "local chain, from the plan");

        AVIPMessageEndpoint relay = AVIPMessageEndpoint(d.relay);
        AVIPMessageEndpoint collusion = AVIPMessageEndpoint(d.collusion);
        AVIPMessageEndpoint slashing = AVIPMessageEndpoint(d.slashing);

        assertEq(
            relay.kind(), AVIPMessageCodec.KIND_COMMITMENT_PROPAGATION, "relay answers for kind 1"
        );
        assertEq(
            collusion.kind(), AVIPMessageCodec.KIND_COLLUSION_ALERT, "alert answers for kind 2"
        );
        assertEq(
            slashing.kind(), AVIPMessageCodec.KIND_SLASHING_NOTIFICATION, "slash answers for kind 3"
        );

        assertEq(relay.destinationCount(), 1, "one subscriber chain");
        AVIPMessageEndpoint.Destination memory dest = relay.destinationAt(0);
        assertEq(dest.blockchainId, keccak256("subnet"), "the peer chain");
        assertEq(dest.receiver, address(0xB0B1), "the peer's relay");
        assertEq(
            relay.originOf(AVIPMessageCodec.KIND_COMMITMENT_PROPAGATION, keccak256("subnet")),
            address(0),
            "a source chain accepts nothing"
        );
        assertEq(
            AVIPMessageEndpoint(d.slashing).destinationCount(),
            1,
            "the slashing notification has somewhere to go"
        );
    }

    function test_transportScript_deploysTheDestinationSide() public {
        DeployTransport.Deployment memory d = transportScript.deploy(_transportPlan(false));

        AVIPMessageEndpoint relay = AVIPMessageEndpoint(d.relay);
        AVIPMessageEndpoint collusion = AVIPMessageEndpoint(d.collusion);
        AVIPMessageEndpoint slashing = AVIPMessageEndpoint(d.slashing);

        assertEq(relay.destinationCount(), 0, "receive-only: no routing table");
        assertEq(collusion.destinationCount(), 0, "receive-only: no routing table");
        assertEq(slashing.destinationCount(), 0, "receive-only: no routing table");

        assertEq(
            relay.originOf(AVIPMessageCodec.KIND_COMMITMENT_PROPAGATION, keccak256("subnet")),
            address(0xB0B1),
            "only the peer's relay may announce here"
        );
        assertEq(
            collusion.originOf(AVIPMessageCodec.KIND_COLLUSION_ALERT, keccak256("subnet")),
            address(0xB0B2),
            "only the peer's alert channel may flag here"
        );
        assertEq(
            slashing.originOf(AVIPMessageCodec.KIND_SLASHING_NOTIFICATION, keccak256("subnet")),
            address(0xB0B3),
            "only the peer's slashing channel may notify here"
        );
    }

    function test_transportScript_refusesAMissingTeleporterOnFuji() public {
        vm.chainId(43_113);
        DeployTransport.Plan memory p = _transportPlan(true);
        p.deployer = address(0xBEEF);
        p.teleporter = address(0);

        vm.expectRevert(abi.encodeWithSelector(DeployCommon.MissingRole.selector, "TELEPORTER"));
        transportScript.deploy(p);
    }

    function test_transportScript_refusesAnEOATeleporterOnFuji() public {
        vm.chainId(43_113);
        DeployTransport.Plan memory p = _transportPlan(true);
        p.deployer = address(0xBEEF);
        p.teleporter = address(0x1234_5678);

        vm.expectRevert(
            abi.encodeWithSelector(DeployTransport.TeleporterIsEOA.selector, address(0x1234_5678))
        );
        transportScript.deploy(p);
    }

    function test_transportScript_refusesTheLocalChainAsItsOwnPeer() public {
        DeployTransport.Plan memory p = _transportPlan(true);
        p.peerBlockchainId = p.localBlockchainId;

        vm.expectRevert(
            abi.encodeWithSelector(DeployTransport.SameChain.selector, p.localBlockchainId)
        );
        transportScript.deploy(p);
    }

    /// @dev The plan the transport script would build for one side. The peers are
    ///      arbitrary non-zero addresses: a deployment is told them, it does not
    ///      predict them (§4), and this suite is about the wiring, not about the
    ///      other chain. `teleporter` is empty on the local chain, which is where
    ///      the script deploys the mock.
    function _transportPlan(bool source) internal pure returns (DeployTransport.Plan memory) {
        return DeployTransport.Plan({
            deployer: ANVIL_0,
            teleporter: address(0),
            localBlockchainId: keccak256("fuji"),
            peerBlockchainId: keccak256("subnet"),
            source: source,
            registry: source ? address(0x5EED) : address(0),
            sequencer: source ? address(0x5E01) : address(0),
            alerter: source ? address(0xA1E2) : address(0),
            notifier: source ? address(0x4071) : address(0),
            manager: source ? address(0) : address(0x4A4A),
            peerRelay: address(0xB0B1),
            peerCollusion: address(0xB0B2),
            peerSlashing: address(0xB0B3)
        });
    }

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
        return address(
            new AVIPRegistry(
                ANVIL_1,
                address(0),
                ANVIL_3,
                keccak256("avalanche-c-chain"),
                keccak256("AVIP/fragment-function/v1")
            )
        );
    }

    /// @dev The statement the registry is expected to build itself from its own
    ///      state: `[statementRoot, epoch, validator, certifiedNorm]` (§5.2.1,
    ///      M4d). Mirrors `AVIPRegistry.t.sol`, so the double asserts the same
    ///      binding here.
    function _statement(uint256 root, uint256 epoch, address validator, uint256 norm)
        internal
        pure
        returns (bytes memory)
    {
        uint256[] memory statement = new uint256[](4);
        statement[0] = root;
        statement[1] = epoch;
        statement[2] = uint256(uint160(validator));
        statement[3] = norm;
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

