# Recibos de anclaje — sellado externo de `anchor_root.sha256`

Fecha: 2026-10-08. Sello en `2026-10-08T21:34:05Z` → `21:34:07Z` (UTC).
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
| Recibo | `verification/anchor_root.sha256.ots` (945 bytes) |
| SHA-256 del recibo | `e78cab51c6075e03b8c8ac69ddc442005d71b57d79d13d357e8a4814f05998b9` |
| Cliente | `ots` v0.7.2 (`opentimestamps-client` 0.7.2, `opentimestamps` 0.4.5, Python 3.10.12) |
| Envío a calendarios | 4 *(4 líneas `Submitting to remote calendar` en la salida del cliente)* |
| Atestaciones | 4, **pendientes** de confirmación en Bitcoin |
| Verificación | `ots verify verification/anchor_root.sha256.ots` → `exit 1`, con 4 líneas `Pending confirmation in Bitcoin blockchain` |
| Copia out-of-band | **pendiente** — ver §R-1.3 |

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

- Con las atestaciones **pendientes**, el `.ots` es un **recibo de envío**, no
  una prueba: un calendario que aún no ha agregado el compromiso a un bloque no
  ha firmado nada. `ots verify` sale `1` en este estado, y eso es el estado
  esperado, no un fallo.
- Cuando un calendario agregue la atestación, `ots upgrade` añade la prueba de
  Bitcoin al `.ots`; el fichero cambia, su hash cambia, y este recibo pasa de
  *pending* a *confirmed* con el número de bloque. **Verificar el estado
  confirmado exige un nodo Bitcoin Core local (podado basta) o calendarios
  alcanzables; verificar el estado pendiente, no.**
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

Estado: **no enviada**. El canal decidido es correo con **dos destinatarios**
(`To: ilichblanco@andromedacomputer.net` más una `Cc` en un proveedor distinto de
`andromedacomputer.net`, de modo que el testigo cruce dos dominios de confianza
independientes de GitHub). La dirección de la `Cc` aún no está fijada.

Se deja dicho en vez de escribir la frase «emailed …», porque un recibo que
afirma un envío que no ocurrió es peor que un recibo que declara la ausencia:
mientras la copia de este repositorio sea la **única** copia, no hay testigo
contra la manipulación del propio repositorio. Ilich envía el `.ots` y un commit
posterior de sólo documentación registra la fecha y la `Cc` reales.

### R-1.4 Reproducción

    python3 -m venv ~/.local/venvs/ots && ~/.local/venvs/ots/bin/pip install opentimestamps-client==0.7.2
    ots stamp verification/anchor_root.sha256                    # 4 envíos; escribe el .ots
    strings verification/anchor_root.sha256.ots | grep -c 'https://'   # 4 (2ª vía del conteo)
    sha256sum verification/anchor_root.sha256.ots                # e78cab51…
    ots verify verification/anchor_root.sha256.ots               # pending -> exit 1
    ots upgrade verification/anchor_root.sha256.ots              # tras la confirmación en Bitcoin
