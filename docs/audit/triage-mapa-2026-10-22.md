# Triaje del «Mapa Diamond-framework 22 Oct» contra el árbol vivo

## Qué es este fichero

Llegó una revisión externa en texto libre —`docs/audit/Mapa Diamond-framework 22
Oct (1).md`, 3 133 líneas, sin commit— que combina un mapa del repositorio, una
lista de hallazgos de seguridad, una matriz de ataque del data layer, diez
*hazards* y dos planes de parche en Solidity + Rust. Este fichero registra el
**triaje** de cada afirmación contra el árbol vivo, con el mismo método que
`content-audit-pending.md`, `triage-external-review-2026-10.md` y
`triage-external-review-2026-10b.md`:

1. **Modelar** la discrepancia que el revisor afirma.
2. **Verificar** contra el texto comprometido, el contrato, el circuito y —donde
   se puede— una ejecución.
3. **Registrar** el resultado: confirmado (**C**), parcial (**P**), refutado
   (**R**) o ya dentro del alcance del paper/plan (**S**).
4. **Proponer** la corrección sólo después de registrar el resultado.

Es una hoja de trabajo, no un artefacto del paper, y **no** está sellada por
`verification/anchor_root.sha256`. Este triaje no modifica nada bajo
`docs/paper/` ni `verification/`. El fichero triado sigue sin commitear.

La diferencia con los triajes anteriores es de género: aquéllos revisaban el
*paper* contra sus scripts; éste revisa un *diagnóstico de arquitectura* contra
el código, y su interés real no está en los hallazgos —casi todos llegan al
mismo sitio que `R3-03`, `P-03` y `P-38`— sino en el **plan de parche**, que
propone una solución que no cierra la brecha que denuncia. La sección 3 es la
que importa.

## Estado en el momento del triaje (verificado, no asumido)

- `HEAD` = `ea75594` (rama `m4d-review`), *«fix(P-03): r = T(i), per validator,
  and the floor that follows»*; `git describe --tags --always` =
  `v0.2.1-15-gea75594`.
- Árbol de trabajo: sólo el mapa sin seguimiento
  (`?? "docs/audit/Mapa Diamond-framework 22 Oct (1).md"`), ningún otro cambio.
- `sha256sum docs/paper/main.tex` =
  `2a3605eef22956fb6ffe1b668deb9456c4c995534f33ce1af17f187615a95879`.
- `forge test` en `integrations/avalanche/` (offline): **275 tests, 0 fallos,
  exit 0** (ejecutado para este triaje; volcado en `/tmp/forge_test_triage.log`).
- `cargo test -p avip-reputation --offline`: 53 tests, ver §6 para la salida.
- Los números de gas del circuito de admisión son los de `test/M4dRealKey.t.sol`:
  **234 284** en `verify`, **306 275** fríos / **247 233** calientes por
  `verifyThreshold` (plan §5.5.11, `M4dRealKey.t.sol` en `test/README.md`).

El mapa se escribió sin ver el commit `ea75594` (P-03, 2026-10-22) y, por lo que
se deduce de sus números de línea, sin ver el estado posterior a M4d. Eso explica
la mitad de sus discrepancias de hecho y **ninguna** de sus discrepancias de
método: el plan de parche habría fallado igual contra el árbol que el mapa
describía.


## Veredictos

Leyenda: **C** confirmado; **P** parcialmente confirmado; **R** refutado contra
HEAD; **S** ya declarado en el paper/plan (fuera del alcance de un parche).

