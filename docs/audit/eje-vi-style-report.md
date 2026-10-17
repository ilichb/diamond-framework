# Eje (vi) — Estilo y terminología

Fecha: 2026-10-10
HEAD previo al eje: `57c73fe` (`docs(audit): fix self-contradiction in eje-v report verdict`)
Alcance: `docs/paper/main.tex`, `CONTRIBUTING.md`, `README.md`.

> **Nota de alcance (transparencia).** El fichero de *spec* del Eje (vi) —
> que fija la lista exacta de los 6 inventarios, la guarda de notación y los
> dos commits de estilo— **no está en el repositorio** (comprobado en el árbol,
> en `/tmp` y en todo el historial de git). Los cuatro sub-ejes se reconstruyen
> de la sesión y de los anclajes entregados. Donde una decisión depende de la
> spec ausente se marca **[pendiente de validación]** y no se edita el paper.

## Metodología

1. Inventarios de terminología con `grep -in` (case-insensitive) sobre
   `docs/paper/main.tex`.
2. Guardas de notación con `grep -in` para `\mu` y `\alpha(t)` (Sub-eje 2).
3. Inventario de `[CONJECTURE]` y de los verbos objetivo de reproducción
   (Sub-ejes 3 y 4).
4. La regla *attribution ≠ value verification* (C-36) se respeta: citar un
   pasaje no es verificarlo.

**Convención de líneas.** Las líneas citadas son las del estado *antes* de C-44.
C-44 borra `main.tex:35`, de modo que en el árbol final toda línea ≥ 35 se
desplaza una posición hacia arriba (p. ej. la l.721 citada en C-43 es la l.720
tras C-44; l.850 → 849; l.1027 → 1026).

---

## Sub-eje 1 — Inventario de terminología (6 inventarios)

Cada inventario lista las variantes de un término y su forma en el paper. La
columna «canónico» usa como árbitro la **forma mayoritaria** en el paper (regla
de desempate reproducible); la dirección exacta de cada normalización es una
decisión de spec **[pendiente de validación]**.

### Inventario 1 — `net_gain` (nombre del modelo de recompensa)

    grep -inE 'net[_ ]?gain' docs/paper/main.tex

| Variante | Ocurrencias | Líneas |
|---|---|---|
| `net\_gain` (prosa) | 4 | 1107 (×3), 1259 |
| `net_gain` (rutas de script) | 6 | 1034, 1039, 1096, 1097, 1098, 1099 |
| `netgain` (etiquetas `\label`) | 2 | 1027 (`eq:netgain`), 1254 (`eq:netgain-limits`) |
| `net gain` (dos palabras) | 0 | — |

**Adjudicación: STOP (>5 cambios).** Incluyendo rutas y etiquetas hay 8
ocurrencias de `net_gain`/`netgain`; la prosa sola son 4. Cualquier
normalización que toque el identificador alcanza o supera el umbral de 5.
Se reporta el conteo exacto y **no se aplica fix** hasta validación.

### Inventario 2 — `on-chain`

    grep -inE 'on[- ]?chain' docs/paper/main.tex

| Variante | Ocurrencias | Nota |
|---|---|---|
| `on-chain` | 31 | adjetivo/adverbio (dominante) |
| `on chain $c$` | 2 (l.323, 904) | preposición «on chain *c*» — uso distinto |
| `On-chain` / `On-Chain` | 4 (l.486, 496, 1150) | encabezado de tabla / título de subsección |

**Adjudicación: LIMPIO.** Las formas con espacio son preposicionales
(«score on chain $c$») y las mayúsculas son títulos de sección/cabeceras. No hay
dos grafías del **mismo rol**.

### Inventario 3 — `heavy-tail(ed)`

    grep -inE 'heavy[- ]?tail(ed)?' docs/paper/main.tex

| Variante | Ocurrencias | Líneas |
|---|---|---|
| `heavy-tailed` | 10 | 74, 589, 685, 728, … (dominante) |
| `heavy-tail` (atributivo) | 2 | 123, 1148 («heavy-tail recalibrations») |

**Adjudicación: divergencia menor (2 cambios).** El uso atributivo debería ser
`heavy-tailed`. **Resuelto como C-47** (aplicado en el cierre): las dos líneas de
prosa pasan a `heavy-tailed`; los nombres de script (`heavy_tail_*.py`) no se
tocan.

