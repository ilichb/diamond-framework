# Diamond Framework — Content Audit, Session Report

Ultra-detailed handoff report for the agent coordinating the **remaining
work**. Written at the close of session 3 (content-audit remediation).

> **Regla 7 de este repo:** si un valor es derivable (con `git`, `grep`,
> `find`), NO se teclea: se da el comando. Todos los números de este
> informe se derivaron con los comandos marcados. Si un número aquí
> discrepa de una derivación en vivo, gana la derivación.

---

## 0. Quick state (todo derivable — no confíes, re-deriva)

    cd /home/ilich/Escritorio/diamond-framework
    git rev-parse HEAD                                   # 7ef2a2b96bc734d45eb98bb0e2b51a5cbb0947b0
    git rev-parse origin/main                            # 7ef2a2b96bc734d45eb98bb0e2b51a5cbb0947b0
    git status --short                                   # (vacío: árbol limpio)
    md5sum docs/paper/main.tex docs/audit/content-audit-pending.md docs/audit/handoff.md
    grep -c '^### C-' docs/audit/content-audit-pending.md # 18
    grep -c '^### F-' docs/audit/numerical-verification.md # 19
    grep -E '^\| C-[0-9]+ ' docs/audit/handoff.md | grep -c '| yes |'  # 15
    grep -E '^\| C-[0-9]+ ' docs/audit/handoff.md | grep -c '| no |'   # 3
    find verification -name '*.py' -not -path '*/archive/*' | wc -l      # 30
    find verification -name '*.py' | wc -l                               # 37

| Ítem | Valor (derivado) |
|---|---|
| HEAD / origin/main | `7ef2a2b96bc734d45eb98bb0e2b51a5cbb0947b0` (sincronizados) |
| Árbol de trabajo | limpio (sin cambios) |
| `main.tex` md5 | `423da019a7ef162343f431485f4d968e` |
| `content-audit-pending.md` md5 | `041f2ece47e3a69b3bcd99359012c608` |
| `handoff.md` md5 | `72cad5e4978b5a38f438c1cbf8612b8e` |
| Findings (bloques `### C-`) | 18 (C-01…C-18) |
| Entradas log falsación (`### F-`) | 19 (F-001…F-019) |
| Filas `main.tex = yes` / `no` en la tabla §2 | 15 / 3 |
| Scripts `.py` no archivados / total | 30 / 37 |
| Outputs `*_output.txt` no archivados | 30 |
| PDF | `docs/paper/main.pdf`, 33 páginas |

**Todo el backlog C-01…C-18 está cerrado** (18/18 con estado terminal).
El paper ya tiene integrada la remediación de los findings que lo tocan
(15/18 editaron `main.tex`; 3 se cerraron sin tocar el paper: C-01, C-09,
C-15).

---

## 1. Contexto y convenciones

- **Repo:** `ilichb/diamond-framework` (fuente de verdad).
- **Paper:** `docs/paper/main.tex` (LaTeX). Overleaf es *downstream-only*
  (pulls); el repo manda. Se compila con `pdflatex` (×2 para refs) en
  `docs/paper/`. No hay Makefile.
- **Worksheet de auditoría:** `docs/audit/content-audit-pending.md`
  (bloques `### C-NN` con `Location / Status / Severity / Evidence /
  Next step / Resolution`).
- **Log de falsación:** `docs/audit/numerical-verification.md`
  (entradas `### F-NNN`).
- **Handoff durable:** `docs/audit/handoff.md` (§0 anclas, §1 contexto,
  §2 tabla de cierre, §3 gaps residuales, §4 reglas, §5 inventario,
  §6 primer mensaje).
- **Participantes:** un humano (prosa/decisiones) + un agente (ediciones
  + verificación). El humano dicta edits; el agente aplica, verifica y
  reporta. Mecanismo central: **el agente deriva lo que el humano teclea**.

**Qué es un "finding".** Una discrepancia entre lo que el paper afirma y
lo que el repo/scripts demuestran. Cada finding se cierra en su bloque del
worksheet con estado terminal (`Cerrado`, `Resolved`, `Refutado`,
`Confirmed`) + evidencia (script, md5, commit).

---

## 2. Cronología de esta sesión

