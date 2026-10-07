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
`heavy-tailed`. **[pendiente de validación]** — propuesta, no aplicada.

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

**Adjudicación: STOP (>5 cambios).** El mismo rol atributivo («true positive
rate») aparece 6 veces sin guion y con guion. Normalizar a la forma con guion
implica 6 cambios → **STOP**, se reporta y no se aplica.

### Inventario 6 — `fraud proof` / `fraud-proof`

    grep -inE 'fraud[- ]proof' docs/paper/main.tex

| Variante | Ocurrencias | Líneas |
|---|---|---|
| `fraud proof` (atributivo) | 4 | 103, 915 (título), 995 |
| `fraud-proof` (atributivo) | 2 | 909, 995 |

**Adjudicación: divergencia menor (2 cambios).** El rol atributivo se escribe de
las dos formas (l.995 contiene ambas). Forma mayoritaria y del título de
sección: `fraud proof`. **[pendiente de validación]** — propuesta, no aplicada.

### Tabla de adjudicación (resumen)

| # | Término | Formas | Cambios propuestos | Veredicto |
|---|---|---|---|---|
| 1 | `net_gain` | `net\_gain` / `net_gain` / `netgain` | ≥4 | **STOP (>5): reportar, esperar validación** |
| 2 | `on-chain` | `on-chain` / `on chain` / `On-chain` | 0 | LIMPIO |
| 3 | `heavy-tailed` | `heavy-tailed` / `heavy-tail` | 2 | divergencia menor [pendiente] |
| 4 | `worst-case` | `worst-case` / `worst case` | 0 | LIMPIO |
| 5 | `true-positive` | `true positive` / `true-positive` | 6 | **STOP (>5): reportar** |
| 6 | `fraud-proof` | `fraud proof` / `fraud-proof` | 2 | divergencia menor [pendiente] |

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
- `main.tex:721`: mover `[CONJECTURE]` del inicio al final de la oración, en el
  estilo de l.441/l.507 (sin negrita, tras la cláusula).
- `CONTRIBUTING.md:14-15`: cambiar la palabra `prefix` → `suffix`.
- Commit: `fix(paper): C-43 [CONJECTURE] prefix→suffix (main.tex:721, CONTRIBUTING.md)`

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

---

## Estado

- Sub-eje 1: inventarios + tabla de adjudicación entregados. **`net_gain` (I1) e
  `true-positive` (I5) = STOP (>5)**, se reporta y se espera validación. I3 e I6
  son divergencias menores **[pendientes de validación]**; no se editó el paper.
- Sub-eje 2: **LIMPIO** (guardas = 0).
- Sub-eje 3: C-43 y C-44 ejecutados (2 commits, un finding por commit).
- Sub-eje 4: sin finding (9 ocurrencias / 8 con `\fref`; l.850 desestimada).