### Inventario 4 — `worst-case`

    grep -inE 'worst[- ]?case' docs/paper/main.tex

| Variante | Ocurrencias | Líneas |
|---|---|---|
| `worst-case` (atributivo) | 6 | 806, 830, 847, 850, 865, 884 |
| `worst case` (sustantivo) | 1 | 977 («in the worst case») |

**Adjudicación: LIMPIO.** «in the worst case» es una frase sustantiva
(rol distinto del atributivo `worst-case`). No es inconsistencia.

### Inventario 5 — `true-positive` / `false-positive`

    grep -inE '(true|false)[- ]positive' docs/paper/main.tex

| Variante | Ocurrencias | Líneas |
|---|---|---|
| `true positive` (atributivo, con espacio) | 6 | 706, 712, 717, 730, 1180, 1245 |
| `true-positive` (atributivo, con guion) | 2 | 685 |
| `false-positive` (atributivo, con guion) | 3 | 685 |

**Adjudicación: STOP en la primera pasada; resuelto como C-46 en el cierre.** El
mismo rol atributivo («true positive rate» / «false positive rate») aparece en
las **dos** formas dentro de la **misma línea** (l.685: 2 `true-positive` + 3
`false-positive`). La forma mayoritaria y la del título de sección es la **sin
guion**, así que se unifica a `true positive` / `false positive` (5 cadenas en la
línea).

### Inventario 6 — `fraud proof` / `fraud-proof`

    grep -inE 'fraud[- ]proof' docs/paper/main.tex

| Variante | Ocurrencias | Líneas |
|---|---|---|
| `fraud proof` (atributivo) | 4 | 103, 915 (título), 995 |
| `fraud-proof` (atributivo) | 2 | 909, 995 |

**Adjudicación: divergencia menor (2 cambios).** El rol atributivo se escribe de
las dos formas (l.995 contiene ambas). Forma mayoritaria y del título de
sección: `fraud proof`. **Resuelto como C-48 (Opción a, unificar a sin guion):**
se quita el guion en l.909 y en la primera ocurrencia de l.995.

### Tabla de adjudicación (resumen)

| # | Término | Formas | Cambios | Veredicto final |
|---|---|---|---|---|
| 1 | `net_gain` | `net\_gain` / `net_gain` / `netgain` | 0 | STOP sin finding (tocar ≥8 identificadores/etiquetas) |
| 2 | `on-chain` | `on-chain` / `on chain` / `On-chain` | 0 | LIMPIO |
| 3 | `heavy-tailed` | `heavy-tailed` / `heavy-tail` | 2 | **C-47** (aplicado) |
| 4 | `worst-case` | `worst-case` / `worst case` | 0 | LIMPIO |
| 5 | `true-positive` | `true positive` / `true-positive` | 5 | **C-46** (aplicado; unifica a sin guion) |
| 6 | `fraud-proof` | `fraud proof` / `fraud-proof` | 2 | **C-48** (aplicado; unifica a sin guion) |

**Observación adicional (fuera de los 6).** `README.md` documenta dos quiebres
de convención en las tablas «Summary of the Section»: el encabezado de columna
`Status` (9 tablas) vs `Category` (tabla de Limitaciones, l.1302), y el valor
`Estimate` vs `Estimated` / `Measured + estimate`. Se registran aquí, no se tocan.

---

## Sub-eje 2 — Notación: **LIMPIO** (sin cambios)

Guardas ejecutadas y devueltas **0** (coinciden con la ejecución previa del
Auditor):

- **`\mu`** — aparece solo como `\mu(r)` (drift del proceso §2.5: l.270, 274,
  279, 287, 290). El `\mu` como **tasa de decaimiento del bootstrap §8** fue
  renombrado a `\delta` en C-33; no queda ninguna ocurrencia de esa segunda
  acepción.
- **`\alpha(t)`** — **0 ocurrencias**. La tasa de transición del §8 fue
  renombrada a `\tau(t)` en C-32. Los usos restantes de `\alpha` son la
  velocidad de reversión §2 y el nivel de significación §5, ambos legítimos.

Sub-eje 2 declarado **limpio** en este informe. No se toca (por indicación).

