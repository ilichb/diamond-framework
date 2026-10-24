// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/console2.sol";
import {Groth16Verifier} from "../contracts/verifiers/Groth16Verifier.sol";
import {M4dGroth16Fixtures as F} from "../test/fixtures/M4dGroth16Fixtures.sol";
import {DeployCommon} from "./DeployCommon.sol";

/// @title DeployVerifier
/// @notice Deploys the admission-statement `Groth16Verifier` (M4d) and installs
///         the development key from `test/fixtures/M4dGroth16Fixtures.sol`.
///
/// @dev This closes the one deliberate hole M7a left open: `DeployCommon` says
///      it deploys no verifier because both keys in the repository are
///      *development* keys, and installing one on a shared testnet would present
///      a development key as a deployment. That reasoning still holds. What
///      changes here is the purpose of the deployment: it exists so the phase-2
///      registry has a verifier at all, so `verifyThreshold` stops reverting
///      `VerifierNotSet` and the wired path can be observed end to end on Fuji.
///
///      **What this deployment does not claim.**
///        - **No soundness.** `SETUP_SEED` is committed and the transcript is
///          public: the toxic waste is derivable by anyone, so forgeries against
///          this key are free. A ceremony replaces the key by deploying another
///          verifier and rotating it through `proposeVerifier` /
///          `executeVerifierChange`; nothing in the contract changes.
///        - **No mainnet.** `_refuseMainnet()` fires before the key is even
///          loaded.
///
///      Dry run (no environment, no network):
///
///        forge script scripts/DeployVerifier.s.sol:DeployVerifier
///
///      Fuji: add `--rpc-url "$FUJI_RPC_URL" --broadcast` and a funded
///      `DEPLOYER`. The address is then announced with
///      `scripts/ProposeVerifier.s.sol`, which waits `CHANGE_DELAY` (2 days)
///      before `executeVerifierChange()` — permissionless — installs it.
contract DeployVerifier is DeployCommon {
    /// @notice What the script did, and the key facts a reader can compare
    ///         against the fixture without trusting the transcript.
    struct Deployment {
        address deployer;
        address verifier;
        bytes32 keyDigest;
        uint256 numPublicInputs;
        uint256 icLength;
    }

    /// @notice CLI entry point.
    /// @dev The chain guard is repeated here so it fires before the key is read.
    function run() external returns (Deployment memory) {
        _refuseMainnet();
        return deploy(_deployer());
    }

    /// @notice Deploys the verifier from the committed development key and
    ///         verifies its own wiring.
    /// @param deployer The broadcasting account.
    /// @return d The deployment, including the digest the contract publishes.
    function deploy(address deployer) public returns (Deployment memory d) {
        _refuseMainnet();

        Groth16Verifier.VerifyingKey memory vk = F.verifyingKey();

        vm.startBroadcast(deployer);
        Groth16Verifier verifier = new Groth16Verifier(vk);
        vm.stopBroadcast();

        d = Deployment({
            deployer: deployer,
            verifier: address(verifier),
            keyDigest: verifier.verifyingKeyDigest(),
            numPublicInputs: verifier.numPublicInputs(),
            icLength: verifier.icLength()
        });

        _checkWiring(verifier, d);
        _report(d);
    }

    /// @dev Two independent implementations of the same digest: the fixture's
    ///      `KEY_DIGEST` is `keccak256(abi.encode(vk))` computed in Rust from the
    ///      ABI layout (`test/M4dRealKey.t.sol` makes the same comparison), and
    ///      the contract recomputes it in its constructor. A mismatch means the
    ///      key the chain holds is not the key the prover holds, which is the
    ///      only failure mode a verifier deployment can have without a proof.
    function _checkWiring(Groth16Verifier verifier, Deployment memory d) internal view {
        _assertEq("code.length", 1, address(verifier).code.length == 0 ? 0 : 1);
        _assertEq("keyDigest", uint256(F.KEY_DIGEST), uint256(d.keyDigest));
        _assertEq("numPublicInputs", 4, d.numPublicInputs);
        _assertEq("icLength", 5, d.icLength);
    }

    function _log(string memory key, string memory value) internal pure override {
        console2.log(string.concat("[m4d] ", key, "=", value));
    }

    function _report(Deployment memory d) internal view {
        _logHeader("DeployVerifier", d.deployer);
        _logAddress("Groth16Verifier", d.verifier);
        _logBytes32("key.digest", d.keyDigest);
        _logUint("key.numPublicInputs", d.numPublicInputs);
        _logUint("key.icLength", d.icLength);
        _log("key.source", "M4dGroth16Fixtures (development setup, no ceremony)");
        _log("status", "ok");
    }
}
