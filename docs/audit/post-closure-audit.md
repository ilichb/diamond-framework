# Auditoría post-cierre — README ↔ repo

Fecha: 2026-10-08. HEAD auditado: `794ba7c` (cierre de Bloque B).
Alcance: cadena completa *README → docs → verificación → paper → ancla*;
correlaciones entre documentos, implicaciones de esas correlaciones, y
estado del árbol.

Método: todo valor de esta pasada se obtuvo con un comando y el comando
va al lado. Donde un documento y una derivación en vivo difieren, gana la
derivación (regla 7 del repo, `docs/audit/session-report.md:6-9`).

## 0. Estado de partida (re-derivar)

    bash verification/audit-gate.sh        # -> PASS=10 FAIL=0 SKIP=0 (exit 0)
    git status --short                     # ->  M docs/audit/bloque-b-report.md
                                           #    ?? docs/audit/session-report.md

Décima guarda, verbatim del gate:

    G10  PASS  manifiesto verifica (35 outputs; HEAD anclado 3606760 -> actual 794ba7c)

El árbol queda intacto por esta auditoría: las nueve ediciones de §3 sólo
tocan documentos (ninguno entra en `output_manifest.sha256` ni en
`audit_manifest.sha256`), y `main.tex` no se toca.

## 1. Correlaciones verificadas (documento ↔ fuente)

Cada fila se comprobó contra el fichero o el comando que la respalda. No
se listan las que coinciden por construcción (las que produce un script
que el propio gate ejecuta); se listan las que podían divergir.

| Afirmación | Documento | Comprobación | Veredicto |
|---|---|---|---|
| "lists the 35 scripts" | `main.tex:1115` | `grep -c '    python3 ' verification/README.md` = 35 | OK |
| 35 scripts, 36 `.py` no archivados | gate G1 = 36 | `find verification -maxdepth 2 -name '*.py'` = 36 (35 + `eip_cost_check.py`) | OK |
| 35/35 `EXIT 0` | G2 = 35 | `awk 'NR>1{print $2}' verification/baseline_verified/manifest.txt` | OK |
| 0 líneas `DRIFT` | G3 = 0 | `grep -c DRIFT verification/fase1_determinism_evidence.txt` | OK |
| 21 entradas de falsación | G5 = 21; `main.tex` "twenty-one" | `grep -c '^### F-' docs/audit/numerical-verification.md` = 21; `grep -c 'Verdict:'` = 21 | OK |
| 50 worksheets C- | G6 = 50 | `grep -c '^### C-' docs/audit/content-audit-pending.md` = 50; el propio fichero cierra: "All findings C-01 through C-50 are closed" | OK |
| 27 huérfanos adjudicados | G4; `bloque-b-report.md:56-73` | `wc -l docs/audit/claim-registry.csv` = 28 (27 + cabecera); clases UNIT 18 / ANALIT 7 / REF 2 | OK |
| errata 518 → 517 | `eje-iv-reproduction-report.md:8-30` | bloque de errata presente; script del cross-check con un único commit (`34f85f0`) | OK |
| "eleven sections", "sixteen-item reference list" | `docs/paper/README.md` | `grep -c '^\\section' main.tex` = 11; `grep -c '\\bibitem' main.tex` = 16 | OK |
| sha256/bytes/fecha del snapshot | `releases/README.md` | `sha256sum` = `bacd6242…cde`; 624450 bytes; 31 páginas (`pdfinfo`) | OK |
| positivo bajo saltos multiplicativos | README `0% violations` | `sim_positivity_output.txt` | OK |
| Tucker −70.8% | README / paper | `tensor_compression_output.txt` | OK |
| 0 R1CS, 0.72 KB | README / paper | `groth16_bulletproof_output.txt` | OK |
| `n* = floor(B/B*)` | README | `simulate_data_layer_v3.py:32` (`int(B / B_STAR)  # floor`) | OK |
| beneficio atacante `-502` | README | `attacker_profit_analytical_output.txt` | OK |
| `F0* = π_val − ω̄·Θ`, saturado | README | `fee_specification.py:60-63`; salida `F0* = 0.0500`, saturación OK | OK |
| TPR 97.2% vs 3.3% (ratio 29.2×) | README log; `numerical-verification.md:37-38` | `wilson_intervals_output.txt` (0.9720 y 0.0333; ratio 29.16×); `calibration_modularity_output.txt:18,27` | OK |
| `181,142` gas = EIP-197 + 142 | README log (F-017) | `numerical-verification.md:246-258`; `eip_cost_check.py` (G7 exit 0) | OK |
| "solo NumPy y SciPy" | `main.tex:1115` | imports de los 36 `.py` no archivados: `numpy`, `scipy` + stdlib (`sys`, `os`, `math`, `re`, `pathlib`, `multiprocessing`, `dataclasses`) + 4 imports entre scripts hermanos del mismo directorio | OK |
| 0 enlaces rotos | `README.md` | los 4 candidatos de un `grep` ingenuo son prosa (`L[C_R](r)`), no enlaces | OK |


