# Evidencia de POCs — sesión 2026-10-20

Esta carpeta nace de una corrección de proceso: al cerrar la sesión anterior se
borraron los tests `Tmp*` que sostenían varios hallazgos. El usuario quiere
conservarlos como evidencia del razonamiento, de los cálculos, de los fallos y
de los aciertos. **Los fuentes originales no se pueden recuperar byte a byte**;
esta carpeta conserva lo que sí es recuperable y separa con claridad lo
reconstruido de lo perdido.

## Estado de recuperación

| Fuente | Estado |
|---|---|
| Git | No los conoce: eran *untracked* y nunca se commitearon. |
| VS Code History | No hay entradas para esos ficheros. |
| Foundry `out/` y `cache/` | Los artefactos `Tmp*` se borraron; no queda copia. |
| `/tmp` y Trash | No se encontró copia. |
| **Bytes originales** | **Perdidos.** |
| Reconstrucciones | `pocs/reconstructed/`; son reescrituras contra el código actual, no los originales. |

No se debe presentar una reconstrucción como si fuera el fichero que se ejecutó
en la sesión anterior. La diferencia importa para una bitácora pública.

## Contenido

- `RUN-LOG.md` — cronología de la sesión: comandos, resultados, decisiones,
  errores y correcciones. Es la narrativa que faltaba.
- `pocs/INVENTORY.md` — inventario de todos los `Tmp*`, con hallazgo, resultado
  y estado de conservación.
- `pocs/reconstructed/` — POCs reescritas para que la evidencia sea ejecutable.
  Cada fichero lleva una cabecera que dice **RECONSTRUIDO**.
- `pocs/new/` — POCs nuevas de la continuación de la auditoría; no son
  reconstrucciones de ficheros perdidos. `TmpDeployGuards.t.sol` sostiene P-26,
  `TmpEpochShape.rs` sostiene el addendum de P-12 sobre `N`/unicidad,
  `TmpEntryUpperBound.rs` sostiene P-33 (cota por entrada del circuito),
  `CollusionDensityProbe.py` sostiene P-35 (potencia del detector por densidad)
  y `PoseidonCircomlibProbe.rs` sostiene P-37 (permutación Poseidon frente a
  circomlib, absorción multi-bloque, ambigüedad de longitud y convención del
  digest).
- `calculations/gas_break_even.py` — cálculo reproducible de la tabla de gas y
  break-even de P-25; no depende del paper ni de una hoja de cálculo.
- `calculations/gas-table.csv` — salida del script anterior.
- `logs/` — salidas de las ejecuciones que se hagan desde esta carpeta.
- `MANIFEST.sha256` — huellas de los ficheros de esta carpeta (sin incluirse a
  sí mismo), para detectar ediciones posteriores.

## Regla de conservación

1. Todo POC temporal se escribe **primero** aquí, nunca directamente en `test/`.
2. Para ejecutarlo, el runner copia el fuente a
   `integrations/avalanche/test/` con un nombre `TmpEvidence*.t.sol`, ejecuta
   `forge test` y guarda la salida en `logs/`. Para una PoC de Rust, la copia va
   a `src/<crate>/tests/` y se ejecuta con `cargo test --offline --test <nombre>`.
3. La copia de `test/` se retira **sólo después** de que el log esté guardado y
   el fuente canónico siga en esta carpeta. El original no se borra.
4. No se guardan claves, seeds privadas ni outputs de Ceremony con toxic waste.
   Las fixtures de desarrollo que ya están en el repo son públicas y se citan,
   no se duplican.

## Contexto

- HEAD al inicio de la sesión: `70f225cbb364eba0a04b011a54a0483f55f51b5c`.
- HEAD actual (errata publicada): `dcffce2045b201cd7315e1df33a994cfcf6435bb`.
- Red: Avalanche Fuji, chain id 43113, sólo lecturas `eth_call`/`eth_getLogs`.
- No se tocó el ancla, `main.tex`, contratos ni tests permanentes.
- El worksheet de la auditoría sigue siendo
  `docs/audit/audit-2026-10-20-in-progress.md`; esta carpeta es su anexo de
  evidencia, no un segundo informe.
