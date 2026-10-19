#!/usr/bin/env python3
"""
measure_block_time.py — Block time de Fuji C-Chain (chain 43113).

Mide el tiempo entre bloques consecutivos sobre N=100 bloques de Fuji
(59670000-59670099). Por defecto lee el fixture pineado, de modo que la
corrida del harness es offline y determinista:

    verification/fuji/fixtures/block_times_59670000_59670099.json

El fixture se capturo una vez con `cast block <n> --json` contra Alchemy y
guarda, por bloque, el numero, el timestamp y el hash. Con `--live` el script
consulta Alchemy (`ALCHEMY_FUJI_URL`) y, si la red no esta disponible, cae de
vuelta al fixture. El harness no usa `--live`.

Salida determinista (stdout y fichero, con el mismo contenido):

    verification/baseline_verified/fuji_block_time_output.txt

Formato:

    n_blocks=100
    block_start=59670000
    block_end=59670099
    chain_id=43113
    median_s=<mediana>
    p95_s=<percentil 95, rango mas cercano>
    min_s=<minimo>
    max_s=<maximo>
    method=inter-block timestamp delta
    source=alchemy (fixture: verification/fuji/fixtures/block_times_59670000_59670099.json)

Uso:
    python3 verification/fuji/measure_block_time.py
    python3 verification/fuji/measure_block_time.py --live

Exit 0 si el fixture (o la respuesta live) es consistente; 1 si falta el
fixture, la cadena no es 43113, faltan bloques o los timestamps retroceden.
"""

import argparse
import http.client
import json
import math
import os
from pathlib import Path
import statistics
import sys
import urllib.request

REPO_ROOT = Path(__file__).resolve().parents[2]
FIXTURE_FILE = (
    REPO_ROOT
    / "verification"
    / "fuji"
    / "fixtures"
    / "block_times_59670000_59670099.json"
)
OUT_FILE = REPO_ROOT / "verification" / "baseline_verified" / "fuji_block_time_output.txt"

CHAIN_ID = 43113
BLOCK_START = 59_670_000
BLOCK_END = 59_670_099
N_BLOCKS = BLOCK_END - BLOCK_START + 1
RPC_TIMEOUT_S = 20
BATCH_SIZE = 20


def _require_int(value, label):
    """Devuelve un entero JSON, rechazando bools y strings."""
    if isinstance(value, bool) or not isinstance(value, int):
        raise ValueError("%s: se esperaba un entero, no %r" % (label, value))
    return value


def _validate_blocks(blocks):
    """Valida rango, cardinalidad y orden temporal de los bloques."""
    if not isinstance(blocks, list):
        raise ValueError("blocks: se esperaba una lista")
    if len(blocks) != N_BLOCKS:
        raise ValueError(
            "blocks: %d bloques, se esperaban %d" % (len(blocks), N_BLOCKS)
        )

    previous = None
    for expected_number, block in enumerate(blocks, start=BLOCK_START):
        if not isinstance(block, dict):
            raise ValueError("blocks[%d]: se esperaba un objeto" % expected_number)
        number = _require_int(block.get("number"), "blocks[].number")
        timestamp = _require_int(block.get("timestamp"), "blocks[].timestamp")
        if number != expected_number:
            raise ValueError(
                "blocks: se esperaba el bloque %d, no %d" % (expected_number, number)
            )
        if previous is not None and timestamp < previous:
            raise ValueError(
                "blocks: timestamp retrocede en el bloque %d" % number
            )
        previous = timestamp

    return blocks


def load_fixture():
    """Carga y valida el fixture pineado."""
    with FIXTURE_FILE.open(encoding="utf-8") as handle:
        doc = json.load(handle)

    chain_id = _require_int(doc.get("chain_id"), "chain_id")
    if chain_id != CHAIN_ID:
        raise ValueError("chain_id=%d, se esperaba %d" % (chain_id, CHAIN_ID))
    block_start = _require_int(doc.get("block_start"), "block_start")
    block_end = _require_int(doc.get("block_end"), "block_end")
    if block_start != BLOCK_START or block_end != BLOCK_END:
        raise ValueError(
            "rango %d-%d, se esperaba %d-%d"
            % (block_start, block_end, BLOCK_START, BLOCK_END)
        )

    return _validate_blocks(doc.get("blocks"))


def _post_json(url, payload):
    """Envia un payload JSON-RPC y devuelve la respuesta decodificada."""
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=RPC_TIMEOUT_S) as response:
        return json.load(response)


