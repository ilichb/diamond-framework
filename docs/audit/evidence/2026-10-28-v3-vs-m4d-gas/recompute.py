#!/usr/bin/env python3
"""Recompute the paper's gas-derived figures with the key the registry installs.

WHY THIS EXISTS
---------------
`docs/paper/main.tex` (v0.2.2, deposited) prices the deployed path at 286,144
gas. That figure is the cold path of `AVIPRegistry.verifyThreshold` **with V3's
three-input key**: `main.tex:1294` says so ("The V3 Groth16 proof ... verifies
directly at 286,144 gas on the cold path of AVIPRegistry.verifyThreshold"), and
the retired harness `test/M4bRealKey.t.sol` fed `M4bGroth16Fixtures`' three-input
statement to it. The key that admits validators is M4d's, four inputs, and the
current registry builds four public inputs, so a three-input key cannot be
installed at all (`Groth16Verifier.PublicInputsMismatch(3, 4)`).

v0.2.3 prints the installed key's figure as the deployed one (owner decision,
2026-10-28) and keeps 286,144 as V3's. This script recomputes every figure that
*derives* from G under both, so the errata quotes numbers that came out of a
program instead of out of arithmetic in a chat.

INPUTS, AND WHERE THEY COME FROM
--------------------------------
  N_ETH  = 0.2236    mean-stake saving, `main.tex` eq. (deterrence), unchanged
  R_USD  = 684064    composed ingest, `main.tex` §tensor (256,000 + 428,064)
  BP     = 6500000   Bulletproofs alternative, `main.tex` §recursive
  G_*                measured, not transcribed: see MEASUREMENTS below

MEASUREMENTS, WITH THEIR PROVENANCE
-----------------------------------
Contracts at commit `be49336`; forge 1.5.1-stable; solc 0.8.33;
`optimizer = false`, `evm_version = "cancun"` (`integrations/avalanche/foundry.toml`).
Convention: `gasleft()` around the external call, so the 21,000 intrinsic and the
calldata are excluded — the same convention the paper uses for 286,144.

  306,253  `verifyThreshold` cold, M4d key, through the test's blob helper
           (`M4dRealKey.t.sol`, committed; logs 306,253 / 247,211 / 234,284)
  306,218  the same call with the blob built inline: 35 gas less, and the 35 is
           the helper's internal call inside the measured window
           (`logs/manager_admit_m4d.txt`, `test_mirrorWithHelper` vs
           `test_mirrorWithoutManager`)
  247,211  `verifyThreshold` warm, same test
  395,255  full `manager.admit` cold, M4d key, helper convention
  395,220  the same admission, helper excluded (difference: the same 35)
  329,682  a second `manager.admit` in the same transaction, other validator
  376,588  full `manager.admit`, V3-era (2026-10-20), **not comparable**: it
           wraps a verification of a key nothing installs, on a manager that has
           changed since (see the errata's admission section)
  286,144  `verifyThreshold` cold, V3 key, measured 2026-10-20 at commit
           `70f225c` — `docs/audit/evidence/2026-10-20-pocs/RUN-LOG.md` records
           that HEAD, and its `logs/gas_break_even.txt` row is "verifyThreshold,
           frío (harness nuevo)". R-18 gives the paper that provenance instead of
           an undated number.

The break-even formula is the one `gas_break_even.py` (P-25) uses, and it is
restated here rather than imported so that this file has no local dependency:

    g* [gwei] = N_ETH * 1e18 / G / 1e9

Uso:
    python3 recompute.py
"""

from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

COMMIT = "be49336"
TOOLCHAIN = "forge 1.5.1-stable, solc 0.8.33, optimizer=false, evm_version=cancun"

N_ETH = Decimal("0.2236")
R_USD = Decimal("684064")
BP_GAS = Decimal("6500000")

# Warm measurements of the same call under the same convention: the key is
# already in storage, so these are the second-call numbers in one transaction.
# They do not derive from G; they are measured beside it, and the paper prints
# them next to the cold ones so that no cold figure travels alone.
WARM = {
    286_144: 223_403,  # V3 key, `M4bRealKey` harness, 2026-10-20
    306_253: 247_211,  # M4d key, `M4dRealKey.t.sol`, logs 306,253 / 247,211
}

# (label, gas, note)
CASES = [
    ("V3 key, 3 inputs", 286_144, "what v0.2.2 prints; not installable today"),
    ("M4d key, installed", 306_253, "measured 2026-10-28, M4dRealKey harness"),
    ("M4d key, bare call", 306_218, "same call, blob helper excluded (-35)"),
    ("manager.admit, M4d", 395_255, "measured 2026-10-28, helper convention"),
    ("manager.admit, M4d, 2nd", 329_682, "second admission, other validator"),
    ("manager.admit, V3-era", 376_588, "2026-10-20; not comparable, see errata"),
]


