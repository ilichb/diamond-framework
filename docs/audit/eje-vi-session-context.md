# Eje (vi) — Documento de traspaso de contexto

**Propósito.** Capturar todo lo necesario para continuar el **Eje (vi) del
audit** (estilo y terminología de `docs/paper/main.tex`) en una ventana de
contexto nueva, sin depender del historial de chat. Autocontenido: estado,
pendientes, reglas, ficheros a leer y comandos de verificación.

**Idioma de trabajo:** responder en español. Los informes de eje viven en
`docs/audit/` y siguen el formato de `eje-ii-consistency-report.md` /
`eje-v-integrated-read-report.md`.

---

## 0. Anclajes (re-derivar siempre; son volátiles)

Repositorio (raíz de trabajo):

    cd /home/ilich/Escritorio/diamond-framework

Valores en el momento de escribir este documento:

    git rev-parse HEAD          # re-derivar (el Eje (vi) cerró en 35aa8be, antes de este doc)
    git branch --show-current   # main
    git rev-list --left-right --count origin/main...HEAD   # 0	3  (3 commits sin empujar)
    md5sum docs/paper/main.tex  # f513d69c3dab9f93d8438f3dd826bcab

Historial reciente (más nuevo primero):

    35aa8be docs(audit): eje (vi) style report + handoff §2 (C-43, C-44)
    55d4d90 fix(paper): C-44 remove unused conjecture theorem environment
    edc29b9 fix(paper): C-43 [CONJECTURE] prefix->suffix (main.tex:721, CONTRIBUTING.md)
    57c73fe docs(audit): fix self-contradiction in eje-v report verdict   <- HEAD previo al Eje (vi)
    d3e429b docs(audit): add eje-v integrated read report (C-38..C-42)

Estado del árbol: limpio salvo **dos untracked preexistentes** que NO se tocan
ni se commitean:

    ?? docs/audit/session-report.md
    ?? verification/baseline_2026-10-06/

> **Los commits del Eje (vi) están SIN empujar.** Re-derivar el conteo con
> `git rev-list --count origin/main..HEAD` (eran 3 del eje + 1 de este doc).
> No se ha hecho `git push`. Decidir con el revisor si se empuja.

---

## 1. Contexto del proyecto

- Paper fuente de verdad: `docs/paper/main.tex` (LaTeX). Overleaf es
  *downstream-only* (el repo manda).
- Worksheet del audit: `docs/audit/content-audit-pending.md`.
- Log de falsificación: `docs/audit/numerical-verification.md` (F-001…F-021).
- Handoff durable: `docs/audit/handoff.md` (reglas §4, backlog §2, inventario §5).
- Informes de ejes previos: `eje-i-claims-report.md`, `eje-ii-consistency-report.md`,
  `eje-iii-counters-report.md`, `eje-iv-reproduction-report.md`,
  `eje-v-integrated-read-report.md`.
- Informe de ESTE eje: `docs/audit/eje-vi-style-report.md`.

Los ejes cierran hallazgos numerados `C-01…C-NN`. Al empezar el Eje (vi) el
backlog llegaba a **C-42**. El Eje (vi) produjo **C-43** y **C-44**.

---

## 2. La tarea del Eje (vi) — 4 sub-ejes

El Eje (vi) audita **estilo y terminología** (no consistencia matemática ni
valores numéricos). Cuatro sub-ejes:

| Sub-eje | Objeto | Estado |
|---|---|---|
| **1** | Inventario de terminología (6 inventarios) con `grep -in` | **CERRADO con STOP pendiente** |
| **2** | Guarda de notación `\mu` y `\alpha(t)` | **LIMPIO** |
| **3** | Etiquetado `[CONJECTURE]` (C-43, C-44) | **CERRADO** (2 commits) |
| **4** | Tiempos verbales de reproducción | **CERRADO sin finding** |

> **Caveat crítico (spec ausente).** El fichero de *spec* del Eje (vi) que fija
> la lista exacta de los 6 inventarios, la guarda y los commits **NO está en el
> repositorio** (verificado en el árbol, `/tmp` y todo el historial de git). El
> Sub-eje 1 se reconstruyó del resumen de la sesión. Toda decisión dependiente
> de la spec ausente está marcada **[pendiente de validación]** en el informe y
> **no se editó el paper** para esos casos.

### Reglas metodológicas (obligatorias, del handoff §4)

1. **Anti-invención.** No inventar. Si falta la spec, marcar `[pendiente de validación]`.
2. **Attribution ≠ value verification (C-36).** Citar un pasaje no es verificarlo.
3. **Un finding, un commit.** Cada `C-NN` cerrado = un commit propio. Mensajes:
   `fix(paper): C-NN <desc>` o `docs(audit): ...`.
4. **No diffs masivos.** Si un término exige >5 cambios de línea → **PARA**,
   reporta el conteo exacto y espera validación antes de tocar el paper.
5. Inventarios de terminología con **`grep -in`** (case-insensitive).

### Sub-eje 1 — inventarios y tabla de adjudicación (reconstruidos)

