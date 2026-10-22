# Run log — 2026-10-20

Bitácora técnica de la sesión que produjo el worksheet
`docs/audit/audit-2026-10-20-in-progress.md`. No es un informe formal ni un
documento anclado. Los números se re-derivan con los comandos y scripts citados;
las fuentes originales de los POCs se perdieron y se marcan como tales.

## 0. Punto de partida

- HEAD: `70f225cbb364eba0a04b011a54a0483f55f51b5c`.
- `git status --short`: sólo el worksheet sin trackear.
- El ancla y el manifiesto estaban verdes al inicio y al final.
- Hipótesis de trabajo: los dos informes externos habían confirmado con
  ejecución lo que la lectura de código ya sugería; faltaba reconciliar
  severidades y afirmaciones del paper.

## 1. Fuji on-chain: P-05

Lecturas sin transacciones, contra el despliegue de fase 1:

| Lectura | Resultado |
|---|---|
| `vault.manager()` | `0x7C92D08B3d945424154743Adf1D7b1965B88b100` |
| `manager.custody()` | `0xAE41076223b5b9EB0E811B0751D806B092DaA5E4` (el vault) |
| `totalEscrowedUnits` | `0` |
| `totalDeposited` | `0` |
| `heldUnits` | `0` |
| Bloque del vault | `59.670.734` |
| Bloque del manager / `ManagerBound` | `59.670.735` |

**Acierto:** el despliegue de Fuji está bien enlazado y no tuvo fondos.
**Fallo latente:** existió una ventana de un bloque entre el vault y el manager.
El patrón de `bindManager` sigue siendo una carrera para un despliegue futuro;
no se cierra con “un solo script” si las transacciones no son atómicas.

## 2. P-01: de mock a proof real

### 2.1 Primera PoC (perdida)

`TmpGlobalProofReuse.t.sol` usó dos direcciones y el mismo proof contra el
registry. Pasó, pero el verificador era el mock: demostraba la ausencia de
estado por validador, no que el Groth16 real aceptara la misma prueba.

### 2.2 PoC con Groth16 real (perdida; reconstruida)

`TmpP01Real.t.sol`, 4 tests:

- el mismo proof real de `M4bGroth16Fixtures` admite a Alice y a Bob;
- `requiredStake(alice) == requiredStake(bob)`;
- la prueba está atada a `[root, epoch, certifiedNorm]`, no al validador;
- el manager real ejecuta `admit` sin custody.

Resultado: **4 passed, 0 failed**.

Gas observado en ese harness:

| Ruta | Gas |
|---|---:|
| `Groth16Verifier.verify` (caliente) | 223.403 |
| llamada externa alrededor de `verify` | 217.453 |
| `AVIPRegistry.verifyThreshold` (caliente) | 233.104 |
| `AVIPRegistry.verifyThreshold` (frío) | 286.144 |
| `AVIPValidatorManager.admit` | 376.588 |

**Conclusión:** P-01 no es un artefacto del mock. El verificador es `view` y
stateless; el statement sólo contiene tres elementos y ninguno identifica al
validador. La misma prueba sirve para cualquier dirección, y el manager sólo
impide reutilizarla para la **misma** dirección con `isAdmitted`.

**Error de proceso:** el fichero se borró al final de la sesión. Su fuente
original ya no existe. La versión de `pocs/reconstructed/TmpP01Real.t.sol` es
una reescritura, no el original.

## 3. P-16 + P-01: un solo rediseño

La lectura de `AVIPRegistry` mostró que `_roots[epoch]` es un único `bytes32`:
no puede ser a la vez la raíz Poseidon que usa el circuito V3 y la raíz keccak
que usa `verifyEntry`. Un proof V3 contra `MERKLE_ROOT` da `false`; contra
`STATEMENT_ROOT` da `true`, pero esa raíz no es la raíz keccak de las hojas.

