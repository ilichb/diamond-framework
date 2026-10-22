# Auditoría en curso — hallazgos provisionales (2026-10-20)

**Estado:** abierta. Cobertura estimada de esta pasada: **~70 %**
(la pasada anterior cubría ~30 %; esta añade lectura del circuito nativo, data
layer, economía, RMT y scripts de despliegue, más la revisión externa de
arquitectura y de las afirmaciones numéricas del paper).
**Árbol:** HEAD `dcffce2` (`docs: publish v0.2.1 errata and withdraw Zenodo
deposit`); la lectura de código se hizo sobre `70f225c`, y `dcffce2` sólo toca
las tres notas de release, no código ni ancla. `anchor_root` `adfd08d2…`.
**Alcance de esta pasada:** admisión/ZK, circuito nativo V3/V2′, data layer `f_c`,
`AVIPStakeVault`, verificador Groth16/Bn254, autoridad del registry, economía
`C_R`/`S_f*`/`F_0`, RMT, transporte Teleporter y coherencia paper/plan/README.
**Regla:** este fichero es un *worksheet*. No es un informe final, no se publica,
no se re-ancla y no autoriza cambios en `main.tex`, contratos ni `CITATION.cff`.
Los IDs `P-*` son **provisionales** y se renumerarán al cierre de la auditoría.
La única excepción acotada de esta revisión es la errata de
`docs/paper/releases/v0.2.1-notes.md` y sus punteros en
`docs/paper/releases/README.md` y
`docs/paper/releases/v0.2.1-zenodo-checklist.md`: no reexporta el PDF, no crea
Release ni DOI y no mueve el ancla.

**Evidencia conservada:** los fuentes originales de los POCs se borraron al
cerrar la sesión y no son recuperables byte a byte. Su inventario, la bitácora,
los cálculos de gas, dos reconstrucciones ejecutables y dos PoCs nuevas (P-26 y
addendum de P-12) están en `docs/audit/evidence/2026-10-20-pocs/`. Las menciones
“borrado” de este worksheet son históricas; la evidencia disponible se consulta
allí.

## Método

1. Lectura de fuente: contratos, interfaces, mocks, tests Foundry, data layer,
   circuito y bridge.
2. Contraste con `docs/paper/main.tex`, `docs/architecture/implementation-plan.md`,
   `README.md` y los triajes externos.
3. Reproducción: `forge test` offline, `cargo test` offline, PoCs temporales
   (reutilización de proof, clave cero y `gamma2` identidad, token de 0
   decimales, colapso de roles, `certifiedNorm + r`, freshness declarada, burn
   sink permissionless, colisión Poseidon/keccak y gas del verificador) y
   re-ejecución de los scripts numéricos de §2.4, §8, Tucker y M-05.
4. Registro: solo se anota lo confirmado localmente; lo no cubierto queda en la
   sección de alcance pendiente.

## Resumen

| ID | Hallazgo | Severidad provisional | Estado | ¿Nuevo? |
|---|---|---|---|---|
| P-01 | El proof de admisión es global; no está atado al validador | **Crítica** | Confirmado con proof real | Sí |
| P-02 | `f_c` no ata el score a un validador ni a la procedencia de eventos | **Alta** | Confirmado por lectura | Sí |
| P-03 | Tres semánticas incompatibles de `T` (paper, data layer, bridge) | **Alta** | **Resuelto por decisión (2026-10-22): `r = T(i)` per-validator** | Sí |
| P-04 | `certifiedNorm` del prover está limitado a `< 2^64` (18.4467 WAD); el máximo práctico del protocolo es 22.36 y el teórico del circuito 25.78 | Media/baja | Confirmado por lectura | Sí |
| P-05 | `bindManager` del vault es una carrera de despliegue | Media (operacional) | Confirmado on-chain: Fuji OK, sin fondos; código vulnerable | No |
| P-06 | El fee por época no se enforcea on-chain | Baja/media | Ya documentado | No |
| P-07 | Paper/plan/README afirman un binding que el código no tiene | Media | Confirmado por lectura | Derivado |
| P-08 | `Groth16Verifier` acepta una clave degenerada (todo en el infinito, o sólo `gamma2`) y devuelve `true` para cualquier proof | **Alta** (crítica si se instala) | Confirmado con PoC | Sí |
| P-09 | Con un token de 0 decimales, `debit` redondea el slash completo a 0 unidades y el validador retira el escrow | **Alta/media** (según token) | Confirmado con PoC | Sí |
| P-10 | El guardian puede proponerse a sí mismo como sequencer: la separación de roles sólo se comprueba al desplegar | Media | Confirmado con PoC | Sí |
| P-11 | `requiredStake` queda obsoleto tras una eyección: no incluye el surcharge que el siguiente `admit` cobra | Baja | Confirmado con PoC | Sí |
| P-12 | La freshness `γN` sólo se comprueba sobre el delta **declarado**; no está atada al root ni al tensor. Addendum: el data layer tampoco impone `N` ni unicidad | Media (confianza/overclaim) | Confirmado con PoC | Sí |
| P-13 | `Groth16Verifier` acepta `certifiedNorm + r` (public input no canónico); el manager lo bloquea por overflow, no por política | Baja/media (latente) | Confirmado con PoC | Sí |
| P-14 | `AVIPSlashingChannel` descarta `epoch`, `ingestionDigest` y los dos WAD al ejecutar; el destino no los registra | Baja | Confirmado por lectura | Sí |
| P-15 | `AVIPBurnSink.receiveFunds` es permissionless: cualquiera puede quemar tokens no reclamados del sink | Baja/informativa | Confirmado con PoC | Sí |
| P-16 | Un solo `_roots[epoch]` no puede ser a la vez la raíz Poseidon de V3 y la raíz keccak de M1: admisión y `verifyEntry` son incompatibles | **Crítica** | Confirmado con PoC | Sí |
| P-17 | La admisión se evalúa una vez; no hay recertificación ni reprecio y el slash no escribe reputación: el “decay” no tiene efecto on-chain; la ausencia de salida honesta está declarada (`main.tex:1379`: informativo) | **Alta** | Confirmado por lectura | Sí |
| P-18 | El bounty `B` no tiene ruta de pago: slash y fee van a `AVIPBurnSink`; el paper lo declara parámetro de modelo, pero el lazo de auditores no se entrega | Media (gap modelo/implementación) | Confirmado por lectura | Derivado |
| P-19 | El agregador Frobenius permite pasar `Θ_r = 0.5` con una sola celda y obtener 26,7 % de descuento (40 % con una celda a 1,0); no mide amplitud ni historial | Media (diseño económico) | Confirmado por cálculo | Sí |
| P-20 | §2.4: los momentos estacionarios tabulados son el límite `λ = 0`, no el proceso con saltos; la media real es 0,8065/0,9434, no 1,0 | **Alta (paper)** | Confirmado con cálculo y simulación | Sí |
| P-21 | §7.5: `γ` acota entradas cambiadas, no la duración del fraude; una hoja fraudulenta sin cambios persiste y `q_min(k) → 1` | **Alta (paper)** | Confirmado con la fórmula del paper | Sí |
| P-22 | §2.5: `π(r)` se despeja de la `C_R` elegida; la “consistencia” es circular y la tasa de descuento es `r`, sin justificar | Media (paper) | Confirmado por lectura | Sí |
| P-23 | §8: el bootstrap usa `C̃_R = 0.8R/(1+R)`, no el mapeo de §2 (`0.8R`); con el mapeo la reducción sería 31,5 %, no 22,4 %; el Gini es idéntico por construcción | Media (paper) | Confirmado por cálculo | Sí |
| P-24 | `F0* = 0.05` se calcula en `T = 0`, fuera del dominio admisible (`Θ_r = 0.5`); el óptimo admisible es 0,07666 y la fee se quema | Media (paper/contrato) | Confirmado por lectura | Sí |
| P-25 | Erratas y sobreafirmaciones menores: NatSpec de `S_f*`, unidades de `c`, error Tucker, gas `~206k` (corregir a 286.144 frío), frontera absorbente y cola “geométrica” | Baja/media (paper; el gas es material) | Confirmado por lectura/cálculo | Sí |
| P-26 | Los guards de despliegue no son fail-closed fuera del runbook de fase 1: scripts individuales aceptan cadenas no previstas, `deploy(Plan)` no reaplica el guard de claves anvil y la fase 1 acepta `TOKEN`/`SINK` sin código | Media/baja (operacional) | Confirmado con PoC | Sí |
| P-27 | El detector de colusión no está conectado al estado de reputación: `W` es una entrada externa y el mapa `T → W` sigue abierto (D-7); el paper no lo declara en Limitaciones | **Alta** (diseño/paper) | Confirmado por lectura | Sí (adenda) |
| P-28 | El “piso financiero” es `0.2Θ`: garantiza un coste mínimo de admisión, no un nivel de seguridad; un cártel con reputación inflada paga 5× menos por nodo que en PoS puro | **Alta** (paper; económica) | Confirmado por cálculo | Sí (adenda) |
| P-29 | El README presenta como propiedad de v1 una confianza mínima que v1 no tiene: sequencer único, `slashAuthority` único y un guardian que puede cambiar el verificador tras 2 días | Media (documentación/overclaim) | Confirmado por lectura | Sí (adenda) |
| P-30 | `π_val`, `ω` y `k` no tienen una unidad temporal definida; el ejemplo `F0* = 0.05` y el break-even no son convertibles a tiempo real | Media (paper; modelo) | Confirmado por lectura/cálculo | Sí (adenda) |
| P-31 | La introducción afirma que la capacidad física de PoW “frena” la centralización sin cita ni análisis; la literatura de reputación en PoS citada es escasa | Baja/media (paper) | Confirmado por lectura | Sí (adenda) |
| P-32 | `admit` usa siempre `latestEpoch()`: el sequencer puede publicar una época nueva e invalidar proofs en vuelo; es griefing/liveness, no robo | Baja (griefing/DoS) | Confirmado por lectura y test existente | Sí (adenda) |
| P-33 | El circuito no impone `T ∈ [0,1]`: `ENTRY_BITS = 60` acepta entradas hasta `2^60−1 = 1.152921504606846975 WAD`; no hay comparación contra `WAD` | Media/baja (circuito; dominio) | Confirmado con sonda temporal | Sí (adenda) |
| P-34 | El slash cross-chain se ejecuta sobre la palabra del `NOTIFIER`: no hay prueba de fraude on-chain, ventana de impugnación ni alcance temporal; el destino no puede distinguir un `Verdict::Fraud` real de dos números desiguales | **Alta** (confianza/custodia) | Confirmado por lectura; el propio test M7d lo declara | Sí (tercera lectura) |
| P-35 | La frontera de detección no es Kesten–Stigum y el paper sólo probó densidad 10×: 40 coludidos a 3× pasan con TPR≈0,06; BBP sitúa el umbral en θ≈4,38 (m≈12,2 a 10×) y el 50 % en m≈15,4 | **Alta** (paper; resultado negativo) | Confirmado con réplica propia de 300 réplicas | Sí (tercera lectura) |
| P-36 | Bibliografía: Bauer–Jost está mal citado (CPAM 2012 → *Comm. Anal. Geom.* 21(4):787–845, 2013) y faltan referencias para Kesten–Stigum, Feller y EIP-196/197 | Baja (paper) | Confirmado con Crossref/arXiv | Sí (tercera lectura) |
| P-37 | La permutación Poseidon reproduce los vectores t=3 de circomlib; el digest usa `state[1]` (rate) y no el `state[0]` (capacidad) de circomlib. Es una convención de esponja válida, no un defecto del circuito; sólo limita la interoperabilidad con primitivas de 2 entradas | Baja (interoperabilidad; no soundness) | Confirmado con sonda: 2 vectores t=3, absorción 1–10/500 y ambigüedad de longitud documentada | Sí (sonda de cierre; nota de documentación) |
| P-38 | La prueba de admisión tiene todo el statement público y su testigo es el camino de Merkle: sólo oculta la posición de la hoja. No aporta zero-knowledge sobre la norma ni ahorra gas frente a `verifyEntry` | Media (diseño y honestidad del artefacto; no soundness) | Confirmado por lectura (`admission.rs:212-276`) y por medición: 306,275 gas fríos frente a una inclusión keccak de pocos miles | Sí (adenda M4d) |

**Remediación posterior a este worksheet.** M4d (plan §5.5.11) cierra **P-01** y
**P-16** y añade al circuito de admisión la cota de **P-33**: el statement pasa a
`[statementRoot, epoch, validator, certifiedNorm]` sobre una inclusión Merkle de la
hoja `Poseidon(validator, norm)`; `AVIPRegistry` guarda `statementRootOf(epoch)` en
una ranura separada de `commitmentOf(epoch)` (una sola `postCommitment` escribe
ambas); y el circuito impone `norm < WAD`, así que el dominio admitido es
`[0, 1)`: el papel pide `[0,1]` y el circuito excluye el punto `r = 1`, un borde
de completitud (no de soundness) que además es el ínfimo de `S_f` — ver (ii).
Las secciones de abajo conservan el texto, los números de línea y los
medidores del árbol auditado (`70f225c`), que es lo que las PoCs midieron; la
columna «Estado» no se reescribe.

**Lo que M4d no cierra, y que un paper sobre M4d no debe dar por cerrado.**
(i) La norma de la hoja es `Entry.norm_wad`, y la prueba demuestra pertenencia y
ata validador y época, pero no que la raíz de admisión provenga del tensor
comprometido: el `AVIPRegistry` ve raíces, no entradas. Es la ambigüedad de `T`
de **P-03**, y el `TENSOR_DIGEST` pineado la sostiene sólo *off-chain*
(`test/M4dRootSeparation.t.sol` la escribe como prueba, incluida la ausencia de
vínculo on-chain). (ii) El suelo real de `S_f` es **0.6** y lo fija el circuito,
no la lectura de `T`: `admission.rs:245` impone `norm ≤ WAD-1` sobre
representantes canónicos, de modo que `r < 1` y
`S_f = (1+0.2r)/(1+r)`, decreciente, tiene ínfimo 0.6 —no alcanzado, porque
`r = 1` está excluido—; con `Θ_r = 0.5` la banda admitida es `(0.6, 0.7333]`. El
0.2 del paper es el límite `r→∞`, y la lectura global de M4b (12.79 → 0.258) cae
*por debajo* del suelo, luego las dos lecturas no pueden compartir `C_R`. P-33
fija el suelo; P-03, qué significa `r`. La cota de P-33 es de **una sola cara**
—también satisface el chequeo la banda `[p−2^60+WAD, p−1]`, que es `norm`
negativa en el campo—, y eso se cierra ahora en `AVIPRegistry.verifyThreshold`
con `NormOutOfDomain`, no en la clave; el porqué y lo que queda pendiente están
en la nota de endurecimiento de la ficha P-33. (iii)
Las cifras del paper (94,438 restricciones, 3.9 s, 286,144 gas) son de V3; el
circuito de admisión mide **4,827** restricciones, **0.33 s** de prueba y
**234,284** gas de `verify` (**306,275** en frío y **247,233** en caliente por
`verifyThreshold`, ver `test/M4dRealKey.t.sol`); los ratios 2.39× y 1.82× de la
nota de v0.2.1 dependen del camino completo de `manager.admit`, que no se ha
vuelto a medir, así que no se pueden repetir sin medirlo.

---

## P-01 — El proof de admisión es global y no está atado al validador

**Severidad provisional:** Crítica (bloquea v1 con verificador real).
**Estado:** Confirmado con PoC ejecutable.
**Ubicación:** `AVIPRegistry.verifyThreshold`,
`AVIPValidatorManager.admit`, `IAVIPRegistry`.

### Qué hace el código

`AVIPRegistry.verifyThreshold` construye un statement de **tres** elementos:

```solidity
uint256[] memory statement = new uint256[](3);
statement[0] = uint256(root);
statement[1] = epoch;
statement[2] = certifiedNorm;
```

`AVIPRegistry.sol:342-345`.

No hay dirección del validador, ni hoja de reputación, ni proof de inclusión. El
`root` es el compromiso global de la época; `certifiedNorm` es la norma global
certificada por el circuito.

`AVIPValidatorManager.admit` comprueba `msg.sender == validator` y después llama a
`registry.verifyThreshold(epoch, certifiedNorm, proof)`
(`AVIPValidatorManager.sol:231-274`). El manager ata la **llamada** al caller, no
el **proof** a la reputación del validador. No recibe ni verifica una prueba de
inclusión de la hoja del validador.

`verifyThreshold` es `view` y no escribe estado
(`AVIPRegistry.sol:321-324`). El comentario de la interfaz dice que el registry no
guarda estado por validador y que “no caller can consume another validator's proof
slot” (`IAVIPRegistry.sol:158-160`). El problema es que **no existe tal slot**: el
proof es global y reutilizable.

El único anti-replay es `!isAdmitted[validator]`
(`AVIPValidatorManager.sol:235`). Eso impide que la **misma** dirección se admita
dos veces; no impide que direcciones nuevas usen el mismo proof.

### PoC ejecutada

La primera PoC (`TmpGlobalProofReuse.t.sol`, ya borrada) usó dos direcciones
nuevas (`freshA`, `freshB`), el mismo `proof` y `certifiedNorm = THETA_R` con
`MockThresholdVerifier`; ambas quedaron admitidas. Era una prueba de la lógica
del manager, pero no del Groth16 real.

La reconciliación exigía cerrar ese hueco. Se ejecutó
`integrations/avalanche/test/TmpP01Real.t.sol` (temporal; fuente original
perdido, reconstrucción ejecutable en
`docs/audit/evidence/2026-10-20-pocs/pocs/reconstructed/TmpP01Real.t.sol`) con
la proof **real** de `M4bGroth16Fixtures`, el `Groth16Verifier` real y un
`AVIPValidatorManager` real:

```text
registry.postCommitment(0, bytes32(F.STATEMENT_ROOT), 500);
manager.admit(alice, 1e18, F.STATEMENT_NORM, F.proof());
manager.admit(bob,   1e18, F.STATEMENT_NORM, F.proof());
```

Los cuatro tests del harness pasaron. Alice y Bob quedaron admitidas con la
misma prueba; `requiredStake(alice) == requiredStake(bob)`. Es la misma fixture
que usa `M4bRealKey.t.sol`; el test permanente debe añadirse allí, no quedarse
como harness temporal. La conclusión no es un artefacto del mock: el statement
real sólo contiene `[root, epoch, certifiedNorm]`, y el verificador es `view` y
stateless.

El mismo harness midió la ruta real: `verify` 223.403 gas en caliente,
`verifyThreshold` 233.104 en caliente y 286.144 en frío, y `admit` 376.588.
Esos números se usan en P-25; no cambian la severidad de P-01.

### Consecuencia

Cualquier dirección puede copiar el proof de la época actual desde el mempool o
desde la cadena y recibir el descuento de stake sin haber adquirido reputación.
El proof está atado a `(root, epoch, norm)`, no a la identidad. La frescura impide
reutilizar un proof de una época anterior, pero no uno actual entre identidades.

El coste no es cero: el atacante debe depositar el stake descontado. Pero el
componente de reputación —hasta el 80 % del stake— se free-ridea. Con la norma
global alta, el stake requerido baja hasta ~`0.234` y tiende a `0.2`; con
`certifiedNorm = 0.5`, el tipo “de peor caso” paga `0.733`. El proof global aplica
el mejor descuento disponible a cualquier identidad nueva.

### Matiz importante

El data layer sí construye hojas `Entry { validator, norm_wad }`
(`src/datalayer/src/commitment.rs:48-55`). Lo que falta es que ese `validator`
entre en el statement y en el circuito. Además, el bridge declara que la clave de
la hoja es la **posición** del tensor, no la dirección
(`src/zk/src/bridge.rs:36-44`). Es decir: ni la hoja ni el proof identifican de
forma autoritativa al validador.

### Por qué es crítico

El paper dice que la regla es “per-validator” (`main.tex:78`) y que la reputación
está “bound to a validator identity” (`main.tex:86`). §6.2 afirma que “the proof
binds the admission to a specific committed tensor, and the manager ties the
admission call to the validator” (`main.tex:849-851`). La segunda mitad es cierta
para el caller; la primera no ata al validador. El README afirma que la reputación
“accrues to a validator's own verifiable history” y que no puede alquilarse
(`README.md:42`). Tampoco se sostiene con el proof global.

No es explotable en Fuji Phase 1 porque `verifier = address(0)` y
`verifyThreshold` revierte `VerifierNotSet` (`AVIPRegistry.sol:329-330`). Sí bloquea
cualquier despliegue con verificador real.

### Remediación propuesta (no implementada)

1. Añadir `validator` como *public input* del circuito y obligar al circuito a
   demostrar que la norma certificada es la del validador (compromiso por
   validador, o `validator → norm`).
2. Alternativa: compromiso por validador y proof de inclusión de la hoja; el
   registry verifica `(root, leaf, path, norm)`.
3. No basta con añadir `validator` al array de Solidity: el circuito debe
   constrain-earlo, o será una etiqueta sin significado aritmético.
4. **Criterio de aceptación del rediseño (test permanente, proof real).** Debe
   vivir junto a `M4bRealKey.t.sol` y usar `M4bGroth16Fixtures` o la fixture
   regenerada, nunca el mock:
   - dos direcciones nuevas presentan el mismo proof; la primera `admit` pasa y
     la segunda debe revertir;
   - para **cada** entrada pública del statement nuevo (`root`, `epoch`,
     `validator`, `certifiedNorm`) se muta sólo esa entrada y `verify` debe
     devolver `false`; las cuatro mutaciones se prueban por separado, no como
     una suma de cambios;
   - si mutar `validator` sigue devolviendo `true`, la entrada está añadida pero
     no constreñida: el rediseño **no se acepta**, aunque `ic.length` sea el
     esperado;
   - se prueba además una mutación de `validator` a una dirección que sólo
     difiere en los bytes altos (mismos bytes bajos, incluido un par que sólo
     cambia el byte más significativo); también debe devolver `false`. Con 160
     bits dentro de un campo de 254 no debería haber aliasing, pero el test lo
     demuestra en vez de asumirlo;
   - la `gamma_abc_g1` de `validator` no puede ser la identidad y el circuito
     debe atar la hoja/índice privado al validador público (checklist de P-16,
     sección «Diseño conjunto con P-01 (no implementado)»).
5. No basta con añadir `validator` al array de Solidity: el circuito debe
   constrain-earlo y la `gamma_abc_g1` de esa entrada no puede ser la identidad.
   El test de mutación es la única forma de detectar una entrada pública
   “decorativa”; por eso es criterio de aceptación, no un extra.

**Relación con P-16: es el mismo rediseño, no dos parches.** Un compromiso por
validador con una sola raíz canónica on-chain y el validador ligado dentro del
circuito resuelve a la vez el proof global y la colisión Poseidon/keccak. No se
debe implementar P-01 dejando P-16 para después, ni al revés: cambiar el
statement una vez y no dos. El diseño conjunto y la lista de métricas que quedan
inválidas están en P-16.

**Consecuencia adicional sobre M9c.** El recargo por eyección también es por
dirección: `_ejections` es un `mapping(address => uint256)`
(`AVIPValidatorManager.sol:136`) y una dirección nueva empieza en cero. Un
validador expulsado puede re-admitirse desde otra cuenta con el mismo proof y
pagar `S_f*(r)` sin el `+κ` que M9c quería cobrar. No hace falta una identidad
nueva “real”: basta una clave nueva. Esto refuerza que P-01 no es sólo un
descuento de stake, sino la anulación del historial on-chain ligado a la
dirección.

---

## P-02 — `f_c` no ata el score a un validador

**Severidad provisional:** Alta.
**Estado:** Confirmado por lectura.
**Ubicación:** `src/datalayer/src/ingestion.rs`, `src/datalayer/src/commitment.rs`.

`Window` contiene solo tres contadores —`attestations`, `governance`,
`liquidity`—; no contiene validador, dominio ni horizonte
(`ingestion.rs:71-82`). El trait `Ingestion` no recibe identidad: solo conoce la
chain (`ingestion.rs:92-104`). `GenesisFormula::score` es la misma función para
todos los validadores de la chain con la misma ventana (`ingestion.rs:195-201`).

`adjudicate` recibe la `Window` del llamante y solo compara
`published.entry.norm_wad == formula.score(window).wad()`
(`ingestion.rs:251-268`). No comprueba que esos eventos pertenezcan al
`entry.validator`; no hay procedencia ni prueba de que la ventana sea la del
validador.

**Consecuencia:** incluso si P-01 se corrigiera y el proof atara el validador, el
score seguiría sin estar atado a la identidad. Un fraud proof puede elegirse con
una ventana favorable, y el `f_c` global no distingue a dos validadores con la
misma ventana. El paper reconoce que v1 no implementa atribución on-chain
(`main.tex:1443`: “On-chain attribution of a fraudulent leaf to a validator; v1
does not implement it”), pero no conecta esa limitación con el binding de
admisión ni con `f_c`. También dice que no fija una `f_c` numérica
(`main.tex:991`), lo que no exime de atar la ventana al validador.

