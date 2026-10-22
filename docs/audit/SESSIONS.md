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
| S-016 | 2026-10-22 | Validación de la matriz externa y triaje del mapa | este commit | adfd08d2… | cerrada; G10/G11 ya rojo en `ea75594` (T-5) |

S-016 cubre `triage-mapa-2026-10-22.md`, el acta
`checklist-matriz-evidencia-2026-10-22.md` y la v2
`matriz-evidencia-2026-10-22.md`. El `Root` no se mueve porque el cambio no
toca ningún fichero del ancla; se re-deriva con el comando de arriba sobre este
commit. La matriz y el mapa recibidos se conservan sin editar como evidencia de
lo que se auditó: no son documentos normativos y no se citan como si lo fueran.
El gate de auditoría sigue en 9 PASS / 2 FAIL **igual que antes** de este
commit: G10/G11 discrepan porque `docs/paper/main.tex` cambió en `ea75594` sin
re-sellar. Es T-5, no un efecto de S-016.
