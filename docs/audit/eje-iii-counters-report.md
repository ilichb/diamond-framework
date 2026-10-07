# Eje (iii) — Contadores y punteros (paper ↔ repo)

Fecha: 2026-10-07
HEAD (base): `2bfb946` (antes del fix C-37; el fix va en `3f998e7`).
Alcance: cifras autorreferenciales (cuántos scripts, cuántas entradas,
cuántas contribuciones/componentes, conteos de C-/F-) en
`docs/paper/main.tex` y en los ficheros de auditoría
(`handoff.md`, `content-audit-pending.md`, `numerical-verification.md`,
`eje-iv-reproduction-report.md`).
Guard: todo contador se DERIVA; el valor correcto nunca se teclea de
memoria.

## Metodología

- **Derivar, no teclear.** Cada contador sale de un comando reproducible.
- **Contar ambas formas.** Se buscan las cifras en dígitos (`35`, `21`)
  y en palabras (`four`, `twenty-one`), por la clase de bug que
  cerraron C-26 y C-27.
- **Parar en la primera discrepancia** entre prosa y derivación → finding
  nuevo con el ciclo modelar → fix → verificar → commit.

## Derivaciones (comandos reproducibles)

| Contador | Comando | Valor |
|---|---|---|
| Findings C- | `grep -c '^### C-' docs/audit/content-audit-pending.md` | 37 |
| Entradas F- | `grep -c '^### F-' docs/audit/numerical-verification.md` | 21 |
| Filas C- (handoff) | `grep -c '^\| C-' docs/audit/handoff.md` | 37 |
| Scripts (no-archivo) | `find verification -name '*.py' -not -path '*/archive/*' \| wc -l` | 35 |
| Scripts (archivo) | `find verification -name '*.py' -path '*archive*' \| wc -l` | 7 |
| Scripts (total) | `find verification -name '*.py' \| wc -l` | 42 |
| README `python3` | `grep -c '^    python3 ' verification/README.md` | 35 |
| Ítems §1.2 (problemas) | `enumerate` de `main.tex` §1.2 | 5 |
| Contribuciones §1.3 | ítems en negrita de `main.tex` §1.3 | 4 |
| Componentes §12 | ítems del `enumerate` de `main.tex` §12 | 5 |
| Configuraciones §5/§12 | filas del output `recalibrate_top` | 5 |

## Tabla de cruce (paper)

| # | Dónde | Prosa | Derivado | Estado |
|---|---|---|---|---|
| 1 | `main.tex:49` | "four contributions" | 4 (§1.3) | OK |
| 2 | `main.tex:49` | "twenty-one claims" | 21 (F-log) | OK |
| 3 | `main.tex:79` | "addresses all five" | 5 (§1.2) | OK |
| 4 | `main.tex:82` | "four contributions" | 4 (§1.3) | OK |
| 5 | `main.tex:88` | "twenty-one quantitative claims" | 21 | OK |
| 6 | `main.tex:123` | "~67 minutes ... 15 min ... 24 min" | 67 | OK |
| 7 | `main.tex:1115` | "the 35 scripts" | 35 | OK |
| 8 | `main.tex:1117` | "21 entries (F-001 through F-021)" | 21 | OK |
| 9 | `main.tex:1127-1142` | §9.2 table + "All others < 5 s each" | 15 filas ≥5 s | **C-37** |
| 10 | `main.tex:1147` | "~67 minutes ... 15 min ... 24 min" | 67 | OK |
| 11 | `main.tex:1200` | "21 entries documented" | 21 | OK |
| 12 | `main.tex:1319` | "built from five components" | 5 (§12) | OK |
| 13 | `main.tex:1327` | "the five simulated configurations" | 5 | OK |
| 14 | `main.tex:1330` | "with 21 entries" | 21 | OK |
| 15 | `main.tex:1376` | "Falsification log & 21 entries" | 21 | OK |

## Tabla de cruce (auditoría)

| # | Dónde | Prosa | Derivado | Estado |
|---|---|---|---|---|
| 16 | `handoff.md:36` | "C-01 through C-36" / "36 findings" | 36 | OK (→ C-37) |
| 17 | `handoff.md:200` | "35 non-archived (42 total, 7 archive)" | 35 / 42 / 7 | OK |
| 18 | `handoff.md:208` | "F-001 through F-021 (21 entries)" | 21 = 17+3+1 | OK |
| 19 | `content-audit-pending.md:4-6` | "C-01…C-10", "C-11…C-36" | 36 | OK (→ C-37) |
| 20 | `content-audit-pending.md:1376` | "C-01 through C-36 are closed" | 36 | OK (→ C-37) |
| 21 | `eje-iv-reproduction-report.md:13` | "518 tokens" | 490+13+7+4+1+2+1 | OK |
| 22 | `eje-iv-reproduction-report.md:30` | "94.6 %" | 490/518 | OK |

## Findings

### C-37 — §9.2 runtime table omits the heavy-tail rows

La tabla de §9.2 listaba trece scripts y cerraba con
`All others < 5 s each`, pero la propia subsección y §1.4 citan dos
scripts (fuera de la tabla) a `15 min` y `24 min`. Caían en "All others",
cuyo límite `< 5 s each` era falso, y contradecía la resolución de C-18
("match the README rows at ≥5 s"). Fix en `main.tex` §9.2: añadidas las
filas `heavy_tail_scaled_clique.py` `~24 min` y `heavy_tail_n5000.py`
`~15 min` (valores derivados de `verification/README.md`). Commit:
`3f998e7`. Detalle en `content-audit-pending.md` (bloque C-37).

## No-findings (registros históricos)

Los bloques C-16 y C-17 de `content-audit-pending.md` citan `30 scripts`
y `19 entries` como el estado en el momento de su cierre. El suite creció
después (30 → 35 scripts por commits posteriores; 19 → 21 entradas por
F-020/F-021). No son discrepancias: son instantáneas de su fecha,
conservadas como registro de cierre (convención del worksheet). El
contador VIVO del paper (§9) sí se re-derivó a 35 y 21 (C-25).

## Cierre

Contadores del paper y de los ficheros de auditoría derivados y
cruzados. Un finding: C-37 (Minor), cerrado en `3f998e7`. Con C-37, el
paper queda internamente coherente en sus contadores autorreferenciales.
