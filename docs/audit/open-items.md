# Open Items — registro único (N0)

## Qué es este fichero

Un índice de trabajo, no un documento de hallazgos. Cada fila apunta al texto
normativo que ya existe en otro sitio y añade lo único que faltaba: **con qué ID
se nombra y a qué carril está asignada**. La descripción, la severidad y el
estado viven en la fuente; si esta tabla y la fuente discrepan, manda la fuente.

Existe porque el plan de dos carriles —uno reservado y bloqueado, otro libre—
necesita que un ID signifique una sola cosa en los dos. No la significaba: hay
cuatro series `D`, dos `A-8`, dos `A-10` y dos `B-1…B-3` (§3). Con esos IDs,
«cerrar A-8» no identifica trabajo.

**No está en el ancla**, igual que `triage-external-review-2026-10-25.md` y
`anchor-receipts.md`: es estado de trabajo y se reescribe cuando cambia una
asignación. Un fichero de estado sellado obligaría a re-sellar el depósito por
cada fila nueva.

Estado verificado contra `9115ef5` (2026-10-27); §3.7 se actualizó el 2026-10-28
al cerrar `R5-1`/`R5-2` y §5 al abrir el registro de erratas del paper, sin
re-verificar el resto. Los conteos de §2 son medidas, no cifras tecleadas: el
comando que los re-deriva va en la última columna.

## 1. Regla de nombrado

Un ID sin cualificar sólo es válido **dentro de su fichero**. Al cruzar
ficheros, se cualifica:

| Prefijo | Fuente |
|---|---|
| `P-` | `docs/audit/audit-2026-10-20-in-progress.md` |
| `R3-` | `docs/audit/triage-external-review-2026-10.md` (ronda 3) |
| `R4-` | `docs/audit/triage-external-review-2026-10-25.md` (ronda 4) |
| `PC-` | `docs/audit/post-closure-audit.md` |
| `IMP-` | `docs/architecture/implementation-plan.md` (decisiones de diseño) |
| `MPA-` | `docs/audit/triage-mapa-2026-10-22.md` (serie `M-`) |
| `R5-` | ronda 5: hallazgos de la revisión del 2026-10-27, definidos en §3.7 y desarrollados en `docs/architecture/p12-freshness-binding.md` |

Así `R3-A-8` (baseline de succinctness) deja de confundirse con `PC-A-8` (tabla
de runtimes del README), y `IMP-D-3` (layout de Foundry) con el `D-7` del paper.

## 2. Series y conteos

| Serie | Fuente | Rango | Filas | Numeración | Re-derivar |
|---|---|---|---|---|---|
| `P-` | `audit-2026-10-20-in-progress.md:45` | `P-01`…`P-40` | 40 | **congelada** | `grep -oE '^\| P-[0-9]+' docs/audit/audit-2026-10-20-in-progress.md \| sort -u \| wc -l` |
| `P-` disposición | `audit-2026-10-20-in-progress.md:3246` | `P-27`…`P-37` | 11 | misma numeración | `sed -n '3246,$p' docs/audit/audit-2026-10-20-in-progress.md \| grep -cE '^\| P-[0-9]+'` |
| `B-` | `triage-external-review-2026-10.md:677` | `B-1`…`B-7` | 7 | congelada; se amplía en §3.5 | `grep -cE '^\| B-[0-9]+ \|' docs/audit/triage-external-review-2026-10.md` |
| `A-` | `triage-external-review-2026-10.md:153-158, 530-660` | `A-1`…`A-22`, 4 con sufijo | 25 | congelada; mapa en `:805-821` | `grep -oE 'A-[0-9]+(-bis\|[ab])?' docs/audit/triage-external-review-2026-10.md \| sort -uV \| wc -l` |
| `C-` | `content-audit-pending.md` | `### C-` | 50 | congelada (`C-log`) | `grep -c '^### C-'` |
| `IMP-D-` | `implementation-plan.md:2874-2880` | `D-1`…`D-7` | 7 | congelada | `grep -cE '^\| D-[1-7] '` |
| `R3-D-` | `triage-external-review-2026-10.md:728-754` (viñetas, no tabla) | `D-1`…`D-4` | 4 | congelada | `grep -cE '^- \*\*D-[0-9]' docs/audit/triage-external-review-2026-10.md` |
| `R4-D` | `triage-external-review-2026-10-25.md:141-151` | `D1`…`D11` | 11 | congelada | `grep -cE '^\| D[0-9]+ \|'` |
| «D-7 del paper» | `docs/paper/main.tex` §6 | — | 1 | se cita con nombre, no con número | — |
| `MPA-M-` | `triage-mapa-2026-10-22.md:61` | `M-01`… | 18 | **local**: no cruza de carril | `grep -cE '^\| M-[0-9]+'` |
| `V-` | — | — | 0 | **no existe** (§3.5) | `grep -rn 'V-8' docs/ --exclude=open-items.md` → 0 |
| `R5-` | aquí §3.7 (no tienen otro hogar todavía) | `R5-1`, `R5-2` | 2 | nueva; **cerrada** 2026-10-28 | `grep -cE '^\| .R5-[0-9]. ' docs/audit/open-items.md` |