def _rpc(url, method, params):
    """Llama a un metodo JSON-RPC de Alchemy y devuelve `result`."""
    doc = _post_json(
        url, {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    )
    if doc.get("error") is not None:
        raise ValueError("%s: %s" % (method, doc["error"]))
    return doc.get("result")


def fetch_live(url):
    """Lee los bloques del rango desde Alchemy en lotes de BATCH_SIZE."""
    chain_id = int(_rpc(url, "eth_chainId", []), 16)
    if chain_id != CHAIN_ID:
        raise ValueError("chain_id=%d, se esperaba %d" % (chain_id, CHAIN_ID))

    blocks = []
    for offset in range(0, N_BLOCKS, BATCH_SIZE):
        first = BLOCK_START + offset
        last = min(first + BATCH_SIZE - 1, BLOCK_END)
        calls = [
            {
                "jsonrpc": "2.0",
                "id": number,
                "method": "eth_getBlockByNumber",
                "params": [hex(number), False],
            }
            for number in range(first, last + 1)
        ]
        docs = _post_json(url, calls)
        if not isinstance(docs, list):
            raise ValueError("respuesta batch: se esperaba una lista")
        by_id = {doc.get("id"): doc for doc in docs if isinstance(doc, dict)}

        for number in range(first, last + 1):
            doc = by_id.get(number)
            if doc is None:
                raise ValueError("bloque %d ausente de la respuesta batch" % number)
            if doc.get("error") is not None:
                raise ValueError("bloque %d: %s" % (number, doc["error"]))
            block = doc.get("result")
            if block is None:
                raise ValueError("bloque %d no encontrado" % number)
            blocks.append(
                {
                    "number": int(block["number"], 16),
                    "timestamp": int(block["timestamp"], 16),
                }
            )

    return _validate_blocks(blocks)


def percentile_nearest_rank(values, percent):
    """Percentil por rango mas cercano (sin interpolacion)."""
    ordered = sorted(values)
    rank = max(1, math.ceil(percent / 100.0 * len(ordered)))
    return ordered[rank - 1]


def build_output(blocks, source):
    """Calcula las estadisticas y construye la salida de texto."""
    deltas = [
        current["timestamp"] - previous["timestamp"]
        for previous, current in zip(blocks, blocks[1:])
    ]
    if not deltas:
        raise ValueError("no hay intervalos entre bloques")

    lines = [
        "n_blocks=%d" % len(blocks),
        "block_start=%d" % blocks[0]["number"],
        "block_end=%d" % blocks[-1]["number"],
        "chain_id=%d" % CHAIN_ID,
        "median_s=%.1f" % statistics.median(deltas),
        "p95_s=%.1f" % percentile_nearest_rank(deltas, 95),
        "min_s=%.1f" % min(deltas),
        "max_s=%.1f" % max(deltas),
        "method=inter-block timestamp delta",
        "source=%s" % source,
    ]
    return "\n".join(lines) + "\n"


def fixture_source():
    return "alchemy (fixture: %s)" % FIXTURE_FILE.relative_to(REPO_ROOT).as_posix()


def parse_args(argv):
    parser = argparse.ArgumentParser(
        description="Mide el block time de Fuji C-Chain sobre 100 bloques."
    )
    parser.add_argument(
        "--live",
        action="store_true",
        help="consulta Alchemy (ALCHEMY_FUJI_URL); si falla, usa el fixture",
    )
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)

    try:
        if args.live:
            url = os.environ.get("ALCHEMY_FUJI_URL", "").strip()
            if not url:
                print(
                    "measure_block_time: ALCHEMY_FUJI_URL no definida; usando fixture",
                    file=sys.stderr,
                )
                blocks = load_fixture()
                source = fixture_source()
            else:
                try:
                    blocks = fetch_live(url)
                    source = "alchemy (live)"
                except (
                    OSError,
                    ValueError,
                    KeyError,
                    TypeError,
                    http.client.HTTPException,
                ) as exc:
                    print(
                        "measure_block_time: fallo la consulta live (%s); usando fixture"
                        % exc,
                        file=sys.stderr,
                    )
                    blocks = load_fixture()
                    source = fixture_source()
        else:
            blocks = load_fixture()
            source = fixture_source()

        text = build_output(blocks, source)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print("measure_block_time: %s" % exc, file=sys.stderr)
        return 1

    OUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    OUT_FILE.write_text(text, encoding="utf-8")
    sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
