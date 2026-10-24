// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/console2.sol";
import {AVIPRegistry} from "../contracts/AVIPRegistry.sol";
import {DeployCommon} from "./DeployCommon.sol";

/// @title ProposeVerifier
/// @notice Announces a verifier on a live `AVIPRegistry` (M9a, §12.1.2): the
///         first half of the rotation that `executeVerifierChange()` finishes
///         after `CHANGE_DELAY`.
///
/// @dev Why two transactions and two days: the guardian is a single key, and
///      `verifyThreshold` is the only path that certifies an admission. A
///      guardian that could swap the verifier in one block could install a key
///      that certifies anything, and the announcement is what gives every
///      observer two days to notice. The same delay protects a *compromised*
///      guardian: `executeVerifierChange()` is permissionless once the delay has
///      elapsed, so the replacement lands whether or not the guardian that
///      proposed it is still under control.
///
///      Inputs (no defaults; a script cannot invent either one):
///        - `REGISTRY` — the registry to announce on;
///        - `VERIFIER` — the verifier to install (the address
///          `DeployVerifier.s.sol` reports);
///        - `GUARDIAN` — the account that signs, read back from the registry so
///          the script fails before broadcasting if it was given the wrong one.
///
///      Broadcast with the guardian's key:
///
///        REGISTRY=0x... VERIFIER=0x... GUARDIAN=0x... \
///        forge script scripts/ProposeVerifier.s.sol:ProposeVerifier \
///            --rpc-url "$FUJI_RPC_URL" --broadcast --private-key "$GUARDIAN_KEY"
///
///      Then, after `verifierChangeEta` (anyone can send it; no key needed
///      beyond gas):
///
///        cast send "$REGISTRY" 'executeVerifierChange()' --rpc-url "$FUJI_RPC_URL" ...
contract ProposeVerifier is DeployCommon {
    /// @notice The inputs, resolved before anything is signed.
    struct Plan {
        address guardian;
        address registry;
        address verifier;
    }

    /// @notice What the registry now holds as a pending change.
    struct Announcement {
        address registry;
        address verifier;
        address previous;
        address pending;
        uint256 eta;
    }

    /// @notice CLI entry point.
    function run() external returns (Announcement memory) {
        _refuseMainnet();
        return propose(plan());
    }

    /// @notice Announces `p.verifier` on `p.registry` and reports the resulting
    ///         pending state.
    /// @param p The guardian, the registry and the verifier.
    function propose(Plan memory p) public returns (Announcement memory a) {
        _refuseMainnet();
        if (p.registry == address(0)) revert MissingRole("REGISTRY");
        if (p.verifier == address(0)) revert MissingRole("VERIFIER");
        if (p.guardian == address(0)) revert MissingRole("GUARDIAN");
        if (p.verifier.code.length == 0) revert MissingRole("VERIFIER");

        AVIPRegistry registry = AVIPRegistry(p.registry);

        // Fail before spending gas: the guardian is immutable, so a wrong value
        // is not a misconfiguration that a later call repairs.
        _assertAddressEq("guardian", registry.guardian(), p.guardian);

        a.previous = address(registry.verifier());

        vm.startBroadcast(p.guardian);
        registry.proposeVerifier(p.verifier);
        vm.stopBroadcast();

        a.registry = p.registry;
        a.verifier = p.verifier;
        a.pending = registry.pendingVerifier();
        a.eta = registry.verifierChangeEta();

        _assertAddressEq("pendingVerifier", p.verifier, a.pending);
        // A live broadcast lands in a block later than the simulated one, so the
        // exact `eta` is only pinned in `test/DeployScripts.t.sol` (where the
        // timestamp is deterministic). Here the invariant that must hold on a
        // real chain is the one a reader can check: the change is in the future
        // and it is this one.
        if (a.eta <= block.timestamp) revert WiringMismatch("verifier.eta", 1, 0);

        _report(a, p.guardian);
    }

    /// @notice Resolves the three inputs without touching the chain.
    function plan() public view returns (Plan memory p) {
        p.guardian = _requiredRole("GUARDIAN");
        p.registry = _requiredRole("REGISTRY");
        p.verifier = _requiredRole("VERIFIER");
    }

    function _log(string memory key, string memory value) internal pure override {
        console2.log(string.concat("[m9a] ", key, "=", value));
    }

    function _report(Announcement memory a, address guardian) internal view {
        _logHeader("ProposeVerifier", guardian);
        _logAddress("registry", a.registry);
        _logAddress("verifier.previous", a.previous);
        _logAddress("verifier.pending", a.pending);
        _logUint("verifier.eta", a.eta);
        _log("next", "executeVerifierChange() after eta (permissionless)");
        _log("status", "ok");
    }
}