---

## Sub-eje 3 — `[CONJECTURE]` (C-43, C-44)

Inventario: `[CONJECTURE]` como **prefijo** (l.721, `\textbf{[CONJECTURE]}`), como
**sufijo** (l.441 `… $\Theta_r = 0.5$ [CONJECTURE].`; l.507
`… on-chain verification [CONJECTURE: …].`), y `\newtheorem{conjecture}` (l.35,
**nunca** usado: 0 `\begin{conjecture}` en todo el repo).

### C-43 — `[CONJECTURE]` prefijo → sufijo
- `main.tex:768`: mover `[CONJECTURE]` del inicio al final de la oración, en el
  estilo de l.441/l.507 (sin negrita, tras la cláusula).
- `CONTRIBUTING.md:14-15`: cambiar la palabra `prefix` → `suffix`.
- Commit: `fix(paper): C-43 [CONJECTURE] prefix→suffix (main.tex:768, CONTRIBUTING.md)`

### C-44 — eliminar el entorno `conjecture` no usado
- `main.tex:35`: borrar `\newtheorem{conjecture}[theorem]{Conjecture}`.
- Verificación: `grep -rn 'begin{conjecture}' docs/` = **vacío** (ningún
  `\begin{conjecture}` colgando).
- Commit: `fix(paper): C-44 remove unused conjecture theorem environment`

---

## Sub-eje 4 — Tiempos verbales (sin finding)

Los verbos objetivo presentes en `main.tex` dan **9 ocurrencias**, de las cuales
**8** llevan su `\fref` en la misma línea:

| Verbo | Líneas con `\fref` | Línea sin `\fref` |
|---|---|---|
| verify | 211, 248, 608, 830, 942 | **850** |
| measure | 689, 1152 | — |
| simulate | 1039 | — |

La línea **850** («We verify this numerically:») no lleva `\fref` en la misma
línea, pero la tabla que introduce es salida de `fee_specification.py`
(referenciado en la **línea 830**). Se **descarta** por *«continuidad contextual
de `\fref` de la línea 830»*. **No se genera finding.**

---

## Descartes con razón

| Pasaje | Motivo del descarte |
|---|---|
| l.850 «We verify this numerically:» (sin `\fref` en la propia línea) | Continuidad contextual de `\fref` de la línea 830 (`fee_specification.py`). |
| l.323, 904 «on chain $c$» | Uso preposicional («on chain *c*»), no el adjetivo `on-chain`. |
| l.486, 496, 1150 `On-chain`/`On-Chain` | Mayúsculas de cabecera de tabla / título de subsección. |
| l.977 «in the worst case» | Frase sustantiva; el rol atributivo (`worst-case`) sí es consistente. |
| l.1027, 1254 `\label{eq:netgain}` | Identificadores de etiqueta LaTeX, no prosa. |
| l.35 `\newtheorem{conjecture}` | Sin uso; no es inconsistencia de texto, se limpia en C-44. |
| `net_gain` (I1) — normalizar el identificador | STOP por umbral (≥8 cambios en prosa/rutas/etiquetas); sin finding. |
| Opción (b) para `fraud proof` (unificar a **con** guion) | Descartada: la forma mayoritaria y el título de sección son sin guion; (a) implica 2 cambios frente a 4. |
| Recuento de l.685 en I5 (decía 3 cadenas con guion) | Corregido: la línea contiene **5** cadenas (`2 true-` + `3 false-`); el informe omitió además una línea sin guion (l.1329 pre-C-44). |

---

## Estado — Eje (vi) CERRADO

- Sub-eje 1: 6 inventarios. Resueltos I3 (C-47), I5 (C-46) e I6 (C-48);
  `on-chain` (I2) y `worst-case` (I4) limpios; `net_gain` (I1) **STOP sin
  finding** (tocar ≥8 identificadores/etiquetas). Ver «Cierre» más abajo.
- Sub-eje 2: **LIMPIO** (guardas = 0).
- Sub-eje 3: C-43 y C-44 ejecutados (2 commits, un finding por commit).
- Sub-eje 4: sin finding (9 ocurrencias / 8 con `\fref`; l.850 desestimada).
- Cierre: **C-45** (housekeeping del worksheet) y **C-46…C-48** (los tres fixes
  de estilo) aplicados; worksheet, handoff §2 y este informe alineados en 48
  findings.