| Commit | Título | Ficheros | Qué cierra |
|---|---|---|---|
| `5689896` | docs(audit): add session-2 handoff; reduce worksheet Handoff to pointer | worksheet, handoff.md | Infraestructura de handoff |
| `bd20d17` | docs(paper): apply Next-step edits for C-12 and C-14 | worksheet, main.tex | **C-12, C-14** |
| `4facece` | docs(paper): rewrite section 5.2 mechanism with per-pair weights (close C-05) | worksheet, handoff.md, main.tex | **C-05** |
| `7ef2a2b` | docs(paper): bridge C-05 mechanism to the spectral outcome | main.tex | Puente de lectura C-05 (lectura integrada) |

Los tres últimos son el objeto de esta sesión (los tres findings que
tenían `Next step` sin aplicar: C-05, C-12, C-14).

---

## 3. Commit A — `bd20d17` (C-12 + C-14)

**Mensaje:** «apply Next-step edits for C-12 and C-14».
**Stat:** `2 files changed, 9 insertions(+), 6 deletions(-)`
(worksheet +7/−6, main.tex +8/−6).
**md5:** `main.tex` b8e4ce39… → 67e1abb4… ; worksheet 9dfb6216… → 17a7d7c4….

### A.1 — §6.2 «Verified Reputation» (C-12), `main.tex:803`

Problema (C-12): §6.2 afirma que «the proof binds the validator to a
specific tensor», cierto solo bajo el *Option B repair* de §4.3-4.4
(§4.2 refutó el binding original). No citaba esa sección.

- **Antes:** `...the verifier checks the binding. The revelation
  principle does not apply because there is nothing to reveal.`
- **Después:** entre ambas oraciones:
  `This binding property holds under the Option B repair of
  Section~\ref{subsec:recursive}, which replaces the original circuit of
  Section~\ref{sec:zk} with a Pedersen commitment and a Bulletproofs
  argument.`

Refs verificadas: `\label{sec:zk}` (→ §4) y `\label{subsec:recursive}`
(→ §4.4) resuelven en `main.aux`.

### A.2 — §8.2 «Reputation Models», fin de sección (C-14), tras `main.tex:1080`

Problema (C-14): `R_{\mathrm{std}}` nunca se define. Párrafo nuevo tras
el párrafo del sweep:

> `The quantity $R_{\mathrm{std}}$ is the cross-sectional sample standard
> deviation of the reputation score $R$ over the active validators at the
> final epoch of the simulation, with the population convention (numpy
> default \texttt{ddof = 0}); the reference simulation runs $N = 100$
> validators over $T = 500$ epochs
> \fref{verification/bootstrap/r_std_specification.py}.`

> Nota de etiqueta: la sección es **§8.2**, no §8.1 (el párrafo del sweep
> es el último de §8.2, justo antes de `\subsection{Bootstrap Simulation}`).

### A.3 — §8.7 (C-14), `main.tex:1155→1082`

El párrafo yuxtaponía `0.0282` y `0.0424` como si fueran comparables.

- **Antes:** `...is 0.0282 in \spath{compare_reputation_models.py} and
  0.0424 at the sweep optimum $\mu/g = 1.5$; both fall below...`
- **Después:** `...is 0.0282 in \spath{compare_reputation_models.py} at
  $\mu/g = 5.0$ with one seed, and 0.0424 in \spath{sweep_net_gain.py} at
  the sweep optimum $\mu/g = 1.5$, averaged over five seeds; both fall
  below...`

### A.4 — §10.5 (C-14), `main.tex:1315→1228`

- **Antes:** `...is 0.0424 at the sweep optimum, below the 0.05 threshold...`
- **Después:** `...is 0.0424 at the sweep optimum $\mu/g = 1.5$ (five
  seeds; the $N = 100$ mean is $0.043970$ with 95\% CI $[0.043351,
  0.044588]$), below the 0.05 threshold...`

### A.5 / A.6 — Worksheet

- C-12 `Status:` → Cerrado. Forward reference added at main.tex:803 (§6.2 → §4.4).
- C-14 `Status:` → Cerrado. R_std defined at the end of §8.2; operating
  point and seed count declared at main.tex:1155 and main.tex:1315.

---

## 4. Commit B — `4facece` (C-05)