| ID | Afirmación del mapa | Veredicto | Severidad real | Dónde vive ya |
|---|---|---|---|---|
| M-01 | Brecha semántica entre el root publicado, la prueba y el tensor real (hallazgos 1–2, Hazard 1) | **P** | Alta | `P-03`, `P-38`, `R3-03`; `main.tex:291`, `main.tex:1381` |
| M-02 | `AVIPRegistry.verifyThreshold` construye `[root, epoch, certifiedNorm]` | **R** | — | M4d: `[statementRoot, epoch, uint160(validator), certifiedNorm]` (`AVIPRegistry.sol:388-394`) |
| M-03 | La norma certificada es `‖T‖_F` y el parche debe probar `floor(√ΣT_i²)` | **R** | — | `P-03` (2026-10-22): `r = T(i)`, `0 < r < WAD` |
| M-04 | `certifiedNorm` se acepta sin validación de rango | **P** | Baja | `MAX_NORM = 2^64` (`AVIPRegistry.sol:82,373`), `norm < WAD` (`admission.rs:244-245`), `THETA_R` (`AVIPValidatorManager.sol:249`); el hueco negativo es `P-33` |
| M-05 | «El circuito real no existe todavía» | **R** | — | M4d: 4 827 restricciones, clave derivada, 10 tests en `M4dRealKey.t.sol`, 306 275 gas |
| M-06 | El root Merkle no prueba nada por sí solo; nada liga las dos raíces on-chain (Hazard 1/3) | **C** | Alta | `P-16` (dos ranuras), `P-38`, `R3-03` opción (c); el bridge es off-chain (`src/zk/src/bridge.rs`) |
| M-07 | El data layer es un punto de fallo sistémico; la ingesta no se verifica on-chain | **C** | Alta | `P-02`, `P-12`, `main.tex:291`; M7b/M7c entregan ingesta y enlace, no autenticidad de origen |
| M-08 | `adjudicate` sólo detecta discrepancia de hoja, no forja de raíz (Hazard 3) | **P** | Media | M7b/M7c (plan §5.9-§5.10); la raíz se recomputa off-chain, no se prueba on-chain |
| M-09 | `sequencer` y `guardian` son roles peligrosos si se comprometen | **P** | Media | M9a (`AVIPRegistry.sol:45-55`): roles separados, `CHANGE_DELAY`, ejecución permissionless; el multisig es un hecho de despliegue que ningún contrato puede comprobar |
| M-10 | `latestEpoch()` ata la admisión al «último estado publicado», no al correcto (Hazard 4) | **C** | Baja (griefing) | `P-32`, con remediación propuesta en el registro |
| M-11 | No hay binding de identidad persistente; la reputación es portable (Hazard 5) | **C** | Media | `P-12`, `P-38`; el leaf liga la `address`, la unicidad por época no |
| M-12 | La custodia puede saltarse si no se configura (Hazard 6) | **C** | Media (despliegue) | `§5.12`; `admit` exige escrow cuando `custody != 0` (`AVIPValidatorManager.sol:266-271`) |
| M-13 | El slash quema el registro entero; falta un slash proporcional (Hazard 7) | **C** | Media | `M9b` (`AVIPValidatorManager.sol:300-303`): el importe *es* el registro, por el invariante `isAdmitted ⇒ stakeOf ≥ requiredStake` |
| M-14 | No hay pausa de emergencia (Hazard 9) | **C** | Baja | No existe; decisión de alcance (§11 y M8), no un olvido |
| M-15 | La versión de `f_c` no viaja con el estado publicado (Hazard 8) | **P** | Media | `Ingestion::parameters_digest()` (`ingestion.rs:101`) y `chain()` existen off-chain; el registry no los recibe |
| M-16 | No hay módulo de compresión de tensor en el código | **C** | Baja | Correcto: no hay `src/tensor/`; el Tucker vive en `verification/tensor/` y en el paper |
| M-17 | Puntuaciones 4/10, 2/10, 8.5/10 tras el hardening | **—** | — | No auditable: es una opinión sin criterio reproducible. Se registra y no se usa |
| M-18 | El plan de parche (statement de 6–7 palabras, `stateHash`, `OriginMeta`, `digest` de 5 campos) | **R** | — | Ver §3: no cierra la brecha y rompe la ceremonia, la interfaz y el fixture |

## 1. Lo que el mapa acierta

Cuatro cosas, y las cuatro estaban ya registradas; el valor del mapa es que
llega a ellas por una vía independiente, leyendo el código como un sistema y no
como un diff:

