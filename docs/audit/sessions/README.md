# Session logs

Un fichero por sesión, con la plantilla `_TEMPLATE.md`. El índice maestro es
`../SESSIONS.md`; el `Root` de cada fila es `sha256sum verification/anchor_root.sha256`
en el árbol final de la sesión, no el hash de `main.tex`.

**Al inicio de una sesión.** Leer las cinco últimas filas de `../SESSIONS.md`,
leer completo `S-<última>.md`, ejecutar `git log --oneline -5` y
`bash verification/fase0_anchor.sh --check`. Confirmar el estado antes de tocar
nada. **Al cierre.** Escribir `S-NNN.md`, añadir la fila al índice y commitear
ambos con el lote (o en un commit propio si el lote no requiere commit). No se
re-ancla el log: vive fuera del ancla a propósito. `handoff.md` sigue siendo el
snapshot durable; `session-report.md` es la narrativa legacy del content audit;
`verification/fase1_determinism_evidence.txt` es la evidencia del harness. No
existe `session-log.md` append-only en este repositorio; no se inventa uno.