## 2. Hallazgos — corregidos en esta pasada

Ninguno de estos ficheros está anclado por `output_manifest.sha256` ni por
`audit_manifest.sha256`, y ninguno cambia el número de scripts `.py` ni
`main.tex`, así que el gate sigue verde (ver §4). Se numeran `A` para no
colisionar con las `C-`, `F-` y `D-` ya usadas.

### A-1 — El README citaba `18 entries` para el log de falsación

`README.md` decía `18 entries` en la lista de etiquetas de la tabla de
Conclusiones. La cifra ratificada es 21 (G5) y el paper ya escribe
"twenty-one" (`main.tex:1138`). Es la errata de la resolución D1 vista desde
el otro lado: D1 corrigió el gate, A-1 corrige el segundo sitio donde
sobrevivía el 18.

    grep -c '^### F-' docs/audit/numerical-verification.md   # 21

### A-2 — El README llamaba "open findings" al worksheet

`README.md` decía: "Open findings from the content audit of
`docs/paper/main.tex` are tracked separately in
`docs/audit/content-audit-pending.md`; they are open questions, not
corrections." El propio worksheet cierra las 50 y `handoff.md:36` se titula
"Backlog: C-01 through C-50, all closed". El README era el único documento
que todavía lo presentaba como abierto. Se reescribe para que diga lo que
es: el registro completo de los 50 hallazgos, cerrados, con su evidencia.

    tail -3 docs/audit/content-audit-pending.md   # "All findings C-01 through C-50 are closed."

### A-3 — Fila "Bootstrap dynamics" con el enlace en la columna 2

Todas las filas de la tabla Status llevan el artefacto en la tercera
columna; esa fila embebía el enlace al final del texto de la segunda. La
tabla se renderiza igual (el recuento de pipes es correcto —4 en las 10
filas, comprobado fila por fila—), pero la consistencia se rompía. Se mueve
el enlace a su columna.

### A-4 — `docs/paper/README.md` declaraba un PDF de 31 páginas

"produces a 31-page PDF" describe el snapshot del 2026-10-03. La fuente
actual compila a 34 páginas.

    cd docs/paper && pdflatex -interaction=nonstopmode main.tex >/dev/null && pdfinfo main.pdf | grep Pages
    # Pages: 34   (snapshot: pdfinfo releases/diamond-framework-2026-10-03.pdf -> Pages: 31)

Se separan las dos cosas: el snapshot (31 pp, anclado por hash) y la fuente
actual (34 pp), cada una con su fichero y su comando.

### A-5 — `releases/README.md`: la divergencia ya no es "una línea"

El README del release afirma que un rebuild de la fuente actual difiere del
snapshot en "exactly one line of text" y que "a rebuild is
content-equivalent". Era cierto el 2026-10-03; hoy la fuente ha avanzado 43
commits que la tocan.

    git rev-list --count ea8564d..HEAD -- docs/paper/main.tex   # 43
    git diff --shortstat ea8564d..HEAD -- docs/paper/main.tex   # 111 insertions(+), 58 deletions(-)
    git rev-list --count ea8564d..HEAD                          # 100

