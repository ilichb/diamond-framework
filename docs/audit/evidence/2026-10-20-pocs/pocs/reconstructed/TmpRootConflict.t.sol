// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// RECONSTRUIDO — no es el fichero original de la sesión 2026-10-20.
//
// Conserva el experimento de P-16: el registry tiene un solo `_roots[epoch]`,
// pero el proof V3 habla de la raíz Poseidon (`STATEMENT_ROOT`) y `verifyEntry`
// habla de la raíz keccak de las hojas (`MERKLE_ROOT`). No son la misma raíz.
//
// Para ejecutarlo, copiarlo a `integrations/avalanche/test/` como
// `TmpEvidence*.t.sol`, correr
// `forge test --match-contract TmpRootConflictEvidenceTest -vv` y guardar la
// salida en `logs/`.

import {Test} from "forge-std/Test.sol";
import {AVIPRegistry} from "../contracts/AVIPRegistry.sol";
import {Groth16Verifier} from "../contracts/verifiers/Groth16Verifier.sol";
import {M4bGroth16Fixtures as F} from "./fixtures/M4bGroth16Fixtures.sol";
import {M7cBridgeFixtures as F7c} from "./fixtures/M7cBridgeFixtures.sol";

contract TmpRootConflictEvidenceTest is Test {
    address internal sequencer;
    address internal guardian;

    Groth16Verifier internal verifier;
    AVIPRegistry internal registry;

    function setUp() public {
        sequencer = makeAddr("sequencer");
        guardian = makeAddr("guardian");
        verifier = new Groth16Verifier(F.verifyingKey());
        registry = new AVIPRegistry(sequencer, address(verifier), guardian);
    }

    function test_oneSlotCannotHoldThePoseidonRootAndTheMerkleRoot() public {
        vm.startPrank(sequencer);
        registry.postCommitment(0, bytes32(F.STATEMENT_ROOT), 500);
        registry.postCommitment(1, F7c.MERKLE_ROOT, 0);
        vm.stopPrank();

        // The V3 proof verifies against the Poseidon root...
        assertTrue(registry.verifyThreshold(0, F.STATEMENT_NORM, F.proof()));

        // ...and fails against the keccak Merkle root, even though that root is
        // the one `verifyEntry` folds leaves into.
        assertFalse(registry.verifyThreshold(1, F.STATEMENT_NORM, F.proof()));

        assertEq(registry.commitmentOf(0), bytes32(F.STATEMENT_ROOT));
        assertEq(registry.commitmentOf(1), F7c.MERKLE_ROOT);
        assertTrue(bytes32(F.STATEMENT_ROOT) != F7c.MERKLE_ROOT);
    }

    function test_theRegistryCannotTellWhichRootAnEpochMeant() public {
        vm.startPrank(sequencer);
        registry.postCommitment(0, bytes32(F.STATEMENT_ROOT), 500);
        registry.postCommitment(1, F7c.MERKLE_ROOT, 0);
        vm.stopPrank();

        // Both values are "the root" for their epoch; only the epoch number
        // distinguishes them. There is no second slot saying which commitment
        // scheme the epoch uses.
        assertEq(registry.latestEpoch(), 1);
        assertEq(registry.commitmentOf(0), bytes32(F.STATEMENT_ROOT));
        assertEq(registry.commitmentOf(1), F7c.MERKLE_ROOT);
    }
}
