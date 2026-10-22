# Checklist — validación de la *Matriz de evidencia* (2026-10-22)

Estado: **abierto** — A-1…A-8, B-1…B-3, C-1 y D-1…D-3 aplicadas y verificadas;
sólo queda C-2, que espera un commit. Este documento es el acta de validación:
qué se comprobó, contra qué, qué se corrigió y qué queda pendiente con criterio
de aceptación.

Fuente validada: `docs/audit/Matriz de evidencia_ confirmado _ refutado _
parcial _ ya cubierto.md` (81 líneas, 18 filas E-01…E-18, sin encabezado H1 y
sin sección 1). Se conserva intacta como evidencia de lo recibido.

## 0. Método y estado verificado

- `HEAD` = `ea75594` (`m4d-review`, `v0.2.1-15-gea75594`); el 2026-10-22.
- Foundry: **275 tests, 0 fail, exit 0** (`forge test --summary`).
- Rust: `avip-reputation` **53 passed, 0 failed** (26,18 s). `avip-zk-prover`:
  **9 tests de forma + 4 del bridge, 0 fallos**, ejecutados después de los
  arreglos B-1/B-2 (§6).
- Cada fila se contrastó con el fichero y la línea, no con otro documento. Las
  citas de esta acta son las que hay que corregir si el árbol se mueve.

Criterio de veredicto, el mismo del triaje del mapa
(`triage-mapa-2026-10-22.md` §"Veredictos"):

| Sigla | Significado | Se aplica a |
|---|---|---|
| **C** | confirmado contra el árbol | afirmaciones del mapa/auditoría sobre hechos |
| **P** | parcialmente confirmado | afirmaciones con una mitad cierta y otra no |
| **R** | el mapa se equivoca sobre el árbol | sólo afirmaciones del mapa |
| **S** | ya declarado en paper/plan; no se repara como código | decisiones de alcance |
| **V** | verificado por lectura/ejecución (no es un claim del mapa) | conclusiones de la auditoría |
| **D** | decisión registrada, con razones | propuestas aceptadas o rechazadas |
| **N** | no falsable | valoraciones |

El defecto de método central de la matriz recibida es no distinguir estas tres
cosas: **claim del mapa**, **conclusión de la auditoría** y **decisión**. Siete de
sus dieciocho filas son de las dos últimas y llevan estado `C`/`R`, que sólo
tienen sentido para la primera.

## 1. Veredicto global

La matriz **acierta en el contenido y falla en la forma**. De sus 18 filas:

- **4 conservan el estado** (E-01, E-02, E-03, E-08), con alguna cita que faltaba
  o una condición que precisar.
- **2 conservan `P` y sólo necesitan redacción** (E-12, E-13).
- **10 cambian de estado o de categoría**: E-04 (`R`→`V`), E-05 (`C`→`D`), E-06
  (`R`→`D`), E-07 (`C`→`P`, partida en binding cerrado y unicidad abierta), E-09
  (`C`→`S`), E-10 (`C`→`S`), E-14 (fila→nota de estado), E-15 (`C`→`D`), E-17
  (`C`→`N`, fuera), E-18 (`C`→`D`, lista de gaps).
- **2 son duplicados** (E-11 y E-16 repiten E-01).
- **Le faltan cuatro filas** que el registro sí tiene: la cota inferior de la
  norma (P-33), `latestEpoch` (P-32), la unicidad de identidad (P-12) y el
  castigo cross-chain sobre la palabra del notificador (P-34).

El defecto que explica casi todos los demás es de método: la matriz no distingue
**claim del mapa**, **conclusión de la auditoría** y **decisión**. Diez filas son
de las dos últimas y llevan estado `C`/`R`, que sólo tienen sentido para la
primera. Y su sección 3 se contradice con E-05: pide «metadata in the proof
statement» y «canonical state hash» en la lista de la segunda iteración, mientras
E-05 afirma —correctamente— que publicar campos no prueba propiedades. Esa
contradicción es la que el triaje del mapa resolvió en su §3; la v2 la hereda
resuelta.

