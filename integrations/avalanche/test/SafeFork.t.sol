// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CreateSafe, ISafe} from "../scripts/CreateSafe.s.sol";

/// @notice Fork test for the Safe that phase 2 will install as
///         `SLASH_AUTHORITY`: it proves the *policy*, not the deployment.
///
/// @dev Why it is a test and not part of `deploy_dryrun.sh`: it needs live Fuji
///      state (the canonical factory and singleton), and the dry run is
///      deliberately offline and byte-for-byte reproducible. It therefore skips
///      itself when no RPC is available, so `forge test` on a machine without
///      network access still passes — with one skip, visible in the summary
///      rather than hidden. Run it with:
///
///        FUJI_RPC_URL="$(cat ~/.config/avip/fuji_rpc.txt)" \
///            forge test --match-path test/SafeFork.t.sol -vv
///
///      What it establishes, and why each half matters:
///
///        1. P-39 was "one key decides every slash". A Safe that deploys is not
///           an answer to that; an N-of-M that *cannot be executed by fewer than
///           N* is. Two signatures execute the transaction and the nonce moves;
///           one signature reverts. Both directions are asserted, because a
///           misconfigured threshold (1-of-3) would pass the first half alone;
///        2. the two signatures are produced with `vm.sign` over the EIP-712
///           digest, i.e. the same bytes an owner's wallet signs. Nothing here
///           depends on the Safe SDK, so the test is independent evidence for
///           the addresses the SDK will later operate;
///        3. the owner keys are throwaways generated in the test, not the
///           operator's. The test never touches a real key, and the fork is
///           discarded.
contract SafeForkTest is Test {
    /// @dev Throwaway keys for the three owners. `vm.addr` derives the addresses
    ///      from them, so the test knows both halves of each identity — which is
    ///      what lets it sign on the fork without any external secret.
    uint256 internal constant OWNER_A_PK =
        0xA11CE00000000000000000000000000000000000000000000000000000000001;
    uint256 internal constant OWNER_B_PK =
        0xB0B0000000000000000000000000000000000000000000000000000000000002;
    uint256 internal constant OWNER_C_PK =
        0xCAFE000000000000000000000000000000000000000000000000000000000003;

    /// @dev The funded account that pays for the deployment on the fork. It is
    ///      not an owner; that separation is asserted.
    address internal constant PAYER = 0x12458CD567C9f01cbA220Fe3f2Af97034f9635bb;

    bytes32 internal constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(uint256 chainId,address verifyingContract)");
    bytes32 internal constant SAFE_TX_TYPEHASH = keccak256(
        "SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,"
        "uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)"
    );

    CreateSafe internal script;

    function setUp() public {
        string memory rpc = vm.envOr("FUJI_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            vm.skip(true);
            return;
        }
        vm.createSelectFork(rpc);
        script = new CreateSafe();
    }

    function test_safe_twoOfThree_executesAndOneSignatureIsNotEnough() public {
        address[3] memory owners = [vm.addr(OWNER_A_PK), vm.addr(OWNER_B_PK), vm.addr(OWNER_C_PK)];
        address[] memory list = new address[](3);
        for (uint256 i; i < 3; i++) {
            list[i] = owners[i];
        }

        vm.deal(PAYER, 1 ether);
        CreateSafe.Plan memory p =
            CreateSafe.Plan({deployer: PAYER, owners: list, threshold: 2, saltNonce: 0});
        CreateSafe.Deployment memory d = script.deploy(p);

        assertEq(ISafe(d.safe).getThreshold(), 2, "threshold");
        assertEq(ISafe(d.safe).getOwners().length, 3, "owner count");
        assertEq(ISafe(d.safe).nonce(), 0, "nonce starts at zero");
        for (uint256 i; i < 3; i++) {
            assertTrue(d.safe != owners[i], "deployer is not an owner");
        }

        // A no-op transaction to the Safe itself: no value, no calldata. It
        // exercises the full signature path without needing a target contract.
        bytes memory signature = _sign(d.safe, 0, OWNER_A_PK, OWNER_B_PK);
        address executor = address(0xEEEE);
        vm.prank(executor);
        bool ok = ISafe(d.safe)
            .execTransaction(d.safe, 0, bytes(""), 0, 0, 0, 0, address(0), address(0), signature);
        assertTrue(ok, "2-of-3 executes");
        assertEq(ISafe(d.safe).nonce(), 1, "nonce advanced");

        // The same shape with one signature must not execute. `nonce` moved, so
        // this is a fresh transaction, not a replay of the one above.
        bytes memory one = _sign(d.safe, 1, OWNER_A_PK, 0);
        vm.prank(executor);
        vm.expectRevert();
        ISafe(d.safe).execTransaction(d.safe, 0, bytes(""), 0, 0, 0, 0, address(0), address(0), one);
        assertEq(ISafe(d.safe).nonce(), 1, "nonce did not advance");
    }

    /// @dev Builds the two concatenated 65-byte signatures for `nonce`, sorted
    ///      ascending by owner address as `checkNSignatures` requires. `pk2 == 0`
    ///      produces the single-signature case.
    function _sign(address safe, uint256 nonce, uint256 pk1, uint256 pk2)
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = _digest(safe, nonce);
        (address a1, bytes memory s1) = _sig(pk1, digest);
        if (pk2 == 0) return s1;
        (address a2, bytes memory s2) = _sig(pk2, digest);
        return uint160(a1) < uint160(a2) ? abi.encodePacked(s1, s2) : abi.encodePacked(s2, s1);
    }

    function _sig(uint256 pk, bytes32 digest) internal pure returns (address, bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return (vm.addr(pk), abi.encodePacked(r, s, v));
    }

    function _digest(address safe, uint256 nonce) internal view returns (bytes32) {
        bytes32 domain = keccak256(abi.encode(DOMAIN_TYPEHASH, block.chainid, safe));
        bytes32 structHash = keccak256(
            abi.encode(
                SAFE_TX_TYPEHASH,
                safe, // to
                uint256(0), // value
                keccak256(bytes("")), // data
                uint8(0), // operation: CALL
                uint256(0), // safeTxGas
                uint256(0), // baseGas
                uint256(0), // gasPrice
                address(0), // gasToken
                address(0), // refundReceiver
                nonce
            )
        );
        return keccak256(abi.encodePacked(bytes2(0x1901), domain, structHash));
    }
}
