# Eje (iv) — Reproducción numérica (paper ↔ baseline)

Fecha: 2026-10-07
HEAD: `0cb4b34` (`docs(audit): mark the --resume hardening as applied (561e2cf)`)
Alcance: cifras cuantitativas de `docs/paper/main.tex` × outputs de
`verification/baseline_2026-10-06/` (35 scripts). No se editó el paper.

## Errata — Bloque B (resolución G4): 518 → 517 tokens

El total de arriba (**518**) ya no se reproduce: el cross-check actual emite
**517**. La caída NO viene del regex del cross-check.

    git log --follow --oneline -- docs/audit/eje-iv-crosscheck.py   # 34f85f0 (único commit)
    git diff HEAD~5 -- docs/audit/eje-iv-crosscheck.py              # vacío

La pérdida viene de una edición posterior de `main.tex` (commit `cd6f8f4`):

    git show cd6f8f4 -- docs/paper/main.tex | grep -E '^[-+][^-+]'
    -D4 tail is geometric; S2.2 has no censoring & Verified & \spath{censoring_test.py} \\
    +Second-regime tail is geometric; first regime has no censoring & Verified & \spath{censoring_test.py} \\

Eliminar la etiqueta `S2.2` (los rótulos de régimen "D4/S2.2" eran indefinidos,
finding **C-41**) eliminó el token numérico `2.2` — antiguo `main.tex:313`.
Derivación reproducible (mismo `TOKEN_RE` que el cross-check):

    git show 34f85f0:docs/paper/main.tex > /tmp/old.tex
    # TOKEN_RE sobre /tmp/old.tex vs docs/paper/main.tex -> 518 vs 517
    # difflib.SequenceMatcher -> única diferencia: delete '2.2' (old line 304)

**517 es el nuevo baseline.** La tabla de cruce de abajo conserva la numeración
de `34f85f0`: sus filas posteriores a la antigua línea 304 van una por delante
de la numeración actual.

### Limitaciones del matcher del cross-check (no son defectos del paper)

El cross-check compara por igualdad numérica **sin entender escala ni formato**,
por eso reporta como "huérfanas" cifras que sí están en los outputs:

| Formato en el output | Tokens afectados |
|---|---|
| Notación científica (`1.415225e+10`, `3.135455e-08`, `3.1893e+07`) | `1.415`, `3.14`, `3.19` |
| Separadores de millares (`6,500,000`, `1,080,501`) | `6.5`, `1.08` |
| Fracción → porcentaje (`0.9720` → `97.2\%`, `rel_err` → `\%`) | `97.2`, `77.6`, `26.6`, `13.5` |

La adjudicación de las 27 cifras huérfanas (numeración actual) está en
`docs/audit/claim-registry.csv`.

## Metodología

- **Regla A — una cifra, un renglón.** Extracción mecánica con la misma regex
  que el eje (i):
  `grep -noE '[0-9]+\.[0-9]+|[0-9]+\%|[0-9]+,[0-9]{3}'`
  → **518** tokens (idéntico al universo del eje (i): la carga numérica del
  paper no ha cambiado).
- **Regla B — el valor en el output se deriva, no se teclea.** Para cada cifra,
  el valor de referencia se toma del output del script que la cita (`\fref{}`
  más cercano en la misma línea o a ±3 líneas). La coincidencia se decide por
  **igualdad numérica tras redondear** el número del output a la precisión del
  token (el paper redondea al alza; ver C-36).
- **Regla C — parar en el primer MISMATCH.** Cada discrepancia es un finding
  nuevo; no se acumulan.

Herramienta reproducible: `docs/audit/eje-iv-crosscheck.py` (untracked en este
eje; emite la tabla de cruce).

## Resultado global

| Clase | N.º | Nota |
|---|---|---|
| OK (coincide con el output) | 490 | 94.6 % de las cifras |
| DERIVED (aritmética derivada del output) | 13 | p.ej. 6.5M/206k, 1−0.224 |
| Estimate (declarado, sin script) | 7 | "6.5M gas" (Bulletproofs) |
| Notación científica (limitación del matcher) | 4 | 1.415e10, 3.14e-8 |
| Unit conversion (fracción → %) | 1 | TPR 0.972 → 97.2 % |
| Referencia de sección (no es cifra) | 2 | "Section 10.2" |
| **MISMATCH** | **1** | **C-36**: `s[-2] = 8.5` vs output `8.5617` |

## Tabla de cruce (518 cifras)