**Remediación:** incluir `validator` (o un conjunto de eventos con procedencia) en
`Window`; que `adjudicate` verifique que la ventana pertenece al `entry.validator`;
o declarar explícitamente que `f_c` es un score de chain y que la atribución
individual queda fuera de v1. Esta última opción no arregla P-01.

---

## P-03 — Tres semánticas incompatibles de `T`

**Severidad provisional:** Alta.
**Estado:** Confirmado por lectura.
**Ubicación:** `main.tex`, `commitment.rs`, `bridge.rs`.

El paper define `T ∈ [0,1]^{C×D×H}` con `C=20`, `D=5`, `H=5` y dice que
`T[c,d,h]` es “the validator's normalized score” (`main.tex:328-337`). Eso implica
un tensor por validador, o al menos un índice de validador.

El data layer define `Entry { validator: [u8;20], norm_wad: u128 }` y una `Epoch`
con 500 hojas (`commitment.rs:48-55,129-135`). Eso son 500 validadores con un
escalar cada uno, no un tensor `20×5×5` por validador.

El bridge dice que la clave de la hoja `i` es `position_key(i)`, la **posición**
del tensor, no una dirección; y que identificar posición con validador —el mapa
`T → W`— no se reclama (`bridge.rs:36-44`).

**Consecuencia:** hay tres lecturas incompatibles: tensor global de 500 celdas,
500 validadores con un escalar, o un tensor `20×5×5` por validador. El circuito
prueba la suma de cuadrados de 500 entradas (`native.rs:242-254`); no prueba la
norma de un tensor `20×5×5` por validador. La frase del paper “500 entries” es
compatible con el tamaño, pero no con la semántica per-validator.

**Remediación:** decidir una semántica antes de tocar el circuito. Si `T` es por
validador, el compromiso debe ser por validador (o de dos niveles). Si `T` es
global, hay que dejar de presentar la regla como per-validator y asumir el club
de reputación; pero eso no arregla el Sybil.

### Decisión (2026-10-22): `r = T(i)`, y quién lo calcula

Se elige la lectura del data layer y del manager: `r = T(i)`, el escalar
per-validator, `0 < r < WAD`. Tres razones, en orden de peso.

1. **Es lo único que el circuito desplegado certifica.** M4d tiene una entrada
   pública `norm` y un testigo `norm_wad: u64`, y su hoja es
   `Poseidon(validator, norm)`. No hay testigo de 500 entradas, así que la norma
   global no es expresable en la ruta de admisión: `‖T‖_F` exigiría el testigo de
   V3/M4b, que el manager ya no admite porque no nombra validador (P-01).
2. **Las constantes sólo cierran con `r < 1`.** `Θ_r = 0.5` es una puerta de
   entrada y `C_R(r) = 0.8 r/(1+r)`: con `r ∈ [0.5, 1)` el colateral vive en
   `[0.267, 0.4)` y el stake exigido en `(0.6, 0.733]`. Con `r = ‖T‖_F = 12.79`
   el mismo `C_R` da `0.742` y el stake `0.258`: desaparece tanto el suelo de
   `0.6` que el dominio del circuito impone como la razón por la que
   `S_min = 0.2` es inactivo. El paper afirmaba las dos cosas a la vez.
3. **La alternativa no arregla P-38, la desplaza.** Con `r = ‖T‖_F` el
   secuenciador seguiría eligiendo el tensor; la atribución quedaría igual de
   off-chain.

**Quién calcula `T(i)`.** Nadie en la ruta on-chain. El escalar lo escribe el
secuenciador en el delta del epoch (`Entry.norm_wad`, ≤ γ·N = 50 entradas por
epoch, `commitment.rs`), y el circuito prueba pertenencia y rango, no que el
valor provenga de los eventos de consenso. El mapa eventos → `T(i)` es la
ingesta del data layer: off-chain y no probado. La consecuencia que el revisor
señaló es exacta — con `r = T(i)` la estructura de tensor de 500 celdas sale de
la ruta de admisión y queda en el relay y en la auditoría —, y el paper lo dice
ahora en esos términos (contribución, §tensor, §zk, §payment y limitaciones), así
que P-38 gana un párrafo en lugar de perderlo.

**Efecto sobre cifras del paper**, que no son cosméticas:

- El peor caso de la condición de disuasión deja de ser `r_fraud → ∞` (valores
  `0.2857` y `0.7826`, inalcanzables) y pasa a ser `r_fraud → 1`, que es la
  columna de referencia ya publicada: `q > 0.0625` a un epoch y `q > 0.375` a
  nueve. La cota del circuito **mejora** el número, no lo empeora.
- El suelo efectivo es `Θ − C_R(1) = 0.6`, no `Θ − C_R^∞ = 0.2`; `S_min = 0.2`
  no llega a morder. Está en el NatSpec de `requiredStakeFor` y en §payment.
- El Monte Carlo de `fee_specification.py` sortea `r ~ U[0,3]`, el dominio sin
  restringir; la tabla de utilidades no se recalcula aquí y el paper lo declara
  (los valores de `r > 1` no son certificables y los de `r < Θ_r` no son
  admitidos). Recalcularla con `r ~ U[Θ_r, 1)` es trabajo de v0.2.2, no de este
  commit.

**Lo que la decisión no cierra**, y queda escrito: `‖T‖_F` sigue siendo la
magnitud de auditoría del epoch y ninguna cantidad on-chain la mide; la unicidad
de la hoja por validador es off-chain (P-38); y la ligadura entre
`commitmentOf` y `statementRootOf` sigue siendo del secuenciador hasta §5.5.7.

**Relación con P-16:** además de la semántica, el registry sólo tiene una ranura
`_roots[epoch]`; no puede guardar a la vez la raíz Poseidon de la norma y la
raíz keccak de las hojas. P-16 trata esa colisión de estado, no la definición de
`T`.

---

## P-04 — `certifiedNorm` del prover está limitado a `< 2^64`

**Severidad provisional:** Media/baja.
**Estado:** Confirmado por lectura.
**Ubicación:** `src/zk/src/native.rs`.

`NormCircuit`, `PoseidonNormCircuit` y `PedersenNormCircuit` llevan
`certified_norm_wad: u64` (`native.rs:210-214,231-235,418-422`), y
`StatementCircuit` también (`groth16.rs:94-102`). `CERTIFIED_BOUND_BITS = 64` y
el comentario asume una norma WAD `< 3e18` (rango simulado `[0,3]` del plan)
(`native.rs:116-120`). El máximo teórico del dominio del paper es
`√500 ≈ 22.36`, es decir `22.36e18` WAD, por encima de `2^64 ≈ 18.4467e18`.

**Consecuencia:** el prover no puede certificar una norma superior a ~18.4467,
aunque el dominio del paper llegue a 22.36. No bloquea `Θ_r = 0.5` ni los umbrales
bajos, pero sí contradice el dominio completo y la afirmación de que el circuito
cubre `[0,1]^500`. Es una restricción de rango que debe declararse o corregirse.

**Remediación:** usar un tipo más ancho (`u128` o `Fr`) para
`certified_norm_wad`, o declarar explícitamente el rango máximo admitido y
alinearlo con el paper. Si se mantiene `u64`, el paper no puede afirmar el dominio
`[0,1]^500` sin cualificar.

### Addendum (tercera lectura): el límite es aún más estrecho de lo que parecía

El informe externo del 2026-10-21 llega al mismo límite y añade una consecuencia
que conviene registrar: con `ENTRY_BITS = 60`, el máximo por entrada es
`2^60 − 1 = 1.152921504606846975 WAD` (P-33). Si se permiten 500 entradas a ese
máximo, la norma teórica es `√500 × 1.1529 ≈ 25.78`, no `22.36`. El límite
`certified_norm_wad < 2^64 = 18.4467` es, por tanto, **más estrecho** que el
dominio que el circuito acepta, y el fallo es de **completitud** (un tensor
honesto con norma alta no puede probar), no de soundness.

Hay dos cotas distintas y el addendum debe nombrarlas por separado:

- **25.78** es el máximo **del circuito** con `ENTRY_BITS = 60`: 500 entradas a
  `2^60 − 1 = 1.152921504606846975 WAD`.
- **22.36** es el máximo **del protocolo** con entradas `< WAD` y `N = 500`:
  `√500 × 1.0`. Es el tope práctico de un tensor legítimo.
- En ambos casos el límite `certified_norm_wad < 2^64 = 18.4467` queda por
  debajo. No son cifras contradictorias: la primera describe lo que el circuito
  acepta, la segunda lo que el dominio del paper permite.

Esto no cambia la severidad de P-04 ni crea un ID nuevo: es la misma cota global.
Sí cambia el criterio de cierre: al implementar P-33 hay que decidir si el
`certified_norm_wad` se ensancha a `u128`/`Fr` o si el paper declara un máximo
`≤ 18.4467` y el circuito rechaza el resto. Las dos cosas no pueden quedar
implícitas.

---

## P-05 — `bindManager` del vault es una carrera de despliegue

**Severidad provisional:** Media (operacional); Alta si el vault puede recibir
depósitos antes del binding.
**Estado:** Confirmado on-chain; ya documentado y testeado. El despliegue de Fuji
concreto está correctamente enlazado y sin fondos.
**Ubicación:** `AVIPStakeVault.sol:31-60,258-263,372-376`;
`M8StakeVault.t.sol:313-390`; `DeployFujiPhase1.s.sol:17-27`.

`bindManager` no tiene autenticación y acepta un EOA
(`AVIPStakeVault.sol:40-49,258-263`). El manager legítimo llama a `bindManager`
desde su constructor, pero el vault se despliega antes; entre las dos
transacciones hay una ventana en la que un tercero puede registrarse como
manager. Ese tercero hereda `debit` (`:372-376`), puede enviar escrow al sink y
deja `withdrawable` ilegible al hacer `staticcall` de `isAdmitted` contra una
EOA; el resto del escrow queda atrapado. El test
`test_aStrangerWhoTakesTheBindWithAnEoaDrainsAndTrapsAVictimsEscrow` ya lo
demuestra; no es un riesgo teórico.

`DeployFujiPhase1` usa un solo `startBroadcast`/`stopBroadcast`, pero eso **no es
atomicidad**: son dos CREATEs separadas. La prueba on-chain es que el vault se
creó en el bloque **59.670.734** y el manager (que ejecuta el bind) en el
**59.670.735**: hubo una ventana de un bloque. En este despliegue no hubo
adversario y el resultado es correcto:

```text
vault      = 0xAE41076223b5b9EB0E811B0751D806B092DaA5E4
manager    = 0x7C92D08B3d945424154743Adf1D7b1965B88b100
vault.manager()   -> 0x7C92D08B3d945424154743Adf1D7b1965B88b100
manager.custody() -> 0xAE41076223b5b9EB0E811B0751D806B092DaA5E4
totalEscrowedUnits = 0; totalDeposited = 0; heldUnits = 0
```

Es decir: el riesgo de **este** despliegue está cerrado y no hubo fondos
expuestos, pero el patrón sigue siendo vulnerable para cualquier despliegue
futuro. El riesgo no se cierra con “un solo script”; se cierra con atomicidad
real o con una dirección de binder comprometida de antemano.

**Remediación:** (a) factory que despliegue vault y manager en una sola
transacción; o (b) pasar al constructor del vault la dirección **predicha** del
manager (`computeCreateAddress`) y exigir `msg.sender == expectedManager` en
`bindManager`; o (c) `bindManager` restringido al deployer con deadline. La
opción (b) es compatible con el handshake actual y no necesita código del
manager en el momento del bind. No es un bug de la aritmética del vault, pero sí
de su secuencia de despliegue.

---

## P-06 — El fee por época no se enforcea on-chain

**Severidad provisional:** Baja/media.
**Estado:** Ya documentado; se registra por completitud.
**Ubicación:** `AVIPStakeVault.payFee`.

`payFee` no lleva época, no mantiene un ledger por época y no impide pagar varias
veces o no pagar (`AVIPStakeVault.sol:399-401`). El contrato lo declara como
“caller policy”. No es un bug de fondos, pero es una diferencia entre lo que el
paper describe y lo que el contrato garantiza; si el fee es parte del modelo de
deterrencia, el contrato no lo hace ejecutable por sí solo.

**Remediación:** o se enforcea con `(validator, epoch)` y un registro, o se
declara explícitamente que el fee es una obligación off-chain y no una condición
de admisión.

---

## P-07 — Paper/plan/README afirman un binding que el código no tiene

**Severidad provisional:** Media.
**Estado:** Confirmado por lectura; derivado de P-01/P-02.
**Ubicación:** `main.tex`, `implementation-plan.md`, `README.md`,
`triage-external-review-2026-10.md`.

- `main.tex:849-851`: “the proof binds the admission to a specific committed
  tensor, and the manager ties the admission call to the validator”. La primera
  parte no ata al validador; la segunda solo ata el caller.
- `main.tex:86`: “bound to a validator identity”. No se sostiene.
- `implementation-plan.md:261`: “The `validator` argument is gone: with that
  statement it had no binding role”. El argumento sí tenía rol: atar el proof.
- `implementation-plan.md:333-336`: “double admission is impossible because
  `admit` requires `!isAdmitted[validator]`”. Cierto para la misma dirección;
  falso para direcciones nuevas con el mismo proof.
- `README.md:42`: “accrues to a validator's own verifiable history”. No con el
  proof global.
- `triage-external-review-2026-10.md:997` (N-5): “El binding ZK es
  validador↔declaración”. Es más fuerte que lo que el código hace; el proof es
  global.

**Remediación:** no editar estas frases todavía. Al cierre de la auditoría hay que
decidir si se corrige el código (preferible) o se rebaja la afirmación del paper.
Si se corrige el código, las frases pueden quedar; si no, hay que reescribirlas y
ampliar N-5.

### Addendum: el comentario de `IZKThresholdVerifier` está obsoleto

`IZKThresholdVerifier.sol:5-28` dice “There is no implementation yet (milestone
M3)” y describe la opción B (Pedersen + Bulletproofs + recursive SNARK) como el
diseño elegido. El repositorio ya tiene `Groth16Verifier` (M3) y el paper adopta
V3 directo, sin recursión (`main.tex:552-558`). La interfaz es correcta; su
comentario no. Es un problema de documentación para integradores, no de código;
se corrige junto con las frases de P-07.

---

## P-08 — Una clave de verificación degenerada certifica cualquier proof

**Severidad provisional:** Alta (crítica si el verificador instalado es
degenerado). **Estado:** Confirmado con PoC end-to-end.
**Ubicación:** `Groth16Verifier.sol:84-98,108-135,188-205`;
`Bn254.sol:85-88,138-154`.

### Qué hace el código

`Bn254.isInfinity` considera `(0, 0)` la identidad y `pushPair` **descarta en
silencio** cualquier par que contenga una identidad (`Bn254.sol:138-145`).
`Groth16Verifier._wellFormed` valida la clave empujando sus puntos al precompiled
de pairing, pero no exige que los puntos sean distintos de la identidad. Si todos
los puntos de la clave son `(0, 0)`, `_wellFormed` no escribe ningún par, `n == 0`
y devuelve `true` (`Groth16Verifier.sol:188-205`). El constructor sólo comprueba
`vk.ic.length != 0` y `_wellFormed` (`:84-86`), así que acepta una clave con
`alpha1 = beta2 = gamma2 = delta2 = (0,0)` y cuatro entradas `ic` a cero.

En `verify`, un proof con `a = b = c = (0,0)` tampoco escribe pares; `n == 0` y la
función devuelve `true` en `Groth16Verifier.sol:127-130`. El comentario dice que
ese camino “not reachable with a key that passed the constructor”; no es cierto:
la clave cero pasa el constructor.

### PoC ejecutada

`integrations/avalanche/test/TmpZeroVerifyingKey.t.sol` (temporal, borrado
después):

1. `new Groth16Verifier(zeroKey)` con `ic.length = 4` y todos los puntos a cero
   → el constructor no revierte.
2. `verify(0, 0, 0, [123, 456, 789])` → `true`.
3. Un `AVIPRegistry` con ese verificador, root génesis y `verifyThreshold(0,
   5e17, proof)` → `true`.
4. Un `AVIPValidatorManager` sin custody admite a un validador con un proof de
   256 bytes todo a cero.

Los 2 tests de clave cero pasaron. La PoC no depende de un mock: usa el
`Groth16Verifier` real y el precompiled de pairing del EVM.

#### Addendum: no hace falta que **toda** la clave sea cero

La misma causa (`pushPair` descarta identidades) permite una clave con puntos
reales salvo `gamma2 = (0,0)`. `_wellFormed` sigue devolviendo `true` porque el
par `(vk_x, gamma2)` se descarta y el resto de pares son válidos; el constructor
la acepta. En `verify`, un proof construido con `a = alpha1`, `b = beta2` y
`c = (0,0)` cancela `(-a,b)` con `(alpha1,beta2)`, descarta `(vk_x,gamma2)` y
`(c,delta2)`, y devuelve `true` para **cualquier** statement.

PoC temporal `TmpDegenerateGamma.t.sol` (borrada después): clave del fixture real
con `gamma2` a cero; `verify(alpha1, beta2, 0, [1,2,3])` → `true`. El test pasó.
Esto no es una variante teórica: la comprobación del constructor sólo mira que
el precompiled acepte los pares que quedan, y un `gamma2` identidad hace que el
statement desaparezca de la ecuación.

### Consecuencia

Si se instala un verificador con clave cero, **cualquier** proof y un
`certifiedNorm` arbitrario (mientras `collateralFor` no desborde) se aceptan;
combinado con P-01, cualquier dirección puede admitirse con el stake mínimo. El
script `DeployFujiPhase1` no instala verificador (`VERIFIER = address(0)`), así
que la fase 1 de Fuji no está afectada; M4b usa
una clave real. Pero `proposeVerifier` sólo rechaza `address(0)`, no una clave
degenerada, y el constructor se presenta como la validación de la clave. El
defecto es del wrapper, no de la ceremonia.

### Remediación propuesta (no implementada)

1. Rechazar la identidad en `alpha1`, `beta2`, `gamma2`, `delta2` y en cada
   `ic[i]` del constructor; exigir que `_wellFormed` haya empujado al menos un
   par.
2. Hacer que `verify` devuelva `false` (o revierta) cuando `n == 0`, en vez de
   `true`.
3. Añadir tests adversarios permanentes: clave toda cero, G2 a cero, `ic` a cero
   y una clave con `gamma2`/`delta2` identidad.
4. Si se quiere defensa en profundidad, que `AVIPRegistry.proposeVerifier`
   compruebe `code.length`, `numPublicInputs() == 3` y un digest conocido; no
   sustituye la validación de la clave, pero evita instalar una EOA o un
   contrato vacío.

---

## P-09 — Token de 0 decimales: un slash completo mueve cero unidades

**Severidad provisional:** Alta/media, condicionada al token desplegado.
**Estado:** Confirmado con PoC.
**Ubicación:** `AVIPStakeVault.sol:74-85,372-382`;
`AVIPValidatorManager.sol:249-262`.

### Qué hace el código

`WAD_PER_UNIT = 10 ** (18 - decimals)`. Para un token de 0 decimales vale `1e18`
y el constructor lo acepta porque `ONE % 1e18 == 0` (`AVIPStakeVault.sol:235-240`).
En `admit`, con custody configurada, se comprueba

```solidity
if (financialStake > escrowed) revert FinancialStakeNotBacked(...);
```

pero **no** se exige que `financialStake` sea múltiplo de `WAD_PER_UNIT` ni que
cubra al menos una unidad base (`AVIPValidatorManager.sol:258-263`). El validador
puede depositar una unidad entera (`escrowed = 1e18`), declarar
`0.7333...e18` (`S_f*` en `Θ_r = 0.5`) y quedar admitido: `0.7333e18 <= 1e18`.

En `slash`, el manager pone `_stakes = 0` y llama a
`custody.debit(validator, 0.7333...e18)`. En el vault,
`units = floor(0.7333e18 / 1e18) = 0`; el `if (units == 0) return;` sale **sin
transferir nada** (`AVIPStakeVault.sol:375-382`). El manager ya ejecutó la
eyección, así que `isAdmitted` es `false` y `withdrawable` devuelve todo el
escrow; el validador retira la unidad completa.

### PoC ejecutada

`TmpZeroDecimalSlashTest` (temporal, borrado después): token de 0 decimales,
vault con `WAD_PER_UNIT = 1e18`, depósito de 1 unidad, admisión con
`financialStake = 733_333_333_333_333_334`, slash del manager. Resultado:

- `stakeOf == 0` y `isAdmitted == false`;
- `sink.totalReceived == 0`;
- `escrowedUnits == 1`;
- tras `withdraw(1)`, el validador recupera su token entero.

### Matiz de alcance: `WAD_PER_UNIT` sólo se valida como divisor

El constructor comprueba `ONE % wadPerUnit == 0` (`AVIPStakeVault.sol:235-240`),
no que la escala sea `10 ** (18 - decimals)` ni que el token tenga 18 decimales o
menos. Un despliegue con `WAD_PER_UNIT = 2e17` (o `1` para un token de 19
decimales) pasa la comprobación y mis-precio todas las comparaciones. La
documentación dice que un token de más de 18 decimales “is refused”
(`AVIPStakeVault.sol:196-199`), pero el contrato no puede saberlo: la escala es
un input del operador y el script sólo la lee de vuelta
(`DeployStakeVault.s.sol:107-117`). Es un footgun de despliegue, no una segunda
vía de explotación del slash.

### Por qué importa

El boundary de redondeo está documentado (“a slash smaller than one base unit
moves nothing”), pero para un token de 0 decimales **todo** el stake mínimo del
paper (`0.2`–`0.733`) está por debajo de una unidad base: el redondeo no deja
“dust”, deja el slash entero sin efecto. `isBacked` sigue devolviendo `true`
porque la cobertura se mide en WAD, no en unidades embargables. El fee también
falla en ese token (`FeeRoundsToZero`), así que un despliegue de 0 decimales es
inutilizable; el problema es que el vault lo acepta y el manager lo admite sin
una comprobación de representabilidad.

### Remediación propuesta (no implementada)

1. Rechazar escalas en las que el stake mínimo no sea al menos una unidad base
   (por ejemplo, `WAD_PER_UNIT > 1e17`, o un límite derivado de `S_MIN`).
2. O exigir en `admit`, con custody, que `financialStake % WAD_PER_UNIT == 0` y
   que `financialStake >= WAD_PER_UNIT`.
3. O hacer que `debit` redondee hacia arriba y revierta si el importe no se puede
   representar, en vez de devolver silenciosamente sin mover fondos.
4. Añadir tests de regresión con 0, 1 y 6 decimales, incluyendo el caso
   “slash completo, cero unidades”.

---

## P-10 — El guardian puede proponerse a sí mismo como sequencer

**Severidad provisional:** Media (gobernanza).
**Estado:** Confirmado con PoC.
**Ubicación:** `AVIPRegistry.sol:125-131,156-169`;
`DeployRegistry.s.sol` (`RolesCollapsed`), `DeployFujiPhase1.s.sol`.

### Qué hace el código

El constructor sólo rechaza `guardian == address(0)`; no compara
`guardian` con `sequencer` (`AVIPRegistry.sol:125-131`). El plan lo justifica:
la separación de claves es una política de despliegue, no una propiedad que el
contrato pueda comprobar. Los scripts sí la comprueban: `DeployRegistry` y
`DeployFujiPhase1` revierten `RolesCollapsed` si `GUARDIAN == SEQUENCER`.

El problema es que `proposeSequencer` tampoco la comprueba en runtime:

```solidity
function proposeSequencer(address next) external onlyGuardian {
    if (next == address(0)) revert ZeroSequencer();
    ...
    pendingSequencer = next;
    sequencerChangeEta = eta;
}
```

(`AVIPRegistry.sol:156-169`). Acepta `next == guardian`. Tras `CHANGE_DELAY`,
`executeSequencerChange` es permissionless y cualquiera puede confirmar el cambio;
el guardian pasa a ser también el sequencer. La PoC temporal propuso
`guardian` a sí mismo, avanzó `CHANGE_DELAY` y ejecutó: `sequencer() == guardian`.

### Por qué importa

La propiedad que el despliegue dice cerrar —“one key that both writes commitments
and proposes its own continuation is not a second authority”— deja de ser cierta
en cuanto el guardian lo decide. No hace falta una clave comprometida: el propio
guardian puede concentrar los dos poderes. El delay de dos días sólo hace el
cambio observable; no hay veto on-chain del sequencer saliente ni de terceros.
Si el guardian es un multisig, esto es una decisión de gobernanza; si es una EOA,
es una captura silenciosa.

### Follow-up: `proposeVerifier` sólo comprueba que no sea cero

El mismo patrón aparece en la otra lane: `proposeVerifier` rechaza
`address(0)`, pero no exige `next.code.length > 0` ni que el verificador declare
tres public inputs. La interfaz `IZKThresholdVerifier` sólo expone `verify`
(`IZKThresholdVerifier.sol:31-43`); la comprobación tendría que ser un
`staticcall` a `numPublicInputs()` o un cast al `Groth16Verifier` concreto
(`Groth16Verifier.sol:137-145`). Un guardian que proponga una EOA o un contrato con
otra aridad deja `verifyThreshold` revertiendo durante `CHANGE_DELAY` y hasta
que se proponga y ejecute otra rotación. No es una captura —el guardian ya
puede instalar un verificador malicioso— pero sí un footgun de liveness que un
chequeo barato en `proposeVerifier`/`executeVerifierChange` cerraría.

