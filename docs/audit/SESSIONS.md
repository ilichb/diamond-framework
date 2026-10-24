# Sessions — índice maestro

Una línea por sesión. El `Root` es `sha256sum verification/anchor_root.sha256`
en el árbol final de la sesión; **no** es el hash de `main.tex`. Re-derivar:

    git show <commit>:verification/anchor_root.sha256 | sha256sum

La narrativa vive en `sessions/S-NNN.md`. `handoff.md` es el snapshot durable;
`verification/fase1_determinism_evidence.txt` es la evidencia del harness. No
hay `session-log.md` en este repositorio: no inventar uno.

| # | Fecha | Tema | Commit | Root | Estado |
|---|-------|------|--------|------|--------|
| S-001 | 2026-10-11 | P7a: metadatos PDF y re-anclaje | 6440ac5 | 5d6002ba… | cerrada |
| S-002 | 2026-10-11 | R-4: recibo OTS pendiente | 37e69cf | 5d6002ba… | cerrada; OTS pendiente |
| S-003 | 2026-10-12 | R-4.2: promoción a Bitcoin | 204f5d8 | 5d6002ba… | cerrada |
| S-004 | 2026-10-15 | M9a: segunda autoridad del registry | 2eacac1 | 5d6002ba… | cerrada |
| S-005 | 2026-10-16 | M9b/M9c y dry run de once casos | 607f9b9 | 5d6002ba… | cerrada |
| S-006 | 2026-10-17 | P9.4/P9.5: remap de punteros y R-5 | 690a151 | 459be332… | cerrada |
| S-007 | 2026-10-17 | P9.6a: manifiesto de conteos y F-022 | 727fc1a | 559af48c… | cerrada |
| S-008 | 2026-10-17 | R-7: Fase 4 y M9 | d46349c | 943dc96a… | cerrada |
| S-009 | 2026-10-18 | R-8: gas de Fuji | 384008a | 6715786f… | cerrada |
| S-010 | 2026-10-19 | R-9: block time, F-022 y A6 | f00cad2 | e5c3333c… | cerrada |
| S-011 | 2026-10-19 | R-10: N-3, N-7…N-15, M9 | b16f561 | 3138d321… | cerrada |
| S-012 | 2026-10-19 | R-11: P0 pre-v0.2.0 y session logs | este commit | d8b63d29… | cerrada |
| S-013 | 2026-10-19 | Release v0.2.0 | d99c73a | d8b63d29… | cerrada sin release; ver S-014 |
| S-014 | 2026-10-20 | v0.2.1: correcciones P0/P1 | a785770 | adfd08d2… | cerrada; release pendiente |
| S-015 | 2026-10-20 | Release v0.2.1, README/email y Zenodo | fa78fff | adfd08d2… | abierta; DOI pendiente |
| S-016 | 2026-10-22 | Validación de la matriz externa y triaje del mapa | 84e6837 | adfd08d2… | cerrada; G10/G11 roto en `ea75594`, cerrado en S-017 |
| S-017 | 2026-10-22 | T-5: re-sello del ancla tras P-03/M4d | a9488dc | 5ff84501… | cerrada; OTS pendiente de upgrade; PDF anterior (T-6) |
| S-018 | 2026-10-22 | T-2 y T-1: origen del epoch y custodia obligatoria | este commit | 5ff84501… | cerrada; 283 tests Foundry, 14 casos de dry run, ancla intacta |
| S-019 | 2026-10-22 | P-10: la pareja de autoridad no puede colapsar | este commit | 5ff84501… | cerrada; 286 tests, ancla intacta; queda el follow-up de `proposeVerifier` |
| S-020 | 2026-10-22 | P-39/P-40 y el despliegue del transporte M7d | este commit | 5ff84501… | cerrada; 294 tests, 15 casos de dry run, ancla intacta |
| S-021 | 2026-10-22 | Fase 2: preflight, y el transcript de fase 1 que no verificaba | este commit | 5ff84501… | cerrada; 17 casos de dry run, ancla intacta; el despliegue espera al Safe |
| S-022 | 2026-10-23 | CreateSafe: el multisig sin llaves, y P11 | este commit | 5ff84501… | cerrada; 294 + 1 skip, dry run intacto; el Safe espera owners y umbral |
| S-023 | 2026-10-23 | El Safe 2-de-3 en Fuji: una política, no una llave | este commit | 5ff84501… | cerrada; Safe `0x673F77…` vivo (305835 gas); la fase 2 espera el preflight |
| S-024 | 2026-10-23 | Fase 2 desplegada: el slasher es una política (P-39/P-40) | este commit | 5ff84501… | cerrada; 5981575 gas, `verify --require-multisig` OK; P-39 y P-40 cerrados |
| S-025 | 2026-10-24 | Snowtrace: los tres contratos verificados, la Safe como política | este commit | 5ff84501… | cerrada; 3 verificados (solc 0.8.33, optimizer 0), informe reproducible |
| S-026 | 2026-10-24 | R-14: v0.2.2 (gas, P-27/P-28/P-29) y OTS de R-13 | este commit | 38ee9e57… | cerrada; PDF 43 pp; Zenodo y arXiv desbloqueados |

