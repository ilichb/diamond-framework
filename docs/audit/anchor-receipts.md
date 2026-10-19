# Recibos de anclaje — sellado externo de `anchor_root.sha256`

Fecha: 2026-10-08. Sello en `2026-10-08T21:34:05Z` → `21:34:07Z` (UTC).
Promoción del recibo completado al repo (`ots upgrade`, la prueba de Bitcoin
dentro del `.ots`): `2026-10-09T16:07Z` (local `12:07 -04`) — §R-1.6.
HEAD cuyo árbol se selló: `ae94232` (root de D1, digest `83001ca2…`); el árbol
en el momento del sello es `3f8718a`, hijo suyo, donde D14 sólo tocó documentos,
así que el root es idéntico en ambos. HEAD anclado *dentro* del root:
`d4336ca` (el `audit_manifest.sha256` que sella G10).

Alcance: testigos **externos** del root de anclaje. Este fichero vive a
propósito **fuera** del root: incluirlo sería circular (el root no puede
comprometerse a su propio recibo). Consecuencia directa: **todo cambio en
cualquiera de los diez ficheros que el root compromete invalida este sello** y
exige re-anclar y, si se quiere testigo del estado nuevo, un sello nuevo.

Método: cada valor de aquí sale de un comando y el comando va al lado. Donde el
texto y la derivación en vivo difieren, gana la derivación.

## R-1 — Recibo OpenTimestamps del root de D1

| campo | valor |
|---|---|
| Artefacto sellado | `verification/anchor_root.sha256` (10 pares) |
| SHA-256 del artefacto | `83001ca2e047ff17cb02d14dcf6777d51af008b516ae816e5a463fb409d69092` |
| Recibo | `verification/anchor_root.sha256.ots` (**2949 bytes**; el pendiente eran 945) |
| SHA-256 del recibo | `6b28be97603ce2b2a2f1879ef5393aaf26c1bf3a0d3338222e9c9551b903141c` (promovido, §R-1.6). El **pendiente**, el que viajó por correo, era `e78cab51c6075e03b8c8ac69ddc442005d71b57d79d13d357e8a4814f05998b9` |
| Cliente | `ots` v0.7.2 (`opentimestamps-client` 0.7.2, `opentimestamps` 0.4.5, Python 3.10.12) |
| Envío a calendarios | 4 *(4 líneas `Submitting to remote calendar` en la salida del cliente)* |
| Atestaciones | **6 dentro del `.ots`**: 4 `PendingAttestation` (los cuatro calendarios) + **2 `BitcoinBlockHeaderAttestation`** (`970536`, `970537`); derivado de `ots info`, no de la salida del cliente |
| Verificación | `ots verify verification/anchor_root.sha256.ots` → `exit 1`: resuelve el objetivo (`Assuming target filename…`) y **no** dice `File does not match`; falla sólo porque **no hay nodo Bitcoin local** (`Could not connect to Bitcoin node: Cookie file unusable … /home/ilich/.bitcoin/.cookie`). El recibo ya trae la prueba; cerrarla exige el nodo o un explorador |
| Agregación en Bitcoin | **dentro del recibo** desde 2026-10-09: bloques `970536` y `970537` — ver §R-1.5 y §R-1.6 |
| Copia out-of-band | **enviada** el `2026-10-08T22:50:12Z`, `Message-ID <3e1b76af-7944-45a0-8688-290e7eb41a29@gmail.com>` — ver §R-1.3 |

### R-1.1 Los cuatro calendarios

Los pools que se sondean y los calendarios que finalmente responden no son los
mismos nombres, y el recibo debe citar los que quedan **dentro** del `.ots`
(`strings verification/anchor_root.sha256.ots | grep -oE 'https://[a-z0-9._/-]+' | sort -u`):

- `https://alice.btc.calendar.opentimestamps.org`
- `https://bob.btc.calendar.opentimestamps.org`
- `https://btc.calendar.catallaxy.com`
- `https://finney.calendar.eternitywall.com`

El conteo se obtuvo por dos vías independientes y coinciden: la salida del
cliente (4 líneas de envío) y el propio binario del recibo
(`strings … | grep -c 'https://'` = 4). Un recibo que citara el número sin la
segunda vía sería una afirmación, no una medición.

### R-1.2 Qué prueba este recibo y qué no

- Promovido (§R-1.6), el `.ots` **ya no es sólo un recibo de envío**: contiene
  dos `BitcoinBlockHeaderAttestation`, es decir el compromiso está agregado a un
  bloque y dos calendarios lo firmaron. Lo que prueba es que `83001ca2…` existía
  **antes** de `2026-10-08T21:48:49Z` (altura `970536`), con la salvedad de la
  regla de *median-time-past*: la hora la declara el minero.
- Lo que sigue sin ser verificación criptográfica **completa** es local: cerrar
  la prueba exige el encabezado del bloque `970536`/`970537` —un nodo Bitcoin
  Core (podado basta) o un explorador—. `ots verify` sin nodo sale `1` con
  `Could not connect to Bitcoin node`: el recibo pasa su parte (resuelve el
  objetivo y **no** dice `File does not match`) y el cliente se detiene al no
  tener de dónde leer la cadena de encabezados.
- En el estado **pendiente** —el que viajó por correo, §R-1.3— `ots verify`
  también salía `1`, pero por otra razón: los calendarios aún no habían
  agregado. Las dos formas del recibo están en el historial (§R-1.6).
- El compromiso dentro del `.ots` es el sha256 del fichero, que es exactamente
  el valor que este recibo cita. Lo comprueba el propio `ots verify`: resuelve
  el objetivo (`Assuming target filename is 'verification/anchor_root.sha256'`) y
  pasa a leer los calendarios. Si el compromiso no fuera el de este fichero,
  habría dicho `File does not match`.
- El root compromete **diez ficheros** (el ancla, el verificador y tres entradas
  estables de auditoría). Lo que el sello atestigua es **qué guarda corre y
  sobre qué ancla e insumos**, no **el resultado** de esas guardas. El límite está
  declarado en `bloque-b-report.md` §6.2, entradas **D13** (los insumos crudos de
  G2/G3 —`fase1_determinism_evidence.txt`, `baseline_verified/manifest.txt`— se
  leen pero no se hashean dentro del root) y **D14** (en el runner G9 degrada a
  SKIP: el CI no compila LaTeX, así que la corrección a nivel LaTeX la cubre la
  máquina de referencia, no el runner).

### R-1.3 Copia out-of-band

Estado: **enviada**. Un solo mensaje: la carpeta `Enviados` de la cuenta Gmail
contiene exactamente un registro con este asunto, y los otros registros con ese
texto están en `Borradores`/`Todos` y no en `Enviados`, es decir son borradores
nunca enviados. Todo lo que sigue sale de las **copias recibidas** —las que
cruzaron el transporte y volvieron—, no de la copia local del enviado.

| campo | valor |
|---|---|
| Fecha (`Date`) | `Thu, 8 Oct 2026 18:50:12 -0400` = **2026-10-08T22:50:12Z** |
| `Message-ID` | `<3e1b76af-7944-45a0-8688-290e7eb41a29@gmail.com>` |
| `From` | `Gmail <andromedacomputerca@gmail.com>` |
| `To` | `ilichblanco@andromedacomputer.net` (entregado: `Delivery-date` 22:50:57Z) |
| `Cc` | `marketing@andromedacomputer.net` (entregado: `Delivery-date` 22:50:57Z) |
| Adjunto | `anchor_root.sha256.ots`, 945 B, sha256 `e78cab51…` — **idéntico byte a byte** al del repo |
| Cuerpo | 2201 B, sha256 `b47eb5dc2696f0a05b20c138fd4c98a3cd37337a156fc8d6ae87c58fb912d304` |
| Registro completo | copia del `Cc`: 10440 B, `eb42c463…`; copia del `To`: 10444 B, `e17bfa5b…` |
| Recepción | 4 saltos: cliente → `smtp.gmail.com` (22:50:14Z) → `mail-vk1-f180.google.com` (22:50:36Z; la copia del `To` entra por `mail-ua1-f52.google.com`) → `dfw-s05.nixihost.com` (esmtps, TLS1.3, Exim 4.100.1) → entrega local LMTP (22:50:57Z) |
| Firmas DKIM | `DKIM-Signature` y `X-Google-DKIM-Signature`, ambas `v=1; a=rsa-sha256; d=gmail.com; s=20251104`; `t=1791499815` (22:50:15Z), `x=1792104615` (2026-10-15T22:50:15Z) |

Cadena de custodia, sin adornos:

- **El adjunto recibido sella el compromiso.** Guardado desde la copia recibida:
  945 B, sha256 `e78cab51…`, `cmp` idéntico al del repo, y `ots verify` sobre esa
  copia (con el objetivo al lado) dice `Assuming target filename is
  'anchor_root.sha256'` y **no** dice `File does not match`: el compromiso dentro
  del `.ots` es exactamente `83001ca2…`.
- **Cinturón y tirantes.** El cuerpo lleva además el `.ots` en base64 entre
  marcadores, en 20 líneas; decodificado da 945 B y `e78cab51…`, el mismo valor.
  Si un proveedor descartase adjuntos, el testigo viaja igual.
- **Firmas de Google, verificadas aquí.** Con `dkimpy`, aislando cada cabecera (se
  borra la otra y se repite la verificación): `DKIM-Signature` → `True` y
  `X-Google-DKIM-Signature` → `True`. DKIM firma el **cuerpo entero**, adjunto
  incluido. El instrumento se probó antes de creerle: cambiar un carácter del
  digest o del asunto en la copia recibida devuelve `False`.