6 inventarios. Para cada término se listan las variantes; la dirección canónica
propuesta es la **forma mayoritaria** (regla de desempate), pero es decisión de
spec **[pendiente de validación]**.

| # | Término | Comando `grep` | Variantes / líneas | Cambios | Veredicto |
|---|---|---|---|---|---|
| 1 | `net_gain` | `grep -inE 'net[_ ]?gain'` | prosa `net\_gain`=4 (l.1107×3, 1259); rutas `net_gain`=6 (1034,1039,1096-1099); label `netgain`=2 (1027,1254); `net gain`=0 | ≥4 | **STOP (>5)** |
| 2 | `on-chain` | `grep -inE 'on[- ]?chain'` | `on-chain`=31; `on chain $c$`=2 (323,904); `On-chain`/`On-Chain`=4 (486,496,1150) | 0 | LIMPIO |
| 3 | `heavy-tail(ed)` | `grep -inE 'heavy[- ]?tail(ed)?'` | `heavy-tailed`=10; `heavy-tail`=2 (123,1148) | 2 | menor [pendiente] |
| 4 | `worst-case` | `grep -inE 'worst[- ]?case'` | `worst-case`=6 (806,830,847,850,865,884); `worst case`=1 (977) | 0 | LIMPIO |
| 5 | `true/false-positive` | `grep -inE '(true\|false)[- ]positive'` | `true positive`=6 (706,712,717,730,1180,1245); `true-positive`=2 (685); `false-positive`=3 (685) | 6 | **STOP (>5)** |
| 6 | `fraud proof/proof` | `grep -inE 'fraud[- ]proof'` | `fraud proof`=4 (103,915 título,995); `fraud-proof`=2 (909,995) | 2 | menor [pendiente] |

**STOP (I1) — `net_gain`: conteo exacto a reportar (y esperar validación).**
Prosa `net\_gain` = **4**; rutas `..net_gain.py` = **6**; `\label{eq:netgain*}`
= **2**; «net gain» (dos palabras) = **0**. Si el canónico es «net gain», tocar
el identificador **supera 5 cambios** → no aplicar sin validación.

**STOP (I5) — `true-positive`: 6 cambios** al pasar «true positive rate» →
«true-positive rate» (supera 5).

**Menores [pendiente de validación] (no aplicadas):** I3 `heavy-tail` →
`heavy-tailed` (2 líneas: 123, 1148). I6 `fraud-proof` → `fraud proof` (2
líneas atributivas: 909, 995).

**Observación fuera de los 6 (no tocar):** `README.md` documenta dos quiebres
de convención en las tablas "Summary of the Section": columna `Status` (9
tablas) vs `Category` (tabla Limitaciones, l.1302); valor `Estimate` vs
`Estimated` / `Measured + estimate`.

### Sub-eje 2 — notación: LIMPIO (guarda = 0)

- `\mu` aparece solo como `\mu(r)` (drift §2.5; l.270,274,279,287,290). La
  acepción bootstrap §8 se renombró a `\delta` en **C-33** → sin reuso.
- `\alpha(t)` = **0 ocurrencias**; la tasa de transición §8 se renombró a
  `\tau(t)` en **C-32**. Los `\alpha` restantes son velocidad de reversión §2 y
  nivel de significación §5 (legítimos).

Comandos de verificación:

    grep -in '\\mu' docs/paper/main.tex
    grep -in '\\alpha(t)' docs/paper/main.tex   # debe dar 0

> **Resultado confirmado (números post-C-44).** La guarda del drift da 5 líneas
> (269, 273, 278, 286, 289), todas la forma `mu(r)`; la guarda `alpha(t)` da
> vacío; la tasa de transición renombrada aparece en 1044 / 1051 / 1276.
> Equivalentes pre-C-44: 270 / 274 / 279 / 287 / 290.
>
> **Pitfall de escapado (verificado).** En el patrón del `grep` hay que usar
> **dos** barras invertidas dentro de comillas simples. Con una sola, GNU grep
> interpreta la barra-m como la letra `m` y **sobre-coincide** (falso positivo
> masivo); el patrón `alpha(t)` sin barras también es engañoso en BRE. Alternativa
> robusta e inequívoca: `grep -nF` con la forma del símbolo como string fija.

### Sub-eje 3 — `[CONJECTURE]`: C-43 y C-44 (CERRADO, 2 commits)

- **C-43** `edc29b9`: `main.tex:721` movido `\textbf{[CONJECTURE]}` prefijo →
  sufijo al final de la oración (estilo l.441/l.507, sin negrita);
  `CONTRIBUTING.md:14-15` palabra `prefix` → `suffix`.
- **C-44** `55d4d90`: eliminada `\newtheorem{conjecture}[theorem]{Conjecture}`
  (l.35). Verificado: **0** `\begin{conjecture}` colgando.

Verificación:

    grep -in 'conjecture' docs/paper/main.tex          # l.720 sufijo, l.747 "Conjecture" (columna Status)
    grep -rn 'begin{conjecture}' docs/paper/            # vacío
    grep -rn 'newtheorem{conjecture}' docs/paper/       # vacío
    sed -n '14,15p' CONTRIBUTING.md                     # "suffix"