S-016 cubre `triage-mapa-2026-10-22.md`, el acta
`checklist-matriz-evidencia-2026-10-22.md` y la v2
`matriz-evidencia-2026-10-22.md`. El `Root` no se mueve porque el cambio no
toca ningún fichero del ancla; se re-deriva con el comando de arriba sobre este
commit. La matriz y el mapa recibidos se conservan sin editar como evidencia de
lo que se auditó: no son documentos normativos y no se citan como si lo fueran.
El gate de auditoría sigue en 9 PASS / 2 FAIL **igual que antes** de este
commit: G10/G11 discrepan porque `docs/paper/main.tex` cambió en `ea75594` sin
re-sellar. Es T-5, no un efecto de S-016.

S-018 implementa **T-2** y **T-1**, las dos piezas que el triaje del mapa
(§3.3) identificó como cerrables sin tocar el circuito. `AVIPRegistry` toma
`sourceChainId` y `formulaDigest` como inmutables —cero rechazado en el
constructor— y `postCommitment` exige que cada época declare exactamente esos
dos valores: la comprobación va antes de escribir ningún slot, así que una
publicación con otra cadena u otra fórmula revierte `OriginMismatch` y la época
sigue disponible para el reintento correcto. El evento `CommitmentPosted` los
incluye para que el log sea autocontenido. `DeployValidatorManager.deploy`
rechaza `custody == address(0)` fuera de la cadena local (`MissingRole("CUSTODY")`),
que era el único camino por el que un despliegue «de producción» podía quedarse
sin la mitad que hace posible el `slash`.

Lo que **no** se tocó, y es deliberado: el statement de la proof sigue siendo
`[statementRoot, epoch, uint160(validator), certifiedNorm]`. Añadir
`sourceChainId`, `formulaDigest` o un `stateHash` no los ligaría al tensor —el
circuito no los deriva de `entries`, así que certificarían lo que el prover
declara— y costaría una ceremonia nueva (E-05/M-5, §3.1). El hueco de fondo
(tensor ↔ raíces) sigue siendo `P-38`/`T-3`, no un parche de interfaz.

Ninguno de los 11 ficheros del ancla cambia: `fase0_anchor.sh --check` sale 0 y
el gate sigue en PASS=11 FAIL=0 SKIP=0 sobre `5ff84501…`. La suite Foundry pasa
de 275 a 283 tests, y `deploy_dryrun_output.txt` se regeneró con 14 casos
(`md5 41fb72a858a4180fb31b3a2d4ceb4b32`), byte-idéntico entre dos ejecuciones.

S-019 cierra **P-10**, el hallazgo de gobernanza que el registro tenía confirmado
con PoC desde el 2026-10-20 y que S-018 no tocó. `proposeSequencer` rechaza
`next == guardian` y el constructor rechaza `guardian == sequencer`, ambos con
`RolesCollapsed`, así que la separación de la pareja de autoridad deja de
depender de que el script de despliegue la compruebe: es una propiedad del
contrato desplegado. Tres tests: el PoC del hallazgo (proponer, esperar,
ejecutar) revierte en el primer paso; el camino ordinario sigue abierto —el
guard rechaza el **destino**, no al proponente, que es lo que habría convertido
el arreglo en un problema de liveness—; y un despliegue directo tampoco puede
arrancar con la pareja colapsada.

No mueve el ancla: ninguno de los 11 ficheros sellados cambia. 286 tests Foundry,
`deploy_dryrun.sh` sigue en 14 casos (el caso J ejerce la mitad de script, que
falla antes de transmitir), y el gate permanece en PASS=11.

