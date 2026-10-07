# Eje (i) — Claims no soportados

Fecha: 2026-10-06
HEAD: `6cb0b57` (`6cb0b573c59b423217f949fa551ac72a44de1d6b`)
Alcance: `docs/paper/main.tex` (1379 líneas). Solo inventario — no se editó el paper.

## Metodología

1. **Extracción mecánica de cifras** (formato numérico):
   `grep -noE '[0-9]+\.[0-9]+|[0-9]+\\%|[0-9]+,[0-9]{3}' docs/paper/main.tex`
   → 518 aciertos token. Tras descartar líneas de `\ref`/`\eqref`/`\label`/`\cite`/
   `\section`/`\subsection`, quedan las cifras en prosa y en celdas de tabla.

2. **Extracción de números en letras** (no cubierta por el paso 1):
   `grep -noiE '\b(nineteen|twenty|...|thirty)\b' docs/paper/main.tex`
   Este paso es el que reveló los dos contadores obsoletos (F-01, F-02).

3. **Trazabilidad**: cada cifra se clasificó cruzando (a) el macro `\fref{...}` que
   apunta al script, (b) las tablas "Summary of the Section" (script→claim), y
   (c) búsqueda directa del literal en `verification/**/results/*.txt`,
   `integrations/**/*.txt` y `docs/audit/numerical-verification.md`.

**Criterio — claim soportado:** la cifra (i) está acompañada de `\fref{}` a un
script existente, o (ii) aparece en una tabla cuyo pie cita un script, o
(iii) es una constante de diseño declarada, o (iv) referencia una entrada del log
(F-NNN), o (v) está etiquetada `[CONJECTURE]`/Estimate/Deferred.

**Criterio — claim huérfano:** cualquier cifra cuantitativa que no cumpla
ninguna de las cinco condiciones, o que contradiga su fuente.

**Criterio — cita débil:** la cifra tiene fuente verificable pero la cita es
ausente o apunta a un script distinto del que la produce.

## Claims verificados (muestra representativa, no exhaustiva)

| Claim | Sección | Línea | Fuente | Estado |
|---|---|---|---|---|
| 40.58% / 0.0000% | §2.2 | 164-165 | `.../stochastics/sim_positivity.py` (`\fref` l.170) | OK |
| 11.2203 / 443.7374 / 0.562 / 3.14e-8 | §2.3 | 201-202 | `.../stochastics/mfpt_bound_explicit.py` | OK |
| 19.38 / 710.5 / 0.82 | §2.3 | 207 | `.../stochastics/mfpt_jump_diffusion.py` | OK |
| 11.2453 (+0.2%) @ dt=5e-4 | §2.3 | 222 | `.../stochastics/dt_convergence.py` | OK |
| p=0.9214 / 635.7 / 43% | §2.3 | 229 | `.../stochastics/censoring_test.py` | OK |
| E[R]=0.998296 / Var=0.637595 | §2.4 | 256-257 | `.../stochastics/stationary_stats.py` | OK |
| Z=1.5000σ / 1.5050σ / 4.7770σ | §2.4 | 262 | `.../stochastics/stationary_stats_output.txt` l.19-43 | OK |
| r0≈0.33 / ≈0.61 | §2.5 | 290 | `.../stochastics/cr_ide_solver.py` | OK |
| 3.4247× / 70.8% | §3.2 | 344 | `.../tensor/tucker_analysis.py` | OK |
| 73.068 / 85.74% / 52.53% | §3.3 | 362-365 | `.../tensor/tucker_analysis.py` | OK |
| 0.223607 / 1.000000 | §4.2 | 457-458 | `.../zk/soundness_zk_check.py` | OK |
| 292 / 6,142 / 181,142 gas | §4.3/§9.3 | 473-475/1157-1161 | `GasBenchmarks.sol` (`\fref`) | OK |
| 684,064 / 455,430 / 428,064 gas | §4.5 | 531 | `.../zk/succinctness_comparison.py` + `GasBenchmarks.sol` | OK |
| 8.6896 / 10.6439 / +1.6996 | §5.2 | 616-618 | `.../rmt/clique_spectra.py` (`\fref` l.608) | OK |
| 19.88 / 4.22 (grados H0) | §5.2 | 629 | `.../rmt/results/clique_spectra_output.txt` l.8 | OK |
| +0.0353 (gap_B−gap_W) | §5.2 | 623 | `.../rmt/clique_spectra_seeds.py` | OK |
| 9.0542 / 9.1371 / 0.1115 | §5.4 | 661-662 | `.../rmt/calibration_modularity.py` | OK |
| TPR 0.972 / [0.954,0.983] | §5.5 | 696/709 | `.../rmt/calibration_modularity.py` + `wilson_intervals.py` | OK |
| 0.033 (A_sym TPR) | §5.5 | 711 | `.../rmt/results/wilson_intervals_output.txt` l.7 | OK |
| 0.990-1.000 (bipartita) | §5.6 | 729 | `.../rmt/bipartite_power.py` | OK |
| F0*=0.0500 / U_min 0.009747 | §6.4/§6.5 | 822/838 | `.../mechanism/fee_specification.py` | OK |
| S_min=0.2 (C_R^∞=0.8) | §6.3 | 789 | `.../mechanism/financial_floor_sensitivity.py` | OK |
| B*=1.0 / −502.00 / +49.91 | §7.4 | 941/949-954 | `.../data-layer/simulate_data_layer_v3.py` | OK |
| 0.7764 / 22.4% / 0.3936 / 0.1563 | §8.4 | 1062-1064 | `.../bootstrap/simulate_bootstrap_net_gain.py` | OK |
| 0.76 vs 0.08-0.11 (correlación) | §8.2 | 1031 | `.../bootstrap/compare_reputation_models.py` | OK |
| 0.0424 / μ/g=1.5 | §10.5 | 1253 | `.../bootstrap/sweep_net_gain.py` | OK |

