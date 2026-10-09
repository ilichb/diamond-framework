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