`P-` tiene 51 filas y 40 IDs: las 11 de más son la tabla de disposición de
`:3246`, indexada por los mismos IDs. No es una colisión. Igual con `A-`: son 25
tokens y no 26 porque `A-16` sólo existe como `A-16a` y `A-16b`.

## 3. Colisiones y resolución

### 3.1 Cuatro series `D`

`D-3` no es «recursión»: es el layout de Foundry, ya decidido (*Keep current*,
`IMP-D-3`). La recursión es `R3-A-10`. Y `R4-D10` es ACP-77, no una decisión de
diseño. Resolución: `IMP-`, `R3-`, `R4-` obligatorios al cruzar; `D-` a secas
sólo dentro del fichero que lo define.

### 3.2 `A-8` (dos ítems distintos)

| ID cualificado | Qué es | Dónde |
|---|---|---|
| `R3-A-8` | baseline de succinctness; el vuelco de §4.5 si baja de ~206k | `triage-external-review-2026-10.md:597` |
| `PC-A-8` | tabla de runtimes del README sin procedencia y con deriva | `post-closure-audit.md:153` |

### 3.3 `A-10` (dos ítems distintos)

| ID cualificado | Qué es | Dónde |
|---|---|---|
| `R3-A-10` | recursión: Bulletproofs sobre BN254 no nativo | `triage-external-review-2026-10.md:538` |
| `PC-A-10` | el log de evidencia apuntaba a un directorio no versionado | `post-closure-audit.md:189` |

Dentro de la ronda 3, `A-11` y «A-10 (wording)» se funden en `A-10` por decisión
del propio documento (`:811-812`, «confirmed (same item)»). Eso no es colisión:
es el mapa de renumeración que este fichero toma como precedente (§5).

### 3.4 `B-1…B-3` (dos usos)

| ID cualificado | Qué es | Dónde |
|---|---|---|
| `B-1` | `bindManager` pasa al constructor | `triage-external-review-2026-10.md:677` |
| `B-2` | escribir `DeployFujiPhase1.s.sol` | idem `:678` |
| `B-3` | escribir `DeployBurnSink.s.sol` | idem `:679` |
| `PC-B-1…B-3` | sondas de mutación del gate (registro reducido, log movido, par borrado) | `post-closure-audit.md:206-208` |

### 3.5 IDs nuevos, y `V-8`

`V-8` no existe en el repo (`grep -rn 'V-8' docs/ --exclude=open-items.md` → 0;
sin el `--exclude`, este mismo fichero lo cuenta). Es un ID externo, y el
plan lo usaba para dos cosas distintas: extender el gate y anotar `SafeFork`.
Resolución: los dos son acciones de trabajo, así que entran en la serie `B-` por
el final, y este fichero los define:

| ID nuevo | Qué es | Carril |
|---|---|---|
| `B-8` | extender el gate (lo que el plan llamaba `V-8`) | `R4`, re-seal-gated |
| `B-9` | `SafeForkTest` se salta por diseño sin `FUJI_RPC_URL`: omisión explícita en docs | `L5` |
| `B-10` | getter de `MAX_NORM` (el límite está fijado por test, no legible on-chain) | `R4` |

`B-8`…`B-10` no están en la tabla de `:677`; se pliegan en la próxima revisión
del triaje, que es donde vive la serie `B-`.

### 3.6 `P-27`…`P-37` no se renumeran

La tabla de `:3246` ya define, para esos 11 IDs, **disposición, cambio mínimo y
criterio de cierre**. Los carriles no inventan criterios: importan esos. Si un
carril cierra un `P-27`…`P-37` sin cumplir la columna «Cierre verificable», no lo
ha cerrado.

### 3.7 `R5-`: dos divergencias de convención, medidas y cerradas

