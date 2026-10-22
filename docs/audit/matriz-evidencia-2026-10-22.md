# Matriz de evidencia — 2026-10-22 (v2)

Sustituye a `Matriz de evidencia_ confirmado _ refutado _ parcial _ ya cubierto.md`,
que se conserva intacta como fuente. Esta versión aplica las correcciones
A-1…A-8 del acta `checklist-matriz-evidencia-2026-10-22.md`; el contraste con el
mapa está en `triage-mapa-2026-10-22.md`.

Estado verificado: `HEAD` = `ea75594` (`m4d-review`, `v0.2.1-15-gea75594`),
275 tests Foundry / 0 fallos, 53 de reputación / 0 fallos y 13 de zk / 0 fallos.

## 0. Convención

Una fila es una afirmación **con un origen**. El estado sólo tiene sentido
dentro de su origen:

| Estado | Significado | Origen permitido |
|---|---|---|
| **C** | confirmado contra el árbol | mapa, sistema |
| **P** | parcialmente confirmado | mapa |
| **R** | el mapa se equivoca sobre el árbol | mapa |
| **S** | ya declarado en paper/plan; no se repara como código | mapa |
| **V** | verificado por lectura/ejecución, no es un claim del mapa | auditoría |
| **D** | decisión registrada, con razones | decisión |
| **N** | no falsable | — (fuera de la matriz) |

## 1. La matriz

| ID | Origen | Afirmación | Estado | Evidencia (HEAD) | Impacto |
|---|---|---|---|---|---|
| E-01 | mapa | La raíz Merkle y la prueba ZK no están ancladas end-to-end al tensor real: el vínculo es off-chain y no es una prueba | **C** | `src/zk/src/bridge.rs:19-26`; `src/zk/tests/m7c_bridge.rs`; `AVIPCommitmentRelay.sol:47-52` («carried, not proven») | Alta — `P-38`, `R3-03` |
| E-02 | mapa | El data layer es un punto de falla sistémico: la ingesta y la adjudicación viven fuera del contrato | **C** | `src/datalayer/src/ingestion.rs:251` (`adjudicate`); `AVIPRegistry.sol:272` (no recibe cadena de origen) | Alta — `P-02`, `P-12`, `P-34` |
| E-03 | mapa | El riesgo principal es semántico, no clásico (reentrancy, overflow, `delegatecall`) | **C** | 275 tests; ningún bug clásico explotable en el registro (`P-13` es un rechazo por *panic* de overflow, no una corrupción de estado) | Alta (por revisión, no por test) |
| E-04 | auditoría | El mapa describe un statement de tres palabras; HEAD construye cuatro, con `validator` público | **V** | `AVIPRegistry.sol:351-356` (4 argumentos), `:386-394` (4 palabras) | N/A — discrepancia, no defecto |
| E-05 | decisión | Publicar más campos no cierra la brecha: el circuito no puede derivarlos de las entradas | **D** | `triage-mapa-2026-10-22.md` §3.1; `src/zk/README.md` | Alta — rechaza el parche del mapa |
| E-06 | decisión | `certifiedNorm = floor(√ΣT_i²)` no es aceptable: contradice `P-03` y rompe la calibración de `S_f` | **D** | `P-03`; `admission.rs:65` (`STATEMENT_LEN = 4`); `AVIPValidatorManager.sol:78,191` | Alta — reabriría `P-03` |
| E-07a | sistema | El *binding* de la prueba a la dirección está **cerrado**: el proof no es un token al portador | **C** | `AVIPValidatorManager.sol:233-249` (`msg.sender == validator`); `AVIPRegistry.sol:386-394` | — — `P-01` resuelto |
| E-07b | mapa | La reputación no tiene unicidad ni persistencia: una dirección nueva empieza con historial cero | **C** | `P-12`; la hoja liga `address`, no una identidad durable | Media/Alta — abierto |
| E-08 | mapa | La custodia es opcional: con `custody == address(0)` el stake se declara y no se respalda | **C** | `AVIPValidatorManager.sol:143` (constructor), `:266-271` (`FinancialStakeNotBacked`), `§5.12` | Media — es decisión de despliegue, no de contrato |
| E-09 | mapa | El slash consume el registro entero (`amount = available`) y, si el validador estaba admitido, lo eyecta | **S** | `AVIPValidatorManager.sol:295-330`; `§12.1.2`, M9b | Media — decisión explícita |
| E-10 | mapa | No hay pausa de emergencia ni *fail-closed* para admisión o rotaciones | **S** | Ausencia verificada por `grep`; alcance en `§11` y M8 | Baja/Media — fuera de alcance declarado |
| E-12 | mapa | La versión de `f_c` no viaja on-chain con el estado publicado | **P** | Off-chain: `ingestion.rs:96,101,187-191`. On-chain: `AVIPCommitmentRelay.sol:198` transporta `sourceChainId` y el link; `postCommitment` no lo exige | Media — M-15 del mapa, T-2 |
| E-13 | mapa | `sequencer` y `guardian` son roles sensibles | **P** | `AVIPRegistry.sol:151-165` (roles separados), `:174-261` (`CHANGE_DELAY` en `propose*`/`execute*`) | Media — el multisig es de despliegue |
| E-19 | sistema | La cota **inferior** de la norma no la cierra el circuito: `verifyThreshold` acepta `certifiedNorm` en `[0, 2^64)` y sólo `admit` exige `≥ Θ_r`; la superior sí está cerrada (`norm < WAD` en el circuito, `< 2^64` en el registry) | **C** | `AVIPRegistry.sol:373`, `:363-380`; `AVIPValidatorManager.sol:78,249`; `admission.rs:244-245` | Media — `P-33` |
| E-20 | sistema | `verifyThreshold` acepta un epoch anterior al último publicado | **P** | `IAVIPValidatorManager.sol:155-160` (la admisión lee `latestEpoch()`); `AVIPRegistry.sol:328` | Baja (griefing) — `P-32` |
| E-21 | sistema | No hay unicidad de identidad por época | **C** | `P-12`; `admission.rs:102` (`Poseidon(validator, norm)`) | Media/Alta — abierto |
| E-22 | sistema | El castigo cross-chain se ejecuta sobre la palabra del `NOTIFIER`: no hay prueba de fraude on-chain ni ventana de impugnación | **C** | `P-34`; `AVIPMessageCodec.sol` (tipo de mensaje §4) y el test M7d que lo declara | Alta — confianza/custodia |