def quant(value: Decimal, places: str) -> Decimal:
    return value.quantize(Decimal(places), rounding=ROUND_HALF_UP)


def gwei(G: int) -> Decimal:
    """Break-even gas price in gwei for `G` gas units."""
    return quant(N_ETH * Decimal(10) ** 18 / Decimal(G) / Decimal(10) ** 9, "0.1")


def printed(G: int) -> dict:
    """The same figures, rounded the way `main.tex` rounds them.

    The paper is edited from these strings and not from arithmetic typed into an
    editor: the number a reader sees and the number this script prints are the
    same object, so a later edit cannot move one without the other.
    """
    gas = Decimal(G)
    return {
        "gwei": quant(gwei(G), "1"),
        "ingest": quant(R_USD / gas, "0.1"),
        "bp": quant(BP_GAS / gas, "1"),
        "margin": quant(gwei(G) / Decimal(25), "1"),
        "cost25": quant(gas * Decimal(25) * Decimal(10) ** 9 / Decimal(10) ** 18, "0.00001"),
        "cost160": quant(gas * Decimal(160) / Decimal(10) ** 18 * Decimal(10) ** 11, "0.01"),
    }


def sep(n: int) -> str:
    """Thousands separator, as the prose writes it: 306,253."""
    return f"{n:,}"


def tex(n: int) -> str:
    """Thousands separator inside math mode: 306{,}253."""
    return f"{n:,}".replace(",", "{,}")


