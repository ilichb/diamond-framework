// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/console2.sol";
import {DeployCommon} from "./DeployCommon.sol";

/// @dev The subset of `SafeProxyFactory` v1.4.1 this script uses.
interface ISafeProxyFactory {
    function createProxyWithNonce(address singleton, bytes calldata initializer, uint256 saltNonce)
        external
        returns (address proxy);

    function proxyCreationCode() external pure returns (bytes memory);
}

/// @dev The subset of `Safe` v1.4.1 the read-back needs.
interface ISafe {
    function VERSION() external view returns (string memory);
    function getOwners() external view returns (address[] memory);
    function getThreshold() external view returns (uint256);
    function nonce() external view returns (uint256);
    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        bytes calldata signatures
    ) external returns (bool success);
}

/// @title CreateSafe
/// @notice Deploys a Safe (v1.4.1) on Fuji for the `SLASH_AUTHORITY` role of
///         phase 2, from a list of owner addresses and a threshold.
///
/// @dev **Why this exists instead of app.safe.global.** The hosted interface
///      only offers chains its own deployment list maintains, and Avalanche Fuji
///      is not one of them. The SDK route (`safe-global/protocol-kit`) works,
///      but it needs a signer to send the deployment transaction, and the
///      natural signer is one of the owners — which means handling an owner key
///      to create a contract whose whole purpose is that no single key holds the
///      role. That trade is unnecessary, and this script exists to avoid it:
///
///        - the owners only ever appear here as **addresses**. No key, no
///          signature, no `--private-key` for any of them;
///        - creating a Safe needs no approval from its owners. The factory
///          deploys an EIP-1167 proxy whose constructor delegatecalls `setup`
///          on the singleton; `setup` writes the owner set and the threshold
///          without checking a signature, because at that instant the contract
///          has no policy to check against yet. The only signature involved is
///          the *deployer's*, and it pays gas — nothing else;
///        - `setup` is invoked exactly once and only from the proxy's
///          constructor, so there is no window in which a third party can
///          re-initialise the Safe with a different owner set.
///
///      The deployer is therefore the existing `DEPLOYER` role, funded with AVAX
///      for gas, and it does **not** become an owner: `_checkWiring` proves that
///      by reading `getOwners()` back.
///
///      Owners are sorted ascending before the initializer is built, which is
///      what `safe-global/protocol-kit` does. The order changes the initializer
///      and therefore the CREATE2 address: sorting is what makes the address
///      predicted here equal to the one the SDK reports for the same inputs, and
///      it makes the transcript independent of the order the addresses were
///      typed in. Two owners with the same address, a zero owner, or a threshold
///      outside `1..owners.length` revert before anything is sent.
///
///      Dry run against Fuji state, no transaction (the factory must already be
///      deployed on the fork, which it is on 43113):
///
///        DEPLOYER=0x... SAFE_OWNER_1=0x... SAFE_OWNER_2=0x... \
///        SAFE_OWNER_3=0x... SAFE_THRESHOLD=2 \
///            forge script scripts/CreateSafe.s.sol:CreateSafe \
///                --rpc-url "$FUJI_RPC_URL"
///
///      Broadcast: the same command plus `--broadcast --account <keystore>` (or
///      `--private-key` for a throwaway key). Mainnet (`43114`) reverts with
///      `MainnetRefused` before any input is read.
contract CreateSafe is DeployCommon {
    /// @notice `Safe` v1.4.1 singleton, canonical deployment (same address on
    ///         every chain that has it; verified with `cast code` on Fuji).
    address internal constant SAFE_SINGLETON = 0x41675C099F32341bf84BFc5382aF534df5C7461a;

    /// @notice `SafeProxyFactory` v1.4.1, canonical deployment.
    address internal constant SAFE_PROXY_FACTORY = 0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67;

    /// @notice `CompatibilityFallbackHandler` v1.4.1, canonical deployment. The
    ///         handler is what makes the Safe answer ERC-1271 and ERC-721/1155
    ///         callbacks; a Safe without it is still a valid multisig, so this is
    ///         a choice recorded in the transcript, not an assumption.
    address internal constant SAFE_FALLBACK_HANDLER = 0xfd0732Dc9E303f09fCEf3a7388Ad10A83459Ec99;

    /// @notice `MultiSendCallOnly` v1.4.1, canonical deployment. Read-only here:
    ///         the script logs it so the operator has the address at hand when
    ///         batching the phase-2 calls, and it does not need to be in the
    ///         initializer for that.
    address internal constant SAFE_MULTISEND_CALL_ONLY = 0x40A2aCCbd92BCA938b02010E17A5b8929b49130D;

    /// @notice Upper bound on owners, so a typo in `SAFE_OWNER_17` cannot turn
    ///         into a silent extra owner. Safe imposes no such limit; this is the
    ///         script's own guard, and it is generous for a 2-of-3.
    uint256 internal constant MAX_OWNERS = 8;

    /// @notice Where Safe v1.4.1 keeps the fallback handler:
    ///         `keccak256("fallback_manager.handler.address")`. **Read from
    ///         storage, not through a getter**, because 1.4.1 has none —
    ///         `getFallbackHandler()` arrived with 1.5.0, and calling it on a
    ///         1.4.1 Safe reaches the handler's own fallback and reverts. The
    ///         slot is what `setup` wrote, so it is the same fact either way.
    bytes32 internal constant FALLBACK_HANDLER_SLOT =
        0x6c9a6c4a39284e37ed1cf53d337577d14212a4870fb976a4366c693b939918d5;

    /// @notice The inputs the script will use, resolved before anything is sent.
    struct Plan {
        address deployer;
        address[] owners;
        uint256 threshold;
        uint256 saltNonce;
    }

    /// @notice What the script actually did.
    struct Deployment {
        address deployer;
        address safe;
        address[] owners;
        uint256 threshold;
        uint256 saltNonce;
    }

    /// @notice A `SAFE_OWNER_n` entry is the zero address.
    error ZeroOwner(uint256 index);

    /// @notice The same address appears twice in the owner list. Safe's
    ///         `setupOwners` would revert too, but with an unlabelled code.
    error DuplicateOwner(address owner);

    /// @notice The threshold is zero or larger than the owner set.
    error ThresholdOutOfRange(uint256 threshold, uint256 ownerCount);

    /// @notice No owner was supplied.
    error NoOwners();

    /// @notice An owner index is missing while a later one is set — e.g.
    ///         `SAFE_OWNER_3` without `SAFE_OWNER_2`. Reading stops at the gap,
    ///         so without this guard the Safe would be deployed with fewer
    ///         owners than were typed and a threshold that no longer means what
    ///         was intended.
    error OwnerIndexGap(uint256 missingIndex);

    /// @notice The address the factory returned does not hold a Safe, or holds
    ///         one whose singleton slot is not the canonical singleton.
    error NotASafe(address candidate);

    /// @notice The canonical factory has no code on this chain, so neither
    ///         prediction nor deployment is possible.
    error SafeFactoryMissing(address factory, uint256 chainId);

    /// @notice CLI entry point: resolves the inputs from the environment and
    ///         deploys from that plan.
    function run() external returns (Deployment memory) {
        _refuseMainnet();
        return deploy(plan());
    }

    /// @notice Deploys the Safe from an explicit plan and verifies the result.
    /// @param p The deployer, the owner addresses, the threshold and the salt.
    /// @return d The deployment, including the address the Safe landed on.
    function deploy(Plan memory p) public returns (Deployment memory d) {
        _refuseMainnet();
        if (SAFE_PROXY_FACTORY.code.length == 0) {
            revert SafeFactoryMissing(SAFE_PROXY_FACTORY, block.chainid);
        }
        if (p.owners.length == 0) revert NoOwners();
        if (p.owners.length > MAX_OWNERS) revert ThresholdOutOfRange(p.owners.length, MAX_OWNERS);

        _sort(p.owners);
        _validateOwners(p.owners, p.deployer);
        if (p.threshold == 0 || p.threshold > p.owners.length) {
            revert ThresholdOutOfRange(p.threshold, p.owners.length);
        }

        bytes memory initializer = _initializer(p.owners, p.threshold);
        address predicted = predict(p.owners, p.threshold, p.saltNonce);

        vm.startBroadcast(p.deployer);
        address safe = ISafeProxyFactory(SAFE_PROXY_FACTORY)
            .createProxyWithNonce(SAFE_SINGLETON, initializer, p.saltNonce);
        vm.stopBroadcast();

        d = Deployment({
            deployer: p.deployer,
            safe: safe,
            owners: p.owners,
            threshold: p.threshold,
            saltNonce: p.saltNonce
        });

        _assertAddressEq("predicted", predicted, d.safe);
        _checkWiring(d);
        _report(d);
    }

    /// @notice Predicts the address `deploy` will produce, without sending
    ///         anything. Uses the same CREATE2 inputs the factory uses: the salt
    ///         is `keccak256(keccak256(initializer) ++ saltNonce)` and the init
    ///         code is `proxyCreationCode() ++ uint256(singleton)`.
    /// @dev Exposed publicly so an operator can compare it with the address the
    ///      SDK or the Safe UI computes for the same owner set before paying gas.
    function predict(address[] memory owners, uint256 threshold, uint256 saltNonce)
        public
        view
        returns (address)
    {
        bytes memory initializer = _initializer(owners, threshold);
        bytes32 salt = keccak256(abi.encodePacked(keccak256(initializer), saltNonce));
        bytes memory initCode = abi.encodePacked(
            ISafeProxyFactory(SAFE_PROXY_FACTORY).proxyCreationCode(),
            uint256(uint160(SAFE_SINGLETON))
        );
        return vm.computeCreate2Address(salt, keccak256(initCode), SAFE_PROXY_FACTORY);
    }

    /// @notice Resolves the inputs from the environment without touching the
    ///         chain, so `plan` can be inspected before a broadcast.
    /// @dev `SAFE_OWNER_1..8` are read in order and stop at the first absent or
    ///      empty name; a present-but-malformed address reverts (`vm.parseAddress`
    ///      through `_roleOr`), and an `anvil` address is refused off-local by the
    ///      same helper. A gap is refused rather than silently truncating the
    ///      list. `SAFE_THRESHOLD` is required: the script cannot pick a
    ///      threshold for a governance decision. `SAFE_SALT_NONCE` is optional
    ///      and defaults to 0, the SDK's default.
    function plan() public view returns (Plan memory p) {
        p.deployer = _deployer();
        p.threshold = _requiredUint("SAFE_THRESHOLD");
        p.saltNonce = _uintOr("SAFE_SALT_NONCE", 0);

        address[] memory found = new address[](MAX_OWNERS);
        uint256 n;
        for (uint256 i = 1; i <= MAX_OWNERS; i++) {
            address owner = _roleOr(string.concat("SAFE_OWNER_", vm.toString(i)), address(0));
            if (owner == address(0)) {
                for (uint256 j = i + 1; j <= MAX_OWNERS; j++) {
                    if (
                        _roleOr(string.concat("SAFE_OWNER_", vm.toString(j)), address(0))
                            != address(0)
                    ) {
                        revert OwnerIndexGap(i);
                    }
                }
                break;
            }
            found[n++] = owner;
        }

        p.owners = new address[](n);
        for (uint256 i; i < n; i++) {
            p.owners[i] = found[i];
        }
    }

    /// @dev `setup(address[],uint256,address,bytes,address,address,uint256,address)`
    ///      on Safe v1.4.1 — selector `0xb63e800d`, checked against the deployed
    ///      singleton's bytecode rather than taken from documentation. No
    ///      delegate call during setup (`to = 0`, empty data) and no payment:
    ///      the Safe starts with no module enabled and no balance moved.
    function _initializer(address[] memory owners, uint256 threshold)
        internal
        view
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            bytes4(0xb63e800d),
            owners,
            threshold,
            address(0),
            bytes(""),
            SAFE_FALLBACK_HANDLER,
            address(0),
            uint256(0),
            address(0)
        );
    }

    /// @dev Ascending insertion sort, in place. The owner list is at most eight
    ///      entries, so the quadratic cost is irrelevant and the code stays
    ///      obviously correct — a wrong order silently changes the address.
    function _sort(address[] memory owners) internal pure {
        for (uint256 i = 1; i < owners.length; i++) {
            address key = owners[i];
            uint256 j = i;
            while (j > 0 && uint160(owners[j - 1]) > uint160(key)) {
                owners[j] = owners[j - 1];
                j--;
            }
            owners[j] = key;
        }
    }

    /// @dev Rejects the two owner lists Safe would either revert on or accept
    ///      while meaning something else: a zero entry, and a duplicate. The
    ///      deployer is refused as an owner on a live chain: it is the account
    ///      that signs the deployment, and turning it into an extra owner would
    ///      widen the policy without saying so in the owner list.
    function _validateOwners(address[] memory owners, address deployer) internal view {
        for (uint256 i; i < owners.length; i++) {
            if (owners[i] == address(0)) revert ZeroOwner(i);
            _refuseAnvilDefault("SAFE_OWNER", owners[i]);
            if (owners[i] == deployer) revert DuplicateOwner(owners[i]);
            for (uint256 j = i + 1; j < owners.length; j++) {
                if (owners[i] == owners[j]) revert DuplicateOwner(owners[i]);
            }
        }
    }

    /// @dev Reads the policy back from the instance just created. Every fact
    ///      here is one the phase-2 preflight will rely on: the version, the
    ///      owner set, the threshold, the handler, and — through storage slot 0,
    ///      where the proxy keeps the singleton — that the proxy points at the
    ///      canonical implementation and not at something else wearing the same
    ///      address.
    function _checkWiring(Deployment memory d) internal view {
        if (d.safe.code.length == 0) revert NotASafe(d.safe);

        address singleton = address(uint160(uint256(vm.load(d.safe, bytes32(uint256(0))))));
        if (singleton != SAFE_SINGLETON) revert NotASafe(d.safe);

        ISafe safe = ISafe(d.safe);
        _assertEq("threshold", d.threshold, safe.getThreshold());
        address handler = address(uint160(uint256(vm.load(d.safe, FALLBACK_HANDLER_SLOT))));
        _assertAddressEq("fallbackHandler", SAFE_FALLBACK_HANDLER, handler);
        _assertEq("nonce", 0, safe.nonce());
        string memory version = _version(d.safe);
        _assertEq("VERSION", uint256(keccak256("1.4.1")), uint256(keccak256(bytes(version))));
        address[] memory onchain = safe.getOwners();
        _assertEq("ownerCount", d.owners.length, onchain.length);
        for (uint256 i; i < d.owners.length; i++) {
            _assertAddressEq("owner", d.owners[i], onchain[i]);
        }
    }

    /// @dev Tagged `[safe]` rather than the harness's `[m7a]`, like M8's script.
    function _log(string memory key, string memory value) internal pure override {
        console2.log(string.concat("[safe] ", key, "=", value));
    }

    function _report(Deployment memory d) internal view {
        _logHeader("CreateSafe", d.deployer);
        _logAddress("safe", d.safe);
        _logUint("threshold", d.threshold);
        _logUint("owners.count", d.owners.length);
        for (uint256 i; i < d.owners.length; i++) {
            _logAddress(string.concat("owners.", vm.toString(i)), d.owners[i]);
        }
        _logAddress("singleton", SAFE_SINGLETON);
        _logAddress("factory", SAFE_PROXY_FACTORY);
        _logAddress("fallbackHandler", SAFE_FALLBACK_HANDLER);
        _logAddress("multiSendCallOnly", SAFE_MULTISEND_CALL_ONLY);
        _log("check.VERSION", _version(d.safe));
        _logUint("check.nonce", ISafe(d.safe).nonce());
        _logUint("saltNonce", d.saltNonce);
        _log("status", "ok");
    }

    /// @dev `VERSION()` on a Safe proxy, defensively: the singleton answers it,
    ///      but a proxy created by a different factory need not, and the
    ///      read-back should report that rather than revert with an empty return
    ///      the operator cannot interpret.
    function _version(address safe) internal view returns (string memory) {
        try ISafe(safe).VERSION() returns (string memory value) {
            return value;
        } catch {
            return "unavailable";
        }
    }

    /// @dev Reads a uint with the discipline `_bytes32Or` uses: absent or empty
    ///      falls back, present but malformed reverts.
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