Queda abierto el follow-up de `proposeVerifier` —acepta una EOA o un contrato con
otra aridad—: es liveness, no captura, y el chequeo natural (`numPublicInputs()`)
depende de la aridad del circuito, así que va con la ceremonia (§11).

S-020 cierra la mitad ejecutable de **P-39** y documenta **P-40**. El punto de
partida era el `slashAuthority` del despliegue de fase 1: `0xcdFBb0c0…2ec7`. Una
lectura contra Fuji (`cast code`) devuelve `0x`, así que el manager desplegado el
2026-10-18 tiene una sola clave decidiendo el 100 % del stake registrado, para
siempre: el rol es inmutable y no tiene pareja de propuesta. No hay fondos en
juego todavía, pero el arreglo no es un setter —el vault ya está bound a ese
manager y `bindManager` es one-shot—, así que P-39 se cierra en fase 2 con un Safe
como `SLASH_AUTHORITY` y un redespliegue de registry, vault y manager.

Lo que sí se podía cerrar hoy es el guard de despliegue.
`DeployCommon._requireSlasher` rechaza una address sin código en toda cadena que
no sea 31337, y se aplica en `plan()` y en `deploy()` de los dos scripts que
eligen slasher, para que un `Plan` construido a mano no lo salte. Tres tests lo
fijan; la cadena local conserva el EOA de `anvil` que usan el dry run y los
reportes, y el guard no toca el contrato: un Safe es un parámetro del
constructor. `verify_fuji.sh` gana la comparación de `manager.slashAuthority()`
con el transcript, escribe `manager.slashAuthority.kind=eoa|contract` y acepta
`--require-multisig` para fallar en EOA. Contra el despliegue real reporta `eoa`
y, con el flag, sale 1.

La misma sesión encontró **P-40** al intentar validar ese bloque: `sourceChainId()`
y `formulaDigest()` revierten en el registry de Fuji, mientras `sequencer()` y
`TENSOR_SIZE()` responden. El bytecode desplegado es anterior a M-15, y por eso su
transcript sellado no tiene las filas `origin.*` que `verify_fuji.sh` exige desde
T-2: el verificador endurecido no puede verificar ese despliegue. Se arregla en el
mismo redespliegue de fase 2; el ancla no se toca porque el transcript es
evidencia histórica.

El otro frente es **I-1.4**: `M7dReport` probó el transporte, pero no había script
que lo desplegara. `DeployTransport.s.sol` despliega los tres endpoints de §4 en
una cadena, un lado por ejecución (`TRANSPORT_SIDE=source|destination`), con las
direcciones peer como entradas —no predichas— y el messenger obligatorio con
código en cadena viva; en 31337 sin `TELEPORTER` despliega el mock para que el dry
run siga siendo hermético. Cinco tests cubren los dos lados y tres rechazos. **El
transporte sigue sin desplegarse en Fuji**: el script existe, el despliegue no, y
por eso I-1.4 sigue abierto.

Ninguno de los 11 ficheros del ancla cambia: `fase0_anchor.sh --check` sale 0 y el
gate sigue en PASS=11 FAIL=0 SKIP=0 sobre `5ff84501…`. La suite pasa de 286 a 294
tests y el dry run de 14 a 15 casos (`md5 ec094c9127dd9d9813a7919d80e9d774`),
byte-idéntico entre dos ejecuciones.

S-021 empieza la fase 2 —el redespliegue que P-39 y P-40 exigen— y encuentra que
el agujero era mayor de lo documentado. `DeployFujiPhase1._report` **no emitía**
`origin.sourceChainId` ni `origin.formulaDigest`, aunque `DeployRegistry` sí y
`verify_fuji.sh` los exige desde T-2; y el verificador sólo comprobaba que esas
dos claves *existieran* en el transcript, nunca que coincidieran con
`registry.sourceChainId()`/`formulaDigest()`. Los dos lados del contrato de
verificación estaban rotos: un redespliegue con el registry correcto habría
producido un transcript que el propio verificador rechaza, y un transcript con
valores inventados habría pasado. Corregidos ambos: el script emite las dos filas
(caso P del dry run, fase 1 completa en local) y el verificador las coteja contra
la cadena, nombrando la causa cuando los getters revierten
(`the deployed build predates M-15 (P-40)`) en lugar de morir con un
`cast call failed` genérico.