### Remediación propuesta (no implementada)

1. Rechazar `next == guardian` en `proposeSequencer` (y, por simetría, valorar
   `next == address(this)`).
2. O declarar explícitamente que la separación es sólo un invariante de
   despliegue y retirar la afirmación de “dos autoridades” del plan/README.
3. Añadir un test runtime permanente: el guardian no puede proponerse a sí mismo
   como sequencer.
4. En `proposeVerifier`, comprobar código y aridad (`numPublicInputs() == 3`) o
   al menos rechazar una EOA; en `executeVerifierChange`, repetir la comprobación
   por si el contrato cambió entre propuesta y ejecución.

### Addendum: no hay rotación del guardian

`guardian` es `immutable` (`AVIPRegistry.sol:86`), sin setter ni propuesta de
rotación. Si la clave se pierde, no se puede rotar ni el sequencer ni el
verificador: el registry queda congelado en esos dos roles. Si se compromete, el
atacante puede proponer un sequencer/verificador malicioso y, tras
`CHANGE_DELAY`, ejecutarlo; el sequencer saliente no tiene veto on-chain y
`cancel*` sólo lo puede llamar el propio guardian comprometido. El delay hace el
cambio observable, pero no hay una segunda autoridad que lo impida.

No es un bug de código: es el precio de que la autoridad no pueda reescribirse a
sí misma. La respuesta a una pérdida/compromiso es un **procedimiento de
despliegue** (nuevo registry y migración de historia), no una propiedad del
contrato. Severidad operacional Media; debe estar en el runbook y en la lista de
limitaciones, no presentarse como “rotación resuelta”.

---

## P-11 — `requiredStake` queda obsoleto tras una eyección

**Severidad provisional:** Baja (vista/off-chain).
**Estado:** Confirmado con PoC.
**Ubicación:** `AVIPValidatorManager.sol:194-196,306-311`;
`IAVIPValidatorManager.sol:121-123`.

### Qué hace el código

`_requiredStakes` sólo se escribe en `admit` (`AVIPValidatorManager.sol:278`).
`slash` incrementa `_ejections` (`:310`) pero **no** actualiza
`_requiredStakes`. Por tanto, después de una eyección y antes de la
re-admisión, `requiredStake(v)` devuelve la imagen antigua `S_f*(r)` sin el
nuevo `κ`, mientras que el siguiente `admit` cobra
`requiredStakeFor(norm) + ejections * κ` (`:249-250`). La interfaz promete que
`requiredStake` es “the stake a re-admission has to post”
(`IAVIPValidatorManager.sol:121-123`); entre la eyección y la re-admisión no lo
es.

La PoC temporal, tras el slash, comprobó:

```text
requiredStake(v) == requiredStakeFor(5e17) < requiredStakeFor(5e17) + κ
```

No hay exploit on-chain: `admit` recalcula el requirement desde `_ejections`, así
que el cobro es correcto. El defecto es de la vista y de sus consumidores
off-chain (UI, keeper, monitorización, scripts de reporte).

### Remediación propuesta (no implementada)

1. En la eyección, incrementar también `_requiredStakes[validator]` en
   `EJECTION_SURCHARGE` (la imagen antigua + el nuevo `κ`), o
2. cambiar el nombre/semántica de la vista a “requirement de la última admisión”
   y exponer una vista separada que sume el surcharge pendiente.
3. Añadir un test que compare `requiredStake` con
   `requiredStakeFor(norm) + ejectionsOf(v) * EJECTION_SURCHARGE` después de
   cada eyección, no sólo después de la re-admisión.

---

## P-12 — La freshness `γN` se comprueba sobre un delta declarado, no sobre el tensor

**Severidad provisional:** Media (confianza/overclaim).
**Estado:** Confirmado con PoC y por lectura.
**Ubicación:** `AVIPRegistry.sol:251-275`;
`src/datalayer/src/commitment.rs:205-231`.

### Qué hace el código

`postCommitment(epoch, root, changedEntries)` sólo comprueba que
`changedEntries <= MAX_DELTA_ENTRIES` (50) y que el epoch sea secuencial
(`AVIPRegistry.sol:260-267`). El `root` es un argumento arbitrario del
sequencer; el contrato no guarda el tensor ni recibe pruebas de las hojas que
cambiaron, así que no puede comprobar que el número declarado corresponda al
root nuevo.

El data layer sí sabe calcularlo: `Epoch::changed_entries` compara dos mapas de
`Entry` y `Epoch::freshness_ok` aplica `<= 50`
(`src/datalayer/src/commitment.rs:201-231`), pero esa comprobación es
**off-chain**. `adjudicate` sólo compara una hoja publicada con `f_c(events)`
(`src/datalayer/src/ingestion.rs:251-268`); no cuenta las hojas cambiadas ni
prueba el delta. `AVIPMessageCodec.decodeCommitment` tampoco acota
`changedEntries` (`AVIPMessageCodec.sol:281-293`), así que el valor viaja sin
verificación al relay.

### PoC ejecutada

`TmpFreshness.t.sol` (temporal, borrado después): se postea un root génesis y
después un root **completamente distinto** con `changedEntries = 0`. Ambas
llamadas pasan; `changedEntriesOf(1) == 0` y `latestEpoch() == 1`. El test pasó.

### Consecuencia

Un sequencer comprometido o con un bug puede cambiar las 500 entradas y declarar
`0` (o `50`), y el registry lo acepta. La frase del paper “two consecutive epochs
cannot differ in more than `γN` entries” (`main.tex:1000`) describe una
propiedad que el contrato no hace cumplir; el comentario del propio registry lo
reconoce (`AVIPRegistry.sol:21-26`). Esto debilita el bound de latencia de
detección `k` que usa la condición de deterrence (`main.tex:1068-1075`) y la
propagación del relay. No es una segunda vía para que un tercero postee: sigue
siendo el rol `sequencer`, pero la confianza declarada es mayor de lo que el
paper sugiere. **P-21 añade que, incluso si el delta se enforceara, `γ` no acota
la duración de una hoja fraudulenta que no cambia.**

### Addendum: el data layer tampoco fija `N` ni la unicidad

`Epoch::new` acepta cualquier `Vec<Entry>` y `changed_entries` construye un
`BTreeMap` por validador (`src/datalayer/src/commitment.rs:141-143,205-220`).
Eso tiene dos consecuencias que la comprobación off-chain no cubre:

- un epoch con **501 hojas** y una dirección repetida tiene 500 claves en el
  mapa, así que el caso génesis (`previous.entries.is_empty()`) ve
  `changed == TENSOR_SIZE` y `freshness_ok` devuelve `true`, aunque el root
  comprometa 501 hojas;
- un epoch con 1.000 hojas, cada una de las 500 direcciones repetida con la
  misma norma, tiene `changed == 0` respecto del anterior y pasa `<= 50`; el
  mapa oculta las hojas duplicadas y también una segunda norma para la misma
  dirección.

El contrato no puede detectarlo porque sólo recibe `(root, changedEntries)`
(P-12); el data layer *sí* podría, y no lo hace. No es una vía nueva de ataque
—el sequencer ya puede declarar `0`— pero sí muestra que `freshness_ok` no es
la comprobación que su comentario dice ser: no impone `entries.len() == N` ni
la unicidad de `validator`. La corrección es barata: validar ambas cosas en
`Epoch::new` (o al principio de `freshness_ok`) y añadir un test de 501 hojas
con un duplicado y otro de 1.000 hojas duplicadas.

### Remediación propuesta (no implementada)

1. Exigir una prueba on-chain del conjunto cambiado (por ejemplo, pruebas de
   inclusión de las hojas nuevas y de las antiguas, o un compromiso del delta),
   no un contador declarado.
2. O declarar explícitamente en paper/plan que `changedEntries` es una
   atestación del sequencer y que la freshness es una obligación off-chain; en
   ese caso, acotar también el campo en `AVIPMessageCodec`/relay.
3. Añadir un test que postee dos roots con delta declarado 0 y demuestre que el
   contrato no puede distinguirlos; el test actual sólo comprueba el rango del
   número declarado (`AVIPRegistry.t.sol:108-125`).
4. En el data layer, rechazar `entries.len() != TENSOR_SIZE` y validadores
   repetidos antes de calcular el root o la freshness; cubrirlo con los dos
   casos del addendum.

---

## P-13 — `Groth16Verifier` acepta `certifiedNorm + r`: el public input no es canónico

**Severidad provisional:** Baja/media (latente).
**Estado:** Confirmado con PoC.
**Ubicación:** `Groth16Verifier.sol:108-135,176-182`;
`Bn254.sol:117-132`; `AVIPValidatorManager.sol:173-184`.

### Qué hace el código

`Groth16Verifier.verify` no comprueba que cada `publicInputs[i]` sea un elemento
canónico del cuerpo (`< r`, el orden del grupo BN254). `_vkX` pasa el valor
directamente a `Bn254.ecMul`, que ejecuta el precompiled `0x07`; la
multiplicación escalar reduce el escalar módulo `r`. Por tanto, un proof válido
para `certifiedNorm = c` también verifica para `c + k·r`.

La PoC temporal `TmpNormMalleability.t.sol` (borrada después) usó el proof real
de `M4bGroth16Fixtures`:

- `verifier.verify(..., statement con certifiedNorm + r)` → **true**;
- `registry.verifyThreshold(0, certifiedNorm + r, proof)` → **true**;
- `manager.admit(..., certifiedNorm + r, ...)` → revierte con **panic de
  overflow**, no con un error de política.

El manager se salva hoy por accidente: `collateralFor` calcula
`CR_INF * norm` (`AVIPValidatorManager.sol:175-177`) y, con `norm ≈ r ≈ 2.19e76`,
ese producto desborda `uint256` antes de llegar a comparar el stake. Si esa
aritmética se cambia a `mulDiv`, a un tipo más ancho o a `unchecked`, el mismo
proof permitiría declarar una norma enorme y pagar `S_MIN` en lugar de
`S_f*(c)`.

### Consecuencia

El contrato del verificador no cumple la invariante que el registry y el manager
asumen (“certifiedNorm es la norma exacta”): acepta una representación distinta
del mismo elemento. Hoy el único consumidor on-chain (el manager) bloquea el
caso por overflow, y el caso no permite saltarse `Θ_r` en `admit`; por eso la
severidad es baja/media y latente. Sí es un **DoS** de `admit`/vistas para una
norma enorme y una violación de la API pública `verifyThreshold`.

### Remediación propuesta (no implementada)

1. En `AVIPValidatorManager`, exigir `certifiedNorm < 2^64` (o `<= MAX_NORM`)
   antes de `collateralFor`; el circuito ya usa `CERTIFIED_BOUND_BITS = 64`
   (`native.rs:116-120`).
2. En `AVIPRegistry.verifyThreshold`, aplicar el mismo bound o canonicalizar el
   input antes de construir el statement.
3. Si se quiere una verificación genérica, rechazar los public inputs no
   canónicos que no sean el `root` (que es un `bytes32` y puede necesitar una
   representación propia); no basta con “el precompiled lo reduce”.
4. Test permanente: el mismo proof con `c + r` debe devolver `false` (o revertir
   con un error de rango), y `admit` debe rechazarlo por política, no por panic.

### Addendum (tercera lectura): el `root` también es un escalar

El informe externo confirma la reducción de escalares y añade un caso que P-13 no
mencionaba: `root` es un `bytes32` que el registry construye como
`statement[0] = uint256(root)` (`AVIPRegistry.sol:342-345`). `Bn254.ecMul` reduce
cualquier escalar módulo `r`, y `Groth16Verifier` no exige `publicInputs[i] < r`;
por tanto `root` y `root + r` (cuando caben en 256 bits) son el mismo public
input. El `postCommitment` acepta cualquier `bytes32`, así que la representación
no es canónica tampoco para el root.

No es una vía de robo por sí sola —el sequencer elige el root y el binding al
tensor es off-chain (P-16)—, pero sí una violación de la API que el registry
presenta como “el root exacto”. La remediación de P-13 debe incluir:

1. `publicInputs[i] < r` para todos los inputs, no sólo `certifiedNorm`; y
2. `uint256(root) < r` en `postCommitment` y/o en `verifyThreshold`, o una
   codificación canónica explícita del root.

`Bn254.decodeProof` sí comprueba las coordenadas `< p`; eso no cubre los
escalares. El test de `c + r` debe ampliarse a `root + r` y a `epoch + r`.

### Addendum (2026-10-22): el punto 2 está implementado para `certifiedNorm`

`AVIPRegistry.verifyThreshold` rechaza `certifiedNorm >= 2^64` con
`NormOutOfDomain(uint256)` antes de decodificar el blob
(`AVIPRegistry.sol`, constante `MAX_NORM = 1 << 64`). El bound no es `< r`: es el
de `CERTIFIED_BOUND_BITS = 64` (P-04), porque lo que se defiende es que la
palabra sea *una norma codificable* y no un representante cualquiera del mismo
escalar. Con eso caen `c + k·r` y también la banda negativa que la cota de una
sola cara de P-33 admitía. Test:
`test/M4dRealKey.t.sol::test_aNormTheFrameworkCannotEncodeIsRejected` (los puntos
1 y 4 del listado siguen pendientes: el manager aún no acota por política, y
`root`/`epoch` no tienen guard).

---

## P-14 — `AVIPSlashingChannel` descarta la procedencia del fraude al ejecutar

**Severidad provisional:** Baja.
**Estado:** Confirmado por lectura.
**Ubicación:** `AVIPSlashingChannel.sol:70-77,166-188`;
`AVIPMessageCodec.sol:121-146`.

### Qué hace el código

El payload de tipo 3 lleva `validator`, `epoch`, `ingestionDigest`,
`publishedWad` y `formulaWad` (`AVIPMessageCodec.sol:140-146`).
`AVIPSlashingChannel._deliver` lo decodifica y valida, pero después:

- solo escribe `_reasonOf[sourceChain][nonce] = reason`;
- incrementa `executedSlashes`;
- llama a `MANAGER.slash(notification.validator, reason)`;
- emite `SlashingExecuted(sourceChain, nonce, validator, reason)`.

El evento del destino (`AVIPSlashingChannel.sol:70-77`) **no incluye** `epoch`,
`ingestionDigest`, `publishedWad` ni `formulaWad`, y no hay storage para ellos.
El emisor sí los emite en `SlashingNotified` (`:60-68`), y el comentario del
codec dice que el subnet “records which formula was applied”
(`AVIPMessageCodec.sol:30-52`). El destino no lo registra: sólo guarda un
`reason` que identifica `(sourceChain, nonce)`.

### Consecuencia

La cadena que ejecuta el slash no puede reconstruir desde su propio estado qué
epoch, qué instancia de `f_c` ni qué par published/formula motivaron la
ejecución; tiene que ir al evento de la cadena origen y correlacionarlo por
`nonce`. No se pierden fondos ni se puede slashear dos veces por el mismo
`reason`, pero se pierde la trazabilidad que el contrato dice conservar. Es un
defecto de auditoría/observabilidad, no de custody.

**No confundir con P-34.** P-14 es que el destino *guarda poco*; P-34 es que el
destino *cree sin verificar*. La primera es observabilidad; la segunda es la
confianza que permite que un `NOTIFIER` comprometido mueva el stake entero. Se
arreglan juntas, pero no son el mismo hallazgo.

### Remediación propuesta (no implementada)

1. Incluir `epoch`, `ingestionDigest`, `publishedWad` y `formulaWad` en
   `SlashingExecuted` y/o en un struct consultable por `(sourceChain, nonce)`.
2. O corregir la documentación del codec y del canal para decir que el destino
   sólo registra el `reason` y que los detalles viven en el evento origen.
3. Test que lea el evento del destino y compruebe que los cinco campos del
   payload están presentes (si se implementa 1).

---

## P-15 — `AVIPBurnSink.receiveFunds` es permissionless y contradice su propia nota

**Severidad provisional:** Baja/informativa.
**Estado:** Confirmado con PoC.
**Ubicación:** `AVIPBurnSink.sol:30-35,66-82`.

### Qué hace el código

`receiveFunds(amount, reason)` es `external` sin control de caller. Comprueba
que el sink tenga `amount` y llama a `TOKEN.burn(amount)`; cualquiera puede
invocarlo. La nota del contrato dice que los tokens enviados por otra vía “are
not burned, not counted in `totalBurned` and not swept”
(`AVIPBurnSink.sol:30-35`), pero un tercero puede llamar a `receiveFunds` con
ese balance no reclamado y quemarlo, incrementando `totalBurned`.

### PoC ejecutada

`TmpBurnSink.t.sol` (temporal, borrado después): se mintean `1e18` tokens
directamente al sink; una dirección `attacker` llama a
`receiveFunds(1e18, ...)`; el burn se ejecuta, el balance del sink queda a cero
y `totalBurned() == 1e18`. El test pasó.

### Consecuencia

No hay robo: los tokens enviados al sink ya no tienen una función de salida y
quedan atrapados. El impacto es que un tercero puede quemar tokens que el
usuario quizá envió por error, y que `totalBurned` deja de ser un contador
exclusivo del vault. Si el sink se usa con un token cuyo `burn` tiene efectos
externos, el llamante elige cuándo dispararlos. Es informativo para el despliegue
de referencia, no un fallo de custodia del vault.

### Remediación propuesta (no implementada)

1. Restringir `receiveFunds` al vault (con un one-shot bind como el de
   `AVIPStakeVault`, o un constructor que reciba la dirección del vault), o
2. mantenerlo permissionless y corregir la nota para decir que cualquier caller
   puede quemar el balance no reclamado, o
3. añadir un test que documente el comportamiento y evitar que se presente como
   “unsolicited tokens are not burned”.

---

## P-16 — Un solo slot de root para dos compromisos incompatibles (Poseidon vs keccak)

**Severidad provisional:** Crítica (bloquea v1 que pretenda admisión y fraud
proof a la vez).
**Estado:** Confirmado con PoC ejecutable y por lectura.
**Ubicación:** `AVIPRegistry.sol:269,278-280,342-345`;
`AVIPCommitmentRelay.sol:162-173`; `M4bRealKey.t.sol:124`;
`M7dTransport.t.sol:310,318`; `main.tex:552`.

### Qué hace el código

`postCommitment` guarda **un** `_roots[epoch]` (`AVIPRegistry.sol:269`).
Ese único valor se usa con dos funciones de hash incompatibles:

- `verifyThreshold` lo pasa como `statement[0]` al Groth16 de V3; el circuito
  compromete el tensor con **Poseidon** (`AVIPRegistry.sol:342-345`,
  `src/zk/src/native.rs:206-247`).
- `verifyEntry` lo usa como raíz de un árbol **keccak256** con hojas
  `keccak256(abi.encodePacked(leaf))` y pares ordenados
  (`AVIPRegistry.sol:303-317`).
- `commitmentOf` devuelve ese mismo valor, y `AVIPCommitmentRelay.publish` lo
  etiqueta como `merkleRoot` (`AVIPCommitmentRelay.sol:162-173`).

No hay dos slots ni un compromiso que ligue ambos. El fixture M7c demuestra que
las dos raíces del **mismo** tensor son distintas:

```text
MERKLE_ROOT   = 0x187d08e633fb4f3895633e6d3be1075f9603923adb6d70c09f27b458c3917537
STATEMENT_ROOT = 14881564148789680950073164612164838307833922018127128489011700125541095929892
```

`M4bRealKey.t.sol:124` postea el valor Poseidon como `commitmentOf(0)` para que
la admisión funcione; `M7dTransport.t.sol:310,318` evita el conflicto usando **dos
registries** (`registryForCommitment` y `registryForAdmission`). Ese workaround es
la prueba de que un solo registro no puede con las dos.

### PoC ejecutada

`integrations/avalanche/test/TmpRootConflict.t.sol` (temporal; fuente original
perdido, reconstrucción ejecutable en
`docs/audit/evidence/2026-10-20-pocs/pocs/reconstructed/TmpRootConflict.t.sol`):

1. Postea `F7c.MERKLE_ROOT` y llama `verifyThreshold` con el proof real de M4b:
   devuelve **false**, porque el statement espera el root Poseidon.
2. Postea `bytes32(F7c.STATEMENT_ROOT)` y `verifyThreshold` devuelve **true**,
   pero `commitmentOf(0) != F7c.MERKLE_ROOT`.

Ambos tests pasaron. El relay no puede arreglarlo: `publish` lee
`REGISTRY.commitmentOf(epoch)` y lo llama `merkleRoot`; si el registro guarda el
root Poseidon, el relay propaga un “merkleRoot” que no es la raíz de M1. El link
off-chain de M7c liga dos palabras, pero **no hay ningún contrato que las guarde
juntas**.

### Consecuencia

- Si el registro guarda Poseidon (necesario para admitir), `verifyEntry` no puede
  validar las hojas del tensor (salvo una colisión de keccak) y el relay etiqueta
  mal la raíz: el fraud proof de M1 se queda sin raíz on-chain.
- Si guarda keccak (necesario para `verifyEntry` y para el relay), la admisión
  V3 no verifica (salvo que ambas raíces coincidan, que es el caso de colisión)
  y nadie puede entrar.
- La limitación del paper (“the tie is off-chain”, `main.tex:552,1444`) describe
  una confianza, no esta colisión de estado: el propio relay sólo puede publicar
  una de las dos raíces porque lee una sola ranura.
- Es más fuerte que P-03 (tres semánticas de `T`) y que P-12 (delta declarado):
  aquí no hay una representación incorrecta, hay **dos representaciones que el
  mismo campo no puede contener**.

### Remediación propuesta (no implementada)

1. Dos raíces por época: `merkleRootOf(epoch)` y `statementRootOf(epoch)`.
   `postCommitment(epoch, merkleRoot, statementRoot, changedEntries)`; el
   `verifyEntry` usa la primera, `verifyThreshold` la segunda y el relay publica
   ambas. Migrar fixtures, tests y el reporte M7d.
2. O adoptar la Opción A′ (un árbol Poseidon que sirva a la norma y a las
   inclusiones) y cambiar `verifyEntry` a Poseidon; hoy sería caro on-chain y
   obliga a revisar el gas.
3. O retirar una de las dos funciones de v1 y borrar la afirmación
   correspondiente del paper/plan/README.
4. Test permanente, según la opción elegida: si se mantienen **dos** raíces,
   postear ambas y exigir `verifyEntry` y `verifyThreshold` verdaderos, con el
   relay registrando `merkleRoot == MERKLE_ROOT`; si se adopta **una** raíz
   Poseidon, exigir que `verifyThreshold` y `verifyEntry` acepten la misma raíz
   y que el relay no la etiquete como keccak. El test debe fallar si se vuelve a
   usar un solo slot para dos hashes.

### Diseño conjunto con P-01 (no implementado)

El arreglo correcto es **un compromiso por validador con una sola raíz canónica
on-chain y el validador ligado dentro del circuito**. No vale añadir `validator`
al array de Solidity manteniendo el tensor global: sería una etiqueta sin
relación aritmética con la norma.

La forma recomendada es un árbol Poseidon sobre hojas
`leaf_v = H(validator_v, norm_v)` (o `H(validator_v, leaf_index)` si la norma va
en otra hoja). El statement público pasa a
`[root, epoch, validator, certifiedNorm]`; la ruta de Merkle y el índice son
privados. El circuito debe constrañear, en una sola relación:

1. `leaf_v` está en `root` bajo el índice privado;
2. la hoja corresponde al `validator` público;
3. `certifiedNorm` es la norma de esa hoja, no la de otra;
4. la norma satisface el floor y `epoch` está atado al root.

Si `verifyEntry` **no** está en la ruta de slash —el paper dice que el adjudicador
rederiva `f_c` off-chain—, la opción más simple es dejar la raíz Poseidon como
única on-chain y mantener keccak sólo off-chain. Si se quiere conservar
`verifyEntry` on-chain, hay que usar la **misma** raíz Poseidon y aceptar el coste
de la prueba de inclusión; dos raíces por época es la otra alternativa, pero
entonces ya no hay “una sola raíz canónica”. La decisión de retirar
`verifyEntry` de v1 es de alcance, no criptográfica.

**Checklist de revisión del nuevo statement, antes de implementarlo:**

- `ic.length == nPublic + 1` y la entrada de `validator` tiene una
  `gamma_abc_g1` distinta de la identidad. Una entrada no usada verifica
  cualquier valor y el test de mutación no la detecta si sólo se cambia el array
  de Solidity.
- Mutar sólo `validator`, sólo `root`, sólo `epoch` o sólo `certifiedNorm` debe
  dar `false`; el mismo proof con dos validadores debe fallar en el segundo.
- El circuito no debe aceptar una hoja de otro validador ni un índice fuera del
  árbol; hay que atar el índice privado a la posición de la hoja.
- La dirección debe representarse como un elemento de 160 bits sin aliasing en
  el campo (bits altos a cero); si se convierte a `Fr` sin esa comprobación, dos
  direcciones distintas pueden colisionar. El test de mutación de `validator`
  debe cubrir una dirección que sólo difiera en los bytes altos, incluido el byte
  más significativo.
