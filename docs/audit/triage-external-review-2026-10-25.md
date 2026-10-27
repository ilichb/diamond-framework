# External Review Triage — Round 4 (v0.2.2)

## Qué es este fichero

Una cuarta revisión externa llegó el 2026-10-25 como `auditoria 25-10-2026.txt`
(219 líneas, sin firma). Se archiva aquí, sin tocar una coma, como
[`external-review-2026-10-25-source.txt`](external-review-2026-10-25-source.txt),
y se responde con el mismo método que
[`triage-external-review-2026-10.md`](triage-external-review-2026-10.md) y
[`triage-external-review-2026-10b.md`](triage-external-review-2026-10b.md):

1. **Modelar** la discrepancia explícitamente.
2. **Verificar** contra el texto commiteado, el output commiteado y, cuando se
   puede, una ejecución del script que respalda el número.
3. **Registrar** el resultado: confirmado, parcialmente confirmado, refutado o ya
   contemplado.
4. **Proponer** la corrección solo después de registrar el resultado.

No resume la revisión: la contrasta. Cada fila de las tablas de §2 se verificó
abriendo el fichero y la línea que se citan; cuando el revisor acierta, se dice;
cuando no, se dice también.

El documento de revisión está en español, así que la respuesta también, aunque el
resto de los triages esté en inglés.

**Este fichero no está en el ancla**, igual que `anchor-receipts.md`: si estuviera
sellado, corregir una errata obligaría a re-sellar el depósito. La numeración de
líneas que se cita es la del árbol en `b9cffb0` (2026-10-25).

## Estado en el momento del triage (verificado, no asumido)

- `HEAD` = `b9cffb049f7b342fbfad6bb5088a28bbb2600f9e`
  (`fix: Section 9's ratio goes back to its deployed base, and the anchor
  follows (R-16)`); `git describe --tags --always` = `v0.2.1-37-gb9cffb0`.
- `sha256sum docs/paper/main.tex` =
  `2a6384d2c5eec1e2c122352ab3fa89e2fd46cb4ca374b28c2b489ca16334368c`,
  byte-identical a la línea 1 de `verification/anchor_root.sha256`.
- `sha256sum verification/anchor_root.sha256` =
  `abe9c5535eb1dd7e462b49f19b52b828a9cfe235ccbcd32819f5daa37fe56bf7`
  (R-16, sellado el 2026-10-25T16:03:56Z; sello Bitcoin **pendiente**, 4 hojas /
  0 confirmadas).
- `docs/paper/releases/diamond-framework-2026-10-25.pdf`: 591 875 bytes.
- `forge test`: 310 totales, 309 passed, 1 skipped.
- Zenodo: el concepto es `23268373` y tiene **una sola versión publicada**,
  `23268374` (v0.1.0, 2026-10-12). `10.5281/zenodo.23650061` **no resuelve**
  (404 en `/api/records` y en `doi.org`): no hay v0.2.2 publicada todavía.

**Consecuencia.** Cualquier edición de `main.tex` es un cambio nuevo y exige el
pipeline completo de re-anclaje. Lo que esta revisión justifica cambiar en el
paper son dos párrafos de contenido, no erratas: van a v0.2.3, no a este
depósito (§6).

## 0. Resumen

| Categoría | Cuántas | Cuáles |
|-----------|---------|--------|
| Confirmadas literalmente | 30 | ver §2 |
| Confirmadas con matiz | 4 | A2, A5, B5, C4 |
| **Falsas** | **2** | C2 ("no integra fuzzing"), D6 ("§6.3") |
| Recomienda algo que ya existe | 1 | C3 (invariantes multi-estado) |
| Juicios de valor, no verificables | 3 | D11, E4, E5 |

La revisión es, en lo comprobable, **precisa**: acierta los nombres de los
errores del registro, el `CHANGE_DELAY`, el `THETA_R = 0.5 [CONJECTURE]`, el
rechazo del EOA como slasher fuera de local, los cinco roles, el número de
entradas del log de falsificación, las 43 páginas, las 11 guardas y la frase del
guardian comprometido, que es casi literal.

Sus dos errores son concretos y comprobables: dice que no hay fuzzing (hay 7
`testFuzz` y 9 invariantes stateful) y sitúa la pregunta abierta en §6.3, que es
"La matriz de modularidad"; la pregunta está en §7 y §10.

