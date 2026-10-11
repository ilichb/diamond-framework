// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVIPValidatorManager} from "../contracts/AVIPValidatorManager.sol";
import {DeployCommon} from "./DeployCommon.sol";

/// @title DeployValidatorManager
/// @notice Deploys `AVIPValidatorManager` (milestone M2, §5.2) wired to an
///         already-deployed `AVIPRegistry` and to the address that carries the
///         data layer's slashing decision.
///
/// @dev Milestone M7a of `docs/architecture/implementation-plan.md` §5.8; phase 1
///      of `docs/architecture/avalanche-integration.md` §6, and the second half
///      of the pair `DeployRegistry.s.sol` starts. What the script fixes:
///
///        - `REGISTRY` is **required**: a manager pointed at a registry nobody
///          chose enforces `Theta_r` against nothing. `DeployRegistry.s.sol`
///          prints the address it created, and `deploy_dryrun.sh` feeds it back
///          in, which is also exactly how a Fuji deployment would be chained;
///        - `SLASH_AUTHORITY` is read from the environment (default `anvil`
///          account 2). It is the only address allowed to call `slash`
///          (`avalanche-integration.md` §4); in M7 it is the sequencer's
///          monitor, and in M8 the Treasury Module takes over custody. M2 holds
///          no funds, so this role decides *who may decide*, not who may seize;
///        - the paper's five policy constants are read back from the deployed
///          instance (`Theta`, `C_R^inf`, `S_min`, `Theta_r`, `F_0*`) together
///          with the two closed forms at the worst admissible type
///          (`r = Theta_r`), so a wrong decimal or a swapped argument fails the
///          script instead of the first validator.
///
///      Dry run, no environment, no network (`REGISTRY` is the only input that
///      cannot be defaulted):
///
///        REGISTRY=0x... forge script \
///            scripts/DeployValidatorManager.s.sol:DeployValidatorManager
///
///      Fuji (M7): add `--rpc-url "$FUJI_RPC_URL" --broadcast` and a funded
///      `DEPLOYER`. Mainnet (`43114`) reverts with `MainnetRefused`.
contract DeployValidatorManager is DeployCommon {
    /// @notice The roles the script will use, resolved before anything is
    ///         deployed.
    struct Plan {
        address deployer;
        address registry;
        address slashAuthority;
    }

    /// @notice What the script actually did: the plan plus the address the
    ///         manager landed on.
    struct Deployment {
        address deployer;
        address manager;
        address registry;
        address slashAuthority;
    }

    /// @notice `Theta_r = 0.5` (ZK section, `[CONJECTURE]`), the worst
    ///         admissible type and the norm the closed forms below are checked
    ///         at (`AVIPValidatorManager.t.sol` pins the same pair).
    uint256 internal constant THETA_R = 5e17;

    /// @notice `C_R(Theta_r) = 0.8 * 0.5 / 1.5 = 0.2666...` in WAD.
    uint256 internal constant COLLATERAL_AT_THETA_R = 266_666_666_666_666_666;

    /// @notice `S_f*(Theta_r) = 1.0 - C_R(Theta_r) = 0.7333...` in WAD.
    uint256 internal constant STAKE_AT_THETA_R = 733_333_333_333_333_334;

    /// @notice CLI entry point: resolves the roles from the environment and
    ///         deploys from that plan.
    /// @dev `deploy` guards the chain too. The guard is repeated here so that it
    ///      fires *before* a single role is read: a malformed shell variable must
    ///      not be able to mask a mainnet refusal with a parse error.
    function run() external returns (Deployment memory) {
        _refuseMainnet();
        return deploy(plan());
    }

    /// @notice Deploys from an explicit plan, and verifies its own wiring.
    /// @dev The chain guard and the plan validation live here, in the only
    ///      function that creates state, so neither can be skipped by a caller
    ///      that already holds a plan. `run()` is `deploy(plan())`.
    /// @param p The deployer, the registry to enforce and the slash authority.
    /// @return d The deployment, including the address of the new manager.
    function deploy(Plan memory p) public returns (Deployment memory d) {
        _refuseMainnet();
        // Same reason `plan()` requires the variable: a manager wired to the
        // zero address enforces `Theta_r` against nothing.
        if (p.registry == address(0)) revert MissingRole("REGISTRY");

        vm.startBroadcast(p.deployer);
        AVIPValidatorManager manager = new AVIPValidatorManager(p.registry, p.slashAuthority);
        vm.stopBroadcast();

        d = Deployment({
            deployer: p.deployer,
            manager: address(manager),
            registry: p.registry,
            slashAuthority: p.slashAuthority
        });

        _checkWiring(manager, d);
        _report(d);
    }

    /// @notice Resolves the roles without touching the chain. `REGISTRY` has no
    ///         default: it is the address of the M7a registry deployment.
    function plan() public view returns (Plan memory p) {
        p.deployer = _deployer();
        p.registry = _requiredRole("REGISTRY");
        p.slashAuthority = _slashAuthority();
    }

    /// @dev Reads the policy back from the instance just deployed: the wiring,
    ///      the five constants the paper fixes, and the two closed forms at
    ///      `r = Theta_r` (paper, Payment Rule).
    function _checkWiring(AVIPValidatorManager manager, Deployment memory d) internal view {
        _assertAddressEq("registry", d.registry, address(manager.registry()));
        _assertAddressEq("slashAuthority", d.slashAuthority, manager.slashAuthority());

        _assertEq("ONE", 1e18, manager.ONE());
        _assertEq("THETA", 1e18, manager.THETA());
        _assertEq("CR_INF", 8e17, manager.CR_INF());
        _assertEq("S_MIN", 2e17, manager.S_MIN());
        _assertEq("THETA_R", THETA_R, manager.THETA_R());
        _assertEq("F0_STAR", 5e16, manager.F0_STAR());

        _assertEq("collateralFor(THETA_R)", COLLATERAL_AT_THETA_R, manager.collateralFor(THETA_R));
        _assertEq("requiredStakeFor(THETA_R)", STAKE_AT_THETA_R, manager.requiredStakeFor(THETA_R));
    }

    function _report(Deployment memory d) internal view {
        _logHeader("DeployValidatorManager", d.deployer);
        _logAddress("AVIPValidatorManager", d.manager);
        _logAddress("role.registry", d.registry);
        _logAddress("role.slashAuthority", d.slashAuthority);
        _logUint("check.THETA", 1e18);
        _logUint("check.CR_INF", 8e17);
        _logUint("check.S_MIN", 2e17);
        _logUint("check.THETA_R", THETA_R);
        _logUint("check.F0_STAR", 5e16);
        _logUint("check.collateralFor(THETA_R)", COLLATERAL_AT_THETA_R);
        _logUint("check.requiredStakeFor(THETA_R)", STAKE_AT_THETA_R);
        _log("status", "ok");
    }
}