| # | Línea | § | Cifra | Fuente (script) | Valor en paper | Valor en output | Estado |
|---|---|---|---|---|---|---|---|
| 1 | 18 | (pre) | `0.85` | cr_ide_solver | `0.85` | `0.85` | OK |
| 2 | 39 | (pre) | `0.5` | cr_ide_solver | `0.5` | `0.5` | OK |
| 3 | 157 | Domain Validity Under Jumps | `0.5` | cr_ide_solver | `0.5` | `0.5` | OK |
| 4 | 157 | Domain Validity Under Jumps | `1.0` | fee_specification_net | `1.0` | `1.0` | OK |
| 5 | 157 | Domain Validity Under Jumps | `0.8` | cr_ide_solver | `0.8` | `0.8` | OK |
| 6 | 157 | Domain Validity Under Jumps | `1.0` | fee_specification_net | `1.0` | `1.0` | OK |
| 7 | 157 | Domain Validity Under Jumps | `0.64` | sweep_net_gain | `0.64` | `0.6352` | OK |
| 8 | 157 | Domain Validity Under Jumps | `0.8` | cr_ide_solver | `0.8` | `0.8` | OK |
| 9 | 157 | Domain Validity Under Jumps | `0.15` | fee_specification_net | `0.15` | `0.15` | OK |
| 10 | 157 | Domain Validity Under Jumps | `0.3` | cr_ide_solver | `0.3` | `0.316267` | OK |
| 11 | 164 | Domain Validity Under Jumps | `40.58` | sim_positivity | `40.58` | `40.5800` | OK |
| 12 | 165 | Domain Validity Under Jumps | `0.0000` | fee_specification_net | `0.0000` | `1e-09` | OK |
| 13 | 170 | Domain Validity Under Jumps | `0.001` | sim_positivity | `0.001` | `1e-3` | OK |
| 14 | 172 | Domain Validity Under Jumps | `40.58` | sim_positivity | `40.58` | `40.5800` | OK |
| 15 | 201 | The Whitewashing Bound | `0.5` | cr_ide_solver | `0.5` | `0.5` | OK |
| 16 | 201 | The Whitewashing Bound | `0.8` | cr_ide_solver | `0.8` | `0.8` | OK |
| 17 | 201 | The Whitewashing Bound | `11.2203` | mfpt_bound_explicit | `11.2203` | `11.220298` | OK |
| 18 | 201 | The Whitewashing Bound | `19.965` | mfpt_bound_explicit | `19.965` | `1.996524e+01` | OK |
| 19 | 201 | The Whitewashing Bound | `0.562` | cr_ide_solver | `0.562` | `0.562375` | OK |
| 20 | 202 | The Whitewashing Bound | `2.0` | fee_specification_net | `2.0` | `2` | OK |
| 21 | 202 | The Whitewashing Bound | `0.5` | cr_ide_solver | `0.5` | `0.5` | OK |
| 22 | 202 | The Whitewashing Bound | `443.7374` | mfpt_bound_explicit | `443.7374` | `443.737421` | OK |
| 23 | 202 | The Whitewashing Bound | `1.415` | - | `1.415` | `-` |  |
| 24 | 202 | The Whitewashing Bound | `3.14` | - | `3.14` | `-` |  |
| 25 | 207 | The Whitewashing Bound | `0.8` | mfpt_jump_diffusion | `0.8` | `0.8` | OK |
| 26 | 207 | The Whitewashing Bound | `19.38` | mfpt_jump_diffusion | `19.38` | `19.3814` | OK |
| 27 | 207 | The Whitewashing Bound | `710.5` | mfpt_jump_diffusion | `710.5` | `710.4893` | OK |
| 28 | 207 | The Whitewashing Bound | `1.0` | mfpt_jump_diffusion | `1.0` | `1.0` | OK |
| 29 | 207 | The Whitewashing Bound | `0.82` | mfpt_jump_diffusion | `0.82` | `0.8210` | OK |
| 30 | 209 | The Whitewashing Bound | `1.78` | mfpt_jump_diffusion | `1.78` | `1.7794e+00` | OK |
| 31 | 209 | The Whitewashing Bound | `3.19` | mfpt_jump_diffusion | `3.19` | `-` |  |
| 32 | 209 | The Whitewashing Bound | `7.5` | mfpt_jump_diffusion | `7.5` | `-` |  |
| 33 | 209 | The Whitewashing Bound | `0.562` | mfpt_jump_diffusion | `0.562` | `0.562375` | OK |
| 34 | 209 | The Whitewashing Bound | `3.14` | mfpt_jump_diffusion | `3.14` | `-` |  |
| 35 | 217 | The Whitewashing Bound | `0.5` | cr_ide_solver | `0.5` | `0.5` | OK |
| 36 | 217 | The Whitewashing Bound | `0.8` | cr_ide_solver | `0.8` | `0.8` | OK |
| 37 | 217 | The Whitewashing Bound | `2.0` | fee_specification_net | `2.0` | `2` | OK |
| 38 | 217 | The Whitewashing Bound | `0.5` | cr_ide_solver | `0.5` | `0.5` | OK |
| 39 | 219 | The Whitewashing Bound | `0.02` | fee_specification_net | `0.02` | `0.0250` | OK |
| 40 | 219 | The Whitewashing Bound | `12.3115` | dt_convergence | `12.3115` | `12.3115` | OK |
| 41 | 219 | The Whitewashing Bound | `9.7` | recalibrate_top | `9.7` | `9.7397` | OK |
| 42 | 219 | The Whitewashing Bound | `561.55` | dt_convergence | `561.55` | `561.5454` | OK |
| 43 | 219 | The Whitewashing Bound | `26.6` | - | `26.6` | `-` |  |
| 44 | 220 | The Whitewashing Bound | `0.005` | threshold_quantization | `0.005` | `0.005208` | OK |
| 45 | 220 | The Whitewashing Bound | `11.7708` | dt_convergence | `11.7708` | `11.7708` | OK |
| 46 | 220 | The Whitewashing Bound | `4.9` | mfpt_jump_diffusion | `4.9` | `4.9` | OK |
| 47 | 220 | The Whitewashing Bound | `503.71` | dt_convergence | `503.71` | `503.7052` | OK |
| 48 | 220 | The Whitewashing Bound | `13.5` | - | `13.5` | `-` |  |
| 49 | 221 | The Whitewashing Bound | `0.001` | cr_ide_solver | `0.001` | `1e-3` | OK |
| 50 | 221 | The Whitewashing Bound | `11.3334` | dt_convergence | `11.3334` | `11.3334` | OK |
| 51 | 221 | The Whitewashing Bound | `1.0` | fee_specification_net | `1.0` | `1.0` | OK |
| 52 | 221 | The Whitewashing Bound | `461.83` | dt_convergence | `461.83` | `461.8307` | OK |
| 53 | 221 | The Whitewashing Bound | `4.1` | threshold_quantization | `4.1` | `4.1` | OK |
| 54 | 222 | The Whitewashing Bound | `0.0005` | r_std_specification | `0.0005` | `5e-4` | OK |
| 55 | 222 | The Whitewashing Bound | `11.2453` | dt_convergence | `11.2453` | `11.2453` | OK |
| 56 | 222 | The Whitewashing Bound | `0.2` | fee_specification_net | `0.2` | `0.15` | OK |
| 57 | 229 | The Whitewashing Bound | `39.7` | censoring_test | `39.7` | `39.70` | OK |
| 58 | 229 | The Whitewashing Bound | `0.9973` | censoring_test | `0.9973` | `0.9973` | OK |
| 59 | 229 | The Whitewashing Bound | `0.9858` | censoring_test | `0.9858` | `0.9858` | OK |
| 60 | 229 | The Whitewashing Bound | `0.9927` | censoring_test | `0.9927` | `0.9927` | OK |
| 61 | 229 | The Whitewashing Bound | `0.0038` | censoring_test | `0.0038` | `0.0038` | OK |
| 62 | 229 | The Whitewashing Bound | `0.9214` | censoring_test | `0.9214` | `0.921350` | OK |
| 63 | 229 | The Whitewashing Bound | `635.7` | censoring_test | `635.7` | `635.7279` | OK |
| 64 | 229 | The Whitewashing Bound | `443.7` | censoring_test | `443.7` | `443.737421` | OK |
| 65 | 229 | The Whitewashing Bound | `43\%` | censoring_test | `43\%` | `43` | OK |
| 66 | 231 | The Whitewashing Bound | `43\%` | censoring_test | `43\%` | `43` | OK |
| 67 | 248 | Stationary Distribution | `50\%` | stationary_stats | `50\%` | `50.0` | OK |
| 68 | 256 | Stationary Distribution | `0.5` | cr_ide_solver | `0.5` | `0.5` | OK |
| 69 | 256 | Stationary Distribution | `0.8` | cr_ide_solver | `0.8` | `0.8` | OK |
| 70 | 256 | Stationary Distribution | `1.000000` | fee_specification_net | `1.000000` | `1.0` | OK |
| 71 | 256 | Stationary Distribution | `0.998296` | stationary_stats | `0.998296` | `0.998296` | OK |
| 72 | 256 | Stationary Distribution | `0.17` | cr_ide_solver | `0.17` | `0.170136` | OK |
| 73 | 256 | Stationary Distribution | `0.640000` | stationary_stats | `0.640000` | `0.6400` | OK |
| 74 | 256 | Stationary Distribution | `0.637595` | stationary_stats | `0.637595` | `0.637595` | OK |
| 75 | 256 | Stationary Distribution | `0.38` | cr_ide_solver | `0.38` | `0.382206` | OK |
| 76 | 257 | Stationary Distribution | `2.0` | fee_specification_net | `2.0` | `2` | OK |
| 77 | 257 | Stationary Distribution | `0.5` | cr_ide_solver | `0.5` | `0.5` | OK |
| 78 | 257 | Stationary Distribution | `1.000000` | fee_specification_net | `1.000000` | `1.0` | OK |
| 79 | 257 | Stationary Distribution | `1.000062` | stationary_stats | `1.000062` | `1.000062` | OK |
| 80 | 257 | Stationary Distribution | `0.006` | calibration_heavy_tail | `0.006` | `0.0060` | OK |
| 81 | 257 | Stationary Distribution | `0.062500` | stationary_stats | `0.062500` | `0.0625` | OK |
| 82 | 257 | Stationary Distribution | `0.063097` | stationary_stats | `0.063097` | `0.063097` | OK |
| 83 | 257 | Stationary Distribution | `0.96` | calibration_heavy_tail | `0.96` | `0.960` | OK |
| 84 | 262 | Stationary Distribution | `1\%` | fee_specification_net | `1\%` | `1.0` | OK |
| 85 | 262 | Stationary Distribution | `2.2` | tucker_analysis | `2.2` | `2.1931` | OK |
| 86 | 262 | Stationary Distribution | `1.50` | simulate_data_layer_v3 | `1.50` | `1.50` | OK |
| 87 | 262 | Stationary Distribution | `4.80` | stationary_stats | `4.80` | `4.8000` | OK |
| 88 | 262 | Stationary Distribution | `1.5050` | stationary_stats | `1.5050` | `1.5050` | OK |
| 89 | 262 | Stationary Distribution | `4.7770` | stationary_stats | `4.7770` | `4.7770` | OK |
| 90 | 264 | Stationary Distribution | `95\%` | attacker_profit_analytical | `95\%` | `95` | OK |
| 91 | 264 | Stationary Distribution | `0.00354` | stationary_stats | `0.00354` | `0.003540` | OK |
| 92 | 264 | Stationary Distribution | `0.557` | stationary_stats | `0.557` | `0.557221` | OK |
| 93 | 264 | Stationary Distribution | `0.00479` | stationary_stats | `0.00479` | `0.004790` | OK |
| 94 | 264 | Stationary Distribution | `0.201` | sweep_net_gain | `0.201` | `0.2012` | OK |
| 95 | 283 | Integro-Differential Formulation | `0.8` | cr_ide_solver | `0.8` | `0.8` | OK |
| 96 | 285 | Integro-Differential Formulation | `0.8` | cr_ide_solver | `0.8` | `0.8` | OK |
| 97 | 285 | Integro-Differential Formulation | `1.6` | cr_ide_solver | `1.6` | `1.595210` | OK |
| 98 | 285 | Integro-Differential Formulation | `0.85` | cr_ide_solver | `0.85` | `0.85` | OK |
| 99 | 285 | Integro-Differential Formulation | `0.15` | fee_specification_net | `0.15` | `0.15` | OK |
| 100 | 285 | Integro-Differential Formulation | `0.68` | - | `0.68` | `-` |  |
| 101 | 285 | Integro-Differential Formulation | `0.85` | cr_ide_solver | `0.85` | `0.85` | OK |
| 102 | 287 | Integro-Differential Formulation | `0.8` | cr_ide_solver | `0.8` | `0.8` | OK |
| 103 | 287 | Integro-Differential Formulation | `0.8` | cr_ide_solver | `0.8` | `0.8` | OK |
| 104 | 287 | Integro-Differential Formulation | `0.68` | cr_ide_solver | `0.68` | `-` |  |
| 105 | 287 | Integro-Differential Formulation | `0.85` | cr_ide_solver | `0.85` | `0.85` | OK |
| 106 | 287 | Integro-Differential Formulation | `0.8` | cr_ide_solver | `0.8` | `0.8` | OK |
| 107 | 287 | Integro-Differential Formulation | `0.8` | cr_ide_solver | `0.8` | `0.8` | OK |
| 108 | 290 | Integro-Differential Formulation | `0.33` | cr_ide_solver | `0.33` | `0.329412` | OK |
| 109 | 290 | Integro-Differential Formulation | `0.61` | cr_ide_solver | `0.61` | `0.611879` | OK |
| 110 | 290 | Integro-Differential Formulation | `0.8` | cr_ide_solver | `0.8` | `0.8` | OK |
| 111 | 290 | Integro-Differential Formulation | `1.0` | cr_ide_solver | `1.0` | `1` | OK |
| 112 | 304 | Summary of the Section | `2.2` | tucker_analysis | `2.2` | `2.1931` | OK |
| 113 | 310 | Summary of the Section | `40.58` | sim_positivity | `40.58` | `40.5800` | OK |
| 114 | 310 | Summary of the Section | `0.0000` | fee_specification_net | `0.0000` | `1e-09` | OK |
| 115 | 310 | Summary of the Section | `11.2203` | mfpt_bound_explicit | `11.2203` | `11.220298` | OK |
| 116 | 310 | Summary of the Section | `443.7374` | mfpt_bound_explicit | `443.7374` | `443.737421` | OK |
| 117 | 310 | Summary of the Section | `0.562` | cr_ide_solver | `0.562` | `0.562375` | OK |
| 118 | 310 | Summary of the Section | `3.14` | - | `3.14` | `-` |  |
| 119 | 310 | Summary of the Section | `11.2453` | dt_convergence | `11.2453` | `11.2453` | OK |
| 120 | 310 | Summary of the Section | `1\%` | fee_specification_net | `1\%` | `1.0` | OK |
| 121 | 344 | Tucker Decomposition | `3.4247` | tucker_analysis | `3.4247` | `3.4247` | OK |
| 122 | 344 | Tucker Decomposition | `70.8` | tucker_analysis | `70.8` | `70.8` | OK |
| 123 | 362 | Reconstruction Error | `73.068` | tucker_analysis | `73.068` | `73.0680` | OK |
| 124 | 362 | Reconstruction Error | `0.000` | fee_specification_net | `0.000` | `1e-09` | OK |
| 125 | 362 | Reconstruction Error | `4.8` | calibration_heavy_tail | `4.8` | `4.75` | OK |
| 126 | 363 | Reconstruction Error | `0.05` | fee_specification_net | `0.05` | `0.0500` | OK |
| 127 | 363 | Reconstruction Error | `45.261` | tucker_analysis | `45.261` | `45.2608` | OK |
| 128 | 363 | Reconstruction Error | `0.993` | tucker_analysis | `0.993` | `0.9926` | OK |
| 129 | 363 | Reconstruction Error | `2.19` | tucker_analysis | `2.19` | `2.1931` | OK |
| 130 | 364 | Reconstruction Error | `6.407` | tucker_analysis | `6.407` | `6.4067` | OK |
| 131 | 364 | Reconstruction Error | `5.493` | tucker_analysis | `5.493` | `5.4929` | OK |
| 132 | 364 | Reconstruction Error | `85.74` | tucker_analysis | `85.74` | `85.7366` | OK |
| 133 | 365 | Reconstruction Error | `6.775` | tucker_analysis | `6.775` | `6.7754` | OK |
| 134 | 365 | Reconstruction Error | `3.559` | tucker_analysis | `3.559` | `3.5589` | OK |
| 135 | 365 | Reconstruction Error | `52.53` | tucker_analysis | `52.53` | `52.5270` | OK |
| 136 | 372 | Reconstruction Error | `4.8` | calibration_heavy_tail | `4.8` | `4.75` | OK |
| 137 | 376 | Reconstruction Error | `52.53` | tucker_analysis | `52.53` | `52.5270` | OK |
| 138 | 389 | Error Versus Rank | `16.13` | tucker_analysis | `16.13` | `16.1290` | OK |
| 139 | 389 | Error Versus Rank | `5.02` | tucker_analysis | `5.02` | `5.0228` | OK |
| 140 | 390 | Error Versus Rank | `7.35` | tucker_analysis | `7.35` | `7.3529` | OK |
| 141 | 390 | Error Versus Rank | `3.24` | tucker_analysis | `3.24` | `3.2426` | OK |
| 142 | 391 | Error Versus Rank | `4.27` | tucker_analysis | `4.27` | `4.2735` | OK |
| 143 | 391 | Error Versus Rank | `2.32` | tucker_analysis | `2.32` | `2.3221` | OK |
| 144 | 392 | Error Versus Rank | `3.42` | tucker_analysis | `3.42` | `3.4247` | OK |
| 145 | 392 | Error Versus Rank | `2.19` | tucker_analysis | `2.19` | `2.1931` | OK |
| 146 | 393 | Error Versus Rank | `1.82` | tucker_analysis | `1.82` | `1.8182` | OK |
| 147 | 393 | Error Versus Rank | `1.52` | tucker_analysis | `1.52` | `1.5180` | OK |
| 148 | 405 | Tucker Is Not in the Security Path | `3.42` | tucker_analysis | `3.42` | `3.4247` | OK |
| 149 | 407 | Tucker Is Not in the Security Path | `3.4247` | tucker_analysis | `3.4247` | `3.4247` | OK |
| 150 | 419 | Summary of the Section | `85.7` | tucker_analysis | `85.7` | `85.7366` | OK |
| 151 | 420 | Summary of the Section | `52.5` | tucker_analysis | `52.5` | `52.5270` | OK |
| 152 | 441 | Circuit Specification | `0.5` | cr_ide_solver | `0.5` | `0.5` | OK |
| 153 | 457 | Soundness Failure | `0.223607` | soundness_zk_check | `0.223607` | `0.223607` | OK |
| 154 | 457 | Soundness Failure | `0.5` | cr_ide_solver | `0.5` | `0.5` | OK |
| 155 | 458 | Soundness Failure | `1.000000` | fee_specification_net | `1.000000` | `1.0` | OK |
| 156 | 458 | Soundness Failure | `0.5` | cr_ide_solver | `0.5` | `0.5` | OK |
| 157 | 488 | Repair Options | `0.20` | fee_specification_net | `0.20` | `0.2` | OK |
| 158 | 489 | Repair Options | `0.20` | fee_specification_net | `0.20` | `0.2` | OK |
| 159 | 490 | Repair Options | `0.20` | fee_specification_net | `0.20` | `0.2` | OK |
| 160 | 491 | Repair Options | `0.72` | threshold_quantization | `0.72` | `0.72` | OK |
| 161 | 491 | Repair Options | `6.5` | - | `6.5` | `-` |  |
| 162 | 507 | Repair Options | `1.08` | - | `1.08` | `-` |  |
| 163 | 511 | Repair Options | `0.72` | threshold_quantization | `0.72` | `0.72` | OK |
| 164 | 511 | Repair Options | `6.5` | - | `6.5` | `-` |  |
| 165 | 517 | Recursive Verification | `6.5` | - | `6.5` | `-` |  |
| 166 | 533 | Succinctness and the Cost of Ingesting the Tensor | `3.3` | benchmark_output_v2 | `3.3` | `-` |  |
| 167 | 533 | Succinctness and the Cost of Ingesting the Tensor | `2.7` | benchmark_output_v2 | `2.7` | `2.7174` | OK |
| 168 | 533 | Succinctness and the Cost of Ingesting the Tensor | `6.5` | benchmark_output_v2 | `6.5` | `-` |  |
| 169 | 538 | Estimates and Their Provenance | `0.72` | benchmark_output_v2 | `0.72` | `0.72` | OK |
| 170 | 540 | Estimates and Their Provenance | `0.223607` | soundness_zk_check | `0.223607` | `0.223607` | OK |
| 171 | 540 | Estimates and Their Provenance | `1.000000` | fee_specification_net | `1.000000` | `1.0` | OK |
| 172 | 552 | Summary of the Section | `1.08` | - | `1.08` | `-` |  |
| 173 | 553 | Summary of the Section | `2.4` | calibration_heavy_tail | `2.4` | `2.43` | OK |
| 174 | 554 | Summary of the Section | `0.72` | threshold_quantization | `0.72` | `0.72` | OK |
| 175 | 556 | Summary of the Section | `6.5` | - | `6.5` | `-` |  |
| 176 | 591 | The Normalization Problem | `27.2` | asym_weights | `27.2` | `27.2144` | OK |
| 177 | 591 | The Normalization Problem | `0.037` | - | `0.037` | `-` |  |
| 178 | 591 | The Normalization Problem | `20.0` | cr_ide_solver | `20.0` | `20.0` | OK |
| 179 | 591 | The Normalization Problem | `0.050` | fee_specification_net | `0.050` | `0.0500` | OK |
| 180 | 598 | The Normalization Problem | `27.2` | asym_weights | `27.2` | `27.2144` | OK |
| 181 | 599 | The Normalization Problem | `20.0` | cr_ide_solver | `20.0` | `20.0` | OK |
| 182 | 600 | The Normalization Problem | `27.2` | asym_weights | `27.2` | `27.2144` | OK |
| 183 | 600 | The Normalization Problem | `0.037` | - | `0.037` | `-` |  |
| 184 | 601 | The Normalization Problem | `20.0` | cr_ide_solver | `20.0` | `20.0` | OK |
| 185 | 601 | The Normalization Problem | `0.050` | fee_specification_net | `0.050` | `0.0500` | OK |
| 186 | 606 | The Normalization Problem | `10.0000` | asym_weights | `10.0000` | `10` | OK |
| 187 | 606 | The Normalization Problem | `7.4478` | asym_weights | `7.4478` | `7.4478` | OK |
| 188 | 606 | The Normalization Problem | `27.214` | asym_weights | `27.214` | `27.2144` | OK |
| 189 | 606 | The Normalization Problem | `10.1343` | asym_weights | `10.1343` | `10.1343` | OK |
| 190 | 616 | The Normalization Problem | `8.6896` | clique_spectra | `8.6896` | `8.6896` | OK |
| 191 | 616 | The Normalization Problem | `10.6439` | clique_spectra | `10.6439` | `10.6439` | OK |
| 192 | 616 | The Normalization Problem | `8.9443` | clique_spectra | `8.9443` | `8.9443` | OK |
| 193 | 616 | The Normalization Problem | `1.6996` | clique_spectra | `1.6996` | `1.6996` | OK |
| 194 | 617 | The Normalization Problem | `0.4254` | clique_spectra | `0.4254` | `0.4254` | OK |
| 195 | 617 | The Normalization Problem | `0.4316` | clique_spectra | `0.4316` | `0.4316` | OK |
| 196 | 617 | The Normalization Problem | `0.4472` | clique_spectra | `0.4472` | `0.4472` | OK |
| 197 | 617 | The Normalization Problem | `0.0156` | clique_spectra | `0.0156` | `0.0156` | OK |
| 198 | 618 | The Normalization Problem | `8.6896` | clique_spectra | `8.6896` | `8.6896` | OK |
| 199 | 618 | The Normalization Problem | `10.7011` | clique_spectra | `10.7011` | `10.7011` | OK |
| 200 | 618 | The Normalization Problem | `8.9443` | clique_spectra | `8.9443` | `8.9443` | OK |
| 201 | 618 | The Normalization Problem | `1.7569` | clique_spectra | `1.7569` | `1.7569` | OK |
| 202 | 623 | The Normalization Problem | `0.73` | clique_spectra_seeds | `0.73` | `0.73` | OK |
| 203 | 623 | The Normalization Problem | `0.39` | clique_spectra_seeds | `0.39` | `0.39` | OK |
| 204 | 623 | The Normalization Problem | `0.02` | clique_spectra_seeds | `0.02` | `0.02` | OK |
| 205 | 623 | The Normalization Problem | `0.01` | clique_spectra_seeds | `0.01` | `0.01` | OK |
| 206 | 623 | The Normalization Problem | `0.77` | clique_spectra_seeds | `0.77` | `0.77` | OK |
| 207 | 623 | The Normalization Problem | `0.41` | clique_spectra_seeds | `0.41` | `0.41` | OK |
| 208 | 623 | The Normalization Problem | `0.0353` | clique_spectra_seeds | `0.0353` | `0.0353` | OK |
| 209 | 627 | The Normalization Problem | `1.6996` | clique_spectra | `1.6996` | `1.6996` | OK |
| 210 | 627 | The Normalization Problem | `8.9443` | clique_spectra | `8.9443` | `8.9443` | OK |
| 211 | 627 | The Normalization Problem | `0.0156` | clique_spectra | `0.0156` | `0.0156` | OK |
| 212 | 627 | The Normalization Problem | `0.4472` | clique_spectra | `0.4472` | `0.4472` | OK |
| 213 | 627 | The Normalization Problem | `1.7569` | clique_spectra | `1.7569` | `1.7569` | OK |
| 214 | 627 | The Normalization Problem | `1.6996` | clique_spectra | `1.6996` | `1.6996` | OK |
| 215 | 627 | The Normalization Problem | `9.0542` | calibration_heavy_tail | `9.0542` | `9.0542` | OK |
| 216 | 629 | The Normalization Problem | `19.88` | clique_spectra | `19.88` | `19.88` | OK |
| 217 | 629 | The Normalization Problem | `4.22` | clique_spectra | `4.22` | `4.22` | OK |
| 218 | 661 | Null Distribution and Calibration | `8.7679` | max_statistic | `8.7679` | `8.7679` | OK |
| 219 | 661 | Null Distribution and Calibration | `0.1115` | max_statistic | `0.1115` | `0.1115` | OK |
| 220 | 661 | Null Distribution and Calibration | `9.0542` | calibration_heavy_tail | `9.0542` | `9.0542` | OK |
| 221 | 662 | Null Distribution and Calibration | `8.8601` | bipartite_power | `8.8601` | `8.8601` | OK |
| 222 | 662 | Null Distribution and Calibration | `0.1101` | bipartite_power | `0.1101` | `0.1101` | OK |
| 223 | 662 | Null Distribution and Calibration | `9.1371` | bipartite_power | `9.1371` | `9.1371` | OK |
| 224 | 675 | Null Distribution and Calibration | `0.01` | fee_specification_net | `0.01` | `0.01` | OK |
| 225 | 675 | Null Distribution and Calibration | `9.0542` | calibration_heavy_tail | `9.0542` | `9.0542` | OK |
| 226 | 675 | Null Distribution and Calibration | `9.1371` | bipartite_power | `9.1371` | `9.1371` | OK |
| 227 | 676 | Null Distribution and Calibration | `0.05` | fee_specification_net | `0.05` | `0.0500` | OK |
| 228 | 676 | Null Distribution and Calibration | `8.9663` | calibration_modularity | `8.9663` | `8.9663` | OK |
| 229 | 676 | Null Distribution and Calibration | `9.0428` | bipartite_power | `9.0428` | `9.0428` | OK |
| 230 | 681 | Null Distribution and Calibration | `9.0542` | calibration_heavy_tail | `9.0542` | `9.0542` | OK |
| 231 | 681 | Null Distribution and Calibration | `2.57` | q99_standard_error | `2.57` | `2.567713` | OK |
| 232 | 681 | Null Distribution and Calibration | `9.1371` | bipartite_power | `9.1371` | `9.1371` | OK |
| 233 | 681 | Null Distribution and Calibration | `2.52` | - | `2.52` | `-` |  |
| 234 | 683 | Null Distribution and Calibration | `17.5` | calibration_heavy_tail | `17.5` | `17.5172` | OK |
| 235 | 683 | Null Distribution and Calibration | `8.5` | calibration_heavy_tail | `8.5` | `-` |  |
| 236 | 685 | Null Distribution and Calibration | `1.0` | calibration_heavy_tail | `1.0` | `1` | OK |
| 237 | 685 | Null Distribution and Calibration | `0.01` | calibration_heavy_tail | `0.01` | `0.01` | OK |
| 238 | 685 | Null Distribution and Calibration | `2.1` | calibration_heavy_tail | `2.1` | `2.10` | OK |
| 239 | 685 | Null Distribution and Calibration | `2.3` | calibration_heavy_tail | `2.3` | `2.30` | OK |
| 240 | 685 | Null Distribution and Calibration | `2.5` | calibration_heavy_tail | `2.5` | `2.50` | OK |
| 241 | 685 | Null Distribution and Calibration | `3.0` | calibration_heavy_tail | `3.0` | `3.02` | OK |
| 242 | 685 | Null Distribution and Calibration | `0.000` | calibration_heavy_tail | `0.000` | `0` | OK |
| 243 | 685 | Null Distribution and Calibration | `2.3` | calibration_heavy_tail | `2.3` | `2.30` | OK |
| 244 | 685 | Null Distribution and Calibration | `0.155` | calibration_heavy_tail | `0.155` | `0.155` | OK |
| 245 | 685 | Null Distribution and Calibration | `3.0` | calibration_heavy_tail | `3.0` | `3.02` | OK |
| 246 | 685 | Null Distribution and Calibration | `9.20` | calibration_heavy_tail | `9.20` | `9.1957` | OK |
| 247 | 685 | Null Distribution and Calibration | `1.0` | calibration_heavy_tail | `1.0` | `1` | OK |
| 248 | 685 | Null Distribution and Calibration | `2.1` | calibration_heavy_tail | `2.1` | `2.10` | OK |
| 249 | 685 | Null Distribution and Calibration | `2.3` | calibration_heavy_tail | `2.3` | `2.30` | OK |
| 250 | 685 | Null Distribution and Calibration | `2.5` | calibration_heavy_tail | `2.5` | `2.50` | OK |
| 251 | 685 | Null Distribution and Calibration | `3.0` | calibration_heavy_tail | `3.0` | `3.02` | OK |
| 252 | 685 | Null Distribution and Calibration | `2.1` | calibration_heavy_tail | `2.1` | `2.10` | OK |
| 253 | 685 | Null Distribution and Calibration | `4\%` | calibration_heavy_tail | `4\%` | `3.9628` | OK |
| 254 | 685 | Null Distribution and Calibration | `1.000` | calibration_heavy_tail | `1.000` | `1` | OK |
| 255 | 685 | Null Distribution and Calibration | `0.085` | calibration_heavy_tail | `0.085` | `0.085` | OK |
| 256 | 688 | Detection Power | `95\%` | calibration_modularity | `95\%` | `95` | OK |
| 257 | 694 | Detection Power | `0.01` | fee_specification_net | `0.01` | `0.01` | OK |
| 258 | 694 | Detection Power | `95\%` | attacker_profit_analytical | `95\%` | `95` | OK |
| 259 | 696 | Detection Power | `9.7452` | calibration_modularity | `9.7452` | `9.7452` | OK |
| 260 | 696 | Detection Power | `0.972` | mfpt_jump_diffusion | `0.972` | `0.9725` | OK |
| 261 | 696 | Detection Power | `0.954` | wilson_intervals | `0.954` | `0.9536` | OK |
| 262 | 696 | Detection Power | `0.983` | wilson_intervals | `0.983` | `0.9832` | OK |
| 263 | 697 | Detection Power | `10.2714` | calibration_modularity | `10.2714` | `10.2714` | OK |
| 264 | 697 | Detection Power | `1.000` | fee_specification_net | `1.000` | `1.0` | OK |
| 265 | 697 | Detection Power | `0.992` | compare_reputation_models | `0.992` | `0.9920` | OK |
| 266 | 697 | Detection Power | `1.000` | fee_specification_net | `1.000` | `1.0` | OK |
| 267 | 698 | Detection Power | `10.5294` | calibration_modularity | `10.5294` | `10.5294` | OK |
| 268 | 698 | Detection Power | `1.000` | fee_specification_net | `1.000` | `1.0` | OK |
| 269 | 698 | Detection Power | `0.992` | compare_reputation_models | `0.992` | `0.9920` | OK |
| 270 | 698 | Detection Power | `1.000` | fee_specification_net | `1.000` | `1.0` | OK |
| 271 | 699 | Detection Power | `14.2441` | calibration_modularity | `14.2441` | `14.2441` | OK |
| 272 | 699 | Detection Power | `1.000` | fee_specification_net | `1.000` | `1.0` | OK |
| 273 | 699 | Detection Power | `0.992` | compare_reputation_models | `0.992` | `0.9920` | OK |
| 274 | 699 | Detection Power | `1.000` | fee_specification_net | `1.000` | `1.0` | OK |
| 275 | 700 | Detection Power | `16.2281` | calibration_modularity | `16.2281` | `16.2281` | OK |
| 276 | 700 | Detection Power | `1.000` | fee_specification_net | `1.000` | `1.0` | OK |
| 277 | 700 | Detection Power | `0.992` | compare_reputation_models | `0.992` | `0.9920` | OK |
| 278 | 700 | Detection Power | `1.000` | fee_specification_net | `1.000` | `1.0` | OK |
| 279 | 705 | Detection Power | `0.972` | mfpt_jump_diffusion | `0.972` | `0.9725` | OK |
| 280 | 705 | Detection Power | `1.000` | fee_specification_net | `1.000` | `1.0` | OK |
| 281 | 707 | Detection Power | `97.2` | - | `97.2` | `-` |  |
| 282 | 707 | Detection Power | `100\%` | attacker_profit_analytical | `100\%` | `100` | OK |
| 283 | 709 | Detection Power | `0.972` | mfpt_jump_diffusion | `0.972` | `0.9725` | OK |
| 284 | 709 | Detection Power | `95\%` | attacker_profit_analytical | `95\%` | `95` | OK |
| 285 | 709 | Detection Power | `0.954` | wilson_intervals | `0.954` | `0.9536` | OK |
| 286 | 709 | Detection Power | `0.983` | wilson_intervals | `0.983` | `0.9832` | OK |
| 287 | 709 | Detection Power | `0.9` | cr_ide_solver | `0.9` | `0.925926` | OK |
| 288 | 711 | Detection Power | `0.033` | r_std_specification | `0.033` | `0.033499` | OK |
| 289 | 711 | Detection Power | `0.01` | fee_specification_net | `0.01` | `0.01` | OK |
| 290 | 711 | Detection Power | `0.972` | mfpt_jump_diffusion | `0.972` | `0.9725` | OK |
| 291 | 711 | Detection Power | `29.2` | wilson_intervals | `29.2` | `29.16` | OK |
| 292 | 713 | Detection Power | `95\%` | wilson_intervals | `95\%` | `95` | OK |
| 293 | 713 | Detection Power | `0.006` | wilson_intervals | `0.006` | `0.0059` | OK |
| 294 | 713 | Detection Power | `0.167` | wilson_intervals | `0.167` | `0.1667` | OK |
| 295 | 713 | Detection Power | `0.954` | wilson_intervals | `0.954` | `0.9536` | OK |
| 296 | 713 | Detection Power | `0.983` | wilson_intervals | `0.983` | `0.9832` | OK |
| 297 | 713 | Detection Power | `95\%` | wilson_intervals | `95\%` | `95` | OK |
| 298 | 716 | The Detection Boundary | `0.97` | wilson_intervals | `0.97` | `0.9720` | OK |
| 299 | 718 | The Detection Boundary | `1.5` | cr_ide_solver | `1.5` | `1.549826` | OK |
| 300 | 720 | The Detection Boundary | `0.972` | mfpt_jump_diffusion | `0.972` | `0.9725` | OK |
| 301 | 729 | Limitations | `0.990` | bipartite_power | `0.990` | `0.990` | OK |
| 302 | 729 | Limitations | `1.000` | bipartite_power | `1.000` | `1` | OK |
| 303 | 742 | Summary of the Section | `9.0542` | calibration_heavy_tail | `9.0542` | `9.0542` | OK |
| 304 | 743 | Summary of the Section | `0.972` | mfpt_jump_diffusion | `0.972` | `0.9725` | OK |
| 305 | 744 | Summary of the Section | `1.000` | fee_specification_net | `1.000` | `1.0` | OK |
| 306 | 745 | Summary of the Section | `1.000` | fee_specification_net | `1.000` | `1.0` | OK |
| 307 | 746 | Summary of the Section | `29.2` | wilson_intervals | `29.2` | `29.16` | OK |
| 308 | 789 | Private Cost of Capital | `0.8` | financial_floor_sensitivity | `0.8` | `0.8` | OK |
| 309 | 789 | Private Cost of Capital | `0.8` | financial_floor_sensitivity | `0.8` | `0.8` | OK |
| 310 | 789 | Private Cost of Capital | `1.0` | financial_floor_sensitivity | `1.0` | `1.0` | OK |
| 311 | 789 | Private Cost of Capital | `0.8` | financial_floor_sensitivity | `0.8` | `0.8` | OK |
| 312 | 789 | Private Cost of Capital | `0.2` | financial_floor_sensitivity | `0.2` | `0.200` | OK |
| 313 | 789 | Private Cost of Capital | `0.2` | financial_floor_sensitivity | `0.2` | `0.200` | OK |
| 314 | 789 | Private Cost of Capital | `0.5` | financial_floor_sensitivity | `0.5` | `0.5` | OK |
| 315 | 789 | Private Cost of Capital | `1.0` | financial_floor_sensitivity | `1.0` | `1.0` | OK |
| 316 | 789 | Private Cost of Capital | `0.0` | financial_floor_sensitivity | `0.0` | `0.00` | OK |
| 317 | 789 | Private Cost of Capital | `0.5` | financial_floor_sensitivity | `0.5` | `0.5` | OK |
| 318 | 789 | Private Cost of Capital | `0.2` | financial_floor_sensitivity | `0.2` | `0.200` | OK |
| 319 | 789 | Private Cost of Capital | `0.8` | financial_floor_sensitivity | `0.8` | `0.8` | OK |
| 320 | 789 | Private Cost of Capital | `80\%` | financial_floor_sensitivity | `80\%` | `80` | OK |
| 321 | 819 | The Uniform Posted Price | `0.15` | fee_specification_net | `0.15` | `0.15` | OK |
| 322 | 819 | The Uniform Posted Price | `0.10` | fee_specification_net | `0.10` | `0.1` | OK |
| 323 | 819 | The Uniform Posted Price | `1.0` | fee_specification_net | `1.0` | `1.0` | OK |
| 324 | 822 | The Uniform Posted Price | `0.15` | fee_specification_net | `0.15` | `0.15` | OK |
| 325 | 822 | The Uniform Posted Price | `0.10` | fee_specification_net | `0.10` | `0.1` | OK |
| 326 | 822 | The Uniform Posted Price | `1.0` | fee_specification_net | `1.0` | `1.0` | OK |
| 327 | 822 | The Uniform Posted Price | `0.0500` | fee_specification_net | `0.0500` | `0.0500` | OK |
| 328 | 831 | Individual Rationality | `0.01` | fee_specification | `0.01` | `0.01` | OK |
| 329 | 831 | Individual Rationality | `0.10` | fee_specification | `0.10` | `0.1` | OK |
| 330 | 831 | Individual Rationality | `0.6` | fee_specification | `0.6` | `0.555556` | OK |
| 331 | 838 | Individual Rationality | `0.009747` | fee_specification_net | `0.009747` | `0.009747` | OK |
| 332 | 839 | Individual Rationality | `0.069152` | fee_specification | `0.069152` | `0.069152` | OK |
| 333 | 840 | Individual Rationality | `0.095891` | fee_specification | `0.095891` | `0.095891` | OK |
| 334 | 841 | Individual Rationality | `1.0000` | fee_specification_net | `1.0000` | `1.0` | OK |
| 335 | 846 | Individual Rationality | `0.009747` | fee_specification_net | `0.009747` | `0.009747` | OK |
| 336 | 846 | Individual Rationality | `0.10` | fee_specification_net | `0.10` | `0.1` | OK |
| 337 | 856 | Sensitivity | `0.025` | fee_specification_net | `0.025` | `0.0250` | OK |
| 338 | 856 | Sensitivity | `0.0000` | fee_specification_net | `0.0000` | `1e-09` | OK |
| 339 | 856 | Sensitivity | `25.00` | fee_specification_net | `25.00` | `25.00` | OK |
| 340 | 856 | Sensitivity | `25.00` | fee_specification_net | `25.00` | `25.00` | OK |
| 341 | 857 | Sensitivity | `0.040` | fee_specification_net | `0.040` | `0.0400` | OK |
| 342 | 857 | Sensitivity | `0.0000` | fee_specification_net | `0.0000` | `1e-09` | OK |
| 343 | 857 | Sensitivity | `40.00` | fee_specification_net | `40.00` | `40.00` | OK |
| 344 | 857 | Sensitivity | `40.00` | fee_specification_net | `40.00` | `40.00` | OK |
| 345 | 858 | Sensitivity | `0.050` | fee_specification_net | `0.050` | `0.0500` | OK |
| 346 | 858 | Sensitivity | `0.0000` | fee_specification_net | `0.0000` | `1e-09` | OK |
| 347 | 858 | Sensitivity | `50.00` | fee_specification_net | `50.00` | `50.00` | OK |
| 348 | 858 | Sensitivity | `50.00` | fee_specification_net | `50.00` | `50.00` | OK |
| 349 | 859 | Sensitivity | `0.060` | fee_specification_net | `0.060` | `0.0600` | OK |
| 350 | 859 | Sensitivity | `0.0020` | fee_specification_net | `0.0020` | `0.0020` | OK |
| 351 | 859 | Sensitivity | `60.00` | fee_specification_net | `60.00` | `60.00` | OK |
| 352 | 859 | Sensitivity | `59.88` | fee_specification_net | `59.88` | `59.88` | OK |
| 353 | 864 | Sensitivity | `0.06` | fee_specification_net | `0.06` | `0.0600` | OK |
| 354 | 864 | Sensitivity | `20\%` | cr_ide_solver | `20\%` | `20.0` | OK |
| 355 | 864 | Sensitivity | `0.2` | fee_specification_net | `0.2` | `0.15` | OK |
| 356 | 864 | Sensitivity | `0.06` | fee_specification_net | `0.06` | `0.0600` | OK |
| 357 | 864 | Sensitivity | `59.88` | fee_specification_net | `59.88` | `59.88` | OK |
| 358 | 864 | Sensitivity | `60.00` | fee_specification_net | `60.00` | `60.00` | OK |
| 359 | 880 | Summary of the Section | `0.2` | fee_specification_net | `0.2` | `0.15` | OK |
| 360 | 884 | Summary of the Section | `1.2` | fee_specification_net | `1.2` | `1.2` | OK |
| 361 | 884 | Summary of the Section | `0.2` | fee_specification_net | `0.2` | `0.15` | OK |
| 362 | 941 | Numerical Verification | `0.10` | simulate_data_layer_v3 | `0.10` | `0.1` | OK |
| 363 | 941 | Numerical Verification | `0.10` | simulate_data_layer_v3 | `0.10` | `0.1` | OK |
| 364 | 941 | Numerical Verification | `1.0` | simulate_data_layer_v3 | `1.0` | `1.0000` | OK |
| 365 | 941 | Numerical Verification | `10.0` | simulate_data_layer_v3 | `10.0` | `10.00` | OK |
| 366 | 941 | Numerical Verification | `0.10` | simulate_data_layer_v3 | `0.10` | `0.1` | OK |
| 367 | 941 | Numerical Verification | `0.10` | simulate_data_layer_v3 | `0.10` | `0.1` | OK |
| 368 | 941 | Numerical Verification | `1.0` | simulate_data_layer_v3 | `1.0` | `1.0000` | OK |
| 369 | 949 | Numerical Verification | `0.75` | simulate_data_layer_v3 | `0.75` | `0.75` | OK |
| 370 | 949 | Numerical Verification | `0.000` | fee_specification_net | `0.000` | `1e-09` | OK |
| 371 | 949 | Numerical Verification | `49.91` | simulate_data_layer_v3 | `49.91` | `49.91` | OK |
| 372 | 949 | Numerical Verification | `0.00` | fee_specification_net | `0.00` | `1e-09` | OK |
| 373 | 949 | Numerical Verification | `0.9002` | simulate_data_layer_v3 | `0.9002` | `0.9002` | OK |
| 374 | 950 | Numerical Verification | `1.00` | fee_specification_net | `1.00` | `1.0` | OK |
| 375 | 950 | Numerical Verification | `1.000` | fee_specification_net | `1.000` | `1.0` | OK |
| 376 | 950 | Numerical Verification | `502.00` | attacker_profit_analytical | `502.00` | `502.000000` | OK |
| 377 | 950 | Numerical Verification | `0.20` | fee_specification_net | `0.20` | `0.2` | OK |
| 378 | 950 | Numerical Verification | `1.0000` | fee_specification_net | `1.0000` | `1.0` | OK |
| 379 | 951 | Numerical Verification | `2.00` | fee_specification_net | `2.00` | `2` | OK |
| 380 | 951 | Numerical Verification | `1.000` | fee_specification_net | `1.000` | `1.0` | OK |
| 381 | 951 | Numerical Verification | `502.00` | attacker_profit_analytical | `502.00` | `502.000000` | OK |
| 382 | 951 | Numerical Verification | `0.20` | fee_specification_net | `0.20` | `0.2` | OK |
| 383 | 951 | Numerical Verification | `1.0000` | fee_specification_net | `1.0000` | `1.0` | OK |
| 384 | 952 | Numerical Verification | `5.00` | cr_ide_solver | `5.00` | `5.0` | OK |
| 385 | 952 | Numerical Verification | `1.000` | fee_specification_net | `1.000` | `1.0` | OK |
| 386 | 952 | Numerical Verification | `502.00` | attacker_profit_analytical | `502.00` | `502.000000` | OK |
| 387 | 952 | Numerical Verification | `0.20` | fee_specification_net | `0.20` | `0.2` | OK |
| 388 | 952 | Numerical Verification | `1.0000` | fee_specification_net | `1.0000` | `1.0` | OK |
| 389 | 953 | Numerical Verification | `10.00` | cr_ide_solver | `10.00` | `10.0` | OK |
| 390 | 953 | Numerical Verification | `1.000` | fee_specification_net | `1.000` | `1.0` | OK |
| 391 | 953 | Numerical Verification | `502.00` | attacker_profit_analytical | `502.00` | `502.000000` | OK |
| 392 | 953 | Numerical Verification | `0.20` | fee_specification_net | `0.20` | `0.2` | OK |
| 393 | 953 | Numerical Verification | `1.0000` | fee_specification_net | `1.0000` | `1.0` | OK |
| 394 | 954 | Numerical Verification | `20.00` | cr_ide_solver | `20.00` | `20.0` | OK |
| 395 | 954 | Numerical Verification | `1.000` | fee_specification_net | `1.000` | `1.0` | OK |
| 396 | 954 | Numerical Verification | `502.00` | attacker_profit_analytical | `502.00` | `502.000000` | OK |
| 397 | 954 | Numerical Verification | `0.20` | fee_specification_net | `0.20` | `0.2` | OK |
| 398 | 954 | Numerical Verification | `1.0000` | fee_specification_net | `1.0000` | `1.0` | OK |
| 399 | 959 | Numerical Verification | `100\%` | attacker_profit_analytical | `100\%` | `100` | OK |
| 400 | 961 | Numerical Verification | `0.20` | fee_specification_net | `0.20` | `0.2` | OK |
| 401 | 961 | Numerical Verification | `50.2` | attacker_profit_analytical | `50.2` | `50.200000` | OK |
| 402 | 961 | Numerical Verification | `50.0` | fee_specification_net | `50.0` | `50.00` | OK |
| 403 | 961 | Numerical Verification | `0.2` | fee_specification_net | `0.2` | `0.15` | OK |
| 404 | 961 | Numerical Verification | `0.20` | fee_specification_net | `0.20` | `0.2` | OK |
| 405 | 964 | Slashing and Integrity | `10.0` | cr_ide_solver | `10.0` | `10.0` | OK |
| 406 | 964 | Slashing and Integrity | `1.0` | fee_specification_net | `1.0` | `1.0` | OK |
| 407 | 976 | Freshness as Second Line of Defense | `0.10` | fee_specification_net | `0.10` | `0.1` | OK |
| 408 | 976 | Freshness as Second Line of Defense | `1.0` | fee_specification_net | `1.0` | `1.0` | OK |
| 409 | 976 | Freshness as Second Line of Defense | `0.05` | fee_specification_net | `0.05` | `0.0500` | OK |
| 410 | 976 | Freshness as Second Line of Defense | `0.5` | cr_ide_solver | `0.5` | `0.5` | OK |
| 411 | 988 | Summary of the Section | `1.0` | fee_specification_net | `1.0` | `1.0` | OK |
| 412 | 1029 | Reputation Models | `0.8` | compare_reputation_models | `0.8` | `0.8329` | OK |
| 413 | 1031 | Reputation Models | `0.76` | compare_reputation_models | `0.76` | `0.7599` | OK |
| 414 | 1031 | Reputation Models | `0.08` | compare_reputation_models | `0.08` | `0.0816` | OK |
| 415 | 1031 | Reputation Models | `0.11` | compare_reputation_models | `0.11` | `0.1128` | OK |
| 416 | 1033 | Reputation Models | `0.01` | sweep_net_gain | `0.01` | `0.01` | OK |
| 417 | 1033 | Reputation Models | `1.5` | sweep_net_gain | `1.5` | `1.50` | OK |
| 418 | 1033 | Reputation Models | `0.01` | sweep_net_gain | `0.01` | `0.01` | OK |
| 419 | 1033 | Reputation Models | `0.015` | sweep_net_gain | `0.015` | `0.015` | OK |
| 420 | 1042 | Bootstrap Simulation | `0.03` | threshold_quantization | `0.03` | `0.026403` | OK |
| 421 | 1043 | Bootstrap Simulation | `0.5` | cr_ide_solver | `0.5` | `0.5` | OK |
| 422 | 1062 | Results | `0.1283` | simulate_bootstrap_net_gain | `0.1283` | `0.1283` | OK |
| 423 | 1062 | Results | `0.1367` | simulate_bootstrap_net_gain | `0.1367` | `0.1367` | OK |
| 424 | 1062 | Results | `1.0000` | fee_specification_net | `1.0000` | `1.0` | OK |
| 425 | 1062 | Results | `0.3936` | simulate_bootstrap_net_gain | `0.3936` | `0.3936` | OK |
| 426 | 1062 | Results | `0.5976` | simulate_bootstrap_net_gain | `0.5976` | `0.5976` | OK |
| 427 | 1063 | Results | `0.1283` | simulate_bootstrap_net_gain | `0.1283` | `0.1283` | OK |
| 428 | 1063 | Results | `0.1367` | simulate_bootstrap_net_gain | `0.1367` | `0.1367` | OK |
| 429 | 1063 | Results | `0.7764` | simulate_bootstrap_net_gain | `0.7764` | `0.7764` | OK |
| 430 | 1063 | Results | `0.3936` | simulate_bootstrap_net_gain | `0.3936` | `0.3936` | OK |
| 431 | 1063 | Results | `0.5976` | simulate_bootstrap_net_gain | `0.5976` | `0.5976` | OK |
| 432 | 1064 | Results | `0.1563` | simulate_bootstrap_net_gain | `0.1563` | `0.1563` | OK |
| 433 | 1064 | Results | `0.1477` | simulate_bootstrap_net_gain | `0.1477` | `0.1477` | OK |
| 434 | 1064 | Results | `0.8393` | simulate_bootstrap_net_gain | `0.8393` | `0.8393` | OK |
| 435 | 1064 | Results | `0.2553` | simulate_bootstrap_net_gain | `0.2553` | `0.2553` | OK |
| 436 | 1064 | Results | `0.4348` | simulate_bootstrap_net_gain | `0.4348` | `0.4348` | OK |
| 437 | 1069 | Results | `1.0` | fee_specification_net | `1.0` | `1.0` | OK |
| 438 | 1069 | Results | `0.7764` | simulate_bootstrap_net_gain | `0.7764` | `0.7764` | OK |
| 439 | 1069 | Results | `22.4` | bipartite_power | `22.4` | `22.3561` | OK |
| 440 | 1069 | Results | `0.8393` | simulate_bootstrap_net_gain | `0.8393` | `0.8393` | OK |
| 441 | 1069 | Results | `16.1` | tucker_analysis | `16.1` | `16.1290` | OK |
| 442 | 1071 | Results | `0.4` | cr_ide_solver | `0.4` | `0.398195` | OK |
| 443 | 1071 | Results | `0.3936` | simulate_bootstrap_net_gain | `0.3936` | `0.3936` | OK |
| 444 | 1078 | Comparison of Policies | `0.1563` | simulate_bootstrap_net_gain | `0.1563` | `0.1563` | OK |
| 445 | 1078 | Comparison of Policies | `0.1283` | simulate_bootstrap_net_gain | `0.1283` | `0.1283` | OK |
| 446 | 1078 | Comparison of Policies | `0.5976` | simulate_bootstrap_net_gain | `0.5976` | `0.5976` | OK |
| 447 | 1078 | Comparison of Policies | `0.4348` | simulate_bootstrap_net_gain | `0.4348` | `0.4348` | OK |
| 448 | 1078 | Comparison of Policies | `0.6` | cr_ide_solver | `0.6` | `0.555556` | OK |
| 449 | 1078 | Comparison of Policies | `0.43` | clique_spectra | `0.43` | `0.4254` | OK |
| 450 | 1080 | Comparison of Policies | `0.1563` | simulate_bootstrap_net_gain | `0.1563` | `0.1563` | OK |
| 451 | 1080 | Comparison of Policies | `0.1283` | simulate_bootstrap_net_gain | `0.1283` | `0.1283` | OK |
| 452 | 1080 | Comparison of Policies | `0.8393` | simulate_bootstrap_net_gain | `0.8393` | `0.8393` | OK |
| 453 | 1080 | Comparison of Policies | `0.7764` | simulate_bootstrap_net_gain | `0.7764` | `0.7764` | OK |
| 454 | 1083 | Recommendation | `22.4` | bipartite_power | `22.4` | `22.3561` | OK |
| 455 | 1083 | Recommendation | `37\%` | heavy_tail_n5000 | `37\%` | `37.0298` | OK |
| 456 | 1083 | Recommendation | `0.4` | cr_ide_solver | `0.4` | `0.398195` | OK |
| 457 | 1085 | Recommendation | `77.6` | - | `77.6` | `-` |  |
| 458 | 1095 | Summary of the Section | `1.5` | cr_ide_solver | `1.5` | `1.549826` | OK |
| 459 | 1096 | Summary of the Section | `0.7764` | simulate_bootstrap_net_gain | `0.7764` | `0.7764` | OK |
| 460 | 1097 | Summary of the Section | `22.4` | bipartite_power | `22.4` | `22.3561` | OK |
| 461 | 1106 | Summary of the Section | `0.76` | cr_ide_solver | `0.76` | `0.761905` | OK |
| 462 | 1106 | Summary of the Section | `0.08` | threshold_quantization | `0.08` | `0.083333` | OK |
| 463 | 1106 | Summary of the Section | `0.11` | calibration_heavy_tail | `0.11` | `0.1107` | OK |
| 464 | 1106 | Summary of the Section | `0.0282` | r_std_specification | `0.0282` | `0.028156` | OK |
| 465 | 1106 | Summary of the Section | `5.0` | cr_ide_solver | `5.0` | `5.0` | OK |
| 466 | 1106 | Summary of the Section | `0.0424` | r_std_specification | `0.0424` | `0.042400` | OK |
| 467 | 1106 | Summary of the Section | `1.5` | cr_ide_solver | `1.5` | `1.549826` | OK |
| 468 | 1106 | Summary of the Section | `0.05` | fee_specification_net | `0.05` | `0.0500` | OK |
| 469 | 1168 | On-Chain Gas Costs | `6.5` | - | `6.5` | `-` |  |
| 470 | 1170 | On-Chain Gas Costs | `0.8` | cr_ide_solver | `0.8` | `0.8` | OK |
| 471 | 1175 | Stability of Conclusions | `0.22` | soundness_zk_check | `0.22` | `0.223607` | OK |
| 472 | 1177 | Stability of Conclusions | `9.0542` | calibration_heavy_tail | `9.0542` | `9.0542` | OK |
| 473 | 1177 | Stability of Conclusions | `2.568` | q99_standard_error | `2.568` | `2.567713` | OK |
| 474 | 1177 | Stability of Conclusions | `0.017` | q99_standard_error | `0.017` | `0.016802` | OK |
| 475 | 1177 | Stability of Conclusions | `0.186` | q99_standard_error | `0.186` | `0.1856` | OK |
| 476 | 1177 | Stability of Conclusions | `95\%` | attacker_profit_analytical | `95\%` | `95` | OK |
| 477 | 1177 | Stability of Conclusions | `9.021` | q99_standard_error | `9.021` | `9.021269` | OK |
| 478 | 1177 | Stability of Conclusions | `9.087` | q99_standard_error | `9.087` | `9.087131` | OK |
| 479 | 1177 | Stability of Conclusions | `2.326` | q99_standard_error | `2.326` | `2.326` | OK |
| 480 | 1177 | Stability of Conclusions | `0.103` | q99_standard_error | `0.103` | `0.1027` | OK |
| 481 | 1177 | Stability of Conclusions | `0.972` | mfpt_jump_diffusion | `0.972` | `0.9725` | OK |
| 482 | 1177 | Stability of Conclusions | `0.01` | fee_specification_net | `0.01` | `0.01` | OK |
| 483 | 1179 | Stability of Conclusions | `49.91` | simulate_data_layer_v3 | `49.91` | `49.91` | OK |
| 484 | 1181 | Stability of Conclusions | `0.3936` | simulate_bootstrap_net_gain | `0.3936` | `0.3936` | OK |
| 485 | 1181 | Stability of Conclusions | `0.4` | cr_ide_solver | `0.4` | `0.398195` | OK |
| 486 | 1181 | Stability of Conclusions | `1.5` | cr_ide_solver | `1.5` | `1.549826` | OK |
| 487 | 1203 | Summary of the Section | `6.5` | - | `6.5` | `-` |  |
| 488 | 1234 | Collusion Detection Boundary | `0.972` | mfpt_jump_diffusion | `0.972` | `0.9725` | OK |
| 489 | 1241 | Collusion by Bipartite Polarization | `9.1371` | bipartite_power | `9.1371` | `9.1371` | OK |
| 490 | 1241 | Collusion by Bipartite Polarization | `0.990` | bipartite_power | `0.990` | `0.990` | OK |
| 491 | 1241 | Collusion by Bipartite Polarization | `1.000` | bipartite_power | `1.000` | `1` | OK |
| 492 | 1253 | Reputation Model Selection | `0.76` | simulate_bootstrap_net_gain | `0.76` | `0.761905` | OK |
| 493 | 1253 | Reputation Model Selection | `0.08` | simulate_bootstrap_net_gain | `0.08` | `0.083333` | OK |
| 494 | 1253 | Reputation Model Selection | `0.11` | simulate_bootstrap_net_gain | `0.11` | `0.1107` | OK |
| 495 | 1253 | Reputation Model Selection | `0.0424` | simulate_bootstrap_net_gain | `0.0424` | `0.042400` | OK |
| 496 | 1253 | Reputation Model Selection | `1.5` | simulate_bootstrap_net_gain | `1.5` | `1.549826` | OK |
| 497 | 1253 | Reputation Model Selection | `0.043970` | simulate_bootstrap_net_gain | `0.043970` | `0.043970` | OK |
| 498 | 1253 | Reputation Model Selection | `95\%` | simulate_bootstrap_net_gain | `95\%` | `95` | OK |
| 499 | 1253 | Reputation Model Selection | `0.043351` | simulate_bootstrap_net_gain | `0.043351` | `0.043351` | OK |
| 500 | 1253 | Reputation Model Selection | `0.044588` | simulate_bootstrap_net_gain | `0.044588` | `0.044588` | OK |
| 501 | 1253 | Reputation Model Selection | `0.05` | simulate_bootstrap_net_gain | `0.05` | `0.0500` | OK |
| 502 | 1255 | Reputation Model Selection | `22.4` | simulate_bootstrap_net_gain | `22.4` | `22.3561` | OK |
| 503 | 1258 | Community Structure and Tucker Compression | `52.53` | simulate_bootstrap_net_gain | `52.53` | `52.5270` | OK |
| 504 | 1265 | Calibration on Synthetic Graphs | `9.0542` | calibration_heavy_tail | `9.0542` | `9.0542` | OK |
| 505 | 1265 | Calibration on Synthetic Graphs | `9.1371` | bipartite_power | `9.1371` | `9.1371` | OK |
| 506 | 1271 | Bootstrap Assumptions | `0.5` | cr_ide_solver | `0.5` | `0.5` | OK |
| 507 | 1272 | Bootstrap Assumptions | `0.03` | threshold_quantization | `0.03` | `0.026403` | OK |
| 508 | 1278 | Bootstrap Assumptions | `0.7764` | simulate_bootstrap_net_gain | `0.7764` | `0.7764` | OK |
| 509 | 1278 | Bootstrap Assumptions | `0.3936` | simulate_bootstrap_net_gain | `0.3936` | `0.3936` | OK |
| 510 | 1278 | Bootstrap Assumptions | `0.1283` | simulate_bootstrap_net_gain | `0.1283` | `0.1283` | OK |
| 511 | 1300 | Summary of the Section | `10.2` | - | `10.2` | `-` |  |
| 512 | 1301 | Summary of the Section | `10.2` | - | `10.2` | `-` |  |
| 513 | 1325 | Summary | `0.01` | fee_specification_net | `0.01` | `0.01` | OK |
| 514 | 1325 | Summary | `9.0542` | calibration_heavy_tail | `9.0542` | `9.0542` | OK |
| 515 | 1325 | Summary | `0.972` | mfpt_jump_diffusion | `0.972` | `0.9725` | OK |
| 516 | 1326 | Summary | `22.4` | bipartite_power | `22.4` | `22.3561` | OK |
| 517 | 1350 | Open Problems | `0.990` | q99_standard_error | `0.990` | `0.99` | OK |
| 518 | 1350 | Open Problems | `1.000` | fee_specification_net | `1.000` | `1.0` | OK |