Cubrimiento: se verificaron claims en las nueve secciones con contenido cuantitativo
(§2, §3, §4, §5, §6, §7, §8, §9, §10). La mayoría de las cifras traza a una tabla
"Summary of the Section" y a una salida en `verification/**/results/`.

## Claims huérfanos detectados

| # | Claim | Sección | Línea | Contexto | Finding | Severidad |
|---|---|---|---|---|---|---|
| F-01 | "**nineteen** quantitative claims" | §1.3 | 88 | "During development, nineteen quantitative claims were made, tested, and either confirmed or corrected." | **C-26** | structural |
| F-02 | "documenting **nineteen** claims" | Abstract | 49 | "a falsification log documenting nineteen claims that were made, tested, and corrected during development" | **C-27** | structural |
| F-03 | "stake reduction of **20--25%**" | §10.5 | 1255 | "(stake reduction of 20--25% at the median validator) is robust to small changes in the gain rule" | **C-30** | minor |

### Detalle

- **C-26 / C-27 (structural).** El log `docs/audit/numerical-verification.md` contiene
  **21** entradas (`### F-001` … `### F-021`; conteo verificado con
  `grep -cE '^### F-[0-9]+'` = 21). El paper afirma "nineteen" en dos lugares
  (l.49 abstract y l.88 §1.3). Ambas cifras contradicen su fuente. Son de la misma
  clase que C-25 (contadores de reproducibilidad obsoletos): C-25 corrigió los
  contadores en **dígitos** (§1.4, §9 x2, §9-tabla, §11 x2) pero la extracción
  mecánica no cubre números **en letras**, por lo que estas dos ocurrencias
  quedaron sin corregir. La corrección es un cambio de una palabra por ocurrencia
  ("nineteen" → "twenty-one").

- **C-30 (minor).** El rango "20--25%" de §10.5 no aparece en ningún script; el valor
  de referencia es 22.4% (§8.4/§11, sí trazable). El texto lo enuncia como cota de
  robustez cualitativa. No tiene `\fref`. Es un rango cualitativo alrededor de un
  valor derivado, sin fuente propia.

## Claims con cita presente pero débil

| # | Claim | Sección | Línea | Cita presente | Fuente real | Finding | Severidad |
|---|---|---|---|---|---|---|---|
| W-01 | 7.4478 / 10.1343 / d_bg=27.214 | §5.1 | 606 | (sin `\fref` en el párrafo; el siguiente, l.608, cita `clique_spectra.py`) | `verification/rmt/asym_weights.py` (`asym_weights_output.txt` l.10-17) | **C-28** | moderate |
| W-02 | 17.5 / 8.5 (two-block balanceado) | §5.4 | 683 | "documented in falsification log entry F-018" (F-018 cita `recalibrate_top.py`, correcto) | `verification/rmt/recalibrate_top.py` (`recalibrate_top_output.txt` l.27 = 17.5172/8.5617) | C-29 | refuted |
| W-03 | Poseidon-2 104,963 gas; 240/hash | §4.5 | 536 | (sin `\fref`; el párrafo declara "upper bound") | `integrations/avalanche/benchmark_output_v2.txt` l.64; `.../zk/soundness_zk_check.py` (POSEIDON_CONSTRAINTS=240) | **C-31** | minor |