- Dirección cero y normas fuera de rango deben rechazarse dentro del circuito, no
  sólo en el manager. En particular, la norma de la hoja debe cumplir
  `norm ≤ WAD` **por entrada**; el límite global `< 2^64` no sustituye esa cota
  (P-33).
- Un test con la proof real (`M4bGroth16Fixtures`) y otro con el fixture de dos
  raíces; no basta el mock.

**Ventana de época (P-32).** El nuevo `admit` debe recibir `epoch` y comprobar
`epoch <= latestEpoch()` y `epoch + WINDOW >= latestEpoch()`, además de
`epoch > lastAdmittedEpoch[validator]`, con un flag `hasAdmitted` para no
bloquear el génesis `epoch = 0`. Sin el `validator` público de P-01, la ventana
sería reutilizable por otro validador y el `lastAdmittedEpoch` no tendría sujeto.
Si no se implementa la ventana, el README y el paper deben decir que la admisión
depende de que el sequencer no publique durante el proving (3,9 s medidos), en
vez de presentar la prueba como fresca.

**Métricas que el rediseño invalida.** Cambiar el statement cambia
`ic.length` y la verifying key. Hay que recompilar y remedir, como mínimo:
94.438 constraints, 3,9 s de proving, 128 B de proof (256 B on-chain),
206.000/223.403/286.144 gas, la Tabla 4.2, las filas del README, los fixtures
M4b/M7c/M7d, el ratio **2,39×** (`684.064 / 286.144`, con `G` canónico) y el
break-even **781 gwei**. No se debe volver a citar el 3,3×/1.085 gwei: sólo se
reproduce con la clave inline de 206k. Si se reporta la admisión completa, el
par es `376.588` gas y `594 gwei` (1,82×) y ambos lados deben tener el mismo
alcance. El anchor cubre `main.tex`; hasta re-anclar, el ancla y el recibo OTS
quedan inválidos para la nueva versión. **No se debe publicar en arXiv con las
cifras viejas ni presentar el rediseño como un cambio menor.**

---

## P-17 — La admisión se evalúa una vez; el decaimiento no reprecio ni expulsa

**Severidad provisional:** Alta.
**Estado:** Confirmado por lectura; no hay función de recertificación.
**Ubicación:** `AVIPValidatorManager.sol:225-282,287-323`;
`main.tex:793,798,849,1057,1188`.

### Qué hace el código

`admit` escribe `_admitted = true`, `_stakes[validator] = financialStake` y
`_requiredStakes[validator] = stake` (`AVIPValidatorManager.sol:276-278`). No
hay expiración, no hay `recertify`, no hay reprice y `admit` revierte
`AlreadyAdmitted` para la misma dirección (`:235`). `deposit` del vault aumenta
el escrow, pero **no** cambia `_stakes`; no existe un `topUp` que reprecie el
stake on-chain.

`slash` pone `_stakes[validator] = 0`, expulsa e incrementa `_ejections`
(`:293-311`), pero no escribe ninguna reputación. El paper lo dice: “it writes no
reputation state” (`main.tex:1057`). La única vía de salida del set admitido es
el slash; no hay salida voluntaria ni re-evaluación.

El paper cita el decaimiento de reputación como defensa contra colusión
(`main.tex:793,798`) y dice que un validador por debajo del umbral “cannot
produce a valid proof” (`main.tex:849`). Eso es cierto para una **nueva**
admisión, pero un validador ya admitido sigue siéndolo aunque su norma caiga por
debajo de `Θ_r`: el manager no vuelve a llamar a `verifyThreshold` ni actualiza
`_stakes`.

### Consecuencia

Un validador puede entrar con una norma alta y un stake bajo, dejar de
contribuir (o ser objeto de un tensor que decae), y conservar la admisión y el
descuento indefinidamente. El “decay” que §5/§10 presentan como segunda defensa
es una propiedad del proceso off-chain, no del estado on-chain. Es distinto de
P-01: incluso un proof correctamente atado al validador queda obsoleto después
de la admisión.

### Remediación propuesta (no implementada)

1. Admisión con época y caducidad: `admit(epoch, ...)` válido hasta
   `epoch + N`; al caducar, el validador debe re-admitirse con un proof fresco.
2. O `recertify(validator)` permissionless que compruebe el epoch actual con
   `verifyThreshold`, actualice `_stakes`/`_requiredStakes` y expulse si la norma
   cae por debajo de `Θ_r`; con un periodo de gracia y un evento.
3. O declarar explícitamente que la admisión v1 es permanente y retirar el
   decaimiento como defensa on-chain del paper/plan.
4. Tests: admisión con norma alta, epoch siguiente con norma baja, y comprobar
   que el estado on-chain no cambia; si se implementa 1/2, comprobar la expulsión
   y el reprecio.

### Addendum (tercera lectura): “sin salida honesta” es la otra cara de P-17

El informe externo presenta como hallazgo separado que `AVIPValidatorManager`
sólo tenga `admit` y `slash`, y que `AVIPStakeVault.withdraw` esté limitado a lo
que excede `ceil(stakeOf)` para un validador admitido. Es correcto, pero **no es
un ID nuevo**: P-17 ya registra que no hay salida voluntaria ni recertificación,
y el paper lo declara en §Limitations:

> “the manager exposes no exit, and the custody vault caps a withdrawal at the
> escrow above the stake on record ... the only way out of the admitted set is
> the slash itself” (`main.tex:1379`).

La consecuencia económica que el informe añade es válida: el *IR* de §2.5 es
ex-ante (el validador decide entrar con un stake descontado), pero no hay un
*IR* ex-post que le permita salir; la única salida es perder el stake. Eso no
separa a P-17 de P-34, pero sí obliga a que cualquier `exit` futuro se secuencie
con la ventana de adjudicación, como el propio paper dice. El criterio de cierre
de P-17 se amplía: o se implementa `recertify`/`exit` con cola, o se declara que
la admisión es permanente y el IR es sólo de entrada.

**Severidad del sub-hallazgo:** la parte «no hay salida honesta» es
**Informativo**, no Media: el paper ya la declara en `main.tex:1379` y el
contrato hace exactamente lo que el texto dice. P-17 sigue **Alta** por la parte
que el paper **no** declara: la admisión no se recalcula, el decaimiento no
reprecia y el slash no escribe reputación. Esa distinción evita presentar como
overclaim lo que sólo es una limitación reconocida, sin rebajar el hallazgo
principal.

---

## P-18 — El bounty `B` no tiene ruta de pago

**Severidad provisional:** Media (gap modelo/implementación; el paper lo declara
parámetro de modelo).
**Estado:** Confirmado por lectura.
**Ubicación:** `main.tex:1003,1371`; `AVIPBurnSink.sol:8-35`;
`AVIPStakeVault.sol:390-416`; contratos (grep `bounty` = 0).

### Qué hace el código

Ningún contrato menciona `bounty`. El slash del manager llama a
`custody.debit`, que transfiere a `SINK` y llama `SINK.receiveFunds`
(`AVIPStakeVault.sol:390-392`); `payFee` transfiere la fee directamente al
`SINK` (`:411-416`). El sink de referencia **quema** lo que recibe
(`AVIPBurnSink.sol:66-82`). No hay un pool, una recompensa al reportero ni una
dirección que pague `B`.

El paper es explícito: “Both the bounty `B` and the slashing penalty
`S_slash` are model parameters ... the delivered data layer adjudicates and
reports, and does not move funds” (`main.tex:1003`), y §10.2 repite que el
bounty asume auditores racionales (`:1371`). Por eso no es una afirmación falsa
del paper, pero sí un **lazo de incentivos no entregado**: `n*(B) = ⌊B/B*⌋`
supone que alguien paga `B`, y en el stack desplegado el slash y la fee se
queman.

### Consecuencia

La capa de datos puede detectar y reportar, pero el auditor honesto no cobra; el
`B` del equilibrio queda como parámetro externo sin fuente de fondos. Si v1 se
presenta como “data layer con deterrence ejecutable”, esto bloquea esa
afirmación; si se presenta como modelo condicional, es una limitación que debe
estar también en el README y en el plan, no sólo en §10.2.

### Remediación propuesta (no implementada)

1. Repartir el slash (o una fracción de la fee) entre el reportero y el sink;
   añadir un `bountyPool`/`claim` con prueba de adjudicación y evitar el doble
   pago por el mismo `(sourceChain, nonce)`.
2. O mantener el burn y declarar que v1 no paga bounty; en ese caso, quitar
   `n*(B)` de las afirmaciones de entrega y dejar sólo el modelo condicional.
3. Test: un adjudicate + slash real debe pagar `B` al reportero una sola vez; el
   sink recibe el resto.

---

## P-19 — El agregador Frobenius premia una sola celda y no mide historial

**Severidad provisional:** Media (diseño económico).
**Estado:** Confirmado por cálculo.
**Ubicación:** `main.tex:59,335,465,867`;
`AVIPValidatorManager.sol:173-184`.

`r = ||T||_F` y `C_R(r) = 0.8 r/(1+r)`. Con una sola celda a `0.5` y las otras
499 a cero, `r = 0.5`, se pasa `Θ_r = 0.5` y se obtiene
`C_R = 0.2667`: stake `0.7333`, **26,67 %** de descuento. Con una sola celda a
`1.0`, `r = 1`, `C_R = 0.4`: **40 %** de descuento. Las 500 celdas a
`0.02236` dan el mismo `r = 0.5` y el mismo descuento que una sola celda a 0.5.

La norma de Frobenius no distingue amplitud (cuántas celdas), profundidad
(cuántos horizontes) ni continuidad temporal; sólo la magnitud cuadrática. El
paper habla de “a long history of contributions” (`main.tex:59`) y de un tensor
`20×5×5`, pero el agregador no exige que el historial sea largo: una celda basta
para el umbral. No es un bug de código; es una debilidad del diseño económico y
de la afirmación de “historial”.

### Remediación propuesta (no implementada)

1. Usar una estadística que exija amplitud: mínimo por dominio, media por celda,
   norma L1 normalizada, entropía o un mínimo de celdas no nulas por horizonte.
2. O hacer `Θ_r` por celda/por horizonte y combinar con la norma global.
3. Si se mantiene Frobenius, rebajar la frase de “long history” a “magnitud
   agregada” y documentar que una celda puede satisfacer el umbral.

---

## P-20 — §2.4: los momentos estacionarios son el límite `λ = 0`, no el proceso con saltos

**Severidad provisional:** Alta (paper).
**Estado:** Confirmado con cálculo y simulación propia.
**Ubicación:** `main.tex:238-272`;
`verification/stochastics/stationary_stats.py:37-50`.

`stationary_stats.py` simula el CIR **sin saltos**:

```python
R = R + alpha * (rbar - R) * dt + sigma0 * sqrt(R) * sqrt(dt) * Z
```

La tabla de `main.tex:255-268` se titula “stationary moments of the
multiplicative specification” y el texto presenta `Gamma(k, θ)` como la ley
estacionaria del proceso definido en §2.2, que **sí** tiene saltos multiplicativos
(`main.tex:134-141`). No es la misma ley.

Para el proceso con saltos, la media estacionaria resuelve

```text
α(R̄ − m) − λ(1 − E[y]) m = 0
m = αR̄ / (α + λ(1 − E[y]))
```

Con `λ = 0.8` y `E[y] = 0.85` (salto determinista `y = 0.85`, como en
`cr_ide_solver.py:44`), los dos regímenes dan **0,80645** y **0,94340**, no
`1.0`. Mi simulación (20.000 paths, `dt = 0.005`, `T = 50`, burn-in 50 %) dio
**0,80661** y **0,94339**. La tabla actual (`0.998296` y `1.000062`) reproduce
sólo el límite `λ = 0`; la varianza y el KS contra Gamma tampoco son válidos con
saltos.

### Remediación

1. Etiquetar la tabla y el KS como “CIR sin saltos (`λ = 0`)”, igual que ya se
   hace con el MFPT en `main.tex:209`; o
2. simular el proceso completo, derivar los momentos con saltos (la varianza no
   es la Gamma de CIR) y rehacer la tabla, los Z-scores de `R_0 = 2.2` y el KS.
3. Añadir un test que compare la media empírica con `αR̄/(α+λ(1−E[y]))` para
   `λ = 0.8`, no con `R̄`.

---

## P-21 — §7.5: `γ` acota entradas cambiadas, no la duración del fraude

**Severidad provisional:** Alta (paper).
**Estado:** Confirmado con la fórmula del propio paper.
**Ubicación:** `main.tex:1000,1064,1068-1075`;
`verification/mechanism/m05_attack_model.py:114-120`.

`freshness_window()` define el mayor `k` con `γk < 1`; para `γ = 0.1` da 9. Pero
`γ` acota cuántas entradas **cambian por época**, no cuánto tiempo sobrevive una
entrada fraudulenta que **no cambia**. Una hoja fraudulenta puede quedarse
idéntica indefinidamente y el bound `γk` no la expulsa.

El paper dice: “the same `k` is the number of epochs an undetected fraud can run,
so `γ` fixes the largest window the detection probability must survive”
(`main.tex:1075`). Es falso tal como está: para que `γ` acotara la latencia,
toda hoja tendría que ser re-attestada o cambiada al menos una vez cada `k`
épocas, y ese requisito no existe ni en el contrato ni en el data layer.

Con `r_fraud = 1`, `ω = 0.1`, `ΔS = C_R(1) = 0.4`, `L = S_f*(1) = 0.6`:

```text
q_min(k) = k·ω·ΔS / (k·ω·ΔS + L) = 0.04k / (0.04k + 0.6)
k = 9  -> 0.375
k = 20 -> 0.5714
k = 50 -> 0.7692
k -> ∞ -> 1
```

Los valores 0,571 y 0,769 son los que menciona la revisión externa; el 0,375 de
`main.tex:1064` sólo vale si `k` está realmente acotado a 9. Sin un tope de edad
o re-attestation forzada, la probabilidad de detección requerida tiende a 1 y la
frase “freshness is the second line of defense” no se sostiene.

### Remediación

1. Añadir un tope real de edad: cada hoja debe cambiar o re-attestarse al menos
   una vez cada `K` épocas; el contrato/data layer debe poder demostrarlo.
2. O reformular §7.5: `γ` limita la **propagación** de fraude nuevo, no la
   duración de una hoja ya publicada; eliminar “nine epochs” como cota de
   latencia y recalcular la deterrence para `k` no acotado.
3. Test/documento: una hoja fraudulenta sin cambios durante 20 épocas sigue en el
   tensor; el modelo debe decir qué la detecta.

---

## P-22 — §2.5: `π(r)` se despeja de `C_R`; la consistencia es circular

**Severidad provisional:** Media (paper).
**Estado:** Confirmado por lectura.
**Ubicación:** `main.tex:284-298`;
`verification/stochastics/cr_ide_solver.py`.

`C_R(r) = 0.8r/(1+r)` se elige primero y luego se calcula `π(r)` aplicando el
operador integro-diferencial a esa `C_R` (`main.tex:293-298`). Por construcción,
cualquier `C_R` suave produce algún `π`; que `π` sea positiva en el rango
operativo no valida la forma funcional de `C_R`, sólo comprueba que la ecuación
se satisface con el `π` derivado. La “consistencia” es circular.

Además, el término de descuento de la ecuación es `−r C_R`: la tasa de descuento
es el propio estado de reputación `r`, no una tasa exógena. No hay justificación
económica ni dimensional para que la reputación sea a la vez estado y tasa de
descuento; si es una elección de diseño, debe decirse.

### Remediación

1. Derivar `C_R` de una prima `π` primitiva y condiciones de frontera, o
2. declarar `C_R` como ansatz de diseño y `π` como su recompensa implícita, sin
   presentar la consistencia como evidencia; y justificar (o cambiar) la tasa `r`.

---

## P-23 — §8: el bootstrap usa un `C_R` distinto del mapeo de §2

**Severidad provisional:** Media (paper).
**Estado:** Confirmado por cálculo y por lectura del script.
**Ubicación:** `main.tex:1135,1177,1191`;
`verification/bootstrap/simulate_bootstrap_net_gain.py:28-30,64`.

§2 define `C_R(r) = 0.8r/(1+r)` con `r = R/(1−R)`; sustituyendo, el mapeo da
`C_R = 0.8R` (el propio paper lo reconoce en `main.tex:1135`). El bootstrap, en
cambio, usa `C̃_R(R) = 0.8R/(1+R)` (`simulate_bootstrap_net_gain.py:28-30`), que
no es el mapeo de §2.

Con `R` medio `0.3936`, el bootstrap reporta `S_f` medio `0.7764` (reducción
22,4 %). Bajo el mapeo de §2, la reducción sería `0.8 × 0.3936 = 31,49 %`. El
paper presenta 22,4 % como “the protocol” (`main.tex:1191`) sin cualificar que
usa `C̃_R`, no la `C_R` de §2.

El Gini y el Top-10 son idénticos entre `pure_pos` y `hybrid_no_decay` porque
`R(t)` no depende de la política; el paper lo dice (`main.tex:1181`), pero la
comparación no puede responder si la transición concentra poder, sólo comparar
la política de stake. La tabla de políticas no es un test de concentración.

### Remediación

1. Usar el mapeo de §2 (`C_R = 0.8R`) y reportar 31,5 %, o justificar `C̃_R` como
   modelo específico del bootstrap y etiquetar 22,4 % como tal.
2. Añadir una métrica de concentración que dependa de la política (stake,
   control, participación), no sólo de `R`.
3. No presentar el Gini idéntico como evidencia de que la transición no
   concentra; es una tautología.

**Acuerdo de reconciliación:** el 22,4 % es correcto bajo `C̃_R`; no se registra
como error aritmético. La severidad Media se mantiene por la presentación: el
paper lo llama “el protocolo” sin decir que usa un mapeo distinto del de §2. Si
se etiqueta explícitamente como modelo del bootstrap, el hallazgo baja a
informativo.

---

## P-24 — `F0* = 0.05` no es el óptimo admisible y la fee se quema

**Severidad provisional:** Media (paper/contrato).
**Estado:** Confirmado por lectura.
**Ubicación:** `main.tex:881-900`; `AVIPValidatorManager.sol:80-88`;
`AVIPStakeVault.sol:396-416`.

El paper calcula `F0* = π_val − ω̄Θ = 0.15 − 0.10 × 1.0 = 0.05` en el tipo
`(ω̄, T = 0)` (`main.tex:881-900`). Pero `T = 0` no es admisible: el manager exige
`certifiedNorm >= Θ_r = 0.5` (`AVIPValidatorManager.sol:78,268-274`). El propio
contrato dice que, en el dominio admisible, el óptimo es **0,07666** y que 0,05
se mantiene como cota inferior segura (`:80-88`). Llamar “óptimo” a 0,05 es
incorrecto en el dominio que el contrato aplica.

Además, la fee va directamente al `AVIPBurnSink` y se quema
(`AVIPStakeVault.sol:411-416`; `AVIPBurnSink.sol:66-82`). No hay un objetivo de
recaudación que maximizar: “óptimo” sólo puede significar “máximo que preserva
IR”, y 0,05 no es ese máximo ni siquiera en el subdominio admisible.

### Remediación

1. Recalcular `F0*` en `T = Θ_r` (0,07666) o renombrar 0,05 como cota inferior,
   no como óptimo.
2. Decir explícitamente que la fee se quema y por qué; si se quema, no hay
   “revenue” que optimizar y la justificación debe ser IR/deterrence, no ingresos.
3. Alinear paper, comentario del manager y README.

---

## P-25 — Erratas y sobreafirmaciones menores

**Severidad provisional:** Baja/media (paper). La mayor parte son erratas; el
gas y sus cifras derivadas son la parte material y afectan a §4/§9.
**Estado:** Confirmado por lectura/cálculo y ejecución.
**Ubicación:** `main.tex:552,562-564,1290-1297`; `README.md` (filas de gas);
`Groth16Verifier.sol:34-36`.

- `AVIPValidatorManager.sol:18-19`: el NatSpec dice
  `0.2 + 0.2/(1+r)`; lo correcto es `0.2 + 0.8/(1+r)`. El código
  (`S_MIN`, `CR_INF`) está bien.
- `main.tex:465`: `c = ⌊||T||⌋` omite que `certifiedNorm` va en WAD. El circuito
  usa `certified_norm_wad` y `Θ_r = 0.5e18`; con la lectura literal de `c`
  entero, `c ≥ 0.5` se leería como `c ≥ 1`. `native.rs:143` (“Θ_r is an integer”)
  también es engañoso: el umbral es WAD.
- `certified_norm_wad: u64` (`native.rs:214,235,422`): el máximo válido
  `√500 ≈ 22.36` en WAD supera `u64::MAX ≈ 18.45` (ya en P-04).
- Tucker: el paper dice que el error con ruido es **igual** a `||N||/||T||`
  (`main.tex:391`). En 200 sorteos medí `error / (||N||/||T||)` entre 0,848 y
  0,938, media 0,892: Tucker ajusta parte del ruido, así que es sistemáticamente
  menor. Decir “igual” es una sobreafirmación menor.
- Gas: `~206k` (`main.tex:552`) es la composición de primitivas con la clave
  inline, no una medición del verificador desplegado. La ruta real medida con
  la proof de M4b es:
  `Groth16Verifier.verify` **223.403** en caliente;
  `AVIPRegistry.verifyThreshold` **233.104** en caliente y **286.144** en frío
  (incluye decode, SLOAD del registro y la llamada externa); `manager.admit`
  **376.588** (incluye escrituras y eventos). La medición previa de 290.854 en
  frío es consistente con esta; la diferencia es el harness, no otra ruta.
  El paper debe citar la ruta desplegada y usar **286.144** (frío) para el
  break-even; **223.403** es el coste en caliente y no debe usarse para la
  comparación principal. No mezclar la clave inline con la clave en storage.

  Cifras derivadas, con la misma fórmula del paper (`k=10`, `ω=0,10`,
  `ΔS=0,2236`):

  | `G` (gas) | Ruta | `g*` (gwei) | `684.064 / G` |
  |---:|---|---:|---:|
  | 206.000 | clave inline (paper) | 1.085 | 3,32× |
  | 223.403 | verify, caliente | 1.001 | 3,06× |
  | 233.104 | verifyThreshold, caliente | 959 | 2,93× |
  | 286.144 | verifyThreshold, frío (harness nuevo) | 781 | 2,39× |
  | 290.854 | verifyThreshold, frío (harness previo) | 769 | 2,35× |
  | 376.588 | manager.admit completo | 594 | 1,82× |

  **Decisión de reporte (revisión del 2026-10-20):** la cifra canónica es
  `G = 286.144`, el camino frío de `verifyThreshold`, **sólo verificación**. Una
  admisión real es casi siempre la primera llamada de la tx, así que `233.104`
  en caliente subestima. Si se compara contra la admisión completa, ambos lados
  deben usar el mismo alcance y `G = 376.588` (`manager.admit`), con
  `g* ≈ 594`; no se mezcla con `286.144`. El cociente `455.430 / 286.144 ≈ 1,59×`
  mezcla la ingesta optimizada con la verificación sin optimizar y **no** se cita
  hasta remedir ambos lados con el mismo compilador y perfil. A 25 gwei, el
  margen de la ruta fría es `781/25 ≈ 31,2×`, no 43×. El rediseño P-01/P-16
  invalidará además estas cifras (nuevo `ic.length` y nueva clave).
- `main.tex:282`: “absorbing boundary at `r = 0`” bajo Feller. Bajo Feller
  estricto el proceso no alcanza 0; la frontera absorbente no es la descripción
  correcta. Si se quiere hablar de 0, hay que distinguir Feller de no-Feller.
- `main.tex:316`: la tabla marca “second-regime tail is geometric”, pero el
  texto de `:234` reporta una desviación sistemática (`P_emp/P_geo` 0,9973 a
  0,9858). La etiqueta debe ser “aproximadamente geométrica” o quitar
  “Verified”.

---

## P-26 — Los guards de despliegue no son fail-closed fuera del runbook de fase 1

**Severidad provisional:** Media/baja (operacional; no explotable por un tercero
si el operador configura bien, pero puede producir un `status=ok` sobre un
despliegue inoperable). **Estado:** Confirmado con PoC.
**Ubicación:** `DeployFujiPhase1.s.sol:122-142,196-214`;
`DeployRegistry.s.sol:85-124`; `DeployStakeVault.s.sol:67-95`;
`DeployValidatorManager.s.sol:85-123`; `DeployBurnSink.s.sol:71-99`.

### Qué hace el código

El runbook de fase 1 es el único que exige Fuji o local y que reaplica
`_refuseAnvilDefault` a un `Plan` explícito. Los scripts individuales
(`DeployRegistry`, `DeployStakeVault`, `DeployValidatorManager`) sólo llaman a
`_refuseMainnet()`, que rechaza **43114** y ninguna otra cadena; su `deploy(Plan)`
tampoco reaplica `_refuseAnvilDefault`, así que un plan construido directamente
puede usar las claves públicas de anvil en una red viva. La comprobación del
entorno (`plan()`) sí las rechaza, pero `deploy(Plan)` es la única función que
crea estado y no comparte esa garantía.