Ninguna de las dos rompía un despliegue, y por eso importaban: las dos fallaban
cerrado y ninguna suite las podía ver, porque cada lado se comparaba consigo mismo.
Las dos estaban **fuera de la solicitud** (descubiertas después del envío) y por eso
son carril libre, no reservado.

| ID | Qué era | Carril | Estado |
|---|---|---|---|
| `R5-1` | el fondo del árbol keccak no coincidía: `AVIPRegistry.verifyEntry:410` empieza en `keccak256(abi.encodePacked(leaf))` y `commitment.rs:98-112` plegaba `Entry::leaf()` sin ese hash. Medido con el fixture del propio repo (`keccak256_vectors.txt`): `verifyEntry` **rechazaba** la raíz y la prueba del data layer y **aceptaba** su propio árbol para las mismas cuatro entradas. `commitment.rs:114-116` afirmaba lo contrario | libre (`L5`), descubierto tras el envío | **cerrado 2026-10-28**: gana el contrato — el data layer adopta `bottom_node` = `keccak256(Entry::leaf())`, `root(4)` pasa a `0x6d7dbeea…` (el valor que el contrato ya calculaba) y el comentario dice lo que el código hace. Vector cruzado real en `integrations/avalanche/test/DatalayerInclusion.t.sol`, emitido desde Rust por `src/zk/scripts/merkle_fixture.sh` |
| `R5-2` | el fixture `AVIPRegistry.t.sol:1043-1050` duplicaba y hasheaba el nodo impar, mientras la regla especificada (`implementation-plan.md:2033,2065`) y `commitment.rs` lo promocionan sin hashear. Para `N = 500` el nivel 125 es impar: dos raíces distintas para las mismas 500 hojas | libre (`L5`), descubierto tras el envío | **cerrado 2026-10-28**: era un bug del helper de test, no del contrato. `_buildTree` promociona; el tensor del data layer (`TENSOR_ROOT`) es ahora la aserción que falla si vuelve la duplicación |

Por qué gana el contrato: ya está desplegado, y cambiarlo es bytecode y redespliegue;
cambiar Rust cuesta menos y no toca nada de lo que congela la ceremonia. La decisión
no era del memo de `L1`; la tomó el owner el 2026-10-28 y por eso `R5-1` deja de ser
precondición pendiente de la opción (b) de `P-12` — sigue siendo precondición, pero
ya está cumplida. La medición y el razonamiento están en
`docs/architecture/p12-freshness-binding.md` §7, y las dos están validadas por
mutación: revertir cualquiera de los dos arreglos hace fallar un test.

## 4. Los 52 ítems accionables y su carril

Carriles: `G` financiado por la propuesta de $50k (`G1`…`G5` en
`team1-reserved-work.md`, gobernado por `RESEARCH_PROPOSAL_STATUS`), `T1-M1`…`T1-M4`
reservado y bloqueado por el mini grant de Team1 (`GRANT_STATUS`), `L0`…`L7` carril
libre, `—` sin carril. Las etiquetas `R1`…`R4` están retiradas: la solicitud enviada
las sustituyó por los cuatro hitos, y el mapa es `R1`→`T1-M1`, `R2`→`T1-M2`,
`R3`→`T1-M3`, `R4`→`T1-M4`.

`—` es una respuesta, no un olvido: 30 de los 52 no están asignados, y asignarlos
«porque sí» es lo que produjo la lista de 15 que no coincidía con lo financiado.
Se re-deriva con
`sed -n '/^## 4\./,/^## 5\./p' docs/audit/open-items.md | grep -cE '^\| (P-|B-|R5-)'`
para el total (52) y el mismo rango con `grep -E '^\| (P-|B-|R5-)' | grep -cE '\| — \|$'`
para los no asignados (30; `R5-1` contaba como `—` y pasó a `L5` al cerrarse el
2026-10-28).

