# Eje (ii) — Consistencia matemática

Fecha: 2026-10-06
HEAD previo al eje: `c75cda2` (`chore(verification): add baseline orchestrator`)
Alcance: simbología cuantitativa de `docs/paper/main.tex`. Solo inventario —
no se editó el paper en este eje.

## Metodología

1. Inventario de símbolos del modelo con
   `grep -noE '\\Theta[_a-zA-Z]*|\\sigma[_0-9a-zA-Z]*|\\lambda[_a-zA-Z]*|\\alpha|\\mu' docs/paper/main.tex`
   y volcado de macros con
   `grep -oE '\\[a-zA-Z]+\{[^}]*\}' docs/paper/main.tex | sort | uniq -c | sort -rn`.
2. Para cada símbolo se localizó su **primera definición** (§) y se listaron sus
   usos, buscando (a) un mismo símbolo con dos definiciones, o (b) un valor que
   contradiga la definición declarada.
3. Las cifras de cada tabla "Summary of the Section" se contrastaron contra su
   script (esto solapa con el eje (i)).

Conteos derivados: `\alpha` = 32; `\mu` = 20; `\lambda` = 22; `\sigma_{0}` = 22
(`\sigma` total = 35); `\Theta` = 23 (17 `\Theta` + 6 `\Theta_r`).

## Símbolos auditados

| Símbolo | Declarado en | Definición | Ocurrencias | Conflictos |
|---|---|---|---|---|
| Θ | §6.4 | umbral de admisión (constante, ref. 1.0) | 17 | 0 |
| Θ_r | §4.1 | umbral de Frobenius (ref. 0.5, `[CONJECTURE]`) | 6 | 0 |
| S_min | §6.3 | suelo financiero (0.2 = Θ − C_R^∞) | 8 | 0 |
| C_R | §2.5 | valor del colateral reputacional (0.8 r/(1+r)) | 20 | 0 (declarado C-04/C-13) |
| r | §2.1 | estado no acotado (reputación) | ~ | 0 |
| R | §8.2 | score acotado [0,1), R = r/(1+r) | ~ | 0 |
| T | §3.1 | tensor de reputación [0,1]^{C×D×H} | ~ | 0 |
| ‖T‖_F | §3.3/§4.1 | norma de Frobenius | ~ | 0 |
| α | §2.1 | **velocidad de reversión** | 32 | **1 (reuso)** |
| σ_0 | §2.1 | **coef. de difusión** | 22 | **1 (reuso)** |
| λ | §2.2 | **intensidad de salto** | 22 | **1 (reuso)** |
| μ | §2.5 | **drift μ(r) = α(R̄ − r)** | 20 | **1 (reuso)** |
| μ/g | §8.2 | ratio decaimiento/ganancia | ~ | 0 |
| κ, β | §2.3 | exponentes del scale function | ~ | 0 |

No se detectó ningún símbolo con **dos valores** contradictorios dentro de la
misma sección. Los conflictos son de **reuso del mismo glifo con significados
distintos en secciones distintas** (detalle abajo).

## Conflictos detectados

