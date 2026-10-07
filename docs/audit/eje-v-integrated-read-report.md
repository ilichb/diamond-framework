# Eje (v) — Lectura integrada del PDF (end-to-end)

Fecha: 2026-10-10
HEAD: `37ece5e8a6a05f66b8ab28fd22713b78e7f8ca5f` (`origin/main` == HEAD; ahead 0)
Alcance: `docs/paper/main.pdf` (34 páginas). Lectura secuencial sin grep.

Estado: los cinco findings (C-38…C-42) fueron **validados** por el revisor
y **corregidos** en `main.tex`, un commit por finding (C-39 `f06fe16`,
C-42 `a5b0e30`, C-41 `cd6f8f4`, C-38 `ac696c2`, C-40 `cda36f6`). Tras cada
fix: `pdflatex` ×2, 0 `^!`, 0 `Undefined`, 34 páginas.

## Método

Lectura línea a línea del texto extraído con `pdftotext -layout`
(`/tmp/main_integrated.txt`, 1775 líneas), en el orden Abstract → §1 → … →
§11 → References. **Sin grep durante la lectura.** Las anotaciones se tomaron
en orden de aparición (`/tmp/eje_v_notes.txt`) y se adjudicaron al terminar la
lectura completa. Los findings propuestos se verificaron **después** con grep
dirigido contra `main.tex`, según la regla *attribution ≠ value verification*
(C-36): citar un pasaje no es lo mismo que verificar su valor.

Guardas de Fase 1 superadas antes de leer: `pdflatex` ×2 → `^!` = 0 y
`Undefined` = 0; PDF de 34 páginas. El artefacto `/tmp/main_integrated.txt` es
de solo lectura y no se editó.

Ninguno de los pasajes citados fue tocado por C-28/C-30/C-31/C-32/C-33/C-36/C-37
(esas correcciones viven en §5.4, §9.2 y el log; los pasajes de este informe son
otros). Los `.tex` revisados están limpios de esas ediciones.

## Estadísticas de lectura

- Páginas: 34
- Líneas del texto extraído: 1775
- Anotaciones tomadas: 12
- Findings propuestos: 5
- Descartados tras relectura: 7

## Findings (validados y corregidos)

### C-38 — Las "four contributions" cambian de cuarta a cuarta

