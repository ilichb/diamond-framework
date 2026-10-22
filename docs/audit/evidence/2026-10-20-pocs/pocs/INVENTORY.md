# Inventario de POCs temporales

Los ficheros originales se crearon en `integrations/avalanche/test/`, se
ejecutaron con `forge test` y se borraron al final de la sesión anterior. No hay
copia en Git, VS Code History, Foundry `out/cache` ni `/tmp`. Esta tabla conserva
nombre, propósito y resultado; **no** conserva los bytes originales.

| Fichero / contrato | Hallazgo | Qué demostró | Resultado | Fuente |
|---|---|---|---|---|
| `TmpGlobalProofReuse.t.sol` | P-01 | Dos direcciones distintas usan el mismo proof contra el registry; el verificador era un mock | PASS | Perdida |
| `TmpP01Real.t.sol` | P-01 | La misma prueba **real** de `M4bGroth16Fixtures` admite a Alice y Bob con el manager real | Original: 4 PASS; reconstrucción: 3 PASS | **Reconstruida** |
| `TmpZeroVerifyingKey.t.sol` | P-08 | Clave de verificación toda cero: el constructor la acepta y `verify` devuelve `true`; también end-to-end con registry y manager | 2 PASS | Perdida |
| `TmpDegenerateGamma.t.sol` | P-08 | Clave real con `gamma2 = (0,0)`: `verify(alpha1, beta2, 0, [1,2,3])` devuelve `true` para un statement arbitrario | 1 PASS | Perdida |
| `TmpZeroDecimalSlash*.t.sol` | P-09 | Token de 0 decimales: el slash completo redondea a 0 unidades y el validador retira todo el escrow | PASS | Perdida; nombre exacto no preservado |
| `TmpGuardianSequencer.t.sol` (nombre no preservado) | P-10 | El guardian se propone a sí mismo como sequencer, pasa `CHANGE_DELAY` y ejecuta el cambio | PASS | Perdida; nombre exacto no preservado |
| PoC de eyección (nombre no preservado) | P-11 | Tras una eyección, `requiredStake` no incluye el surcharge que el siguiente `admit` cobra | PASS | Perdida; nombre exacto no preservado |
| `TmpFreshness.t.sol` | P-12 | Se postea un root génesis y luego otro completamente distinto con `changedEntries = 0`; el registry acepta ambos | 1 PASS | Perdida |
| `TmpEpochShape.rs` | P-12 (addendum) | `freshness_ok` acepta un génesis de **501 hojas** con un duplicado y un epoch de **1.000 hojas** duplicadas con `changed == 0`; no impone `N` ni unicidad | 2 PASS | **Nueva** (no perdida) |
| `TmpNormMalleability.t.sol` | P-13 | `certifiedNorm + r` (mismo elemento de campo) verifica en el wrapper y en el registry; `admit` revierte por overflow del manager | 3 PASS | Perdida |
| `TmpBurnSink.t.sol` | P-15 | Un tercero quema el balance no reclamado del `AVIPBurnSink` llamando a `receiveFunds` | 1 PASS | Perdida |
| `TmpRootConflict.t.sol` | P-16 | Con `MERKLE_ROOT` el proof V3 da `false`; con `STATEMENT_ROOT` da `true` pero `commitmentOf` no es la raíz keccak | 2 PASS | **Reconstruida** |
| `TmpGas.t.sol` | P-25 | Medición anterior: `verify` 223.445 caliente, 269.939 alrededor de la llamada externa, `verifyThreshold` 290.854 frío | 2 PASS | Perdida; superada por la medición nueva |
| `TmpDeployGuards.t.sol` | P-26 | Fase 1 en Fuji con `TOKEN`/`SINK` EOAs reporta `status=ok`; `DeployRegistry` con `Plan` explícito despliega en chain id 1 | 2 PASS | **Nueva** (no perdida) |
| `TmpEntryUpperBound.rs` | P-33 | `NormCircuit` acepta una entrada `2^60−1 = 1.152921504606846975 WAD`: no hay comparación contra `WAD` | 1 PASS | **Nueva** (no perdida) |
| `CollusionDensityProbe.py` | P-35 | Con 300 réplicas por configuración: 40 coludidos a 3× dan TPR 0.057; 24 a 5× 0.067; 30 a 5× 0.290; 5×12 a 10× 0.480; 10×10 a 10× 0.387. El límite se expresa en θ, no en `m` | 1000 H0 + 300×6 H1, ejecutado | **Nueva** (no perdida) |
| `PoseidonCircomlibProbe.rs` | P-37 | La permutación reproduce los vectores t=3 de circomlib (`[1,2]`, `[3,4]`); el digest de la esponja es `state[1]` (rate), no el `state[0]` (capacidad) de circomlib; la absorción manual coincide para 1–10 y 500 entradas; `[5]`/`[5,0]` documentan la ambigüedad de longitud | 3 PASS | **Nueva** (no perdida) |

