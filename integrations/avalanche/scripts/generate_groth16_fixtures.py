#!/usr/bin/env python3
"""Generate `test/fixtures/Groth16Fixtures.sol`.

WHAT THIS SCRIPT PRODUCES
-------------------------
A Groth16 verification key over BN254, a proof, and the four-element public
statement `[root, epoch, validator, certifiedNorm]` the registry builds, all
consistent with the equation `Groth16Verifier` checks on-chain:

    e(-A, B) * e(alpha1, beta2) * e(vk_x, gamma2) * e(C, delta2) == 1

WHY THERE IS NO TRUSTED SETUP HERE
----------------------------------
The paper's circuit (Pedersen commitment + Bulletproofs IPA, recursively
attested) is a parallel cryptography workstream: its R1CS, its ceremony and its
production key do not exist yet. What *can* be exercised without them is the
wrapper: the decoding, the `vk_x` accumulation, the G2 reordering to EIP-197,
the identity handling and the pairing call itself.

The equation can be set up directly, because in the exponents it is linear.
Writing `A = a*G1`, `B = b*G2`, `alpha1 = al*G1`, `beta2 = bs*G2`,
`gamma2 = g*G2`, `delta2 = d*G2`, `C = c*G1` and `vk_x = v*G1`, the equation
holds iff

    -a*b + al*bs + v*g + c*d == 0   (mod r)

so `c` is simply solved for. `vk_x` is what the verifier computes from the
installed `ic`, so the script picks `ic[i] = s_i*G1` and
`v = sum_i(s_i * input_i)` for the statement above.

The result is a *real* BN254 instance: every point is on the curve, every
coordinate is canonical, and the pairing precompile accepts it. It is also not
a proof of anything: there is no witness, and therefore no soundness claim. Its
job is to make the wrapper's happy path and its failure paths testable against
the EVM's own precompiles instead of against a mock.

The scalars are derived from SHA-256 of fixed labels. They are deterministic and
public — a real deployment replaces all of them with the output of the trusted
setup, which is exactly the swap `Groth16Verifier`'s constructor is built for.

USAGE
-----
    python3 scripts/generate_groth16_fixtures.py && forge fmt

Writes `test/fixtures/Groth16Fixtures.sol` and `scripts/groth16_fixtures_output.txt`.
The script is deterministic (same bytes on every run); `forge fmt` is what turns
its raw output into the committed fixture.
"""

from __future__ import annotations

import hashlib
from pathlib import Path

# --- BN254 parameters (alt_bn128, the curve of EIP-196/EIP-197) -------------

# Base-field modulus, the modulus of every coordinate.
P = 21888242871839275222246405745257275088696311157297823662689037894645226208583

# Order of the prime-order subgroups.
R = 21888242871839275222246405745257275088548364400416034343698204186575808495617

# Generators, in the (c0, c1) = (real, imaginary) order the Solidity side uses.
G1 = (1, 2)
G2 = (
    (
        10857046999023057135944570762232829481370756359578518086990519993285655852781,
        11559732032986387107991004021392285783925812861821192530917403151452391805634,
    ),
    (
        8495653923123431417604973247489272438418190587263600148770280649306958101930,
        4082367875863433681332203403145435568316851327593401208105741076214120093531,
    ),
)

# `b` of the twist `E'`: y^2 = x^3 + b2 over Fp2 = Fp[u]/(u^2 + 1).
B_TWIST = (3, 0)
XI = (9, 1)

# Statement the fixtures certify: the registry's epoch-0 root
# (`keccak256("tensor")`, `cast keccak tensor`), epoch 0 and `Theta_r = 0.5e18`.
# Must match `AVIPRegistryTest.epoch0Root` and `AVIPValidatorManager.THETA_R`.
STATEMENT_ROOT = 86442290903294350648273222779976636221758675587005340531248271500348333491074
STATEMENT_EPOCH = 0
# `address(0xA11CE)`: the validator the proof is bound to (audit P-01).
STATEMENT_VALIDATOR = 0xA11CE
STATEMENT_NORM = 500_000_000_000_000_000


# --- Fp2 arithmetic (elements are (c0, c1) tuples) --------------------------


def f2_add(a, b):
    return ((a[0] + b[0]) % P, (a[1] + b[1]) % P)


def f2_sub(a, b):
    return ((a[0] - b[0]) % P, (a[1] - b[1]) % P)


def f2_mul(a, b):
    return ((a[0] * b[0] - a[1] * b[1]) % P, (a[0] * b[1] + a[1] * b[0]) % P)