- **La norma es la que el secuenciador escribió.** El diagnóstico central —«se
  verifica un proof correcto sobre un statement correcto, pero no que el
  statement represente el tensor»— es exactamente `P-38` en su forma más
  general, y `P-03` después de la decisión. El paper lo dice ya sin adorno en
  `main.tex:291` (*«the step from the diffusion to the committed scalar … is
  not proved by the circuit»*) y en `main.tex:1381` (el publicador del
  compromiso es de confianza, y la confianza está acotada por un retardo).
- **Las dos raíces no se tocan.** Que el registry guarde una raíz keccak y una
  Poseidon sin ligadura on-chain es `P-16` y `R3-03`; el mapa lo ve sin saber
  que son dos ranuras y sin haber leído el bridge.
- **La confianza en el data layer es estructural, no un detalle.** El mapa la
  llama «punto de fallo sistémico»; el audit la registra como `P-02`, `P-12` y
  `P-34` (el slash cross-chain se ejecuta sobre la palabra del notificador).
- **No hay un bug clásico.** Reentrancy, overflow, `delegatecall`, estado
  corrupto: coincidimos en que no hay ninguno, y en que el riesgo es semántico.
  El mapa lo dice en su hallazgo 11; el audit no tiene ninguna entrada de esa
  familia tampoco.

El resto de los hallazgos son la misma intuición aplicada a cada módulo, y por
eso el mapa acaba con diez *hazards* donde el registro tiene treinta y ocho
fichas `P-xx` (P-01…P-38): es un diagnóstico de arquitectura, no un registro de
defectos.

## 2. Lo que el mapa no puede saber (desactualizado, no equivocado)

Estas discrepancias no son errores de razonamiento: son la mitad de M4d y el
commit de P-03, que el mapa no vio. Importan porque el plan de parche se apoya
en la descripción antigua del contrato.

| El mapa describe | HEAD tiene | Evidencia |
|---|---|---|
| `postCommitment(epoch, root, changedEntries)` | `postCommitment(epoch, root, statementRoot, changedEntries)` | `AVIPRegistry.sol:272-302` |
| `verifyThreshold(epoch, certifiedNorm, proof)` | `verifyThreshold(epoch, validator, certifiedNorm, proof)` | `AVIPRegistry.sol:351-356` |
| `statement = [root, epoch, certifiedNorm]` | `[statementRoot, epoch, uint160(validator), certifiedNorm]` | `AVIPRegistry.sol:388-394` |
| «no hay circuito real vinculado al root» | M4d: hoja `Poseidon(validator, norm)` y camino de Merkle; 4 827 restricciones, clave real, 10 tests | `admission.rs`, `M4dRealKey.t.sol` |
| «`certifiedNorm` sin validación de rango» | `norm < WAD` en el circuito; `certifiedNorm < 2^64` en el registry; `≥ Θ_r` en el manager | `admission.rs:244-245`, `AVIPRegistry.sol:373`, `AVIPValidatorManager.sol:249` |
| «`certifiedNorm = floor(√ΣT_i²)`» | `r = T(i)`, escalar por validador | `P-03`, `commitment.rs`, `AVIPValidatorManager.sol:179-191` |
| «`admit` sólo comprueba proof y stake» | añade `msg.sender == validator`, `!isAdmitted`, escrow si hay custodia, recargo por eyección | `AVIPValidatorManager.sol:233-292` |
| «la custodia no se comprueba» | se comprueba si está configurada; lo opcional es *configurarla* | `AVIPValidatorManager.sol:266-271`, `§5.12` |

Una nota sobre el primer renglón, porque es el que más consecuencias tiene en el
plan de parche: el mapa cree que la publicación on-chain son «epoch, root,
changedEntries» y que el statement son tres palabras. En HEAD son cuatro
palabras, y la cuarta —`validator`— es la que cierra `P-01`. Cualquier parche
diseñado sobre la forma antigua tendría que **empezar** por redescubrir M4d.


## 3. Dónde la prescripción deja de seguir al diagnóstico