| ID | Resumen (paráfrasis; el texto manda) | Carril |
|---|---|---|
| P-01 | la prueba de admisión es global, no está atada al validador | — |
| P-02 | `f_c` no ata el score a un validador ni a la procedencia de eventos | — |
| P-03 | tres semánticas incompatibles de `T` (paper, data layer, bridge) | — |
| P-04 | `certifiedNorm` del prover limitado a `< 2^64` (18.4467 WAD) | — |
| P-05 | `bindManager` del vault es una carrera de despliegue | `T1-M1` |
| P-06 | el fee por época no se enforcea on-chain | — |
| P-07 | paper/plan/README afirman un binding que el código no tiene | — |
| P-08 | `Groth16Verifier` acepta una clave degenerada | `T1-M1` |
| P-09 | con token de 0 decimales, `debit` redondea el slash a 0 | `T1-M1` |
| P-10 | el guardian puede proponerse a sí mismo como sequencer | — |
| P-11 | `requiredStake` queda obsoleto tras una eyección | — |
| P-12 | la freshness `γN` sólo se comprueba sobre el delta declarado | `L1`+`T1-M2` |
| P-13 | el verifier acepta `certifiedNorm + r` (input no canónico) | — |
| P-14 | `AVIPSlashingChannel` descarta `epoch`, `ingestionDigest` y los WAD | — |
| P-15 | `AVIPBurnSink.receiveFunds` es permissionless | — |
| P-16 | un solo `_roots[epoch]` no puede ser a la vez raíz de V3 y de la capa | — |
| P-17 | la admisión se evalúa una vez: sin recertificación ni reprecio | `T1-M2` |
| P-18 | el bounty `B` no tiene ruta de pago | `T1-M2` |
| P-19 | el agregador Frobenius permite pasar `Θ_r` con una sola celda | — |
| P-20 | §2.4: los momentos tabulados son el límite `λ = 0` | `T1-M4` |
| P-21 | §7.5: `γ` acota entradas cambiadas, no la duración del fraude | `L1` |
| P-22 | §2.5: `π(r)` se despeja de la `C_R` elegida (consistencia circular) | — |
| P-23 | §8: el bootstrap usa otro `C_R` que el mapeo de §2 | — |
| P-24 | `F0* = 0.05` se calcula en `T = 0`, fuera del dominio admisible | — |
| P-25 | erratas y sobreafirmaciones menores | — |
| P-26 | los guards de despliegue no son fail-closed fuera del runbook | `T1-M1` |
| P-27 | el detector de colusión no está conectado al estado de reputación | — |
| P-28 | el «piso financiero» `0.2Θ` se presenta como garantía de seguridad | — |
| P-29 | el README promete una confianza mínima que v1 no tiene | — |
| P-30 | `π_val`, `ω` y `k` no tienen unidad temporal | — |
| P-31 | la premisa PoW de la introducción no tiene cita | — |
| P-32 | `admit` usa siempre `latestEpoch()` e invalida proofs en vuelo | `T1-M1` |
| P-33 | el circuito no impone `T ∈ [0,1]` (`ENTRY_BITS = 60`) | — |
| P-34 | el slash cross-chain se ejecuta sobre la palabra del `NOTIFIER` | `L5` |
| P-35 | la frontera de detección no es Kesten–Stigum y sólo se probó a 10× | `L2`+`L3` |
| P-36 | bibliografía: Bauer–Jost mal citado (CPAM 2012 → CAG 2013) | `T1-M4` |
| P-37 | la permutación Poseidon usa `state[1]` (rate 2) | — |
| P-38 | la prueba de admisión publica el statement completo: sin ZK | — |
| P-39 | el `slashAuthority` de Fuji es una EOA y el rol es inmutable | — |
| P-40 | el despliegue de Fuji es anterior a M-15 (`sourceChainId()`) | — |
| B-1 | `bindManager` → dirección en el constructor | `T1-M1` |
| B-2 | escribir `DeployFujiPhase1.s.sol` | — |
| B-3 | escribir `DeployBurnSink.s.sol` | — |
| B-4 | cola de salida / retardo de retirada | `T1-M2` |
| B-5 | comparar `token.decimals()` en el script de despliegue | `T1-M1` |
| B-6 | slash de liveness con token pausable/blacklisted | — |
| B-7 | el docstring de `DeployCommon` llama «public, valueless» a anvil | `T1-M1` |
| B-8 | extender el gate (antes `V-8`) | `T1-M4` |
| B-9 | `SafeForkTest` se salta sin `FUJI_RPC_URL`: documentar la omisión | `L5` |
| B-10 | getter de `MAX_NORM` | `T1-M4` |
| R5-1 | el fondo del árbol keccak no coincidía entre contrato y data layer (`§3.7`) | `L5` — libre, cerrado 2026-10-28 |
| R5-2 | el fixture duplicaba el nodo impar en vez de promocionarlo (`§3.7`) | `L5` — libre, cerrado 2026-10-28 |

Notas que no caben en una celda:

1. **P-08 es precondición de `G3`.** Una ceremonia que instale un verifier nuevo
   sin cerrar P-08 instala la misma aceptación de clave degenerada. El orden no
   es preferencia: `T1-M1(P-08)` → decisión de `P-12` → circuito congelado → `G3`.