Los datos de procedencia del PDF (hash, bytes, commit, 31 páginas) siguen
siendo exactos y no se tocan: lo que se acota es la comparación, que pasa a
estar fechada y a remitir al comando que da el número de commits. El
snapshot no se re-exporta.

### A-6 — `compile-logs/README.md`: mismo 31 páginas

"produces a 31-page PDF — the same page count as the reference snapshot"
mezclaba el log histórico con el estado actual. Se acota al snapshot y se
dice cuál es la página actual medida.

### A-7 — `handoff.md` con inventario obsoleto y sin el gate

El handoff es el punto de entrada durable declarado
(`handoff.md:254-261`), y su §5 decía "35 non-archived `.py` files under
`verification/` (42 total, 7 under `*/archive/`)". Números reales hoy:

    find verification -name '*.py' -not -path '*/archive/*' | wc -l   # 36
    find verification -name '*.py' | wc -l                            # 43
    find verification -path '*/archive/*' -name '*.py' | wc -l        # 7

El `.py` número 36 es `verification/eip_cost_check.py`, el helper de la
guarda G7 añadido en Bloque A (`604b3f5`). Consecuencias, ambas corregidas:

- "Every script has a corresponding `*_output.txt`" ya no es cierto tal como
  está: hay 35 `results/*_output.txt` para 36 `.py`; `eip_cost_check.py` no
  emite salida (G7 lee su exit code).
- El handoff no mencionaba el gate en absoluto. Se añade una sección con el
  comando (`bash verification/audit-gate.sh`), el mapa de las diez guardas y
  las anclas: es lo que necesita cualquier lector para no re-descubrir
  Bloque A/B.

Efecto colateral, deliberado: `eje-iii-counters-report.md:63` citaba
`handoff.md:200` como fuente de "35 non-archived (42 total, 7 archive)". Esa
cita era cierta para el HEAD `2bfb946` del acta y ya no resuelve; el acta no
se reescribe (§6 lo justifica). El valor vivo es el de esta sección.


### A-8 — Tabla de runtimes del README sin procedencia y con deriva

`verification/README.md` publicaba una tabla "Approximate runtimes on a
2020-era desktop" con los mismos valores que `main.tex` §9.2, y la
implicación latente es que siguen describiendo el suite de hoy. No es así:
varias filas se han optimizado y el README no lo decía. Deriva medida contra
la corrida anclada:

    awk 'NR>1{printf "%-32s %8.2f s\n", $1, $3}' verification/baseline_verified/manifest.txt | sort -k2 -nr | head
    awk 'NR>1{s+=$3} END{printf "total %.1f s\n", s}' verification/baseline_verified/manifest.txt   # total 2074.6 s

Dos filas del README están obsoletas por órdenes de magnitud:
`clique_spectra.py` (17 s declarados; hoy 0.16 s) y
`heavy_tail_scaled_clique.py` (24 min a un núcleo; hoy 499 s en 6 núcleos,
que es lo que la propia tabla ya anotaba como "~5 min on 6 cores"). La
corrección mantiene los valores del paper (que son su tabla §9.2, medida a
un núcleo) pero los etiqueta como estimaciones del equipo de referencia y
apunta a `manifest.txt` como fuente de los tiempos medidos, con el comando
de derivación. No se teclea una tabla nueva de 35 tiempos: el manifiesto ya
es el artefacto (`output_manifest.txt` lo lista, `baseline_verified/` lo
guarda y el gate lo verifica).

### A-9 — `run_all.sh` documentaba tres scripts que escriben ficheros

El comentario del harness dice que "the three scripts that emit a file write
to a path relative to their own location". En el suite actual no hay
ninguno:

    grep -rlE 'savetxt|to_csv|savez|np\.save|savefig|json\.dump' verification --include='*.py'   # vacio
    find verification -name '*.csv' -o -name '*.npy' -o -name '*.pkl'                             # vacio

Se corrige el comentario: la suite no escribe ficheros, y las reglas de
`results/*.csv` en `.gitignore` quedan como política preventiva, no como
descripción de un mecanismo vivo. La propiedad que se quería documentar —la
CWD-independencia— se mantiene y se enuncia aparte.