E-11, E-15 y E-16 no aparecen: E-11 y E-16 son E-01, y E-15 es E-05. E-14
(el mapa está desactualizado) es el estado de la §0, no una fila. E-17 (juicio
sobre el prototipo) queda fuera: no es falsable.

## 2. Lo que está resuelto y lo que sigue abierto

### 2.1 Resuelto, con la evidencia que lo sostiene

- **La prueba está atada a la dirección.** `admit` exige `msg.sender == validator`
  y el statement lleva `uint160(validator)` como palabra pública
  (`AVIPValidatorManager.sol:233-249`, `AVIPRegistry.sol:386-394`). `P-01` está
  cerrado; lo que queda es historial, no binding.
- **La custodia se comprueba cuando existe.** Con `custody != address(0)` el
  manager exige escrow y el constructor hace el handshake
  (`AVIPValidatorManager.sol:143-169,266-271`). El fallo posible es *no
  configurarla*, y eso es despliegue.
- **Las autoridades están separadas y sus cambios tienen retardo.**
  `onlySequencer` / `onlyGuardian`, `propose*` / `execute*` / `cancel*` con
  `CHANGE_DELAY` (`AVIPRegistry.sol:151-261`).
- **El juicio de fraude es explícito y tipado.** `adjudicate` devuelve
  `Consistent` / `Fraud` / `Unproven` sobre la ventana declarada
  (`src/datalayer/src/ingestion.rs:251`), y el transporte sólo mueve el veredicto.