Decisión de diseño: **no parchear P-16 y P-01 por separado**. El statement debe
pasar a `[root, epoch, validator, certifiedNorm]` con un compromiso por
validador, una sola raíz canónica on-chain y `validator` constreñido dentro del
circuito. La checklist completa está en el worksheet; el punto crítico es que
añadir un public input sin constreñirlo no arregla nada.

Métricas que el rediseño invalida: 94.438 constraints, 3,9 s de proving, 128 B
de proof, la tabla de gas, la Tabla 4.2, las filas del README, los fixtures, el
ratio, el break-even y el ancla/OTS que cubre `main.tex`.

## 4. P-25: gas y cifras derivadas

El paper usa **206k** como gas de verificación. Esa cifra corresponde a la clave
inline, no a la ruta desplegada:

- `Groth16Verifier.verify` caliente: **223.403**;
- `verifyThreshold` caliente: **233.104**;
- `verifyThreshold` frío: **286.144**;
- medición anterior fría: **290.854** (mismo camino, distinto harness).

Con `R = 684.064` y `N = 0,2236 ETH`:

| G (gas) | g* (gwei) | R/G |
|---:|---:|---:|
| 206.000 | 1.085 | 3,32× |
| 223.403 | 1.001 | 3,06× |
| 286.144 | 781 | 2,39× |
| 290.854 | 769 | 2,35× |
| 376.588 (admit completo) | 594 | 1,82× |

**Acierto:** el “3,3×” se reproduce exactamente con 206k.
**Fallo:** presentarlo como el ratio de la ruta desplegada. Con la ruta fría real
es ≈2,4× y el break-even cae de 1.085 a ≈769–781 gwei.
**Matiz:** 455.430 / 286.144 ≈ 1,59× mezcla ingest optimizado con verificación
sin optimizar; no es una comparación homogénea. **Decisión posterior (ver §12):**
el paper usa `G = 286.144` para sólo verificación; si usa `manager.admit`,
`g*` baja a ≈594 gwei y ambos lados deben cubrir la admisión completa.

## 5. P-23: el 22,4 %

La revisión externa señaló que el 22,4 % de §8 no cuadraba. La comprobación
mostró que **sí es correcto bajo `C̃_R = 0.8R/(1+R)`**: con `R ≈ 0,3936`,
`0,8·0,3936/1,3936 ≈ 22,6 %`, en la misma familia que el 22,4 % reportado; bajo
el mapeo de §2 sería `0,8·0,3936 = 31,49 %`. No era un error aritmético. El
problema es de presentación: el paper lo llama “el protocolo” sin decir que usa
`C̃_R`. Se mantiene como Media sólo por esa ambigüedad.

## 6. Zenodo

No se debe depositar v0.2.1 tal cual. §6.2 y la fila “Non-transferable” del
README afirman un binding al validador que P-01 desmiente, y un DOI es
permanente. Decisión: corregir y publicar v0.2.2 después de P-01/P-16, o añadir
una errata visible al Release si v0.2.1 ya está depositado.

## 7. Validación de cierre

- `forge test --offline` → **262 passed, 0 failed, 0 skipped**.
- `cargo test --offline -q`: datalayer 39, reputation 53, rmt 36 (+1 ignored),
  zk 42 (+1 ignored).
- `bash verification/audit-gate.sh` → **PASS=11 FAIL=0 SKIP=0**.
- `bash verification/fase0_anchor.sh --check` → **exit 0**, ancla byte a byte.
- `git status --short` al cierre de la sesión anterior → sólo el worksheet sin
  trackear. Ahora también aparece `docs/audit/evidence/` (esta carpeta), que no
  está anclada ni commiteada.

## 8. Fallos, correcciones y lecciones

1. **Se borraron los POCs.** Fue el error que motivó esta carpeta. No hay copia
   recuperable; la regla nueva es escribir primero en `docs/audit/evidence/`.