### A-10 — El log de evidencia apuntaba a un directorio no versionado

`verification/fase1_determinism_evidence.txt` es entrada de G2/G3 y está
commiteado (D7-a), pero compara contra `verification/baseline_2026-10-06/`,
que está en `.gitignore:57` por decisión D5: en un clon limpio esa
comparación no se puede re-ejecutar. La decisión es correcta; lo que faltaba
es que el propio log lo dijera. Se añade una línea de cabecera que lo
declara, sin tocar ninguna línea `EXIT`/`DRIFT` de las que dependen G2 y G3.


## 3. Robustez del gate: pruebas negativas sobre el árbol real

Las tres se ejecutaron en esta pasada; el árbol se restauró por copia y por
`git checkout`, y §5 confirma que quedó limpio.

| # | Manipulación | Resultado real | Lectura |
|---|---|---|---|
| B-1 | registro de claims reducido a su cabecera | `G4 PASS claims Orphan/sin clase = 0 (registro: 0 filas clasificadas)` y **PASS=10** | **G4 es vacuo**: ni un registro vacío ni un token nuevo sin fila lo rompen |
| B-2 | `fase1_determinism_evidence.txt` movido fuera | `G2 FAIL EXIT 0 = 0/35` y `G3 PASS lineas DRIFT = 0` | **G3 es vacuo sin el log**: "0 DRIFT" es verdad trivial si no hay líneas que contar |
| B-3 | una línea borrada de `output_manifest.sha256` | `G10 FAIL manifiesto no verifica (34 outputs): manifiesto maestro` | acierto de D8: el encadenado sí detecta la baja |

B-3 merece detalle: borrar un par no rompe `sha256sum -c` (los 34 restantes
verifican), pero rompe el eslabón `output_manifest.sha256 ←
audit_manifest.sha256`. En otras palabras, G10 detecta la manipulación
mientras el maestro no se regenere (ver P-4).

    # B-1
    cp docs/audit/claim-registry.csv /tmp/reg.bak && head -1 /tmp/reg.bak > docs/audit/claim-registry.csv
    bash verification/audit-gate.sh | grep -E 'G4|PASS=' ; cp /tmp/reg.bak docs/audit/claim-registry.csv
    # B-2
    mv verification/fase1_determinism_evidence.txt /tmp/evid.bak
    bash verification/audit-gate.sh | grep -E 'G2|G3' ; mv /tmp/evid.bak verification/fase1_determinism_evidence.txt
    # B-3
    sed -i '3d' verification/output_manifest.sha256 ; bash verification/audit-gate.sh | grep G10
    git checkout -- verification/output_manifest.sha256

Advertencia operativa: estas pruebas no son paralelizables. Ejecutadas a la
vez, la manipulación de B-3 contamina el resultado de B-1/B-2 (el segundo
`FAIL` que aparece entonces es G10, no una guarda rota).

## 4. Implicaciones y decisiones abiertas (para el Auditor)

`P-1`, `P-2` y `P-3` son las preguntas ya planteadas en Bloque B; aquí sólo
se añade la evidencia localizada. `P-4` a `P-7` son nuevas y salen de las
correlaciones de §1 y de las pruebas de §3.

### P-1 — Semántica de la columna `verified`

La columna contiene **cadenas de derivación**, no booleanos: 27 filas, 16
valores distintos (`6500000 / 1e6 = 6.5` ×7, `0.9720 x 100 = 97.2`,
`subsections 10.1-10.10 exist under Limitations (section 10)`…). La
evidencia en sentido estricto (fichero:línea) vive en la columna vecina.
Decisión: ¿se renombra la columna (`derivation`) o se convierte en
booleano dejando la derivación en `evidence`?

### P-2 — La etiqueta de los 7 tokens `6.5`

Es el único grupo del registro que el propio paper califica como
**Estimated**, no como medido:

    grep -n '6\.5M' docs/paper/main.tex        # 555 y 1206: fila "Estimated"