Sus tres aportaciones útiles son reales, no errores de lectura:

1. **`src/README.md` mentía.** Decía "Status: **skeleton**. The subdirectories
   below are placeholders; no code has been written yet" (l. 3–4) con 88 ficheros
   trackeados y cuatro crates compilando. Corregido el 2026-10-25; ver §3.1.
2. **`THETA_R` sigue siendo una conjetura sin argumento.** Cierto, aunque está
   etiquetada en el código y en el paper, no escondida. Ver §3.2.
3. **ACP-77 no aparece en el paper.** Cero ocurrencias en `main.tex`. Ver §3.3.

## 1. Método

Tres reglas, para que el veredicto sea auditable y no una opinión mejor escrita:

- Una afirmación es **confirmada** solo si el fichero y la línea que se citan
  existen y dicen eso. Si el fichero existe pero el contenido es más débil, es
  **matiz**.
- Una afirmación es **falsa** si el repositorio contiene la negación, no si el
  revisor exagera un límite ya declarado. La diferencia importa: "no hay auditoría
  externa" es un límite declarado en el README y repetido en §10; "no hay fuzzing"
  es falso.
- Lo que no se puede comprobar con un `grep` no se puntúa. "Demasiado alcance para
  una persona" no es verdadero ni falso; es una lectura.

## 2. Contraste

### A. Estado, alcance y estructura

| # | Afirmación de la revisión | Evidencia | Veredicto |
|---|---------------------------|-----------|-----------|
| A1 | El repo se presenta como *research in progress*, no auditado, no verificado formalmente, no productivo | `README.md` §"Non-goals": "Not audited... no external security review... no mainnet deployment" | Confirmada |
| A2 | Árbol de directorios: `docs/{architecture,audit,grants,paper}`, `integrations/avalanche/{benchmarks,contracts,scripts,foundry.toml}`, `src/{datalayer,reputation,rmt,zk}`, `verification/{stochastics,mechanism,zk,rmt,data-layer,bootstrap,fuji}` | Todos existen. **Omite** `verification/{tensor,baseline_2026-10-06,baseline_verified,ots-history}` y los artefactos de `integrations/avalanche/{out,cache,broadcast}` | Matiz: correcto pero incompleto |
| A3 | Los cinco comandos de arranque existen con ese nombre | `verification/{stochastics/sim_positivity.py, mechanism/frobenius_counterexample.py, zk/soundness_zk_check.py, rmt/calibration_modularity.py, data-layer/simulate_data_layer_v3.py}`: 5/5 | Confirmada |
| A4 | `pip install -r verification/requirements.txt` y `verification/eip_cost_check.py` | Ambos existen; el requirements son dos líneas (`numpy>=1.24`, `scipy>=1.10`) | Confirmada |
| A5 | La suite y el gate no sustituyen seguridad real | Cierto, y el propio paper lo dice. El gate (11 guardas) comprueba reproducibilidad y coherencia, no resistencia a ataques | Matiz: es un límite ya declarado, no un defecto oculto |
| A6 | La parte más frágil es la confianza operativa en los roles | Coincide con la tabla de roles de `README.md:49` y con §10.2 del paper | Confirmada |

### B. Contratos