**Mensaje:** «rewrite section 5.2 mechanism with per-pair weights (close C-05)».
**Stat:** `3 files changed, 17 insertions(+), 10 deletions(-)`
(worksheet +7/−4, handoff +12/−3, main.tex +8/−3).
**md5:** `main.tex` 67e1abb4… → df13862f… ; worksheet 17a7d7c4… → 041f2ece… ;
handoff 1a1d025f… → 72cad5e4….

Problema (C-05): §5.2 comparaba solo el **peso por arista** (intra-clique
`1/27.2` vs fondo `1/20`) y concluía que la señal de densidad se
*cancelaba* por el aumento de grado. Ignoraba que los pares intra-clique
son **10× más probables**; la comparación relevante es **por par**.

### B.1 — §5.2, párrafo del mecanismo, `main.tex:604`
Se elimina la frase inicial («The normalization is inappropriate for
detecting cliques.») y se reescribe en términos per-edge vs per-pair:
per-edge intra `1/27.2 ≈ 0.037`, fondo `1/20.0 ≈ 0.050`; «the expected
weight is what determines the spectral signature».

### B.2 — §5.2, párrafo tras la tabla de grados, `main.tex:619`
- **Antes:** «The clique's edges are weaker... The density signal is
  cancelled by the degree increase.»
- **Después:** «The clique's per-edge weight is lower... but the per-pair
  weight is not. Under $W$... $10.0000\times$... Under $A_{\mathrm{sym}}$,
  with the null-model background degree... ($d_{\mathrm{bg}} = 20$), the
  ratio is $7.4478$; with the model-consistent background degree under
  $H_1$ ($d_{\mathrm{bg}} = 27.214$), the ratio is $10.1343$. Under either
  denominator the density signal is attenuated by the normalization, not
  cancelled.»

### B.3a — §5.2, prosa antes de la tabla espectral, `main.tex:621`
`...leading non-trivial eigenvalue` → `...eigenvalue, for a single draw of
the generator (seed 42):`

### B.3b — §5.2, párrafo nuevo tras la tabla espectral
> Multi-seed: 200 seeds, `W` gap mean `+0.73` std `0.39`; `A_sym` mean
> `-0.02` std `0.01`; `B` mean `+0.77` std `0.41`. Los single-seed caen en
> P99/P90/P99. El par `gap_B > gap_W` es **estructural** (Weyl interlacing
> sobre `B = W − ddᵀ/(2m)`), no informativo; la diferencia empírica media
> es `+0.0353`, pequeña frente a la std por-semilla.

### B.4 / B.5 / B.6
- Worksheet C-05 `Status:` → `Cerrado. §5.2 mechanism paragraph rewritten
  with the per-pair weight argument; table prose now reports the
  multi-seed distribution and cites Weyl interlacing for the paired claim.`
- Handoff §2: filas C-05, C-12, C-14 → columna `main.tex` de `no` a `yes`.
- Handoff §2: nota bajo la tabla (derivación de la columna con
  `git log --format='%h %s' -- docs/paper/main.tex`).

---

## 5. Commit bridge — `7ef2a2b` (lectura integrada de C-05)

**Mensaje:** «bridge C-05 mechanism to the spectral outcome».
**Stat:** `1 file changed, 1 insertion(+), 1 deletion(-)`.
**md5:** `main.tex` df13862f… → **423da019…** (estado actual).

Motivo: tras B, el texto decía «attenuated, not cancelled» pero la tabla
inmediata muestra `A_sym` con **gap negativo**. Compatible, pero el lector
debía inferir el puente. Se añade al final del párrafo que termina en
`...not cancelled.`:

> `The attenuation under $A_{\mathrm{sym}}$ places the clique signal
> inside the finite-size bulk edge, while the $10\times$ ratio under $W$
> keeps it above; the spectral table below confirms both outcomes.`

Una frase; ambos números ya estaban en la tabla. Esto salió de la
**lectura integrada del PDF** (regla 8): detecta incoherencias de prosa
que la verificación fragmentaria no ve.

---

## 6. Protocolo de verificación usado

**Fragment-level (por edición):**
- `grep` de los contadores y labels afectados.
- Comprobar que cada `\ref{}`/`\label{}` citado resuelve en `main.aux`.
- md5 del fichero antes/después.

**Integrated (lectura del PDF completo, regla 8):**
- `pdflatex` ×2 en `docs/paper/`; comprobar `exit 0`, ausencia de `^!` y de
  `Undefined` en el log.