2. **Se mezclaron configuraciones de gas.** 206k (inline), 223k (storage,
   caliente) y 286k/291k (frío) no son intercambiables. La tabla de P-25 ahora
   las separa.
3. **Se confundió un número correcto con un error.** P-23: 22,4 % es correcto
   bajo `C̃_R`; el defecto es no declarar el mapeo.
4. **Un PoC con mock no basta para P-01.** La primera versión mostraba el
   síntoma; la segunda, con Groth16 real, mostró que también ocurre con la
   prueba real.
5. **La ventana de un bloque de Fuji no se vio en el estado final.** Hubo que
   leer los bloques de creación, no sólo el estado actual.

## 9. Pendiente

- Reconstruir, sólo si se necesita para la bitácora pública, los POCs perdidos
  de P-08, P-09, P-10, P-11, P-12, P-13 y P-15. El inventario dice qué
  demostraba cada uno y qué resultado dio.
- Revisar el diseño de P-01/P-16 antes de implementarlo.
- Cerrar la auditoría, renumerar, asignar severidades finales y abrir `S-016`.

## 10. Continuación (2026-10-20): P-26, guards de despliegue

Se leyeron línea a línea los scripts individuales y el runbook de fase 1. La
comprobación ejecutable es `pocs/new/TmpDeployGuards.t.sol`:

- `vm.chainId(43113)` + `DeployFujiPhase1.deploy` con `TOKEN`/`SINK` EOAs:
  registry, vault y manager desplegados, `code.length == 0` en token y sink,
  `status=ok`.
- `vm.chainId(1)` + `DeployRegistry.deploy`: registry desplegado, `status=ok`,
  sin `UnsupportedChain` ni `AnvilDefaultOnLiveNetwork`.

Resultado: **2 passed, 0 failed**. Log en `logs/deploy-guards.txt`; la copia
transitoria en `test/` se borró. No se tocaron contratos, tests permanentes ni
el ancla. P-26 queda como hallazgo operativo media/baja: no es una
vulnerabilidad del protocolo, pero el runbook no debe reutilizarse sin los
checks de código y de cadena.

## 10b. Continuación (2026-10-20): addendum de P-12, forma del epoch

Al cerrar la lectura del data layer apareció un caso que el comentario de
`Epoch::freshness_ok` no cubre: `changed_entries` colapsa las hojas en un
`BTreeMap` por validador y `Epoch::new` no exige `N` ni unicidad.

`pocs/new/TmpEpochShape.rs` se ejecutó como test de integración transitorio en
`src/datalayer/tests/tmp_epoch_shape.rs`:

- génesis con **501 hojas** y una dirección repetida → `changed == 500` y
  `freshness_ok == true`, aunque el root tiene 501 hojas;
- epoch con **1.000 hojas**, cada una de las 500 direcciones repetida con la
  misma norma → `changed == 0`, root distinto y `freshness_ok == true`.

Resultado: **2 passed, 0 failed**. Log en `logs/epoch-shape.txt`; la copia en
`src/datalayer/tests/` se borró. No es un ataque nuevo —P-12 ya establece que el
contrato sólo ve un contador declarado— pero el data layer tampoco impone la
forma que dice imponer. Queda como addendum de P-12, no como P-27.

También se ejecutó la campaña de fuzzing existente con
`FOUNDRY_FUZZ_RUNS=5000`: **7 tests, 5000 runs cada uno, 0 failed** (3 de
transporte M7d, 2 del manager, 2 del vault). Log en `logs/fuzz-5000.txt`. No hay
`invariant_*` de estado;
`test_invariant_isAdmittedImpliesBackedAcrossTheWholeLifecycle` es un test
dirigido, no una campaña. El hueco de fuzzing de estado sigue abierto.

## 11. Pendiente actualizado

- Decidir si se reconstruyen los POCs restantes (sólo para la bitácora pública;
  el inventario ya conserva qué probaban).