La fase 1, además, sólo comprueba que `TOKEN` y `SINK` no sean cero
(`DeployFujiPhase1.s.sol:138-139`); no comprueba `code.length`. `DeployStakeVault`
hace lo mismo (`DeployStakeVault.s.sol:77-79`). `DeployBurnSink` sí exige código
del token en Fuji (`DeployBurnSink.s.sol:79-81`); la fase 1, que es el runbook que
enlaza vault y manager, no. La falta de comprobación del `VERIFIER` en
`DeployRegistry` es el follow-up ya abierto en P-10 y no se cuenta dos veces aquí.

### PoC ejecutada

`pocs/new/TmpDeployGuards.t.sol` (fuente canónica; copia transitoria
`test/TmpEvidenceDeployGuards.t.sol` borrada tras guardar el log):

1. `vm.chainId(43113)` y `DeployFujiPhase1.deploy` con
   `TOKEN = 0x…5005`, `SINK = 0x…6006` (EOAs), roles no-anvil. El script
   despliega registry, vault y manager, y emite `status=ok`; las dos direcciones
   tienen `code.length == 0`.
2. `vm.chainId(1)` y `DeployRegistry.deploy` con un `Plan` explícito: el script
   despliega el registry y emite `status=ok`; no hay `UnsupportedChain` ni
   `AnvilDefaultOnLiveNetwork`.

Resultado: **2 passed, 0 failed**, salida en `logs/deploy-guards.txt`.

### Consecuencia

Un operador que ejecute la fase 1 con un `TOKEN` o un `SINK` equivocados recibe
el mismo `status=ok` que con direcciones correctas. Con un token EOA, `deposit`
revierte en la primera llamada a `balanceOf`; con un sink EOA, el vault transfiere
el stake al sink y la notificación `receiveFunds` no ejecuta ninguna lógica (la
llamada a una EOA tiene éxito con retorno vacío), de modo que los fondos quedan en
una dirección que no es un `IFundSink`. En el segundo caso no hay un atacante,
pero el destino de los fondos slasheados es una decisión de despliegue que el
script no valida. El caso del `VERIFIER` EOA es el mismo patrón, ya descrito en
P-10; aquí no se reintroduce como hallazgo separado.

No es una vulnerabilidad del protocolo desplegado: es un fallo de los guards
operativos, y por eso la severidad es media/baja y no alta. La fase 1 de Fuji
existente usa `VERIFIER = address(0)` y no está afectada; el riesgo aparece en el
siguiente despliegue que reutilice estos scripts.

### Remediación propuesta (no implementada)

1. Que `DeployFujiPhase1`, `DeployStakeVault` y `DeployRegistry` exijan
   `code.length > 0` para `TOKEN`, `SINK` y `VERIFIER` en toda cadena que no sea
   `LOCAL_CHAIN` (mismo criterio que `DeployBurnSink`).
2. Que los tres scripts individuales usen `_requirePhase1Chain()` (Fuji o local)
   en vez de `_refuseMainnet()`, o que `DeployCommon` ofrezca un único
   `_requireAvalancheChain()` y no haya dos políticas.
3. Que `deploy(Plan)` reaplique `_refuseAnvilDefault` a cada rol, como ya hace
   `DeployFujiPhase1`, para que la garantía no dependa de llamar a `plan()`.
4. Cerrar el follow-up de P-10 para `VERIFIER` (código, aridad y digest) en el
   mismo cambio de `DeployRegistry`; aquí no se duplica.
5. Añadir un caso al `deploy_dryrun.sh` con `--chain 43113` y `TOKEN`/`SINK` EOAs
   que deba fallar; la suite actual sólo prueba el camino local.

---

## Adenda (2026-10-20, segunda lectura): siete hallazgos nuevos

Esta adenda recoge los puntos que no estaban en el informe anterior. Siete son
nuevos (`P-27`…`P-33`); el cuarto —la freshness declarada— **ya estaba
confirmado como P-12** y no se renumera. El punto 8 se verificó con una sonda
temporal del circuito: no son 64 bits, son 60, y el circuito acepta una entrada
por encima de `WAD`.

| # | Hallazgo de la segunda lectura | ID | Tratamiento |
|---|---|---|---|
| 1 | El detector de colusión no se deriva de `T` ni del data layer; `W` es una entrada externa | P-27 | Nuevo |
| 2 | El “piso financiero” `0.2Θ` se presenta como garantía de seguridad | P-28 | Nuevo |
| 3 | El README promete una confianza mínima que v1 no entrega | P-29 | Nuevo |
| 4 | La cota de freshness es declarativa, no on-chain | P-12 | **Ya registrado**; no se duplica |
| 5 | `π_val`, `ω` y `k` no tienen epoch/tiempo definido | P-30 | Nuevo |
| 6 | La premisa PoW de la introducción no tiene cita | P-31 | Nuevo |
| 7 | `admit` usa siempre la última época e invalida proofs en vuelo | P-32 | Nuevo |
| 8 | El circuito no acota las entradas a `≤ 1 WAD` | P-33 | Nuevo, con sonda ejecutada |

---

## P-27 — El detector de colusión no está conectado al estado de reputación

**Severidad provisional:** Alta (diseño/paper; la defensa anunciada no es
operativa).
**Estado:** Confirmado por lectura.
**Ubicación:** `docs/paper/main.tex` §Collusion, `src/rmt/`,
`docs/architecture/implementation-plan.md` D-7, `src/datalayer/`.

### Qué hace el código y qué dice el paper

El paper define dos objetos distintos y nunca los relaciona:

- `T ∈ [0,1]^{C×D×H}` es el tensor de reputación de **un** validador
  (`main.tex:333`), construido por `f_c` a partir de eventos de consenso
  (`main.tex:982-989`).
- `W ∈ R^{n×n}` es el grafo de **interacciones entre** validadores
  (`main.tex:629-632`), con `W_ij` contando votos de gobernanza, PRs
  coautorados o eventos de liquidez simultáneos.

La sección de colusión no contiene una ecuación `W = g(T)` ni una ruta de
ingesta que produzca `W`. El detector implementado recibe el grafo como
argumento explícito:

```rust
pub fn detect(w: &Graph, cal: &Calibration) -> Detection
```

(`src/rmt/src/detector.rs`), y `Graph` es una matriz `n × n` que el llamador
construye (`src/rmt/src/graph.rs`). El propio README del crate lo declara:

> `main.tex` defines `W` as the *collaboration* graph (`eq:collab`) and `T` as
> the *reputation* tensor (`eq:tensor`); §collusion never relates them, so M5
> does not invent a projection — the missing map is plan §10 **D-7**.

(`src/rmt/README.md:107-113`).

El plan lo deja abierto en la opción (b): `W` es una entrada del detector, sin
derivación de `T` en el repositorio (`implementation-plan.md:2623`). El data
layer tampoco lo produce: `Epoch` contiene hojas `Entry { validator, norm_wad }`
(`src/datalayer/src/commitment.rs:48-55`), no una matriz de interacciones.

### Por qué importa

El paper presenta la detección de colusión como uno de los componentes del
protocolo (`main.tex:78`, `main.tex:95`) y, cuando la detección falla en colas
pesadas, traslada la garantía al piso financiero (`main.tex:798`). Pero el
detector no consume el estado que el protocolo sí tiene (`T`), sino un grafo
externo que ningún componente del repositorio construye. En la práctica es un
monitor sobre datos sintéticos, no una defensa conectada a la admisión.

Tampoco hay una ruta de ejecución: `AVIPCollusionAlertChannel` registra una
bandera y el propio test de transporte dice que una alerta de colusión “does not
touch a voting weight” (`integrations/avalanche/test/M7dTransport.t.sol:71`);
`AVIPValidatorManager.slash` sólo puede ser llamado por `slashAuthority`. Es
decir, ni la señal se deriva de `T` ni la señal produce un slash automático.

### Lo que el paper no declara

§Limitations menciona que la calibración RMT usa grafos Erdős–Rényi y
Chung–Lu y que los umbrales no son válidos para grafos reales
(`main.tex:1419-1421`), pero **no** dice que falte el mapa `T → W`. La lista de
limitaciones de diseño incluye la frontera de detección no localizada
(`main.tex:1447-1471`), no la ausencia de la entrada. Un lector puede concluir
que el detector ya está alimentado por el protocolo; no lo está.

El paper sí documenta el resultado negativo en colas pesadas (F-019/F-020/F-021,
`main.tex:752` y `798`: el umbral ER no transfiere a Chung–Lu, y la
recalibración por null destruye la potencia). Lo que no documenta es que, incluso
en el caso sintético donde funciona, `W` no se deriva de `T` ni de la ingesta de
eventos. Son dos límites distintos: el de validez estadística ya está declarado;
el de conexión con el protocolo, no.

### Remediación propuesta (no implementada)

1. Declarar `W` como **entrada externa** en el paper y en §Limitations, con la
   misma claridad con la que el plan dice D-7; o
2. definir e ingerir `W` desde el data layer (interacciones verificables), y
   entonces especificar `T → W`; o
3. mantener D-7 abierto y retirar del paper la palabra “protocol” para la
   detección, presentándola como análisis de un grafo que el protocolo no
   produce.
4. En cualquiera de las tres, definir qué ocurre tras una alerta: quién puede
   slashar, con qué prueba y con qué quórum. Hoy la alerta no tiene consecuencia
   on-chain.

No se debe inventar una proyección heurística: sería una constante con
apariencia de medición, el mismo error que el plan evita en D-7.

### Addendum (tercera lectura): el flag on-chain es irrevocable y no tiene consumidor

El informe externo añade dos hechos que P-27 ya rozaba pero no medía:

- `AVIPCollusionAlertChannel._deliver` graba `_flagOf[sourceChain][epoch]` una
  sola vez y revierte con `FlagAlreadyRecorded` si llega otra alerta para el
  mismo par (`AVIPCollusionAlertChannel.sol:168-180`). No hay `unflag`,
  `challenge` ni revocación: el conjunto de flags sólo crece.
- En el caso Chung–Lu, el propio paper reporta `FPR = 1.0` a `α = 0.01`
  (`main.tex:752`): el detector marca **todos** los grafos. Un flag permanente
  producido por ese falso positivo no se puede corregir.

Hoy no hay consumidor on-chain, así que el impacto es latente: el flag no mueve
stake ni peso. Pero si se añade el consumidor que §4 promete, un flag irrevocable
y con FPR=1.0 en colas pesadas sería una sanción permanente sobre validadores
honestos. **No es un ID nuevo**: es la mitad on-chain de P-27 (punto 4 de la
remediación). El cierre debe elegir una de dos:

1. el flag es sólo un aviso, se declara que no es una sanción y no se conecta a
   ningún peso sin una prueba adicional o una ventana de impugnación; o
2. el flag se puede disputar/revocar y el consumidor exige esa disputa antes de
   reducir peso.

En ambos casos, la tabla de calibración por densidad de P-35 es la que dice
cuándo el flag es informativo y cuándo es ruido.

---

## P-28 — El “piso financiero” es `0.2Θ`: coste mínimo de admisión, no garantía de seguridad

**Severidad provisional:** Alta (paper; económica).
**Estado:** Confirmado por cálculo sobre el texto.
**Ubicación:** `docs/paper/main.tex:752`, `798`, `865-867`.

### La aritmética

El paper fija

```text
C_R(r) = 0.8 r / (1 + r)
C_R^∞ = 0.8
S_min = Θ − C_R^∞ = 1.0 − 0.8 = 0.2
S_f*(T) = max{S_min, Θ − C_R(T)}
```

(`main.tex:865`). Como `C_R(r) < 0.8` para todo `r` finito, el máximo es
siempre `0.2`: el piso **nunca** queda inactivo en el dominio admisible. Un
validador con reputación arbitrariamente inflada paga `0.2` por nodo, frente a
`1.0` en PoS puro: **5× menos**.

El paper reconoce la mitad de esto: dice que la ecuación “is not a network-level
cost-of-attack bound” (`main.tex:867`) y que el Cost of Attack sigue abierto
(§10). Pero en la misma sección afirma que, cuando la detección no funciona, la
“guarantee against a heavy-tailed collusive core rests on the financial floor
`max{S_min, Θ − C_R^∞}`” (`main.tex:798`; véase también `main.tex:752`). Eso
no es una garantía de seguridad: es una garantía de que **el stake mínimo es
0.2**, y `0.2` es precisamente el precio al que el atacante compra el nodo.

### Por qué la palabra “garantía” no se sostiene

- El piso es el **coste de admisión**, no el coste del ataque. Para que el slash
  disuada, el beneficio por nodo tendría que ser menor que `0.2`; el paper no
  demuestra esa condición para un cártel.
- `0.2` no es una constante derivada: se mueve con `C_R^∞`. El propio paper
  barre `C_R^∞ ∈ [0.5, 1.0]` y obtiene `S_min ∈ [0.0, 0.5]` (`main.tex:865`).
  Con `C_R^∞ = 0.9`, el piso es `0.1`: 10× menos que PoS. La “garantía” es, en
  el mejor caso, una elección de parámetro.
- El modelo no pricea el coste de **adquirir** la reputación que produce el
  descuento (`main.tex:867`). Sin ese coste, `S_min` no es una cota del coste
  total del ataque, ni siquiera por nodo.
- La comparación con PoS puro es la relevante para la tesis del paper: si el
  argumento es que la reputación baja la barrera, el precio de esa bajada es
  exactamente `5×` menos capital por nodo en el límite. El paper puede afirmarlo
  como trade-off; no puede llamarlo garantía sin cualificar.

### Remediación propuesta

1. Sustituir “guarantee against a heavy-tailed collusive core” por “minimum
   admission cost” y añadir la frase “`S_min = 0.2Θ`, i.e. one fifth of the
   pure-PoS stake per node”.
2. Añadir una sensitividad explícita de `S_min` (ya existe el barrido) y
   decir qué valor se necesitaría para que el piso fuese disuasorio.
3. Si se quiere mantener una afirmación de seguridad, modelar el coste de
   adquisición de reputación y el beneficio del cártel; hoy el paper
   explícitamente no lo hace.
4. No confundir este hallazgo con P-19: P-19 mide cuánto descuento compra una
   sola celda del agregador; P-28 mide el límite del descuento cuando la
   reputación es alta. Son dos defectos distintos del mismo mecanismo.

---

## P-29 — El README promete una confianza mínima que v1 no entrega

**Severidad provisional:** Media (documentación/overclaim).
**Estado:** Confirmado por lectura.
**Ubicación:** `README.md:42-43`, `AVIPRegistry.sol`, `AVIPValidatorManager.sol`.

### Qué promete el README

La tabla de principios de diseño dice:

> **Non-transferable:** Reputation cannot be bought, sold, or delegated. It
> accrues to a validator's own verifiable history, so it cannot be rented from
> the capital market.

> **Verifiable:** Possession is designed to be proven with V3/Groth16 threshold
> proofs (measured circuit; the on-chain verifier is not deployed), not by
> trusting a committee or a centralized registry.

(`README.md:42-43`).

La segunda frase mezcla dos cosas: el **diseño** (“is designed to be proven”) y
una comparación de confianza (“not by trusting a committee or a centralized
registry”) que se lee como una propiedad de v1. La primera frase también se lee
en presente, aunque v1 no ata el proof al validador (P-01).

### Los trust anchors que v1 sí tiene

- `AVIPRegistry.sequencer` es la **única** dirección que puede publicar
  compromisos (`AVIPRegistry.sol:69`, `:133-139`). El root que usa `admit` es el
  que publica esa dirección.
- `AVIPRegistry.guardian` es la **única** dirección que puede proponer cambios
  de `sequencer` y de `verifier` (`AVIPRegistry.sol:86`, `:148-166`,
  `:211-239`). El cambio de verificador se ejecuta tras `CHANGE_DELAY = 2 days`
  (`:94`). Un verificador malicioso puede devolver `true` para cualquier proof:
  `verifyThreshold` confía en `currentVerifier.verify(...)`
  (`AVIPRegistry.sol:321-346`), y P-08 ya demuestra que una clave degenerada
  acepta cualquier statement.
- `AVIPValidatorManager.slashAuthority` es la **única** dirección que puede
  slashar (`AVIPValidatorManager.sol:116`, `:288`).
- `AVIPSlashingChannel.NOTIFIER` es la **única** dirección que puede pedir un
  slash cross-chain, y el destino lo ejecuta sin verificar el fraude (P-34). En
  el reporte M7d de referencia es `ANVIL_2`, una EOA
  (`M7dReport.s.sol:69,150-166`).
- El guardian es inmutable, pero no hay rotación del guardian (P-10, addendum):
  si se compromete, el protocolo queda con esa autoridad.

Nada de esto es necesariamente un defecto de v1: son decisiones de despliegue
declaradas en el paper (§10.2). El defecto es que el README, que es la puerta de
entrada, no las enumera y usa “not by trusting … a centralized registry” sin
decir que el registry centraliza tres roles, que el transporte confía en un
notifier y que el verificador es mutable.

### Por qué importa

Un lector que sólo lee el README puede creer que v1 ya elimina la confianza en
el comité/registro. No la elimina: la mueve a un sequencer, un guardian y un
slashAuthority, y deja la verificación en un contrato que el guardian puede
cambiar. El paper lo dice en §10.2; el README no. La inconsistencia es de
documentación, pero afecta a la decisión de un integrador.

### Remediación propuesta

1. Añadir al README una sección **“Trust assumptions in v1”** con los cinco
   roles anteriores (sequencer, guardian, slashAuthority, notifier y verificador)
   y el delay de 2 días, enlazando a `main.tex` §10.2.
2. Reescribir la fila “Verifiable” en futuro/condicional: “is designed to be
   proven … once the on-chain verifier is deployed”; no yuxtaponer “not by
   trusting a committee” con un registry que hoy tiene roles privilegiados.
3. Enlazar P-01 y P-08 desde esa sección: el proof global y la clave degenerada
   son los dos casos en que “verifiable” no implica “trustless”.

---

## P-30 — `π_val`, `ω` y `k` no tienen unidad temporal; el break-even no es convertible a tiempo real

**Severidad provisional:** Media (paper; modelo).
**Estado:** Confirmado por lectura/cálculo.
**Ubicación:** `docs/paper/main.tex:854`, `869-876`, `891-902`, `1289-1293`.

### Qué dice el paper

```text
U(ω, T) = π_val − ω · S_f*(T) − F_0
```

con “`π_val` is the expected validation revenue per epoch” y `ω` el coste
privado del capital (`main.tex:872-876`). El ejemplo usa
`π_val = 0.15`, `ω̄ = 0.10`, `Θ = 1.0` (`main.tex:895`) y obtiene
`F_0* = 0.05`, “charged per epoch” (`main.tex:902`).

El break-even de gas usa la misma `ω` y `k`:

```text
g* = k · ω · ΔS_mean / G × 10^18  wei per gas
```

(`main.tex:1293`), con `k = 10` “epochs” (`main.tex:1289`).

### El problema dimensional

- `π_val` está definido **por epoch**, pero el paper no fija la duración de un
  epoch. La única declaración es que `N_b` es un parámetro de despliegue y que
  no hay contrato que lo fije (`main.tex:1323`, `1381`).
- `ω` se usa como si fuese **por epoch** en `U` y en `g*`, pero también se
  describe como “opportunity cost of locking financial stake”, que
  normalmente es una tasa anual. No hay conversión.
- Si `ω = 0.10` es por epoch, el coste de capital es `10%` del stake **cada
  epoch**; con `k = 10`, el coste acumulado es `100%` del stake. Eso hace que
  `F_0* = 0.05` sea un precio por epoch, no una fracción anual, y que
  `π_val = 0.15` sea un ingreso del `15%` del stake por epoch. Sin duración, no
  se puede decir si es plausible o no.
- Si `ω = 0.10` es anual, la fórmula `U` y `g*` necesitan
  `ω_epoch = ω_annual · T_e / 365 días` (o el período que se elija). Multiplicar
  por `k` sin esa conversión mezcla unidades.
- `k` se define como número de epochs (`main.tex:1000`, `1064`), pero §9
  reconoce que para pasar a wall-clock hace falta `k · N_b · B_blk`
  (`main.tex:1323`, `1381`). Esa conversión no se aplica al break-even: el
  resultado en gwei no tiene horizonte temporal, sólo “10 epochs”.

### Por qué importa

El `F_0* = 0.05` y el `g* ≈ 781 gwei` (P-25) son números que el paper presenta
como operativos. Si `π_val` y `ω` son por epoch, el primero es
`15%` del stake por epoch; si son anuales, el segundo necesita conversión. En
ambos casos, la comparación con el coste de gas de una admisión —que ocurre una
vez— no es directa: el ahorro `k · ω · ΔS` es un flujo durante `k` epochs, y el
gas es un pago único. La fórmula puede ser correcta bajo una convención, pero la
convención no está escrita.

Como ilustración: si `ω = 0.10` es **anual** y el epoch dura un día,
`ω_epoch = 0.10/365 ≈ 0.000274`; entonces `F_0* ≈ 0.14973` (no `0.05`) y el
break-even de P-25 baja de `781` a `≈2.1 gwei` con `k = 10`. La diferencia no
es cosmética: decide si el costo de gas es despreciable o no. Si `ω` es por
epoch, el `0.05` es un precio por epoch y el `781 gwei` es el break-even de 10
epochs, no de 10 unidades de tiempo sin definir.

### Remediación propuesta

1. Definir `T_e`, la duración del epoch, como parámetro de despliegue (no
   necesariamente on-chain), y declarar si `π_val` y `ω` son por `T_e` o por
   año.
2. Reescribir `U` y `g*` con la conversión explícita; si `ω` es anual, usar
   `ω_epoch = ω · T_e / 365 días`.
3. Reportar `F_0*` y `g*` con el horizonte en días, no sólo en epochs.
4. Añadir una sensitividad de `T_e` (por ejemplo, 1 hora, 1 día, 1 semana) para
   mostrar cómo cambian `F_0*` y el break-even.

---

## P-31 — La premisa PoW de la introducción no tiene cita

**Severidad provisional:** Baja/media (paper).
**Estado:** Confirmado por lectura; no es una refutación empírica.
**Ubicación:** `docs/paper/main.tex:56`.

### Qué afirma

> In proof-of-work networks, physical capacity constraints (hardware, energy,
> cooling) act as a natural brake on centralization. A miner with a
> technological advantage cannot expand indefinitely without facing diminishing
> returns on capacity.

No hay cita en la frase ni en el párrafo. La afirmación se usa como contraste
retórico con PoS, pero no entra en ninguna ecuación, simulación o prueba del
paper.

### Por qué es discutible

La literatura de minería documenta lo contrario en varios regímenes: economías
de escala en hardware y energía, pools que concentran hashrate y ventajas de
acceso a capital/energía que no se agotan linealmente. “No puede expandirse
indefinidamente” es una afirmación empírica fuerte que requiere evidencia, no
una consecuencia de la física. El paper no la usa después; es una premisa
decorativa que un revisor puede atacar sin tocar el resto del modelo.

No he revisado la bibliografía completa; el hallazgo es la **ausencia de cita y
de análisis**, no una demostración de que la frase sea falsa en todos los casos.
Los errores de entradas concretos y las demás referencias faltantes se registran
en P-36; P-31 es la premisa, no la lista de bibliografía.

### Literatura de reputación en PoS

La bibliografía del paper cita EigenTrust (`kamvar2003`), PeerTrust
(`xiong2004`), DPoS (`larimer2014`) y Tezos (`goodman2014`), pero no una línea
de investigación de reputación aplicada a PoS (reputation staking, delegated
reputation, trust scores on-chain). No es un defecto formal —el paper no
necesita una revisión exhaustiva— pero sí debilita la afirmación de
“positioning” de `main.tex:86`.

### Remediación propuesta

1. Suavizar la frase a “may act as a brake” y añadir una cita empírica sobre
   concentración de minería/pools; o eliminarla, porque no se usa.
2. Añadir 2–3 referencias de reputación en PoS en la sección de positioning, o
   declarar explícitamente que la comparación es con EigenTrust/DPoS y no con
   toda la literatura.
3. No convertir esta observación en una afirmación de que PoW es más
   centralizado: el paper no mide eso y la auditoría tampoco.

---

## P-32 — `admit` usa siempre la última época: el sequencer puede invalidar proofs en vuelo

**Severidad provisional:** Baja (griefing/liveness; no robo).
**Estado:** Confirmado por lectura y por un test existente.
**Ubicación:** `AVIPValidatorManager.sol:269-274`, `AVIPRegistry.latestEpoch()`,
`test/AVIPValidatorManager.t.sol:276-300`.

### Qué hace el código

`admit` no recibe la época como argumento. Lee la última época publicada en el
registry y verifica el proof contra ese root:

```solidity
uint256 epoch = registry.latestEpoch();
if (!registry.verifyThreshold(epoch, certifiedNorm, proof)) {
    revert IAVIPRegistry.InvalidZKProof();
}
```

(`AVIPValidatorManager.sol:269-274`).

El test `test_admit_usesTheLatestEpoch` confirma el comportamiento, y
`test_admit_rejectsAProofForAnOlderEpoch` confirma la otra cara: un proof de la
época 0 deja de valer cuando existe la época 1
(`AVIPValidatorManager.t.sol:276-300`).