2. **P-12 tiene dos trabajos**: el memo de opciones (`L1`, sin tocar código) y la
   implementación de la opción elegida (`T1-M2`). `L1` cierra con una recomendación,
   no con un cambio.
3. **P-21 es el gemelo de paper de P-12** y estaba huérfano. Va en `L1` junto al
   memo, porque un memo que no dice qué se puede seguir afirmando en §7.5 no ha
   terminado.
4. **`L2` depende de `T1-M4`.** Sustituir el `[CONJECTURE]` de `main.tex:796` exige
   citar el resultado de BBP, y la bibliografía es `P-36` = `T1-M4`. Un carril libre
   que se bloquea a sí mismo no es libre: se declara bloqueado.
5. **`L2` no es `θ_r`.** El `[CONJECTURE]` es la frontera de detección (§7,
   `P-35`); `Θ_r` (`main.tex:471`) es el umbral de norma para admisión. Son dos
   símbolos distintos y el argumento de uno no sustituye al otro.
6. **`B-8` y `B-10` no son «libres» por ser pequeños**: tocan el gate y el
   contrato, así que son re-seal-gated tanto como los ítems grandes.
7. **`R5-1` era precondición de la opción (b) de `P-12`, y ya está cumplida.**
   Sin unificar el fondo del árbol, cualquier prueba de inclusión on-chain rechazaba
   la prueba honesta, y la remediación 1 del audit es exactamente esa prueba. Gana la
   regla del contrato (`keccak256(leaf)` en el fondo) porque el contrato está
   desplegado; `R5-2` se arregló en el mismo movimiento, en el helper de test, y el
   tensor del data layer es ahora su vector cruzado. Queda como precondición
   *cumplida*, no como pendiente: la opción (b) sigue necesitando ventana, bond y
   ruta de pago (`P-18`).
8. **El carril reservado se nombra por el hito que lo paga** (`T1-M1`…`T1-M4`),
   no por un ordinal interno: un carril sin pagador no se puede auditar, y las
   etiquetas `R1`…`R4` de la primera versión sobrevivieron justo hasta que se
   envió la solicitud.

## 5. Cómo se actualiza

- Una fila por ítem. Sin columna de estado: el estado vive en la fuente y aquí se
  duplicaría con deriva.
- Un ID nuevo se toma del final de su serie; no se reutiliza un número libre.
- Renumerar exige dos cosas: fila en §3 y mapa viejo→nuevo, como `:805-821`.
- Un carril vacío (`—`) no se rellena sin decidir antes si el ítem lo paga `G` o
  el trabajo propio. La lista de 15 ítems «reservados» que no coincidía con lo
  financiado es el motivo de que esta columna exista.
- Este fichero no se sella. Si algún día se sella, cada reasignación de carril
  pedirá re-sellar el depósito, y el registro dejará de actualizarse.
- Las correcciones de `docs/paper/main.tex` que esperan a v0.2.3 **no** son ítems
  de este registro: viven en `docs/paper/releases/v0.2.3-errata.md`, cada una con
  su medida. La primera es `E-01` (2026-10-28): el paper llama «desplegada» a la
  cifra de gas de V3 (286,144) cuando la clave instalada es la de M4d (306,253 en
  frío, medido el 2026-10-28), y una clave de tres inputs ya no puede instalarse
  (`PublicInputsMismatch(3, 4)`). Aplicarla es editar `main.tex` y re-sellar; desde
  el 2026-10-28 eso es **carril libre y autofinanciado**, no reservado: v0.2.3 sale
  con o sin la mini beca, y `T1-M4` conserva sólo `P-20` y `P-36`
  (`team1-reserved-work.md` §6, decisión 6). **Aplicada en `wip/v0.2.3` el
  2026-10-29** (sello `R-17`, PDF `diamond-framework-2026-10-29.pdf`, checklist de
  depósito preparado): la rama no está fusionada y el depósito no está hecho, así
  que lo que sigue abierto es la decisión del owner, no el trabajo. `R-18`
  (2026-10-30) cerró el hueco que `E-01` dejaba: cada cifra de gas lleva ahora su
  clave, la fecha (`2026-10-20`) y el commit (`70f225c`) de la medición, más el
  `PublicInputsMismatch(3, 4)` que hace ininstalable la clave de V3, sin mover
  ninguna cifra (root `6fe5884b…`, PDF de 601340 B). `main.tex` y
  `claim-registry.csv` quedan **congelados** en ese sello: tocarlos pide otro root.