| # | Afirmación | Evidencia | Veredicto |
|---|------------|-----------|-----------|
| B1 | `CHANGE_DELAY = 2 days` | `AVIPRegistry.sol`; `test/DeployScripts.t.sol:191` lo afirma: `assertEq(registry.CHANGE_DELAY(), 2 days, ...)` | Confirmada |
| B2 | El guardian no puede convertirse en sequencer | `AVIPRegistry.sol:183` (`guardian_ == sequencer_` → `RolesCollapsed`) y `:223` (`next == guardian` → `RolesCollapsed`) | Confirmada |
| B3 | Ejecutar un cambio es permissionless tras el delay | `executeSequencerChange()` (l. 243) y `executeVerifierChange()` (l. 293) no llevan modificador; solo proponer y cancelar son `onlyGuardian` | Confirmada |
| B4 | El guardian es inmutable y sin rotación | `AVIPRegistry.sol:126`: `address public immutable guardian;`. No hay `proposeGuardian` | Confirmada |
| B5 | (implícito) "la rotación es permissionless después del delay" incluye al guardian | La rotación permissionless cubre `sequencer` y `verifier`, no `guardian`. El texto lo deja ambiguo al decir "la guardia de guardian no puede convertirse en sequencer y la rotación es permissionless" | Matiz: cierto para dos roles de tres |
| B6 | Errores `ZeroRoot`, `ZeroStatementRoot`, `NonSequentialEpoch`, `FreshnessViolation` | `interfaces/IAVIPRegistry.sol:93–98`, literales | Confirmada |
| B7 | `verifyThreshold` valida el rango del norm y de la prueba, y ata el epoch al root | `AVIPRegistry.sol` `verifyThreshold` (ll. 421–469): `MAX_NORM` → `NormOutOfDomain`, `Bn254.decodeProof`, y `statement[0..3] = (root, epoch, validator, certifiedNorm)` construidos desde el storage | Confirmada |
| B8 | `THETA_R = 0.5` marcado `[CONJECTURE]` en el propio código | `AVIPValidatorManager.sol:74` (línea de documentación) y `:78` (`uint256 public constant THETA_R = 5e17;`). También `main.tex:471` | Confirmada, literal |
| B9 | `requiredStakeFor`, `collateralFor` y el recargo de eyección son explícitos | `AVIPValidatorManager.t.sol:201–220` fija los valores en el umbral (`CR = 0.2666…`, `SF = 0.7333…`, y `SF = THETA − CR`) | Confirmada |
| B10 | `admit` liga la prueba a la raíz más reciente | `admit` → `verifyThreshold`, que lee `_statementRoots[epoch]`; el llamante no puede aportar el root | Confirmada |
| B11 | Se rechaza un EOA como slasher fuera de local | `scripts/DeployCommon.sol:182–186`: `if (block.chainid == LOCAL_CHAIN) return authority; if (authority.code.length == 0) revert SlashAuthorityIsEOA(...)`; error declarado en `:102` | Confirmada, literal |
| B12 | El verifier no tiene ceremonia y es una clave de desarrollo | `README.md:57`: "a development-key verifier was announced on 2026-10-24... No ceremony key exists" | Confirmada |
| B13 | `sequencer`, `guardian` y `slashAuthority` son puntos únicos de confianza | Tabla de `README.md:49–57`; ninguno tiene más de un titular en v1 | Confirmada |

### C. Pruebas y contratos

| # | Afirmación | Evidencia | Veredicto |
|---|------------|-----------|-----------|
| C1 | 309 tests de Foundry pasando | `forge test`: 310 totales, **309 passed, 1 skipped** (el skip es `SafeForkTest`, que necesita `FUJI_RPC_URL`) | Confirmada |
| C2 | "No integra fuzzing" | **Falso.** 7 funciones `testFuzz` (`AVIPValidatorManager.t.sol` ×2, `M7dTransport.t.sol` ×3, `M8StakeVault.t.sol` ×2) y 9 invariantes stateful en `test/invariant/AVIPInvariants.t.sol:315–394`. El plan los cuenta en `implementation-plan.md:444` | **Refutada** |
| C3 | Recomienda "invariants con múltiples estados y permisos" | Ya existen: `conservationOfUnits`, `vaultHoldsExactlyItsEscrow`, `aggregateIsTheSumOfValidators`, `everyValidatorIsBacked`, `admissionImpliesRequirement`, `unadmittedHasNoStake`, `ejectionsNeverDecrease`, `withdrawableIsWithinEscrow`, `sinkReceivedWhatLeftEscrow` | Ya implementado |
| C4 | Recomienda simular slashing + re-admission + eventos cross-chain | `M8StakeVault.t.sol`, `M7dTransport.t.sol` y `AVIPSlashingChannel.sol` cubren slashing y transporte. La re-admisión tras eyección **no** la verifiqué exhaustivamente | Matiz: parcialmente implementado |
| C5 | No cubre monitoreo ni operación de red | No hay servicios de monitorización en el repo; el alcance declarado es artefacto + prototipo | Confirmada |

### D. Paper y evidencia

