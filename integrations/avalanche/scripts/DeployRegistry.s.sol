// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVIPRegistry} from "../contracts/AVIPRegistry.sol";
import {DeployCommon} from "./DeployCommon.sol";

/// @title DeployRegistry
/// @notice Deploys `AVIPRegistry` (milestone M1, amended by M2 §5.2 and M3 §5.4)
///         with the sequencer role and the threshold verifier that the rest of
///         the protocol expects.
///
/// @dev Milestone M7a of `docs/architecture/implementation-plan.md` §5.8; phase 1
///      of `docs/architecture/avalanche-integration.md` §6. What the script
///      fixes, and why:
///
///        - the **sequencer** is the only writer of epoch commitments. It is read
///          from `SEQUENCER` (default `anvil` account 1), never from the
///          deployer, so the two roles cannot collapse by accident;
///        - the **verifier** is read from `VERIFIER` and defaults to
///          `address(0)`, which the registry accepts: with no verifier set,
///          `verifyThreshold` reverts instead of certifying. M7a deploys no
///          verifier (see `DeployCommon`), so the honest default is "none";
///        - the chain is asserted not to be C-Chain mainnet, and the wiring is
///          read back from the deployed instance before the script reports
///          success.
///
///      The registry enforces no threshold of its own and holds no per-validator
///      state (`Theta_r` lives in `AVIPValidatorManager`), so this script has
///      exactly one job: get the roles and the frozen constants right.
///
///      Dry run, no environment, no network:
///
///        forge script scripts/DeployRegistry.s.sol:DeployRegistry
///
///      Fuji (M7, deliberately not automated by this milestone): add
///      `--rpc-url "$FUJI_RPC_URL" --broadcast` and a funded `DEPLOYER`. Mainnet
///      (`43114`) reverts with `MainnetRefused`.
contract DeployRegistry is DeployCommon {
    /// @notice The roles the script will use, resolved before anything is
    ///         deployed.
    struct Plan {
        address deployer;
        address sequencer;
        address verifier;
    }

    /// @notice What the script actually did: the plan plus the address the
    ///         registry landed on.
    struct Deployment {
        address deployer;
        address registry;
        address sequencer;
        address verifier;
    }

    /// @notice The frozen constants the registry is supposed to carry: `N =
    ///         C*D*H = 500` (paper, Tensor Compression) and
    ///         `gamma * N = 0.10 * 500 = 50` (paper, Data Layer freshness).
    uint32 internal constant N = 500;
    uint32 internal constant GAMMA_N = 50;

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
    /// @param p The deployer, the sequencer and the verifier to wire.
    /// @return d The deployment, including the address of the new registry.
    function deploy(Plan memory p) public returns (Deployment memory d) {
        _refuseMainnet();
        // A registry whose sequencer is nobody accepts no commitment at all:
        // that is a deployment bug, not a policy.
        if (p.sequencer == address(0)) revert MissingRole("SEQUENCER");

        vm.startBroadcast(p.deployer);
        AVIPRegistry registry = new AVIPRegistry(p.sequencer, p.verifier);
        vm.stopBroadcast();

        d = Deployment({
            deployer: p.deployer,
            registry: address(registry),
            sequencer: p.sequencer,
            verifier: p.verifier
        });

        _checkWiring(registry, d);
        _report(d);
    }

    /// @notice Resolves the roles without touching the chain, so a caller (or a
    ///         test) can see the plan a dry run would execute.
    function plan() public view returns (Plan memory p) {
        p.deployer = _deployer();
        p.sequencer = _sequencer();
        p.verifier = _verifier();
    }

    /// @dev Reads the state back from the instance just deployed. The registry's
    ///      constructor is the only writer of these three fields, so a mismatch
    ///      means the script passed something other than what it resolved.
    function _checkWiring(AVIPRegistry registry, Deployment memory d) internal view {
        _assertAddressEq("sequencer", d.sequencer, registry.sequencer());
        _assertAddressEq("verifier", d.verifier, address(registry.verifier()));
        _assertEq("TENSOR_SIZE", N, registry.TENSOR_SIZE());
        _assertEq("MAX_DELTA_ENTRIES", GAMMA_N, registry.MAX_DELTA_ENTRIES());
    }

    function _report(Deployment memory d) internal view {
        _logHeader("DeployRegistry", d.deployer);
        _logAddress("AVIPRegistry", d.registry);
        _logAddress("role.sequencer", d.sequencer);
        _logAddress("role.verifier", d.verifier);
        _logUint("check.TENSOR_SIZE", N);
        _logUint("check.MAX_DELTA_ENTRIES", GAMMA_N);
        _log("status", "ok");
    }
}