El otro entregable es `preflight_fase2.sh`, porque `DeployFujiPhase1` ya *es* el
script de fase 2 —despliega el registry con el origen, exige código en el slasher—
pero no puede comprobar su propia entrada. Diez comprobaciones de sólo lectura:
artefacto post-M-15, `bindManager`/`slashAuthority` presentes, `origin.*` en el
script; cadena 43113, slasher con código y distinto de la EOA de fase 1 y de
`SEQUENCER`/`DEPLOYER` (aviso si es el `GUARDIAN`), 0.05 AVAX en el deployer,
Teleporter presente, y confirmación de que el registry vigente sigue sin los
getters. Verificado en tres modos: `--offline` (`PASS=3 FAIL=0`), contra el estado
real (`FAIL=2`, habría bloqueado el despliegue original) y con una dirección con
código (`PASS=10 FAIL=0`).

**Estado operativo, comprobado hoy:** el deployer `0x1245…35bb` tiene 0.5 AVAX, el
Teleporter existe en Fuji en `0x253b2784…5fcf`, y **no hay Safe**. La fase 2 está
bloqueada por una decisión de gobernanza —owners y umbral—, no por el código: en
cuanto exista la dirección, el orden está escrito y el preflight lo valida. El
transporte sigue igual: el script existe, los peers de la otra cadena no.

Suite sin cambios en Solidity (294): lo añadido es shell, y su prueba es el dry
run, que pasa de 15 a 17 casos con md5 nuevo
(`bf274cdbc9ebeae61e0daafa00c6ee56`, estable entre dos ejecuciones). Ancla y gate
intactos: PASS=11.

Nota de medición, porque afecta a cómo se cita la evidencia: la primera corrida de
esta sesión reportó **260** tests y `--match-path test/DeployScripts.t.sol` decía
"No tests found in project!" con los 34 tests presentes en el artefacto. No faltaba
nada: `out/` estaba desincronizado tras editar el script, y `forge clean &&
forge test` devuelve los 294 (10 suites, `DeployScriptsTest` incluida). Un conteo
leído de una corrida incremental no es evidencia; se limpia antes de citarlo.

S-022 desbloquea la parte que no era gobernanza. La fase 2 esperaba un Safe, y
crear un Safe parecía exigir una llave de owner: `app.safe.global` no lista Fuji,
y `safe-global/protocol-kit` necesita un firmante para enviar el despliegue, que
en la práctica sería la llave de un dueño —manipulada para crear el contrato cuyo
propósito es que ninguna llave sola decida—. No hace falta. La factory canónica
despliega un proxy cuyo constructor hace `delegatecall` a `setup` en el singleton,
y `setup` no comprueba ninguna firma: en ese instante el Safe no tiene todavía una
política contra la que comprobar. La única firma es la del deployer, y sólo paga
gas; no se convierte en owner. `CreateSafe.s.sol` toma los owners como
**direcciones** y nada más: ninguna clave, ni como variable de entorno.

El script usa las direcciones canónicas de Safe 1.4.1, verificadas con `cast code`
en Fuji antes de escribirlo (singleton `0x41675C09…`, factory `0x4e1DCf7A…`,
handler `0xfd0732Dc…`, `MultiSendCallOnly` `0x40A2aCCb…`). Ordena los owners
ascendentemente antes de codificar, que es lo que hace el SDK: así la dirección
CREATE2 no depende del orden en que se teclearon y coincide con la que el SDK
reportará. Predice la dirección con `proxyCreationCode()` más el singleton,
despliega, y **comprueba que coinciden**; después relee la política —umbral,
lista de owners, `nonce()`, el singleton en el slot 0 del proxy, el handler en su
slot de storage y `VERSION() = 1.4.1`— y emite `status=ok`. Rechaza owner cero,
duplicado, el deployer como owner, un hueco en la numeración `SAFE_OWNER_n` —que
de otro modo desplegaría una política con menos owners de los escritos— y umbral
fuera de `1..n`.

Dos errores propios, porque el registro sirve para eso. El primero: leía el
handler con `getFallbackHandler()`, que **no existe en 1.4.1** —llegó con 1.5.0—
y la llamada acaba en el fallback del propio handler y revierte con datos vacíos;
el slot `keccak256("fallback_manager.handler.address")` dice lo mismo y es lo que
`setup` escribió. El segundo: P11 contaba owners con `grep -c`, que cuenta
*líneas*, y `cast` imprime el array en una sola; habría reportado `2-of-1`. Los
dos se vieron ejecutando, no leyendo: el primero abortó la simulación, el segundo
sólo habría mentido en el recuento.

