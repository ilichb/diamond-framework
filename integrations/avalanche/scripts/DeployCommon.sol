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
///          verification key, and the keys in the repository — M4b's V3 key and
///          M4d's admission key — are both *development* keys over circuits with
///          no ceremony (`../test/fixtures/M4bGroth16Fixtures.sol`,
///          `../test/fixtures/M4dGroth16Fixtures.sol`, §5.5): installing either
///          on a shared testnet would present a development key as a deployment.
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

    /// @notice `anvil` accounts 0, 1, 2 and 3. On `anvil` (31337) they are
    ///         harmless. On any chain other than 31337 they are public addresses
    ///         with real activity (high nonces and, on Fuji, a balance); a
    ///         deployment there must set `DEPLOYER`, `SEQUENCER` and
    ///         `SLASH_AUTHORITY` explicitly. `_roleOr` refuses them there.
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

    /// @notice A role resolved to one of the public `anvil` accounts on a chain
    ///         other than the local one. Those addresses are not valueless on
    ///         Fuji (they have nonces and balance), so using one as a deployment
    ///         authority is a configuration error, not a harmless default.
    error AnvilDefaultOnLiveNetwork(string role, address account, uint256 chainId);

    /// @notice `SLASH_AUTHORITY` resolved to an address with no code on a chain
    ///         other than the local one.
    /// @dev `AVIPValidatorManager.slashAuthority` is a single immutable address
    ///      with no proposal pair: whoever holds it decides every slash the
    ///      manager will ever execute, for the whole stake on record (M9b,
    ///      §12.1.2). A script cannot check a threshold — no on-chain call can
    ///      look inside a multisig — but it *can* refuse the case the threshold
    ///      is meant to rule out: one externally owned key. A contract is not
    ///      proof of an N-of-M policy; it is the difference between "one key" and
    ///      "a policy somebody had to deploy".
    error SlashAuthorityIsEOA(address authority, uint256 chainId);

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
            return _refuseAnvilDefault(name, fallbackTo); // absent
        }
        if (bytes(raw).length == 0) {
            return _refuseAnvilDefault(name, fallbackTo); // present but empty
        }
        // Parsed strictly, and NOT through `envOr`: `envOr` answers a malformed
        // value with the default, which is exactly the silent fallback this
        // helper exists to prevent (`vm.parseAddress` reverts instead).
        return _refuseAnvilDefault(name, vm.parseAddress(raw));
    }

    /// @dev A3/B-7: an `anvil` key is a public development key, and on Fuji it
    ///      is a live address with a nonce (and a balance). It is harmless only
    ///      on the local chain, where the dry run needs it. This guard is also
    ///      applied by the phase-1 script to explicit `Plan` values, so a caller
    ///      cannot bypass the environment check by constructing a plan directly.
    function _refuseAnvilDefault(string memory role, address account)
        internal
        view
        returns (address)
    {
        if (block.chainid == LOCAL_CHAIN) return account;
        if (account == ANVIL_0 || account == ANVIL_1 || account == ANVIL_2 || account == ANVIL_3) {
            revert AnvilDefaultOnLiveNetwork(role, account, block.chainid);
        }
        return account;
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
        return _requireSlasher(_roleOr("SLASH_AUTHORITY", ANVIL_2));
    }

    /// @dev M9b: on every chain other than the local one, the slashing authority
    ///      must be a contract. The manager's role is immutable and has no
    ///      proposal pair, so this is the last point at which a deployment can
    ///      refuse a single key deciding the whole stake. The local chain keeps
    ///      the `anvil` EOA, which is what the dry run and the reports use.
    function _requireSlasher(address authority) internal view returns (address) {
        if (block.chainid == LOCAL_CHAIN) return authority;
        if (authority.code.length == 0) revert SlashAuthorityIsEOA(authority, block.chainid);
        return authority;
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

    /// @notice Reference `sourceChainId`: the C-Chain, where this registry lives
    ///         and where the reference deployment folds from. Overridable with
    ///         `SOURCE_CHAIN_ID` when the data layer folds another chain's log.
    /// @dev **A deployment input, not a model parameter** (§6): no paper
    ///      equation names it. It is a `keccak256` of a domain string, not the
    ///      EIP-155 number, because `postCommitment` compares it as a `bytes32`
    ///      and a bare integer invites a silent unit mismatch.
    bytes32 internal constant DEFAULT_SOURCE_CHAIN_ID = keccak256("avalanche-c-chain");

    /// @notice Reference `formulaDigest`: `keccak256("AVIP/fragment-function/v1")`.
    /// @dev **A reference value, not a derived one.** The canonical digest of
    ///      `f_c` belongs to the implementation in `src/datalayer`; asserting a
    ///      literal here would let the script claim a check it cannot make. What
    ///      the contract enforces is that every epoch declares *this* value, so
    ///      a formula rotation cannot happen silently (M-15, Hazard 8). Supply
    ///      the real digest with `FORMULA_DIGEST` in a live deployment.
    bytes32 internal constant DEFAULT_FORMULA_DIGEST = keccak256("AVIP/fragment-function/v1");

    /// @dev Resolves `sourceChainId` from the environment, falling back to the
    ///      reference C-Chain value.
    function _sourceChainId() internal view returns (bytes32) {
        return _bytes32Or("SOURCE_CHAIN_ID", DEFAULT_SOURCE_CHAIN_ID);
    }

    /// @dev Resolves `formulaDigest` from the environment, falling back to the
    ///      reference value.
    function _formulaDigest() internal view returns (bytes32) {
        return _bytes32Or("FORMULA_DIGEST", DEFAULT_FORMULA_DIGEST);
    }

    /// @dev Reads a `bytes32` input with the same discipline as `_roleOr`:
    ///      absent or empty falls back, present but malformed reverts
    ///      (`vm.parseBytes32`), so a typo cannot silently deploy a registry
    ///      claiming an origin nobody chose.
    function _bytes32Or(string memory name, bytes32 fallbackTo) internal view returns (bytes32) {
        string memory raw;
        try vm.envString(name) returns (string memory value) {
            raw = value;
        } catch {
            return fallbackTo;
        }
        if (bytes(raw).length == 0) return fallbackTo;
        return vm.parseBytes32(raw);
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

    function _logBytes32(string memory key, bytes32 value) internal pure {
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