El mapa propone, en cuatro variantes sucesivas que dicen lo mismo, esto:

1. ampliar `postCommitment` con `sourceChainId`, `formulaDigest`, `eventsRoot`,
   `stateHash` y `canonicalizationVersion`;
2. ampliar el statement público a seis o siete palabras con esos campos;
3. ampliar `admit` con los mismos argumentos;
4. definir `OriginMeta`, `PublishedState` y un `stateHash` que ligue
   `entries + source + formula + epoch + version`;
5. extender `Epoch::digest()` a cinco o seis campos;
6. y, en la variante literal, volver a `certifiedNorm = floor(√ΣT_i²)`.

La intuición —«el verificador debe aprender algo del estado, no sólo un número»—
es correcta. La construcción no lo consigue, y conviene dejarlo escrito porque es
la parte del mapa que alguien podría intentar implementar.

### 3.1 Publicar un campo no es probarlo

En un circuito Groth16, una palabra pública es una palabra que el probador
**declara**; lo que la ata al testigo es una restricción. `sourceChainId` y
`formulaDigest` no son funciones de las entradas —ninguna combinación de
`entries` produce un `chainId`—, así que el circuito no puede restringirlos:
puede copiarlos del testigo a la salida pública y nada más. `stateHash`, si se
define como `keccak(entries, …)`, tampoco: keccak no es computable dentro de
BN254 al tamaño del tensor, que es la razón por la que existen dos raíces
(`P-16`). Del lado on-chain, el registry compara esos campos contra **su propio
mapping**, escrito por el mismo `sequencer` en `postCommitment`: comparar lo que
publicó un actor con lo que publica después el mismo actor no añade una
hipótesis, añade una comprobación de coherencia interna.

Lo que el parche sí consigue, sin querer, es **más superficie pública** para el
mismo probador: el statement pasa de cuatro palabras a seis o siete, la clave y
la verificación se regeneran, el gas sube y el fixture se rehace. El argumento
está en `src/zk/README.md` y en `R3-03`: un verificador que sólo tiene las dos
raíces no aprende nada del `link`, porque el `link` necesita el tensor. Añadir
el `link` al statement no cambia quién tiene el tensor: lo sigue teniendo el
secuenciador.

### 3.2 La variante literal contradice P-03 y rompe la economía

`certifiedNorm = floor(√ΣT_i²)` es la lectura global que `P-03` descartó el
2026-10-22, con tres razones registradas: el circuito desplegado no puede
certificarla (una sola palabra `norm`, testigo `u64`, hoja
`Poseidon(validator, norm)`); las constantes sólo cierran con `r < 1`
(`r ∈ [0.5, 1)` → colateral `[0.267, 0.4)`, stake `(0.6, 0.733]`, mientras
`‖T‖_F = 12.79` daría `C_R = 0.742` y stake `0.258`, por debajo del suelo `0.6`);
y la alternativa sólo desplaza `P-38` de sitio. Implementar el parche tal como
está escrito reabriría esa decisión sin discutirla y, de paso, dejaría
`requiredStakeFor` devolviendo menos que el mínimo que `admit` acepta.

### 3.3 Las piezas que sí valen, y por qué no necesitan el statement

Hay dos campos del parche que **sí** cambian algo, y los dos funcionan mejor
como **constantes de despliegue** que como palabras públicas:

- `sourceChainId` **inmutable** en el registry: hoy `postCommitment` acepta
  cualquier raíz sin decir de qué cadena viene; una constante convierte
  «publicar roots de otra fuente» en un `revert` que ningún testigo puede
  evitar. No necesita circuito ni ceremonia.
- `parametersDigest` **inmutable** en el registry, o mejor `activeFormulaDigest`
  con la regla «la publicación debe declarar el digest activo»: es la única
  forma on-chain de que un cambio de `f_c` no sea silencioso (Hazard 8 →
  M-15). Tampoco necesita statement: el digest lo publica el secuenciador y el
  contrato lo compara con su constante; la diferencia con hoy es que el valor
  esperado deja de ser «lo que el secuenciador dijo la última vez».