| # | Afirmación | Evidencia | Veredicto |
|---|------------|-----------|-----------|
| D1 | 43 páginas | `diamond-framework-2026-10-25.pdf`, compilado desde `main.tex` | Confirmada |
| D2 | Cada claim lleva etiqueta, script y registro | `docs/audit/claim-registry.csv` (29 filas), etiquetas Verified/Measured/Estimated/Design/Deferred/Conjecture, guarda G4 del gate | Confirmada |
| D3 | Log de falsificación con 22 entradas, una que dice "fabricada" | `grep -c '^### F-'` → **22**; `numerical-verification.md:23`: "the 4.7% figure was **fabricated**" | Confirmada, literal |
| D4 | Gate de 11 guardas | `audit-gate.sh`: G1–G11, `PASS=11 FAIL=0` | Confirmada |
| D5 | Encontró y corrigió su propio 31× vs 23× | §9 del paper, ratio vuelto a 23× sobre base desplegada; anotado como R-16 en `anchor-receipts.md` el mismo 2026-10-25 | Confirmada |
| D6 | "La pregunta central está abierta en **§6.3** y §10" | §6.3 es "The Modularity Matrix" (`main.tex:699`), que trata de colusión. La pregunta está en **§7** (Payment Rule, `\label{sec:payment}`, `main.tex:836`) y en **§10** (`sec:limitations`, `main.tex:1364`). El fondo es cierto: `main.tex:59`, `:1453`, `:1479` | **Refutada** en el número; correcta en el fondo |
| D7 | No hay resultado de seguridad; la contribución es diseño + verificación numérica | `main.tex:1453`: falta "a network-level Cost of Attack bound"; `:1479` lo marca como *Design* | Confirmada |
| D8 | Los parámetros (CIR, colusión, cola pesada) son elegidos, no calibrados con datos reales | Cierto y declarado: §10 lista la calibración con datos reales como pendiente | Confirmada |
| D9 | La capa de identidad se asume; vender la clave transfiere el flujo de ingresos | `main.tex:61` y `:1393`: "selling a signing key would transfer the reputation-weighted income stream" | Confirmada, casi literal |
| D10 | ACP-77 ya bajó la barrera y el paper no argumenta por qué el mecanismo sigue haciendo falta | `grep 'ACP-77' docs/paper/main.tex` → **0 ocurrencias**. El paper no discute el cambio de requisitos de validación de Avalanche | Confirmada como hueco |
| D11 | 43 páginas de meta-documentación serían ruido para un journal | No verificable: es una opinión sobre el formato | Juicio |

### E. Proceso y mercado

| # | Afirmación | Evidencia | Veredicto |
|---|------------|-----------|-----------|
| E1 | El README enumera cinco roles y dice que un guardian comprometido instala un verifier que acepta cualquier prueba | `README.md:49–57`, y la celda del guardian dice: "A compromised guardian can install a verifier that returns `true` for any proof" | Confirmada, casi literal |
| E2 | El workflow fija las acciones por SHA, no por tag | `.github/workflows/audit-gate.yml:15` (`actions/checkout@11d5960a…`) y `:19` (`setup-python@a26af69b…`) | Confirmada |
| E3 | La convocatoria que lo financiaría está cerrada | `README.md` §"Not audited": la convocatoria del programa de investigación de Avalanche cerró el 2026-10-24 | Confirmada |
| E4 | Demasiado alcance para una persona | No verificable | Juicio |
| E5 | Sesgo *paper-first*, no *operating-system-first* | No verificable | Juicio |

## 3. Los tres aciertos que importan

### 3.1 `src/README.md` decía que `src/` estaba vacío

Línea 3 del fichero, hasta hoy: "Status: **skeleton**. The subdirectories below
are placeholders; no code has been written yet."

Debajo había 88 ficheros trackeados y cuatro crates que compilan:

| Crate | Ficheros trackeados | Tests `#[test]` (conteo por `grep`, no por ejecución) |
|-------|---------------------|--------------------------------------------------------|
| `avip_zk_prover` (M4) | 31 | 48 |
| `avip_reputation` (M6) | 20 | 53 |
| `avip_datalayer` (M7b) | 19 | 39 |
| `avip_rmt_detector` (M5) | 18 | 37 |

La tabla del README tampoco listaba `src/datalayer/`, y la sección "Language"
seguía presentando como abierta la decisión D-1 (Rust vs Python), que el plan ya
cerró en Rust (`implementation-plan.md:2874`). Tres afirmaciones falsas en 31
líneas, y el revisor las vio en una pasada.

**Corregido el 2026-10-25.** `src/README.md` no está en el ancla de 11 ficheros,
así que la corrección no toca el sello ni el PDF.

### 3.2 `THETA_R = 0.5 [CONJECTURE]` es un parámetro económico abierto

