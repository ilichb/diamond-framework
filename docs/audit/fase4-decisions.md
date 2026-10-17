# Pre-compromiso de Fase 4 — DEC-1 … DEC-5

**Fecha:** 2026-10-17. **Árbol:** HEAD `727fc1a` (P9.6a; `anchor_root` `559af48c…`,
11 pares; gate `PASS=11 FAIL=0 SKIP=0`). **Firma:** ilichb
&lt;gerencia@andromedacomputer.net&gt;.

Este documento fija, **antes** de editar `main.tex`, qué se decide en cada una de
las cinco decisiones de contenido y cómo se verificará. Regla de ejecución: si
durante el lote algún cambio exige apartarse de un párrafo de aquí, el lote **se
detiene** y se re-planifica; no se improvisa. Fase 4 es un solo lote (O3): el
`main.tex` completo se edita de una vez, sin mitades, y `pdflatex` debe cerrar
limpio antes de R-7.

**Estado de partida de `M9`.** `M9a`, `M9b` y `M9c` ya están entregados en código
(`AVIPRegistry.sol`: `guardian`, `CHANGE_DELAY = 2 days`, `ZeroGuardian`;
`AVIPValidatorManager.sol`: `EJECTION_SURCHARGE = 1e17`, `_stakes`, `slash(validator,
reason)` sin importe). Lo que queda de `M9` es **verificación** (`forge test`
`--offline` una vez al final, O2), no implementación; Fase 4 declara el estado que
esos contratos ya tienen.

## DEC-1 — Alcance y custodia: opción (B)

**Decisión.** §7.3 conserva la frase «the delivered data layer … does not move
funds» y **añade los dos sujetos que omite**: el manager que adjudica y debita
(`AVIPValidatorManager`) y el vault de custodia que guarda el escrow. La frase se
cualifica, no se borra: el defecto era un actor ausente, no una afirmación falsa.
**Aceptación.** §7.3 nombra ambos sujetos; «the delivered manager» de §7.4 tiene
ahora antecedente; `custody` deja de aparecer solo en «chain of custody».
**Firma.** ilichb, 2026-10-17.

## DEC-2 — Secuenciador: opción (B) + declarar el estado

**Decisión.** §10.2 declara el estado tras `M9a`: un `guardian` multisig es el
único proposer de `sequencer` y `verifier`; la ejecución es permissionless tras
`CHANGE_DELAY`; ambos setters emiten evento; `address(0)` se rechaza; y **el
verifier sigue mutable**, con su razón — congelarlo convertiría un bug de circuito
en un redeploy del registry, que perdería el historial de commitments
(`_roots`/`_changedEntries`) del que depende `admit`. `sequencer` no aparece hoy en
`main.tex`: esto es una adición, no una corrección.
**Aceptación.** §10.2 enumera los cinco hechos y la razón de la mutabilidad;
ninguna frase presenta el verifier como inmutable.
**Firma.** ilichb, 2026-10-17.

## DEC-3 — Eje temporal: restricción declarada, no enforcement

**Decisión.** La ventana de detección es una **restricción del modelo**; `M-05`
(parametrizado en `F-022`) evalúa la deterción sobre la latencia `k` en épocas; una
challenge window on-chain es **follow-up** y queda explícitamente fuera de v1.
§7.4/§5.7 usan las cifras del script (tipo de peor caso: `q > 0.0625` a una época,
`0.25` a cinco, `0.375` a las nueve que admite `γ·k < 1`) y §10.2 declara la
ventana como constraint.
**Aceptación.** §10.2 contiene la frase de follow-up; ninguna cifra nueva aparece
sin `\fref{verification/mechanism/m05_attack_model.py}`.
**Firma.** ilichb, 2026-10-17.

## DEC-4 — Importe del slash: opción (A)

**Decisión.** `L` es **todo el stake posteado** (`_stakes[validator]`) y el importe
sale del payload de Teleporter. `L ≥ S_f*(T) ∈ [0.2, 1.0]`, **sin cota superior**,
porque `admit` no limita nada. `Θ = 1.0` es la **convención de cobertura del
modelo**, no un cap ejecutable. Se elimina la cláusula del importe suministrado por
el llamante; §7.4 y §9.4 etiquetan `Θ` como convención.
**Aceptación.** §7.4 y §9.4 dicen «model's coverage convention»; no queda frase que
presente `Θ = 1.0` como límite impuesto; `S_slash = 10.0` deja de citarse como
cantidad del protocolo.
**Firma.** ilichb, 2026-10-17.

## DEC-5 — Reputación: opción (B) + (C) honesto

**Decisión.** `M9c` hace del coste de re-entrada un **recargo de eyección
separado** (`requiredStakeFor(norm) + n_ejections·κ`), nunca una inflación de
`requiredStakeFor`: `collateral` sigue derivándose de la norma y `Θ − C_R` no puede
volverse negativo. §7.5 retira la reducción de reputación que nada escribe; el
abstract y §1.2 pasan de «reputational collateral» / «partial substitutes» a
**reputation-weighted access cost**. El título se mantiene: describe el descuento
que `collateralFor` aplica.
**Aceptación.** §7.5 no atribuye al slash un efecto sobre reputación; abstract y
§1.2 usan «access cost»; `grep -c 'partial substitutes'` = 0.
**Firma.** ilichb, 2026-10-17.

## Fuera de alcance en v1 (O4)

No entran en este lote: las 98 citas muertas (inventariadas en §R-5), `.zenodo.json`,
el triage untracked, la bibliografía `N-8`/`N-14` y `N-9…N-15`. **Excepción:** si un
defecto de redacción rompe un gate (`G5`, `G8`, `G9`), entra; si no, se queda para
v2.

## Condiciones de parada

1. `G10` y `G11` estarán en **FAIL** durante Fase 4 y `M9` (§R-6, decisión O1): es
   el estado previsto, no se corrige ni se regeneran manifiestos hasta el cierre.
2. `pdflatex` debe terminar con `errors=0, Undefined=0` (G9) antes de R-7.
3. `forge test --offline` se corre **una vez** al final (O2); si falla, bisección
   por contrato, no por milestone.
4. Un único re-anclaje, **R-7**, con `PASS=11 FAIL=0 SKIP=0` y `--check` exit 0.
5. Cambiar cualquiera de las cinco decisiones de este documento obliga a detener el
   lote y re-planificar; no se aplica sobre la marcha.