Ambos son cambios de interfaz (`postCommitment` gana un argumento), así que van
a un milestone con su nota de despliegue, no a un parche.

### 3.4 Las piezas que rompen algo sin cerrar nada

- **`Epoch::digest()` de cinco campos.** El digest actual
  (`keccak256(abi.encodePacked(uint256 epoch, bytes32 root))`,
  `commitment.rs:157-166`) está fijado por el test
  `digest_is_keccak_of_the_epoch_number_and_root` y por el fixture de
  `src/datalayer/fixtures/`. Cambiarlo rompe el fixture y no tiene consumidor
  on-chain: si se quiere trazabilidad de la metadata, lo correcto es un digest
  **nuevo** con dominio separado (`keccak("AVIP/epoch-meta/v1" ‖ …)`), no
  reutilizar el existente.
- **`identityCommitment` en `admit`.** El leaf ya liga la `address`
  (`Poseidon(validator, norm)`), así que la prueba no es un token al portador
  (`P-01`). Lo que falta no es un commitment de identidad: es que una dirección
  nueva no pueda empezar de cero, y eso es unicidad por época y persistencia
  off-chain (`P-12`, `P-38`). Añadir una palabra más al leaf cambia el circuito,
  la clave, el fixture y los cuatro sitios de coste, y no impide que alguien
  registre una identidad nueva.
- **Slash proporcional.** El importe completo es una decisión de `M9b`, y su
  razón está escrita en el contrato: con `stake = 0` el invariante
  `isAdmitted ⇒ stakeOf ≥ requiredStake` se mantiene para cualquier norma
  admitida. Un `slashPercent` menor que 1 obliga a repreciar
  `requiredStakeFor` y a decidir qué pasa con la eyección, que es trabajo de
  mecanismo, no de hardening.


## 4. Lo que merece un ticket (y no estaba en el registro)

Cuatro cosas del mapa no están en `audit-2026-10-20-in-progress.md` con esa
forma, y tres de ellas son baratas.

- **T-1 — Guard de despliegue para la custodia (M-12).** El contrato ya hace lo
  correcto cuando `custody != 0`; lo que no existe es nada que impida desplegar
  un `AVIPValidatorManager` con `custody = address(0)` y llamarlo «producción».
  `scripts/deploy_dryrun.sh` ya tiene los casos G–I de §5.12; falta el caso que
  falla cuando el manager se despliega sin la mitad de custodia y el
  `verify_fuji.sh` que lo comprueba en la cadena. No toca contratos.
- **T-2 — `sourceChainId` y `activeFormulaDigest` como constantes del registry
  (M-15, Hazard 8).** `postCommitment` gana dos argumentos que el contrato
  compara con sus inmutables; sin ellos, un cambio de fórmula o de cadena de
  origen es indistinguible de una publicación normal. Cambia la interfaz
  pública: va a un milestone con nota de despliegue (§5.12 ya es el precedente
  de cómo se documenta una firma nueva) y con tests de `revert` por mismatch.
- **T-3 — `EpochMeta` off-chain para trazabilidad (M-06/M-15).** Un
  `EpochMeta { number, root, statement_root, source_chain_id,
  parameters_digest, changed_entries }` con digest de dominio separado
  (`keccak("AVIP/epoch-meta/v1" ‖ …)`) en `src/datalayer/src/report.rs`. Da al
  auditor lo que el mapa echa de menos sin tocar `Epoch::digest()` ni el
  fixture, y sin pretender que sea una prueba.
- **T-4 — Tabla «qué garantiza el artefacto» (Hazard 10).** El README de
  `integrations/avalanche/contracts/` ya separa lo implementado de lo delegado;
  falta la tabla de tres columnas —*verificado / medido / supuesto*— por
  garantía (admisión, frescura, origen, custodia, slash). Es el entregable que
  el mapa pide en su Hazard 10 y el único de los diez que no requiere código.