La prueba de que el resultado es una *política* y no un contrato con dos dueños
escritos es `test/SafeFork.t.sol`, sobre estado real de Fuji y con llaves
desechables generadas en el test: dos firmas EIP-712 ejecutan una transacción y
avanzan el `nonce`, una sola revierte y el `nonce` no se mueve. Se comprueban las
dos direcciones porque un umbral mal puesto (1-de-3) pasaría la primera mitad.
Sin `FUJI_RPC_URL` el test se salta a sí mismo: `forge test` sin red sigue verde
(`294 passed, 0 failed, 1 skipped`), y el skip se ve en el resumen en vez de
esconderse. La corrida con RPC la da por buena (1 suite, 1 test, 2 s).

El preflight gana **P11**, que es donde este trabajo toca la fase 2: P5 preguntaba
si el slasher tiene código; P11 pregunta si ese código es una política. Lee
`getThreshold()` y falla por debajo de 2, porque un Safe 1-de-N pasa "tiene
código" y deja P-39 exactamente como estaba; si la dirección no responde —no es
un Safe, o es anterior a 1.1.0— avisa y no falla, porque el control sólo puede
juzgar una política que sabe leer. Verificado en los tres caminos contra una fork
local de Fuji: 2-de-3 da `PASS=11 FAIL=0 SKIP=0`; 1-de-1 da
`FAIL P11 … one signature still decides every slash (P-39)` con salida 1; y la
EOA de fase 1 da `SKIP P11` porque P5 ya la rechaza. El `--offline` pasa de 7 a 8
skips (`PASS=3`) y el dry run sigue en 17 casos con el mismo
`md5 bf274cdbc9ebeae61e0daafa00c6ee56`: el bloque P11 no se ejecuta sin cadena y
la salida del caso Q no cambia.

**Estado operativo:** sigue sin haber Safe. Lo que falta ya no es código sino la
decisión —las tres direcciones y el umbral—, y el comando está listo:

```shell
DEPLOYER=0x12458CD567C9f01cbA220Fe3f2Af97034f9635bb \
SAFE_OWNER_1=0x... SAFE_OWNER_2=0x... SAFE_OWNER_3=0x... SAFE_THRESHOLD=2 \
    forge script scripts/CreateSafe.s.sol:CreateSafe --rpc-url "$FUJI_RPC_URL"   # sin --broadcast
```

En cuanto el Safe exista: preflight con esa dirección (`PASS=11`), `DeployFujiPhase1
--broadcast`, `verify_fuji.sh <transcript> --require-multisig`. Nada de esto toca
el ancla: los 11 ficheros siguen igual, `fase0_anchor.sh --check` sale 0 y el gate
en `PASS=11 FAIL=0 SKIP=0` sobre `5ff84501…`. El transporte (I-1.4) sigue igual:
el script existe, los peers de la otra cadena no.

S-023 ejecuta el paso que S-022 dejó escrito, desde el terminal del operador y no
desde este: el Safe existe en Fuji en `0x673F7725CF17A481299c7073486F8Fb222a66813`,
2-de-3, en la transacción `0x3c39a83e…2112`, bloque 59932344, 305835 gas. Los
owners son `0x27923A94…`, `0x8022bbC2…` y `0xDaa59b40…`, ordenados ascendentemente
porque el script ordena antes de codificar; el deployer —`0x12458CD5…`, el mismo
de fase 1— firmó y pagó, y **no** figura entre ellos. La simulación previa imprimió
esa misma dirección, que es lo que un CREATE2 con `saltNonce=0` tiene que hacer, y
el script aborta si la creada no coincide con la predicha; no hubo ninguna llave de
owner en el proceso.

La prueba no es el `Success` de forge, es la relectura: `getThreshold()` = 2,
`getOwners()` = los tres, `VERSION()` = `1.4.1`, `nonce()` = 0, el singleton
`0x41675C09…` en el slot 0 del proxy y el handler `0xfd0732Dc…` en
`keccak256("fallback_manager.handler.address")`. El recibo añade los dos eventos:
`ProxyCreation` de la factory canónica `0x4e1DCf7A…` y `Setup` del propio Safe con
umbral 2, `to=0x0`, el handler y los tres owners. Y las cuatro lecturas se repiten
por la API de Snowtrace (`eth_getCode`, `eth_call` con los selectores `0xe75235b8`,
`0xa0e67e2b`, `0xffa1ad74`, `0xaffed0e0`), con `getcontractcreation` nombrando la
factory como `contractFactory` y al deployer como `contractCreator`: la misma
política leída desde fuera del RPC.

