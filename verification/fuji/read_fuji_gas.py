#!/usr/bin/env python3
"""
read_fuji_gas.py — Gas y coste de las cinco creaciones del deploy de Fuji.

Lee los tres broadcast JSON pineados del deploy de Fuji (chain 43113,
2026-10-18) y reconstruye, sin red, el gas consumido y el coste en AVAX de
cada transaccion de creacion:

    integrations/avalanche/scripts/fuji_20261018/token.json
    integrations/avalanche/scripts/fuji_20261018/sink.json
    integrations/avalanche/scripts/fuji_20261018/phase1.json

Cada JSON es un `run-latest.json` de Foundry: `.transactions[]` lleva el
nombre y la direccion del contrato, y `.receipts[]` el `gasUsed` y el
`effectiveGasPrice` del recibo. El script empareja transaccion y recibo por
`transactionHash`, exige `status == 0x1` y no consulta ningun RPC.

Salida determinista (stdout y fichero, con el mismo contenido):

    verification/baseline_verified/fuji_gas_output.txt

Formato:

    contract | gas | fee_wei | cost_avax
    ...
    TOTAL | <gas> | <fee_wei> | <cost_avax>
    chain_id=43113
    block_range=<primer_bloque>-<ultimo_bloque>
    source=broadcast/Deploy*.s.sol/43113/run-latest.json

Uso:
    python3 verification/fuji/read_fuji_gas.py

Exit 0 si los tres JSON son consistentes; 1 si falta un fichero, falta un
recibo, un recibo no esta confirmado o la cadena no es 43113.
"""

from decimal import Decimal
import json
from pathlib import Path
import sys

REPO_ROOT = Path(__file__).resolve().parents[2]
BROADCAST_DIR = REPO_ROOT / "integrations" / "avalanche" / "scripts" / "fuji_20261018"
OUT_FILE = REPO_ROOT / "verification" / "baseline_verified" / "fuji_gas_output.txt"

SOURCES = ("token.json", "sink.json", "phase1.json")
EXPECTED_CHAIN = "43113"
WEI_PER_AVAX = Decimal(10**18)


def parse_hex(value):
    """Convierte un entero hexadecimal de los JSON de Foundry a int."""
    if not isinstance(value, str) or not value.startswith("0x"):
        raise ValueError("se esperaba un entero hexadecimal, no %r" % (value,))
    return int(value, 16)


def format_sci(value):
    """Formatea un Decimal en notacion cientifica con exponente de dos digitos.

    `Decimal` evita el redondeo binario de `float`; el exponente se normaliza
    a dos digitos para que la salida sea estable (`e-09`, no `e-9`).
    """
    mantissa, exponent = format(value, "e").split("e")
    sign = exponent[0]
    digits = exponent[1:].lstrip("0") or "0"
    return "%se%s%02d" % (mantissa, sign, int(digits))


def read_broadcast(path):
    """Devuelve las filas (contrato, gas, gas_price, bloque) de un JSON."""
    with path.open(encoding="utf-8") as handle:
        doc = json.load(handle)

    chain = str(doc.get("chain", ""))
    if chain != EXPECTED_CHAIN:
        raise ValueError("%s: chain=%r, se esperaba %s" % (path, chain, EXPECTED_CHAIN))

    transactions = doc.get("transactions") or []
    receipts = doc.get("receipts") or []
    if not transactions:
        raise ValueError("%s: no contiene transacciones" % path)
    if len(transactions) != len(receipts):
        raise ValueError(
            "%s: %d transacciones y %d recibos" % (path, len(transactions), len(receipts))
        )

    by_hash = {}
    for receipt in receipts:
        tx_hash = receipt.get("transactionHash")
        if not tx_hash:
            raise ValueError("%s: recibo sin transactionHash" % path)
        by_hash[tx_hash.lower()] = receipt

    rows = []
    for tx in transactions:
        tx_hash = tx.get("hash")
        if not tx_hash:
            raise ValueError("%s: transaccion sin hash" % path)
        receipt = by_hash.get(tx_hash.lower())
        if receipt is None:
            raise ValueError("%s: sin recibo para %s" % (path, tx_hash))
        if parse_hex(receipt.get("status")) != 1:
            raise ValueError("%s: recibo no confirmado para %s" % (path, tx_hash))

        contract = tx.get("contractName")
        address = tx.get("contractAddress") or receipt.get("contractAddress")
        if not contract or not address:
            raise ValueError("%s: transaccion %s sin contrato o direccion" % (path, tx_hash))

        gas = parse_hex(receipt.get("gasUsed"))
        gas_price = receipt.get("effectiveGasPrice")
        if gas_price is None:
            gas_price = (tx.get("transaction") or {}).get("gasPrice")
        gas_price = parse_hex(gas_price)
        block = parse_hex(receipt.get("blockNumber"))
        rows.append((contract, gas, gas_price, block))

    return rows


def build_output():
    """Reconstruye la tabla completa a partir de los tres JSON pineados."""
    rows = []
    for name in SOURCES:
        rows.extend(read_broadcast(BROADCAST_DIR / name))

    total_gas = sum(row[1] for row in rows)
    total_fee = sum(row[1] * row[2] for row in rows)
    first_block = min(row[3] for row in rows)
    last_block = max(row[3] for row in rows)

    lines = ["contract | gas | fee_wei | cost_avax"]
    for contract, gas, gas_price, _block in rows:
        fee = gas * gas_price
        lines.append(
            "%s | %d | %d | %s"
            % (contract, gas, fee, format_sci(Decimal(fee) / WEI_PER_AVAX))
        )
    lines.append(
        "TOTAL | %d | %d | %s"
        % (total_gas, total_fee, format_sci(Decimal(total_fee) / WEI_PER_AVAX))
    )
    lines.append("chain_id=%s" % EXPECTED_CHAIN)
    lines.append("block_range=%d-%d" % (first_block, last_block))
    lines.append("source=broadcast/Deploy*.s.sol/43113/run-latest.json")

    return "\n".join(lines) + "\n"


def main():
    try:
        text = build_output()
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print("read_fuji_gas: %s" % exc, file=sys.stderr)
        return 1

    OUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    OUT_FILE.write_text(text, encoding="utf-8")
    sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