- Cerrar el alcance restante: soundness formal/ceremonia (no hay ceremonia que
  auditar; la clave es de desarrollo), DA/recuperación (no implementadas y no
  afirmadas como garantía) y economía independiente. El fuzzing existente ya se
  corrió a 5.000 runs; falta una campaña de invariantes de estado, que hoy no
  existe en el repo.
- Al cierre: renumerar, severidades finales, `S-016`, re-ancla y commit.

## 12. Revisión del usuario (2026-10-20)

El usuario reconcilió las cifras y fijó las decisiones que el paper debe seguir
cuando se levante el hold:

| Punto | Decisión |
|---|---|
| `G` canónico | **286.144 gas**, `verifyThreshold` en frío, sólo verificación. `233.104` en caliente subestima porque una admisión real es la primera llamada de la tx. |
| Break-even | **781 gwei** con 286.144; **594 gwei** con los 376.588 de `manager.admit` completo. |
| Comparaciones | Mismo alcance (sólo verificación o admisión completa) y mismo compilador/perfil. |
| `1,59×` | **No se cita**: mezcla ingesta optimizada con verificación sin optimizar. |
| Release v0.2.1 | Errata visible en `v0.2.1-notes.md`; el PDF no se toca. |
| Zenodo | Confirmado **no depositar v0.2.1**; la corrección va a v0.2.2 tras P-01/P-16. |
| P-01 | El test permanente debe mutar **cada** entrada pública, incluida `validator`. Si mutar `validator` sigue verificando, la entrada es decorativa y el rediseño no se acepta. La mutación de `validator` incluye además una dirección que sólo difiere en los bytes altos (incluido el byte más significativo): 160 bits en un campo de 254 no deberían tener aliasing, pero el test lo demuestra. |
| Estado del rediseño | El statement nuevo está diseñado, no implementado. No hay diff de circuito/`ic` que revisar todavía. |

La tabla de gas, la errata y el criterio de aceptación quedaron incorporados al
worksheet (P-25, P-01 y P-16); esta entrada sólo registra la decisión y no
cambia ningún artefacto ejecutable.

## 13. Publicación de la errata (2026-10-20)

- Commit `dcffce2` (`docs: publish v0.2.1 errata and withdraw Zenodo deposit`)
  empujado a `origin/main` (`70f225c..dcffce2`). Sólo incluye los tres ficheros
  de `docs/paper/releases/`: notas, índice y checklist de Zenodo.
- El cuerpo del Release remoto se actualizó por API con una línea de errata al
  principio y un enlace permanente a
  `v0.2.1-notes.md` en el commit `dcffce2`. El cuerpo anterior se conserva
  íntegro debajo.
- `fase0_anchor.sh --check` después del commit: `output_manifest`,
  `audit_manifest` y `anchor_root` idénticos byte a byte; HEAD anclado
  `d99c73a` es ancestro de `dcffce2`. `audit-gate.sh`: 11/11 PASS.
- El worksheet y este anexo de evidencia **siguen sin trackear y sin publicar**.
  El worksheet lo prohíbe expresamente; quedan para revisión local antes de
  decidir su inclusión.
- P-01: se añadió al criterio de aceptación la mutación de `validator` con una
  dirección que sólo difiere en los bytes altos, incluido el byte más
  significativo, para demostrar que no hay truncamiento ni aliasing.

## 14. Segunda lectura (2026-10-20): P-27…P-33

Se revisaron ocho puntos adicionales. Siete son nuevos (`P-27`…`P-33`); el de
freshness ya estaba en **P-12** y no se renumera.