def f2_neg(a):
    return ((-a[0]) % P, (-a[1]) % P)


def f2_inv(a):
    norm = (a[0] * a[0] + a[1] * a[1]) % P
    inv = pow(norm, -1, P)
    return ((a[0] * inv) % P, ((-a[1]) * inv) % P)


def f2_is_zero(a):
    return a[0] % P == 0 and a[1] % P == 0


F2_ZERO = (0, 0)
F2_ONE = (1, 0)


def f2_pow(a, k):
    out = F2_ONE
    while k:
        if k & 1:
            out = f2_mul(out, a)
        a = f2_mul(a, a)
        k >>= 1
    return out


# --- Curve arithmetic: affine coordinates, `None` is the point at infinity -


def g1_add(p, q):
    if p is None:
        return q
    if q is None:
        return p
    x1, y1 = p
    x2, y2 = q
    if x1 == x2:
        if (y1 + y2) % P == 0:
            return None  # p == -q
        lam = (3 * x1 * x1) % P * pow(2 * y1, -1, P) % P
    else:
        lam = (y2 - y1) % P * pow((x2 - x1) % P, -1, P) % P
    x3 = (lam * lam - x1 - x2) % P
    return (x3, (lam * (x1 - x3) - y1) % P)


def g2_add(p, q):
    if p is None:
        return q
    if q is None:
        return p
    x1, y1 = p
    x2, y2 = q
    if x1 == x2:
        if f2_is_zero(f2_add(y1, y2)):
            return None  # p == -q
        lam = f2_mul(f2_mul((3, 0), f2_mul(x1, x1)), f2_inv(f2_mul((2, 0), y1)))
    else:
        lam = f2_mul(f2_sub(y2, y1), f2_inv(f2_sub(x2, x1)))
    x3 = f2_sub(f2_sub(f2_mul(lam, lam), x1), x2)
    return (x3, f2_sub(f2_mul(lam, f2_sub(x1, x3)), y1))


def scalar_mul(k, p, add):
    out = None
    acc = p
    while k:
        if k & 1:
            out = add(out, acc)
        acc = add(acc, acc)
        k >>= 1
    return out


def g1_mul(k, p=G1):
    return scalar_mul(k, p, g1_add)


def g2_mul(k, p=G2):
    return scalar_mul(k, p, g2_add)


def g1_on_curve(pt):
    if pt is None:
        return True
    x, y = pt
    return (y * y - x * x * x - 3) % P == 0


def g2_on_curve(pt, b2):
    if pt is None:
        return True
    x, y = pt
    return f2_is_zero(f2_sub(f2_sub(f2_mul(y, y), f2_pow(x, 3)), b2))


# The twist coefficient is derived, not hardcoded: `b2 = 3 / (9 + u)` for the
# D-type twist of BN254. The assertion against the standard generator is what
# says the derivation is right; if it ever fails the arithmetic below is wrong.
B2 = f2_mul(B_TWIST, f2_inv(XI))
if not g2_on_curve(G2, B2):
    raise SystemExit("Fp2 twist coefficient does not put G2 on the curve")


# --- Deterministic, public scalars (a real deployment uses the ceremony) ----


def derive(label: str) -> int:
    digest = hashlib.sha256(f"diamond-framework/groth16-fixtures/{label}".encode()).digest()
    return int.from_bytes(digest, "big") % (R - 1) + 1


def check_parameters() -> list[str]:
    """Self-checks that must hold before anything is emitted."""
    lines = [
        f"p                  = {P}",
        f"r                  = {R}",
        f"G1 on curve        = {g1_on_curve(G1)}",
        f"G2 on curve        = {g2_on_curve(G2, B2)}",
        f"r * G1 == O        = {g1_mul(R) is None}",
        f"r * G2 == O        = {g2_mul(R) is None}",
        f"(r + 1) * G1 == G1 = {g1_mul(R + 1) == G1}",
        f"(r + 1) * G2 == G2 = {g2_mul(R + 1) == G2}",
    ]
    structural = [
        g1_on_curve(G1) and g2_on_curve(G2, B2),
        g1_mul(R) is None,
        g2_mul(R) is None,
        g1_mul(R + 1) == G1,
        g2_mul(R + 1) == G2,
    ]
    if not all(structural):
        raise SystemExit("curve arithmetic self-check failed:\n" + "\n".join(lines))
    return lines


# --- The synthetic instance -------------------------------------------------


