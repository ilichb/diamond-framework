#!/usr/bin/env python3
"""
eip_cost_check.py — Cierra la brecha aritmetica del gas de las precompilas
EIP-196/197 (finding C-51; entrada F-017 de docs/audit/numerical-verification.md).

El paper mide con Foundry (Solc 0.8.33, OPTIMIZER OFF, igual que el resto de
benchmarks; ver main.tex:474 y main.tex:1159-1168) el gas de las precompilas
BN254 y lo compara con el esquema de EIP-196 (ecAdd, ecMul) y EIP-197
(ecPairing):

    ecAdd      = 150
    ecMul      = 6000
    ecPairing  = 45000 + 34000*k      (k = numero de pares)

La medicion incluye un OVERHEAD CONSTANTE de harness de 142 gas (una sola
staticcall dispatch: main.tex:1168, "The overhead is 142 gas in all five
measurements"). Por tanto:

    medido = base_EIP + 142           (para toda precompila)

Este script verifica, contra la salida cruda del benchmark
(integrations/avalanche/benchmark_output_v2.txt), que:

    150  + 142                 == 292      (ecAdd)
    6000 + 142                 == 6142     (ecMul)
    45000 + 34000*k + 142      == medido   (k in {1, 2, 4})
    marginal por par           == 34000    (k2-k1 y (k4-k2)/2)

Procedencia: todas las cifras se leen del benchmark crudo; ninguna se teclea de
memoria (regla de la auditoria: un valor en prosa sin comando originador es una
hipotesis, no un valor). Reproducibilidad: aritmetica entera cerrada; sin Monte
Carlo, sin semilla.

Uso:
    python3 verification/eip_cost_check.py [ruta_benchmark]

Salida: tabla de comprobacion + veredicto PASS/FAIL (exit 0/1).
"""

import os
import re
import sys

# --- Esquema EIP (constantes de protocolo, NO medidas) ---
ECADD_EIP = 150
ECMUL_EIP = 6_000
PAIRING_BASE = 45_000
PAIRING_PER = 34_000
HARNESS_OVERHEAD = 142  # main.tex:1168

DEFAULT_BENCH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "integrations", "avalanche", "benchmark_output_v2.txt",
)


def parse_measured(path):
    """Lee los cinco valores medidos de la salida cruda de Foundry."""
    text = open(path, encoding="utf-8").read()
    rows = {}
    rows["ecAdd"] = int(re.search(r"ecAdd gas:\s*(\d+)", text).group(1))
    rows["ecMul"] = int(re.search(r"ecMul gas:\s*(\d+)", text).group(1))
    for k in (1, 2, 4):
        m = re.search(r"ecPairing k=%d gas:\s*(\d+)" % k, text)
        rows["pairing%d" % k] = int(m.group(1))
    return rows


def main(argv):
    bench = argv[1] if len(argv) > 1 else DEFAULT_BENCH
    if not os.path.isfile(bench):
        print("eip_cost_check: benchmark no encontrado: %s" % bench, file=sys.stderr)
        return 2

    meas = parse_measured(bench)

    checks = [
        ("ecAdd", ECADD_EIP, ECADD_EIP + HARNESS_OVERHEAD, meas["ecAdd"]),
        ("ecMul", ECMUL_EIP, ECMUL_EIP + HARNESS_OVERHEAD, meas["ecMul"]),
    ]
    for k in (1, 2, 4):
        base = PAIRING_BASE + PAIRING_PER * k
        checks.append(("ecPairing k=%d" % k, base, base + HARNESS_OVERHEAD, meas["pairing%d" % k]))

    print("=" * 72)
    print("eip_cost_check — EIP-196/197 base + overhead de harness vs medido")
    print("=" * 72)
    print("benchmark: %s" % bench)
    print()

    header = "%-16s %12s %6s %12s %12s %6s" % ("primitive", "EIP base", "+142", "expected", "measured", "check")
    print(header)
    print("-" * len(header))

    ok = True
    for name, base, expected, measured in checks:
        good = expected == measured
        ok = ok and good
        print("%-16s %12d %6d %12d %12d %6s"
              % (name, base, HARNESS_OVERHEAD, expected, measured, "OK" if good else "FAIL"))

    m12 = meas["pairing2"] - meas["pairing1"]
    m24 = (meas["pairing4"] - meas["pairing2"]) // 2
    marginal_ok = (m12 == PAIRING_PER and m24 == PAIRING_PER)
    ok = ok and marginal_ok
    print()
    print("marginal per pairing: k2-k1 = %d   (k4-k2)/2 = %d   expected %d   %s"
          % (m12, m24, PAIRING_PER, "OK" if marginal_ok else "FAIL"))
    print()
    print("VERDICT: %s" % ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
