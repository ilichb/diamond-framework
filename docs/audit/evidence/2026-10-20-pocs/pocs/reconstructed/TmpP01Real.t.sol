// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// RECONSTRUIDO — no es el fichero original de la sesión 2026-10-20.
//
// El `TmpP01Real.t.sol` original se borró y no hay copia recuperable. Esta
// reescritura conserva el experimento central: el mismo proof **real** de
// `M4bGroth16Fixtures` (Groth16/BN254, no un mock) admite a dos validadores
// distintos con el `AVIPValidatorManager` real.
//
// Para ejecutarlo, copiarlo a `integrations/avalanche/test/` con un nombre
// `TmpEvidence*.t.sol` (las rutas de import asumen esa ubicación), correr
// `forge test --match-contract TmpP01RealEvidenceTest -vv` y guardar la salida
// en `logs/`. El fuente canónico se queda en esta carpeta.

import {Test} from "forge-std/Test.sol";
import {AVIPRegistry} from "../contracts/AVIPRegistry.sol";
import {AVIPValidatorManager} from "../contracts/AVIPValidatorManager.sol";
import {Groth16Verifier} from "../contracts/verifiers/Groth16Verifier.sol";
import {M4bGroth16Fixtures as F} from "./fixtures/M4bGroth16Fixtures.sol";

contract TmpP01RealEvidenceTest is Test {
    address internal sequencer = makeAddr("sequencer");
    address internal guardian = makeAddr("guardian");
    address internal slashAuthority = makeAddr("slashAuthority");

    Groth16Verifier internal verifier;
    AVIPRegistry internal registry;
    AVIPValidatorManager internal manager;

    function setUp() public {
        verifier = new Groth16Verifier(F.verifyingKey());
        registry = new AVIPRegistry(sequencer, address(verifier), guardian);

        // Genesis: the registry's own post, with the Poseidon root the proof
        // certifies. 500 entries is the tensor size the paper fixes.
        vm.prank(sequencer);
        registry.postCommitment(F.STATEMENT_EPOCH, bytes32(F.STATEMENT_ROOT), 500);

        // No custody: this isolates admission from the vault and is the M2 path.
        manager = new AVIPValidatorManager(address(registry), slashAuthority, address(0));
    }

    /// @notice The finding: the proof carries no validator, so Alice and Bob can
    ///         present the same bytes and both are admitted.
    function test_sameRealProofAdmitsTwoDifferentValidators() public {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");

        vm.prank(alice);
        manager.admit(alice, 1e18, F.STATEMENT_NORM, F.proof());

        vm.prank(bob);
        manager.admit(bob, 1e18, F.STATEMENT_NORM, F.proof());

        assertTrue(manager.isAdmitted(alice), "alice admitted");
        assertTrue(manager.isAdmitted(bob), "bob admitted with the same proof");
        assertEq(
            manager.requiredStake(alice),
            manager.requiredStake(bob),
            "the stake is a function of the norm, not of the validator"
        );
    }

    /// @notice The proof is bound to the three statement elements, but not to a
    ///         fourth one: there is no fourth one to bind.
    function test_theStatementHasOnlyThreeBindings() public view {
        uint256[] memory statement = F.statement();
        assertTrue(verifier.verify(F.proofA(), F.proofB(), F.proofC(), statement));

        statement[0] = F.STATEMENT_ROOT + 1;
        assertFalse(verifier.verify(F.proofA(), F.proofB(), F.proofC(), statement));

        statement[0] = F.STATEMENT_ROOT;
        statement[1] = F.STATEMENT_EPOCH + 1;
        assertFalse(verifier.verify(F.proofA(), F.proofB(), F.proofC(), statement));

        statement[1] = F.STATEMENT_EPOCH;
        statement[2] = F.STATEMENT_NORM + 1;
        assertFalse(verifier.verify(F.proofA(), F.proofB(), F.proofC(), statement));
    }

    /// @notice A proof for another norm cannot be turned into an admission: the
    ///         registry builds the statement and returns false, the manager
    ///         turns that verdict into a revert.
    function test_managerRejectsAProofForAnotherNorm() public {
        address alice = makeAddr("alice");
        vm.prank(alice);
        vm.expectRevert();
        manager.admit(alice, 1e18, F.STATEMENT_NORM + 1, F.proof());
    }
}