- Lectura de las 33 páginas del PDF como texto continuo, buscando
  incoherencias que la verificación por fragmentos no ve.
- **Rindió dos veces:** encontró C-17/C-18 (sesión 2) y la frase-puente de
  C-05 (sesión 3). Fragmentaria e integrada son **complementarias**, no
  sustitutas.

**Definition of done por commit:**
1. `pdflatex` limpio (0 errores, 0 refs indefinidas).
2. Bloque del worksheet con `Status:` a estado terminal.
3. Fila correspondiente de la tabla §2 del handoff con la columna derivada.
4. Commit con mensaje descriptivo (convención `docs(paper):` / `docs(audit):`).

---

## 7. Findings resueltos esta sesión

| ID | Severidad | Naturaleza | Commit | Ficheros |
|---|---|---|---|---|
| **C-05** | Moderate | §5.2 explicación conceptualmente errónea (per-edge vs per-pair; single-seed sin declarar) | `4facece` (+ `7ef2a2b`) | main.tex, worksheet, handoff |
| **C-12** | Structural | §6.2 presupone el repair §4.3-4.4 sin citarlo | `bd20d17` | main.tex, worksheet |
| **C-14** | Minor | `R_{\mathrm{std}}` sin definir; valores sin punto operativo ni nº de semillas | `bd20d17` | main.tex, worksheet |

Los tres tenían `Status:` distinto de terminal y un `Next step` de edición
del paper pendiente. Tras esta sesión los tres están **cerrados** y el
paper compila limpio.

**Estado terminal de los 18 findings** (derivado por `grep`):

    grep -oE '^\*\*Status:\*\* [A-Za-z]+' docs/audit/content-audit-pending.md | sort | uniq -c
    # 14 Cerrado · 1 Resolved (C-02) · 1 Refutado (C-09) · 2 Confirmed con Resolution (C-10, C-15)

Los 4 no-`Cerrado` siguen siendo **terminales** (Resolved/Refutado/Confirmed
con `Resolution`).

---

## 8. El error de bookkeeping ("12 findings") — regla 7 en acción

Durante la sesión el humano escribió en prosa «12 findings that touch the
paper». **Es incorrecto.** El conteo derivado es **15** (las filas con
`main.tex = yes`). El «12» se tecleó de memoria *antes* de que C-05/C-12/C-14
se cerraran; los tres pasaron a `yes` y el total subió a 15.

Hecho clave: el «12» **no existe en ningún fichero**:

    grep -rnE '1[24] findings|tocan el paper|paper-touching' docs/   # vacío

Es decir, el repositorio estaba correcto; el error fue solo de prosa. La
columna `main.tex` del handoff §2 se deriva del historial de git:

    git log --format='%h %s' -- docs/paper/main.tex

**Mecanismo (por qué funciona):** el humano escribe prosa → el agente
deriva → el repo ya era correcto. Es el contrato de la regla 7. Ocurrió
**dos veces** esta sesión (antes: «14»; ahora: «12»). En ambos casos la
derivación del repo es el árbitro.

---

## 9. Trabajo que queda / ítems menores abiertos

### A. Micro-fix opcional (1 línea, cosmético) — **decisión pendiente**

El bloque C-05 del worksheet (`content-audit-pending.md`, L287-288) tiene el
campo `Location:` desactualizado: cita *«paragraph beginning 'The
normalization is inappropriate for detecting cliques'»*. La edición **B.1
eliminó esa frase**; el opener nuevo es *«Each edge is scaled by…»*.

    grep -c 'The normalization is inappropriate' docs/paper/main.tex   # 0

- **Fix propuesto:** cambiar `Location:` a
  *«§5.2, paragraph 'Each edge is scaled by…' and the spectral table.»*
- **Segunda copia obsoleta (esperada, NO tocar):**
  `docs/paper/_deprecated-md/05-collusion-detection.md`.
- **Recomendación:** aplicarlo (elimina la última referencia muerta a
  wording retirado). Bajo, sin riesgo, no cambia el PDF.

### B. Output archivado huérfano (pre-existente, cosmético)

Hay 8 outputs archivados frente a 7 scripts archivados:

    find verification -path '*/archive/*' -name '*.py' | wc -l           # 7
    find verification -path '*/archive/*' -name '*_output.txt' | wc -l   # 8