Dos cosas que esta evidencia **no** dice, y conviene escribirlas. Que la dirección
tenga código no prueba un umbral —por eso P11 lee `getThreshold()`—, y que el
umbral sea 2 no prueba que las tres llaves estén en manos distintas: eso se audita
en el explorador y en la configuración del Safe, no en una llamada. Y el proxy no
se verifica en Snowtrace a propósito: su bytecode es el de la factory, no el de
este repositorio, así que no hay fuente que compilar y comparar; publicarla sería
afirmar algo que nada del repo sostiene. La reproducibilidad se demuestra de otra
forma: mismos owners, mismo umbral, mismo `saltNonce` y mismo deployer dan la misma
dirección, que es justo lo que imprime el dry run.

El estado no cambia todavía: `slashAuthority` del manager de fase 1 sigue siendo
la EOA `0xcdFBb0c0…2ec7`, porque el rol es inmutable y el arreglo es el
redespliegue. Lo que cambia es que el preflight ya tiene su entrada: con esta
dirección como `SLASH_AUTHORITY` debe salir `PASS=11 FAIL=0`, y entonces
`DeployFujiPhase1 --broadcast` y `verify_fuji.sh <transcript> --require-multisig`
cierran P-39 y P-40 a la vez. La evidencia queda versionada en
`scripts/fuji_20261023/fuji_safe.txt` —la salida del operador más las lecturas y
la respuesta del explorador— y `scripts/fuji_20261023/safe.json`, copia del run de
forge, porque `broadcast/` está en `.gitignore` y ahí el recibo se pierde con el
próximo `forge clean`. Ancla y gate intactos: `PASS=11 FAIL=0 SKIP=0`.

S-024 ejecuta la fase 2 y cierra **P-39** y **P-40** a la vez, aunque el trabajo de
esta sesión sea sobre todo comprobar que se cerraron. Antes de firmar nada, el
preflight con la Safe como `SLASH_AUTHORITY` dio `PASS=11 FAIL=0 SKIP=0`, con `P11`
leyendo el umbral de la cadena (`2-of-3`) y no del entorno. La simulación sin
`--broadcast` predijo las tres direcciones —registry `0x8DE8C843…`, vault
`0xD560F40B…`, manager `0x88e60aA2…`— y el despliegue real creó exactamente esas:
no es una coincidencia, es el nonce del deployer y el orden de las tres
deployments. Tres transacciones, bloques 59935785 y 59935786, **5981575 gas** en
total, 0,000000000957 AVAX a 160 wei/gas. `verify_fuji.sh --require-multisig`
devolvió `OK` inmediatamente después y otra vez contra la copia versionada del
transcript, que es la que queda en el repo.

La verificación que importa no es la del script, es la de la cadena después:
`manager.slashAuthority()` devuelve `0x673F7725…6813`, una dirección con **171
bytes de código** —un proxy, no una EOA—, y su `getThreshold()` lee 2;
`vault.manager()` devuelve el manager nuevo, así que el handshake es el del par
recién desplegado; y `registry.sourceChainId()`/`formulaDigest()` responden
`0xce128645…091bc1` y `0x403af787…a4cfc`, idénticos a las filas `origin.*` del
transcript. Eso es lo que **P-40** pedía: el valor deja de estar sólo en el texto y
el verificador lo coteja contra el contrato, que es la comparación que S-021 tuvo
que escribir porque antes no existía.

Un error propio, del tipo que sólo se ve al mirar lo guardado: el `tee` capturó
sólo stdout, y forge escribe las líneas `✅ [Success] Hash: … Contract Address: …`
por **stderr**. El transcript versionado, por tanto, no tenía ni un hash de
transacción: verificaba —el verificador sólo necesita las filas `[fuji]`— pero como
evidencia habría obligado a fiarse del terminal del operador. Se corrige con
`fuji_phase2_chain.txt`, que guarda los tres hashes, sus recibos (`status=1`,
bloque y gas de cada uno) y las lecturas de arriba, hechas contra la cadena
después del despliegue. La lección es la de S-022 con el conteo de tests: lo que no
está en el fichero no es evidencia, aunque uno lo haya visto pasar.

