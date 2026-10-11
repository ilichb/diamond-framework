// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/console2.sol";
import {AVIPStakeVault} from "../contracts/AVIPStakeVault.sol";
import {DeployCommon} from "./DeployCommon.sol";

/// @title DeployStakeVault
/// @notice Deploys `AVIPStakeVault` (milestone M8, §5.12): the custody the
///         manager's `financialStake` is declared against, wired to the token it
///         escrows and the sink that receives slashed stake and the fee.
///
/// @dev M8's phase of `docs/architecture/avalanche-integration.md` §6. What the
///      script fixes, and why each input is mandatory:
///
///        - `TOKEN` — the escrowed token. Required: a vault pointed at nobody
///          escrows nothing, and the constructor refuses `address(0)` anyway;
///        - `SINK` — the `IFundSink` that receives a slash and the fee. Required
///          for the same reason. `AVIPBurnSink` is the reference choice
///          (`D-M8-0`), and a deployment that keeps the funds points at its own
///          implementation; nothing in the vault changes either way;
///        - `WAD_PER_UNIT` — `10 ** (18 - decimals)` of `TOKEN`. **Required, and
///          deliberately not read from the token**: `decimals()` is a
///          non-standard call on the custody path and the vault never makes it.
///          A wrong scale would mis-price every comparison against `stakeOf`, so
///          it is an operator input the script reads back, not a default.
///
///      **This script deploys the first half of the handshake.** The vault cannot
///      know the manager's address, so it is deployed first and its single hole is
///      filled by `DeployValidatorManager.s.sol`, which is handed this address as
///      `CUSTODY`, binds it from the manager's constructor and verifies the
///      result. That is why the transcript below reports `check.manager` as
///      unbound: at this point it must be.
///
///      Dry run, no environment, no network (all three inputs are required):
///
///        TOKEN=0x... SINK=0x... WAD_PER_UNIT=1000000000000 forge script \
///            scripts/DeployStakeVault.s.sol:DeployStakeVault
///
///      Fuji (M8): add `--rpc-url "$FUJI_RPC_URL" --broadcast` and a funded
///      `DEPLOYER`. Mainnet (`43114`) reverts with `MainnetRefused`.
contract DeployStakeVault is DeployCommon {
    /// @notice The inputs the script will use, resolved before anything is
    ///         deployed.
    struct Plan {
        address deployer;
        address token;
        address sink;
        uint256 wadPerUnit;
    }

    /// @notice What the script actually did: the plan plus the address the vault
    ///         landed on.
    struct Deployment {
        address deployer;
        address vault;
        address token;
        address sink;
        uint256 wadPerUnit;
    }

    /// @notice CLI entry point: resolves the inputs from the environment and
    ///         deploys from that plan.
    /// @dev The chain guard is repeated here so it fires before a single input is
    ///      read: a malformed shell variable must not be able to mask a mainnet
    ///      refusal with a parse error.
    function run() external returns (Deployment memory) {
        _refuseMainnet();
        return deploy(plan());
    }

    /// @notice Deploys from an explicit plan, and verifies its own wiring.
    /// @param p The deployer, the token, the sink and the token's scale.
    /// @return d The deployment, including the address of the new vault.
    function deploy(Plan memory p) public returns (Deployment memory d) {
        _refuseMainnet();
        if (p.token == address(0)) revert MissingRole("TOKEN");
        if (p.sink == address(0)) revert MissingRole("SINK");
        if (p.wadPerUnit == 0) revert MissingRole("WAD_PER_UNIT");

        vm.startBroadcast(p.deployer);
        AVIPStakeVault vault = new AVIPStakeVault(p.token, p.sink, p.wadPerUnit);
        vm.stopBroadcast();

        d = Deployment({
            deployer: p.deployer,
            vault: address(vault),
            token: p.token,
            sink: p.sink,
            wadPerUnit: p.wadPerUnit
        });

        _checkWiring(vault, d);
        _report(d);
    }

    /// @notice Resolves the inputs without touching the chain. All three are
    ///         required: none of them can be defaulted without inventing a token,
    ///         a destination or a scale.
    function plan() public view returns (Plan memory p) {
        p.deployer = _deployer();
        p.token = _requiredRole("TOKEN");
        p.sink = _requiredRole("SINK");
        p.wadPerUnit = _requiredUint("WAD_PER_UNIT");
    }

    /// @dev Reads the wiring back from the instance just deployed: the two
    ///      addresses, the scale, and the fact that **no manager is bound yet**,
    ///      which is the state `DeployValidatorManager.s.sol` is supposed to find.
    function _checkWiring(AVIPStakeVault vault, Deployment memory d) internal view {
        _assertAddressEq("token", d.token, address(vault.TOKEN()));
        _assertAddressEq("sink", d.sink, address(vault.SINK()));
        _assertEq("wadPerUnit", d.wadPerUnit, vault.WAD_PER_UNIT());
        _assertEq("ONE", 1e18, vault.ONE());
        _assertAddressEq("manager", address(0), vault.manager());
        _assertEq("feeInUnits", 0, vault.feeInUnits());
        _assertEq("totalEscrowedUnits", 0, vault.totalEscrowedUnits());
    }

    /// @dev Tagged `[m8]` rather than the harness's `[m7a]`: this is M8's script,
    ///      and `deploy_dryrun.sh` greps for both tags.
    function _log(string memory key, string memory value) internal pure override {
        console2.log(string.concat("[m8] ", key, "=", value));
    }

    function _report(Deployment memory d) internal view {
        _logHeader("DeployStakeVault", d.deployer);
        _logAddress("AVIPStakeVault", d.vault);
        _logAddress("role.token", d.token);
        _logAddress("role.sink", d.sink);
        _logUint("check.wadPerUnit", d.wadPerUnit);
        _logUint("check.ONE", 1e18);
        _log("check.manager", "unbound");
        _logUint("check.feeInUnits", 0);
        _logUint("check.totalEscrowedUnits", 0);
        _log("status", "ok");
    }
}