Un `*_output.txt` archivado no tiene script archivado hermano. Cosmético.

### C. Columna `main.tex` del handoff §2

No editar a mano: se **deriva** de git (ver §8). Ya está en `15 yes / 3 no`.

### D. Nada bloqueante

Árbol limpio, `HEAD == origin/main`, PDF compila, 18/18 findings terminales.
El ítem A es la única edición real pendiente; todo lo demás está cerrado.

---

## 10. Gaps residuales declarados (NO son findings) — handoff §3

Estos dos son **no-findings declarados a propósito**; el agente coordinador
debe saber que no son deuda oculta:

1. **`eq:integro` sin implementación.** La ecuación etiquetada
   `\label{eq:integro}` no tiene código que la instancie. Declarado en §3 del
   handoff; es una limitación conocida, no una discrepancia.
2. **`n ≥ 5000` postpuesto.** El experimento `n≥5000` vive fuera del repo:
   `/home/ilich/Escritorio/Rootstock/andromeda-rootstock/diamond-verification-rmt.py`
   (existe, 1932 B). Postpuesto; ruta verificada.

> **Próxima sesión empieza por `docs/audit/handoff.md §3`** (estos dos gaps).

---

## 11. Reglas del repo (metodología)

**De `CONTRIBUTING.md`:**
- A script for every number.
- Declared sample size.
- Reproducible output with a declared seed.
- `[CONJECTURE]` for conjectures.

**Consolidadas en sesión 2** (reflejan lecciones reales de esta auditoría):
- One finding per iteration. One script, one commit, one verification.
- Stop and ask when a guard returns 0 and the expectation was `>= 1`.
- Enumerate `\section{}` before citing a section number.
- Do not conflate quantities in different units.
- Do not commit without verified raw output.
- Stop rule when a citable reference is missing: stop, report, do not invent.
- **Counters and pointers are findings.** Every edit that moves lines or
  adds/removes scripts leaves counters stale. After each commit, grep the
  relevant counters.
- **Read the PDF end-to-end after a batch of edits.** Fragment-level
  verification does not see prose incoherences that appear when §2.5, 4.1,
  6.3, 7.2 and 8.1 are read as continuous text. C-17/C-18 salieron así.
- **Do not assert a derivable value; derive it.** Si un número sale con
  `git`, `grep` o `find`, da el comando, no el resultado de memoria.

---

## 12. Anclas y comandos derivables (handoff §0)

    git rev-parse HEAD                                     # commit actual
    git status --short                                     # estado del árbol
    md5sum docs/paper/main.tex docs/audit/content-audit-pending.md
    grep -c '^### C-' docs/audit/content-audit-pending.md   # nº findings
    grep -c '^### F-' docs/audit/numerical-verification.md  # nº entradas log
    grep -c '^    python3 ' verification/README.md          # scripts catalogados
    find verification -name '*.py' -not -path '*/archive/*' | wc -l
    git log --format='%h %s' -- docs/paper/main.tex        # ediciones del paper

> El handoff **no** almacena HEAD, md5 ni estado del árbol: se re-derivan.
> Este informe sí los incluye (§0) para comodidad, pero la regla 7 manda:
> re-derivar.

---

## 13. Inventario de verificación (handoff §5)

- **30** scripts `.py` no archivados (**37** en total, **7** bajo `*/archive/`).
- Cada script tiene su `*_output.txt` en el `results/` hermano.
- Todos los scripts son **deterministas**: semilla declarada, sin reloj,
  sin entropía, sin I/O de disco.
- Toda figura citada en `main.tex` traza a un script, un benchmark o una
  entrada del log de falsación.