### El griefing

Secuencia:

1. El validador genera un proof para la época `e` (3,9 s de proving en el
   circuito V3 medido).
2. Antes de que la transacción se incluya, el sequencer publica `e+1` con un
   root distinto (o incluso el mismo root, `changedEntries = 0`).
3. `admit` lee `e+1`; el proof de `e` no verifica; la transacción revierte con
   `InvalidZKProof`.
4. El validador debe volver a probar y reintentar. El sequencer puede repetir
   el ciclo en cada época.

No hay robo ni corrupción de estado: el validador conserva su stake y puede
reintentar. Es un ataque de **liveness/griefing** que fuerza trabajo de proving
y permite bloquear una admisión concreta si el sequencer identifica la
transacción en el mempool. El sequencer ya puede censurar transacciones, así que
no añade un trust anchor nuevo; añade un coste y una denegación de servicio
específica del diseño “latest epoch”.

Si la duración del epoch es menor que el tiempo de proving, el sistema puede
quedar en un estado donde ningún proof llega a tiempo. El paper no fija `N_b`
(P-30), así que esto no se puede descartar con los parámetros actuales.

### Remediación propuesta

1. Aceptar un `epoch` explícito en `admit`, con una ventana acotada
   (`epoch >= latestEpoch() - W` o `epoch == latestEpoch()`), y verificar contra
   ese root. La ventana debe combinarse con el binding al validador de P-01 y
   con un nullifier por validador para que no reintroduzca replay.
2. O permitir `epoch == latestEpoch()` y `epoch == latestEpoch() - 1` durante
   una ventana de tiempo, con un evento que registre la época usada.
3. O documentar que la admisión requiere un mempool privado / inclusión
   inmediata y que el sequencer puede bloquearla; en ese caso, decirlo en
   §Limitations y en el README.
4. Añadir un test que publique una época nueva entre la generación y la
   inclusión y compruebe el comportamiento elegido. Hoy el test existente
   confirma el comportamiento actual, no el deseado.

---

## P-33 — El circuito no impone `T ∈ [0,1]`: acepta entradas hasta `1.1529 WAD`

**Severidad provisional:** Media/baja (circuito; desviación de dominio).
**Estado:** Confirmado con una sonda temporal ejecutada.
**Ubicación:** `src/zk/src/fixture.rs:15`, `src/zk/src/native.rs:73-88`,
`src/zk/src/native.rs:152-161`, `docs/paper/main.tex:333`.

### Qué hace el circuito

El paper define `T ∈ [0,1]^{C×D×H}` (`main.tex:333`) y `f_c` mapea eventos a
un score en `[0,1]` (`main.tex:982-989`). El circuito, en cambio, descompone
cada entrada en **60 bits**:

```rust
pub const ENTRY_BITS: usize = 60;
```

(`src/zk/src/fixture.rs:15`), y `allocate_entry_bits` genera exactamente 60
booleanos por entrada, sin comparar con `WAD`:

```rust
(0..ENTRY_BITS).map(|j| {
    let bit = (e >> j) & 1 == 1;
    Boolean::new_witness(cs.clone(), || Ok(bit))
})
```

(`src/zk/src/native.rs:73-88`). El único límite es la descomposición: cualquier
valor representable es `< 2^60`. Pero

```text
2^60 − 1 = 1,152,921,504,606,846,975
         = 1.152921504606846975 WAD
```

es un 15.29% mayor que `1.0`. El fixture sí comprueba `max_entry() < WAD`
(`src/zk/src/fixture.rs:139-143`), pero esa comprobación es del fixture, no del
circuito: un prover con otro witness no la hereda.

### La sonda ejecutada

Se añadió temporalmente `src/zk/tests/tmp_entry_upper_bound.rs`:

```rust
let entry = (1u64 << fixture::ENTRY_BITS) - 1;
assert!(entry > fixture::WAD);
let (cost, synthesis) = native::synthesize(native::NormCircuit {
    entries: vec![entry],
    certified_norm_wad: entry,
});
synthesis.expect("synthesis");
assert!(cost.satisfied);
```

Resultado:

```text
running 1 test
test an_entry_above_one_wad_satisfies_the_norm_circuit ... ok
test result: ok. 1 passed; 0 failed
```

La fuente se conserva en
`docs/audit/evidence/2026-10-20-pocs/pocs/new/TmpEntryUpperBound.rs` y el log en
`logs/entry-bound.txt`; la copia en `src/zk/tests/` se borró. El circuito acepta
la entrada `1.152921504606846975 WAD` y certifica `certified_norm_wad = entry`.

### Alcance del impacto

No es una escalada directa: el límite global `certifiedNorm < 2^64`
(`CERTIFIED_BOUND_BITS = 64`, `src/zk/src/native.rs:120`, `152`) equivale a
`18.4467 WAD`, así que 500 entradas a `1.1529` no se pueden certificar (la norma
sería `≈25.78 WAD`). Pero **no hace falta** llevarlas todas al máximo: 100
entradas a `1.1529` dan una norma de `≈11.53 WAD`, por debajo del límite, y
pasan. La cota por entrada no existe; la cota global no la sustituye.

Consecuencias:

- Un validador puede probar un tensor que no pertenece al dominio `[0,1]` y
  obtener el descuento asociado. El efecto económico es pequeño en el margen
  (`C_R` pasa de `≈0.766` a `≈0.770` en el ejemplo), pero la afirmación
  “`T ∈ [0,1]`” del paper no queda enforceable.
- `allocate_entry_bits` **descarta** los bits por encima de 60: una entrada
  `2^60 + x` se interpreta como `x` (no como `2^60 − 1`). El generador de witness
  no rechaza el valor fuera de rango; si el data layer pudiera contenerlo, el
  proof sería sobre el valor reducido módulo `2^60`. Hoy el fixture está por
  debajo de `2^60`, pero el contrato del circuito no lo exige.
- El comentario de `fixture.rs` (“`2^60 > 1e18`”) justifica el ancho, no un
  máximo de `1e18`; es fácil leerlo como si la cota fuese `WAD`.

### Remediación propuesta

1. Añadir al circuito una restricción explícita `entry ≤ WAD` (por ejemplo,
   descomponer `WAD − entry` en 60 bits y comprobar que no hay acarreo
   negativo), además de la descomposición de 60 bits.
2. Añadir tests de frontera: `entry = WAD` satisfecho; `entry = WAD + 1`
   rechazado; `entry = 2^60 − 1` rechazado.
3. Rechazar en `allocate_entry_bits` cualquier `e >= 1 << ENTRY_BITS` en vez de
   truncarlo, o documentar que el tipo de witness ya es de 60 bits y que el
   llamador debe validar.
4. Actualizar el paper o el plan para decir que `T ∈ [0,1]` es una convención
   del data layer, no una propiedad demostrada por el circuito, hasta que (1)
   esté implementado.

### Endurecimiento (2026-10-22): la cota es de una sola cara, y dónde se cierra

M4d implementó la cota de P-33 en la ruta de admisión
(`admission.rs:245`: `enforce_below_pow2(wad - norm - 1, ENTRY_BITS)`), pero esa
forma **sólo acota por arriba**. La resta ocurre en el cuerpo y lo que se exige
es que el resultado esté por debajo de `2^60`; si `norm` es un elemento
«negativo», la diferencia vuelve a caer en rango y la comprobación pasa. La banda
aceptada fuera de `[0, WAD-1]` es

```text
norm ∈ [p − 2^60 + WAD, p − 1] = [p − 152.921.504.606.846.977, p − 1]
```

que en valores con signo es `[-2^60 + WAD, -1]`. `[0, WAD)` es el dominio de los
representantes **canónicos**, no de todos los que el circuito admite. No hay
ninguna otra restricción que acote `norm` por abajo: la descomposición de la
diferencia es la única que la toca.

Alcanzabilidad. `AdmissionCircuit::norm_wad` es un `u64`, así que este crate no
puede construir ese testigo; la descripción del circuito y la clave son públicas,
así que un prover con su propio generador de witness sí. Además la hoja tiene que
estar en el árbol, y el árbol lo escribe el secuenciador. Y hoy
`admit` revertiría igualmente, porque `collateralFor` calcula `CR_INF * norm` y
con `norm ≈ 2.19e76` ese producto desborda `uint256` antes de comparar el stake
—el mismo accidente que P-13 documenta—. Ninguna de las tres razones es una
comprobación.

Cierre implementado (barato, sin tocar la clave). `AVIPRegistry.verifyThreshold`
rechaza `certifiedNorm >= 2^64` con `NormOutOfDomain` **antes** de decodificar el
blob. El bound es el de `CERTIFIED_BOUND_BITS = 64` (P-04), no `< WAD`: el
registry certifica la codificación de una norma, no la política de un circuito
concreto, y así sigue sirviendo a un statement histórico con norma `> 1` (M4b,
`12.79`). La banda negativa cae entera por encima de `2^64`, y con ella la
maleabilidad módulo `r` de P-13 (`c` y `c + k·r` llegan al pairing como el mismo
escalar porque `Bn254.ecMul` reduce). Test permanente:
`test/M4dRealKey.t.sol::test_aNormTheFrameworkCannotEncodeIsRejected` — `r`,
`r−1` y `2^64` revierten; `WAD` pasa el guard y falla como veredicto del pairing,
que es donde vive P-33.

Queda pendiente, y se debe a la regeneración de clave que P-03 ya obliga: la cota
inferior **en el circuito**, `enforce_below_pow2(norm, ENTRY_BITS)` —una
descomposición de bits más—, que cambia `vk`, fixture y las cifras de gas. Hasta
entonces el circuito no es canónico por sí mismo y la canonicalidad la pone el
llamador.

---

## Contraste con la revisión externa

| Punto de la revisión | Resultado local | ID |
|---|---|---|
| Una sola raíz con dos usos incompatibles | Confirmado; el PoC muestra que un slot no puede satisfacer ambas. Es más fuerte que “la prueba no está atada”: es una colisión de estado | P-16 |
| La prueba no está atada a ningún validador | Ya confirmado con PoC de dos direcciones y el mismo proof; el registry es `view` y no hay nullifier | P-01 |
| El bounty no tiene de dónde pagarse | Confirmado como gap de implementación; el paper lo declara parámetro de modelo, así que no es una afirmación falsa, pero el lazo no se entrega | P-18 |
| `admit` se evalúa una sola vez | Confirmado; no hay recertificación ni reprecio y el slash no escribe reputación | P-17 |
| §2.4: momentos estacionarios | Confirmado; la tabla es el límite `λ = 0`; con saltos, 0,8065/0,9434 | P-20 |
| §7.5: freshness y latencia | Confirmado; `γ` no acota la duración de una hoja que no cambia; `q_min` 0,571/0,769 y tiende a 1 | P-21 |
| §2.5: `π(r)` y tasa `r` | Confirmado como consistencia circular; la tasa `r` no está justificada | P-22 |
| Agregador Frobenius débil | Confirmado: una celda 0,5 da 26,7 % y una celda 1,0 da 40 % | P-19 |
| §8: Gini y 22,4 % vs 31,5 % | Aceptado el matiz: 22,4 % no es error aritmético; es correcto bajo `C̃_R` y no bajo el mapeo de §2 (`0.8R`, 31,5 %). El problema es presentarlo como “el protocolo” sin cualificar. El Gini idéntico es tautológico y el paper lo dice | P-23 |
| `F0* = 0.05` no es óptimo admisible | Confirmado; el óptimo admisible es 0,07666 y la fee se quema | P-24 |
| Gas del verificador y cifras derivadas | 206k es la clave inline; la ruta desplegada da 223.403 en caliente y 286.144 en frío. `G` canónico = 286.144: 2,39× y 781 gwei; si se reporta `manager.admit` completo, 376.588 y 594 gwei (1,82×). El 1,59× no se cita hasta homogeneizar compilador/alcance | P-25 |
| Carrera de `bindManager` en el vault | Confirmada en código y test; en Fuji el vault apunta al manager correcto y no hay fondos, pero la ventana existió (bloques 59.670.734 → 59.670.735) | P-05 |
| Erratas menores | Confirmadas y agrupadas | P-25 |

**No confirmado como error:** el 22,4 % del bootstrap no es un fallo aritmético
del script; es el resultado de `C̃_R = 0.8R/(1+R)`. El problema es presentarlo
como “el protocolo” sin decir que no usa el mapeo de §2. Igual ocurre con el
Gini: el paper reconoce que es idéntico porque `R(t)` no depende de la política;
la objeción válida es que entonces esa comparación no mide concentración.

**Reconciliación cerrada en esta sesión.** (1) P-01 y P-16 son un único
rediseño: compromiso por validador, una raíz canónica y `validator` constreñido
en el circuito; la evidencia de P-01 ya usa la proof real, no el mock. (2) La
lectura correcta de `T` es la de P-03: hojas `Entry {validator, norm_wad}` en el
data layer, no “un tensor de 500 entradas por época” ni un tensor 20×5×5 que el
circuito use. (3) P-23 se mantiene como problema de presentación, no de
aritmética. (4) El gas se corrige en P-25 con la ruta desplegada y la nota de que
206k es la clave inline. (5) La carrera de `bindManager` es P-05; en Fuji el
binding correcto está comprobado on-chain y no hubo fondos, pero la ventana de
un bloque existió y el patrón sigue abierto para futuros despliegues.

---

## Tercera lectura (2026-10-21): conciliación del informe externo completo

El informe externo completo repite varios hallazgos ya registrados y añade tres
que no estaban: el slash cross-chain sin verificación (P-34), la frontera de
detección mal caracterizada y no barrida en densidad (P-35) y los errores de
bibliografía (P-36). La sonda de cierre de la duda Poseidon añade un cuarto
(P-37), que no venía del informe: el informe sólo pedía contrastar el vector.
La tabla siguiente fija la correspondencia **por ID**; no se abre un ID nuevo
para lo que ya estaba.

| Punto del informe externo | Resultado local | ID |
|---|---|---|
| `enforce_floor_norm` impone `c = ⌊√S⌋` sin holguras; la prueba de ligadura falla como debe | Confirmado por lectura; no es un hallazgo | — |
| `CERTIFIED_BOUND_BITS = 64` impide certificar norma > 18.4467; máximo 22.36 (25.78 con 60 bits por entrada) | Confirmado; es **completitud**, no soundness. Añadido a P-04 | P-04 |
| Poseidon (rate 2, capacity 1, 8+57 rondas, α=5) no contrastado con un vector de circomlib | **Contrastado**: la permutación reproduce los vectores t=3 de circomlib (`[1,2]`, `[3,4]`) y la absorción coincide para 1–10/500; el digest usa `state[1]` (rate), no el `state[0]` (capacidad) de circomlib. Convención válida, no defecto | **P-37** |
| `ecMul` reduce escalares ≥ r; `v` y `v+r` equivalentes; exigir `input < r` y `root < r` | Confirmado; P-13 se amplía al `root` | P-13 |
| `pushPair` descarta pares con identidad; `(0,0)` es el infinito; `decodeProof` sí comprueba coordenadas < p | Confirmado; es la misma causa de P-08, no un hallazgo separado | P-08 |
| `AVIPSlashingChannel` descarta epoch/ingestionDigest/published/formula; `reason = keccak(sourceChain, nonce)`; sin verificación de fraude ni alcance temporal | Confirmado; P-14 era observabilidad, la confianza es nueva | P-14 + **P-34** |
| `AVIPCollusionAlertChannel` y `AVIPCommitmentRelay` no tienen consumidor; flags irrevocables; FPR=1.0 en colas pesadas | Confirmado; es la mitad on-chain de P-27 | P-27 (addendum) |
| Sólo `admit` y `slash`; `withdraw` capado a `ceil(stakeOf)`; IR ex-ante | Confirmado; el paper ya lo declara en §Limitations y P-17 lo registra | P-17 |
| `payFee` no se aplica en el vault | Confirmado; ya estaba | P-06 |
| `bindManager` es una carrera de despliegue | Confirmado; ya estaba, y **es P-05, no P-25** | P-05 |
| Réplica H0: media 8.758, q99 9.01 (paper 8.768/9.054) | Coincide; sin hallazgo | — |
| Frontera calculable con BBP: θ≈4.38, m≈12.2 a 10×; 50 % en m≈15.4; Kesten–Stigum no aplica a m≈20 sobre n=500 | Confirmado; la tabla es réplica propia y el 50 % es cifra del informe | **P-35** |
| Evasión por densidad: 40 a 3× TPR≈0.06; 24 a 5×≈0.12; 30 a 5×≈0.35; multibloque subcrítico no evade | Confirmado; nuevo | **P-35** |
| Bauer–Jost mal citado (CPAM 2012) y referencias faltantes | Confirmado; nuevo | **P-36** |
| OTS no inspeccionado (el informe decía 4 attestations pendientes) | El recibo **vigente** tiene 3 `PendingAttestation` (alice, finney, catallaxy) y ninguna Bitcoin; el `.bak` tiene 4 pero compromete un root anterior. Ancla y manifiesto verdes; cadena Bitcoin no cerrada | — (alcance) |
| Suite numérica completa no reproducida | Fuera de alcance, como ya constaba | — (alcance) |
| BN254 ~100 bits no discutido en el paper | `main.tex` no declara nivel de seguridad; no se cuantificó ni se añadió fuente. No se eleva a hallazgo | — (alcance) |
| Commitment Poseidon sin etiqueta de dominio ni longitud | Confirmado por lectura y sonda: `[5]` y `[5,0]` colisionan; en la ruta de 500 fija no aplica. Relevante para P-16; cobertura pendiente, no hallazgo | — (cobertura pendiente) |

**No confirmado como error:** la réplica H0 del informe coincide con el paper
(8.758/9.01 frente a 8.768/9.054); la diferencia es ruido de simulación, no un
defecto. Tampoco se confirma la hipótesis de que partir la colusión en varios
bloques evite el test: en la réplica, los bloques múltiples subcríticos
**aumentaron** la detección (5×12 a 10×: 0.480; 10×10 a 10×: 0.387), no la
redujeron. El límite se expresa en θ, no en `m`.

Las diferencias de TPR entre la réplica propia y la del informe (24 a 5×:
0,067 frente a 0,120; 30 a 5×: 0,290 frente a 0,350; 5×12: 0,480 frente a 0,603;
10×10: 0,387 frente a 0,473) se explican por el `q99` del nulo estimado con
1.000 frente a 1.500 réplicas, que desplaza todos los TPR a la vez; con IC de
±0,06, la conclusión cualitativa es la misma. Para el paper se reporta el TPR
con intervalo y un `q99` fijado, no una mezcla de calibraciones.

---

## P-34 — El slash cross-chain se ejecuta sobre la palabra del `NOTIFIER`

**Severidad provisional:** **Alta** (confianza/custodia). No es un fallo de la
aritmética del manager: es que el destino no puede verificar la premisa.
**Estado:** Confirmado por lectura; el propio test M7d declara la limitación.
**Ubicación:** `AVIPSlashingChannel.sol:120-205`;
`AVIPMessageCodec.sol:139-146,305-320`; `AVIPMessageEndpoint.sol`;
`AVIPValidatorManager.sol:287-323`; `M7dTransport.t.sol:60-80`.

### Qué hace el código

En la cadena origen, `notify` sólo exige `msg.sender == NOTIFIER` y un payload
que pase `encodeSlashing`/`decodeSlashing`:

- `validator != address(0)`;
- `ingestionDigest != bytes32(0)`;
- `publishedWad != formulaWad`.

En la cadena destino, `_deliver` vuelve a decodificar, escribe
`_reasonOf[sourceChain][nonce] = reason` y llama a
`MANAGER.slash(notification.validator, reason)`. El manager toma **todo** el
stake on record (`available = _stakes[validator]`), lo pone a cero y expulsa.

No hay ninguna comprobación de que `publishedWad` sea realmente la hoja
publicada, de que `formulaWad` sea `f_c(events)`, de que los eventos existan, de
que la época sea reciente o de que el validador estuviera admitido en esa época.
`publishedWad != formulaWad` sólo dice que dos números son distintos: cualquier
par inventado lo satisface. El `reason` es `keccak(sourceChain, nonce)`, así que
tampoco compromete el contenido del fraude.

El test M7d lo dice sin ambigüedad:

> “A compromised ... notifier can ask for a slash that no proof supports
> (`NotAFraudProof` catches only the self-refuting case). The claim is
> *provenance and at-most-once delivery*; soundness lives in M7b's fraud proof
> and in the data layer, not here.” (`M7dTransport.t.sol:74-79`).

### Por qué es Alta y no Baja

- **Un solo rol mueve todo el stake.** `NOTIFIER` es inmutable y, en el
  despliegue de referencia, una única dirección. En el reporte M7d es
  `ANVIL_2`, una **EOA**, no un multisig ni un contrato con quórum
  (`M7dTransport.t.sol`). Si se compromete (o si el contrato de origen tiene un
  bug), puede slashear a cualquier validador registrado en cualquier subnet
  suscrita, en cualquier época, por el stake entero. La allowlist de `origins`
  autentica la *procedencia* del mensaje, no la *verdad* de su contenido.
- **No hay ventana de impugnación.** La ejecución es inmediata en la entrega.
  El `nonce` impide repetir el mismo mensaje, pero no impide fabricar uno nuevo
  con otra época u otro validador.
- **El paper no lo declara con esta claridad.** §7.3 dice que “soundness rests on
  the fraud proof and slashing mechanisms” (`main.tex:996`) y que “the data layer
  reports; the manager is what acts on the report” (`main.tex:1003`). Eso describe
  un flujo, no la confianza en un `NOTIFIER` que puede inventar el reporte. El
  README del transporte sí lo dice; el paper no.
- **La comparación con P-14.** P-14 es que el destino no guarda los campos;
  P-34 es que el destino no los verifica. Arreglar P-14 sin P-34 produce un
  registro más rico de una orden que sigue sin prueba.

No se ha ejecutado una PoC de slash fabricado porque el propio test M7d ya
documenta que el transporte no comprueba la verdad y porque el manager real
requiere un `NOTIFIER` y un `slashAuthority` configurados; la lectura del flujo
es suficiente para el hallazgo. Si se quiere una PoC end-to-end, el caso es:
`notify({validator: alice, epoch: 0, ingestionDigest: 0x…01, publishedWad: 2,
formulaWad: 1})` desde `NOTIFIER`, y comprobar que `alice` queda con
`stakeOf == 0` y `isAdmitted == false` sin ninguna prueba de inclusión.

### Remediación propuesta (no implementada)

1. **Prueba on-chain o ventana optimista.** O el destino verifica una prueba de
   inclusión de la hoja y re-ejecuta `f_c` (caro pero verificable), o el slash se
   encola y se ejecuta tras una ventana de impugnación con un bono; en ambos
   casos el `reason` debe comprometer `(ingestionDigest, epoch, publishedWad,
   formulaWad)`.
2. **Alcance temporal.** Rechazar `notification.epoch` fuera de
   `[latestEpoch − WINDOW, latestEpoch]` y exigir que el validador estuviera
   admitido en esa época. Sin esto, una notificación vieja con nonce nuevo sigue
   pasando.
3. **Limitar el daño.** Si se mantiene el rol, un cap por época y por validador,
   una ejecución diferida y un `NOTIFIER` multisig/contrato con quórum, no una
   EOA. Declararlo en §Limitations y en el README como trust anchor.
4. **No confundir procedencia con verdad.** La allowlist de Teleporter prueba que
   el mensaje vino de `(sourceChain, originSender)`; no prueba que el payload sea
   un `Verdict::Fraud`. El test debe separar las dos cosas.

### Criterio de cierre

- Test 1: un payload fabricado con `publishedWad != formulaWad` pero sin prueba
  **no** reduce `stakeOf` (hoy lo hace; el test debe documentar el estado actual
  y, tras el cambio, fallar).
- Test 2: una notificación con `epoch` fuera de ventana revierte.
- Test 3: una notificación para un validador no admitido en esa época revierte.
- Test 4: con `NOTIFIER` comprometido, el máximo slasheable por época está
  acotado y el evento incluye los cuatro campos de P-14.
- Documento: §Limitations nombra el rol y su poder; el README deja de presentar
  el transporte como “soundness lives elsewhere” sin decir que el destino confía
  en el notifier.

---

## P-35 — La frontera de detección no es Kesten–Stigum y la densidad 3× evade el test

**Severidad provisional:** **Alta** (paper; resultado negativo que invalida una
frase de alcance).
**Estado:** Confirmado con una réplica propia de 300 réplicas por configuración
(fuente `pocs/new/CollusionDensityProbe.py`, log `logs/collusion-density.txt`).
**Ubicación:** `main.tex:780-786` (frontera), `main.tex:1392` (Kesten–Stigum),
`main.tex:752` (FPR=1.0 en Chung–Lu), `verification/rmt/calibration_modularity.py`
(`density_factor=10` por defecto), `src/rmt/src/graph.rs::sbm_cliques` (10×
hardcodeado).

### Qué dice el paper y qué se midió

El paper sólo mide `10×` de densidad intra-clique (`main.tex:744-760`) y concluye:

> “Configurations below `m=20` were not simulated; the boundary at which
> detection degrades is below the tested range.” (`main.tex:780-786`)