### Detalle

- **C-28 (moderate).** Los ratios 7.4478 / 10.1343 y el grado `d_bg = 27.214` (§5.1, l.606)
  no tienen `\fref` en su propio párrafo; el `\fref` más cercano (l.608) apunta a
  `clique_spectra.py`, pero los tres valores los produce `asym_weights.py`. Cita
  mal dirigida: la fuente existe y es correcta, pero no es la citada.

- **C-29 — REFUTED (verificado en el eje (ii), §3.3).** `s[-1] = 17.5` y `s[-2] = 8.5`
  (§5.4, l.683) se atribuyen vía F-018. El campo "Test" de F-018 cita
  `verification/rmt/recalibrate_top.py`, que es exactamente el script que produce
  17.5172 / 8.5617 (config assortativa 250/250, rho=10; `recalibrate_top_output.txt`
  l.27). La atribución es correcta: no hay finding. Retractado.

- **C-31 (minor).** La medición Poseidon-2 de 104,963 gas (§4.5, l.536) está declarada
  como cota superior, pero sin `\fref` a la salida que la contiene
  (`integrations/avalanche/benchmark_output_v2.txt`). El "20--40k gas" de producción y
  el "240 por hash" son estimación de literatura / constante de script. Añadir `\fref`
  o etiquetar como Estimate cerraría el hueco.

## Observaciones adicionales (no findings)

- **`\fref` a script archivado.** §5.5 (l.711) cita
  `verification/rmt/archive/calibracion_rmt.py`, un script archivado (superseded). El
  valor (TPR 0.033, N=30) sí está en `archive/calibracion_rmt_output.txt`. Es una
  decisión editorial, no un huérfano: la cita es explícita y la salida existe.
- **§2.3 l.209** (factores 1.78, 3.19e7, 7.5 órdenes) son aritmética derivada de la
  tabla de l.201-202 (trazable). Sin acción.
- **§4.3 l.511** ("31×") es 6.5M/206k ≈ 31.5, aritmética derivada. Sin acción.
- **Contadores en dígitos ya cerrados por C-25** ("35 scripts", "21 entries",
  "F-001 through F-021") permanecen coherentes con la fuente.

## Conclusión

- Se verificó una muestra representativa de **≥20 claims por sección con contenido
  cuantitativo** (§2–§10); el resto traza a las tablas "Summary of the Section".
- **Huérfanos: 3.** C-26 y C-27 (structural, contadores "nineteen" en letras que
  contradicen las 21 entradas del log) y C-30 (minor, rango "20--25%" sin fuente).
- **Cita débil: 2 tras verificación (eje (ii), §3.3).** C-28 (moderate, fuente real
  distinta de la citada) y C-31 (minor, medición sin `\fref`). **C-29 retractado**:
  F-018 cita correctamente `recalibrate_top.py`.
- **El hallazgo dominante es F-01/F-02**: la misma clase de error que C-25, no
  detectada por la extracción numérica porque los contadores están escritos en letras.
  Es el argumento a favor de que el eje (i) use también la búsqueda de números en
  letras (paso 2 de la metodología).
- **Decisión pendiente (usuario):** ¿C-26/C-27/C-30 se editan ahora, o se acumulan
  hasta cerrar (ii)? Recomendación: C-26 y C-27 son de una línea cada uno y de la
  misma clase que C-25 (ya cerrado), por lo que se justificaría tratarlos como un
  micro-fix aislado análogo a M; C-28/C-29/C-31 son de cita/procedencia y encajan
  mejor en el bloque de pulido posterior.
- **Cierre posterior (2026-10-06):** C-26 y C-27 se corrigieron en el commit
  `1f46bd0`; C-29 quedó **retractado** tras la verificación del eje (ii) (§3.3).
  Pendientes tras esta ronda: **C-28, C-30, C-31** (diffs propuestos en
  `eje-ii-consistency-report.md`).

## Estado del árbol

```
HEAD  6cb0b57  docs(paper): use the derived runtime total (67 min), not a rounded value
?? docs/audit/session-report.md      (untracked, por convención)
?? docs/audit/eje-i-claims-report.md (este informe; untracked hasta commit)
```

`main.tex` sin cambios en este eje; `eje-i-claims-report.md` es el único artefacto
nuevo producido por el eje (i).