- **T-5 — El ancla no verifica contra su propio árbol (G10/G11).** En `ea75594`
  el paper pasó a `2a3605ee…` y `anchor_root.sha256` siguió sellando
  `37ebdc73…`; hasta `fa78fff` coincidían. `bash verification/audit-gate.sh`
  devuelve 9 PASS / 2 FAIL (G10 «manifiesto no verifica», G11 «pares sha256
  DISCREPAN») también en un worktree detachado de `ea75594`, así que es deuda
  previa a esta sesión. Exige una decisión de gobernanza: re-emitir el sello
  (nuevo `Root` y nuevo anclaje) o revertir el paper a lo sellado. Mientras
  tanto, ningún `Root` prueba el contenido actual del paper.
  *Criterio:* 11/11 PASS en un worktree limpio de HEAD.
  *Nota operativa:* sin `--check`, `fase0_anchor.sh` **re-sella** en vez de
  verificar; el gate siempre lo invoca con `--check` (`audit-gate.sh:239`).
  Ejecutarlo a mano en el árbol de trabajo mueve el ancla.

## 5. Plan, en el orden en que conviene hacerlo

### P0 — deuda ya abierta, sin cambios de interfaz

| # | Acción | Archivos | Criterio de aceptación |
|---|---|---|---|
| 1 | Cerrar el test de `norm = p − 1` **o** documentar que el testigo `u64` no puede expresarlo y que el cierre es sólo del registry | `src/zk/tests/admission_statement.rs`, nota en `P-33` | El test existe y pasa, o la nota dice por qué no puede existir y `NormOutOfDomain` lo cubre en `M4dRealKey.t.sol` |
| 2 | Re-medir `manager.admit` de punta a punta con `r = T(i)`, `S_min = 0.6`, y decidir qué `r` se tarifa | `verification/mechanism/`, nota de v0.2.1 | Los ratios 2.39×/1.82× se reproducen o se sustituyen por los medidos, con el `r` nombrado |
| 3 | Decidir §5.5.7: opción (a) —admisión por `verifyEntry` keccak y retirada del ZK de la ruta de admisión— o (c) —bridge off-chain declarado— | `docs/architecture/implementation-plan.md` §5.5.7, `P-38` | Una frase de decisión con fecha, y la §4 del paper sin ninguna afirmación de cierre |
| 4 | Registrar este triaje y el acta de la matriz (`checklist-matriz-evidencia-2026-10-22.md`, con su v2 `matriz-evidencia-2026-10-22.md`) en el índice (`SESSIONS.md`) y enlazarlos desde la ficha de `P-38` | `docs/audit/SESSIONS.md`, `audit-2026-10-20-in-progress.md` | Enlace bidireccional |

### P1 — M10, con cambio de interfaz y nota de despliegue

| # | Acción | Archivos | Criterio de aceptación |
|---|---|---|---|
| 5 | T-2: `sourceChainId` y `activeFormulaDigest` inmutables en el registry | `AVIPRegistry.sol`, `IAVIPRegistry.sol`, tests Foundry, nota §5.12-style | Publicación con `sourceChainId` distinto revierte; con digest distinto revierte; la publicación válida no sube el gas más de un `SLOAD` medido |
| 6 | T-1: guard de despliegue de custodia | `scripts/deploy_dryrun.sh`, `scripts/verify_fuji.sh` | El dry-run falla con un caso nuevo «manager sin custodia»; el caso queda en el README del script |
| 7 | T-3: `EpochMeta` con dominio separado | `src/datalayer/src/report.rs` (tests inline), `commitment.rs` | El digest viejo no cambia (test pineado verde); el nuevo está cubierto por un vector fijo |

### P2 — rechazado o diferido, con motivo escrito