## 2. Validación fila por fila

### 2.1 Filas E-01…E-09

| ID | Declarado | Veredicto | Evidencia (HEAD) | Defecto | Acción |
|---|---|---|---|---|---|
| E-01 | C | **C** | `src/zk/src/bridge.rs:20` (link = keccak de tres palabras), `src/zk/tests/m7c_bridge.rs`, `AVIPCommitmentRelay.sol:47-52` («carried, not proven») | Duplica E-11 y E-16 | Mantener; absorber E-11/E-16 |
| E-02 | C | **C** | `src/datalayer/src/ingestion.rs:251` (`adjudicate` sólo existe en Rust); `AVIPRegistry.postCommitment` (`:272`) no recibe cadena de origen | Ninguno; faltaba la cita | Añadir evidencia |
| E-03 | C | **C** | 275 tests Foundry + 53 Rust; ninguna entrada de reentrancy/overflow en el registro | Es una afirmación negativa: se sostiene por revisión, no por un test que la pruebe | Mantener con la nota «revisión, no ejecución» |
| E-04 | R | **V** | `AVIPRegistry.sol:351-356` (4 argumentos) y `:386-394` (4 palabras) | No es un claim del mapa refutado: es una discrepancia que detecta la auditoría. El mapa no afirma «el statement es de tres palabras *y es correcto*»; describe el contrato que leyó | Reclasificar a origen=auditoría, estado=V |
| E-05 | C | **D** | Argumento en `triage-mapa-2026-10-22.md` §3.1; `src/zk/README.md` (un verificador con dos raíces no aprende el link) | Es tesis propia, no hallazgo del mapa; `C` finge corroboración del árbol | Estado D, con enlace al §3.1 |
| E-06 | R | **D** | `P-03` (2026-10-22); `src/zk/src/admission.rs:65` (`STATEMENT_LEN = 4`), `AVIPValidatorManager.sol:78` (`THETA_R`), `:191` (`S_MIN`) | `R` = «el mapa se equivoca sobre el árbol», pero aquí no hay hecho refutable: hay una decisión con tres razones (norma global, constantes, y el desplazamiento de P-38) | Estado D, citar P-03 |
| E-07 | C | **P** | Binding cerrado: `admit` exige `msg.sender == validator` y la hoja es `Poseidon(validator, norm)` (`admission.rs:102`, `AVIPValidatorManager.sol:233-249`). Persistencia/unicidad abierta: `P-12` | Mezcla dos cosas: identidad *atada a la prueba* (resuelta, P-01) y reputación *no transferible entre épocas/identidades* (abierta) | Partir en E-07a (cerrado) y E-07b (abierto) |
| E-08 | C | **C** | `AVIPValidatorManager.sol:143` (constructor con `address(0)`), `:266-271` (`FinancialStakeNotBacked`), `§5.12` | «El path declared, not backed existe» sólo con `custody == address(0)`; con custodia configurada el contrato sí lo comprueba | Precisar la condición |
| E-09 | C | **S** | `AVIPValidatorManager.sol:295-330`: `amount = available`, `_stakes = 0`, eyección; decisión M9b/§12.1.2 | «slash completo por estado cero» y «ceroes el balance» describen mal el hecho: no es un estado cero, es que el importe *es* el registro | Reescribir; estado S (decisión) |

### 2.2 Filas E-10…E-18