Confirmado, literal, en `AVIPValidatorManager.sol:74` y `:78`, y en
`main.tex:471`: "It is a design parameter, not derived from first principles in
this paper."

El revisor lo presenta como señal de que algo no está cerrado. Tiene razón en el
fondo y se queda corto en el crédito: no es un parámetro escondido, está
etiquetado `[CONJECTURE]` en los dos sitios donde un lector lo va a encontrar.
Lo que no existe es un argumento que fije θ_r; fijarlo exige una sección nueva,
no una errata.

### 3.3 ACP-77 no aparece en el paper

`grep -c 'ACP-77' docs/paper/main.tex` → 0.

Es el hueco más caro de los tres, porque no es un descuido de documentación: es
un cambio en el entorno del problema. Si Avalanche ya bajó el coste de ser
validador, el argumento de "la barrera de entrada es el problema" necesita
responder por qué el mecanismo sigue aportando algo que el cambio de protocolo
no aporta. Hoy el paper no lo responde en ninguna sección.

No lo he escrito yo: es una decisión de tesis, no una corrección, y tocar
`main.tex` obliga a re-sellar y a rehacer el depósito. Queda anotado como
candidato a v0.2.3, ver §6.

## 4. Las dos afirmaciones falsas

### 4.1 "No integra fuzzing" (C2)

Falso, y el propio plan lo cuenta: `implementation-plan.md:444` habla de "registry
+ 34 manager, **two of them fuzz** — the admission invariant and the policy", y
`:2656` de "the fuzz that varied the slashed amount".

En el árbol hay 7 `testFuzz` y 9 invariantes stateful. La confusión probable es
que el gate de 11 guardas no ejecuta `forge test` (está en el backlog del CI,
anotado aparte), así que quien lea solo `audit-gate.sh` no ve ni un test de
Foundry y puede concluir que no hay fuzzing.

Donde el revisor sí tiene razón es en el adjetivo que no usó: no hay fuzzing
*adversarial*. Los `testFuzz` varían importes y direcciones; no varían θ_r, la
comisión ni el decaimiento contra los invariantes económicos, ni corren campañas
largas. Eso es una mejora real, y es distinta de "no integra fuzzing".

### 4.2 "La pregunta central está abierta en §6.3 y §10" (D6)

§6.3 es "The Modularity Matrix" (`main.tex:699`): la matriz B, los autovalores,
la calibración nula. No trata del Cost of Attack.

La pregunta está en **§7** (*Payment Rule*, `\label{sec:payment}`,
`main.tex:836`) y en **§10** (*Limitations*, `main.tex:1364`). El propio paper lo
dice en la introducción: "taken up in Section~\ref{sec:payment} and recorded in
Section~\ref{sec:limitations}" (`main.tex:59`), y la tabla de §10 la marca como
*Design* con esas dos referencias (`main.tex:1479`).

El fondo es correcto —la pregunta está abierta—, pero un lector que siga la cita
del revisor acabará leyendo sobre grafos espectrales.

## 5. Las recomendaciones, una por una

| Recomendación | Estado | Acción |
|---------------|--------|--------|
| Etiqueta de "no auditado" como condición de uso | Ya existe (`README.md`, §10.1) | Ninguna |
| Separar "paper + evidencia" de "despliegue" | Ya separado: paper en `docs/paper/`, prototipo en `integrations/`, y el paquete de financiación queda deliberadamente fuera del paper y del ancla | Ninguna |
| Catálogo de riesgos y ataques | Parcial: la tabla de cinco roles, §10.2 y los hallazgos P-01/P-10/P-13/P-16/P-33 comentados en el código. No hay documento único | Candidato: `docs/audit/threat-catalogue.md`, no sellado |
| Auditoría externa antes de desplegar | Es el item #1 de §10 desde el principio; bloqueado por financiación | Sin cambio |
| Fuzzing adversarial | Existe fuzzing, no adversarial | Añadir campañas sobre θ_r, comisión y decaimiento |
| Invariantes multi-estado y permisos | 9 en `test/invariant/` | Subir `runs`/`depth` si el tiempo de CI lo permite |
| Slashing + re-admisión + cross-chain | M8 y M7d cubiertos; re-admisión tras eyección sin test dedicado | Añadir un test de re-admisión |
| No confundir anclaje con seguridad | El repo no lo confunde (A5) | Ninguna |
| Modelo de amenazas con un ataque concreto y su coste | No existe; coincide con el hueco "Cost of Attack bound" de §10 | Trabajo de v0.3, no errata |
| Versión corta del paper para un venue | Decisión editorial | Del autor |