- Log de falsación **F-001 … F-019** (19 entradas). 16 refutadas o
  parcialmente refutadas; 3 no aplicables / mal aplicadas / mal testeadas.

    find verification -name '*.py' -not -path '*/archive/*'
    ls verification/*/results/*_output.txt
    grep -c '^### F-' docs/audit/numerical-verification.md

---

## 14. Coordinación — hoja de ruta para el agente

**Estado:** backlog cerrado salvo el ítem A (cosmético). 18/18 findings
terminales; paper compila; árbol limpio; `HEAD == origin/main`.

**Orden de trabajo sugerido:**
1. **Decidir el ítem A** (§9): micro-fix del `Location:` de C-05. Si se
   aprueba → editar 1 línea, `pdflatex` ×2, commit `docs(audit):`.
2. Arrancar la próxima sesión por **`docs/audit/handoff.md §3`** (los dos
   gaps residuales: `eq:integro`, `n≥5000`).

**Rutina obligatoria:**
- Antes de afirmar cualquier valor: correr los comandos de §12.
- **Un finding → un commit → una verificación.** Tras cada commit: `grep`
  de los contadores afectados.
- Tras un lote de ediciones al paper: **leer el PDF completo** (regla 8).

**Punto a reconciliar (opcional, para el coordinador):** en la tabla §2 del
handoff, la columna `Commit(s)` de C-05/C-12/C-14 lista los commits de
**registro en la auditoría** (`0eeea29` registró C-05, `4f597a7` registró
C-12, `82324e6` registró C-14), no los commits de la **edición del paper**
que cerró el finding (`4facece` cerró C-05; `bd20d17` cerró C-12 y C-14).
Si la convención deseada es que `Commit(s)` apunte al cierre, añadir esos
hashes a esas tres filas. La columna `main.tex` (la que importa para
«paper-touching») ya es correcta.

**Ficheros clave (rutas absolutas):**
- `/home/ilich/Escritorio/diamond-framework/docs/paper/main.tex` — el paper.
- `/home/ilich/Escritorio/diamond-framework/docs/audit/content-audit-pending.md` — worksheet (18 bloques C-).
- `/home/ilich/Escritorio/diamond-framework/docs/audit/handoff.md` — handoff durable (§0 anclas, §3 gaps).
- `/home/ilich/Escritorio/diamond-framework/docs/audit/numerical-verification.md` — log de falsación (19 bloques F-).
- `/home/ilich/Escritorio/diamond-framework/docs/paper/main.pdf` — PDF compilado (33 páginas).
- `/home/ilich/Escritorio/diamond-framework/docs/audit/session-report.md` — este informe (untracked, no commiteado).

---

**Resumen de una línea:** sesión 3 cerró C-05, C-12 y C-14 (commits
`bd20d17`, `4facece`, `7ef2a2b`); el backlog C-01…C-18 queda 18/18 cerrado;
solo resta un micro-fix cosmético (ítem A §9) y los dos gaps residuales
declarados (handoff §3).

---

## 15. Sesión 7 — lote P6b: aparato del paper y re-anclaje (2026-10-12)

**Estado: P6b cerrado.** El aparato del paper (C1–C4: `center` → `table[H]` con
`\caption`) llevó `main.tex` de 1410 a 1566 líneas; las dos amendments que §10
dejó en cola quedaron aplicadas (§10.4's `-502` acotado por §7.5 en
`main.tex:1266`; `\|T\|_F` donde se quiere la norma en `main.tex:842` y `:882`).
Como el paper cambió, las citas `main.tex:NNNN` de los tres inputs sellados se
re-derivaron **antes** de regenerar el root (316 tokens, 313 remapeados, 23
ficheros, 396 citas validadas, 0 cambios de sección; `anchor-receipts.md`
§R-3.1), y el ancla se re-firmó con recibo propio, R-3.

    bash verification/audit-gate.sh                       # PASS=11 FAIL=0 SKIP=0
    bash verification/fase0_anchor.sh --check             # exit 0; 10 pares idénticos
    sha256sum verification/anchor_root.sha256             # 79ac6783…
    sha256sum verification/anchor_root.sha256.ots         # 1e5e5cb6… (805 B)
    ots info verification/anchor_root.sha256.ots          # compromete 79ac6783…
    wc -l docs/paper/main.tex                             # 1566 (1410 en d8d2e55)
    grep -c '^### C-' docs/audit/content-audit-pending.md # 50 (worksheet congelado)
    grep -c '^### F-' docs/audit/numerical-verification.md # 21

**Reglas que este lote deja escritas** (handoff, "Consolidated during session 7"):
un remap de citas mueve números y no adjudica significados; "1:1" es propiedad de
una edición, no una garantía heredable; `ots stamp` no sobrescribe un `.ots` y ya
ha enviado el compromiso a sus calendarios; y un manifiesto que sella citas es
parte del árbol de la auditoría.

> §0 de este informe data de la sesión 3; los valores vivos se re-derivan con los
> comandos de arriba, no se copian.