| ID | Declarado | Veredicto | Evidencia (HEAD) | Defecto | Acción |
|---|---|---|---|---|---|
| E-10 | C | **S** | No hay `pause` en `AVIPRegistry` ni en `AVIPValidatorManager` (grep vacío); alcance en `§11` y M8 | «No hay fail-closed path» es cierto; llamarlo hallazgo cuando está declarado fuera de alcance es doble contabilidad | Estado S con nota de alcance |
| E-11 | C | **duplicado** | — | Repite E-01: root + proof + state sin tensor | Consolidar en E-01 |
| E-12 | P | **P** | `src/datalayer/src/ingestion.rs:96` (`chain`), `:101` (`parameters_digest`), `:187-191`; y M7d ya propaga: `AVIPCommitmentRelay.sol:198` (`latestEpochOf`) y `propagatedOf` con `sourceChainId` | «No viajan con el registry» es cierto para `postCommitment`, pero omite que el relay M7d sí transporta `sourceChainId` + link + roots; el hueco es que el registry *local* no lo exige | Precisar: registro local vs relay |
| E-13 | P | **P** | `AVIPRegistry.sol:151-165` (`onlySequencer`/`onlyGuardian`), `:174-261` (`propose*`/`execute*` con `CHANGE_DELAY`) | «Tienen delay» es impreciso: el retardo es del cambio de autoridad, no del ejercicio del rol; el multisig es un hecho de despliegue que ningún contrato comprueba | Precisar ambas cosas |
| E-14 | C | **nota** | `HEAD` vs el mapa: todo el §2 del triaje | Es una afirmación sobre el mapa, no sobre el sistema; como fila de matriz contamina el conteo | Mover a §0 (estado) |
| E-15 | C | **D** | `triage-mapa-2026-10-22.md` §3 | Repite E-05 con otro alcance | Fusionar con E-05 como disposición |
| E-16 | C | **duplicado** | `bridge.rs` cabecera; `AVIPCommitmentRelay.sol:47-52` | Repite E-01 y E-11 | Consolidar en E-01 |
| E-17 | C | **N** | — | Valoración («buen prototipo»); no falsable. Se descartó la puntuación 0–10 del mapa (M-17) por el mismo motivo | Sacar de la matriz; si se quiere, va a la conclusión |
| E-18 | C | **D** | Gaps con ticket: `T-1`…`T-4` (triaje §4), `P0` (triaje §5) | «Falta hardening de orígen»: typo y generalidad; una conclusión no es una fila | Convertir en la lista de gaps con sus IDs |

### 2.3 Filas que faltan (y que el registro sí tiene)

| ID | Afirmación | Estado | Evidencia | Por qué importa |
|---|---|---|---|---|
| E-19 | La cota **inferior** de la norma no la cierra el circuito: `verifyThreshold` acepta `certifiedNorm` en `[0, 2^64)` y sólo `admit` exige `≥ THETA_R` | **C** | `AVIPRegistry.sol:373` (`MAX_NORM`), `:363-380`; `AVIPValidatorManager.sol:78,249` | `P-33`: un proof de norma 0 verifica; ninguna ruta de admisión lo acepta. El hueco está acotado, no cerrado |
| E-20 | Se puede verificar contra un epoch anterior al último publicado | **P** | `IAVIPValidatorManager.sol:155-160` (el manager lee `registry.latestEpoch()`), `AVIPRegistry.sol:328` | `P-32`; el mapa lo tenía (su Hazard 4) y la matriz lo perdió |
| E-21 | No hay unicidad de identidad por época: una dirección nueva empieza con historial cero | **C** | `P-12`; la hoja liga `address`, no una identidad persistente | Es la mitad que E-07b no cubre |
| E-22 | El castigo cross-chain se ejecuta sobre la palabra del `NOTIFIER`: no hay fraude on-chain ni ventana de impugnación | **C** | `P-34`; `AVIPMessageCodec.sol` (mensaje §4) y el test M7d que lo declara | El mapa no lo vio y es Alta; el binding a la dirección, en cambio, está cerrado (E-07a / P-01) |

## 3. Defectos de método

- **M-1 — Origen mezclado.** No hay columna «origen» (mapa / auditoría / decisión).
  Sin ella, `C` y `R` se aplican a cosas que no son claims del mapa (E-04, E-05,
  E-06, E-14, E-15, E-17, E-18).
