// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/console2.sol";
import {AVIPRegistry} from "../contracts/AVIPRegistry.sol";
import {AVIPStakeVault} from "../contracts/AVIPStakeVault.sol";
import {AVIPValidatorManager} from "../contracts/AVIPValidatorManager.sol";
import {DeployCommon} from "./DeployCommon.sol";

/// @title DeployFujiPhase1
/// @notice The Fuji phase-1 runbook in one session: `AVIPRegistry`,
///         `AVIPStakeVault` and `AVIPValidatorManager`, in that order, inside a
///         single `startBroadcast`/`stopBroadcast` pair.
///
/// @dev What this script fixes:
///
///        - **one broadcast, not two scripts.** The vault and the manager that
///          binds it are deployed from the same `DEPLOYER` and in the same
///          session, so the unbound window is as short as the gap between two
///          transactions, not the gap an operator leaves between two commands
///          (`implementation-plan.md` §5.12);
///        - **the manager address is predicted, not discovered.** The manager
///          is the third CREATE from `DEPLOYER` (registry, vault, manager), so
///          its address is `computeCreateAddress(deployer, nonce + 2)`. The
///          prediction is checked before broadcast (the address must be empty)
///          and again against the deployed instance; a mismatch reverts the
///          script instead of accepting a manager the vault does not obey;
///        - **`VERIFIER` is `address(0)` by construction.** Phase 1 installs no
///          Groth16 verifier, and this script does not read `VERIFIER` from the
///          environment at all: with no verifier the registry refuses to
///          certify (`VerifierNotSet`) instead of certifying a development key;
///        - **`DEPLOYER`, `SEQUENCER` and `SLASH_AUTHORITY` are mandatory.**
///          They cannot fall back to the public `anvil` accounts; `DeployCommon`
///          refuses those on every chain other than 31337. `SLASH_AUTHORITY` must
///          also have code there (`SlashAuthorityIsEOA`): the role is immutable
///          and has no proposal pair, so this deployment is the last point at
///          which a single key can be refused (M9b/P-39). `GUARDIAN` is
///          optional and defaults to `DEPLOYER` (a distinct `GUARDIAN` is
///          accepted, but it may not equal `SEQUENCER`);
///        - **mainnet and unknown chains are refused.** Only Fuji (43113) and a
///          local `anvil`/dry run (31337) are accepted; 43114 gets
///          `MainnetRefused` before any input is resolved.
///
///      **Token and sink are inputs, not deployments.** `AVIPStakeVault`'s
///      constructor requires a token, an `IFundSink` and `WAD_PER_UNIT`; A1
///      deploys only the registry, the vault and the manager, so `TOKEN`,
///      `SINK` and `WAD_PER_UNIT` must name existing addresses/scale. No real
///      funds are moved by this script.
///
///      **The manager is not immutable in the current vault.** `AVIPStakeVault`
///      has no manager constructor argument: the manager's own constructor
///      performs the one-shot bind, which this script does not call.
///      Passing the predicted manager as an immutable vault constructor
///      argument is B-1, a contract change explicitly outside A1–A3. What this
///      script guarantees instead is the B-2 property: one session, predicted
///      address, and both sides read back before `status=ok`.
///
///      Dry run (local, no network, no keys):
///
///        DEPLOYER=0x... SEQUENCER=0x... SLASH_AUTHORITY=0x... \
///        TOKEN=0x... SINK=0x... WAD_PER_UNIT=1000000000000 \
///            forge script scripts/DeployFujiPhase1.s.sol:DeployFujiPhase1 --offline
///
///      Fuji (the human runs the broadcast; the agent never does):
///
///        forge script scripts/DeployFujiPhase1.s.sol:DeployFujiPhase1 \
///            --rpc-url "$FUJI_RPC_URL" --broadcast --account deployer
contract DeployFujiPhase1 is DeployCommon {
    /// @notice The frozen registry constants the transcript must carry.
    uint32 internal constant N = 500;
    uint32 internal constant GAMMA_N = 50;

    /// @notice Phase 1 installs no verifier. Fixed here, never read from env.
    address internal constant VERIFIER = address(0);

    /// @notice Deploy order is registry (0), vault (+1), manager (+2).
    uint256 internal constant MANAGER_NONCE_OFFSET = 2;

    /// @notice The chain is neither Fuji nor a local dry run.
    error UnsupportedChain(uint256 chainId);

    /// @notice The predicted manager address already has code: the nonce
    ///         prediction cannot be used without colliding with it.
    error ManagerAddressOccupied(address predicted);

    /// @notice The deployed manager is not at the address the vault will be
    ///         asked to obey.
    error ManagerPredictionFailed(address predicted, address actual);

    /// @notice The inputs the script will use, resolved before deployment.
    struct Plan {
        address deployer;
        address sequencer;
        address slashAuthority;
        address guardian;
        address token;
        address sink;
        uint256 wadPerUnit;
        /// @dev Origin (M-15): chain and fragment-function digest every epoch of
        ///      this registry will declare.
        bytes32 sourceChainId;
        bytes32 formulaDigest;
    }

    /// @notice What the script actually did.
    struct Deployment {
        address deployer;
        address registry;
        address vault;
        address manager;
        address token;
        address sink;
        uint256 wadPerUnit;
        address sequencer;
        address slashAuthority;
        address guardian;
        address verifier;
        bytes32 sourceChainId;
        bytes32 formulaDigest;
    }

    /// @notice CLI entry point: resolves the environment and deploys.
    /// @dev The chain guard runs before `plan()` so a malformed variable cannot
    ///      mask a mainnet refusal with a parse error.
    function run() external returns (Deployment memory) {
        _requirePhase1Chain();
        return deploy(plan());
    }

    /// @notice Deploys from an explicit plan and verifies the result.
    /// @dev The chain guard and every role check live here as well, so a caller
    ///      that supplies a `Plan` directly cannot skip them.
    function deploy(Plan memory p) public returns (Deployment memory d) {
        _requirePhase1Chain();

        // B-7/A3: the public anvil keys are refused on every live chain, even
        // when a caller bypasses `plan()` and hands over a Plan directly.
        _refuseAnvilDefault("DEPLOYER", p.deployer);
        _refuseAnvilDefault("SEQUENCER", p.sequencer);
        _refuseAnvilDefault("SLASH_AUTHORITY", p.slashAuthority);
        _refuseAnvilDefault("GUARDIAN", p.guardian);

        if (p.deployer == address(0)) revert MissingRole("DEPLOYER");
        if (p.sequencer == address(0)) revert MissingRole("SEQUENCER");
        if (p.slashAuthority == address(0)) revert MissingRole("SLASH_AUTHORITY");
        if (p.guardian == address(0)) revert MissingRole("GUARDIAN");
        if (p.token == address(0)) revert MissingRole("TOKEN");
        if (p.sink == address(0)) revert MissingRole("SINK");
        if (p.wadPerUnit == 0) revert MissingRole("WAD_PER_UNIT");
        if (p.guardian == p.sequencer) revert RolesCollapsed("GUARDIAN", "SEQUENCER");

        // M9b. The slasher is immutable and has no proposal pair, so a phase-1
        // deployment on Fuji with an EOA here hands the whole stake on record to
        // one key for the life of the manager. `MissingRole` above keeps the
        // zero address on its own error; this refuses everything else without
        // code.
        _requireSlasher(p.slashAuthority);

        uint64 startNonce = vm.getNonce(p.deployer);
        address predictedManager =
            vm.computeCreateAddress(p.deployer, uint256(startNonce) + MANAGER_NONCE_OFFSET);
        if (predictedManager.code.length != 0) revert ManagerAddressOccupied(predictedManager);

        vm.startBroadcast(p.deployer);
        AVIPRegistry registry =
            new AVIPRegistry(p.sequencer, VERIFIER, p.guardian, p.sourceChainId, p.formulaDigest);
        AVIPStakeVault vault = new AVIPStakeVault(p.token, p.sink, p.wadPerUnit);
        AVIPValidatorManager manager =
            new AVIPValidatorManager(address(registry), p.slashAuthority, address(vault));
        vm.stopBroadcast();

        if (address(manager) != predictedManager) {
            revert ManagerPredictionFailed(predictedManager, address(manager));
        }

        d = Deployment({
            deployer: p.deployer,
            registry: address(registry),
            vault: address(vault),
            manager: address(manager),
            token: p.token,
            sink: p.sink,
            wadPerUnit: p.wadPerUnit,
            sequencer: p.sequencer,
            slashAuthority: p.slashAuthority,
            guardian: p.guardian,
            verifier: VERIFIER,
            sourceChainId: p.sourceChainId,
            formulaDigest: p.formulaDigest
        });

        _checkWiring(registry, vault, manager, d, predictedManager);
        _report(d);
    }

    /// @notice Resolves the environment without touching the chain.
    /// @dev `TOKEN`, `SINK` and `WAD_PER_UNIT` are mandatory because the vault
    ///      constructor cannot invent them. `GUARDIAN` defaults to the deployer:
    ///      a live deployment has no safe `anvil` fallback for it either.
    function plan() public view returns (Plan memory p) {
        p.deployer = _requiredRole("DEPLOYER");
        p.sequencer = _requiredRole("SEQUENCER");
        p.slashAuthority = _requireSlasher(_requiredRole("SLASH_AUTHORITY"));
        p.guardian = _roleOr("GUARDIAN", p.deployer);
        p.token = _requiredRole("TOKEN");
        p.sink = _requiredRole("SINK");
        p.wadPerUnit = _requiredUint("WAD_PER_UNIT");
        p.sourceChainId = _sourceChainId();
        p.formulaDigest = _formulaDigest();
    }

    /// @dev Reads the deployment back from the instances just created. The
    ///      registry's constructor is the only writer of its roles; the manager's
    ///      constructor is the only caller of the vault's one-shot bind. A
    ///      mismatch here means the prediction or the wiring is wrong, and the
    ///      script must not report `status=ok`.
    function _checkWiring(
        AVIPRegistry registry,
        AVIPStakeVault vault,
        AVIPValidatorManager manager,
        Deployment memory d,
        address predictedManager
    ) internal view {
        _assertAddressEq("manager.predicted", predictedManager, d.manager);
        _assertAddressEq("registry", d.registry, address(manager.registry()));
        _assertAddressEq("sequencer", d.sequencer, registry.sequencer());
        _assertAddressEq("verifier", VERIFIER, address(registry.verifier()));
        _assertEq("TENSOR_SIZE", N, registry.TENSOR_SIZE());
        _assertEq("MAX_DELTA_ENTRIES", GAMMA_N, registry.MAX_DELTA_ENTRIES());
        _assertEq("sourceChainId", uint256(d.sourceChainId), uint256(registry.sourceChainId()));
        _assertEq("formulaDigest", uint256(d.formulaDigest), uint256(registry.formulaDigest()));
        _assertAddressEq("custody", d.vault, address(manager.custody()));
        _assertAddressEq("vault.manager", d.manager, vault.manager());
        _assertAddressEq("slashAuthority", d.slashAuthority, manager.slashAuthority());
        _assertAddressEq("token", d.token, address(vault.TOKEN()));
        _assertAddressEq("sink", d.sink, address(vault.SINK()));
        _assertEq("wadPerUnit", d.wadPerUnit, vault.WAD_PER_UNIT());
    }

    /// @dev Only the two chains phase 1 is allowed on. Mainnet has its own
    ///      error so the refusal is the one the rest of the repository tests.
    function _requirePhase1Chain() internal view {
        if (block.chainid == C_CHAIN_MAINNET) revert MainnetRefused(block.chainid);
        if (block.chainid != FUJI_C_CHAIN && block.chainid != LOCAL_CHAIN) {
            revert UnsupportedChain(block.chainid);
        }
    }

    /// @dev Tagged `[fuji]` so `verify_fuji.sh` can parse the transcript without
    ///      depending on gas, timings or human-readable headings.
    function _log(string memory key, string memory value) internal pure override {
        console2.log(string.concat("[fuji] ", key, "=", value));
    }

    function _report(Deployment memory d) internal view {
        _log("chain.id", vm.toString(block.chainid));
        _log("chain.name", _chainName());
        _logAddress("sender", d.deployer);
        _logAddress("deployer", d.deployer);
        _logAddress("registry", d.registry);
        _logAddress("vault", d.vault);
        _logAddress("manager", d.manager);
        _logAddress("sink", d.sink);
        _logAddress("token", d.token);
        _logAddress("guardian", d.guardian);
        _logAddress("sequencer", d.sequencer);
        _logAddress("slash_authority", d.slashAuthority);
        _logAddress("verifier", d.verifier);
        _logUint("TENSOR_SIZE", N);
        _logUint("MAX_DELTA_ENTRIES", GAMMA_N);
        _logUint("wad_per_unit", d.wadPerUnit);
        _log("status", "ok");
    }
}