_Total tokens: 518_

> Nota: la columna "Fuente (script)" es **heurística** (el `\fref{}` más cercano,
> o — si no hay — el primer output que contiene el valor). Cuando el `\fref`
> cercano y la coincidencia no apuntan al mismo script (p.ej. #515, #516), la
> etiqueta puede señalar un output coincidente distinto del productor real; la
> procedencia script-por-script la fijó el eje (i). La columna "Valor en output"
> es el número que redondea a la cifra del paper.

## Adjudicación de las 28 cifras sin match automático

| # | Línea | § | Cifra | Clase | Fuente / derivación |
|---|---|---|---|---|---|
| 23 | 202 | §2.3 | `1.415` | Sci-notation | `1.415225e+10` (mfpt_bound_explicit) |
| 24 | 202 | §2.3 | `3.14` | Sci-notation | `3.135455e-08` (mfpt_bound_explicit) |
| 31 | 209 | §2.3 | `3.19` | DERIVED | factor `3.1893e+07` (mfpt_bound_explicit) |
| 32 | 209 | §2.3 | `7.5` | DERIVED | log10(3.1893e7) = 7.50 |
| 34 | 209 | §2.3 | `3.14` | Sci-notation | `3.135455e-08` |
| 43 | 219 | §2.3 | `26.6` | DERIVED | (561.55 − 443.7374)/443.7374 = 26.55 % |
| 48 | 220 | §2.3 | `13.5` | DERIVED | (503.71 − 443.7374)/443.7374 = 13.52 % |
| 100 | 285 | §2.5 | `0.68` | DERIVED | 0.8 × 0.85 (coef. closed form `C_R(yr)`) |
| 104 | 287 | §2.5 | `0.68` | DERIVED | idem (eq. running-reward) |
| 118 | 310 | §2 sum | `3.14` | Sci-notation | `3.135455e-08` |
| 161 | 491 | §4.3 | `6.5` | Estimate | "6.5M gas" Bulletproofs (tabla: Estimated) |
| 162 | 507 | §4.3 | `1.08` | DERIVED | 1,080,501 / 10⁶ (soundness_zk_check) |
| 164 | 511 | §4.3 | `6.5` | Estimate | idem |
| 165 | 517 | §4.4 | `6.5` | Estimate | idem |
| 166 | 533 | §4.5 | `3.3` | DERIVED | 684,064 / 206,000 = 3.32 |
| 168 | 533 | §4.5 | `6.5` | Estimate | idem |
| 172 | 552 | §4 sum | `1.08` | DERIVED | 1,080,501 / 10⁶ |
| 175 | 556 | §4 sum | `6.5` | Estimate | idem |
| 177 | 591 | §5.1 | `0.037` | DERIVED | 1/27.2 = 0.0368 (asym_weights `d_bg = 27.2144`) |
| 183 | 600 | §5.1 | `0.037` | DERIVED | idem |
| 233 | 681 | §5.4 | `2.52` | DERIVED | (9.1371 − 8.8601)/0.1101 = 2.52σ (calibration_modularity) |
| 235 | 683 | §5.4 | `8.5` | **MISMATCH** | recalibrate_top `mean_s2 = 8.5617` → 8.6 |
| 281 | 707 | §5.5 | `97.2` | Unit | TPR 0.972 → 97.2 % (calibration_modularity) |
| 457 | 1085 | §8.3 | `77.6` | DERIVED | (1 − 0.224) × 100 (simulate_bootstrap_net_gain `0.776`) |
| 469 | 1168 | §9.3 | `6.5` | Estimate | idem |
| 487 | 1203 | §11 | `6.5` | Estimate | idem (tabla: Estimated) |
| 511 | 1300 | §11 | `10.2` | Ref | "Section 10.2" (referencia, no es cifra) |
| 512 | 1301 | §11 | `10.2` | Ref | idem |

## Hallazgo C-36 (minor) — §5.4, l.683: `s[-2] = 8.5` no redondea

El paper afirma: *"for a balanced two-block structure the signal is at
`s[-1] = 17.5` while `s[-2] = 8.5` sits inside the bulk."* La fuente
(F-018 → `recalibrate_top.py`) reporta, para la config assortativa 250/250
rho=10: `mean_s1 = 17.5172`, `mean_s2 = 8.5617`
(`recalibrate_top_output.txt` l.27).

- `17.5172` → `17.5` ✓ (redondeo a 1 decimal).
- `8.5617` → `8.6` (redondeo a 1 decimal); el paper escribe `8.5`.

El paper **redondea al alza** en el resto de casos (p.ej. `85.7366 → 85.74` y
`52.5270 → 52.53` en `tucker_analysis_output.txt` l.25/28), por lo que `8.5` es
incoherente con su propia convención: el valor correcto a 1 decimal es **8.6**.

Ningún output contiene un número en `[8.45, 8.55)`, así que `8.5` no procede de
una fuente alternativa: es truncamiento (o errata) de `8.5617`.

**Propuesta (una línea, `main.tex:727`):** `$s[-2] = 8.5$` → `$s[-2] = 8.6$`.

Severidad: minor — la afirmación es cualitativa ("sits inside the bulk") y el
error es de 0.1 en el último dígito; no cambia la conclusión. Requiere decisión
del autor: fue error del paper (fix `8.5 → 8.6`) o convención de truncamiento
declarada.

Nota: los ejes (i)/(ii) rozaron este punto en **C-29**, pero lo cerraron por
**atribución** (F-018 sí cita el script correcto) sin cuestionar el **valor**.
El eje (iv) caza exactamente esa clase de discrepancia.

## Lista MISSING (scripts citados sin output en el baseline)

- `integrations/avalanche/benchmarks/src/GasBenchmarks.sol` — no es un script de
  `verification/`; su salida vive en
  `integrations/avalanche/benchmark_output_v2.txt`. Documentado (eje i, C-31).
- `verification/rmt/archive/calibracion_rmt.py` — archivado (superseded); su
  output `archive/calibracion_rmt_output.txt` existe. Observación del eje (i).

No hay cifras del paper sin fuente identificable.

## Veredicto

El paper **reproduce fielmente** contra el baseline: **494 de 518** cifras
coinciden directamente con su output o por notación científica; las **24**
restantes se desglosan en 13 derivadas del output, 7 estimaciones declaradas,
1 conversión de unidades, 2 referencias de sección y **1 discrepancia de valor**
(C-36, `8.5` vs `8.6`, minor). Cero cifras huérfanas nuevas.

## Estado del árbol

```
HEAD  0cb4b34  docs(audit): mark the --resume hardening as applied (561e2cf)
?? docs/audit/eje-iv-crosscheck.py           (herramienta; untracked)
?? docs/audit/eje-iv-reproduction-report.md  (este informe; untracked hasta commit)
?? docs/audit/session-report.md              (untracked por convención)
?? verification/baseline_2026-10-06/         (baseline local; no se commitea)
```

`main.tex` sin cambios en este eje (C-36 pendiente de decisión).

