// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AVIPRegistry} from "../contracts/AVIPRegistry.sol";
import {DatalayerInclusion as Data} from "./fixtures/DatalayerInclusion.sol";

/// WHAT IS TESTED
/// --------------
/// R5-1 and R5-2, from the other side of the language boundary. The vector is
/// emitted by `src/zk/scripts/merkle_fixture.sh`, i.e. computed by
/// `avip_datalayer::commitment` and nothing else — no Solidity code in this file
/// builds a tree, hashes a leaf or folds a level. The deployed contract's own
/// `verifyEntry` is then asked whether it accepts that answer:
///
/// 1. `keccak256(payload)` is the leaf, for all four entries of the 4-entry epoch:
///    one hash, the first of the two `verifyEntry` performs.
/// 2. `verifyEntry(EPOCH_ROOT, leaf, proof)` is `true` for all four entries, with
///    `EPOCH_ROOT` and the proofs straight from the data layer (R5-1: before the
///    fix this returned `false` for every honest entry).
/// 3. The retired convention — the root you get by folding the *leaves* instead of
///    `keccak256(leaf)` — is rejected on-chain, so the two conventions are not
///    interchangeable and the fixture pins the one that is deployed.
/// 4. A payload with one bit flipped is rejected: the root binds the 52-byte
///    payload and not only its position.
/// 5. The 500-entry tensor's proofs verify against `TENSOR_ROOT`, including the
///    leaf that has no sibling at the odd level (125 nodes) — the shape R5-2 is
///    about. `AVIPRegistry.t.sol` asserts the other half: that its own `_buildTree`
///    folds those same leaves to `TENSOR_ROOT` by promoting, not by duplicating.
///
/// WHAT IS NOT TESTED
/// ------------------
/// - Nothing here says the tensor is the paper's tensor: that tie is M7c's
///   (`src/zk/scripts/m7c_output.txt`), and this file only asserts the tree.
/// - `verifyEntry` is `pure` and reads no state, so no epoch is posted and no
///   sequencer is involved. Whether a *registry* stores this root is `commitEpoch`'s
///   business and is covered by `AVIPRegistry.t.sol`.
contract DatalayerInclusionTest is Test {
    AVIPRegistry internal registry;

    function setUp() public {
        // Two distinct roles: the constructor refuses guardian == sequencer (P-10).
        registry = new AVIPRegistry(
            makeAddr("sequencer"),
            address(0),
            makeAddr("guardian"),
            keccak256("avalanche-c-chain"),
            keccak256("AVIP/fragment-function/v1")
        );
    }

    function test_verifyEntry_acceptsTheDatalayerEpoch() public view {
        bytes[] memory payloads = Data.payloads();
        bytes32[] memory leaves = Data.leaves();
        bytes32[][] memory proofs = Data.proofs();

        assertEq(payloads.length, Data.EPOCH_ENTRIES, "one payload per entry");
        assertEq(leaves.length, Data.EPOCH_ENTRIES, "one leaf per entry");
        assertEq(proofs.length, Data.EPOCH_ENTRIES, "one proof per entry");

        for (uint256 i = 0; i < leaves.length; ++i) {
            assertEq(payloads[i].length, 52, "abi.encodePacked(address, uint256)");
            assertEq(keccak256(payloads[i]), leaves[i], "leaf = keccak256(payload)");
            assertTrue(
                registry.verifyEntry(Data.EPOCH_ROOT, leaves[i], proofs[i]),
                "the data layer's root must verify on-chain"
            );
        }
    }

    function test_verifyEntry_rejectsTheRetiredRoot() public view {
        // The pre-R5-1 fold: the leaves go straight into the pairs, one hash fewer
        // at the bottom.
        bytes32[] memory leaves = Data.leaves();
        bytes32 retired = _foldLeavesDirectly(leaves);

        assertTrue(retired != Data.EPOCH_ROOT, "the two conventions differ");
        for (uint256 i = 0; i < leaves.length; ++i) {
            assertFalse(
                registry.verifyEntry(retired, leaves[i], Data.proofs()[i]),
                "the retired root must not verify"
            );
        }
    }

    function test_verifyEntry_rejectsATamperedPayload() public view {
        bytes memory payload = Data.payloads()[0];
        payload[51] ^= 0x01;
        assertFalse(
            registry.verifyEntry(Data.EPOCH_ROOT, keccak256(payload), Data.proofs()[0]),
            "one bit of the norm"
        );
    }

    function test_verifyEntry_acceptsTheDatalayerTensorProofs() public view {
        bytes32[] memory leaves = Data.tensorLeaves();
        uint256[] memory positions = Data.tensorPositions();
        bytes32[][] memory proofs = Data.tensorProofs();

        assertEq(leaves.length, Data.TENSOR_ENTRIES, "the full tensor");
        assertEq(positions.length, proofs.length, "one proof per emitted position");

        for (uint256 i = 0; i < positions.length; ++i) {
            assertEq(
                proofs[i].length,
                _proofLength(positions[i], leaves.length),
                "one sibling per level that has one"
            );
            assertTrue(
                registry.verifyEntry(Data.TENSOR_ROOT, leaves[positions[i]], proofs[i]),
                "a tensor proof must verify on-chain"
            );
        }
    }

    function test_verifyEntry_rejectsATensorProofFromAnotherLeaf() public view {
        uint256[] memory positions = Data.tensorPositions();
        bytes32[][] memory proofs = Data.tensorProofs();
        assertFalse(
            registry.verifyEntry(Data.TENSOR_ROOT, Data.tensorLeaves()[positions[0]], proofs[1]),
            "a proof belongs to its own leaf"
        );
    }

    /// @dev The number of levels a proof of `index` carries when an odd level
    ///      promotes its last node: one sibling per level, except where the node is
    ///      the unpaired last one.
    function _proofLength(uint256 index, uint256 count) internal pure returns (uint256) {
        uint256 length = 0;
        uint256 level = count;
        uint256 pos = index;
        while (level > 1) {
            if ((pos ^ 1) < level) {
                length++;
            }
            pos /= 2;
            level = (level + 1) / 2;
        }
        return length;
    }

    /// @dev The retired fold, kept only to show that `verifyEntry` rejects it.
    function _foldLeavesDirectly(bytes32[] memory leaves) internal pure returns (bytes32) {
        bytes32[] memory level = leaves;
        while (level.length > 1) {
            bytes32[] memory next = new bytes32[]((level.length + 1) / 2);
            for (uint256 p = 0; p < next.length; ++p) {
                if (2 * p + 1 < level.length) {
                    next[p] = _hashPair(level[2 * p], level[2 * p + 1]);
                } else {
                    next[p] = level[2 * p];
                }
            }
            level = next;
        }
        return level[0];
    }

    function _hashPair(bytes32 left, bytes32 right) internal pure returns (bytes32) {
        return left < right
            ? keccak256(abi.encodePacked(left, right))
            : keccak256(abi.encodePacked(right, left));
    }
}