- **Estabilidad entre buzones.** Los dos registros recibidos difieren en 38 líneas
  (envolvente, `Received`, entrega) y por eso sus hashes completos difieren; el
  **cuerpo** y el **adjunto** son idénticos en ambos. El valor estable es el
  `Message-ID` más los dos hashes de parte, no el hash del registro entero.
- **Dos proveedores, un dominio y un titular.** La cadena cruza Google (firma y
  almacén) y `nixihost`/`andromedacomputer.net` (recepción y almacén); ninguno de
  los dos es GitHub. Pero la `Cc` **no cumple** lo que esta sección pedía antes:
  `marketing@andromedacomputer.net` está en el **mismo dominio** que el `To`, así
  que los dos destinos comparten dominio, DNS y servidor de correo — **un solo
  fallo de dominio, no dos**. Y los tres buzones son de la misma persona: la
  independencia es **a nivel de proveedor, no a nivel de tercero**. Se declara la
  desviación en vez de dar por cumplido un requisito que no se cumplió.
- **La firma caduca.** `x=1792104615` = 2026-10-15T22:50:15Z: pasada esa fecha un
  verificador *puede* rechazar la firma por expirada. Las copias del mensaje
  siguen existiendo; lo que caduca es la atestación criptográfica de Google, y
  rehacerla exige que la clave de `20251104._domainkey.gmail.com` siga publicada.
- No hay cabeceras `ARC-*` ni `Authentication-Results` en la copia recibida: el MX
  de destino **no** añadió veredicto propio. La única atestación de tercero es la
  de Google.

Lo que esto **no** prueba: que el `.ots` esté confirmado. El enviado es el
**pendiente** (`e78cab51…`); lo que el correo fija es que ese recibo pendiente
existía el 2026-10-08T22:50:12Z, en dos buzones y con la firma de Google. Quien
tenga el adjunto puede completarlo por su cuenta con `ots upgrade`, porque los
calendarios ya agregaron (§R-1.5). El `.ots` completado vive en el repo desde el
2026-10-09 (`6b28be97…`, §R-1.6) y se deriva de ese mismo compromiso: el hash
del fichero —el root— no cambia, sólo el recibo que lo acompaña.

### R-1.4 Reproducción

    python3 -m venv ~/.local/venvs/ots && ~/.local/venvs/ots/bin/pip install opentimestamps-client==0.7.2
    ots stamp verification/anchor_root.sha256                    # 4 envíos; escribe el .ots
    strings verification/anchor_root.sha256.ots | grep -c 'https://'   # 4 (2ª vía del conteo)
    sha256sum verification/anchor_root.sha256.ots                # e78cab51… antes de promover; 6b28be97… desde §R-1.6
    ots verify verification/anchor_root.sha256.ots               # exit 1 sin nodo: «Could not connect to Bitcoin node»
    ots upgrade verification/anchor_root.sha256.ots              # tras la confirmación en Bitcoin; idempotente

Evidencia del envío (§R-1.3), leída del propio almacén de Thunderbird
(`~/.thunderbird/<perfil>/ImapMail/…`) y no de la pantalla: se localiza el
registro por su `Message-ID`, se compara el adjunto y se validan las firmas.

    python3 -m pip install --user dkimpy
    python3 -c 'import dkim,sys;print(dkim.verify(open(sys.argv[1],"rb").read()))' recibido.eml
    # aislando cada firma (se borra la otra cabecera y se repite): True en las dos
    # guardado desde la copia recibida: 945 B, sha256 e78cab51…, cmp con el del repo
    # ots verify sobre esa copia: «Assuming target filename…», sin «File does not match»

### R-1.5 Agregación en Bitcoin (medido después del sellado)

El sellado fue a las `21:34:07Z` y las cuatro atestaciones quedaron pendientes.
Medido después, **sobre una copia en `/tmp`** (así se hizo en su momento; §R-1.6
promueve luego el resultado al repo).

    cp verification/anchor_root.sha256 verification/anchor_root.sha256.ots /tmp/probe/ && cd /tmp/probe
    ots upgrade anchor_root.sha256.ots   # exit 0: «Got 2 attestation(s) from cache» + «Success! Timestamp complete»
    ots info anchor_root.sha256.ots      # sigue habiendo 4 PendingAttestation, y dos BitcoinBlockHeaderAttestation
    sha256sum anchor_root.sha256.ots     # 6b28be97…  (medido antes de promover; desde §R-1.6 el commitado es éste)

Dos calendarios agregaron el compromiso a un bloque:

- `BitcoinBlockHeaderAttestation(970536)`, merkle root `e2376ba95d40…`, bloque de
  `2026-10-08T21:48:49Z`
- `BitcoinBlockHeaderAttestation(970537)`, merkle root `a87a055e88c2…`, bloque de
  `2026-10-08T22:00:55Z`

Las dos raíces coinciden con las que imprime `ots info` y con las que devuelve un
explorador público para esas alturas. Eso **no** es verificación criptográfica
completa (haría falta el encabezado del bloque, es decir un nodo) y el explorador
es un tercero: se cita como medición, no como prueba. El cliente resolvió las
atestaciones desde su caché `~/.cache/ots`, poblada en una verificación previa.

Nota de cronología: el correo salió a las `22:50:12Z`, **después** de los dos
bloques. El testigo externo cubre por tanto el `.ots` pendiente, cuyo compromiso
es anterior a `21:48:49Z` según la cadena de Bitcoin (la hora de un bloque la
declara el minero, acotada por la regla de *median-time-past*).

Promover el estado completado —`ots upgrade` en el repo y reescritura de R-1,
R-1.2 y R-1.4 con el hash nuevo y el número de bloque— es un cambio aparte,
ejecutado el 2026-10-09: **§R-1.6**.

### R-1.6 Promoción del estado completado (Turn B, 2026-10-09)

El estado completado vivía sólo en `/tmp` (§R-1.5). Promoverlo es repetir el
`upgrade` sobre una copia y, **sólo si el resultado coincide** con lo ya medido,
sustituir el recibo del repo. Sustituir es seguro porque el `.ots` **no** está
entre los diez ficheros que el root compromete —el root sella el ancla y sus
insumos; el recibo es el sobre externo—, así que el digest del ancla sigue
siendo `83001ca2…` y la guarda G11 sigue verde:

    grep -c 'ots' verification/anchor_root.sha256      # 0: el recibo no está en el root

Medido (`2026-10-09T16:07Z`, local `12:07 -04`):

    rm -rf /tmp/upg && mkdir -p /tmp/upg
    cp verification/anchor_root.sha256 verification/anchor_root.sha256.ots /tmp/upg/ && cd /tmp/upg
    ots upgrade anchor_root.sha256.ots
    #   Got 2 attestation(s) from cache
    #   Success! Timestamp complete                       -> exit 0
    ots info anchor_root.sha256.ots
    #   File sha256 hash: 83001ca2…   (el compromiso; = sha256 del root)
    #   4 PendingAttestation + 2 BitcoinBlockHeaderAttestation
    #     BitcoinBlockHeaderAttestation(970536)  merkle e2376ba95d40…95da
    #     BitcoinBlockHeaderAttestation(970537)  merkle a87a055e88c2…ec05
    sha256sum anchor_root.sha256.ots
    #   6b28be97603ce2b2a2f1879ef5393aaf26c1bf3a0d3338222e9c9551b903141c   (2949 B)
    #   = exactamente el hash que §R-1.5 había medido en /tmp
    ots verify anchor_root.sha256.ots
    #   Assuming target filename is 'anchor_root.sha256'
    #   Could not connect to Bitcoin node: Cookie file unusable …/.bitcoin/.cookie
    #   -> exit 1 por falta de nodo; el compromiso del recibo no se discute
    #      (no hay «File does not match»)
    cp /tmp/upg/anchor_root.sha256.ots verification/anchor_root.sha256.ots

Trazabilidad: el recibo **pendiente** (`e78cab51…`, 945 B) no se pierde; sigue en
el historial, comprobado en el commit padre de la promoción:

    git show 4ddb5f4:verification/anchor_root.sha256.ots | sha256sum
    #   e78cab51c6075e03b8c8ac69ddc442005d71b57d79d13d357e8a4814f05998b9

Un mismo compromiso, dos formas del recibo: el pendiente (lo que viajó por
correo, §R-1.3) y el completado (lo que vive en el repo). Ninguna de las dos
altera el ancla ni el sello: lo sellado fue el root, y el root no cambió.

## R-2 — Recibo OpenTimestamps del root de P6a

Fecha: 2026-10-11, re-anclaje `2026-10-11T21:48:40Z`; el `.ots` sellado a las `21:49Z` (UTC; local `17:49 -04`). HEAD cuyo
árbol se selló: `094c41b`; el `.ots` vive en su propio commit, `ccc7e55`. HEAD anclado
*dentro* del root (el que sella G10): `aaaf460`.

Este sello **sustituye** al de §R-1, y por la razón que el propio §Alcance declara:
`docs/paper/main.tex` cambió (P6a), y todo cambio en cualquiera de los diez ficheros
que el root compromete invalida el sello anterior. El recibo de D1 no se destruye —se
apartó del árbol sólo para poder sellar— y su valor no sale de ese archivo temporal
sino de un comando.

