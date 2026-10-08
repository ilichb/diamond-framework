# Bloque B — Reporte de las 4 resoluciones del Auditor

Fecha: 2026-10-08
HEAD al empezar: `3606760` (`docs(audit): fix F-017 prose (C-51) — constant
142-gas harness overhead`), 2 commits por delante de `origin/main`.
Árbol: **nada commiteado** (indicación explícita del Auditor). Cambios
versionados: `verification/run_all.sh` (2 líneas), `verification/audit-gate.sh`
(reescrito), `docs/audit/eje-iv-reproduction-report.md` (errata). Artefactos
nuevos: `docs/audit/claim-registry.csv`,
`verification/fase1_determinism_evidence.txt`, `verification/output_manifest.sha256`,
`verification/audit_manifest.sha256`, `verification/baseline_verified/`.

| # | Resolución | Resultado |
|---|---|---|
| 1 | G4 — token 518→517 + adjudicación de los 27 huérfanos | resuelto (ver §1) |
| 2 | Manifest canónico durable (`OUT_DIR` → `verification/baseline_verified/`) | resuelto (ver §2) |
| 3 | Definiciones autoritativas G1–G10 en `audit-gate.sh` | implementadas (ver §3) |
| 4 | Fase 0 (anclaje tamper-evident) | ejecutada (ver §4) |

---

## 1. Resolución G4

### 1.1 El token perdido (518 → 517): NO fue el regex