**P-39** queda cerrado en su parte ejecutable y con dos matices escritos. El
manager vivo ya no tiene una EOA en el rol inmutable, sino una política 2-de-3; el
manager de fase 1 sigue en la cadena apuntando a `0xcdFB…2ec7` y seguirá siempre
—es histórico, y por eso `--require-multisig` falla contra *aquel* transcript y no
contra éste—. Y la cadena acredita que el rol lo ejerce un contrato con umbral ≥ 2,
no que las tres llaves estén en manos distintas: eso se audita en el explorador y
en la configuración del Safe, no en un `getOwners()`. El `guardian` sigue siendo la
EOA del deployer, igual que en fase 1, porque el inicializador lo toma como
parámetro y cambiarlo habría cambiado las tres direcciones; es una decisión de
gobernanza pendiente, no un descuido, y ahora está dicha en el README.

Con esto la fase 2 deja de estar pendiente en la documentación: `scripts/README.md`
describe el despliegue vivo con sus hashes, `contracts/README.md` deja de hablar de
la fase 2 como futuro, y las dos filas del audit dicen **cerrado** con la evidencia
detrás. Ancla intacta —los 11 ficheros no se tocan, `fase0_anchor.sh --check` sale
0— y gate en `PASS=11 FAIL=0 SKIP=0` sobre `5ff84501…`. Suite sin cambios: 294
tests más el skip de `SafeFork` sin RPC. Lo que sigue abierto es el transporte
(I-1.4, sin peers en la otra cadena), la rotación de `guardian` y el resto del
roadmap.

S-025 separa lo que la cadena puede atestiguar de lo que no, y lo escribe donde
cualquiera puede repetirlo. Los tres contratos de fase 2 se verifican en Snowtrace
con los argumentos del transcript —`solc 0.8.33`, optimizer off, que es lo que fija
`foundry.toml`— y ese es el único sentido en el que "el código está en la cadena"
es una afirmación comprobable. La Safe no se verifica, y no por pereza: su runtime
es el proxy de 171 bytes de la factoría, así que verificar *eso* contra este repo
sería verificar bytecode ajeno contra nuestro árbol. La prueba de la Safe es de
política, y son sus lecturas y su recibo de creación.

El detalle que hizo falta descubrir: Snowtrace responde `getsourcecode` sin clave,
pero `forge` se niega a enviar el POST si `ETHERSCAN_API_KEY` no está definida. El
script pone un placeholder cuando el entorno no trae ninguna y lo dice en la
cabecera, porque un `ETHERSCAN_API_KEY=0000…` en un script se lee como credencial y
no lo es: es una comprobación del lado del cliente. Con eso, `forge verify-contract`
aceptó los tres (registry `831fffd9…`, y dos más) y el explorador pasó de
`Contract source code not verified` a `Pass - Verified` con nombre, compilador y
optimizer correctos en cada uno.

`scripts/verify_public_fuji.sh` empaqueta eso y añade lo que un `verify-contract`
no dice: lee el explorador **de vuelta** en vez de fiarse del código de salida de
forge, compara once getters fijados por constructor contra el transcript —un source
verificado con argumentos equivocados sigue siendo el contrato equivocado— y
reconstruye la política del Safe desde el recibo: `ProxyCreation` nombra la
factoría que lo emitió, el proxy y el singleton; `SafeSetup` lleva umbral 2,
`initializer = 0x0`, el handler 1.4.1 y los tres owners. El informe queda en
`scripts/fuji_20261023/fuji_public_verify.txt`, y `--skip-submit` lo reduce a
lectura para cuando no se quiere escribir en el explorador.

Un fallo propio, encontrado al leer la primera salida: el informe imprimía la URL
del RPC completa, y la del runbook (`~/.config/avip/fuji_rpc.txt`) lleva la clave
de Alchemy en el path. Un fichero que se commitea no puede llevar eso. Ahora se
imprime sólo esquema y host, con la línea diciendo que las credenciales no se
imprimen. `verify_fuji.sh` ya lo hacía así —"never print it"— y este script lo
violaba por copiar el patrón de lectura sin copiar la precaución.

Lo que el informe no establece, y dice: que las tres llaves de owner estén en tres
manos distintas o que sigan bajo control. Eso es gobernanza, se audita fuera de la
cadena, y el guardian sigue siendo la EOA del deployer por decisión.
