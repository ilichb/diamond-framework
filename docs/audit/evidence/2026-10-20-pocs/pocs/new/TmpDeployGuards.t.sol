// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// NUEVO — PoC de la pasada de auditoría de ops/despliegue (2026-10-20), no una
// reconstrucción de un `Tmp*` perdido.
//
// Demuestra dos huecos de los guards de despliegue:
//
//   1. `DeployFujiPhase1.deploy` acepta `TOKEN` y `SINK` que son EOAs (sin
//      código) y devuelve `status=ok`: el transcript no distingue un token real
//      de una dirección vacía. La fase 1 no mueve fondos, pero el vault queda
//      desplegado y el manager enlazado a una custodia que no puede operar.
//   2. `DeployRegistry.deploy` sólo rechaza la C-Chain (`43114`); con un `Plan`
//      explícito en otra red viva (aquí chain id 1) despliega igual, sin
//      reaplicar `_refuseAnvilDefault`. El `run()` de la fase 1 sí exige Fuji o
//      local, pero los scripts individuales no comparten ese contrato.
//
// Para ejecutarlo, copiarlo a `integrations/avalanche/test/` con un nombre
// `TmpEvidence*.t.sol` (las rutas de import asumen esa ubicación), correr
// `forge test --match-contract TmpDeployGuardsTest -vv` y guardar la salida en
// `logs/`. El fuente canónico se queda en esta carpeta.

import {Test} from "forge-std/Test.sol";
import {AVIPRegistry} from "../contracts/AVIPRegistry.sol";
import {DeployFujiPhase1} from "../scripts/DeployFujiPhase1.s.sol";
import {DeployRegistry} from "../scripts/DeployRegistry.s.sol";

contract TmpDeployGuardsTest is Test {
    DeployFujiPhase1 internal phase1;
    DeployRegistry internal registryScript;

    function setUp() public {
        phase1 = new DeployFujiPhase1();
        registryScript = new DeployRegistry();
    }

    /// @notice La fase 1 en Fuji acepta un token y un sink sin código y reporta
    ///         `status=ok`. El `Plan` usa direcciones no-anvil para pasar el
    ///         guard de roles; el hueco es la ausencia de `code.length`.
    function test_phase1AcceptsEOATokenAndSinkAndReportsOk() public {
        vm.chainId(43_113); // Fuji C-Chain

        DeployFujiPhase1.Plan memory p = DeployFujiPhase1.Plan({
            deployer: address(0x1001),
            sequencer: address(0x2002),
            slashAuthority: address(0x3003),
            guardian: address(0x4004),
            token: address(0x5005),
            sink: address(0x6006),
            wadPerUnit: 1e12
        });

        DeployFujiPhase1.Deployment memory d = phase1.deploy(p);

        assertGt(d.registry.code.length, 0, "registry deployed");
        assertGt(d.vault.code.length, 0, "vault deployed");
        assertGt(d.manager.code.length, 0, "manager deployed");
        assertEq(d.token.code.length, 0, "TOKEN is an EOA");
        assertEq(d.sink.code.length, 0, "SINK is an EOA");
        assertEq(AVIPRegistry(d.registry).sequencer(), p.sequencer, "plan wired");
    }

    /// @notice `DeployRegistry.deploy` en una red que no es 43114: el guard
    ///         `_refuseMainnet` no se dispara y el `Plan` explícito no pasa por
    ///         `_refuseAnvilDefault`. La dirección es no-anvil para aislar el
    ///         guard de cadena del guard de claves públicas.
    function test_registryScriptAcceptsNonAvalancheLiveChain() public {
        vm.chainId(1); // Ethereum mainnet, no la C-Chain

        DeployRegistry.Plan memory p = DeployRegistry.Plan({
            deployer: address(0x1001),
            sequencer: address(0x2002),
            verifier: address(0),
            guardian: address(0x3003)
        });

        DeployRegistry.Deployment memory d = registryScript.deploy(p);

        assertGt(d.registry.code.length, 0, "registry deployed on chain 1");
        assertEq(AVIPRegistry(d.registry).sequencer(), p.sequencer, "plan wired");
    }
}