y en las conclusiones:

> “the theoretical Kesten–Stigum threshold ... is below the tested range.”
> (`main.tex:1392`)

La segunda frase es el marco equivocado. Kesten–Stigum describe la recuperación
de comunidades de tamaño **lineal** en `n`; aquí `m ≈ 20` sobre `n = 500` es una
comunidad de tamaño constante. El umbral relevante es el de detección espectral
(BBP, Baik–Ben Arous–Péché): `θ = m(p_in − p_0) ≈ √(σ² n)`. Con
`p_0 = 20/500 = 0.04` y `10×`,
`θ = m·0.36`; `θ ≈ 4.38` da `m ≈ 12.2`, y el informe sitúa la potencia del 50 %
en `m ≈ 15.4` (cifra del informe; la sonda de esta sesión mide los puntos de la
tabla, no ese intermedio). A `3×`, el mismo `θ` exige `m ≈ 4.38/0.08 ≈ 55`: por
eso un bloque de 40 a `3×` está por debajo de la frontera aunque `m > 20`. La frase “la
frontera está por debajo del rango probado” sólo es cierta para `10×`; no es una
propiedad de `m` sola.

La tabla siguiente es la réplica propia (300 réplicas por configuración, umbral
nulo `q99 = 9.0469` medido con 1.000 réplicas, semilla 20261021; IC95 aproximado
±0,06). La segunda columna de TPR es la del informe externo, que usó 1.500
réplicas para el nulo; se incluye para que la diferencia quede registrada, no
para promediar dos calibraciones distintas:

| Configuración | θ | TPR @ 0.01 (esta réplica) | TPR @ 0.01 (informe) |
|---|---:|---:|---:|
| 1 bloque, `m=20`, 10× | 7.21 | 0.980 | s.d. |
| 1 bloque, `m=24`, 5× | 3.85 | 0.067 | 0.120 |
| 1 bloque, `m=30`, 5× | 4.81 | 0.290 | 0.350 |
| 1 bloque, `m=40`, 3× | 3.21 | 0.057 | s.d. |
| 5 bloques, `m=12`, 10× | 4.33 | 0.480 | 0.603 |
| 10 bloques, `m=10`, 10× | 3.61 | 0.387 | 0.473 |

Las diferencias de TPR **no son contradicción**: el `q99` del nulo estimado con
1.000 réplicas frente a 1.500 desplaza todos los TPR a la vez. Con intervalos de
±0,06, la diferencia más marcada es la de 5×12 (0,480 frente a 0,603); las
conclusiones cualitativas coinciden. Para el paper se debe reportar el TPR con
su intervalo y el `q99` **fijado** en una sola calibración, no mezclar las dos.

El punto material: **40 coludidos (8 % de `n=500`) con densidad 3× pasan casi
indetectados (`TPR ≈ 0.06`)**. El paper sólo prueba 10×, donde `m=20` da 0.972.
No es que la frontera esté “por debajo de 20”; es que depende de `θ` y la
densidad no se barrió. La hipótesis del informe de que partir la colusión en
varios bloques evita el test **no** se confirma: los bloques múltiples
subcríticos aumentaron la detección (0.480 y 0.387), no la redujeron; el límite
sigue siendo `θ`. El umbral a 3× es `m ≈ 55` con `θ* = 4.38` y
`p_in − p_0 = 0.08`; la cifra se reproduce, no es una estimación aparte.

### Consecuencia

- La afirmación “Detection is uniform across the five configurations” es cierta
  sólo para las cinco configuraciones medidas, todas a 10×; no se extiende a
  densidades menores.
- La defensa de respaldo en colas pesadas es el piso financiero (P-28), no el
  test espectral; el paper ya lo dice para Chung–Lu (`main.tex:752`), pero no
  para el caso ER con densidad baja.
- El grafo `W` sigue siendo externo (P-27); este hallazgo es sobre la potencia
  del detector, no sobre su fuente.

### Remediación propuesta

1. Sustituir “Kesten–Stigum boundary” por el umbral BBP/`θ` y decir que es una
   frontera de **detectabilidad**, no una garantía.
2. Añadir a `calibration_modularity.py` un barrido de `density_factor ∈
   {3,5,10}` y una tabla TPR a `m` fijo y a `θ` fijo, con IC y un `q99` fijado
   en una sola calibración; la tabla de P-35 es el mínimo que el paper debe
   reproducir.
3. Rebajar la frase de `main.tex:780-786`: “uniforme en el rango probado, que es
   sólo 10×; a 3× un bloque de 40 no se detecta”.
4. Si el piso financiero es la defensa para `θ` bajo, decirlo en la misma
   sección y cuantificarlo con P-28; no dejar que el lector infiera una garantía
   espectral.
5. Pasar `density_factor` a `Graph::sbm_cliques` (hoy fija 10×) para que el test
   de Rust pueda reproducir el barrido, o dejar el barrido sólo en Python y
   declararlo.

### Criterio de cierre

- `main.tex` no contiene “Kesten–Stigum” como explicación de esta frontera, o lo
  cita correctamente y explica por qué no aplica a `m` constante.
- El script reproduce la tabla de arriba con una semilla, un `N_H1` y un `q99`
  declarados; el TPR se reporta con su intervalo, no sólo como punto.
- La frase “uniforme” está acotada a 10× y la tabla de densidad aparece en el
  paper o en un apéndice reproducible.

---

## P-36 — Bibliografía: Bauer–Jost mal citado y referencias faltantes

**Severidad provisional:** Baja (paper).
**Estado:** Confirmado con arXiv y Crossref.
**Ubicación:** `main.tex:1624` (`bauer2012`), `main.tex:84,132,514,1392`
(referencias sin `\cite`), `main.tex:1623-1643` (bibliografía).

### El error confirmado

La entrada actual dice:

```bibtex
@article{bauer2012,
  author  = {F. Bauer and J. Jost},
  title   = {Bipartite and neighborhood graphs and the spectrum of the
             normalized graph Laplacian},
  journal = {Communications on Pure and Applied Mathematics},
  year    = {2012}
}
```

Los metadatos correctos son:

- **Título:** “Bipartite and neighborhood graphs and the spectrum of the
  normalized graph Laplace operator” (no “Laplacian”).
- **Revista:** *Communications in Analysis and Geometry* (no CPAM).
- **Volumen/número/páginas:** 21(4):787–845, 2013.
- **DOI:** `10.4310/cag.2013.v21.n4.a2`.
- **arXiv:** `0910.3118`; la v4 (21 feb 2012) dice “final version that will
  appear in Communications in Analysis and Geometry”.

La búsqueda del informe sólo confirmó el preprint; Crossref confirma la revista,
volumen y páginas. El título con «Laplacian» es el del preprint de arXiv; la
entrada bibliográfica debe usar el título publicado con «Laplace operator». La
entrada debe corregirse, no sólo el año.

### Otras inconsistencias y faltantes

- `chung2003` tiene clave de 2003 pero la entrada dice 2002 (PNAS
  99(25):15879–15882, 2002). La clave puede quedarse por compatibilidad, pero el
  año de la entrada es el que manda; conviene renombrar a `chung2002` en el mismo
  cambio.
- **Kesten–Stigum** se usa como marco en `main.tex:84` y `1392` sin `\bibitem`.
  P-35 explica además por qué no es el marco correcto para este régimen.
- **Feller** se usa en `main.tex:132,151,171,239` sin cita; si se mantiene la
  condición, necesita una referencia estándar (p. ej. el texto de Øksendal que ya
  está en la bibliografía, o una referencia de procesos de difusión).
- **EIP-196/EIP-197/EIP-1108** se citan por número en `main.tex:514,1266-1286`
  sin URL ni `\bibitem`; para una afirmación de gas “to the gas unit” conviene
  una referencia normativa.
- El umbral **BBP** que P-35 introduce no está en la bibliografía; si se usa,
  hay que citar la transición de Baik–Ben Arous–Péché (BBP) o el resultado de
  detección espectral que se use (para SBM, Mossel–Neeman–Sly), en vez de dejar
  “BBP” como una sigla sin fuente.

No se ha hecho una revisión bibliográfica completa: el informe externo dice que
quedan “errores de entradas” en las líneas 1562–1646 que no repite. Esta sección
registra **sólo** lo confirmado localmente (Bauer–Jost y `chung2003`) y los
faltantes que se ven en el texto. La lista del informe debe contrastarse entrada
por entrada antes de cerrar P-36.

### Remediación

1. Corregir `bauer2012` con los metadatos de Crossref/arXiv; añadir DOI.
2. Corregir el año/clave de `chung2003` o justificar la clave.
3. Añadir `\bibitem` para Kesten–Stigum, Feller, EIP-196/197/1108 y BBP, o
   eliminar la mención si no se usa.
4. Recompilar `main.tex` y comprobar que no hay citas indefinidas ni entradas sin
   usar.
5. Contrastar la lista completa del informe (líneas 1562–1646) antes de declarar
   cerrado el hallazgo.

### Criterio de cierre

- `bauer2012` coincide con Crossref (`10.4310/cag.2013.v21.n4.a2`).
- No hay `\cite` sin `\bibitem` ni `\bibitem` sin `\cite`.
- Cada resultado nombrado (Kesten–Stigum, Feller, EIP, BBP) tiene cita o se ha
  retirado.
- La compilación no emite “Citation undefined”.

---

## P-37 — La permutación Poseidon coincide con circomlib; el digest de la esponja no

**Severidad provisional:** Baja (interoperabilidad/reproducibilidad; **no** es un
fallo de soundness ni un defecto del circuito).
**Estado:** Confirmado con una sonda temporal: dos vectores t=3 de circomlib,
absorción multi-bloque para 1–10 y 500 entradas, y ambigüedad de longitud sin
etiqueta documentada.
**Ubicación:** `src/zk/src/native.rs:164-199` (`poseidon_params`,
`poseidon_commitment`); `PoseidonSponge` de `ark-crypto-primitives 0.6.0`;
tests existentes `native.rs:511-537`; `main.tex:93,529,552` (afirmación
“Poseidon-sponge”).

### Qué se contrastó

La sonda construye la permutación con los `ark`, `mds`, `alpha` y rondas que
devuelve `poseidon_params()`, y compara dos vectores públicos de circomlib
(`test/poseidoncircuit.js`, t=3):

| Entradas | Vector de circomlib | `state[0]` de la permutación | Digest de la esponja |
|---|---|---|---|
| `[1, 2]` | `7853200120776062878684798364095072458815029376092732009249414926327459813530` | **coincide** | `7142104613055408817911962100316808866448378443474503659992478482890339429929` |
| `[3, 4]` | `14763215145315200506921711489642608356394854266165572616578112107564877678998` | **coincide** | `17463678829190627617464904566380183791916908580219504546165890868928721427440` |

La permutación t=3 que produce `poseidon_params()` reproduce exactamente ambos
vectores; con `α = 5`, `Rf = 8` y `Rp = 57`, las constantes son compatibles con
la instancia de circomlib. La diferencia no está en la permutación ni en las
constantes, sino en **qué elemento del estado se publica**:

- circomlib `Poseidon(2)` inicializa `[initialState, in0, in1]` y devuelve
  `state[0]`, que es el elemento de **capacidad**;
- `PoseidonSponge` de arkworks usa `[capacity, rate0, rate1]`, absorbe en
  `capacity..` y `squeeze` devuelve el primer elemento de **rate**, es decir
  `state[1]`.

La convención del repo es, si acaso, la **más ortodoxa** de las dos para una
esponja: extrae del rate y reserva la capacidad. **No es un defecto del circuito
ni una desviación criptográfica**; es una diferencia de convención de salida. El
circuito y el cálculo nativo usan la misma esponja de arkworks, así que
`PoseidonNormCircuit` sigue siendo consistente: el test
`poseidon_circuit_is_satisfied_at_the_true_digest` lo comprueba. Lo que no hay
es **interoperabilidad de digest** con el hash de circomlib.

La sonda también reimplementa el bucle de absorción (bloques de `rate = 2`, sin
relleno) y lo compara con `PoseidonSponge` para longitudes 1–10 y 500: coincide
en los 11 casos. La ruta del protocolo usa exactamente 500 entradas, es decir
250 bloques completos: no depende de relleno. Esto no es un vector externo de
500 —no existe un `Poseidon(500)` estándar en circomlib—, pero descarta un error
del bucle de absorción multi-bloque de la implementación.

La misma sonda documenta la **ambigüedad de longitud** que deja la ausencia de
etiqueta: `poseidon_commitment(&[5])` y `poseidon_commitment(&[5, 0])` producen
el mismo digest, porque la absorción es aditiva y no hay relleno. En la ruta del
protocolo no aplica (500 entradas fijas), así que **no se eleva a hallazgo**; es
la razón concreta por la que la separación de dominio queda como cobertura
pendiente y no como una propiedad cubierta.

### Consecuencia

- **La esponja de 500 entradas no tiene equivalente canónico en circomlib**: no
  existe un `Poseidon(500)` estándar. La compatibilidad de digest sólo sería
  relevante para primitivas de **2 entradas** (hojas o nodos de Merkle) o si un
  consumidor externo previsto usara circomlib. Hoy no hay tal consumidor
  declarado en el repo ni en el paper.
- Si apareciera ese consumidor, una reproducción con `circomlibjs`/`circomlib`
  obtendría un root distinto para esas primitivas de 2 entradas. Lo mismo vale
  para un verificador o un árbol de Merkle que use circomlib y para el que el
  `statement_root` de V3 sea una entrada.
- El paper dice “Poseidon-sponge” y no afirma compatibilidad con circomlib; aun
  así, la frase “the widely deployed BN254 Poseidon instance” del comentario de
  `native.rs` puede leerse como compatibilidad de hash. Hay que cualificarla.
- No hay ruptura de soundness ni de completitud **dentro** de V3: el compromiso
  es el que el circuito prueba, y el bridge lo recalcula con la misma función.
- **Re-pinnear no se justifica por el protocolo interno.** Fixtures, roots y
  ancla sólo se regeneran si se adopta un consumidor circomlib; por defecto,
  P-37 se cierra como nota de documentación.

### Remediación propuesta

1. Documentar en `native.rs`, el plan y el paper que la **permutación** es la de
   circomlib t=3, pero el **digest** es el de la esponja de arkworks
   (`rate = 2`, `capacity = 1`, salida en `state[1]`, el rate), no el `state[0]`
   (la capacidad) de circomlib. Decirlo como convención válida y más ortodoxa,
   no como defecto. Si no se añade etiqueta de dominio/longitud, la ruta de
   protocolo debe imponer en código las 500 entradas (API específica o aserción
   en la llamada), no sólo documentarlo; el uso de 8 entradas de `m4b` es un
   smoke test, no la ruta de commitment.
2. **No re-pinnear por defecto.** Si y sólo si aparece un consumidor externo de
   primitivas de 2 entradas con circomlib, añadir una función explícita
   `poseidon_circomlib` que devuelva `state[0]` y re-pinnear fixtures, roots,
   `M4bGroth16Fixtures`, `M7cBridgeFixtures` y el ancla; no cambiar sólo la
   salida de `poseidon_commitment` sin regenerar todo.
3. Añadir un test permanente con los dos vectores de la tabla y con la
   comprobación de absorción 1–10/500: uno para la permutación (debe coincidir
   con circomlib) y otro para el digest (debe fijar la convención de la
   esponja). Hoy la sonda es evidencia, no test permanente.

### Criterio de cierre

- El paper/plan/README no afirman interoperabilidad con circomlib sin decir que
  el digest es el de la esponja de arkworks y que la esponja de 500 no tiene
  equivalente circomlib.
- Hay un test permanente que fija la permutación contra circomlib, la absorción
  1–10/500 y la salida de la esponja contra un valor pineado.
- Si no se añade etiqueta de dominio/longitud, la restricción de 500 entradas
  está también en código en la ruta de protocolo; el worksheet no es la única
  barrera.
- No se re-pinnearon fixtures, roots ni ancla sin un consumidor circomlib
  declarado. Si se adopta la variante circomlib, se regeneran y se revisa el
  diff; no se declara cerrado con un cambio de una línea en `squeeze`.

### Errata de documentación (v0.2.1)

- **E-01 — `docs/paper/releases/v0.2.1-notes.md:72`.** La línea decía «OTS: 4
  pending attestations, `.ots` sha256 `1bdfcbbf…`». El recibo con ese hash
  (739 B, target `adfd08d2…`) contiene **3** `PendingAttestation` (alice,
  finney y catallaxy) y **0** `BitcoinBlockHeaderAttestation`; `ots info` no
  muestra la de bob. La cifra «4» es incompatible con el hash citado. La línea
  reproduce `docs/audit/sessions/S-014.md:35`, que registró 4 al sellar;
  `S-015.md:20` ya documenta que `ots upgrade` vio tres calendarios y que el
  `.ots` no cambió (`S-015.md:28`, mismo hash), así que ambos registros de
  sesión no son consistentes. El recibo actual con ese hash resuelve el estado
  en 3. El `.bak` local (ignorado por `.gitignore:38`; 910 B, target
  `5d6002ba…`) sí tiene 4 (alice, bob, finney y catallaxy), pero es otro recibo
  y otro root. **Corrección aplicada** en la
  nota visible («3 pending attestations»), con puntero en
  `docs/paper/releases/README.md` y nota en la
  checklist de Zenodo; no se reexporta el PDF, no se mueve el ancla ni el
  recibo. La fuente inmediata es `S-014`, no el `.bak`; `S-014` y
  `anchor-receipts.md` conservan el 4 histórico.

---

## P-38 — La prueba de admisión oculta la posición de la hoja y nada más

**Severidad provisional:** Media (diseño y honestidad del artefacto; **no** es un
fallo de soundness y no permite a nadie admitirse sin estar en el árbol).
**Estado:** Confirmado por lectura (`admission.rs:212-276`) y por medición
(`test/M4dRealKey.t.sol`).
**Ubicación:** `src/zk/src/admission.rs:212-276`;
`integrations/avalanche/contracts/AVIPRegistry.sol:327` (`verifyEntry`);
`AVIPValidatorManager.admit`; plan §5.5.11.

### Qué se comprobó