El registro los etiqueta `UNIT` con la derivación `6500000 / 1e6 = 6.5`. Un
`UNIT` afirma "conversión de unidad de un valor medido"; el paper dice
"approximate/Estimated". Si la taxonomía del Auditor tiene un bucket para
estimación de origen externo (`EXTA`), estos 7 son su caso de uso, no el de
`UNIT`. Es una decisión semántica, no un error de conteo: la clase no
cambia el total de 27.

### P-3 — Alcance 27 frente a 517

El registro sólo contiene huérfanos: los ~490 tokens que el eje (iv) ya
había clasificado como OK no tienen fila (`eje-iv-reproduction-report.md`).
Combinado con B-1, hoy **ninguna guarda detecta un token nuevo sin fila**:
`G4` cuenta huérfanos dentro del registro, no tokens del paper contra el
registro. Cerrar la cadena exige o bien (a) una guarda que corra
`docs/audit/eje-iv-crosscheck.py` y compare el total de tokens con
`490 + 27`, o bien (b) declarar explícitamente que el registro es un
subconjunto y que el inventario completo es el eje (iv).

### P-4 — G10 no ata el ancla a la lista cerrada ni al blob commiteado

Tres piezas hoy sueltas:

1. El maestro no se compara con su versión versionada. Un atacante con
   permiso de escritura regenera los tres ficheros y el gate pasa: el ancla
   sólo es tamper-evident frente a ediciones *parciales*. Mitigación barata:

       git diff --quiet HEAD -- verification/audit_manifest.sha256 verification/output_manifest.sha256

2. El listado cerrado (`output_manifest.txt`, 35 rutas) y el listado
   hasheado (`output_manifest.sha256`) no se comparan entre sí. Mitigación:

       test "$(wc -l < verification/output_manifest.sha256)" -eq "$(wc -l < verification/output_manifest.txt)"

3. El testigo externo no se publica. `sha256sum
   verification/audit_manifest.sha256` = `49eb2ae2161183debc842d3d8d44ab4b1d0c061bc72b9a0c6424dc5c3ea4b3c8`,
   y está almacenado en `794ba7c`; el gate no puede compararlo contra nada
   (es el nivel raíz de la cadena). La mitigación honesta es registrarlo en
   §6.1 del reporte de cierre y/o firmar el commit/tag de anclaje. Nota
   operativa: el encabezado del maestro usa fecha local del sistema
   (`jue 08 oct 2026 10:41:13 -04`), así que el fichero no es reproducible
   byte a byte y **el testigo cambia en cada re-anclaje**; para el próximo,
   `date -u +%Y-%m-%dT%H:%M:%SZ`.


### P-5 — La tabla §9.2 del paper y sus 67 minutos

`main.tex` §9.2 lista 15 filas de tiempos y cierra con "approximately 67
minutes on a single core". Son estimaciones del equipo de referencia
(declaradas como tales: "on a 2020-era desktop") y la corrida anclada mide
otra cosa: 2074.6 s = 34.6 min en 6 núcleos, con filas desviadas hasta 100×.
No es un error del paper —es una tabla de estimaciones, y el paper no afirma
que sean reproducibles al segundo— pero sí es la última afirmación
cuantitativa del paper sin artefacto que la fije. Cualquier edición de
`main.tex` rompe G10 hasta re-anclar (el maestro hashea `main.tex`), así que
la propuesta va en un solo commit, a ratificar:

1. refrescar en §9.2 las filas con deriva grande y sustituir "All others
   `< 5 s` each" por la remisión a `verification/baseline_verified/manifest.txt`
   (que es el artefacto que las mide);
2. ajustar `main.tex:1115` ("expected runtimes") si (1) cambia el enunciado;
3. regenerar Fase 0 sobre `baseline_verified/` (que no ha cambiado) para que
   el hash de `main.tex` vuelva a casar, y commitear.

Mientras no se ratifique, `main.tex` no se toca: esta auditoría deja el gate
verde.

### P-6 — La Fase 0 no tenía generador versionado (resuelto)