**Severidad:** Minor
**Pasaje A:** Abstract (`main.tex` L49) y §1.3 (`main.tex` L82–90): *"The paper
makes four contributions: … and a set of design decisions with explicit
boundaries, stating where the protocol cannot deliver a guarantee."*
**Pasaje B:** §11.3 (`main.tex` L1337–1343): *"The paper contributes: … 4. Local
benchmarks of the EVM precompile costs for the cryptographic primitives used in
the protocol."*
**Tensión:** Las tres listas afirman "four contributions" y coinciden en las tres
primeras (protocolo, suite de verificación, log de falsación), pero la cuarta no
es la misma: Abstract/§1.3 la cuarta es *"design decisions with explicit
boundaries"*; §11.3 la cuarta es *"Local benchmarks of the EVM precompile costs"*
y **desaparece** "design decisions with explicit boundaries". El número coincide,
el contenido del cuarto ítem no.
**Resolución propuesta:** Alinear la cuarta contribución de §11.3 con la de
Abstract/§1.3 (p. ej. añadir "design decisions with explicit boundaries" como
cuarta y plegar "local benchmarks" dentro de la segunda, "A numerical
verification suite"). Decidir cuál de las dos cuartas es la canónica.

### C-39 — §5.6 atribuye la potencia de detección a la subsección equivocada

**Severidad:** Minor
**Pasaje A:** §5.6 "The Detection Boundary" (`main.tex` L716): *"The detection
power measured in Section~\ref{subsec:null-distribution} is uniform across the
simulated range. All five configurations have true positive rates above 0.97."*
**Pasaje B:** §5.5 "Detection Power" (`main.tex` L687–688) es donde realmente se
mide: *"We measure the power of the right-tail test … The measurement uses
N_H1 = 500 replicates per configuration"* (tabla de las cinco configuraciones).
§5.4 "Null Distribution and Calibration" (`main.tex` L652–653, label
`subsec:null-distribution`) **no mide potencia**; calibra los cuantiles nulos.
**Tensión:** La cita LaTeX `\ref{subsec:null-distribution}` resuelve a **5.4**
(así aparece impreso en el PDF, L893), pero "las cinco configuraciones con TPR"
viven en **§5.5**. El puntero apunta una subsección atrás.
**Resolución propuesta:** Cambiar `\ref{subsec:null-distribution}` por un label
en §5.5 (`subsec:detection-power`) en `main.tex` L716.

### C-40 — "five components" (§11.1) contra una tabla de siete componentes (§11.6)

**Severidad:** Minor
**Pasaje A:** §11.1 (`main.tex` L1321): *"The protocol is built from five
components, each verified numerically in this paper:"* — enumera cinco, con el
quinto *"Payment, data layer, and bootstrap (Sections 6–8)"* agrupando tres
secciones.
**Pasaje B:** §11.6 (`main.tex` L1368–1376): tabla con cabecera **"Component /
Status / Evidence"** y **siete** filas de componente (Reputation dynamics,
Tensor compression, ZK threshold proof, Collusion detection, Payment rule,
**Data layer**, **Bootstrap**), separando en filas lo que §11.1 funde en una.
**Tensión:** El mismo objeto ("componentes del protocolo") se cuenta como cinco
en §11.1 y como siete en la tabla de §11.6. Además §1.3 (`main.tex` L84) lista
*otro* conjunto de cinco partes del protocolo (*"the reputation dynamics, the
collusion test, the payment rule, the data layer, and the bootstrap
simulation"*), que omite Tensor y ZK que sí están en las cinco de §11.1. La
partición de "componentes" no es estable entre §1.3, §11.1 y §11.6.
**Resolución propuesta:** Fijar una única partición canónica. Si son siete,
§11.1 debería decir "seven"; si son cinco por agrupación deliberada, declararlo
y alinear §1.3. (Nota: §11.1 es transparente al rotular su quinto ítem con sus
tres secciones; el recuento 5 vs 7 sigue siendo citable.)

### C-41 — La tabla de §2.6 usa etiquetas de régimen ("D4", "S2.2") que no se definen

**Severidad:** Minor
**Pasaje A:** §2.6 tabla resumen (`main.tex` L304): *"D4 tail is geometric; S2.2
has no censoring & Verified & censoring_test.py"*.
**Pasaje B:** §2.3 (`main.tex` L207, L229, L262, L264): el cuerpo se refiere a
los dos regímenes siempre como *"first regime"* / *"second regime"* (p. ej. *"In
the first regime the process has no censoring within T_max = 300"*).
**Tensión:** Las cadenas "D4" y "S2.2" no aparecen en ningún otro punto del
documento (grep sobre `main.tex`: única aparición en L304). El lector no puede
mapear "D4"/"S2.2" a *first/second regime* ni a los pares de parámetros
(α=0.5, σ0=0.8)/(α=2.0, σ0=0.5): es una etiqueta huérfana en la tabla.
**Resolución propuesta:** Sustituir "D4"/"S2.2" por las etiquetas del cuerpo
(p. ej. "second regime tail is geometric; first regime has no censoring") o
definir D4/S2.2 en el texto. Verificar en `censoring_test.py` qué nombres de
configuración usa el script (probable origen).

### C-42 — §11.4 atribuye a §10 dos problemas que en realidad son de §9.5

**Severidad:** Minor
**Pasaje A:** §11.4 Open Problems (`main.tex` L1347): *"The limitations section
(Section~\ref{sec:limitations}) identifies several open problems that are not
resolved in this paper:"* seguido de seis ítems, entre ellos *"Recursive proving
time"* y *"Teleporter latency"*.
**Pasaje B:** §9.5 "Deferred Benchmarks" (`main.tex` L1186–1190): *"Recursive
SNARK proving time. … Teleporter latency. …"*. §9.1 (`main.tex` L1112) los
declara *"deferred to future work"*. Grep de "proving time|Teleporter|latency"
restringido a §10 (`main.tex` L1216–1316) → **cero** coincidencias.
**Tensión:** §11.4 encuadra su lista como los problemas que *"identifica la
sección de limitaciones (Sección 10)"*, pero dos de los seis ítems
(*Recursive proving time*, *Teleporter latency*) viven en §9.5 (Deferred
Benchmarks) y **no aparecen en §10**. Recíprocamente, §10.5 (Reputation Model
Selection) y §10.8 (Bootstrap Assumptions) no figuran en §11.4. La lista de
§11.4 no es un subconjunto limpio de §10 ni coincide con él.
**Resolución propuesta:** Reformular la entradilla de §11.4 para no atribuir la
lista completa a §10 (p. ej. "the open problems of the paper, spanning §9.5 and
§10"), o incluir los dos ítems de §9.5 en §10 y citarlos desde §11.4.


## Descartados tras relectura

| # | § | Pasaje | Razón del descarte |
|---|---|---|---|
| 1 | §1.2 | "The Diamond Framework addresses all five." (`main.tex` L180 ext.) | "five" = los cinco problemas enumerados justo arriba en §1.2. Coherente; el "five" de §11.1 (componentes) es otro conjunto, en otro contexto. Sin tensión. |
| 2 | §2.3 | "reach R0 within the horizon falls from 1.0 to 0.82" | "horizon" es la ventana del script citado (`mfpt_jump_diffusion.py`); el 39.7% del test de censura es de otro experimento (λ=0, T_max=300), no de esta cifra. Término de simulación estándar; no hay segundo pasaje en tensión. |
| 3 | §8.2 vs §8.3 | `C̃_R(R)` (L1029) vs `C_R(R(t))` (L1051) | `C_R(x) = 0.8x/(1+x)` y `C̃_R(x) = 0.8x/(1+x)` son **la misma forma algebraica** (verificado numéricamente). Alimentar `C_R` con la `R` acotada da idéntico valor que `C̃_R`. La distinción es de dominio (r no acotado vs R∈[0,1)), no de fórmula: sin tensión numérica. |
| 4 | §4.1 vs §6 | Θr = 0.5 (L558) vs Θ = 1.0 (L1017) | Símbolos distintos con dominios distintos: Θr es el umbral de **norma** Frobenius del ZK; Θ es el umbral de **colateral híbrido** (CoA ≥ Θ). No se refieren a la misma cantidad; admitir puede exigir ambos. Sin contradicción (notación potencialmente confundible). |
| 5 | §8.2 | `R = r/(1+r)`, `R ∈ [0,1)` | El puente §2.5↔§8.2 **sí se declara** explícitamente en `main.tex` L1029. Cumple lo pedido por el checklist. |
| 6 | §10.4 | "−λmin(B) > 9.1371" (L1508) | Coincide exactamente con el cuantil de cola izquierda de §5.4 (`main.tex` L817/L823). Verificado sin fricción. |
| 7 | §9.2/§9.5 | runtimes y benchmarks diferidos | Los dos benchmarks diferidos aparecen en Abstract (L51), §9.1 (L1112), §9.5 (L1186–1190) y §9.6 (L1208–1209), coherentes entre sí. El checklist menciona "§9.4" pero en el paper los benchmarks diferidos están en §9.5 (§9.4 es "Stability"); no hay fricción en el paper. |

## Veredicto

Se detectaron **cinco fricciones** (todas de severidad **Minor**), detalladas
arriba: C-38 (cuarta contribución discrepante entre Abstract/§1.3 y §11.3),
C-39 (cross-ref de §5.6 apuntando a §5.4 en vez de §5.5), C-40 ("five
components" vs siete filas de componente), C-41 (etiquetas de régimen "D4"/"S2.2"
no definidas) y C-42 (§11.4 atribuye a §10 dos problemas de §9.5).

Ninguna es **Structural**: el argumento del paper (protocolo, verificaciones,
límites) se lee de forma coherente de principio a fin; los cálculos citados que
pude cruzar (C = 37 / F = 21 tras C-37; 9.0542/9.1371; 500→146; 684,064 gas;
tabla de runtimes de §9.2) son internamente consistentes. Las cinco fricciones
son de **coherencia enumerativa y de punteros**: recuentos que no cuadran entre
dos listas del mismo objeto, un `\ref` una subsección atrás, etiquetas huérfanas
y una atribución de lista demasiado estrecha. Todas localizables y de arreglo
quirúrgico.

**Ninguno de los cinco findings se resuelve en un tercer pasaje** (comprobado por
grep dirigido en Fase 4): C-38, C-39 y C-41 no tienen pasaje intermedio que los
desambigüe; C-40 el tercer pasaje (§1.3) *agrava* la inconsistencia; C-42 se
confirma al comprobar que §10 no contiene los dos ítems.

Los findings se registraron primero como **propuestos** a la espera de
validación; tras la validación del revisor se corrigieron en `main.tex` (los
commits están en la cabecera). Se respetó la regla anti-invención: las
anotaciones que se disolvieron al contextualizarse se registran como descartes
(arriba), no como findings.


## Pasajes verificados sin fricción (muestreo)

Muestreo de 14 pasajes que la lectura integrada leyó como coherentes, para que
el informe sea auditable (los tres últimos son los cruces obligatorios del
checklist que resultaron limpios):

1. **Abstract ↔ §1.3 ↔ §11.1** — "four contributions" y "five components": el
   número "four" es consistente (la discrepancia está en el *contenido* del
   cuarto → C-38); "five components" en §11.1 se verifica contra la tabla de
   §11.6 (→ C-40). El resto del mapeo Abstract↔§1.3 (protocolo, suite, log) liga
   sin costuras.
2. **§1.2 (cinco problemas) ↔ §2–§8** — el mapeo problema→sección no es 1:1
   (Stochastic→§2, Verifiability→§3/§4, Collusion→§5, Incentive→§6, Data
   integrity→§7) y §8 (bootstrap) no responde a ninguno de los cinco problemas;
   es reconstruible sin contradicción (una sección de resultados adicional). Sin
   fricción.
3. **§2.5 (C_R(r)) ↔ §8.2 (C̃_R(R))** — el puente se declara en `main.tex`
   L1029 ("$R = r/(1+r)$ … replaced by … $\tilde{C}_R(R)$"). Sin fricción.
4. **§4.1 (Θr = 0.5) ↔ §9.3/§4.5** — el umbral de norma y el coste de ingesta se
   mantienen consistentes (684,064 gas; 206k Groth16). Sin fricción.
5. **§5.4 (heavy-tailed) ↔ §5.7 (Limitations) ↔ §6.3 (S_min) ↔ §7 (slashing)** —
   el hilo "defensa económica" se sigue de un tirón: §5.4 L854–856 y §5.7
   L918–925 apuntan ambos a max{S_min, Θ−C_R^∞} (§6) y a slashing (§7). Sin
   costuras.
6. **§8.2 (R = r/(1+r), R acotado) ↔ §2.1 (r no acotado)** — el cambio de dominio
   se declara (`main.tex` L1029). Sin fricción.
7. **§9.2 (runtimes) ↔ §9.5 (deferred) ↔ Abstract** — los dos benchmarks
   diferidos (recursive SNARK proving time, Teleporter latency) aparecen en
   Abstract L51, §9.1 L1112, §9.5 L1186–1190 y tabla §9.6 L1208–1209. Coherentes.
8. **§5.5 (Detection Power) ↔ §5.6 (Detection Boundary)** — se complementan (uno
   mide TPR, el otro discute el borde); el único defecto es el puntero de §5.6
   (→ C-39).
9. **§10 (Limitations) ↔ §11.4 (Open Problems)** — no es un subconjunto limpio
   (→ C-42); fuera de la atribución de la entradilla, el contenido temático liga.
10. **§5.4 L729–733 (normalización A_sym)** — "1/√(d_i d_j)" y los valores
    0.037/0.050 cuadran con los grados 27.2/20.0. Verificado.
11. **§5.4 L823–828** — umbrales q99 = 9.0542 (2.57σ) y 9.1371 (2.52σ) cuadran
    con media/std de la tabla nula (8.7679±0.1115, 8.8601±0.1101). Verificado.
12. **§6.4 L1017–1021** — F0* = πval − ω̄Θ = 0.15 − 0.10 = 0.0500. Verificado.
13. **§4.5 L663–669** — ingesta = 500×32 = 16,000 bytes → 256,000 gas (cota
    superior) + 428,064 gas = 684,064 gas; 3.3× (vs 206k) y 2.7× (vs 250k).
    Aritmética verificada.
14. **§11.6 ↔ §2–§8 Summary tables** — la tabla de componentes de §11.6 y las
    siete "Summary of the Section" (§2.6–§8.7) coinciden en estados y scripts
    citados (p. ej. q99 = 9.0542 en §5.8 ↔ §11.1 ítem 4; 21 entradas del log en
    §11.6 ↔ §9.2). Coherentes, salvo el recuento "five" (→ C-40).