| campo | valor |
|---|---|
| Artefacto sellado | `verification/anchor_root.sha256` (10 pares) |
| SHA-256 del artefacto | `217d6d51384b051e82d74b6d82e09bb111fd779deff280c0383851ba941cf6d5` |
| Recibo | `verification/anchor_root.sha256.ots` (**735 bytes**, **pendiente**) |
| SHA-256 del recibo | `c0ca6425c5af24bd945c2acd433b30e826d47d4f39f50e658ae4a6542fa5ab71` |
| Cliente | `ots` v0.7.2 |
| Envío a calendarios | 4 *(4 líneas `Submitting to remote calendar`)* |
| Atestaciones | **4 `PendingAttestation`** (alice, finney, bob, catallaxy) y **ninguna** `BitcoinBlockHeaderAttestation` todavía; derivado de `ots info`, no de la salida del cliente |
| Verificación | `ots info` → `File sha256 hash: 217d6d51…`: el compromiso del recibo es el del artefacto. `ots verify` → exit 1 con las cuatro líneas `Pending confirmation in Bitcoin blockchain` y **sin** `File does not match`: el recibo resuelve su objetivo y sólo le falta la confirmación en un bloque |
| Sustituye a | `6b28be97603ce2b2a2f1879ef5393aaf26c1bf3a0d3338222e9c9551b903141c` (2949 B; con Bitcoin en los bloques `970536`/`970537`), el recibo de D1 sobre `83001ca2…` |
| Recuperación del anterior | `git show aaaf460:verification/anchor_root.sha256.ots \| sha256sum` → `6b28be97…`: sigue en el historial y no depende de ningún archivo fuera del repo |

Promoción, para cuando toque: el recibo de §R-1 llegó a prueba Bitcoin porque se
volvió a ejecutar `ots upgrade` cuando un calendario ya había agregado el compromiso
en un bloque (§R-1.5–§R-1.6). El de aquí está recién enviado; `ots upgrade
verification/anchor_root.sha256.ots` y el `.ots` se reemplaza otra vez. Promover no
exige re-anclar: el recibo vive fuera del root, que es lo que evita la circularidad.

### R-2.1 Por qué este recibo no invalida las referencias selladas

El root compromete `docs/paper/main.tex` **y** los tres ficheros de `docs/audit/` que
lo citan por número de línea (`claim-registry.csv`, `numerical-verification.md`,
`content-audit-pending.md`). Por eso P6a se hizo **1:1** —doce líneas reemplazadas,
1410 → 1410— y por eso este sello no deja obsoleta ninguna de esas tres citas: las que
ya eran inexactas en `aaaf460` siguen siéndolo (P6b las lleva), y ninguna pasó a serlo
por P6a.

`verification/output_manifest.sha256` no cambió (35 pares idénticos byte a byte), así
que los 35 outputs no se regeneraron: este root sella un árbol en el que lo único que
se movió es el paper y los dos manifiestos que lo sellan.


## R-3 — Recibo OpenTimestamps del root de P6b

Fecha: 2026-10-12, re-anclaje `2026-10-12T00:54:19Z`; el `.ots` sellado a las
`00:55:26Z` y **promovido a prueba Bitcoin** a las `02:46:10Z` (UTC; local
`20:54`/`20:55` del día 11 y `22:46` del 11 `-04`). HEAD al re-anclar:
`d8d2e55` (sobre ese árbol se aplicó el lote P6b, todavía sin commitear); HEAD
anclado *dentro* del root (el que sella G10): `d8d2e55`.

Este sello **sustituye** al de §R-2, y por la razón que el propio §Alcance
declara: P6b tocó `docs/paper/main.tex` y, con él, los tres inputs sellados que
lo citan por número de línea. §R-2.1 dejó escrito que las citas de esos tres
ficheros "las que ya eran inexactas en `aaaf460` siguen siéndolo (P6b las
lleva)". P6b no se limitó a llevarlas: las **re-derivó** (§R-3.1), y el sello de
§R-2 quedó obsoleto en cuanto el root cambió de digest.

| campo | valor |
|---|---|
| Artefacto sellado | `verification/anchor_root.sha256` (10 pares) |
| SHA-256 del artefacto | `79ac6783523cf2c656795ac146107122cafc101d8fa4c27bcfebb5d91d0b4fdd` |
| Recibo | `verification/anchor_root.sha256.ots` (**2774 bytes**, **promovido**: con atestación Bitcoin) |
| SHA-256 del recibo | `46755224943988d0d4353c5e82f11960920220a9df696bb679141f655904d8c5`; el pendiente de 805 B era `1e5e5cb69748872a34060d668a6bde2d5ec5fe35be0f04588edc5dc376dbd2f8` |
| Cliente | `ots` v0.7.2 |
| Envío a calendarios | 4 *(4 líneas `Submitting to remote calendar`)* |
| Atestaciones | **2 `BitcoinBlockHeaderAttestation` en los bloques `971017` y `971018`** (llegadas por `alice` y `bob`), más 4 `PendingAttestation` que quedan como ramas ya innecesarias; derivado de `ots info`, no de la salida del cliente |
| Verificación | `ots info` → `File sha256 hash: 79ac6783…`: el compromiso del recibo es el del artefacto. `ots verify` → exit 1 con `Could not connect to Bitcoin node: Cookie file unusable ([Errno 2] No such file or directory: '/home/ilich/.bitcoin/.cookie')`, es decir, este entorno no tiene nodo Bitcoin: la prueba está **en el recibo** y se comprueba con un nodo. Los dos bloques existen en la cadena: `curl -s https://blockstream.info/api/block-height/971017` → `00000000000000000000f418a6953e467b4ae6e63ab99060c1ffc735dc1763b3` y `…/971018` → `0000000000000000000144f8b6d6f77d0ea60cac10fe025b4130773b6b4abf70` |
| Sustituye a | `c0ca6425c5af24bd945c2acd433b30e826d47d4f39f50e658ae4a6542fa5ab71` (735 B; pendiente), el recibo de P6a sobre `217d6d51…` |
| Recuperación del anterior | `git show HEAD:verification/anchor_root.sha256.ots \| sha256sum` → `c0ca6425…`: sigue en el historial y no depende de ningún archivo fuera del repo |
| Commits del lote | `3955d91` (el aparato C1–C4, las citas re-derivadas y el root), `874188c` (este recibo), `14dcee0` (§R-3 y §R-3.1) |

Promoción — y aquí llegó: `ots upgrade verification/anchor_root.sha256.ots` →
`Got 1 attestation(s) from https://bob.btc.calendar.opentimestamps.org`,
`Got 1 attestation(s) from https://alice.btc.calendar.opentimestamps.org`,
`Success! Timestamp complete` (bloques `971017` y `971018`). El recibo pasó de
805 a **2774 bytes** y de pendiente a prueba Bitcoin en la misma sesión, sin
re-sellar y **sin re-anclar**: el `--check` posterior devuelve exit 0 con
`anchor_root.sha256` idéntico byte a byte (10 pares), que es la demostración de la
regla — el recibo vive fuera del root, y eso es lo que evita la circularidad.

Una trampa del cliente que este sello encontró: `ots stamp` **no sobrescribe** un
`.ots` existente (`Failed to create timestamp 'verification/anchor_root.sha256.ots':
[Errno 17] File exists`) y, aun así, **ya ha enviado** el compromiso a los cuatro
calendarios. El envío no se pierde, pero el `.ots` hay que generarlo apartando el
anterior (es lo que hacen §R-1 y §R-2). El primer intento de aquí fue exactamente
eso: 4 envíos, `.ots` intacto (`c0ca6425…`); el `.ots` de 805 bytes salió del
segundo, y `ots info` confirma que su compromiso es el root de P6b. Sobre ese
mismo compromiso —y sin un tercer envío— `ots upgrade` construyó después el
promovido de 2774 bytes.

### R-3.1 Por qué este recibo sí invalida las referencias selladas — y qué se hizo

§R-2.1 pudo escribir "este sello no deja obsoleta ninguna de esas tres citas"
porque P6a se hizo **1:1** (1410 → 1410 líneas). P6b no: el aparato C1–C4 llevó el
paper de **1410 a 1566 líneas** (`wc -l docs/paper/main.tex`; 1410 en `d8d2e55`),
al convertir bloques `center` en `table[H]` con `\caption` y añadir texto. Toda
cita `main.tex:NNNN` de los tres inputs sellados quedaba, por tanto, desplazada, y
el root de §R-2 sellaba el desfase.

La re-derivación se hizo con un mapa de líneas `difflib` HEAD → árbol de trabajo
(`/tmp/p6b_pointers.py`, herramienta desechable, no versionada) sobre las formas de
cita que el repo usa: `` `main.tex` LNNN ``, `main.tex:NNN`, `:NNN` y `LNNN` de
continuación —con ancla al fichero nombrado más cercano, para no tocar las
`L20`/`L40` de `threshold_quantization.py`— y la columna `line` de
`claim-registry.csv`. Resultado derivado:

- **316** tokens citados: **313** re-derivados, **1** histórico (marcado
  `antigua`/`forma parte de una`), y **3** irresolubles por diseño: los
  `main.tex:35` de `content-audit-pending.md` y `eje-vi-style-report.md`, ya
  muertos antes de P6a (pre-C-44).
- **23** ficheros reescritos, `claim-registry.csv` incluido (27 filas).
- Validación estructural: **396** citas mapeadas, **0** cambios de sección LaTeX
  (una cita desviada habría cambiado de sección) y el mapa estrictamente
  monótono.
- Los dos `.py` cuyo *stdout* imprime citas (`zk/threshold_quantization.py`,
  `rmt/clique_spectra_seeds.py`) se regeneraron, y sus cuatro copias
  (`baseline_verified/` más los `results/`) coinciden byte a byte:
  `output_manifest.sha256` cambia en **2 pares** y los otros **33** son
  idénticos.