- **M-2 — `R` con dos significados.** En E-04 significa «el mapa describe mal el
  árbol»; en E-06, «la propuesta no vale». Lo segundo es una **decisión** (D), no
  una refutación.
- **M-3 — `C` para una valoración.** E-17 no es verificable; el mismo criterio que
  descartó M-17 obliga a excluirla o marcarla N.
- **M-4 — Duplicados.** E-11 y E-16 son E-01; E-15 es E-05. Tres filas inflan el
  conteo y hacen parecer que hay más hallazgos de los que hay.
- **M-5 — Contradicción interna.** §3.A pide «metadata in the proof statement» y
  «canonical state hash»; E-05 y §4 dicen que publicar no prueba. La v2 sustituye
  esa entrada por lo que sí cierra el hueco: digest con dominio separado fuera
  del statement (T-3) y constantes inmutables en el registry (T-2).
- **M-6 — Forma.** Falta H1, falta la sección 1 (la numeración empieza en 2), la
  tabla no tiene título, y el nombre del fichero usa espacios y guiones bajos
  sueltos, contra la convención `kebab-case` del directorio.

## 4. Huecos de cobertura

La matriz no cubre cuatro cosas que el registro ya tiene y que un lector
externo necesita para no repetir el diagnóstico:

- **P-33 — cota inferior de la norma.** La matriz dice «la identidad no está
  resuelta» y «la norma no se valida», pero no distingue tres cosas: el rango que
  el registry admite (`[0, 2^64)`), el que el circuito puede probar
  (`norm < WAD`), y la cota económica que exige `admit` (`Θ_r = 0.5`). La cota
  superior está cerrada dos veces; la inferior no la pone ninguno de los tres, y
  sólo `admit` la compensa. Merece fila propia (E-19).
- **P-32 — `latestEpoch`.** El mapa lo tenía (Hazard 4) y la matriz lo perdió al
  resumir. El manager lee `registry.latestEpoch()`, así que un proof viejo se
  rechaza en la admisión, pero `verifyThreshold` sigue siendo `view` y acepta
  cualquier epoch con `statementRoot != 0`. La fila E-20 lo separa del resto.
- **P-12 — unicidad.** E-07 mezcla «la prueba está atada a la dirección» (hecho,
  P-01) con «una dirección nueva empieza de cero» (abierto). Son dos propiedades
  distintas y sólo la segunda es un gap.
- **T-1…T-4.** La matriz pide «custody mandatory», «identity binding»,
  «threshold slash authority» y «pause» como lista de deseos, sin decir cuál es
  código, cuál es despliegue y cuál es documento. El triaje del mapa ya los
  convirtió en tickets con criterio de aceptación; la v2 los cita.

## 5. Cabos sueltos documentales detectados al validar

Estos no están en la matriz: aparecieron al comprobar sus citas y son
afirmaciones **falsas en presente** dentro del código, que es peor que una
matriz desactualizada porque el código se lee como fuente de verdad.