| Punto | ID | Verificación |
|---|---|---|
| Detector de colusión desconectado de `T` | P-27 | Lectura de `main.tex` §Collusion, `src/rmt/` y D-7 del plan |
| Piso financiero `0.2Θ` llamado “garantía” | P-28 | Aritmética sobre `main.tex:865-867` |
| README y trust anchors de v1 | P-29 | Lectura de `README.md:42-43` y `AVIPRegistry`/`AVIPValidatorManager` |
| Freshness declarativa | P-12 | Ya confirmado; no se duplica |
| Unidades de `π_val`, `ω`, `k` | P-30 | Lectura de `main.tex:854-902`, `1289-1293` |
| Premisa PoW sin cita | P-31 | Lectura de `main.tex:56` y bibliografía |
| `admit` usa `latestEpoch()` | P-32 | Código y tests existentes |
| Circuito sin cota `≤ 1 WAD` | P-33 | Sonda ejecutada |

### P-33: sonda del circuito

`pocs/new/TmpEntryUpperBound.rs` se copió a
`src/zk/tests/tmp_entry_upper_bound.rs` y se ejecutó:

```text
cargo test --offline --test tmp_entry_upper_bound -- --nocapture
running 1 test
test an_entry_above_one_wad_satisfies_the_norm_circuit ... ok
test result: ok. 1 passed; 0 failed
```

La entrada probada es `2^60−1 = 1.152921504606846975 WAD`, y
`NormCircuit` queda satisfecho con `certified_norm_wad = entry`. No hay
comparación contra `WAD` en `allocate_entry_bits`; el fixture sí la tiene, pero
es una comprobación del fixture. Log en `logs/entry-bound.txt`; la copia
transitoria se borró.

### Lo que no se tocó

- No se modificaron `main.tex`, contratos, tests permanentes, `README.md` ni
  `CITATION.cff`.
- No se implementó el rediseño P-01/P-16 ni la cota `entry ≤ WAD`; P-33 es una
  sonda de auditoría, no un parche.
- El worksheet y este anexo siguen sin trackear y sin publicar, como en §13.
- `MANIFEST.sha256` se regeneró para incluir la fuente y el log nuevos.

## 15. Tercera lectura (2026-10-21): P-34…P-36

El informe externo completo se reconcilió por ID. La mayoría de sus puntos ya
estaban: P-04 (cota `2^64`), P-05 (`bindManager`, no P-25), P-06 (`payFee`),
P-08 (`pushPair`/identidad), P-13 (`c + r`/BN254), P-14 (metadatos del slash),
P-17 (sin salida) y P-27 (alertas sin consumidor). Se añadieron tres IDs:

| Punto | ID | Verificación |
|---|---|---|
| Slash cross-chain sin prueba de fraude; sólo `NOTIFIER`; sin ventana | P-34 | Lectura de `AVIPSlashingChannel`, codec y test M7d |
| Frontera de detección: Kesten–Stigum no aplica; 3× evade | P-35 | Réplica propia, 300 réplicas por configuración |
| Bauer–Jost mal citado; referencias faltantes | P-36 | arXiv 0910.3118 + Crossref |

### P-35: sonda de densidad

`pocs/new/CollusionDensityProbe.py` se ejecutó desde esta carpeta:

```text
N=500, d_bar=20, H0=1000, H1=300, seed=20261021
q99(lambda_max(B)) = 9.0469  (11.0s)

configuration              theta  TPR@0.01     mean
1 block m=20 10x            7.21     0.980    9.721  (13.9s)
1 block m=24 5x             3.85     0.067    8.835  (17.0s)
1 block m=30 5x             4.81     0.290    8.970  (19.9s)
1 block m=40 3x             3.21     0.057    8.854  (23.2s)
5 blocks m=12 10x           4.33     0.480    9.053  (26.3s)
10 blocks m=10 10x          3.61     0.387    9.022  (29.5s)
```

La conclusión es que la frontera se expresa en `θ`, no en `m`: 40 coludidos
(8 % de `n=500`) con densidad 3× pasan casi indetectados. Los bloques múltiples
subcríticos no evaden; aumentan la detección en esta réplica. El log completo
está en `logs/collusion-density.txt`.

### Lo que no se tocó

- No se modificaron `main.tex`, contratos, tests permanentes, `README.md` ni
  `CITATION.cff`.
