// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/console2.sol";
import {DeployCommon} from "./DeployCommon.sol";
import {AVIPBurnSink} from "../contracts/AVIPBurnSink.sol";
import {IERC20Minimal} from "../contracts/interfaces/IERC20Minimal.sol";

/// @title DeployBurnSink
/// @notice Deploys `AVIPBurnSink`, the reference `IFundSink` that destroys what
///         the vault sends it (`implementation-plan.md` §5.12, `D-M8-0`).
///
/// @dev A1b, the sink half of the Fuji runbook. The sink is constructor-fixed to
///      one token and has no setter, so `TOKEN` is mandatory and is read back
///      only through what the contract exposes: there is no `TOKEN()` getter by
///      design. On Fuji the script requires the token to have code; it always
///      checks that the sink has code, that `totalBurned` is zero, and that the
///      sink holds none of the token before the first slash.
///
///      **The token must be burnable.** `AVIPBurnSink` calls the token's own
///      `burn(uint256)` and reports `BurnFailed` for a token without it. Use
///      `DeployMockToken.s.sol` (a `MockBurnableERC20`) on a testnet, or a real
///      burnable ERC-20. A plain ERC-20 would deploy successfully and fail at
///      the first slash, which is the documented refusal and not a wiring bug.
///
///      Dry run, no network:
///
///        DEPLOYER=0x... TOKEN=0x... \
///            forge script scripts/DeployBurnSink.s.sol:DeployBurnSink --offline
///
///      Fuji: add `--rpc-url "$FUJI_RPC_URL" --broadcast --account deployer`; the
///      human runs that command. Mainnet (43114) reverts with `MainnetRefused`,
///      and any chain other than Fuji/local reverts with `UnsupportedChain`.
contract DeployBurnSink is DeployCommon {
    /// @notice The chain is neither Fuji nor a local dry run.
    error UnsupportedChain(uint256 chainId);

    /// @notice The token address has no code, so the sink would point at nobody.
    error TokenHasNoCode(address token);

    /// @notice The sink address has no code after deployment.
    error SinkHasNoCode(address sink);

    /// @notice The sink's read-back disagrees with the deployment.
    error SinkWiringMismatch(string field, uint256 expected, uint256 actual);

    /// @notice The inputs the script will use, resolved before deployment.
    struct Plan {
        address deployer;
        address token;
    }

    /// @notice What the script actually did.
    struct Deployment {
        address deployer;
        address token;
        address sink;
        uint256 totalBurned;
        uint256 sinkTokenBalance;
    }

    /// @notice CLI entry point: resolves the environment and deploys.
    function run() external returns (Deployment memory) {
        _requirePhase1Chain();
        return deploy(plan());
    }

    /// @notice Deploys from an explicit plan and verifies its own wiring.
    /// @dev The guard and the input checks live here too, so a caller that hands
    ///      over a `Plan` directly cannot skip them.
    function deploy(Plan memory p) public returns (Deployment memory d) {
        _requirePhase1Chain();
        _refuseAnvilDefault("DEPLOYER", p.deployer);
        _refuseAnvilDefault("TOKEN", p.token);
        if (p.deployer == address(0)) revert MissingRole("DEPLOYER");
        if (p.token == address(0)) revert MissingRole("TOKEN");
        // A live deployment must point at a real token; a dry run may use an
        // arbitrary address, because a fresh local EVM has no Fuji code to read.
        if (block.chainid == FUJI_C_CHAIN && p.token.code.length == 0) {
            revert TokenHasNoCode(p.token);
        }

        vm.startBroadcast(p.deployer);
        AVIPBurnSink sink = new AVIPBurnSink(p.token);
        vm.stopBroadcast();

        d = Deployment({
            deployer: p.deployer,
            token: p.token,
            sink: address(sink),
            totalBurned: sink.totalBurned(),
            sinkTokenBalance: p.token.code.length == 0
                ? 0
                : IERC20Minimal(p.token).balanceOf(address(sink))
        });

        _checkWiring(sink, d);
        _report(d);
    }

    /// @notice Resolves the two inputs without touching the chain.
    function plan() public view returns (Plan memory p) {
        p.deployer = _requiredRole("DEPLOYER");
        p.token = _requiredRole("TOKEN");
    }

    /// @dev The sink has no token getter, so the token is checked at the input
    ///      boundary (`TokenHasNoCode` on Fuji) and the sink is checked for the
    ///      two facts it does expose: it exists and it has burned/holds nothing
    ///      yet. A local dry run with an address that has no code reports a zero
    ///      balance without pretending to have read the token.
    function _checkWiring(AVIPBurnSink sink, Deployment memory d) internal view {
        if (address(sink).code.length == 0) revert SinkHasNoCode(address(sink));
        if (sink.totalBurned() != 0) {
            revert SinkWiringMismatch("totalBurned", 0, sink.totalBurned());
        }
        if (d.sinkTokenBalance != 0) {
            revert SinkWiringMismatch("sinkTokenBalance", 0, d.sinkTokenBalance);
        }
    }

    /// @dev Same two chains A1 accepts. Mainnet keeps its own error.
    function _requirePhase1Chain() internal view {
        if (block.chainid == C_CHAIN_MAINNET) revert MainnetRefused(block.chainid);
        if (block.chainid != FUJI_C_CHAIN && block.chainid != LOCAL_CHAIN) {
            revert UnsupportedChain(block.chainid);
        }
    }

    /// @dev Tagged `[fuji]` so the A1 transcript and this one share a parser.
    function _log(string memory key, string memory value) internal pure override {
        console2.log(string.concat("[fuji] ", key, "=", value));
    }

    function _report(Deployment memory d) internal view {
        _log("chain.id", vm.toString(block.chainid));
        _log("chain.name", _chainName());
        _logAddress("sender", d.deployer);
        _logAddress("deployer", d.deployer);
        _logAddress("token", d.token);
        _log("token.code", d.token.code.length == 0 ? "absent" : "present");
        _logAddress("sink", d.sink);
        _log("sink.kind", "burn");
        _logUint("sink.total_burned", d.totalBurned);
        _logUint("sink.token_balance", d.sinkTokenBalance);
        _log("status", "ok");
    }
}