| Propuesta del mapa | Disposición |
|---|---|
| Statement de 6–7 palabras con `sourceChainId`/`formulaDigest`/`stateHash`/`merkleRoot` | **Rechazado**: §3.1. Publicar no es probar, y el coste es una ceremonia nueva |
| `certifiedNorm = floor(√ΣT_i²)` | **Rechazado**: contradice `P-03` y rompe la calibración de `S_f` (§3.2) |
| `identityCommitment` en `admit` | **Diferido** a §11 con `P-12`; no cierra portabilidad y cambia la clave (§3.4) |
| Slash proporcional | **Diferido** a mecanismo (`M9b`): exige repreciar `requiredStakeFor` antes (§3.4) |
| `emergencyPause` | **Diferido** a §11/M8; no hay hoy ruta de actualización que una pausa proteja |
| `Epoch::digest()` de 5–6 campos | **Rechazado**: rompe el fixture sin consumidor on-chain; sustituido por T-3 |
| Puntuaciones 0–10 | **No se registran** como hallazgo: sin criterio reproducible (M-17) |


## 6. Reproducción

```sh
# Estado del árbol
git log --oneline -1 && git describe --tags --always
sha256sum docs/paper/main.tex

# Contratos (275 tests, 0 fallos)
cd integrations/avalanche && forge test --summary

# Capa Rust de reputación (53 tests, 0 fallos)
cd src/reputation && cargo test --offline

# Las afirmaciones de §2, una por una
grep -n 'function postCommitment\|function verifyThreshold\|MAX_NORM' \
    integrations/avalanche/contracts/AVIPRegistry.sol
grep -n 'THETA_R\|S_MIN\|function admit' \
    integrations/avalanche/contracts/AVIPValidatorManager.sol
grep -n 'enforce_below_pow2(&(wad - norm' src/zk/src/admission.rs
grep -n 'pub fn digest' src/datalayer/src/commitment.rs
```

Salida observada el 2026-10-22 en `ea75594`: 275 *pass* / 0 *fail* en Foundry;
`53 passed; 0 failed` en `avip-reputation` (26,18 s).

## 7. Correspondencia con el registro

| Mapa | Registro existente | Comentario |
|---|---|---|
| Hallazgo 1 (root/proof/tensor) | `P-03`, `P-38`, `R3-03` | El mapa llega sin saber que ya hay decisión y triaje |
| Hallazgo 2 (root declarado) | `P-12`, `P-16` | — |
| Hallazgo 3 (norm sin rango) | `P-04`, `P-13`, `P-33` | Refutado como defecto; el hueco que queda es la cota inferior |
| Hallazgo 4 (data layer) | `P-02`, `P-12`, `P-34` | — |
| Hallazgo 5 (sequencer/guardian) | `P-10`, `P-29`, M9a | — |
| Hallazgo 6 (`latestEpoch`) | `P-32` | El mapa lo sube a Medio; el registro lo deja en Bajo (griefing) |
| Hallazgo 7 (identidad) | `P-12`, `P-38` | — |
| Hallazgo 8 (custodia) | `P-05`, `P-09`, `§5.12` | T-1 es lo que falta |
| Hallazgo 9 (slash) | `P-17`, `M9b` | Decisión, no defecto |
| Hallazgo 10 (circuito «no real») | `P-38`, `§5.5.11` | Refutado por M4d |
| Hazards 1–10 | `P-01`…`P-38` en bloque | Sin hallazgos nuevos; T-1…T-4 son las únicas piezas accionables |

## 8. Conclusión

El mapa es un buen diagnóstico y un mal plan. Acierta en el sitio —la verdad
del tensor vive fuera del contrato— y se equivoca en el remedio, porque confunde
*hacer público* un dato con *probarlo*: los campos que propone añadir al
statement los aporta el mismo actor que aporta el testigo, y el circuito no
puede derivarlos de las entradas. De sus diez *hazards*, la mayoría están ya en
el registro con más precisión (`P-xx`), dos son decisiones de despliegue o de
alcance (custodia obligatoria, pausa), uno es un entregable documental (Hazard
10, T-4) y uno —el versionado de `f_c`— se puede cerrar de verdad con dos
constantes inmutables en el registry, sin ceremonia y sin tocar el circuito.
Eso, y no el statement de siete palabras, es lo que este triaje se lleva al
plan.

