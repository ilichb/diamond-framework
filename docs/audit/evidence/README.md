# Evidence

Evidencia de auditoría separada de los informes y del worksheet. Cada carpeta
lleva la fecha de la sesión y contiene su propio `README.md` con el estado de
recuperación y la regla de conservación.

| Carpeta | Contenido | Estado |
|---|---|---|
| `2026-10-20-pocs/` | POCs, gas/break-even y bitácora de la sesión del 2026-10-20 | Parcial: los fuentes originales se perdieron; hay inventario, dos reconstrucciones ejecutables y dos PoCs nuevas (P-26 y addendum P-12) |

Regla: un POC temporal se escribe primero aquí. No se borra. Si hay que
ejecutarlo, se copia a `integrations/avalanche/test/` y se retira **sólo la
copia**, después de guardar el log en `logs/`.