- No se implementaron P-34 ni P-35; son hallazgos, no parches.
- El worksheet y este anexo siguen sin trackear y sin publicar.
- `MANIFEST.sha256` se regeneró para incluir la fuente y el log nuevos.

## 16. Cierre de la duda Poseidon (2026-10-21): P-37

La única duda criptográfica abierta del circuito era si `poseidon_params()` y
`PoseidonNormCircuit` producían el mismo hash que circomlib. Se contrastó con
dos vectores públicos de `circomlib/test/poseidoncircuit.js` (t=3) y, para
cubrir la absorción multi-bloque, con una reimplementación manual del bucle de
la esponja para longitudes 1–10 y 500.

`pocs/new/PoseidonCircomlibProbe.rs` se copió a `src/zk/tests/` y se ejecutó:

```text
cargo test --offline --test TmpPoseidonVector -- --nocapture

running 3 tests
[5]   = 16385265615296117650629542106180099124665767598414332878451034854685214984533
[5,0] = 16385265615296117650629542106180099124665767598414332878451034854685214984533
inputs [1, 2]
  circomlib expected        : 7853200120776062878684798364095072458815029376092732009249414926327459813530
  raw permutation state[0]  : 7853200120776062878684798364095072458815029376092732009249414926327459813530
  arkworks sponge digest    : 7142104613055408817911962100316808866448378443474503659992478482890339429929 (state[1])
inputs [3, 4]
  circomlib expected        : 14763215145315200506921711489642608356394854266165572616578112107564877678998
  raw permutation state[0]  : 14763215145315200506921711489642608356394854266165572616578112107564877678998
  arkworks sponge digest    : 17463678829190627617464904566380183791916908580219504546165890868928721427440 (state[1])
len 1: manual state[1] = ... , sponge = ...   (coinciden)
...
len 500: manual state[1] = 14881564148789680950073164612164838307833922018127128489011700125541095929892, sponge = 14881564148789680950073164612164838307833922018127128489011700125541095929892
test result: ok. 3 passed; 0 failed
```

**Resultado:** la permutación t=3 reproduce los vectores de circomlib; con
`α=5`, `Rf=8` y `Rp=57`, las constantes son compatibles con esa instancia. La
diferencia es la convención de salida: circomlib devuelve `state[0]`, el
elemento de **capacidad**; la esponja de arkworks devuelve el primer elemento de
rate, `state[1]`. La convención del repo es la más ortodoxa de las dos y **no es
un defecto del circuito**. El circuito y el cálculo nativo usan la misma
esponja, así que V3 sigue siendo internamente consistente; lo que no hay es
interoperabilidad de digest con el hash de circomlib. La absorción manual
coincide con `PoseidonSponge` para 1–10 y 500 entradas; 500 = 250 bloques
completos, sin relleno. No existe un `Poseidon(500)` estándar en circomlib, así
que la compatibilidad sólo importaría para primitivas de 2 entradas o un
consumidor externo declarado; no lo hay. Se registra como P-37 (Baja, no
soundness) y, por defecto, se cierra como nota de documentación sin re-pinnear.
La separación de dominio (sin etiqueta de dominio ni longitud) queda como
cobertura pendiente, no como hallazgo: la sonda comprobó que `[5]` y `[5,0]`
producen el mismo digest, pero la ruta on-chain usa 500 entradas fijas y no se
demostró que la ambigüedad la alcance.

El log completo está en `logs/poseidon-circomlib.txt`; la copia transitoria en
`src/zk/tests/` se borró y el fuente canónico queda en `pocs/new/`.

### Lo que no se tocó

- No se modificaron `main.tex`, contratos, tests permanentes, el `README.md`
  raíz ni `CITATION.cff`.
- No se cambió `poseidon_commitment` ni se regeneraron fixtures/roots/ancla.
- El worksheet y este anexo siguen sin trackear y sin publicar.
- `MANIFEST.sha256` se regeneró para incluir la fuente y el log nuevos.