Tu hipótesis de partida ("el regex del crosscheck se ajustó o un token se
fusionó") queda **refutada por la evidencia**: `docs/audit/eje-iv-crosscheck.py`
tiene **un único commit** en toda su historia y nada lo ha tocado después.

    git log --follow --oneline -- docs/audit/eje-iv-crosscheck.py   # 34f85f0 (único)
    git diff HEAD~5 -- docs/audit/eje-iv-crosscheck.py              # (vacío)

El 518 está fijado en el informe `docs/audit/eje-iv-reproduction-report.md`
(escrito en `34f85f0`). La pérdida viene de una **edición posterior de
`main.tex`**: el commit `cd6f8f4` (`fix(paper): C-41 §2.6 table uses undefined
regime labels D4/S2.2`) reescribió una fila de la tabla §2.6 y con ella
desapareció el token numérico `2.2`:

    git show cd6f8f4 -- docs/paper/main.tex | grep -E '^[-+][^-+]'
    -D4 tail is geometric; S2.2 has no censoring & Verified & \spath{censoring_test.py} \\
    +Second-regime tail is geometric; first regime has no censoring & Verified & \spath{censoring_test.py} \\

Derivación reproducible (aisla la ÚNICA diferencia entre los dos conteos):

    git show 34f85f0:docs/paper/main.tex > /tmp/old.tex
    # mismo TOKEN_RE del crosscheck sobre /tmp/old.tex y docs/paper/main.tex
    #   -> 518 vs 517
    # difflib.SequenceMatcher sobre la secuencia de tokens:
    #   delete '2.2'   (antigua main.tex:304)

**517 es el nuevo baseline** (queda documentado como errata al principio de
`docs/audit/eje-iv-reproduction-report.md`).

### 1.2 Adjudicación de los 27 huérfanos

Artefacto: `docs/audit/claim-registry.csv` (27 filas, columnas
`id,line,section,token,class,verified,evidence`). Etiquetas usadas:
`UNIT` (18), `ANALIT` (7), `REF` (2). `DESIGN`, `EXTA` y `SCI` **no tienen
miembros** entre los 27 (ver §5, pregunta P2).

El reparto NO es arbitrario: coincide con la clasificación que el propio eje
(iv) ya había hecho para el universo de 518 tokens
(`eje-iv-reproduction-report.md:26-34`): 490 OK + **13 DERIVED** + **7 Estimate**
+ **4 notación científica** + **1 unit conversion** + **2 section ref** +
1 MISMATCH (C-36, ya corregido) = 518 → hoy 13+7+4+1+2 = **27 huérfanos**.

Mapa entre la taxonomía del eje (iv) y las seis etiquetas del Auditor:

| Bucket del eje (iv) | N.º | Etiqueta del Auditor |
|---|---|---|
| DERIVED (aritmética derivada en el texto) | 13 | `ANALIT` (7) + `UNIT` (6) |
| Estimate ("6.5M gas", declarado) | 7 | `UNIT` (valor presente en el output) |
| Notación científica (limitación del matcher) | 4 | `UNIT` |
| Unit conversion (fracción → %) | 1 | `UNIT` |
| Section ref ("10.2") | 2 | `REF` |

Regla aplicada, por coherencia con tus definiciones:

- `UNIT` — el mismo valor existe en un output bajo otra escala/formato:
  notación científica (`1.415225e+10` → `1.415`), separadores de millares
  (`6,500,000` → `6.5`; `1,080,501` → `1.08`) o fracción→% (`0.2655` → `26.6`;
  `0.9720` → `97.2`).
- `ANALIT` — derivación explícita en el texto que ningún script imprime
  (`log10(3.1893e+07) = 7.5`; `0.8 × 0.85 = 0.68`; `1/27.2 = 0.037`;
  `(9.1371−8.8601)/0.1101 = 2.52`; `684,064/206,000 = 3.3`).
- `REF` — referencia cruzada de sección (`10.2` = §10.2 de Limitations).

`verified` es la **confirmación concreta y verificable** de cada fila, de tipo
coherente con la etiqueta (aritmética exacta para `UNIT`, fórmula para
`ANALIT`, sección existente para `REF`), con su ubicación en `evidence`. La
guarda G4 (literal del Auditor) da 0:

    python3 -c "import csv; r=list(csv.DictReader(open('docs/audit/claim-registry.csv'))); print(sum(1 for row in r if row['class']=='Orphan' or not row['class']))"
    # 0

### 1.3 Hallazgo colateral: el matcher del crosscheck es ciego a la escala

18 de los 27 "huérfanos" **sí están** en los outputs; el crosscheck no los ve
porque compara por igualdad numérica sin entender notación científica ni
separadores de millares. No son defectos del paper: son limitaciones del
instrumento. Queda documentado en la errata (§1.1) para que nadie vuelva a
perseguir estos 18 tokens como si fueran cifras sin respaldo.

## 2. Resolución 2 — Manifest canónico durable

Ratificado: `/tmp` es inaceptable para el manifiesto final. Cambio de
infraestructura (autorizado explícitamente), 2 líneas efectivas en
`verification/run_all.sh`:

    -OUT_DIR="${OUT_DIR:-${SCRIPT_DIR}/baseline_$(date +%F)}"
    +OUT_DIR="${OUT_DIR:-${SCRIPT_DIR}/baseline_verified}"

(más el docstring del encabezado). El directorio no necesita crearse a mano:
`run_all.sh` ya hace `mkdir -p "${OUT_DIR}"`.

Corrida: `bash verification/run_all.sh` **sin argumentos** → `OUT_DIR =
verification/baseline_verified/` (ruta durable dentro del repo).

**Resultado:** la corrida terminó con **35/35 scripts con exit 0** (0 filas
`MISSING` en el manifiesto), **2074.6 s** de suma de `runtime_s` (34.6 min), y
los 35 outputs salieron **byte-idénticos** al directorio congelado:
`frozen_vs_durable COMPARED 35 DIFFERENCES 0`. Es decir, el determinismo de la
Fase 1 se mantiene **con la ruta durable** (no era un artefacto de `/tmp`).

Consecuencia directa: `verification/output_manifest.txt` (la copia canónica
que `run_all.sh` escribe al final) deja de listar rutas volátiles. Antes de
este cambio listaba:

    /tmp/baseline_verify2/sim_positivity_output.txt
    /tmp/baseline_verify2/stationary_stats_output.txt
    ...

y el caveat que quedó abierto en el Bloque A era precisamente ése. Ahora
`verification/output_manifest.txt` y `verification/baseline_verified/output_manifest.txt`
son el mismo contenido y ambas listan rutas durables.

> Nota de reconciliación: `verification/output_manifest.txt` (listado de rutas,
> escrito por `run_all.sh`) y `verification/output_manifest.sha256` (hashes,
> escrito en la Fase 0) son **dos ficheros distintos y complementarios**; no se
> pisan. El primero es el listado cerrado; el segundo es su anclaje.

## 3. Resolución 3 — Definiciones autoritativas G1–G10

`verification/audit-gate.sh` fue **reescrito** con tus definiciones. La regla
del repo (un valor derivable no se teclea) se mantiene: cada guarda re-deriva
el suyo con el comando exacto de la spec. Dos adaptaciones que tú mismo
autorizaste ("Ajustar según el formato real del log del harness") van marcadas
`[ADAPTED]`; todo lo demás es literal.

| Guarda | Definición de la spec | Desviación |
|---|---|---|
| G1 | `find verification -maxdepth 2 -name "*.py" \| wc -l` ≥ 35 | ninguna |
| G2 | `grep -c "EXIT 0" verification/fase1_determinism_evidence.txt` | `[ADAPTED]`: el log se emite con una línea `<script> EXIT <code>` por script (ver §3.1) |
| G3 | `grep -c "DRIFT" verification/fase1_determinism_evidence.txt` = 0 | ninguna (el log sólo escribe `DRIFT <fichero>` cuando `cmp` discrepa) |
| G4 | nº de filas de `docs/audit/claim-registry.csv` con `class=='Orphan'` o vacía = 0 | ninguna |
| G5 | `grep -c '^### F-' docs/audit/numerical-verification.md` = **19** | **D1** — el valor real es 21 (ver §5) |
| G6 | `grep -c '^### C-' docs/audit/content-audit-pending.md` = 50 | ninguna (real: 50) |
| G7 | `python3 verification/eip_cost_check.py` → exit 0 | ninguna |
| G8 | `grep -c 'Estimate.*Verified\|Verified.*Estimate' docs/paper/main.tex` = 0 | ninguna (real: 0) |
| G9 | `pdflatex main.tex` ×2 + `grep -c '^!' main.log` = 0 y `grep -c 'Undefined' main.log` = 0 | `[ADAPTED]`: se compila con `-output-directory` a un temporal para no dejar `main.aux`/`main.log` en el árbol; el `.log` leído es el mismo que produciría la compilación en sitio |
| G10 | integridad del manifiesto (se evalúa tras la Fase 0) | `[ADAPTED]`: `sha256sum -c` no puede consumir `audit_manifest.sha256` tal cual, porque el fichero de la Fase 0 contiene una línea `# Audit Manifest <fecha>` y una línea con **sólo** el SHA de HEAD (no es formato `sha256sum`); el gate filtra los pares `<sha>  <path>` válidos y compara HEAD por separado |

### 3.1 Cambio de formato del log de evidencia (necesario para G2/G3)

El `verification/fase1_determinism_evidence.txt` que existía era **prosa**: el
`grep -c "DRIFT"` de G3 lo habría contado 4 veces (falso FAIL) y no contenía
ninguna línea `EXIT 0` (falso FAIL en G2). Se regeneró como **log máquina**:

    # una línea por script de la corrida durable
    <script>.py EXIT 0            <- × 35
    <script>.py MISSING           <- sólo si el script faltase
    # comparaciones byte a byte (cmp -s sobre cada *_output.txt)
    frozen_vs_durable COMPARED 35 DIFFERENCES 0
### 3.2 Nota sobre G1

G1 da **36** (no 35): `find verification -maxdepth 2 -name "*.py"` cuenta los
36 scripts bajo `verification/` a profundidad ≤ 2 (la spec pide `>= 35`, y se
cumple). El total con subdirectorios más profundos es 43.

## 4. Resolución 4 — Fase 0 (anclaje tamper-evident)

Ejecutados **verbatim**, una vez que `run_all.sh` pobló el directorio durable:

    find verification/baseline_verified -type f -name "*_output.txt" -o -name "*.csv" | sort | xargs sha256sum > verification/output_manifest.sha256
    echo "# Audit Manifest $(date)" > verification/audit_manifest.sha256
    git rev-parse HEAD >> verification/audit_manifest.sha256
    sha256sum docs/paper/main.tex >> verification/audit_manifest.sha256
    sha256sum verification/output_manifest.sha256 >> verification/audit_manifest.sha256

**Resultado:** `verification/output_manifest.sha256` contiene **35 pares**
`<sha256>  verification/baseline_verified/<script>_output.txt` (rutas
**relativas** al repo, así que el listado es portable).
`verification/audit_manifest.sha256` contiene 4 líneas:

    # Audit Manifest jue 08 oct 2026 10:28:27 -04
    36067607c2e01809fc5a2a6df63e8328a6e217a5
    32c2dff4996a1b81d2a2f0b6b75c2398f86d4ad95b4b6d49964f591d2eea0753  docs/paper/main.tex
    cf2883f66be2767c02cded320bf02fc8f7f35fd2bc68ec6b8960c7cda724084a  verification/output_manifest.sha256

La guarda G10 lo verifica: **PASS**.

Tres notas de ejecución (no son desviaciones, son propiedades del artefacto):

1. `audit_manifest.sha256` **no es consumible por `sha256sum -c` tal cual**:
   su primera línea es un comentario (`# Audit Manifest <fecha>`) y su segunda
   línea contiene **sólo** el SHA de HEAD, sin nombre de fichero. El gate G10 lo
   maneja filtrando los pares `<sha>  <path>` válidos y comparando HEAD aparte
   (ver la tabla de §3).
2. El manifiesto maestro **ancla el HEAD committeado**, que en este momento es
   `36067607c2e01809fc5a2a6df63e8328a6e217a5`. Como el Bloque B termina con
   cambios **sin commitear** (tu indicación), este anclaje quedará obsoleto en
   cuanto se commitee: `verification/audit_manifest.sha256` debe **regenerarse
   tras el commit** o G10 fallará por HEAD. Lo mismo vale para
   `verification/run_all.sh`, cuyas 2 líneas nuevas no están en el HEAD anclado.
3. `main.tex` no se tocó en todo el Bloque B (`md5 =
   11c1cca54de63b0a2825961f1dde2a96`), así que su hash en el manifiesto maestro
   es el mismo que ya reportó el Bloque A.

## 5. Veredicto del gate, discrepancias y preguntas

### 5.1 Salida del gate tras la Fase 0

    audit-gate.sh  repo=/home/ilich/Escritorio/diamond-framework
    --------------------------------------------------------------------------
    G1   PASS  scripts .py (verification, depth 2) = 36 (>= 35)
    G2   PASS  EXIT 0 = 35/35 scripts
    G3   PASS  lineas DRIFT = 0
    G4   PASS  claims Orphan/sin clase = 0 (registro: 27 filas clasificadas)
    G5   FAIL  F- entries = 21 (spec: 19; paper dice 'twenty-one' en L48/L87)
    G6   PASS  C- worksheets = 50
    G7   PASS  eip_cost_check exit 0
    G8   PASS  ninguna mezcla Estimate/Verified en docs/paper/main.tex
    G9   PASS  pdflatex limpio (errors=0, Undefined=0)
    G10  PASS  manifiesto verifica (35 outputs hasheados; HEAD 3606760)
    --------------------------------------------------------------------------
    PASS=9 FAIL=1 SKIP=0

**9 PASS / 1 FAIL / 0 SKIP.** El único FAIL es **D1**, y es la discrepancia de
la spec (19 vs 21), no un fallo del repositorio: el gate está haciendo
exactamente lo que se le pidió.

### 5.2 Discrepancias con la especificación

**D1 — G5 fija 19 entradas F-, el artefacto tiene 21.** La spec dice
`(CORRECCIÓN: El main.tex actual dice 19, no 21)`, pero la derivación dice lo
contrario: `grep -c '^### F-' docs/audit/numerical-verification.md` → **21**, y
el propio paper escribe **"twenty-one"** en `main.tex` L48 y L87. El log tiene
F-020 y F-021, añadidas después de la nota:

    git log --oneline -3 -- docs/audit/numerical-verification.md
    # 3606760 fix F-017 prose … / 3510769 isolate heavy-tail miscalibration … / 0c54363 register F-020 …

El origen del "19" es `docs/audit/session-report.md` (informe de la sesión 3,
cuando sólo existían F-001…F-019). Se implementó el **19 literal** de tu spec en
primera instancia (G5 FAIL por diseño). **RESUELTA** en el cierre: con tu
ratificación, `verification/audit-gate.sh:88` pasa a `-eq 21` y G5 da PASS.
Verificado: `grep -c '^### F-' docs/audit/numerical-verification.md` = 21 y
`grep -c '^### F-' docs/paper/main.tex` = 0 (la guarda cuenta el artefacto
derivado, no el paper; el paper sólo lo enuncia como "twenty-one").

**D2 — El token 518→517 no se perdió por el regex.** Ver §1.1: el crosscheck
sólo tiene un commit y `git diff HEAD~5` está vacío; el token `2.2` lo eliminó
la edición del paper `cd6f8f4` (C-41). 517 es el nuevo baseline.

**D3 — G2 y G3 exigían cambiar el formato del log de evidencia.** Tal como
estaba (prosa), `grep -c "EXIT 0"` daba 0 y `grep -c "DRIFT"` daba 4: las dos
guardas fallaban por formato, no por contenido. Se regeneró como log máquina
(§3.1). Es la adaptación que tu propia nota de G2 autoriza.

**D4 — G10 no puede usar `sha256sum -c` directo.** El manifiesto maestro de la
Fase 0 lleva una línea de comentario y una línea con sólo el SHA de HEAD; no es
formato `sha256sum`. G10 filtra los pares válidos y compara HEAD aparte (§4).

**D5 — El "frozen" no está anclado.** `verification/baseline_2026-10-06/` está
**untracked** (`git status --short` → `?? verification/baseline_2026-10-06/`) y
la Fase 0 sólo hashea `verification/baseline_verified/`. Si el directorio
congelado es la referencia de determinismo, su integridad no está protegida por
ningún manifiesto. Propuesta: hashearlo también, o declarar
`baseline_verified/` como la única referencia. **RESUELTA (parcial, por tu
decisión)**: el directorio se añade a `.gitignore` (`.gitignore:57`) y se
conserva **en disco** como referencia local del determinismo (la comparación
`frozen_vs_durable` del log de evidencia lo referencia, así que borrarlo
rompería la trazabilidad). Queda por tanto **untracked a propósito** y **sin
anclar**: `baseline_verified/` es el baseline commiteado y anclado.

**D6 — `output_manifest.txt` lista rutas absolutas.** `run_all.sh` construye
`OUT_DIR` desde `SCRIPT_DIR` (absoluto), así que
`verification/output_manifest.txt` contiene
`/home/ilich/Escritorio/diamond-framework/verification/baseline_verified/…`.
El fichero es durable pero **no portable** entre máquinas. El anclaje de Fase 0
no depende de él: `output_manifest.sha256` se generó con `find` sobre rutas
relativas y sí es portable. **RESUELTA** en el cierre, y en la **fuente**, no
sólo en el `.txt`: `run_all.sh` incorpora `REPO_ROOT` + un helper `rel_of()` y
emite el listado **relativo al root del repo** (lo que quede fuera del repo
sigue absoluto). El listado se regeneró con el propio harness
(`bash verification/run_all.sh --resume`, que re-emite el manifiesto sin
re-ejecutar los 35 scripts) y se comprobó: 35 líneas
`verification/baseline_verified/…`, **0 rutas absolutas**, las dos copias
idénticas y `manifest.txt` **byte-idéntico** al de la corrida (hash
`4b4f7288…`, la regeneración no lo tocó). Tras eso se regeneró
`output_manifest.sha256` y `audit_manifest.sha256` con los comandos de Fase 0.

**D7 — Dos defectos en el plan de cierre** (detectados al ejecutarlo).

(a) **La lista de `git add` omite el log de evidencia.**
`verification/fase1_determinism_evidence.txt` es el fichero que leen **G2 y G3**
(ver definiciones en `audit-gate.sh:26`), sigue **untracked** y no está en tu
lista. En un clon limpio, `grep -c "EXIT 0"` sobre un fichero ausente da 0 →
**G2 FAIL**; y G3 daría un **falso PASS**, porque `count()` sale por `|| true`
y una CLI vacía se interpreta como 0. Lo he **incluido** en el commit: sin él el
gate no es reproducible en un clon.

(b) **`audit_manifest.sha256` no puede anclar su propio commit.** El gate
compara el HEAD registrado con el actual (`audit-gate.sh:153`). Hoy coinciden
(`3606760`) y el gate da **PASS=10 FAIL=0** (exit 0) ✓, verificado tras los
pasos 1–3:

    G1 PASS  scripts .py = 36 (>= 35)          G6  PASS  C- worksheets = 50
    G2 PASS  EXIT 0 = 35/35 scripts            G7  PASS  eip_cost_check exit 0
    G3 PASS  lineas DRIFT = 0                  G8  PASS  sin mezcla Estimate/Verified
    G4 PASS  claims Orphan/sin clase = 0       G9  PASS  pdflatex limpio
    G5 PASS  F- entries = 21 (ratificado: 21)  G10 PASS  manifiesto verifica (HEAD 3606760)
    PASS=10 FAIL=0 SKIP=0

Pero el commit que **contiene** el manifiesto tiene necesariamente otro hash (el
hash del commit depende de su contenido, y el contenido incluye el manifiesto):
la **igualdad estricta es insatisfacible** para cualquier manifiesto commiteado.
En `main` recién pusheado el gate daría **G10 FAIL**. No es un indicio de
manipulación — los 35 hashes de outputs y el de `main.tex` se siguen verificando
—, sino un límite lógico de la definición. Opciones: **(1)** relajar G10 a "el
HEAD anclado es **ancestro** del actual" (`git merge-base --is-ancestor`),
conservando íntegra la evidencia de manipulación; **(2)** dejar G10 literal y
aceptar que sólo verifica **antes** del commit; **(3)** re-anclar tras commitear
(no sirve: cada commit vuelve a mover HEAD, es recursivo). No commiteo hasta que
elijas.

### 5.3 Preguntas (decisiones que me corresponden mal tomar solo)

**P1 — Semántica de `verified`.** Lo he implementado como la **confirmación
concreta** de cada fila (p. ej. `0.2655 x 100 = 26.6` para `UNIT`, la fórmula
para `ANALIT`, la sección para `REF`), que es lo que hace verificable la
coherencia con la etiqueta. Si querías un **booleano** (`yes`/`no` = ¿está
reproducido por un script?), dímelo y lo convierto a `verified` ∈ {yes,no} +
columna `evidence` aparte. Con los datos actuales, 18 `UNIT` y 2 `REF` serían
`yes`; en `ANALIT` las 7 también son reproducibles a mano (aritmética exacta).

**P2 — No hay filas `DESIGN`, `EXTA` ni `SCI` entre los 27 huérfanos.** No es
un olvido: los 27 son valores numéricos con respaldo en output (18), derivaciones
en el texto (7) o referencias de sección (2). El caso más discutible son las
**7 filas de `6.5`**: las puse `UNIT` porque `6,500,000` está literal en
`succinctness_comparison_output.txt:39` (el propio output lo rotula `estimado`)
y el eje (iv) las tenía como "Estimate". Si prefieres conservar esa naturaleza
de estimación, el hueco de las seis etiquetas sería `EXTA` (cifras de
Bulletproofs) o `ANALIT` (estimación derivada en el texto). Dime cuál y
re-clasifico esas 7 filas (y sólo esas).

**P3 — Alcance del registro.** `docs/audit/claim-registry.csv` contiene **sólo
las 27 filas huérfanas**, que es lo que pediste clasificar. Los otros 490 tokens
están respaldados por script y ninguna de las seis etiquetas los describe. Si
quieres el registro de los 517, necesito una etiqueta adicional (p. ej. `OK`).

### 5.4 Resultado de la corrida

    bash verification/run_all.sh          # sin argumentos -> OUT_DIR por defecto

| Dato | Valor (derivado) |
|---|---|
| `OUT_DIR` | `verification/baseline_verified/` |
| Scripts ejecutados | **35/35, todos `EXIT 0`** (0 filas `MISSING`) |
| Suma de `runtime_s` | 2074.6 s (**34.6 min**) |
| Fin de la corrida | 2026-10-08 10:28:23 (mtime del manifiesto) |
| Outputs | 35 `*_output.txt` |
| `frozen_vs_durable` | `COMPARED 35 DIFFERENCES 0` |
| `run1_vs_durable` | `COMPARED 35 DIFFERENCES 0` |
| `run2_vs_durable` | `COMPARED 35 DIFFERENCES 0` |

Log máquina: `verification/fase1_determinism_evidence.txt` (47 líneas = 35
`<script> EXIT 0` + 3 líneas `COMPARED … DIFFERENCES 0`; **cero** líneas `DRIFT`).

Los dos scripts que dominan el reloj siguen siendo los mismos del Bloque A:
`heavy_tail_n5000.py` y `heavy_tail_scaled_clique.py` (906.6 s y 491.7 s en la
corrida de referencia).

> Caveat: las dos comparaciones `run1_vs_durable` y `run2_vs_durable` apuntan a
> los directorios transitorios `/tmp/baseline_verify{,2}` del Bloque A, que son
> volátiles. La comparación **reproducible y anclada** es `frozen_vs_durable`
> (contra `verification/baseline_2026-10-06/`, que sí es durable).

    ...
    DRIFT <fichero>               <- sólo si hubiera deriva

La prosa (ventanas de corrida, caveats, historial) vive **en este informe**,
no en el log. Así `grep -c "EXIT 0"` y `grep -c "DRIFT"` significan
exactamente lo que dicen.

## 6. Cierre del Bloque B (pasos del Auditor, pasos 1–4)

**D6 resuelta** (paso 1) — ver §5.2. Listado en rutas relativas, regenerado con
el propio harness, `manifest.txt` intacto, Fase 0 regenerada.

**D1 resuelta** (paso 2) — `audit-gate.sh:88` pasa a `-eq 21`; G5 PASS.

**D5 acotada** (paso 3) — `verification/baseline_2026-10-06/` añadido a
`.gitignore` (línea 57) y conservado en disco como referencia local.

**D7-b resuelta, opción (1) ratificada por el Auditor** — G10 ya no exige
igualdad estricta de HEAD sino que el HEAD anclado sea **ancestro** del actual
(`git merge-base --is-ancestor`). El motivo es lógico, no discrecional: un commit
no puede contener un manifiesto que ancle su propio hash (el hash del commit
depende de su contenido), así que la igualdad estricta sólo era satisfacible
**antes** de commitear el manifiesto. Con esto el gate queda verde también en el
HEAD commiteado.

**D8 — hallazgo nuevo, durante la validación de la opción (1): el ancla no
cubría los 35 outputs.** G10 verificaba únicamente los pares del manifiesto
maestro (`main.tex` + `output_manifest.sha256`) y **contaba sin comprobar** las
líneas del listado cerrado. Consecuencia medida, no teórica: añadir 1 byte a
`verification/baseline_verified/sim_positivity_output.txt` daba **G10 PASS** —
falso verde con el mensaje "35 outputs hasheados". Corregido añadiendo
`sha256sum -c verification/output_manifest.sha256`; la cadena queda cerrada:

    outputs  <-  output_manifest.sha256  <-  audit_manifest.sha256  <-  main.tex

El mensaje de FAIL ahora nombra la causa concreta en lugar de culpar siempre al
HEAD.

Pruebas negativas ejecutadas (las cinco sobre el árbol real, restaurando después
por hash; todas exigen G10 FAIL salvo la última):

| Test | Manipulación | G10 tras el fix |
|---|---|---|
| A | HEAD anclado → `0000…0` | FAIL · `HEAD '0000000' no ancla '3606760'` |
| B | +1 byte en un `*_output.txt` | FAIL · `hashes de outputs` — **antes del fix: PASS indebido** |
| C | +1 byte en `docs/paper/main.tex` | FAIL · `manifiesto maestro` |
| D | línea añadida a `output_manifest.sha256` | FAIL · `manifiesto maestro` |
| E | árbol intacto | **PASS=10 FAIL=0 SKIP=0** (exit 0) |

**D7-a** — se incluye `verification/fase1_determinism_evidence.txt` en el commit
(§5.2): es la entrada de G2 y G3 y sin él el gate no es reproducible en un clon.

Cambios respecto de la letra de las instrucciones del cierre, todos reportados:
(i) el `.txt` se corrigió en su **fuente** (`run_all.sh`), no sólo el artefacto;
(ii) se añade al `git add` el log de evidencia (D7-a); (iii) G10 incorpora las
correcciones D7-b y D8, y el mensaje de commit añade un párrafo describiéndolas
(las cinco líneas originales se conservan verbatim).

### 6.1 Datos del cierre

| Dato | Valor |
|---|---|
| Commit | `794ba7c` (`794ba7ca078d06e3a75f069a5e33f69a13510ea1`) |
| Mensaje | `feat(audit): close Block B - deterministic baseline, claim registry, and tamper-evident manifest` |
| Ficheros | 47 (+2487 / −91); incluye los 35 outputs + `manifest.txt` + `output_manifest.txt` |
| Push | `4d55687..794ba7c  main -> main` (exit 0) — `main` = `origin/main` |
| Gate en el HEAD nuevo | **PASS=10 FAIL=0 SKIP=0** (exit 0); G10 = `HEAD anclado 3606760 -> actual 794ba7c` |
| Sin commitear | `docs/audit/session-report.md` (untracked; fuera de tu lista) |

El ancla de Fase 0 registra `3606760` (el HEAD de entonces) y el commit de cierre
es `794ba7c`: G10 lo acepta como relación de **ancestro** (D7-b). Los 35 hashes
de outputs y el de `main.tex` se verifican byte a byte contra el árbol actual, así
que la evidencia de manipulación es la misma que con igualdad estricta.

### 6.2 Hallazgos de la remediación post-clausura (D9, D10, D11)

Estos hallazgos no son del cierre del Bloque B: D9 y D10 salen de la auditoría
post-clausura (`post-closure-audit.md`, P-6 y P-7) y de su remediación; D11 salió
de la implementación de G11 (commit `5bd9e3b`, sesión de sellado) y lo ratificó
el Auditor. Se registran aquí para que la serie D1…D11 quede completa en un solo
sitio.

**D9 — La Fase 0 original era locale-dependiente.**

*Síntoma.* `output_manifest.sha256` se generó con
`find … | sort | xargs sha256sum` bajo el **locale del sistema** (la máquina de
generación corría `es_VE.UTF-8`), no bajo `LC_ALL=C`. El orden commiteado no
coincide con el de C: se intercambian dos entradas **adyacentes**
(`recalibrate_top_output.txt` ↔ `r_std_specification_output.txt`), porque la
colación de glibc ignora `_` y la de C no. Evidencia re-derivada:

    awk '{print $2}' verification/output_manifest.sha256 > /tmp/ord_committed.txt
    LC_ALL=C sort /tmp/ord_committed.txt | diff /tmp/ord_committed.txt -
    #  23d22  < verification/baseline_verified/recalibrate_top_output.txt
    #  24a24  > verification/baseline_verified/recalibrate_top_output.txt
    #  es_VE.UTF-8 y en_US.UTF-8 SI reproducen el orden commiteado; C no.

*Impacto real.* `fase0_anchor.sh --check` (regenera en temporal y compara pares
sha256) no reproducía el ancla en una máquina con otro locale.

*Impacto latente.* Si alguien regenera `output_manifest.sha256` bajo otro locale
y lo commitea, G10 falla por el paso (i): lo que está anclado es el **hash del
fichero**, no su orden, y el mensaje lo nombra (`manifiesto maestro`). No es el
caso del CI, que sólo verifica con `sha256sum -c` (order-independent) y nunca
regenera.

*Fix.* `verification/fase0_anchor.sh` (commit `48b6a3c`), con clave de ordenación
locale-independiente: `LC_ALL=C` sobre la ruta **sin** guiones bajos
(`fase0_anchor.sh:110-111`). Reproduce el ancla byte a byte (`cmp` limpio).

**D10 — G10 exige historia completa del repo: el checkout del CI es shallow.**

*Síntoma.* La primera corrida del CI (run `37804484099`, commit `48b6a3c`) falló:

    G10  FAIL  manifiesto no verifica (35 outputs): HEAD '3606760' no ancla '48b6a3c'
    PASS=8 FAIL=1 SKIP=1

No es defecto del gate, del manifiesto ni del generador: los pasos (i) y (ii) de
G10 pasaron —el mensaje no lleva sus prefijos `manifiesto maestro;` ni
`; hashes de outputs`—, es decir los 35 hashes de outputs y el par maestro
verificaron en el runner.

*Causa.* `actions/checkout@v4` hace **shallow clone** por defecto
(`fetch-depth: 1`), y así lo muestra el log del propio runner. El commit anclado
`3606760` no existe en la historia local del runner, así que
`git merge-base --is-ancestor 3606760 HEAD` sale 128 (`fatal: Not a valid commit
name`) y G10 cae por esa rama. El stderr de git va a `/dev/null`, así que
"commit ausente" y "no ancestro" producen el mismo mensaje
(`audit-gate.sh:171-173`): por eso el síntoma no bastaba y hubo que reproducirlo.
Reproducido en local con `git clone --depth 1 file://…`: mismo FAIL sobre el
mismo árbol; tras `git fetch --unshallow` en ese mismo clon: `PASS=10 FAIL=0`.

*Propiedad fail-closed.* En clon shallow G10 emite **FAIL**, no SKIP: no hay
PASS vacuo. Corolario operativo: cualquier clon local que corra el gate —o
`fase0_anchor.sh --check`, que usa la misma comprobación de ancestro— necesita
historia completa, o `git fetch --unshallow`.

*Fix.* `fetch-depth: 0` en `.github/workflows/audit-gate.yml` (commit `56bf653`).
No sirve un `fetch-depth: N` fijo: la profundidad necesaria para alcanzar el
commit anclado crece con cada commit (era 3 en `48b6a3c`; hoy el ancla está 3
commits por detrás del HEAD, es decir harían falta N=4).

*Verificación.* Segunda corrida verde: run `37805524979`, commit `56bf653`,
`fetch-depth: 0` en el log,
`G10 PASS manifiesto verifica (35 outputs; HEAD anclado 3606760 -> actual
56bf653)`, `PASS=9 FAIL=0 SKIP=1` (G9 SKIP por `pdflatex` ausente:
`audit-gate.sh:120-135` degrada a SKIP y el cierre sólo rompe por FAIL).

Corridas posteriores, también verdes, sobre los dos commits de documentación que
siguieron: run `37806740664` (`7ee0d1f`) y run `37808594205` (`496fc48`), ambas
`PASS=9 FAIL=0 SKIP=1` (valores leídos del log del runner, no de este informe).

**D11 — G10 hace SKIP cuando falta su input manifiesto: fail-open (cubierto por G11).**

*Síntoma.* Con `verification/output_manifest.sha256` y
`verification/audit_manifest.sha256` ausentes, G10 emitía **SKIP**, no FAIL: el
gate salía `PASS=9 FAIL=0 SKIP=1`, **exit 0** — verde sin ancla alguna. G10 era
la única guarda que leía los manifiestos, así que retirarlos bastaba para que el
gate certificara la nada.

*Causa.* La definición ratificada de G10 (Resolución 3, §3) trata el input
ausente como «no verificable»: la rama `emit G10 SKIP "sin manifiestos sha256
todavia (Fase 0)"` (introducida en `48b6a3c`). Es defendible para el estado en
que el manifiesto **nunca existió** —el gate se escribió antes de la Fase 0— y es
**fail-open** cuando existió y fue retirado: «todavía no» y «ya no» producen la
misma salida, y lo segundo es manipulación.

*Mitigación.* G11 (`fase0_anchor.sh --check`, commit `5bd9e3b`) es **fail-closed**
ante ese input: si el ancla no se re-deriva, emite FAIL. No se tocó G10 —su
definición está ratificada y se preserva—, así que la cobertura se añadió
*encima*. G11 no forma parte de la Resolución 3 (§3 sigue siendo el registro
ratificado de G1–G10): se añadió después y el Auditor lo ratificó en la sesión de
sellado.

*Residual.* G10 conserva su fail-open por decisión: endurecerlo exige revisar su
definición ratificada, y el sitio natural es **P-4/D1**, donde la raíz se mueve de
todos modos. Y lo que G11 **no** cierra es el defecto de fondo —el verificador
dentro de lo verificado—: sube el coste a «hay que modificar dos ficheros en vez
de uno» (ratchet), no lo elimina.

*Evidencia* (medida; el árbol se restauró y `git status` quedó limpio). El gate
PRE-G11 se toma de `120634d` (C1a: ya con G3 cerrado, aún sin G11): **`HEAD~1` no
sirve para esta prueba**, porque `47b7d1f` ya lleva G11. El temporal va dentro de
`verification/` a propósito, porque el gate resuelve `REPO_DIR` desde su ruta.

    git show 120634d:verification/audit-gate.sh > verification/.tmp_pre_g11_gate.sh
    mv verification/output_manifest.sha256 /tmp/om.bak
    mv verification/audit_manifest.sha256 /tmp/am.bak
    bash verification/.tmp_pre_g11_gate.sh 2>&1 | grep -E '^G10|^PASS='
    #  G10  SKIP  sin manifiestos sha256 todavia (Fase 0)
    #  PASS=9 FAIL=0 SKIP=1
    bash verification/audit-gate.sh 2>&1 | grep -E '^G10|^G11|^PASS='
    #  G10  SKIP  sin manifiestos sha256 todavia (Fase 0)
    #  G11  FAIL  ancla no re-derivable (exit 1): ... output_manifest.sha256  DISCREPA ...
    #  PASS=9 FAIL=1 SKIP=1
    mv /tmp/om.bak verification/output_manifest.sha256
    mv /tmp/am.bak verification/audit_manifest.sha256
    rm -f verification/.tmp_pre_g11_gate.sh

Exit codes capturados con `$?` (no a través del pipe): PRE-G11 `exit 0` (verde sin
ancla), con G11 `exit 1`. Restaurado: `PASS=11 FAIL=0 SKIP=0`, `G11 PASS`.

*Nota de método.* Esta entrada evita citar por número de línea: los números
envejecen con cada edición del gate —las citas de D10 (`audit-gate.sh:120-135`,
`171-173`) corresponden a la numeración de `48b6a3c`, no a la vigente— y una cita
que no resuelve es una afirmación falsa en el árbol. Localización por símbolo, p.
ej. `grep -n 'sin manifiestos sha256 todavia' verification/audit-gate.sh`. Sin
este registro, dentro de dos sesiones «G11 cubre el caso» se leería sin saber por
qué existía el caso.