| ID | Fichero | Qué dice | Qué es cierto en HEAD | Acción |
|---|---|---|---|---|
| K-5 | `docs/paper/main.tex` vs `verification/anchor_root.sha256` | El ancla sella `37ebdc73…` para `docs/paper/main.tex` | El blob de `ea75594` es `2a3605ee…`: el paper cambió en ese commit **sin re-sellar**. Hasta `fa78fff` los dos coincidían. `bash verification/audit-gate.sh` daba 9 PASS / 2 FAIL (G10, G11) en un worktree limpio de `ea75594` | **Resuelto** en R-13: re-sello (`Root` `5ff84501…`), gate 11/11. Se re-selló, no se revirtió el paper, porque el diff es la corrección `T(i)`/M4d |
| K-1 | `src/zk/src/bridge.rs:4-6` | «The statement `AVIPRegistry.verifyThreshold` builds is `[uint256(root), epoch, certifiedNorm]`» | Construye cuatro palabras: `[statementRoot, epoch, uint160(validator), certifiedNorm]` (`AVIPRegistry.sol:386-394`) | Corregir el comentario (B-1) |
| K-2 | `src/zk/src/groth16.rs:1-3,16-24` y `:60-63` | «`verifyThreshold` is frozen since M3 and builds `[root, epoch, certifiedNorm]` … con `ic.length == 4`» | El contrato cambió en M4d: 4 argumentos, `ic.length == 5`; `STATEMENT_LEN = 3` es la constante **histórica** de M4b | Corregir el comentario y el doc de `STATEMENT_LEN` (B-2); no tocar el valor, que el test de forma fija |
| K-3 | `src/zk/src/m4b_fixture.rs:250` y `M4bGroth16Fixtures.sol:147` | «the statement the registry builds» | Es el statement **global** que el registry construía en M4b; el fixture se conserva sólo porque M7c lee `TENSOR_DIGEST` y `STATEMENT_ROOT` | No tocar: ya está acotado en `integrations/avalanche/test/README.md:19` («retired as an admission artifact»). Regenerarlo para corregir un comentario rompería el pin byte a byte de `m4b_fixture.sh` |
| K-4 | nombre del fichero de la matriz | `Matriz de evidencia_ confirmado _ refutado _ parcial _ ya cubierto.md` | Convención del directorio: `kebab-case` (`triage-…`, `audit-…`, `handoff.md`) | La v2 se llama `matriz-evidencia-2026-10-22.md`; la fuente se conserva |

## 6. Checklist accionable

### A. Matriz (aplicado en `matriz-evidencia-2026-10-22.md`)

- [x] **A-1** Crear la v2 con nombre `kebab-case` y H1, sin destruir la fuente.
      *Criterio:* existe `docs/audit/matriz-evidencia-2026-10-22.md` y la fuente
      sigue intacta.
- [x] **A-2** Numerar las secciones desde 1 y titular la tabla.
      *Criterio:* §1 es la tabla; §2 resuelto/abierto; §3 segunda iteración; §4
      estrategia.
- [x] **A-3** Añadir columna **Origen** (mapa / auditoría / decisión) y ampliar la
      leyenda con V, D y N. *Criterio:* ninguna fila de origen≠mapa usa C/P/R/S.
- [x] **A-4** Consolidar E-11 y E-16 en E-01, y E-15 en E-05.
      *Criterio:* sin E-11/E-15/E-16 y sin afirmación repetida.
- [x] **A-5** Reclasificar E-04 (→V), E-06 (→D), E-09/E-10 (→S), E-17 (→N, fuera),
      E-18 (→D, lista de gaps). *Criterio:* cada fila tiene un estado que su
      origen permite.
- [x] **A-6** Añadir E-19…E-22 (P-33, P-32, P-12 y P-34); el cierre de P-01
      entra como E-07a, porque es la mitad resuelta de E-07.
- [x] **A-7** Corregir redacciones E-07, E-08, E-09, E-12, E-13 y el typo
      «orígen». *Criterio:* cada fila dice el hecho, no la impresión.
- [x] **A-8** Reescribir §3.A: fuera «metadata in the proof statement» y
      «canonical state hash»; dentro T-2 (inmutables) y T-3 (digest fuera del
      statement). *Criterio:* §3 no contradice E-05.

### B. Documentación del código

- [x] **B-1** `bridge.rs`: el statement de hoy son cuatro palabras; el link sigue
      siendo de tres (merkleRoot, statementRoot, epoch). *Criterio:* el comentario
      nombra `AVIPRegistry.sol` y la fecha de M4d.
- [x] **B-2** `groth16.rs`: marcar `verifyThreshold` como histórico de M4b y
      `STATEMENT_LEN` como la longitud de M4b, no la del contrato actual.
      *Criterio:* `cargo test -p avip-zk-prover --test groth16_statement_shape`
      sigue verde (el valor no cambia).