### C-32 — `\alpha`: velocidad de reversión (§2) vs tasa de transición (§8) vs nivel de significación (§5)
- §2.1 (l.136): "$\alpha > 0$ the mean-reversion speed" — ref. 0.5 / 2.0.
- §5.4–§5.5 (l.667, 673, 694, 711): `\alpha` = nivel de significación ("TPR @
  $\alpha = 0.01$"). Uso estándar, sin conflicto real.
- §8.3 (l.1044): "Transition rate $\alpha(t) = \min(1, t/200)$" — **mismo glifo,
  otra cantidad** dentro del mismo modelo.
Severidad: minor (el conflicto real es §2 vs §8; ambos son parámetros del modelo).

### C-33 — `\mu`: drift μ(r) (§2.5) vs tasa de decaimiento (§8)
- §2.5 (l.270, 279): `\mu(r) = \alpha(\bar{R} - r)` — drift del proceso.
- §8.2 (l.1025, 1249): `R^* = ga/(ga+\mu)`, `R' = g a (1-R) - \mu R` — decaimiento
  reputacional del bootstrap.
Severidad: minor.

### C-34 — `\lambda`: intensidad de salto (§2.2) vs autovalor (§5)
- §2.2 (l.157): `\lambda = 0.8` — intensidad de Poisson de los saltos.
- §5 (l.614, 661-662, 694, 696-700): `\lambda_{\max}(B)`, `-\lambda_{\min}(B)` —
  autovalores del espectro.
Severidad: minor.

### C-35 — `\sigma`: coef. de difusión σ_0 (§2) vs ruido σ (§3.3) vs varianza σ(r) (§2.5)
- §2.1: `\sigma_0` = 0.8 / 0.5 (difusión).
- §2.5 (l.274): `\sigma^2(r) = \sigma_0^2 r` — varianza local.
- §3.3 (l.363): "Low-rank + noise ($\sigma = 0.05$)" — desviación del ruido del
  tensor (dominio distinto, §3).
Severidad: minor.

Nota de no-conflicto: `\Theta` (admisión, ref. 1.0) y `\Theta_r` (Frobenius, 0.5)
son glifos **distintos**; se verificó que no se intercambian en ningún lugar.

## Uso consistente (muestra)
- `S_{\min}` (§6.3 = 0.2) referenciado de forma coherente en §5.7 (l.727) y §11.
- `C_R(r) = 0.8 r/(1+r)` (§2.5) coincide con el valor usado en §6.3 y en
  `verification/mechanism/fee_specification.py`.
- `R = r/(1+r)` (§8.2) declarado explícitamente; no colisiona con `r`.
- `\|T\|_F` (§3.3 tabla y §4.1 umbral) con el mismo significado.
- `\Theta_r = 0.5` (§4.1) aparece idéntico en la tabla del exploit (§4.2).

## Conclusión
- **4 conflictos de reuso de glifo** (C-32…C-35), todos severidad **minor** y de la
  misma clase: el mismo símbolo con dos cantidades en secciones distintas. No hay
  contradicción de valores dentro de una sección.
- Los símbolos de diseño (Θ, Θ_r, S_min, C_R, r, R, T, ‖T‖_F, μ/g, κ, β) son
  consistentes.
- El eje (ii) corrige además el eje (i): **C-29 retractado** (F-018 cita
  correctamente `recalibrate_top.py`, que produce 17.5/8.5).

## Propuestas de resolución (C-28 … C-31)

Todas son ediciones de una línea en `main.tex`; ninguna requiere re-ejecutar scripts
(los valores ya están en las salidas versionadas).

### C-28 — `\fref` mal dirigido en §5.1 (moderate)
Fuente verificada: `verification/rmt/asym_weights.py` produce 7.4478 / 10.1343 /
27.214 (`results/asym_weights_output.txt` l.10-17). El párrafo (l.606) no cita script.
Diff (`main.tex:641`), añadir el `\fref` al cerrar la frase cuantitativa:

```
- ...the ratio is $10.1343$. Under either denominator the density signal is
+ ...the ratio is $10.1343$ \fref{verification/rmt/asym_weights.py}. Under either denominator the density signal is
```

### C-29 — REFUTADO (sin diff)
F-018 es la fuente correcta y ya está citado. No hay edición.

### C-30 — rango sin fuente en §10.5 (minor)
Ningún script produce "20--25%"; el valor de referencia derivado es 22.4%
(§8.4/§11, `simulate_bootstrap_net_gain.py`). Dos opciones:

(b) **Recomendada** — sustituir el rango por el valor derivado y citado:
```
- The qualitative conclusion (stake reduction of 20--25\% at the median
- validator) is robust to small changes in the gain rule, but the specific
- numbers are not.
+ The qualitative conclusion (a stake reduction of about 22\% at the median
+ validator \fref{verification/bootstrap/simulate_bootstrap_net_gain.py}) holds
+ for the reference gain rule; the specific numbers of other rules are not
+ tabulated in this paper.
```
(c) Alternativa mínima — etiquetar como estimación:
```
- (stake reduction of 20--25\% at the median validator)
+ (stake reduction of roughly 20--25\% at the median validator [Estimate])
```
Recomendación: (b) — reemplaza una cifra no soportada por la derivada y acotada.

### C-31 — medición Poseidon sin `\fref` en §4.5 (minor)
`GasBenchmarks.sol` contiene `benchPoseidon2()` (l.92) y su salida
`integrations/avalanche/benchmark_output_v2.txt` l.64 registra `poseidon2 gas: 104963`.
Diff (`main.tex:564`):

```
- The Poseidon-2 measurement of 104{,}963 gas is an upper bound from an
+ The Poseidon-2 measurement of 104{,}963 gas
+ \fref{integrations/avalanche/benchmarks/src/GasBenchmarks.sol} is an upper bound from an
```

(coherente con §4/§9, que citan `GasBenchmarks.sol` para el resto de gas).

## Estado del árbol (snapshot)

```
HEAD  c75cda2  chore(verification): add baseline orchestrator (run_all.sh)
?? docs/audit/eje-i-claims-report.md
?? docs/audit/eje-ii-consistency-report.md
?? docs/audit/session-report.md          (untracked por convención)
?? verification/baseline_2026-10-06/     (baseline en curso; no se commitea)
```

`main.tex` sin cambios en este eje. Baseline de (iv): PID 47338, en curso.


