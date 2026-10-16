// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

/// @title DeployCommon
/// @notice Shared floor of the M7a deployment scripts: the chain guard, the role
///         plumbing, the read-back assertions and nothing else.
///
/// @dev Milestone M7a of `docs/architecture/implementation-plan.md` §5.8 (see
///      also `docs/architecture/avalanche-integration.md` §6, phases 1-2, and
///      the layout in `scripts/README.md`). Two rules live here so that no
///      individual script can forget them:
///
///      1. **Mainnet is refused, not discouraged.** Every script reverts on
///         Avalanche C-Chain mainnet (`43114`). Fuji (`43113`) and a local
///         `anvil`/dry run (`31337`) are allowed. Nothing in this repository has
///         been audited, so a script that can be pointed at the chain that holds
///         real value is a hazard, not a convenience. The refusal is a `require`
///         in the script *and* a test (`../test/DeployScripts.t.sol`), because a
///         comment is not a guard.
///
///      2. **Roles come from the environment, never from the deployer.** The
///         inputs are `DEPLOYER` (the sender), `SEQUENCER` (the registry's only
///         writer), `GUARDIAN` (the registry's only proposer of role changes,
///         M9a §12.1.2), `SLASH_AUTHORITY` (the manager's only slasher) and
///         `VERIFIER` (the M3 threshold verifier). An absent or empty variable
///         falls back to a public, valueless `anvil` address: a half-configured
///         run cannot mint a role to an account nobody controls, and a dry run
///         with no environment at all is byte-for-byte reproducible. A variable
///         that is present but malformed is a hard error (`envOr` reverts), so a
///         typo cannot silently deploy a protocol wired to the fallback.
///
///      What M7a deliberately does NOT do:
///        - it deploys no threshold verifier. `Groth16Verifier` takes a
///          verification key, and the only key in the repository is M4b's
///          *development* key over a circuit with no ceremony
///          (`../test/fixtures/M4bGroth16Fixtures.sol`, §5.5): installing it on a
///          shared testnet would present a development key as a deployment.
///          `VERIFIER` is therefore an explicit input, `address(0)` by default,
///          which `AVIPRegistry` accepts on purpose — with no verifier set,
///          `verifyThreshold` reverts (`VerifierNotSet`) instead of certifying;
///        - it never broadcasts: no script here calls `--broadcast`, and
///          `deploy_dryrun.sh` runs them in dry-run mode. Handing the network
///          step to a human with a funded key is M7's decision, not a default.
abstract contract DeployCommon is Script {
    /// @notice Avalanche C-Chain mainnet: refused by every script in this
    ///         directory.
    uint256 internal constant C_CHAIN_MAINNET = 43_114;

    /// @notice Avalanche Fuji C-Chain testnet: the intended target of M7.
    uint256 internal constant FUJI_C_CHAIN = 43_113;

    /// @notice Chain id of a local `anvil`, and of a `forge script` dry run.
    uint256 internal constant LOCAL_CHAIN = 31_337;

    /// @notice `anvil` accounts 0, 1, 2 and 3. Public development keys that hold
    ///         nothing on any real network, which is exactly why they are the
    ///         defaults: a missing role falls back to an address that cannot be
    ///         stolen rather than to the deployer.
    address internal constant ANVIL_0 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address internal constant ANVIL_1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address internal constant ANVIL_2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address internal constant ANVIL_3 = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;

    /// @notice Role `name` is absent, empty, or resolved to the zero address.
    error MissingRole(string name);

    /// @notice The deployed contract answers something other than what the
    ///         script wired: `role` labels the pair.
    error WiringMismatch(string role, uint256 expected, uint256 actual);

    /// @notice The script was pointed at C-Chain mainnet.
    error MainnetRefused(uint256 chainId);

    /// @notice Two roles that the protocol keeps separate were resolved to the
    ///         same address. A `GUARDIAN` that is also the `SEQUENCER` is not a
    ///         second authority: it is one key that can both post commitments and
    ///         propose its own continuation (M9a, §12.1.2), which is the capture
    ///         the proposal/execute pair exists to close.
    error RolesCollapsed(string role, string other);

    /// @dev Fail closed on the one chain where a mistake costs money.
    function _refuseMainnet() internal view {
        if (block.chainid == C_CHAIN_MAINNET) revert MainnetRefused(block.chainid);
    }

    /// @dev Reads `name`, falling back to `fallbackTo` when it is absent or
    ///      empty, and reverting when it is present but not an address.
    function _roleOr(string memory name, address fallbackTo) internal view returns (address) {
        string memory raw;
        try vm.envString(name) returns (string memory value) {
            raw = value;
        } catch {
            return fallbackTo; // absent
        }
        if (bytes(raw).length == 0) return fallbackTo; // present but empty
        // Parsed strictly, and NOT through `envOr`: `envOr` answers a malformed
        // value with the default, which is exactly the silent fallback this
        // helper exists to prevent (`vm.parseAddress` reverts instead).
        return vm.parseAddress(raw);
    }

    /// @dev Reads a role the script cannot invent: `REGISTRY`, for instance.
    function _requiredRole(string memory name) internal view returns (address value) {
        value = _roleOr(name, address(0));
        if (value == address(0)) revert MissingRole(name);
    }

    /// @dev Reads a decimal input the script cannot invent either — a token scale,
    ///      for instance. Absent, empty or malformed all revert: the same reason
    ///      `_requiredRole` exists, and the same error, because it is the same
    ///      class of input (something the script must be told and must not guess).
    function _requiredUint(string memory name) internal view returns (uint256 value) {
        string memory raw;
        try vm.envString(name) returns (string memory found) {
            raw = found;
        } catch {
            revert MissingRole(name);
        }
        if (bytes(raw).length == 0) revert MissingRole(name);
        value = vm.parseUint(raw);
    }

    function _deployer() internal view returns (address) {
        return _roleOr("DEPLOYER", ANVIL_0);
    }

    function _sequencer() internal view returns (address) {
        return _roleOr("SEQUENCER", ANVIL_1);
    }

    function _slashAuthority() internal view returns (address) {
        return _roleOr("SLASH_AUTHORITY", ANVIL_2);
    }

    /// @dev `address(0)` by default and deliberately: M7a deploys no verifier,
    ///      and the registry treats "no verifier set" as "certify nothing".
    function _verifier() internal view returns (address) {
        return _roleOr("VERIFIER", address(0));
    }

    /// @dev Never `address(0)`, and deliberately at the far end of the anvil
    ///      range from `SEQUENCER`: the registry's `guardian` is a *proposer*, so
    ///      an unconfigured deployment must not silently hand that power to the
    ///      sequencer's own key (M9a, §12.1.2; the contract rejects a zero
    ///      guardian outright).
    function _guardian() internal view returns (address) {
        return _roleOr("GUARDIAN", ANVIL_3);
    }

    /// @dev `address(0)` by default and deliberately: with no custody the manager
    ///      declares `financialStake` without backing it, which is the original M2
    ///      behaviour and what phase 1 deploys (§5.2.3). M8's phase supplies the
    ///      vault it deployed first, whose `bindManager` hole the manager's
    ///      constructor then fills and verifies (§5.12).
    function _custody() internal view returns (address) {
        return _roleOr("CUSTODY", address(0));
    }

    /// @dev The name of the chain the script is talking to, for the transcript.
    function _chainName() internal view returns (string memory) {
        if (block.chainid == FUJI_C_CHAIN) return "fuji";
        if (block.chainid == LOCAL_CHAIN) return "anvil-or-dry-run";
        return "unknown";
    }

    /// @dev The strongest statement a deployment script can make without a
    ///      network: read the wiring back from the instance it just created, so
    ///      a wrong constructor argument fails here rather than at the first
    ///      real call.
    function _assertEq(string memory role, uint256 expected, uint256 actual) internal pure {
        if (expected != actual) revert WiringMismatch(role, expected, actual);
    }

    function _assertAddressEq(string memory role, address expected, address actual) internal pure {
        _assertEq(role, uint256(uint160(expected)), uint256(uint160(actual)));
    }

    /// @dev One machine-readable line per fact, so `deploy_dryrun.sh` can pin the
    ///      transcript without pinning gas or timestamps. `virtual` so a milestone
    ///      that logs through this harness can tag its own lines (M8's vault script
    ///      prints `[m8]`), while the shared helpers keep working unchanged.
    function _log(string memory key, string memory value) internal pure virtual {
        console2.log(string.concat("[m7a] ", key, "=", value));
    }

    function _logAddress(string memory key, address value) internal pure {
        _log(key, vm.toString(value));
    }

    function _logUint(string memory key, uint256 value) internal pure {
        _log(key, vm.toString(value));
    }

    /// @dev Header shared by every script's transcript.
    function _logHeader(string memory scriptName, address deployer) internal view {
        _log("script", scriptName);
        _log("chain", vm.toString(block.chainid));
        _log("chain.name", _chainName());
        _logAddress("sender", deployer);
    }
}