def main() -> None:
    # The manager's own overhead must be convention-independent: if someone edits
    # one figure without the other, this fails instead of publishing a mismatch.
    overhead_helper = Decimal(395_255) - Decimal(306_253)
    overhead_bare = Decimal(395_220) - Decimal(306_218)
    if not (overhead_helper == overhead_bare == 89_002):
        raise SystemExit(
            f"admit - verifyThreshold disagrees between conventions: "
            f"{overhead_helper} vs {overhead_bare}"
        )

    # A warm call cannot cost more than the cold call it follows; if a warm
    # figure is ever edited past its cold one, this fails before the paper does.
    for cold, warm in WARM.items():
        if not warm < cold:
            raise SystemExit(f"warm {warm} is not below cold {cold}")

    out = [
        "# The paper's gas-derived figures, under V3's key and the installed one",
        "",
        "Generated by `recompute.py`; do not edit by hand.",
        "",
        f"Measured at commit `{COMMIT}`; {TOOLCHAIN}.",
        "",
        "| G (gas) | Route | g* (gwei) | R/G | 6.5M/G | margin at 25 gwei "
        "| cost at 25 gwei (AVAX) | cost at 160 wei (AVAX) |",
        "|---:|---|---:|---:|---:|---:|---:|---:|",
    ]

    for label, G, note in CASES:
        gas = Decimal(G)
        g = gwei(G)
        ratio = quant(R_USD / gas, "0.01")
        bp = quant(BP_GAS / gas, "0.1")
        margin = quant(g / Decimal(25), "0.1")
        at25 = quant(gas * Decimal(25) * Decimal(10) ** 9 / Decimal(10) ** 18, "0.00000001")
        at160 = quant(gas * Decimal(160) / Decimal(10) ** 18, "1E-13")
        out.append(
            f"| {G} | {label} ({note}) | {g} | {ratio}× | {bp}× | {margin}× "
            f"| {at25} | {at160} |"
        )

    v3, m4d = Decimal(286_144), Decimal(306_253)
    admit, verify = Decimal(395_255), Decimal(306_253)
    out += [
        "",
        "## What moves, and by how much",
        "",
        "v0.2.3 prints **306,253** as the deployed figure and keeps 286,144 as V3's,",
        "so every figure below moves once:",
        "",
        f"- Break-even: {gwei(286_144)} gwei → {gwei(306_253)} gwei "
        f"(scales as 1/G; the {quant((m4d / v3 - 1) * 100, '0.01')}% cost increase "
        "lowers it by the same factor).",
        f"- Ingest over verification: {quant(R_USD / v3, '0.01')}× → "
        f"{quant(R_USD / m4d, '0.01')}×.",
        f"- Bulletproofs over Groth16: {quant(BP_GAS / v3, '0.1')}× → "
        f"{quant(BP_GAS / m4d, '0.1')}×.",
        f"- Margin at 25 gwei: {quant(gwei(286_144) / 25, '0.1')}× → "
        f"{quant(gwei(306_253) / 25, '0.1')}×.",
        "",
        f"The admission path moves too, and by a different amount: `manager.admit` is",
        f"**{quant(admit, '1')}** cold with the installed key, against the V3-era",
        f"376,588 — {quant(admit - 376_588, '1')} gas, which is **not** the",
        f"{quant(m4d - v3, '1')} the verification itself moved. The two are different",
        "quantities on a contract that also changed between 2026-10-20 and today; the",
        "errata refuses to attribute the difference to the key without the original",
        "probe, which was deleted.",
        "",
        "## What the paper prints",
        "",
        "The same quantities, rounded the way `main.tex` rounds them: gwei and",
        "margins to the unit, ratios to one decimal, AVAX to five decimals, and",
        "the 160-wei cost in units of 1e-11 AVAX. v0.2.3's edit of Sections 6 and 9",
        "reads `paper_strings.txt` — written from this block — so the paper cannot",
        "print a number this script does not compute.",
        "",
        "| G (gas) | Route | g* (gwei) | ingest | Bulletproofs | margin at 25 gwei "
        "| cost at 25 gwei | cost at 160 wei |",
        "|---:|---|---:|---:|---:|---:|---:|---:|",
    ]
    for label, G, note in CASES:
        p = printed(G)
        out.append(
            f"| {sep(G)} | {label} | {p['gwei']} | {p['ingest']}× | {p['bp']}× "
            f"| {p['margin']}× | {p['cost25']} AVAX | {p['cost160']}e-11 AVAX |"
        )

    out += [
        "",
        "## Checks this script performs on itself",
        "",
        f"- The manager's own overhead is `admit - verifyThreshold` = "
        f"{quant(admit - verify, '1')} gas, and it is the same in both conventions:",
        "  395,255 − 306,253 and 395,220 − 306,218 are both 89,002.",
        "- 35 gas is the test's blob helper, not the contract: the same call measured",
        "  inline is 306,218.",
        "",
        "None of these changes a conclusion in the paper: the verification stays ",
        "two orders of magnitude below the ingest, Bulletproofs stays an order of ",
        "magnitude above it, and the break-even stays far above any realistic gas ",
        "price. What changes is the label — and, in v0.2.3, the number the label ",
        "points at: 286,144 is V3's, and the deployed key is not V3.",
        "",
        "## What this script does not do",
        "",
        "- It does not measure anything. It takes the numbers from the probes named",
        "  above, which are logged in this directory and reproducible from HEAD.",
        "- It does not decide policy. The choice v0.2.3 makes — installed key as the",
        "  deployed figure, V3's as history — is the owner's, recorded in the errata.",
    ]

    text = "\n".join(out) + "\n"
    print(text)

    target = Path(__file__).with_name("gas_recompute.txt")
    target.write_text(text, encoding="utf-8")
    print(f"escrito: {target}")

    # The paper's own rounding, as key=value so that the edit of main.tex can
    # read it instead of retyping it.
    d = printed(306_253)
    if (d["gwei"], d["ingest"], d["bp"], d["margin"]) != (
        Decimal("730"),
        Decimal("2.2"),
        Decimal("21"),
        Decimal("29"),
    ):
        raise SystemExit(f"the strings the errata quotes moved: {d}")

    pairs = []
    for label, G, note in CASES:
        p = printed(G)
        pairs += [
            (f"gas.{G}.tex", tex(G)),
            (f"gas.{G}.plain", sep(G)),
            (f"gwei.{G}", str(p["gwei"])),
            (f"ingest.{G}", str(p["ingest"])),
            (f"bp.{G}", str(p["bp"])),
            (f"margin.{G}", str(p["margin"])),
            (f"cost25.{G}", str(p["cost25"])),
            (f"cost160e11.{G}", str(p["cost160"])),
        ]
        if G in WARM:
            pairs += [
                (f"gas.{G}.warm.tex", tex(WARM[G])),
                (f"gas.{G}.warm.plain", sep(WARM[G])),
            ]

    target2 = Path(__file__).with_name("paper_strings.txt")
    body = "\n".join(
        [
            "# The exact strings main.tex prints, computed here and read by the",
            "# v0.2.3 edit; do not edit by hand. Written by recompute.py.",
            "",
        ]
        + [f"{k}={v}" for k, v in pairs]
    )
    target2.write_text(body + "\n", encoding="utf-8")
    print(f"escrito: {target2}")


if __name__ == "__main__":
    main()