- **El relay re-verifica el link en los dos extremos.**
  `AVIPCommitmentRelay` rechaza un link que no sea el que computan sus propias
  palabras y registra un epoch una sola vez (`AVIPCommitmentRelay.sol:29-41,198,231`).
- **La disciplina documental.** Paper, scripts, `claim-registry.csv`, auditoría y
  275 tests Foundry, 53 de reputación y 13 de zk, con salida reproducible: es lo
  que permite que este documento cite líneas en vez de impresiones.

### 2.2 Abierto, con su ticket

| Gap | Estado | Ticket / decisión |
|---|---|---|
| Autenticidad del origen en el registry (`sourceChainId`) | Abierto | **T-2** (inmutable + `revert` por mismatch) |
| Versionado on-chain de `f_c` | Abierto | **T-2** (`activeFormulaDigest`) |
| Vínculo semántico tensor ↔ raíces | Abierto, declarado | `P-38`, `R3-03` opción (c); decisión §5.5.7 |
| Unicidad / persistencia de identidad | Abierto | `P-12`, §11 |
| Custodia obligatoria | Abierto (despliegue) | **T-1** (guard en `deploy_dryrun.sh`) |
| Cota inferior de la norma en el circuito | Abierto, acotado | `P-33`; P0-1 del triaje |
| Frescura del epoch en `verifyThreshold` | Abierto (griefing) | `P-32` |
| Umbral de la autoridad de slash | Decisión | M9a/M9b: hoy una sola `slashAuthority`; el umbral es multisig de despliegue |
| Pausa de emergencia | Fuera de alcance | §11 / M8 |
| Castigo cross-chain sobre la palabra del notificador | Abierto | `P-34` |

## 3. Segunda iteración

### A. Integridad del origen

- `sourceChainId` y `activeFormulaDigest` **inmutables** en el registry, y
  `postCommitment` revierte si no coinciden (T-2).
- `EpochMeta` **off-chain** con digest de dominio separado
  (`keccak("AVIP/epoch-meta/v1" ‖ …)`) en `report.rs` (T-3).
- **No** metadata en el statement y **no** `stateHash` dentro de la prueba: el
  circuito no puede derivarlos de `entries`, y añadirlos sólo cambia la
  ceremonia, la clave y el gas (E-05).

### B. Política de seguridad operativa

- Custodia obligatoria **en el despliegue**, no en el contrato: el caso G–I del
  dry run se amplía con «manager sin custodia» (T-1).
- Identidad: la unicidad por época es del data layer (`P-12`); no se resuelve
  añadiendo una palabra al leaf.
- Slash: el importe completo es el invariante de M9b; un umbral es una decisión
  de gobernanza (multisig), no una constante nueva.
- Pausa: si entra, entra con una ruta de actualización (§11); hoy no hay nada que
  una pausa proteja que no proteja el retardo.

### C. Qué es diseño y qué es código

| Pregunta | Respuesta | Razón |
|---|---|---|
| ¿`sourceChainId` inmutable? | **Sí** | Convierte «publicar roots de otra fuente» en un `revert`; no necesita circuito |
| ¿`formulaDigest` inmutable? | **Sí** | Único modo on-chain de que un cambio de `f_c` no sea silencioso |
| ¿Se fuerza un flujo más fuerte que el bridge off-chain? | **No por ahora** | Sería otra ceremonia; el paper ya declara la confianza acotada por retardo |
| ¿`identityCommitment` en la ruta crítica? | **No** | El leaf ya liga la dirección; no cierra la portabilidad |

## 4. Estrategia

1. No repetir el diagnóstico: E-01 y E-02 ya están en `P-38` y `P-02`, y en el
   paper; repetirlos no añade evidencia.
2. No implementar el parche del mapa: E-05 y E-06 lo rechazan con razones.
3. Cerrar primero lo que no cambia interfaz (P0 del triaje), después T-2/T-1/T-3.
4. Cada fila abierta tiene ID y criterio; ninguna se cierra con un párrafo.

