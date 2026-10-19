// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/console2.sol";
import {DeployCommon} from "./DeployCommon.sol";
import {MockBurnableERC20} from "../test/mocks/MockBurnableERC20.sol";

/// @title DeployMockToken
/// @notice Deploys the burnable ERC-20 test double used by phase 1, so that the
///         vault has a `TOKEN` and `AVIPBurnSink` has a token whose `burn` works.
///
/// @dev A1b, the token half of the Fuji runbook. `MockBurnableERC20` is the
///      repository's own test double (`../test/mocks/`), not a production token:
///      `mint` is unrestricted, the supply is zero at deployment, and the token
///      exists to exercise the custody path on a testnet. It is used here because
///      the repository vendors no deployable ERC-20 and phase 1 must not present
///      a test double as a real asset. The supply is zero after deployment;
///      `mint(to, amount)` is unrestricted, so the operator funds the deployer or
///      a validator with a separate call after this script (for example
///      `cast send "$TOKEN" "mint(address,uint256)" "$WHO" "$AMOUNT"`). The other
///      behaviour knobs (`setBlocked`, `setFeeBps`, ...) are unrestricted too:
///      this token is for a testnet, never for value.
///
///      The scale is part of the transcript because `AVIPStakeVault` does not call
///      `decimals()`: `WAD_PER_UNIT = 10 ** (18 - decimals)` is the value the
///      vault's constructor must receive. With the default 18 decimals it is 1;
///      with 6 decimals it is 1e12, which is the scale M8's fixtures use.
///
///      Dry run, no network:
///
///        DEPLOYER=0x... TOKEN_NAME="AVIP Mock Token" TOKEN_DECIMALS=6 \
///            forge script scripts/DeployMockToken.s.sol:DeployMockToken --offline
///
///      Fuji: add `--rpc-url "$FUJI_RPC_URL" --broadcast --account deployer`; the
///      human runs that command. Mainnet (43114) reverts with `MainnetRefused`,
///      and any chain other than Fuji/local reverts with `UnsupportedChain`.
contract DeployMockToken is DeployCommon {
    /// @notice The largest scale the vault can express: `10 ** (18 - decimals)`.
    uint8 internal constant MAX_DECIMALS = 18;

    /// @notice Defaults, used only when the optional variable is absent or empty.
    string internal constant DEFAULT_NAME = "AVIP Mock Token";
    uint8 internal constant DEFAULT_DECIMALS = 18;

    /// @notice The chain is neither Fuji nor a local dry run.
    error UnsupportedChain(uint256 chainId);

    /// @notice The token's constructor requires a non-empty name.
    error EmptyTokenName();

    /// @notice `decimals` is larger than 18, so the vault has no WAD scale.
    error TooManyDecimals(uint256 decimals);

    /// @notice The deployed token has no code at the reported address.
    error TokenHasNoCode(address token);

    /// @notice The deployed token does not answer the metadata it was given.
    error TokenMetadataMismatch(string field, string expected, string actual);

    /// @notice The inputs the script will use, resolved before deployment.
    struct Plan {
        address deployer;
        string name;
        uint8 decimals;
    }

    /// @notice What the script actually did.
    struct Deployment {
        address deployer;
        address token;
        string name;
        uint8 decimals;
        uint256 wadPerUnit;
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
        if (p.deployer == address(0)) revert MissingRole("DEPLOYER");
        if (bytes(p.name).length == 0) revert EmptyTokenName();
        if (p.decimals > MAX_DECIMALS) revert TooManyDecimals(p.decimals);

        vm.startBroadcast(p.deployer);
        MockBurnableERC20 token = new MockBurnableERC20(p.name, p.decimals);
        vm.stopBroadcast();

        d = Deployment({
            deployer: p.deployer,
            token: address(token),
            name: p.name,
            decimals: p.decimals,
            wadPerUnit: 10 ** (18 - uint256(p.decimals))
        });

        _checkWiring(token, d);
        _report(d);
    }

    /// @notice Resolves the optional metadata without touching the chain.
    function plan() public view returns (Plan memory p) {
        p.deployer = _requiredRole("DEPLOYER");
        p.name = _stringOr("TOKEN_NAME", DEFAULT_NAME);
        uint256 decimals = _uintOr("TOKEN_DECIMALS", DEFAULT_DECIMALS);
        if (decimals > MAX_DECIMALS) revert TooManyDecimals(decimals);
        // The bound above makes the cast lossless; `decimals <= 18`.
        // forge-lint: disable-next-line(unsafe-typecast)
        p.decimals = uint8(decimals);
    }

    /// @dev Reads the metadata back from the instance just deployed. The token's
    ///      supply is zero by construction and its `burn` has not been called.
    function _checkWiring(MockBurnableERC20 token, Deployment memory d) internal view {
        if (address(token).code.length == 0) revert TokenHasNoCode(address(token));
        if (token.decimals() != d.decimals) {
            revert TokenMetadataMismatch(
                "decimals", vm.toString(uint256(d.decimals)), vm.toString(uint256(token.decimals()))
            );
        }
        if (keccak256(bytes(token.name())) != keccak256(bytes(d.name))) {
            revert TokenMetadataMismatch("name", d.name, token.name());
        }
        _assertEq("totalSupply", 0, token.totalSupply());
        _assertEq("totalBurned", 0, token.totalBurned());
        _assertEq("wadPerUnit", d.wadPerUnit, 10 ** (18 - uint256(d.decimals)));
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
        _log("token.kind", "mock-burnable-erc20");
        _log("token.name", d.name);
        _logUint("token.decimals", d.decimals);
        _logUint("token.total_supply", 0);
        _logUint("wad_per_unit", d.wadPerUnit);
        _log("status", "ok");
    }

    /// @dev Optional string: absent and empty both mean "use the default". A
    ///      string has no malformed case to refuse (unlike an address).
    function _stringOr(string memory name, string memory fallbackTo)
        internal
        view
        returns (string memory)
    {
        try vm.envString(name) returns (string memory value) {
            if (bytes(value).length != 0) return value;
        } catch {}
        return fallbackTo;
    }

    /// @dev Optional decimal: absent and empty use the default; a present but
    ///      malformed value reverts through `vm.parseUint` rather than falling
    ///      back silently.
    function _uintOr(string memory name, uint256 fallbackTo) internal view returns (uint256) {
        string memory raw;
        try vm.envString(name) returns (string memory value) {
            raw = value;
        } catch {
            return fallbackTo;
        }
        if (bytes(raw).length == 0) return fallbackTo;
        return vm.parseUint(raw);
    }
}