- Ronda post-cierre: **C-49** (`collusion test` → `collusion detection`, **dos**
  ocurrencias) y **C-50** (`log of falsifications` → `falsification log`),
  halladas al re-derivar el árbol con el comando exacto. Total final: **50**
  findings. Ver «Lección aprendida».

---

## Cierre — adjudicaciones definitivas (C-45…C-50)

Seis commits atómicos, uno por finding (los fixes se aplican sobre `main.tex`
y se validan con `pdflatex` ×2 → `^!` = 0, `Undefined` = 0):

| Commit | Finding | Cambio | Guarda |
|---|---|---|---|
| `dc62f1c` | C-45 | worksheet: bloques C-43/C-44 (+ C-45) | `grep -c '^### C-'` = 45 |
| `065fc9a` | C-46 | `main.tex:728`: `true/false-positive` → sin guion (5 cadenas) | `grep -cE '[-](true\|false)positive'` = 0 |
| `8c04346` | C-47 | `main.tex:115,1147`: `heavy-tail` → `heavy-tailed` (sin tocar `heavy_tail_*.py`) | `grep -cE 'heavy-tail([^e]\|$)'` = 0 |
| `d04d5a4` | C-48 | `main.tex:969,994`: `fraud-proof` → `fraud proof` | `grep -c 'fraud-proof'` = 0 |
| `e08c862` | C-49 | `main.tex:76,1337`: `collusion test` → `collusion detection` | `grep -c 'collusion test'` = 0 |
| `6cc8130` | C-50 | `main.tex:1440`: `log of falsifications` → `falsification log` | `grep -c 'log of falsifications'` = 0 |

### Estado final de los 6 inventarios (re-derivado en el árbol final)

| # | Término | Reparto | Forma canónica | Acción |
|---|---|---|---|---|
| 1 | `net_gain` | `net\_gain`(4) / `net_gain`(6) / `netgain`(2) | — | sin cambio (STOP) |
| 2 | `on-chain` | `on-chain`(31) / `on chain`(2) / `On-chain`(4) | `on-chain` | ninguna (roles distintos) |
| 3 | `heavy-tail(ed)` | `heavy-tailed`(6) / `heavy-tail`(0) | `heavy-tailed` | C-47 |
| 4 | `worst-case` | `worst-case`(6) / `worst case`(1) | `worst-case` | ninguna (roles distintos) |
| 5 | `true/false positive` | `… positive`(8 líneas) / `…-positive`(0) | sin guion | C-46 |
| 6 | `fraud proof` | `fraud proof`(4) / `fraud-proof`(0) | sin guion | C-48 |

### Correcciones a este informe (arregladas en el cierre)

1. **I5, l.685.** El informe listaba 3 cadenas con guion; la línea contiene
   **5** (`2 true-` + `3 false-`). El fix de C-46 afecta a las 5, no a 3.
2. **I5, recuento sin guion.** El informe citaba 6 líneas; hay **7** (706, 712,
   717, 730, 1180, 1245, **1329** en numeración pre-C-44); faltaba la última.
3. **Numeración de findings.** El handoff declaraba «C-01 through C-44» pero el
   worksheet sólo tenía 42 bloques; el cierre abre **C-45** (housekeeping) y
   **C-46…C-48** (los fixes), dejando worksheet y handoff en 48.
4. **C-49/C-50, terminología huérfana.** El plan de cierre asumía un solo
   `collusion test` (real: **dos**, §1.3 y §11) y daba `log of falsifications`
   por ya corregido (real: **presente**, §11). Ambos se recuperaron al
   re-derivar el árbol con el comando exacto; el recuento final sube a **50**.

### Lección aprendida (C-49/C-50)

Un valor en prosa sin comando de origen no es un valor, es una hipótesis. Los
guards deben re-derivarse con el comando exacto. C-49 es el ejemplo directo:
`grep -c 'collusion test'` no puede llegar a 0 tocando una sola línea, porque
la forma aparece dos veces. C-50 es el reverso: una variante declarada «ya
corregida» seguía en el árbol. Antes de declarar un grep en 0, se re-ejecuta.