## 6. Qué cambia y qué no

**Cambia hoy:** `src/README.md`, corregido contra las 88 líneas de código que
negaba. No toca el ancla, el PDF ni el depósito.

**No cambia:** `main.tex`. Las dos únicas cosas que la revisión justificaría
tocar —un párrafo sobre ACP-77 y una sección que fije θ_r— son contenido nuevo,
y el artefacto del 2026-10-25 está sellado y esperando DOI. Meterlas ahora
obligaría a re-sellar, recompilar y volver a empezar el depósito por dos
párrafos que no cambian ninguna cifra.

**Queda anotado para v0.2.3:** el párrafo de ACP-77, el argumento de θ_r, el
catálogo de amenazas y el test de re-admisión.

## 7. Lo que esta respuesta no es

No es una auditoría de seguridad. Verifica si lo que la revisión afirma sobre el
repositorio es cierto; no dice si el protocolo es seguro, y no sustituye la
revisión externa que §10 sigue debiendo. Un documento que confundiera las dos
cosas sería exactamente el error que la revisión advierte en A5.

Tampoco es una defensa. De 37 afirmaciones contrastables, 30 se confirman, 4 más
se confirman con matiz, 2 son falsas y 1 recomienda algo que ya existía: la
revisión leyó el repositorio, no lo hojeó. Las dos falsas y el hueco de ACP-77
son la parte que valía la pena.

---

Verificado contra el árbol en `b9cffb0`, 2026-10-25. Documento no sellado, por
la misma razón que `anchor-receipts.md`: se corrige sin re-anclar.

---

## Apéndice (2026-10-27) — las cifras del suite, verificadas contra el árbol

Este apéndice corrige tres cifras de un inventario interno fechado 2026-10-27
que no se publicó en el repo. No modifica nada de lo anterior: la cifra correcta
ya estaba en §C2 (línea 132) y en §5 (línea 221), y es la que queda.

### A-1. Invariantes: **nueve**, más una prueba auxiliar

`test/invariant/AVIPInvariants.t.sol` contiene 9 funciones `invariant_`
(líneas 315–394, exactamente el rango que §C2 cita) y **una** función `test_`:
`test_handlerReachesEveryPath()` (línea 286), que no es una invariante. Asserta
que el handler alcanzó sus selectores; sin ella, un invariante podría pasar sin
haber ejecutado nada.

`forge` cuenta 10 tests en ese fichero; las invariantes son 9. Ambas cifras son
ciertas y no son la misma. La formulación que ya usaba el repo
(`docs/grants/avalanche-research-proposal.md:121`) es la buena: «10
stateful-invariant tests: 9 invariants over the escrow».

### A-2. Llamadas por invariante: **1.536 en total**, no por ejecución

`foundry.toml` fija `runs = 48` y `depth = 32`. `forge` reporta
`(runs: 48, calls: 1536, reverts: 0)`, y 48 × 32 = 1.536: el campo `calls` **ya
incluye** las 48 ejecuciones. No se vuelve a multiplicar por 48; hacerlo da
73.728 y es doble conteo.

| Cantidad | Valor |
|---|---|
| llamadas por invariante | 1.536 (= 48 × 32) |
| llamadas por las 9 invariantes | 13.824 |
| llamadas de la prueba auxiliar | 1.536 |
| llamadas del fichero completo | 15.360 |

El «15.360» es el total del fichero, no una cifra «por invariante».

### A-3. Selectores del handler: **cinco**

`admit`, `deposit`, `payFee`, `slash`, `withdraw`. En
`test_handlerReachesEveryPath()` el reparto es 298 + 300 + 310 + 314 + 314 =
1.536. Son cinco, no seis: la lista del inventario era correcta y su encabezado
no.

### A-4. El conteo total, después del test de frontera

Antes: 310 funciones, 309 ejecutadas, 1 omitida. Después de
`test_theLargestEncodableNormReachesTheVerifier` (frontera de `MAX_NORM`,
`M4dRealKey.t.sol`): 311 funciones, **310 ejecutadas**, 1 omitida. La omitida
sigue siendo la misma y sigue siendo deliberada: `SafeForkTest.setUp()` llama
`vm.skip(true)` cuando no hay `FUJI_RPC_URL`.