### Sub-eje 4 — tiempos verbales: SIN FINDING

Verbos objetivo = **verify, measure, simulate**. Dan **9 ocurrencias**; **8**
con `\fref` en la misma línea:

| Verbo | Con `\fref` | Sin `\fref` |
|---|---|---|
| verify | 211, 248, 608, 830, 942 | **850** |
| measure | 689, 1152 | — |
| simulate | 1039 | — |

**l.850** («We verify this numerically:») se **descarta** con la razón exacta:
*«continuidad contextual de `\fref` de la línea 830»* (la tabla que introduce es
salida de `fee_specification.py`, referenciado en l.830). **No genera finding.**
(Los verbos «We check» 1176, «We compute» 335, «We estimate» 521, «We demonstrate»
450 NO son del conjunto objetivo; incluirlos daría 13.)

> **Aviso de numeración.** C-44 borra una línea (l.35), de modo que en el árbol
> final toda línea ≥35 se desplaza **−1**: l.721→720, l.850→849, l.1027→1026,
> etc. Las citas de arriba son del estado **previo** a C-44.

---

## 3. Ficheros a leer (en este orden) al retomar

1. `docs/audit/eje-vi-session-context.md` — **este documento**.
2. `docs/audit/eje-vi-style-report.md` — informe del eje (incluye sección
   «Descartes con razón»).
3. `docs/audit/handoff.md` — **§2** (backlog C-01…C-44) y **§4** (reglas/lecciones).
4. `CONTRIBUTING.md` — regla 4 (l.14-15: `[CONJECTURE]` como *suffix*).
5. `README.md` — convenciones de las tablas "Summary of the Section"
   (columna `Status`/`Category`; valores `Verified`/`Measured`/…/`Conjecture`).
6. `docs/paper/main.tex` — fuente del paper (tocar solo con finding + commit).
7. `docs/audit/eje-ii-consistency-report.md` y `eje-v-integrated-read-report.md`
   — para el **formato de informe** de eje.

## 4. Comandos de verificación (copiar y pegar)

Estado general:

    cd /home/ilich/Escritorio/diamond-framework
    git rev-parse HEAD
    git status --short
    git log --oneline -6

Sub-eje 1 (inventarios):

    for g in 'net[_ ]?gain' 'on[- ]?chain' 'heavy[- ]?tail(ed)?' 'worst[- ]?case' '(true|false)[- ]positive' 'fraud[- ]proof'; do echo "== $g =="; grep -inE "$g" docs/paper/main.tex; done

Sub-eje 2 (guarda de notación):

    grep -in '\\mu' docs/paper/main.tex ; grep -in '\\alpha(t)' docs/paper/main.tex

Sub-eje 3 (conjecture):

    grep -rn 'begin{conjecture}' docs/paper/ ; grep -n 'conjecture' docs/paper/main.tex | head

Sub-eje 4 (verbos):

    grep -inE 'we (verify|verified|measure|measured|simulate|simulated)' docs/paper/main.tex

Compilación del paper (validar que no rompe):

    cd docs/paper && pdflatex -interaction=nonstopmode -halt-on-error main.tex >/tmp/vi1.log 2>&1; \
    pdflatex -interaction=nonstopmode -halt-on-error main.tex >/tmp/vi2.log 2>&1; \
    echo "exit=$?"; grep -c '^!' main.log; grep -c 'Undefined' main.log

(Referencia de resultado esperado: exit=0, `^!`=0, `Undefined`=0.)

## 5. Pendientes / criterios de cierre

1. **Validar la lista de los 6 inventarios** del Sub-eje 1 (¿coincide con la spec?).
2. **Validar el canónico** de `net_gain` (¿`net_gain` o «net gain»?) y de
   `true-positive` (¿con guion?).
3. Decidir si se aplican las **divergencias menores** I3 (`heavy-tail`→
   `heavy-tailed`, 2 líneas) e I6 (`fraud-proof`→`fraud proof`, 2 líneas). Si se
   aprueban: **un finding, un commit** cada una (p. ej. C-45, C-46).
4. Si algún fix cambia contadores del paper/handoff, re-derivar (§1.4/§9/§11 y
   cabeceras del handoff). Un cambio de 2 líneas de estilo normalmente **no**
   altera contadores.
5. Decidir si se hace `git push` (los 3 commits del eje están sin empujar).

## 6. Registro de commits del Eje (vi)

    edc29b9 fix(paper): C-43 [CONJECTURE] prefix->suffix (main.tex:721, CONTRIBUTING.md)
    55d4d90 fix(paper): C-44 remove unused conjecture theorem environment
    35aa8be docs(audit): eje (vi) style report + handoff §2 (C-43, C-44)
    <hash>  docs(audit): eje (vi) session context handoff   <- este fichero

Sin empujar (`origin/main` a 0 detrás). Re-derivar con
`git log --oneline origin/main..HEAD` y `git log -1 --format=%h -- docs/audit/eje-vi-session-context.md`.