## Notas

- `TmpP01Real` y `TmpRootConflict` se reescribieron contra el código actual.
  Son ejecutables, pero **no son los originales**; la cabecera de cada fichero
  lo declara.
- `TmpDeployGuards` es una PoC **nueva** de la continuación de la auditoría
  (P-26), no una reconstrucción: vive en `pocs/new/` y su log en
  `logs/deploy-guards.txt`.
- `TmpEpochShape` es una PoC **nueva** de Rust (P-12, addendum): fuente en
  `pocs/new/TmpEpochShape.rs` y log en `logs/epoch-shape.txt`. Se ejecutó como
  test de integración transitorio en `src/datalayer/tests/` y se borró después.
- `TmpEntryUpperBound` es una sonda **nueva** de Rust (P-33): fuente en
  `pocs/new/TmpEntryUpperBound.rs` y log en `logs/entry-bound.txt`. Se ejecutó
  como test de integración transitorio en `src/zk/tests/` y se borró después.
  No se tocaron fuentes del crate.
- `CollusionDensityProbe.py` es una sonda **nueva** de Python (P-35): fuente en
  `pocs/new/` y log en `logs/collusion-density.txt`. No modifica los scripts
  sellados; reimplementa el generador y usa `eigsh` para λ_max(B). Se ejecutó
  desde esta carpeta con 1.000 réplicas H0 y 300 por configuración H1.
- `PoseidonCircomlibProbe.rs` es una sonda **nueva** de Rust (P-37): fuente en
  `pocs/new/` y log en `logs/poseidon-circomlib.txt`. Se ejecutó como test de
  integración transitorio en `src/zk/tests/` y se borró después. Contrasta la
  permutación con circomlib, la absorción multi-bloque (1–10 y 500) y la
  diferencia de convención del digest (`state[1]` rate frente a `state[0]`
  capacidad); además documenta la ambigüedad de longitud sin etiqueta
  (`[5]`/`[5,0]`). No toca el circuito ni el ancla. La separación de dominio
  sigue sin cubrir y se registra como cobertura pendiente, no como hallazgo.
- Las cifras de gas de `TmpGas` y `TmpP01Real` se midieron con harness distintos.
  La comparación válida es la que usa la misma configuración; el worksheet P-25
  separa 286.144 de 290.854 y explica que es el mismo camino frío.
- P-01 no tiene todavía test permanente. El criterio de aceptación del rediseño
  está en el worksheet: dos direcciones con el mismo proof (la segunda falla) y
  mutación de **cada** entrada pública (`root`, `epoch`, `validator`,
  `certifiedNorm`), cada una por separado. La mutación de `validator` incluye una
  dirección que sólo difiere en los bytes altos (incluido el byte más
  significativo): con 160 bits en un campo de 254 no debería haber aliasing, pero
  el test debe demostrarlo. Si mutar `validator` sigue verificando, la entrada es
  decorativa y el rediseño no se acepta. El test se escribirá con
  `M4bGroth16Fixtures`/la fixture regenerada, nunca con el mock.
- La reconstrucción de los demás POCs queda pendiente y sólo se hará si aporta a
  la bitácora pública. El inventario ya conserva qué probaban y qué resultado
  dieron.