- [x] **B-3** Nota del fixture histórico: **ya existía** en
      `integrations/avalanche/test/README.md:19` («retired as an admission
      artifact by M4d»). No se toca el `.sol` ni se regenera. *Criterio
      cumplido:* la frase «the statement the registry builds» queda acotada a
      M4b por el README sin romper el pin.

### C. Registro

- [x] **C-1** Enlazar esta acta y la v2 desde `triage-mapa-2026-10-22.md` (§5,
      fila P0-4). *Criterio:* enlace bidireccional entre los tres documentos.
- [x] **C-2** Fila S-016 en `SESSIONS.md` con `Commit = «este commit»` (la misma
      convención que S-012) y `Root = adfd08d2…`, derivado **antes** del commit
      porque `sha256sum verification/anchor_root.sha256` no depende del hash.
      *Por qué no un hash:* un commit no puede citar su propio SHA sin dejar de
      ser el mismo commit; `git show <commit>:verification/anchor_root.sha256 |
      sha256sum` sobre el commit de la fila re-deriva el mismo valor en S-014,
      S-015 y S-016, que es lo que hace verificable la trazabilidad.

### D. Verificación de cierre

- [x] **D-1** `cargo test --offline --test groth16_statement_shape` y `--test
      m7c_bridge` en verde tras B-1/B-2: **9 + 4 passed, 0 failed, exit 0**
      (`/tmp/zk_tests_after_docs.log`).
- [x] **D-2** `forge test --summary`: **275 `[PASS]`, 0 `[FAIL]`, exit 0**
      (`/tmp/forge_after_docs.log`).
- [x] **D-3** `git status --short`: dos modificados (`bridge.rs`, `groth16.rs`,
      **0 líneas de código**, sólo `//!`), y cinco sin seguimiento (el mapa, la
      fuente, el acta, la v2 y el triaje). `docs/paper/` y `verification/` sin
      tocar.

## 7. Lo que no se toca, y por qué

- `docs/paper/` y `verification/`: sellados por `anchor_root.sha256`; la matriz
  es un documento de auditoría y no puede mover el sello.
- El fixture `M4bGroth16Fixtures.sol`: es un artefacto congelado y reproducible
  byte a byte; su comentario histórico se documenta, no se regenera (K-3).
- Los valores `STATEMENT_LEN = 3` (M4b) y `= 4` (M4d): los fija un test; sólo se
  corrige su documentación.

## 8. Reproducción

```sh
cd /home/ilich/Escritorio/diamond-framework
git log --oneline -1

# Forma del statement: 4 palabras en el contrato, 4 en admission.rs
grep -n 'function verifyThreshold' -A 6 integrations/avalanche/contracts/AVIPRegistry.sol
grep -n 'uint256\[\] memory statement' -A 6 integrations/avalanche/contracts/AVIPRegistry.sol
grep -n 'STATEMENT_LEN' src/zk/src/admission.rs src/zk/src/groth16.rs

# Norma: encoding vs umbral económico
grep -n 'MAX_NORM\|NormOutOfDomain' integrations/avalanche/contracts/AVIPRegistry.sol
grep -n 'THETA_R\|S_MIN' integrations/avalanche/contracts/AVIPValidatorManager.sol

# Custodia, slash y ausencia de pausa
grep -n 'FinancialStakeNotBacked\|CustodyNotBound' integrations/avalanche/contracts/AVIPValidatorManager.sol
grep -rn 'pause' integrations/avalanche/contracts || echo 'no pause'

# Origen: adjudicate es off-chain; el relay M7d es quien propaga
grep -rn 'fn adjudicate' src/datalayer/src
grep -n 'latestEpochOf\|propagatedOf' integrations/avalanche/contracts/AVIPCommitmentRelay.sol

# Tests
cd integrations/avalanche && forge test --summary
cd ../../src/zk && cargo test --offline --test groth16_statement_shape
```