Una precisión de método: el remap **mueve números, no adjudica significados**. Donde
una cita ya era imprecisa en `d8d2e55`, esta re-derivación la deja imprecisa en el
mismo sentido. El caso quedó medido: la frase que `content-audit-pending.md` cita
como "nearby values give similar results" vive en `main.tex:1183` de `d8d2e55` y en
`:1268` del árbol actual; las citas que la invocan —`content-audit-pending.md` con
`:1133` y `F-019` en `numerical-verification.md` con `:1215`— se remapearon a
`:1215` y `:1304`, así que siguen sin apuntar a la frase, exactamente como en
`aaaf460`. La validación estructural confirma que cada cita conserva su sección
padre (`\subsection{Reproducibility}` para `:1133`→`:1215`, `Stability of
Conclusions` para `:1183`→`:1268`, `Summary of the Section` para `:1215`→`:1304`).
Decidir *qué* debe citar cada número es una edición de contenido, no una
re-derivación, y no forma parte de este lote.

Nota de disciplina: el commit de P6b debe preservar los diez ficheros que el root
compromete tal como quedaron aquí. Cualquier retoque posterior exige re-anclar;
`bash verification/fase0_anchor.sh --check` (G11) lo dice en un comando.

## R-4 — Recibo OpenTimestamps del root de P7

Fecha: 2026-10-12, re-anclaje `2026-10-12T03:28:48Z`; el `.ots` sellado a las
`03:29Z` y **promovido a prueba Bitcoin** a las `19:54Z` (UTC; local `23:28`/`23:29`
del día 11 y `15:54` del día 12, `-04`). HEAD al re-anclar:
`bfe329d` (sobre ese árbol se aplicó el lote P7a, todavía sin commitear); HEAD
anclado *dentro* del root (el que sella G10): `bfe329d`. El lote se commiteó como
`6440ac5`, padre del commit que añade este recibo; la promoción vive en un commit
posterior (§R-4.2).

Este sello **sustituye** al de §R-3, por la razón que el propio §Alcance declara:
P7a tocó `docs/paper/main.tex` (los metadatos del PDF). El recibo de P6b no se
destruye —se apartó del árbol sólo para poder sellar— y su valor sale de un
comando, no de ese archivo temporal.

| campo | valor |
|---|---|
| Artefacto sellado | `verification/anchor_root.sha256` (10 pares) |
| SHA-256 del artefacto | `5d6002ba02234120106fa272586f657d0d07649d58ca0f5368fadaf30890f22e` |
| Recibo | `verification/anchor_root.sha256.ots` (**5058 bytes**, **promovido**: ya con atestación Bitcoin) |
| SHA-256 del recibo | `38910c8d61292fb77b3390a9f38d12b946a1774c6b1c369f43fe5dc8cab04910`; el **pendiente**, el que se selló a las `03:29Z`, era `f6209374b6e33d601c1eb138005fd8c0788312629ce1684c3feec702c14a16fa` (910 B) y sigue recuperable (§R-4.2) |
| Cliente | `ots` v0.7.2 |
| Envío a calendarios | 4 *(4 líneas `Submitting to remote calendar`)* |
| Atestaciones | **4 `BitcoinBlockHeaderAttestation`**, una por calendario, en los bloques `971035`, `971036`, `971047` y `971090`, más las 4 `PendingAttestation` que quedan como ramas ya innecesarias; derivado de `ots info`, no de la salida del cliente |
| Verificación | `ots info` → `File sha256 hash: 5d6002ba…`: el compromiso del recibo es el del artefacto. `ots verify` → exit 1 con `Could not connect to Bitcoin node: Cookie file unusable ([Errno 2] No such file or directory: '/home/ilich/.bitcoin/.cookie')`, es decir, este entorno no tiene nodo Bitcoin: la prueba está **en el recibo** y se comprueba con un nodo. Los cuatro bloques existen en la cadena y sus raíces merkle coinciden con las del recibo: `curl -s https://blockstream.info/api/block-height/971090` → `00000000000000000001c16f3f5772150f617a42a50a4379b18edd634d131ed3`, y las otras tres en §R-4.2 |
| Agregación en Bitcoin | **dentro del recibo desde 2026-10-12**, 16 h después del sello: los bloques `971035`–`971090`, el primero a las `03:46:29Z` (17 min después del sello) y el último a las `12:06:00Z` — ver §R-4.2 |
| Sustituye a | `46755224943988d0d4353c5e82f11960920220a9df696bb679141f655904d8c5` (2774 B; con Bitcoin en los bloques `971017`/`971018`), el recibo de P6b sobre `79ac6783…` |
| Recuperación del anterior | `git show 874188c:verification/anchor_root.sha256.ots \| sha256sum` → `46755224…`; en la misma sesión se copió a `/tmp/root_79ac6783_r3.ots` |

Promoción — y aquí llegó, 16 h después del sello: `ots upgrade
verification/anchor_root.sha256.ots` sobre el fichero del repo →

    Got 1 attestation(s) from https://btc.calendar.catallaxy.com
    Got 1 attestation(s) from https://bob.btc.calendar.opentimestamps.org
    Got 1 attestation(s) from https://finney.calendar.eternitywall.com
    Got 1 attestation(s) from https://alice.btc.calendar.opentimestamps.org
    Success! Timestamp complete                                        -> exit 0

Respondieron **los cuatro** calendarios, así que el recibo pasó de 910 a **5058
bytes** y de pendiente a prueba Bitcoin, sin re-sellar y **sin re-anclar**: el
`--check` posterior devuelve exit 0 con `anchor_root.sha256` idéntico byte a byte
(10 pares), que es la demostración de la regla — el recibo vive fuera del root, y
eso es lo que evita la circularidad. El transcript y el cruce contra un explorador
están en §R-4.2.

### R-4.1 Por qué este recibo no invalidó ninguna referencia sellada

§R-3.1 tuvo que re-derivar 316 tokens porque P6b llevó el paper de 1410 a 1566
líneas. P7a hizo lo contrario: los metadatos del PDF entraron **en la línea 19 ya
existente** (`\hypersetup{…}`), así que `main.tex` sigue con **1566 líneas** y el
root se movió en **un solo par** —el del paper— de sus diez. Medido:

    wc -l docs/paper/main.tex                                # 1566 antes y después
    git diff --stat -- verification/anchor_root.sha256       # 1 línea (el par del paper)
    git diff --stat -- verification/audit_manifest.sha256    # 3 líneas (sello, HEAD, main.tex)
    git diff --exit-code -- verification/output_manifest.sha256   # sin cambio: 35 pares idénticos

Consecuencia: las citas `main.tex:NNNN` de los tres inputs sellados siguen siendo
válidas por construcción, sin remap — **120** de esa forma sola
(`grep -oh 'main\.tex:[0-9]\+' docs/audit/claim-registry.csv
docs/audit/numerical-verification.md docs/audit/content-audit-pending.md | wc -l`)
más las formas continuadas `:NNN`, que son posicionales. Y como lo único que
cambió es el contenido de la línea 19, ninguna cita puede apuntar a una línea
distinta: la más baja de las selladas es la **35**, que da el mismo comando con
`| grep -oE '[0-9]+$' | sort -n | head -1`. La regla que esto deja está en §4 del
`handoff.md`: una edición en el sitio cuesta una línea; una que cambia el recuento
de líneas cuesta el mapa entero.

    sha256sum verification/anchor_root.sha256             # 5d6002ba… (artefacto sellado)
    sha256sum verification/anchor_root.sha256.ots         # 38910c8d… (5058 B, promovido en §R-4.2; el pendiente era f6209374…, 910 B)
    strings verification/anchor_root.sha256.ots | grep -oE 'https://[a-z0-9._/-]+' | sort -u   # 4 calendarios (2ª vía)
    ots info verification/anchor_root.sha256.ots          # 4 BitcoinBlockHeaderAttestation + 4 PendingAttestation
    ots verify verification/anchor_root.sha256.ots        # exit 1 sin nodo; sin «File does not match»
    ots upgrade verification/anchor_root.sha256.ots       # idempotente tras la promoción de §R-4.2

### R-4.2 Promoción del estado completado (misma sesión, 2026-10-12)

§R-1.6 promovió copiando a `/tmp`; §R-3 promovió sobre el fichero del repo, en la
misma sesión. Aquí, lo segundo. Antes de sustituir nada se comprobó que el resultado
fuera el esperado: §R-4.1 dejó el sello ejecutado a las `03:29Z`, y a las `03:37Z`
—cuando corrió la guarda— `ots info` seguía **sin** ninguna atestación Bitcoin. No
era un fallo: el primer bloque que agregó el compromiso no llegó hasta las
`03:46:29Z`.

Efecto de la promoción, medido y no recordado:

    ls -l verification/anchor_root.sha256.ots       # 5058 B (el pendiente: 910)
    sha256sum verification/anchor_root.sha256.ots   # 38910c8d61292fb77b3390a9f38d12b946a1774c6b1c369f43fe5dc8cab04910
    ots info verification/anchor_root.sha256.ots | grep -c BitcoinBlockHeaderAttestation   # 4
    ots info verification/anchor_root.sha256.ots | grep -c PendingAttestation              # 4 (ramas ya innecesarias)
    strings verification/anchor_root.sha256.ots | grep -oE 'https://[a-z0-9._/-]+' | sort -u   # los 4 calendarios (2ª vía)
    ots upgrade verification/anchor_root.sha256.ots  # idempotente: otra vez «Success! Timestamp complete», sha256 sin cambio
    ots info verification/anchor_root.sha256.ots | head -1   # File sha256 hash: 5d6002ba… (el compromiso no cambió)

Las cuatro atestaciones, cada una con la raíz merkle que imprime `ots info`
(`… | grep -E 'BitcoinBlockHeaderAttestation|merkle root'`), y el cruce contra un
explorador público — bloque por altura, raíz por hash de bloque:

| calendario | bloque | merkle root (del recibo) | hora del bloque (explorador) |
|---|---|---|---|
| `alice` | `971035` | `ec1a44c248ff78885896762904ab57fb13e4f482c4a6504458f24d5198674cf9` | `2026-10-12T03:46:29Z` |
| `bob` | `971036` | `e8b74a39dd7403576085d41c459e347c6e829a1c6c2c5b339400e732a8d852fc` | `2026-10-12T03:53:14Z` |
| `finney` | `971047` | `33918556ce05fd459bbee9a5d80dc4e6affb6cdf24b6e4eb0d3be39305cf1d64` | `2026-10-12T05:02:23Z` |
| `catallaxy` | `971090` | `6f0e51f1479f48f8af74ba2a0fe130a14c91470dd9aaca1386624b88687d713e` | `2026-10-12T12:06:00Z` |

    for h in 971035 971036 971047 971090; do
      bh=$(curl -s https://blockstream.info/api/block-height/$h)                       # 0000000000000000000…: los cuatro hashes existen
      curl -s https://blockstream.info/api/block/$bh | python3 -c 'import sys,json;print(json.load(sys.stdin)["merkle_root"])'
    done        # cuatro líneas, idénticas a la columna «merkle root (del recibo)»

Las cuatro coinciden y las cuatro alturas existen en la cadena: eso **no** es
verificación criptográfica completa —haría falta el encabezado del bloque, es decir
un nodo— y el explorador es un tercero: se cita como medición, no como prueba. Lo
que sí trae el recibo desde la promoción es la prueba: cuatro
`BitcoinBlockHeaderAttestation` dentro del `.ots`, que es justo lo que §R-1.2
distingue del simple recibo de envío.

Trazabilidad del pendiente: el `.ots` sellado a las `03:29Z` (`f6209374…`, 910 B)
no se pierde; sigue en el historial, comprobado en el commit que lo añadió, y
también en la copia fuera del repo:

    git show 37e69cf:verification/anchor_root.sha256.ots | sha256sum
    #   f6209374b6e33d601c1eb138005fd8c0788312629ce1684c3feec702c14a16fa
    sha256sum /tmp/r4_pending_f6209374.ots               # el mismo valor
    sha256sum verification/anchor_root.sha256.ots.bak    # f6209374… otra vez: el cliente
    #   movió el pendiente a FILE.bak en el propio `upgrade` (`otsclient/cmds.py`),
    #   así que hay una tercera copia en disco; está ignorada por `.gitignore`
    #   (*.ots.bak) porque su valor es el del historial

Copia out-of-band: §R-1.3 mandó por correo el `.ots` **pendiente** del root de D1
(945 B) —lo que se puede enviar en el momento del sellado—. Para R-4 **no hay envío
registrado**: la copia del pendiente vivió en `/tmp/r4_pending_f6209374.ots` y en el
historial de git (`37e69cf`), que no son testigos externos; el testigo externo de
R-4 es su cadena de Bitcoin, no un correo. Lo que conviene copiar fuera del repo es
ahora el `.ots` **promovido** (`38910c8d…`, 5058 B), y eso sigue **pendiente**.

Nota de cronología: el compromiso es **anterior** al primer bloque que lo agregó
(`03:46:29Z`) — el sello es de las `03:29Z`, y la hora de un bloque la declara el
minero, acotada por la regla de *median-time-past*. Promover no exige re-anclar: lo
sellado fue el root, que no cambió, y este fichero no está entre los diez —lo
demuestra el `git diff --stat` de §R-4.1, que ve **una** sola línea, la del paper.

## R-5 — Recibo de la re-derivación de punteros de P9.4

P9.4 repite el trabajo de §R-3.1 sobre el árbol que dejan P9.1, P9.2 y F-022.
`main.tex` pasa de **1566 a 1578 líneas** (`git diff --numstat`: 21 inserciones y 9
borrados) en diez hunks, de modo que toda cita `main.tex:NNN` sellada queda
desplazada. La re-derivación se hizo con `~/p9/p9_pointers.py` (herramienta
desechable, no versionada) y **no** con `difflib`: el mapa se deriva de los hunks del
diff —que son exactos— y resulta una función a trozos estrictamente monótona:

| rango en HEAD (`607f9b9`) | rango en el árbol de trabajo | causa |
|---|---|---|
| 1–1029 | 1–1029 (identidad) | hunks 1:1 en 41, 58–59, 76, 976 y 1028 |
| 1030 | 1030 | reemplazo 1→8; la frase de reducción de reputación sigue aquí |
| 1031–1032 | 1038–1039 | cola del reemplazo anterior |
| 1033–1322 | +8 | inserción en 1040 (`\label{subsec:freshness}`) |
| 1323–1566 | +12 | cuatro líneas insertadas en 1331 (publisher y ventana de detección) |

Cifras derivadas (tabla puente completa en `~/p9/p9_table.tsv`, 422 filas):

- **411 tokens** de texto inventariados en 25 ficheros: `main.tex:NNN` 263,
  `` `main.tex` LNNN `` 32, `` `:NNN` `` 101 y `:NNN` desnudo 15; más las **27** filas
  del registro con columna `line`.
- **120 punteros reescritos** (71 + 9 + 29 + 6 de texto, más 5 en el registro) en
  **9 ficheros** del alcance; los otros cuatro no tenían ningún puntero desplazado.
- **11 overrides** verificados a mano donde el párrafo cita el paper sin nombrar
  `main.tex` (P8.2/P8.4 del plan y seis líneas de `content-audit-pending.md`).
- **0 cambios de sección LaTeX**: al ser el mapa monótono, ninguna cita puede
  cruzar un `\section`/`\subsection`.
- Segunda pasada **byte-idéntica**: la transformación toma siempre el blob de `HEAD`
  como base, así que es una función pura y no acumula desplazamiento.

**Alcance y exclusiones.** Se reescriben solo los documentos que forman parte del
ancla auditada y siguen vivos: los siete informes de auditoría, `claim-registry.csv`
y el plan. Quedan **sin remapear**, por decisión registrada aquí:

- `docs/audit/triage-external-review-2026-10.md` (hoja de trabajo sin sellar): 24
  punteros que habrían entrado.
- `anchor-receipts.md` (este fichero): sus §R-3.1 y §R-4 citan lo que se hizo a
  líneas concretas; remapearlas falsificaría el recibo.
- `verification/eip_cost_check.py` y `data-layer/attacker_profit_analytical.py`: su
  comentario de línea **se imprime** en el output sellado, de modo que remapear el
  fuente rompería el baseline sin beneficio (mismo criterio que P6b).
- Cuatro scripts más (`src/zk/.../range_proof.rs`, `rmt/calibration_heavy_tail.py`,
  `rmt/clique_spectra_seeds.py`, `zk/threshold_quantization.py`) y cuatro outputs
  sellados: fuera del alcance de P9.4.
- Las diez líneas de **crónica** del plan (1725, 1735, 1743, 2170, 2224, 2232, 2234,
  2238, 2241, 2640), que citan lo que P6a/P6b hicieron: esos números son hechos
  históricos, no punteros vivos.

**Citas ya muertas.** La columna `muertos` de la tabla puente marca **98** punteros
cuya línea destino no existe o está en blanco: 71 en ficheros del alcance
(`content-audit-pending.md` 38, plan 8, `eje-v` 6, `eje-iii` 6, `session-report` 4,
`eje-vi-session-context` 3, `eje-vi-style` 2, `eje-ii` 2, `eje-iv` 1, registro 1) y
27 en ficheros solo informados. El remap **mueve el número, no adjudica el
significado**: una cita muerta sigue muerta, desplazada igual que las vivas, para que
una futura corrección parta de la misma base. El caso medido es el de §R-3.1 otra
vez: `content-audit-pending.md` dice que `R_{\mathrm{std}}` aparece en
`main.tex:1063`, `:1126` y `:1133`, pero en HEAD esas líneas son una blanca,
`\subsection{Results}` y `\begin{tabular}` —las ocurrencias reales están en
1106/1174/1268—; tras P9.4 la cita es `:1071`, `:1134`, `:1141` y sigue sin apuntar
a la frase. Decidir *qué* debe citar cada número es edición de contenido.

**Verificación.** `bash verification/audit-gate.sh` da **8 PASS / 3 FAIL** tanto
antes como después de remapear: G4, G5 y G6 —las tres guardas que leen el registro y
los dos documentos— pasan con los ficheros reescritos, y G9 (`pdflatex` limpio,
errors=0, Undefined=0) confirma que el paper sigue compilando. Los tres FAIL
(G2 `EXIT 0 = 35/36`, G10 manifiesto de 35 outputs, G11 `fase0_anchor`:
`output_manifest.sha256` discrepa) son **pre-existentes** del lote de `M-05`, no de
este remap: se reproducen idénticos con los documentos revertidos a HEAD
(`git stash push -- docs/audit docs/architecture/implementation-plan.md`).

**Nota de disciplina.** Este recibo no se remapea (§R-4.1) y P9.4 no toca `main.tex`:
los números de §R-3.1 y §R-4 siguen siendo los que fijó cada sello. El commit de P9.4
debe preservar los nueve documentos tal como quedaron, y el re-anclaje de P9.5 es el
que sella el conjunto.

**Anexo — inventario nominal de las 98 citas muertas.** Formato `L<línea del
documento>:<número citado>`; todos los números citan `main.tex`, y la lista se
re-deriva con `awk -F'\t' '$6!="ok"' ~/p9/p9_table_final.tsv`. Un muerto no es
necesariamente un error: el propio plan documenta en P9.1 que `:837` y `:805` están
en blanco hoy. **Casi todos son ≤1029, o sea identidad pura: ya estaban muertos en
HEAD**; los únicos desplazados son `L1726:1305`, `L684:1090`, `L774:1066` y
`L126:1305`.

- `content-audit-pending.md` (38): L45:837, L69:805, L77:469, L96:469, L150:469,
  L183:176-188, L245:286, L246:1071, L279:286, L281:1071, L355:231-233,
  L391:231-233, L555:665, L651:325, L651:445, L651:456, L661:463-464, L681:325,
  L681:445, L684:1090, L694:803, L702:469, L708:469, L716:279-286, L717:1071,
  L751:286, L753:1071, L765:1063, L772:1063, L774:1066, L1165:81, L1187:42,
  L1346:727, L1385:116, L1409:42, L1410:75, L1537:460, L1537:535.
- `implementation-plan.md` (8): L539:526, L1726:1305, L1739:70, L2688:974-980,
  L2689:114-116, L2691:229, L2839:837, L2839:805.
- `threshold_quantization.py` (10): L8:445, L10:805, L19:325, L21:463-464, L25:526,
  L41:463-464, L47:526, L48:526, L67:805, L97:325.
- `eje-iii-counters-report.md` (6): L42:42, L43:42, L44:72, L45:75, L46:81, L47:116.
- `eje-v-integrated-read-report.md` (6): L43:42, L43:75, L89:77, L104:206,
  L126:1305, L142:176.
- `session-report.md` (4): L94:803, L146:803, L171:619, L182:621.
- `eje-vi-session-context.md` (3): L38:768, L158:768, L255:768.
- `eje-ii-consistency-report.md` (2): L103:641, L137:564.
- `eje-vi-style-report.md` (2): L168:768, L171:768.
- `eje-iv-reproduction-report.md` (1): L661:727. `claim-registry.csv` (1): L10:286.
- **Solo informados, no reescritos** (17; los 10 de `threshold_quantization.py` van
  arriba): `triage-external-review` 13 (L156:764, L462:953-1000, L995:166-169,
  L997:187-190, L999:837, L999:837, L999:805, L999:805, L1070:879-901,
  L1070:1231-1258, L1165:837, L1165:805, L1259:187-190);
  `attacker_profit_analytical.py` 2 (L7:975-979, L80:975-979); los dos outputs
  sellados de `threshold_quantization` 2 (`baseline_verified/…output.txt` L7:325 y
  `zk/results/…output.txt` L7:325). `bloque-b-report.md` no tiene ninguna.

Suma: 81 + 17 = 98.

### R-5.1 — Cierre del re-anclaje (P9.5, 2026-10-17)

El cuerpo de §R-5 selló la **re-derivación de punteros** de P9.4; este cierre sella el
**árbol** en el que esos punteros viven. El ancla vigente describía el `main.tex` de
`fb5cae97` (1566 líneas); P9.1, P9.2 y F-022 lo llevaron a `b2085341` (1578 líneas,
21 inserciones y 9 borrados) sin re-anclar, de modo que `fase0_anchor.sh --check` y las
guardas G2, G10 y G11 llevaban en **FAIL** desde el lote `M-05` (8 PASS / 3 FAIL).
P9.5 regenera la evidencia con el pipeline completo —36 scripts, `m05_attack_model.py`
incluido— y re-sella.

| artefacto | antes (HEAD `607f9b9`) | después (árbol sellado) |
|---|---|---|
| `docs/paper/main.tex` | `fb5cae97…` (1566 líneas) | `b2085341…` (1578 líneas) |
| `output_manifest.sha256` | 35 pares | **36 pares** |
| `fase1_determinism_evidence.txt` | 35 líneas `EXIT 0` | **36 líneas** |
| `baseline_verified/manifest.txt` | 36 filas | 36 filas (regeneradas) |
| `anchor_root.sha256` | `5d6002ba…` | `459be332…` |
| `anchor_root.sha256.ots` | sellaba `5d6002ba…` | sella `459be332…` |

**Corrida.** `bash verification/run_all.sh`: 36 scripts, 36 códigos de salida cero, 0
`MISSING`, 5 340 s de cómputo acumulado. Los 35 outputs preexistentes salen
**byte-idénticos** a los de HEAD —`git status` no marca ninguno; el único fichero nuevo
es `m05_attack_model_output.txt`—, lo que confirma el determinismo que §R-3.1 declaró
con `cmp -s`. La máquina estaba cargada (load ~12 sobre 6 núcleos): los scripts con BLAS
multihilo tardaron hasta 13× más (`calibration_heavy_tail` 873 s frente a 66,4;
`recalibrate_top` 820 s frente a 62,9) sin que cambiara un byte del resultado, mientras
que los monohilo conservaron su tiempo base (`heavy_tail_n5000` 945,7 s frente a 920;
`heavy_tail_scaled_clique` 500,5 s frente a 499). La corrida se partió en dos tramos por
un corte de suministro y se retomó con `--resume`: las 27 filas ya cerradas se
conservaron y solo se re-ejecutaron las 9 restantes; el `heavy_tail_n5000` interrumpido
se rehízo entero, sin heredar su salida parcial.

**Gate.** `bash verification/audit-gate.sh`: **PASS=11 FAIL=0 SKIP=0**. Las tres guardas
cierran por su causa, no por relajación: G2 `EXIT 0 = 36/36`, G10 `manifiesto verifica
(36 outputs; HEAD anclado 607f9b9 -> actual 607f9b9)` y G11 `ancla re-derivada byte a
byte (fase0_anchor.sh --check, exit 0)`. G5 sigue en **21** por diseño: F-022 (21→22) se
difiere a P9.6 junto con P9.3 —el manifiesto de conteos—, porque los literales 21/50
viven dentro de `audit-gate.sh` y subirlos en este mismo commit habría roto G5 mientras
se re-anclaba.

**OTS.** `ots stamp verification/anchor_root.sha256` sella `459be332…` con cuatro
atestaciones **pendientes**: `alice.btc.calendar.opentimestamps.org`,
`bob.btc.calendar.opentimestamps.org`, `btc.calendar.catallaxy.com` y
`finney.calendar.eternitywall.com`. Pendiente significa aún sin confirmación en bloque
Bitcoin: `ots upgrade` la resolverá en unas horas y, hasta entonces, el sello prueba
*cuándo se envió*, no que esté en la cadena. El `.ots` anterior —que sellaba
`5d6002ba…`, el `anchor_root.sha256` de HEAD— queda reemplazado; su copia se conserva
fuera del repo en `~/p9/anchor_root.sha256.ots.antiguo_12oct`. El `.ots` no figura entre
los diez pares de `anchor_root.sha256`, de modo que instalarlo no invalida el ancla.

**Alcance.** P9.5 no edita `main.tex` ni los nueve documentos de P9.4: sus trece sha256
son los mismos antes y después (el `main.tex` del árbol sigue siendo el de ayer, mtime
2026-10-16 12:29). Lo que cambia en `verification/` es exactamente el resultado de
re-ejecutar el pipeline y re-sellar: `manifest.txt`, `output_manifest.txt` (las dos
copias), `output_manifest.sha256`, `audit_manifest.sha256`, `anchor_root.sha256` y su
`.ots`. `fase0_anchor.sh --check` sale con **exit 0**.

### R-6 — Manifiesto de conteos y registro de `M-05` (P9.6a, 2026-10-17)

R-5.1 cerró el re-anclaje de P9.5 dejando una deuda explícita: los conteos que el
gate verifica seguían siendo literales dentro de los ficheros sellados. `audit-gate.sh`
fijaba 21 entradas `F-` y 50 worksheets `C-`; `fase0_anchor.sh:196` imprimía «35
pares» con 36 reales. El triage externo había declarado ambos cambios inseparables
(«La entrada `F-022` y el manifiesto de conteos van juntos, o no van»): añadir `F-022`
sin desacoplar G5 del literal habría dejado el gate en FAIL por diseño. R-6 los
entrega en un solo acto.

| artefacto | antes (`690a151`) | después (este lote) |
|---|---|---|
| entradas `### F-` | 21 | **22** (`F-022`) |
| pares de `anchor_root.sha256` | 10 | **11** (`count_manifest.txt`) |
| G5 / G6 | literales `21` / `50` | claves `F-log` / `C-log` selladas |
| G2 (esperado) | filas del manifiesto de la corrida | clave `scripts` + contraste con el README |
| `fase0_anchor.sh --check` | «(35 pares)» tecleado | «(36 pares)» derivado |
| `anchor_root.sha256` | `459be332…` | `559af48c…` |
| `anchor_root.sha256.ots` | sella `459be332…` | sella `559af48c…` |

**`F-022` registra `M-05`, no una corrección de conteos.** La entrada documenta la
medición que el triage declaró necesaria (A-18/A-21): la deterción
`q > G/(G+L)` evaluada sobre la latencia de detección `k` en épocas, con
`G(k, ω) = k·ω·ΔS` y `L = S_f*(r_fraud) + n·κ`, en lugar de los escalares de la
hoja de cálculo (`V_fraud = 1.0`, `S_slash = 10.0`), que no son cantidades del
protocolo. `m05_attack_model.py` (semilla 42, 10 000 réplicas) da, para el tipo de
peor caso (`ω = 0.10`), `q > 0.0625` a una época, `0.25` a cinco y `0.375` a las
nueve que admite la frescura (`γ·k < 1`), con un punto de ruptura
`k_be(q = 0.10, ω = 0.01) = 16.67` más allá de esa ventana: para el tipo de bajo
capital con detección lenta la cota es vacua. El paper ya cita el script en §7.5 y
§7.8 (ventana declarada, no impuesta on-chain, DEC-3); lo que faltaba era su
registro en `numerical-verification.md`. La entrada ocupa el hueco 22 que el propio
`--check` reclamaba.

**El manifiesto.** `verification/count_manifest.txt` declara tres pares
clave-valor —`F-log 22`, `C-log 50`, `scripts 36`— con el formato documentado en
cabecera y sin fecha, de modo que es determinista byte a byte. `fase0_anchor.sh` lo
hashea como **11.º par** del root (orden fijo: 3 del ancla + 4 del verificador +
3 inputs estables + el manifiesto). `audit-gate.sh` lo lee con `cman()` y compara
contra la re-derivación: G5 y G6 contra `grep -c '^### [FC]-'`, G2 contra las líneas
`EXIT 0` de la evidencia **y** contra el número de comandos `python3` del README, de
forma que manifiesto y catálogo no pueden separarse. Una clave ausente o un valor
desfasado es FAIL explícito con ambos números; el manifiesto de la corrida conserva
su comprobación de 0 `MISSING`. Cambiar un conteo exige ahora editar un fichero
sellado, que mueve el root y obliga a re-anclar: la misma disciplina que el resto.

Las tres rutas de fallo se probaron por mutación temporal y se restauró el fichero
byte-idéntico: `F-log 22→21` → `G5 FAIL F- entries = 22 (manifiesto: 21)`; clave
`scripts` borrada → `G2 FAIL count_manifest sin clave 'scripts'`; `scripts 36→37` →
`G2 FAIL scripts en README = 36 != manifiesto = 37`.

**La línea 196.** `fase0_anchor.sh` deriva el número de pares del fichero regenerado
(`wc -l` sobre el `output_manifest.sha256` del directorio temporal que acaba de
compararse), así que el mensaje no puede volver a desfasarse. Sus comentarios y los
del gate se actualizan a 11 pares; el texto «10 ficheros» desaparece de los ficheros
sellados.

**Gate y determinismo.** `bash verification/audit-gate.sh` → **PASS=11 FAIL=0
SKIP=0**, con `G2 EXIT 0 = 36/36 scripts (manifiesto)`, `G5 F- entries = 22
(manifiesto: 22)`, `G6 C- worksheets = 50 (manifiesto: 50)` y `G10 ... HEAD anclado
690a151 -> actual 690a151`; `bash verification/fase0_anchor.sh --check` → exit 0,
`36 pares` y `11 pares` derivados.

**OTS.** `ots stamp` sella `559af48c…` con cuatro atestaciones pendientes (alice,
bob, catallaxy, finney). El `.ots` que sellaba `459be332…` —con dos transacciones
Bitcoin en curso, `16489786…` (alice) y `43aa805c…` (catallaxy)— queda reemplazado
en el árbol pero se conserva en el commit `690a151` y fuera del repo en
`~/p9/anchor_root.sha256.ots.459be332_pre_R6`. Ningún `.ots` figura entre los 11
pares: instalarlo no invalida el ancla. `ots upgrade` se repetirá en P9.6b hasta
obtener atestación de bloque.

**Alcance.** Sellados tocados: `audit-gate.sh` (par 4), `fase0_anchor.sh` (par 5),
`numerical-verification.md` (par 9) y `count_manifest.txt` (par 11, nuevo), más
`anchor_root.sha256` y su `.ots`. No sellados: este recibo y
`implementation-plan.md`. `main.tex` (`b2085341…`, 1578 líneas),
`content-audit-pending.md` y `claim-registry.csv` quedan intactos.

**Rojo esperado antes de R-7.** Fase 4 (texto de `main.tex`) y `M9a/b/c`
(`integrations/`) tocan ficheros sellados sin regenerar los manifiestos, de modo
que `G10` y `G11` —y con ellos el resumen del gate— estarán en **FAIL** durante
todo ese tramo. Es el estado previsto por la decisión O1 (una sola re-ancla para
Fase 4 + M9, en lugar de tres intermedias), no una regresión: no se corrige, no se
regeneran manifiestos y no se commitea un ancla parcial. El único criterio de
salida es **R-7** con `PASS=11 FAIL=0 SKIP=0` y `fase0_anchor.sh --check` exit 0
sobre el lote cerrado.


### R-7 — Cierre de Fase 4 (texto del paper) y M9a/b/c: re-anclaje único (2026-10-17)

**Qué cierra.** El tramo que el recibo de R-6 declaró en rojo esperado: el texto de Fase 4
en `main.tex` y la verificación de `M9a/b/c` en `integrations/`. Una sola re-ancla para
ambos, conforme a la decisión O1. `M9a/b/c` no aporta cambios de fichero —sus contratos ya
estaban commiteados y `git status` no los lista—, así que el lote sellado que se mueve es el
texto del paper.

**El pre-compromiso.** `ab8f268` (`docs/audit/fase4-decisions.md`) firmó DEC-1…DEC-5 antes
de tocar una línea. La verificación DEC↔código se hizo contra `AVIPRegistry.sol`,
`AVIPStakeVault.sol` y `AVIPValidatorManager.sol`: las cinco decisiones describen el código
entregado. DEC-4 se resolvió como falsa alarma: `slash(address,bytes32)` no lleva importe
porque el importe *es* el stake completo (`amount = _stakes[validator]`, `_stakes = 0`).

**Los siete cambios (ocho líneas), todos de redacción.** (i) `:76` — cae «financial stake and
reputation are partial substitutes in the cost of admission»; la regla ahora dice que la
reputación *rebaja el stake que la admisión exige*, que es lo que DEC-5 firma (un crédito,
no colateral apropiable). (ii) `:280` — `$C_R(r)$` deja de llamarse «reputational collateral»
y pasa a «reputation-weighted access cost». (iii) `:769` y (iv) `:774` — «reputational
collateral destruction» → «the decay of reputation». (v) `:817` — la definición de `$C_R$` en
la ecuación de admisión, mismo término. (vi) `:1037` — `$L = S_f^*$` → `at least $S_f^*$`,
porque `slash` toma el stake entero que el registro nombra. (vii) `:1076` — `$C_R(0)$` en
génesis, mismo término.

**El cambio delicado, `:1333`.** La limitación de DEC-3 estaba infravalorada: v1 no tiene
*ninguna* salida voluntaria, de modo que `$L \to 0$` no es un riesgo lento sino inalcanzable.
Se comprobó antes de escribir: `grep -nE 'exit|unstake|withdraw|release'` sobre
`AVIPValidatorManager.sol` devuelve **cero** coincidencias, y en `AVIPStakeVault.sol` solo
aparece `withdraw`, capado por `withdrawable = escrowed - ceil(stakeOf)` mientras el validador
está admitido (el propio contrato lo documenta: «no cooldown and no exit queue: leaving the
set is the manager's business»). El texto nuevo afirma exactamente eso: la premisa del modelo
se cumple *por construcción* —no hay salida y el único camino fuera del conjunto admitido es
el slash—, y lo que falta no es el escrow sino la ordenación: un unbonding delay y una
challenge window on-chain son trabajo posterior, y una salida futura tendría que secuenciarse
contra la adjudicación antes de poder leer~\eqref{eq:deterrence} como cobertura.

**Evidencia de texto.** `grep -c 'partial substitutes'` = 0 y `grep -c 'reputational
collateral'` = 0. `main.tex` sigue en 1578 líneas, el resumen conserva «twenty-two claims»
(G5) y no entra ninguna tabla, figura ni ecuación nuevos (G8 = 0 mezclas Estimate/Verified).
`pdflatex` ×2: `errors=0`, `Undefined=0`, PDF de 554 688 bytes.

**Evidencia de código.** `forge test --offline` en `integrations/avalanche`: 9 suites,
**262 tests passed, 0 failed, 0 skipped**.

**Evidencia de ancla.** `run_all.sh`: 36/36 scripts con `EXIT 0`; los 36 outputs son
byte-idénticos a los del ancla anterior (`git diff` de `baseline_verified/` vacío salvo
`manifest.txt`, que solo cambia la columna `runtime_s` y no figura en la lista cerrada).
`fase0_anchor.sh`: 36 outputs, sello UTC `2026-10-18T00:04:17Z`, HEAD anclado `ab8f268`;
root nuevo `943dc96a…` (el anterior era `559af48c…`), con los 11 pares y `main.tex` movido de
`b2085341…` a `24132371…` como único par distinto. `fase0_anchor.sh --check` → exit 0
(`36 pares` y `11 pares` idénticos byte a byte). `audit-gate.sh` → **PASS=11 FAIL=0 SKIP=0**,
con `G10 ... HEAD anclado ab8f268 -> actual ab8f268` y `G11 ... exit 0`: los dos rojos
declarados en R-6 quedan cerrados.

**OTS.** `ots stamp` sella `943dc96a…` con tres atestaciones pendientes (alice, bob,
catallaxy); el cuarto calendario enviado (Eternity Wall) aún no había devuelto atestación en
esta corrida. El `.ots` que sellaba `559af48c…` se conserva en `727fc1a` y fuera del
repo en `~/p9/anchor_root.sha256.ots.559af48c_pre_R7`. Ningún `.ots` figura entre los 11
pares. `ots upgrade` se repetirá hasta obtener atestación de bloque.

**Alcance.** Sellados tocados: `main.tex` (par 1), `anchor_root.sha256` (derivado) y su
`.ots`. `output_manifest.sha256` no cambia; `audit_manifest.sha256` cambia solo en el sello
UTC y el HEAD. No sellados: este recibo, `baseline_verified/manifest.txt` (registro de la
corrida) e `implementation-plan.md`.

### R-8 — Gas del deploy de Fuji en el paper (P10): re-anclaje (2026-10-18)

**Qué cierra.** LOT 1 / P10: el gas de las cinco creaciones del deploy de Fuji
(chain 43113) entra en el paper como medición reproducible offline. No toca
contratos, ni F-022, ni el registro de claims.

**La medición.** `verification/fuji/read_fuji_gas.py` lee los tres broadcast JSON
pineados (`token.json`, `sink.json`, `phase1.json`), empareja transacción y
recibo por `transactionHash`, exige `chain == 43113` y `status == 0x1`, y deriva
gas y coste con `Decimal`; no consulta ningún RPC. La salida son las cinco filas,
el `TOTAL`, `chain_id=43113` y `block_range=59670678-59670735`. El total es
7.787.000 gas y 1.24592e-9 AVAX a 160 nAVAX; el `1.2459552e-09` del ejemplo del
encargo no sale de esa aritmética y no se usó. La tabla `tab:fuji-gas` de
`main.tex` redondea esas cifras y se insertó antes de `\subsection{Estimates and
Their Provenance}` (la numeración actual es §4.6; el encargo la llamaba §6).
§9.4 *Deferred Benchmarks* remite a la tabla.

**Evidencia de determinismo.** `run_all.sh` → 37/37 `EXIT 0`, 0 `MISSING`; los
36 outputs anteriores son byte-idénticos (solo cambia `manifest.txt` por los
runtimes y la fila nueva, y `output_manifest.txt` +1). `read_fuji_gas_output.txt`
(anclado) y `baseline_verified/fuji_gas_output.txt` (copia de conveniencia, no
anclada) son byte-idénticos. `pdflatex` ×2: `errors=0`, `Undefined=0`, PDF de
38 páginas.

**El ancla.** `fase0_anchor.sh`: 37 outputs, sello UTC `2026-10-19T02:47:07Z`,
HEAD `d46349c`; root nuevo `6715786f…` (el anterior era `943dc96a…`), con los
11 pares; `main.tex` pasa de `24132371…` a `32fc7738…`, y también cambian
`count_manifest.txt` (36→37) y `run_all.sh`.
`audit-gate.sh` → **PASS=11 FAIL=0 SKIP=0**, con `G2 EXIT 0 = 37/37 scripts
(manifiesto)`, `G10 ... HEAD anclado d46349c -> actual d46349c` y `G11 ... exit
0`; `fase0_anchor.sh --check` → exit 0 (37 pares y 11 pares idénticos).

**OTS.** `ots stamp` sella `6715786f…` con cuatro atestaciones pendientes
(alice, bob, catallaxy, finney). La versión instalada (0.7.2) no acepta `-o`:
escribe `verification/anchor_root.sha256.ots` por defecto, que es la ruta
requerida. El `.ots` anterior (que sellaba `943dc96a…`) se conserva fuera del
repo en `~/p9/anchor_root.sha256.ots.943dc96a_pre_R8`. Ningún `.ots` figura entre
los 11 pares.

**Alcance.** Sellados tocados: `main.tex` (par 1), `count_manifest.txt` (par 11),
`run_all.sh` (par 6), `anchor_root.sha256` (derivado) y su `.ots`; además
`output_manifest.sha256`/`audit_manifest.sha256` (derivados),
`verification/output_manifest.txt` y `baseline_verified/` (registro de corrida).
No sellados: este recibo, `README.md`, `verification/README.md`,
`fase1_determinism_evidence.txt` y `fuji_gas_output.txt`. F-022 no tocado.

### R-9 — Block time de Fuji C-Chain en el paper y F-022 (P10b): re-anclaje (2026-10-18)

**Qué cierra.** LOT 2 / P10b: el block time de Fuji C-Chain entra en el paper
como medición reproducible offline y se reescribe F-022
(`docs/audit/numerical-verification.md`) para que su conversión de épocas a
tiempo de pared use esa medición. No toca contratos; sí toca el registro de
claims (fila F-022) y la sección §9.4 de `main.tex`.

**La medición.** `verification/fuji/measure_block_time.py` lee el fixture
pineado `verification/fuji/fixtures/block_times_59670000_59670099.json` (100
bloques consecutivos, `59670000`–`59670099`, obtenidos una vez vía Alchemy) y
valida `chain == 43113`, números consecutivos, timestamps no decrecientes y
hashes no vacíos. No consulta ningún RPC en la corrida normal: el fixture es la
fuente canónica offline. Una comprobación puntual de 40 bloques emparejados
contra el RPC público `api.avax-test.network` coincidió en número, timestamp y
hash; no forma parte del pipeline. La corrida mide 99 deltas: mediana 1.0 s,
p95 11.0 s (rango más cercano, *nearest-rank*), mínimo 0.0 s, máximo 28.0 s,
media 2.545 s; distribución `{0:3, 1:53, 2:28, 3:2, 4:6, 5:1, 8:1, 11:1, 13:1,
23:1, 25:1, 28:1}`. El p84 es 2.0 s: el «2.0 s» del encargo no es la mediana.
El p95 de 11.0 s no es el valor interpolado (8.3 s); se usa el rango más
cercano porque es el criterio declarado en el script y en F-022.

**F-022.** Se reescribió con la estructura Claim under test / Test / Verdict /
Empirical anchor / Conclusion / Sample. La fórmula de disuasión es
`q > G/(G+L)` con `G = k·ω·ΔS` (la versión anterior usaba una forma
incorrecta). La medición fija el block time, no la duración de la época: el
mapeo época↔bloque es un parámetro de diseño no fijado on-chain. F-022 declara
`N_b` (bloques por época) y `B` (block time), de modo que `k` épocas abarcan
`k·N_b·B`; con la mediana `B = 1.0 s` y con el p95 `B = 11.0 s` (máximo
observado 28.0 s). La condición de disuasión se evalúa contra los percentiles
altos, no contra la mediana; el ancla fija `B` y su cola, pero no fija `N_b`,
así que por sí sola no convierte `k` épocas a segundos. Los valores de `q_min`
no cambian: el block time sólo pone escala temporal a `k`. La latencia de
Teleporter queda diferida a §9.4 y no se mezcla con esta medición. §9.4 de
`main.tex` incorpora las mismas cifras (mediana 1.0 s, p95 11.0 s, mínimo
0.0 s, máximo 28.0 s), declara el mapeo época↔bloque como parámetro de diseño y
usa la cola alta (p95/máximo) como escala conservadora, no la mediana; no
presenta la medición como benchmark del protocolo.

**Evidencia de determinismo.** La corrida ejecutó los 38 scripts:
`38/38 EXIT 0`, 0 `MISSING`; la finalización de la lista de salida se completó
con `run_all.sh --resume` (38/38 ya completos, exit 0) y
`verification/output_manifest.txt` quedó con 38 rutas. Los 37 outputs
anteriores son byte-idénticos a `384008a` (sólo cambian `manifest.txt` por los
runtimes y la fila nueva, `output_manifest.txt` +1 y aparece el output 38).
`measure_block_time_output.txt` (anclado) y
`baseline_verified/fuji_block_time_output.txt` (copia de conveniencia, no
anclada) son byte-idénticos. `pdflatex` ×2: `errors=0`, `Undefined=0`.

**El ancla.** `fase0_anchor.sh`: 38 outputs, sello UTC
`2026-10-19T03:53:22Z`, HEAD `384008a`; root nuevo `e5c3333c…` (el anterior
era `6715786f…`; el intermedio de la corrección P2/P3 fue `b01899db…`), con
los 11 pares. `main.tex` pasa de `32fc7738…` a `e451bd1e…`;
`numerical-verification.md` pasa de `4d484691…` a `3d35456e…`,
`count_manifest.txt` en `460f2f69…` y `run_all.sh` en `0e6b5117…`. `audit-gate.sh` → **PASS=11
FAIL=0 SKIP=0**, con `G2 EXIT 0 = 38/38 scripts (manifiesto)`, `G10 ... HEAD
anclado 384008a -> actual 384008a` y `G11 ... exit 0`; `fase0_anchor.sh
--check` → exit 0 (38 pares y 11 pares idénticos).

**OTS.** `ots stamp` sella `e5c3333c…` con cuatro atestaciones pendientes
(alice, bob, catallaxy, finney). La versión instalada (0.7.2) no acepta `-o`:
escribe `verification/anchor_root.sha256.ots` por defecto, que es la ruta
requerida. El `.ots` anterior (que sellaba `6715786f…`) se conserva fuera del
repo en `~/p9/anchor_root.sha256.ots.6715786f_pre_R9`; los intermedios
`8b5d8dd7…` (ordinal del *Sample* de F-022) y `b01899db…` (corrección P2/P3)
en `~/p9/anchor_root.sha256.ots.8b5d8dd7_pre_R9_fix` y
`~/p9/anchor_root.sha256.ots.b01899db_pre_P3_fix`, respectivamente. El root
intermedio se conserva en `~/p9/anchor_root.sha256.b01899db_pre_P3_fix`.
Ningún `.ots` figura entre los 11 pares.

**Alcance.** Sellados tocados: `main.tex` (par 1), `output_manifest.txt`
(par 2), `output_manifest.sha256` (par 3), `run_all.sh` (par 6),
`numerical-verification.md` (par 9) y `count_manifest.txt` (par 11); además
`anchor_root.sha256` (derivado) y su `.ots`, y `audit_manifest.sha256`
(derivado). `baseline_verified/` cambia como registro de corrida (manifiesto,
lista de salida y output 38). No sellados: este recibo,
`verification/README.md`, `fase1_determinism_evidence.txt`,
`fuji_block_time_output.txt`, el script nuevo y el fixture.