Los comandos del anclaje existen, en `/tmp/blkA/post.sh`, es decir fuera del
repo. Ahí se lee que el `output_manifest.sha256` se generó con

    find verification/baseline_verified -type f -name "*_output.txt" -o -name "*.csv" | sort | xargs sha256sum

mientras `run_all.sh:9-11` documenta justo lo contrario ("No `find` glob is
used downstream; Fase 0 hashes exactly the listed files"). Los dos
enunciados no pueden ser ciertos a la vez, y el de `post.sh` tiene además un
defecto de precedencia (`-type f -name A -o -name B` agrupa como
`(-type f -name A) -o (-name B)`). Hoy no se materializa —el directorio no
tiene `.csv`— pero el día que un script vuelque un CSV junto a sus outputs,
el ancla crecería sin que nada lo declare. Propuesta: `verification/fase0_anchor.sh`
que regenere ambos manifiestos recorriendo `output_manifest.txt` (sin
`find`), con el encabezado en ISO-8601 UTC, más la actualización del
comentario de `run_all.sh` para que describa el script y no una regla
implícita.

**Resuelto.** `verification/fase0_anchor.sh` (commit `48b6a3c`) recorre
`output_manifest.txt` (lista cerrada, sin `find`), resuelve cada ruta, sella en
ISO-8601 UTC (`date -u`) y reproduce el ancla byte a byte; `--check` usa la
semántica de G10/D7-b (el HEAD anclado debe ser ancestro del actual) y es
determinista salvo la línea de timestamp. El comentario de `run_all.sh`
(`run_all.sh:18-19`, "No `find` glob is used downstream") pasa a ser cierto tal
como está: el generador hashea exactamente los ficheros listados. Hallazgo
colateral de la remediación: la Fase 0 original era **locale-dependiente**
→ registro **D9** en `bloque-b-report.md` §6.2.

### P-7 — `.github/workflows/` estaba vacío (resuelto)

`.github` no tenía ni un fichero versionado (`git ls-files .github` = vacío) y
`workflows/` era un directorio vacío: un andamio que git no puede seguir y que
no ejecuta nada. **Resuelto:** CI activado en `48b6a3c`, corregido en `56bf653`
(G10 requiere historia completa: `fetch-depth: 0`). Primera corrida verde: run
`37805524979` (commit `56bf653`; `PASS=9 FAIL=0 SKIP=1`, G9 SKIP por `pdflatex`
ausente). El CI mínimo que este repo admite sin tocar nada más es el propio
gate, que ya degrada G9 a SKIP cuando no hay `pdflatex` —el YAML de abajo era
la propuesta; el fichero implementado es `.github/workflows/audit-gate.yml`
(Python 3.10, y corre además `python3 verification/eip_cost_check.py`):

    name: audit-gate
    on: [push, pull_request]
    jobs:
      gate:
        runs-on: ubuntu-latest
        steps:
          - uses: actions/checkout@v4
          - uses: actions/setup-python@v5
            with: { python-version: '3.12' }
          - run: pip install -r verification/requirements.txt
          - run: bash verification/audit-gate.sh

Ha sido la primera ejecución del gate fuera de esta máquina —el testigo
externo que P-4 pide— y no crea ningún valor tecleado. (El hash raíz del ancla
sigue sin publicarse fuera del repo: P-4.3 permanece abierto.)

## 5. Validación de esta pasada

    bash verification/audit-gate.sh      # PASS=10 FAIL=0 SKIP=0, G10 = "HEAD anclado 3606760 -> actual 794ba7c"
    git status --short                   # sólo los ficheros de documentación tocados + session-report.md (untracked)

Ficheros tocados por la auditoría, ninguno de ellos anclado:

| Fichero | Qué se cambió |
|---|---|
| `README.md` | A-1 (`21 entries`), A-2 (worksheet cerrado), A-3 (enlace a su columna) |
| `docs/paper/README.md` | A-4 (31 pp del snapshot vs 34 pp actuales) |
| `docs/paper/releases/README.md` | A-5 (comparación fechada + comando) |
| `docs/audit/compile-logs/README.md` | A-6 (idem) |
| `docs/audit/handoff.md` | A-7 (inventario 36/43/7, `eip_cost_check.py`, sección del gate) |
| `verification/README.md` | A-8 (procedencia + deriva; bloque `## Running` intacto, es entrada de `run_all.sh`) |
| `verification/fase1_determinism_evidence.txt` | A-10 (nota de cabecera; cero líneas `EXIT`/`DRIFT` añadidas) |
| `verification/run_all.sh` | A-9 (comentario del harness) |
| `docs/audit/post-closure-audit.md` | este informe (nuevo) |

Cadena de custodia del ancla, re-verificada al final de la pasada:

    sha256sum -c verification/output_manifest.sha256                                   # 35 OK
    grep -E '^[0-9a-f]{64}  ' verification/audit_manifest.sha256 > /tmp/pairs && sha256sum -c /tmp/pairs   # 2 pares OK
    git merge-base --is-ancestor 3606760 HEAD && echo ancestro OK

## 6. Lo que esta auditoría NO toca, y por qué

- `docs/paper/main.tex`: es objeto del ancla (P-5). Ninguna edición sin
  ratificación y re-anclaje.
- `docs/audit/bloque-b-report.md`: salió de su ` M` en el mismo commit que este
  registro (adenda §6.1 + hallazgos D9/D10 de §6.2). No se mezcló con esta
  pasada.
- `docs/audit/session-report.md`: sigue *untracked*, que es la convención
  declarada por los ejes anteriores (`eje-i-claims-report.md:160`,
  `eje-iv-reproduction-report.md:696`). Si se quisiera un `git status`
  limpio habría que decidir entre versionarlo o ignorarlo; hoy no es un
  defecto, es una convención del repo.
- `docs/audit/{eje-i,eje-ii,eje-iii,eje-v,eje-vi}-*.md`: son actas fechadas
  con su HEAD de entonces. Contienen cifras caducas por diseño (18 findings,
  33 páginas…) y todas se abren con la regla "si un número discrepa de una
  derivación en vivo, gana la derivación". No se reescribe historia; el
  estado actual es responsabilidad del handoff, que es el documento que sí
  se ha actualizado (A-7).
- `docs/paper/main.tex:1115` ("The README lists the 35 scripts"): **no es
  deriva**. El bloque `## Running` de `verification/README.md` lista 35
  scripts, que es justo lo que consume `run_all.sh` y lo que cuenta G2
  (`EXIT 0 = 35/35`); el `.py` 36 es `eip_cost_check.py`, que no es un script
  del suite sino el helper de G7. La distinción 35-listas / 36-ficheros queda
  ahora escrita en el README (A-8) y en el handoff §5 (A-7), así que la frase
  del paper sigue siendo exacta. No se edita: está dentro del ancla (P-5).
- `docs/paper/_deprecated-md/`: instantánea congelada y etiquetada como tal
  por `docs/paper/README.md:8-10` ("kept for reference only… no longer
  maintained"). Sus contadores (`18 entries` en `09-evaluation.md:24` y
  `11-conclusion.md:121`) describen el paper en formato Markdown de entonces,
  no el estado de hoy, y estaban en lo cierto cuando se escribieron.
- `docs/audit/content-audit-pending.md`: los worksheets narran la acción de
  auditoría en su fecha, no afirman el estado presente. Ejemplo comprobado:
  el "35 non-archived scripts" de la línea 1150 entró en `047dc5c`
  (2026-10-06), un día *antes* de que `eip_cost_check.py` se añadiera en
  `604b3f5` (2026-10-07) — era correcto entonces. Igual que `18 entries`.
- `docs/audit/eje-iii-counters-report.md:63` (fila 17, que cita
  `handoff.md:200` con "35 non-archived (42 total, 7 archive)"): verificado
  contra su HEAD declarado —`git show 2bfb946:docs/audit/handoff.md | sed -n
  200p` devuelve esa línea exacta—, así que el acta es cierta *para ese HEAD*.
  Tras A-7 esa cita ya no resuelve y el valor vivo es 36/43/7; el cambio está
  registrado en A-7, que es donde un lector debe buscarlo.