def g1_on_curve_all(instance: dict) -> bool:
    """Every emitted point is on the curve: the precompile's own admission test."""
    g1_points = [
        instance["proof"]["a"],
        instance["proof"]["c"],
        instance["key"]["alpha1"],
    ] + list(instance["key"]["ic"])
    g2_points = [instance["proof"]["b"]] + [
        instance["key"][name] for name in ("beta2", "gamma2", "delta2")
    ]
    return all(g1_on_curve(pt) for pt in g1_points) and all(
        g2_on_curve(pt, B2) for pt in g2_points
    )


def build() -> dict:
    """Solve the Groth16 equation in the exponents for the statement below."""
    alpha = derive("alpha")
    beta = derive("beta")
    gamma = derive("gamma")
    delta = derive("delta")
    a = derive("a")
    b = derive("b")
    s = [derive(f"ic/{i}") for i in range(5)]  # ic[0..4] -> 4 public inputs

    inputs = [STATEMENT_ROOT, STATEMENT_EPOCH, STATEMENT_VALIDATOR, STATEMENT_NORM]
    # The group has order `r`, so a scalar above `r` selects the same multiple:
    # `k * P == (k mod r) * P` for every `P`. The scalar is solved modulo `r`
    # while the fixture keeps the public input as it is (a `bytes32` root), which
    # is what the registry actually passes in.
    reduced = [value % R for value in inputs]
    vk_x_scalar = (s[0] + sum(s[i + 1] * reduced[i] for i in range(4))) % R
    c = ((a * b - alpha * beta - vk_x_scalar * gamma) % R) * pow(delta, -1, R) % R

    residual = (-a * b + alpha * beta + vk_x_scalar * gamma + c * delta) % R
    if residual != 0:
        raise SystemExit("exponent equation not satisfied")

    instance = {
        "scalars": {
            "alpha": alpha,
            "beta": beta,
            "gamma": gamma,
            "delta": delta,
            "a": a,
            "b": b,
            "c": c,
            "ic": s,
            "vk_x": vk_x_scalar,
        },
        "proof": {"a": g1_mul(a), "b": g2_mul(b), "c": g1_mul(c)},
        "key": {
            "alpha1": g1_mul(alpha),
            "beta2": g2_mul(beta),
            "gamma2": g2_mul(gamma),
            "delta2": g2_mul(delta),
            "ic": [g1_mul(s_i) for s_i in s],
        },
        "statement": inputs,
        "residual": residual,
    }

    if not g1_on_curve_all(instance):
        raise SystemExit("a point left the curve")
    return instance


def g1_literal(pt) -> str:
    return f"[uint256({pt[0]}), uint256({pt[1]})]"


def g2_literal(pt) -> str:
    return (
        "[\n"
        f"            [uint256({pt[0][0]}), uint256({pt[0][1]})],\n"
        f"            [uint256({pt[1][0]}), uint256({pt[1][1]})]\n"
        "        ]"
    )


HEADER = """// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// GENERATED FILE - do not edit by hand.
//
// Produced by `scripts/generate_groth16_fixtures.py`; regenerate with
//     python3 scripts/generate_groth16_fixtures.py && forge fmt
// See that script for what these numbers are, and are not: there is no circuit
// and no trusted setup behind this key, so it certifies nothing. It is a real
// BN254 instance (on-curve points, canonical coordinates, accepted by the
// pairing precompile) built so that the Groth16 equation of `Groth16Verifier`
// holds for the proof and statement shipped with it.

import {Groth16Verifier} from "../../contracts/verifiers/Groth16Verifier.sol";

library Groth16Fixtures {
    /// @notice `keccak256("tensor")`, the registry's epoch-0 root.
    uint256 internal constant STATEMENT_ROOT = %s;
    /// @notice Epoch the statement belongs to.
    uint256 internal constant STATEMENT_EPOCH = %s;
    /// @notice `address(0xA11CE)`: the validator the statement admits.
    uint256 internal constant STATEMENT_VALIDATOR = %s;
    /// @notice `Theta_r = 0.5e18` (0.5 in WAD).
    uint256 internal constant STATEMENT_NORM = %s;

    /// @notice The installed key: 4 public inputs, so `ic.length == 5`.
    function verifyingKey() internal pure returns (Groth16Verifier.VerifyingKey memory vk) {
        vk.alpha1 = %s;
        vk.beta2 = %s;
        vk.gamma2 = %s;
        vk.delta2 = %s;
        vk.ic = new uint256[2][](5);
%s
    }

    /// @notice `[root, epoch, validator, certifiedNorm]`, the statement the
    ///         registry builds.
    function statement() internal pure returns (uint256[] memory inputs) {
        inputs = new uint256[](4);
        inputs[0] = STATEMENT_ROOT;
        inputs[1] = STATEMENT_EPOCH;
        inputs[2] = STATEMENT_VALIDATOR;
        inputs[3] = STATEMENT_NORM;
    }

    function proofA() internal pure returns (uint256[2] memory) {
        return %s;
    }

    function proofB() internal pure returns (uint256[2][2] memory) {
        return %s;
    }

    function proofC() internal pure returns (uint256[2] memory) {
        return %s;
    }
}
"""