Los cuatro elementos del statement —`statementRoot`, `epoch`, `validator`, `norm`—
son entradas públicas (`admission.rs:213-216`), y el testigo es el índice de hoja
más nueve hermanos (`admission.rs:204-206`, `251-264`), ambos derivables por
cualquiera que tenga la época. Lo único que el proof no revela es **la posición**
de la hoja. El propio circuito lo dice (`admission.rs:247`: «the proof says "this
(validator, norm) pair is in the committed tree", not "I know a secret score"»).

El coste tampoco lo justifica. `AVIPRegistry.verifyEntry` ya verifica una inclusión
keccak, `public pure`, para un número arbitrario de niveles: nueve hashes de 64
bytes cuestan unos pocos miles de gas, frente a los **306,275** fríos y **247,233**
calientes que mide `verifyThreshold` con la clave real (**234,284** en `verify`).
Un árbol Poseidon en EVM quedaría en el orden de Groth16, no por debajo, así que
la ruta barata es keccak — y ya existe en el contrato.

### Consecuencia

- M4d **cierra P-01**: el proof deja de ser un bearer token, admite exactamente una
  dirección y la ata a la época (`M4dRootSeparation.t.sol`).
- Pero no compra lo que el paper vende: la norma sigue siendo la que el
  secuenciador escribió en las entradas y **ninguna parte on-chain la liga al
  tensor** (P-03; `M4dRootSeparation.t.sol` fija esa ausencia como prueba). La
  confianza en el secuenciador queda como en un sistema sin ZK.
- Presentar la admisión como «norma de Frobenius certificada por prueba» es
  incorrecto en HEAD.
- El conflicto de comentarios está cerrado por la decisión de P-03 (2026-10-22):
  `commitment.rs` dice ahora `r = T(i)` y nombra `‖T‖_F` como magnitud de
  auditoría; `AVIPValidatorManager.sol:181` dice lo mismo y añade que el suelo
  efectivo sobre el dominio admitido es `Θ − C_R(1) = 0.6`, no `S_min = 0.2`.
  El límite `< WAD` del circuito coincide con esa lectura y excluye la global
  para el fixture real (12.79).
- **Nada impone una hoja por validador.** Ni el circuito ni el registry impiden
  que el secuenciador publique la misma dirección dos veces con normas distintas
  en el mismo epoch; el prover elige la hoja que le conviene y la prueba es
  válida para esa hoja. La unicidad es otra propiedad del epoch off-chain, del
  mismo tipo que la ligadura entre las dos raíces: `freshness_ok` cuenta entradas
  cambiadas, no direcciones repetidas (P-12 lo registra en el génesis de 501
  hojas). Queda escrito como propiedad off-chain en `admission.rs` y en
  `contracts/README.md`, no como restricción.

### Remediación propuesta

1. Decirlo en §5.5.11 y en el paper: la prueba aporta **pertenencia con posición
   privada**, más los atados de validador y época; no confidencialidad de la norma
   ni ahorro de gas.
2. Si el criterio es coste, admitir con `verifyEntry` sobre
   `commitmentOf(epoch)` y la hoja `keccak256(abi.encodePacked(validator, norm))`
   —sin código nuevo— y reservar Groth16 para el statement del tensor.
3. Si el criterio es confidencialidad, la norma tiene que dejar de ser un input
   público; hoy la prueba no la oculta porque no hay nada oculto.
4. El vínculo real es §5.5.7 (el compromiso como input del circuito). Allí el
   obstáculo es P-03 —qué es `T` por validador—, no el coste: V3 ya plegó 500
   entradas con 94,438 restricciones y 3.9 s.

---

## Cobertura y alcance pendiente

**Leído completo en esta pasada:** `AVIPRegistry`, `AVIPValidatorManager`,
`AVIPStakeVault`, `AVIPBurnSink`, `Groth16Verifier`, `Bn254`,
`AVIPMessageEndpoint`, `AVIPCommitmentRelay`, `AVIPCollusionAlertChannel`,
`AVIPSlashingChannel` y `AVIPMessageCodec`; el circuito nativo
(`src/zk/src/native.rs`, `groth16.rs`, `bridge.rs`) y sus tests; el data layer
(`commitment.rs`, `equilibrium.rs`, `ingestion.rs`, `binomial.rs`); la economía
`C_R`/`WAD` (`src/reputation/src/{cr,wad,commitment}.rs`); el detector RMT
(`detector.rs`, `spectrum.rs`, `graph.rs`); y los scripts de despliegue
principales (`DeployCommon`, `DeployRegistry`, `DeployStakeVault`,
`DeployValidatorManager`, `DeployFujiPhase1`). También se leyeron las
interfaces y los mocks usados como evidencia. En esta segunda pasada se
revisaron además `stationary_stats.py`, `cr_ide_solver.py`,
`simulate_bootstrap_net_gain.py`, `m05_attack_model.py`, `tucker_analysis.py`,
los fixtures M7c/M4b y la ruta de gas del verificador.

En esta continuación se leyeron línea a línea los scripts individuales de
despliegue (`DeployRegistry`, `DeployStakeVault`, `DeployValidatorManager`,
`DeployBurnSink`, `DeployMockToken`) y el runbook `DeployFujiPhase1`, además de
los tres canales de transporte y el verificador. De ahí sale P-26. También se
revisó la procedencia de la clave: la única clave del árbol es la de desarrollo
de M4b, con `SETUP_SEED` público y toxic waste derivable; no hay ceremonia,
`.circom`, `.r1cs`, `.zkey` ni `.ptau`, y el paper ya declara que el verificador
on-chain no está desplegado. Eso no es un hallazgo nuevo: es una limitación de
alcance que impide tratar la clave como una clave de producción.

En la lectura del data layer se cerró además el addendum de P-12: `Epoch::new`
no exige `N` ni unicidad y `changed_entries` colapsa las hojas duplicadas, de
modo que `freshness_ok` acepta un génesis de 501 hojas y un epoch de 1.000
hojas duplicadas con `changed == 0`. La PoC está en
`pocs/new/TmpEpochShape.rs` y el log en `logs/epoch-shape.txt` (2 PASS). No es
un ID nuevo: el contrato ya sólo ve el contador declarado (P-12); lo que faltaba
era que el propio data layer tampoco imponía la forma que su comentario declara.

La segunda lectura añadió P-27…P-33. No fue una revisión bibliográfica: P-31
se limita a registrar que la premisa PoW de `main.tex:56` no tiene cita y que la
literatura de reputación en PoS citada es escasa; no se leyó ni se contrastó la
bibliografía completa. P-27 se confirmó en código y paper, no con una ejecución
del detector sobre un grafo real; P-33 sí se confirmó con una sonda del circuito
(1 PASS).

La tercera lectura (informe externo completo) añadió P-34 (slash cross-chain sin
verificación), P-35 (frontera de detección por densidad) y P-36 (bibliografía).
P-35 se confirmó con una réplica propia de 300 réplicas por configuración; P-34
se confirmó por lectura del canal, del codec y del propio test M7d; P-36 se
confirmó con arXiv/Crossref. La sonda de cierre de Poseidon añadió P-37: la
permutación coincide con circomlib, el digest de la esponja no; la absorción
multi-bloque se comprobó para 1–10 y 500 entradas. La **separación de dominio**
del commitment (sin etiqueta de dominio ni longitud) no se cubrió y se registra
como cobertura pendiente, no como hallazgo. El resto del informe se reconcilió
con IDs ya existentes en la tabla de la tercera lectura; no se duplicaron P-04,
P-05, P-06, P-08, P-13, P-14, P-17 ni P-27.

**Lo que sigue fuera de esta pasada, y no debe presentarse como cubierto:**

- **Soundness formal del circuito, trusted setup y ceremonia.** Se revisó la
  aritmética de `enforce_floor_norm` (cotas de 60/64/130 bits) y que el wrapper
  liga `epoch`; no se hizo una prueba formal ni una revisión criptográfica
  independiente. No hay `.circom`/`.r1cs`/`.zkey`/`.ptau` en el árbol: el
  circuito es Rust (`ark-r1cs`) y la clave de M4b es de **desarrollo**, con
  `SETUP_SEED` público y toxic waste derivable; el paper ya dice que el
  verificador on-chain no está desplegado. P-08 es un defecto del wrapper, no
  una auditoría de la ceremonia.
- **Data availability / almacenamiento.** Se revisaron `commitment.rs` y la
  ruta del bridge: el repo implementa una convención de commitment y un bridge
  recomputable, pero **no** una capa de disponibilidad, retención ni recuperación
  del tensor. No hay una garantía implementada que auditar; es un hueco de
  implementación y debe declararse como tal en paper/plan, no como una propiedad
  cubierta.
- **Reproducción numérica externa completa.** Se re-ejecutaron
  `stationary_stats.py`, `simulate_bootstrap_net_gain.py`,
  `tucker_analysis.py` (200 sorteos propios), la fórmula de `m05_attack_model.py`
  y mediciones de gas con `gasleft()`; no se corrió la suite numérica entera del
  paper (~67 min) ni se re-derivaron todos los outputs sellados fuera de los
  fixtures ya pineados. La réplica de densidad de P-35 sí se ejecutó (300
  réplicas por configuración) y su log está en `logs/collusion-density.txt`.
- **Cadena OpenTimestamps.** El recibo **vigente**
  `verification/anchor_root.sha256.ots` (sha256 `1bdfcbbf…`, 739 B) compromete el
  root actual (`adfd08d2…`) y contiene **tres** `PendingAttestation`, no cuatro
  (ver **E-01**): alice, finney y catallaxy. No contiene ninguna
  `BitcoinBlockHeaderAttestation`.
  El `.ots.bak` (sha256 `f6209374…`, 910 B; target `5d6002ba…`) sí tiene cuatro
  pendientes (alice, bob, finney, catallaxy), pero compromete un root anterior y
  **no cubre el ancla vigente**. `ots verify` resuelve el target y no reporta
  `File does not match`; no completa la verificación por falta de nodo Bitcoin
  local. Como el
  recibo vigente no tiene ninguna `BitcoinBlockHeaderAttestation`, la cadena
  Bitcoin no está cerrada. El ancla y el manifiesto sí se comprobaron con
  `verification/fase0_anchor.sh --check` (exit 0) y `sha256sum -c
  verification/anchor_root.sha256` (exit 0). No se ejecutó `ots upgrade` ni se
  modificó el recibo.
- **Nivel de seguridad de BN254.** Se comprobó que `main.tex` **no declara** un
  nivel de seguridad para BN254; el paper sólo cita BN254 como curva de Groth16
  y mide gas. No se cuantificó el nivel (~100 bits según las estimaciones
  estándar de NFS/sexTNFS para BN254) ni se añadió una fuente. No se eleva a
  hallazgo hasta verificarlo; si se cita una cifra, debe llevar fuente.
- **Separación de dominio del commitment Poseidon.** `poseidon_commitment`
  absorbe sólo las entradas: **no hay etiqueta de dominio ni de longitud**. En
  la ruta del protocolo la longitud es fija (500 = 250 bloques de `rate = 2`),
  así que la ambigüedad no aplica; pero la API pública acepta cualquier `&[u64]`
  y `m4b` usa 8 entradas en su smoke test. La sonda **sí demostró una colisión
  trivial de longitud**: `poseidon_commitment(&[5]) ==
  poseidon_commitment(&[5, 0])`, porque la absorción es aditiva y no hay
  relleno. No se demostró que esa colisión alcance la ruta on-chain de 500
  entradas, y por eso **no se eleva a hallazgo en esta ronda**. Queda relevante
  para P-16, donde el mismo slot `_roots[epoch]` se lee como root Poseidon y
  como root keccak. Cierre mínimo: o se documenta **y se hace cumplir en la
  ruta de protocolo** que la función sólo admite 500 entradas, o se añade una
  etiqueta de dominio/longitud y un test que muestre digests distintos para
  dominios distintos; la segunda opción exige re-pinnear.
- **Revisión línea a línea de todos los tests, mocks y scripts M7c/M7d/M8.** Se
  usaron como evidencia y se leyeron los relevantes; no se auditó cada assert,
  helper ni transcript.
- **Operación, upgrades, gobernanza e incident response más allá de
  P-05/P-10/P-26.** No hay path de upgrade; el addendum de P-10 documenta que el
  guardian es inmutable y que una clave perdida/comprometida se responde con un
  redespliegue, no con una rotación on-chain. P-26 cubre los guards de los
  scripts, no la operación real: no se revisaron runbooks, multisig/threshold,
  key management, planes de migración ni un procedimiento de incidentes.
- **Análisis económico externo y fuzzing/invariants.** Las fórmulas `C_R`,
  `S_f*`, `F_0`, la freshness y el equilibrio se contrastaron con el paper y sus
  tests; no se hizo un modelo económico independiente. Los 7 tests `testFuzz`
  existentes se corrieron a 5.000 runs cada uno (0 fallos), pero no hay
  `invariant_*` ni una campaña de estado con acciones aleatorias; el test
  `test_invariant_isAdmittedImpliesBackedAcrossTheWholeLifecycle` es dirigido y
  no cubre esa laguna.
- **Diff del rediseño P-01/P-16.** El statement
  `[root, epoch, validator, certifiedNorm]` está diseñado, no implementado. No
  hay todavía diff del circuito ni de `ic` que revisar. Cuando exista, se revisa
  contra la checklist de P-16 («Diseño conjunto con P-01») y el criterio de
  aceptación de P-01 («Remediación propuesta»); hasta entonces no se puede
  declarar cerrado P-01.

## Orden de reparación propuesto

1. **P-16 + P-01 como un solo rediseño** (compromiso por validador, una raíz
   canónica, `validator` constreñido en el circuito) y después **P-17**
   (recertificación): son arquitectura; sin ellas no hay v1 que pueda llamarse
   “admisión + fraud proof”. No implementar P-16 y P-01 en dos cambios de
   statement separados.
2. **P-27** (conectar o declarar `W`), **P-19** (agregador), **P-18**
   (bounty) y **P-34** (slash sin prueba): cierran el modelo de defensa/económico
   que el paper presenta como operativo. P-27 es de diseño: o se declara `W`
   externo en Limitaciones, o se define `T → W` y la ruta de respuesta; no se
   inventa una proyección. P-34 es la confianza que hoy no se declara: o se
   verifica el fraude en destino, o se acota y se documenta el rol.
3. **P-20/P-21/P-28/P-30/P-31/P-35**: afirmaciones del paper que no deben ir a
   arXiv sin cualificar. P-28 (piso `0.2Θ`), P-30 (unidades temporales), P-31
   (premisa PoW) y P-35 (frontera de detección) son de texto/economía;
   P-20/P-21 son numéricas.
4. **P-22/P-23/P-24/P-25/P-29/P-36/P-37**: consistencia, erratas, bibliografía,
   convención Poseidon y documentación; después de las anteriores. P-29 es
   README, no paper; P-37 es una cualificación de `native.rs`/paper, no un
   cambio de circuito.
5. P-33 (cota por entrada del circuito), P-32 (ventana de época en `admit`) y
   P-02, P-03, P-05, P-12, P-13, P-14 y P-08/P-09/P-10/P-11/P-15 se mantienen
   en la lista de reparaciones de código/tests; no cambian el orden de lo
   anterior. P-33 exige recompilar y re-medir si cambia el circuito; P-32 debe
   resolverse junto con el binding al validador de P-01. P-05 es además un
   requisito de despliegue para mainnet. P-26 es un arreglo de scripts/tests de
   despliegue: no toca el protocolo, pero debe cerrarse antes de reutilizar el
   runbook.

### Disposición y criterio de cierre (P-27…P-37)

Ninguna fila de esta tabla está implementada. La columna «Cierre verificable» es
el mínimo para pasar de **confirmado** a **remediado**; no sustituye la revisión
del diff ni la re-medición.

| ID | Disposición | Cambio mínimo | Cierre verificable |
|---|---|---|---|
| P-27 | Paper + plan (diseño) | Declarar `W` externo en §Collusion y §Limitations, o definir `T → W` y la ruta de respuesta; si no se alimenta, retirar «protocol» para la detección | §Collusion nombra la fuente de `W` y un lector no puede inferir que `T` la produce; si se define, hay ingesta y test de esa ruta, no una proyección heurística |
| P-28 | Paper (economía) | Sustituir «guarantee against a heavy-tailed collusive core» por «minimum admission cost»; añadir `S_min = 0.2Θ`, el factor 5× frente a PoS puro y el barrido de `C_R^∞` | No queda una frase que prometa seguridad por `S_min`; el texto distingue coste de admisión, coste de adquisición de reputación y coste de ataque |
| P-29 | README | Sección «Trust assumptions (v1)»: sequencer único, `slashAuthority` único, `NOTIFIER` único, guardian + `CHANGE_DELAY`, verificador mutable y clave de desarrollo | El README no usa «trustless» sin enumerar esos supuestos y enlaza a P-01/P-10/P-14/P-34; el verificador no se presenta como producción |
| P-30 | Paper + script | Definir `T_e` y si `π_val`, `ω` y `k` son por epoch o anuales; recalcular `F_0*` y `g*` con esa convención | Tabla de unidades; `financial_floor_sensitivity.py` recibe `T_e` y reproduce los números; el texto no mezcla flujo por epoch con pago único de gas |
| P-31 | Paper | Citar literatura de descentralización PoW o eliminar la premisa causal; ampliar la bibliografía de reputación en PoS o declarar que no se usa | La frase de `main.tex:56` tiene cita o desaparece; la introducción no atribuye a PoW una garantía que el modelo no usa |
| P-32 | Código + docs | Añadir `epoch` a `admit`, ventana `epoch + WINDOW >= latestEpoch()`, `epoch > lastAdmittedEpoch[validator]` con `hasAdmitted` para el génesis y el binding a validador de P-01; si no se implementa, declarar la ventana como confianza en el sequencer | Test: proof de época reciente pasa; proof fuera de ventana revierte; proof vieja del mismo validador no re-admite; proof de otro validador falla; `epoch = 0` no queda bloqueado |
| P-33 | Circuito + tests | Constreñir `entry ≤ WAD` además de `< 2^ENTRY_BITS`; rechazar en `allocate_entry_bits` en vez de truncar | Tests `WAD` pasa, `WAD + 1` revierte, `2^60 − 1` revierte; recompilar, remedir constraints/gas y re-anclar |
| P-34 | Código + docs | O prueba on-chain/ventana optimista con `reason` que comprometa los cuatro campos, o declarar `NOTIFIER` como trust anchor y acotar por época/validador; rechazar epoch fuera de ventana y validador no admitido | Tests de payload fabricado, epoch fuera de ventana, validador no admitido y cap; §Limitations nombra el rol; el evento de P-14 lleva los cuatro campos |
| P-35 | Paper + script | Sustituir Kesten–Stigum por BBP/`θ`; barrer `density_factor ∈ {3,5,10}` y publicar TPR a `m`/`θ` fijos con IC y `q99` fijado; acotar «uniforme» a 10× | El script reproduce la tabla de P-35; `main.tex` no usa Kesten–Stigum como explicación; la evasión 40 a 3× está declarada o mitigada; el TPR no mezcla calibraciones |
| P-36 | Paper | Corregir `bauer2012` (CAG 21(4):787–845, 2013, DOI), `chung2003` (2002) y añadir Kesten–Stigum/Feller/EIP/BBP o retirarlos | Crossref coincide; no hay `\cite` sin `\bibitem`; compilación sin «Citation undefined»; lista completa del informe contrastada |
| P-37 | Docs + test (paper/plan/README) | Declarar que la permutación es la de circomlib t=3 y el digest el de la esponja de arkworks (`state[1]`, rate), no el `state[0]` (capacidad) de circomlib; es convención válida, no defecto. No re-pinnear salvo consumidor externo de 2 entradas; si no se añade etiqueta, fijar 500 en la ruta de protocolo | Hay test permanente de permutación contra circomlib, absorción 1–10/500 y digest contra un valor pineado; paper/plan/README no afirman interoperabilidad sin cualificar; la ruta de protocolo impone 500 entradas en código si no hay etiqueta; no se regeneraron fixtures/roots/ancla |

**Dependencias.** P-32 y P-33 no deben implementarse como parches aislados del
statement actual: P-32 necesita el `validator` público de P-01 para que la
ventana no sea reutilizable por otro validador, y P-33 cambia la verifying key y
las métricas que P-01/P-16 ya invalidan. P-27 y P-28 son de texto/diseño y no
bloquean el rediseño; P-29 es README y puede corregirse sin re-anclar el paper.
P-30, P-31, P-35, P-36 y P-37 son de paper/docs y sí deben entrar en la misma
revisión editorial que P-20/P-21. P-37 no exige cambiar el circuito mientras se
declare la convención de la esponja; si se opta por circomlib, sí obliga a
regenerar fixtures, roots y ancla. P-34 toca el transporte y el manager: comparte
con P-14 el evento y con P-17/P-32 la noción de época; no requiere el rediseño
del statement, pero no debe cerrarse sólo con documentación si se mantiene la
ejecución inmediata del slash.

## Decisión de la sesión

**Hold.** No se toca `main.tex`, no se tocan contratos, no se toca
`CITATION.cff`, no se tocan tests permanentes ni el ancla, y no se hace commit.
La revisión del 2026-10-20 autoriza **una excepción acotada**: una errata visible
en `docs/paper/releases/v0.2.1-notes.md` (con puntero en
`docs/paper/releases/README.md` y la checklist
`v0.2.1-zenodo-checklist.md` marcada como no ejecutable), sin reexportar el PDF,
sin crear un Release nuevo y sin DOI. El usuario confirma la decisión de **no
depositar v0.2.1 en Zenodo**; la corrección va a v0.2.2 después de P-01/P-16,
con re-anclaje y revisión del diff del circuito/`ic`. Este worksheet y el anexo
de evidencia son los artefactos de la pasada. Al cerrar la auditoría:

1. Renumerar y consolidar los hallazgos con el resto.
2. Asignar severidad final y decidir qué es bloqueante de v1.
3. Abrir `S-016` (o la sesión que corresponda) con el acta.
4. Corregir código y tests primero; paper/plan/README después.
5. Re-anclar una sola vez y actualizar el recibo OTS.

### Zenodo v0.2.1: no depositar tal cual

**Decisión de auditoría:** no se debe generar un DOI nuevo para v0.2.1 en su
estado actual. §6.2 (`main.tex:849-851`) y la fila “Non-transferable” del README
afirman un binding al validador que P-01 desmiente; un DOI es permanente y no se
puede retirar. La opción correcta es corregir esos textos y publicar **v0.2.2**
después de P-01/P-16, o —si ya existe un depósito v0.2.1— añadir una **errata
visible** en el Release que enlace a este hallazgo. No se toca `CITATION.cff` ni
el release en esta sesión: la decisión se ejecuta al cerrar la auditoría, junto
con el re-anclaje.

## Evidencia ejecutada

- `forge test --offline` (suite completa, 9 suites) → **262 passed, 0 failed,
  0 skipped** (después de borrar los `Tmp*`).
- `cargo test --offline -q`:
  - `src/datalayer` → **39 passed, 0 failed**;
  - `src/reputation` → **53 passed, 0 failed**;
  - `src/rmt` → **36 passed, 0 failed, 1 ignored** (el test de reproducción
    pesado);
  - `src/zk` → **42 passed, 0 failed, 1 ignored** (el range proof de 32,768
    bits).
- PoC temporales de esta pasada (todas PASS; fuentes originales borrados, ver
  `docs/audit/evidence/2026-10-20-pocs/pocs/INVENTORY.md`):
  - `TmpDegenerateGamma.t.sol` → **1 test**: clave real con `gamma2 = 0` acepta
    un statement arbitrario;
  - `TmpNormMalleability.t.sol` → **3 tests**: `c + r` verifica en el wrapper y
    en el registry; `admit` revierte por panic de overflow;
  - `TmpFreshness.t.sol` → **1 test**: root distinto con `changedEntries = 0`
    aceptado;
  - `TmpBurnSink.t.sol` → **1 test**: un tercero quema el balance no reclamado
    del sink.
  - `TmpRootConflict.t.sol` → **2 tests**: con `MERKLE_ROOT` el proof V3 da
    `false`; con `STATEMENT_ROOT` da `true` pero `commitmentOf` no es la raíz
    keccak.
  - `TmpP01Real.t.sol` → **4 tests**: el mismo proof **real** de
    `M4bGroth16Fixtures` admite a Alice y Bob; `verify` 223.403 en caliente,
    llamada externa 217.453, `verifyThreshold` 233.104 en caliente y 286.144 en
    frío, `manager.admit` 376.588.
  - `TmpGas.t.sol` → **2 tests** de la pasada anterior: `verify` 223.445 en
    caliente (269.939 alrededor de la llamada externa en frío) y
    `verifyThreshold` 290.854 en frío. La diferencia con 286.144 es el harness,
    no otra ruta; el rango frío es ≈286–291k.
  - `TmpDeployGuards.t.sol` → **2 tests** de esta continuación (fuente nueva,
    no reconstruida): fase 1 en Fuji con `TOKEN`/`SINK` EOAs → `status=ok` y
    ambos con `code.length == 0`; `DeployRegistry` con un `Plan` explícito en
    chain id 1 → despliega y `status=ok`. Salida en
    `logs/deploy-guards.txt`; la copia en `test/` se borró después.
  - `TmpEpochShape.rs` → **2 tests** de esta continuación (fuente nueva):
    génesis de 501 hojas con un duplicado y epoch de 1.000 hojas duplicadas
    pasan `freshness_ok`; el segundo declara `changed == 0` con un root distinto.
    Salida en `logs/epoch-shape.txt`; la copia en `src/datalayer/tests/` se borró.
  - `TmpEntryUpperBound.rs` → **1 test** de esta segunda lectura (fuente nueva):
    `NormCircuit` acepta una entrada `2^60−1 = 1.152921504606846975 WAD` con
    `certified_norm_wad = entry` (`1 passed`). Salida en
    `logs/entry-bound.txt`; la copia en `src/zk/tests/` se borró. No se tocaron
    fuentes del crate.
  - `CollusionDensityProbe.py` → **1.000 réplicas H0 + 300 por configuración
    H1** de la tercera lectura: `q99 = 9.0469`; TPR 0.980 (20 a 10×), 0.067
    (24 a 5×), 0.290 (30 a 5×), 0.057 (40 a 3×), 0.480 (5×12 a 10×) y 0.387
    (10×10 a 10×). Salida en `logs/collusion-density.txt`; no se tocaron los
    scripts sellados.
  - `PoseidonCircomlibProbe.rs` → **3 tests** de la sonda de cierre (P-37): la
    permutación coincide con los vectores t=3 de circomlib para `[1,2]` y
    `[3,4]`; el digest de la esponja es `state[1]` (rate), no el `state[0]`
    (capacidad) de circomlib; la absorción manual coincide para 1–10 y 500
    entradas; y `[5]`/`[5,0]` documentan la ambigüedad de longitud sin etiqueta.
    Salida en `logs/poseidon-circomlib.txt`; la copia en `src/zk/tests/` se
    borró. No se tocaron fuentes del crate ni el circuito.
- Fuzzing existente: `FOUNDRY_FUZZ_RUNS=5000 forge test --offline --match-test
  'testFuzz'` → **7 passed, 0 failed** (3 M7d, 2 manager, 2 vault), 5.000 runs
  por test; salida en `logs/fuzz-5000.txt`. No hay campaña `invariant_*` que
  ejecutar.
- Lecturas on-chain de Fuji (chain 43113, sin transacciones):
  - `vault.manager()` = `0x7C92D08B3d945424154743Adf1D7b1965B88b100`;
  - `manager.custody()` = `0xAE41076223b5b9EB0E811B0751D806B092DaA5E4`;
  - `totalEscrowedUnits = totalDeposited = heldUnits = 0`;
  - vault creado en el bloque 59.670.734, manager/bind en el 59.670.735.
- Comprobaciones numéricas de esta pasada:
  - `stationary_stats.py` reproduce 0,998296/1,000062 (λ = 0); la simulación con
    saltos da 0,80661/0,94339 y la fórmula 0,80645/0,94340.
  - `tucker_analysis.py` con 200 sorteos: `error / (||N||/||T||)` en
    [0,848, 0,938], media 0,892.
  - Agregador: `r = 0.5` → 26,67 % de descuento; `r = 1.0` → 40 %.
  - `q_min(k)` con `r_fraud = 1`: 0,375 (k=9), 0,5714 (k=20), 0,7692 (k=50).
- PoC de la pasada anterior: reutilización de proof, clave cero (2), token de 0
  decimales y colapso guardian→sequencer → **PASS**; ficheros eliminados.
- `bash verification/audit-gate.sh` → **PASS=11 FAIL=0 SKIP=0**.
- `bash verification/fase0_anchor.sh --check` → **exit 0**, ancla byte a byte.
- `ots info verification/anchor_root.sha256.ots` → **3** `PendingAttestation`
  (alice, finney, catallaxy) y **0** `BitcoinBlockHeaderAttestation`; el `.bak`
  tiene 4 y target `5d6002ba…` (otro root). Ver **E-01**.
- `git diff --check` → limpio; `git status --short` muestra este worksheet y
  `docs/audit/evidence/` sin trackear (ambos fuera del ancla por diseño) y los
  tres ficheros de `docs/paper/releases` modificados por **E-01**.

## Ficheros tocados

- `docs/audit/audit-2026-10-20-in-progress.md` (este fichero; no anclado).
- Tests temporales de PoC creados y eliminados en la misma sesión:
  `TmpZeroVerifyingKey.t.sol`, `TmpGlobalProofReuse.t.sol`,
  `TmpZeroDecimalSlash*.t.sol`, `TmpDegenerateGamma.t.sol`,
  `TmpNormMalleability.t.sol`, `TmpFreshness.t.sol`, `TmpBurnSink.t.sol`,
  `TmpRootConflict.t.sol`, `TmpGas.t.sol`, `TmpP01Real.t.sol`.
  Los fuentes originales no están en `test/` y no son recuperables; los
  artefactos `out/Tmp*` también se eliminaron. El inventario y dos
  reconstrucciones (`TmpP01Real`, `TmpRootConflict`) viven en
  `docs/audit/evidence/2026-10-20-pocs/` y no se ejecutan en la suite.
- PoC nueva de P-26: `docs/audit/evidence/2026-10-20-pocs/pocs/new/TmpDeployGuards.t.sol`
  y `logs/deploy-guards.txt`; la copia transitoria en `test/` se eliminó.
- PoC nueva del addendum de P-12:
  `docs/audit/evidence/2026-10-20-pocs/pocs/new/TmpEpochShape.rs` y
  `logs/epoch-shape.txt`; la copia transitoria en `src/datalayer/tests/` se
  eliminó. No se tocaron fuentes del crate.
- Sonda nueva de P-33: `docs/audit/evidence/2026-10-20-pocs/pocs/new/TmpEntryUpperBound.rs`
  y `logs/entry-bound.txt`; la copia transitoria en `src/zk/tests/` se eliminó.
  No se tocaron fuentes del crate, el circuito ni el ancla.
- Sonda nueva de P-35:
  `docs/audit/evidence/2026-10-20-pocs/pocs/new/CollusionDensityProbe.py` y
  `logs/collusion-density.txt`; se ejecutó desde el anexo y no modificó los
  scripts sellados ni el detector.
- Sonda nueva de P-37:
  `docs/audit/evidence/2026-10-20-pocs/pocs/new/PoseidonCircomlibProbe.rs` y
  `logs/poseidon-circomlib.txt`; se ejecutó como test de integración transitorio
  en `src/zk/tests/` y se borró después. Cubre permutación, absorción 1–10/500
  y convención del digest; no se tocaron fuentes del crate, el circuito, los
  fixtures ni el ancla.
- Log de fuzzing de alto número de runs:
  `docs/audit/evidence/2026-10-20-pocs/logs/fuzz-5000.txt` (7 tests × 5.000
  runs). No se añadieron tests de invariantes.
- `docs/paper/releases/v0.2.1-notes.md`, `docs/paper/releases/README.md` y
  `docs/paper/releases/v0.2.1-zenodo-checklist.md`: errata **E-01** (conteo OTS
  4 → 3). No se reexportó el PDF, no se tocó `main.tex`, ningún fichero anclado,
  contrato, test permanente ni configuración.
