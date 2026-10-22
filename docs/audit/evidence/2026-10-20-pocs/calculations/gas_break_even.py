#!/usr/bin/env python3
"""Reproduce la tabla de gas/break-even de P-25.

Fórmula del paper: un atacante paga R = 684.064 USD (o N = 0,2236 ETH al
precio de la sesión) por un fraude; el protocolo paga G de gas por admisión.
El atacante queda indiferente cuando

    N / G = gas_price * 1e-9  (N en ETH, gas_price en gwei)
    g* = N * 1e18 / G / 1e9

No se usan librerías externas. La salida se escribe también en
`gas-table.csv`, junto a este script.

Uso:
    python3 gas_break_even.py
"""

import csv
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

N_ETH = Decimal("0.2236")
R_USD = Decimal("684064")


def gwei(G: int) -> Decimal:
    """Break-even gas price in gwei for `G` gas units."""
    return (N_ETH * Decimal(10) ** 18 / Decimal(G) / Decimal(10) ** 9).quantize(
        Decimal("0.1"), rounding=ROUND_HALF_UP
    )


def main() -> None:
    rows = [
        ("206000", "clave inline (paper)", 206_000),
        ("223403", "verify, caliente", 223_403),
        ("233104", "verifyThreshold, caliente", 233_104),
        ("286144", "verifyThreshold, frío (harness nuevo)", 286_144),
        ("290854", "verifyThreshold, frío (harness previo)", 290_854),
        ("376588", "manager.admit completo", 376_588),
    ]

    out = [
        "# P-25 — gas y break-even",
        "",
        "| G (gas) | Ruta | g* (gwei) | R/G |",
        "|---:|---|---:|---:|",
    ]
    csv_rows = [("gas", "route", "g_star_gwei", "ratio_R_over_G")]

    for label, route, G in rows:
        g = gwei(G)
        ratio = (R_USD / Decimal(G)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
        out.append(f"| {label} | {route} | {g} | {ratio}× |")
        csv_rows.append((label, route, str(g), str(ratio)))

    out += [
        "",
        "Lectura: el 3,32× del paper sólo se reproduce con 206k. La ruta fría",
        "desplegada da ≈2,39× y el break-even cae a ≈781 gwei; con el harness",
        "previo (290.854) da ≈769 gwei. El cociente 455.430/286.144 ≈ 1,59× no",
        "se incluye porque mezcla ingest optimizado con verificación sin optimizar.",
        "",
        "Decisión: G canónico = 286144 (verifyThreshold frío, sólo verificación):",
        "2,39× y 781,4 gwei. Si se reporta manager.admit completo, G = 376588:",
        "1,82× y 593,8 gwei; ambos lados deben usar el mismo alcance y compilador.",
        "",
        "A 25 gwei, el margen de la ruta fría es 781/25 ≈ 31,2×, no 43×.",
    ]

    text = "\n".join(out) + "\n"
    print(text)

    csv_path = Path(__file__).with_name("gas-table.csv")
    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerows(csv_rows)
    print(f"escrito: {csv_path}")


if __name__ == "__main__":
    main()