def render_solidity(instance: dict) -> str:
    key = instance["key"]
    proof = instance["proof"]
    ic_lines = "\n".join(
        f"        vk.ic[{i}] = {g1_literal(pt)};" for i, pt in enumerate(key["ic"])
    )
    return HEADER % (
        instance["statement"][0],
        instance["statement"][1],
        instance["statement"][2],
        instance["statement"][3],
        g1_literal(key["alpha1"]),
        g2_literal(key["beta2"]),
        g2_literal(key["gamma2"]),
        g2_literal(key["delta2"]),
        ic_lines,
        g1_literal(proof["a"]),
        g2_literal(proof["b"]),
        g1_literal(proof["c"]),
    )


def render_report(instance: dict, checks: list[str]) -> str:
    scalars = instance["scalars"]
    statement = instance["statement"]
    lines = [
        "Groth16 fixtures for test/Groth16Verifier.t.sol",
        "==============================================",
        "",
        "Produced by scripts/generate_groth16_fixtures.py (deterministic: the script",
        "emits the same bytes on every run; `forge fmt` then formats them, so the",
        "committed fixture is the script's output after `forge fmt`).",
        "",
        "WHAT THIS IS",
        "  A synthetic Groth16 instance over BN254: no circuit, no trusted setup, no",
        "  witness. The pairing equation is solved in the exponents, where it is",
        "  linear, so the verifier's happy path (and its failure paths) can be",
        "  exercised against the real 0x06/0x07/0x08 precompiles.",
        "",
        "PARAMETERS AND SELF-CHECKS",
    ]
    lines += [f"  {line}" for line in checks]
    lines += [
        "",
        "STATEMENT",
        f"  root  = {statement[0]}",
        f"  epoch = {statement[1]}",
        f"  validator = {statement[2]}",
        f"  norm  = {statement[3]}",
        "",
        "SOLVED SCALARS (public, derived from SHA-256 of fixed labels)",
        f"  alpha = {scalars['alpha']}",
        f"  beta  = {scalars['beta']}",
        f"  gamma = {scalars['gamma']}",
        f"  delta = {scalars['delta']}",
        f"  a     = {scalars['a']}",
        f"  b     = {scalars['b']}",
        f"  c     = {scalars['c']}",
        f"  vk_x  = {scalars['vk_x']}",
        "  ic    = " + ", ".join(str(value) for value in scalars["ic"]),
        "",
        "EQUATION",
        "  -a*b + alpha*beta + vk_x*gamma + c*delta mod r = "
        f"{instance['residual']} (c was solved for)",
        "",
        "EVERY EMITTED POINT IS ON THE CURVE",
        f"  {g1_on_curve_all(instance)}",
        "",
        "WHAT THIS IS NOT",
        "  A proof of anything. There is no witness and no circuit, so these",
        "  fixtures carry no soundness claim. What they carry is a claim about the",
        "  wrapper: that the decoding, the vk_x accumulation, the EIP-197",
        "  reordering and the pairing call behave. test/Groth16Verifier.t.sol",
        "  re-establishes the pairing half of that claim inside the EVM, which is",
        "  what makes it evidence.",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    checks = check_parameters()
    instance = build()

    solidity = root / "test" / "fixtures" / "Groth16Fixtures.sol"
    solidity.parent.mkdir(parents=True, exist_ok=True)
    solidity.write_text(render_solidity(instance))

    report = render_report(instance, checks)
    report_path = root / "scripts" / "groth16_fixtures_output.txt"
    report_path.write_text(report)

    print(report)
    print(f"wrote {solidity} ({solidity.stat().st_size} bytes)")
    print(f"wrote {report_path} ({report_path.stat().st_size} bytes)")
    print("now run: forge fmt")


if __name__ == "__main__":
    main()

