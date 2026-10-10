// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Bn254
/// @notice Low-level BN254 (`alt_bn128`) helpers for the on-chain Groth16
///         verifier (milestone M3): the EIP-196/EIP-197 precompiles at
///         `0x06`/`0x07`/`0x08` and the decoding of the proof blob.
///
/// @dev Three things this library deliberately does NOT assume:
///
///      1. **The point at infinity has no precompile representation.** EIP-196
///         encodes a G1 point as `(x, y)` and treats a non-on-curve pair as a
///         failure, so `(0, 0)` — the identity this codebase uses — must be
///         handled before the precompile is called. `ecAdd`/`ecMul` do that
///         here, and the verifier drops pairs that contain the identity
///         (`e(O, Q) = 1`, so a dropped pair is not a missing constraint).
///      2. **G2 coordinates are carried in the natural `Fp2` order**
///         `(c0, c1)` = (real, imaginary), which is the order a prover emits
///         (`pi_b = [[x0, x1], [y0, y1]]`). EIP-197 wants the imaginary
///         coefficient first, so the reordering happens once, in `pushPair`.
///      3. **The proof blob may carry trailing bytes.** M1's blob was
///         `(a, b, c, publicInputs)` and `abi.decode` does not require the whole
///         payload to be consumed (§5.2.4 of the implementation plan); only the
///         first eight words are read. The public inputs are never taken from
///         the caller: the registry builds them from its own state.
library Bn254 {
    /// @notice Base-field modulus `p`, the modulus of every coordinate of
    ///         `(a, b, c)`. Coordinates are canonical only below this value; a
    ///         larger coordinate makes EIP-197 fail, so it is rejected here with
    ///         a named error instead.
    uint256 internal constant FIELD_MODULUS =
        21888242871839275222246405745257275088696311157297823662689037894645226208583;

    /// @notice Order `r` of the two prime-order subgroups. Scalars (public
    ///         inputs, `vk_x` multipliers) live modulo `r`.
    uint256 internal constant GROUP_ORDER =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    /// @notice Coordinates in one encoded proof: `a` (2) + `b` (4) + `c` (2).
    uint256 internal constant COORDINATES = 8;

    /// @notice Bytes of one encoded proof: 8 * 32 = 256 (two coordinates for
    ///         `a`, four for `b`, two for `c`).
    uint256 internal constant PROOF_LENGTH = COORDINATES * 32;

    /// @dev One G1 pair plus one G2 pair is 6 words; 4 pairs is the Groth16
    ///      maximum (`e(-A,B) * e(alpha,beta) * e(vk_x,gamma) * e(C,delta)`).
    uint256 internal constant PAIRS = 4;

    /// @dev `proof` is shorter than `(a, b, c)`. Carries the length that was
    ///      received, so a producer can see whether the blob was truncated.
    error MalformedProof(uint256 length);

    /// @dev Coordinate `index` of the proof is not a canonical field element
    ///      (`>= FIELD_MODULUS`). Index order: 0 `a.x`, 1 `a.y`, 2-3 `b.x`,
    ///      4-5 `b.y`, 6 `c.x`, 7 `c.y`.
    error CoordinateOutOfRange(uint256 index);

    /// @dev A precompile rejected its input: a point is not on the curve, or a
    ///      coordinate was not canonical. Distinct from a well-formed proof that
    ///      simply does not verify (which returns `false`).
    error PrecompileFailed(uint256 precompile);

    /// @notice Decodes `(a, b, c)` from the `bytes proof` blob.
    /// @dev Reverts with `MalformedProof` when the blob is shorter than
    ///      `PROOF_LENGTH` and with `CoordinateOutOfRange` when a coordinate is
    ///      not canonical. Trailing bytes are ignored, never read.
    function decodeProof(bytes calldata proof)
        internal
        pure
        returns (uint256[2] memory a, uint256[2][2] memory b, uint256[2] memory c)
    {
        if (proof.length < PROOF_LENGTH) revert MalformedProof(proof.length);

        bytes memory head = proof[0:PROOF_LENGTH];
        (a, b, c) = abi.decode(head, (uint256[2], uint256[2][2], uint256[2]));

        uint256[COORDINATES] memory flat =
            [a[0], a[1], b[0][0], b[0][1], b[1][0], b[1][1], c[0], c[1]];
        for (uint256 i = 0; i < COORDINATES; ++i) {
            if (flat[i] >= FIELD_MODULUS) revert CoordinateOutOfRange(i);
        }
    }

    /// @notice `(0, 0)`, this codebase's encoding of the point at infinity.
    function isInfinity(uint256[2] memory p) internal pure returns (bool) {
        return p[0] == 0 && p[1] == 0;
    }

    /// @notice Negates a G1 point: `(x, y) -> (x, p - y)`, identity preserving.
    function negate(uint256[2] memory p) internal pure returns (uint256[2] memory) {
        if (isInfinity(p)) return p;
        return [p[0], FIELD_MODULUS - p[1]];
    }

    /// @notice `p + q` over G1 (precompile `0x06`, EIP-196), identity-aware.
    function ecAdd(uint256[2] memory p, uint256[2] memory q)
        internal
        view
        returns (uint256[2] memory result)
    {
        if (isInfinity(p)) return q;
        if (isInfinity(q)) return p;

        uint256[4] memory input = [p[0], p[1], q[0], q[1]];
        bool ok;
        assembly ("memory-safe") {
            ok := staticcall(gas(), 0x06, input, 0x80, result, 0x40)
        }
        if (!ok) revert PrecompileFailed(0x06);
    }

    /// @notice `k * p` over G1 (precompile `0x07`, EIP-196), identity-aware.
    /// @dev A zero scalar or the identity point short-circuits: the precompile
    ///      cannot be handed `(0, 0)`. A scalar above the group order is fine:
    ///      the group has order `r`, so `k` and `k mod r` give the same point.
    function ecMul(uint256[2] memory p, uint256 k)
        internal
        view
        returns (uint256[2] memory result)
    {
        if (k == 0 || isInfinity(p)) {
            return [uint256(0), uint256(0)];
        }

        uint256[3] memory input = [p[0], p[1], k];
        bool ok;
        assembly ("memory-safe") {
            ok := staticcall(gas(), 0x07, input, 0x60, result, 0x40)
        }
        if (!ok) revert PrecompileFailed(0x07);
    }

    /// @notice Writes pair `n` of the `0x08` input: `(g1, g2)` reordered to
    ///         EIP-197's convention (imaginary coefficient first).
    /// @dev Returns `n` unchanged when either point is the identity, so the pair
    ///      is dropped rather than written: `e(O, Q) = e(P, O) = 1`.
    function pushPair(
        uint256[PAIRS * 6] memory pairs,
        uint256 n,
        uint256[2] memory g1,
        uint256[2][2] memory g2
    ) internal pure returns (uint256) {
        if (isInfinity(g1)) return n;
        if (isInfinity(g2[0]) || isInfinity(g2[1])) return n;

        uint256 base = n * 6;
        pairs[base] = g1[0];
        pairs[base + 1] = g1[1];
        pairs[base + 2] = g2[0][1]; // x, imaginary
        pairs[base + 3] = g2[0][0]; // x, real
        pairs[base + 4] = g2[1][1]; // y, imaginary
        pairs[base + 5] = g2[1][0]; // y, real
        return n + 1;
    }

    /// @notice Product of `n` pairings (precompile `0x08`, EIP-197).
    /// @dev `pairs` holds `n` contiguous 192-byte pairs. EIP-197 defines the
    ///      cost as `45_000 + 34_000 * n`, the formula the paper's `181,142 gas`
    ///      measurement for `k = 4` reproduces.
    ///
    ///      `ok == false` is not a cheap failure. A rejected input makes the
    ///      precompile consume the whole gas budget it was handed —
    ///      `test_pairingCheck_reportsAnInputItCannotRead` burns its 1e9 budget —
    ///      which is the precompile's own behaviour and the reason a verifier
    ///      that must survive adversarial proofs should hand it an explicit
    ///      limit instead of `gas()`. `Groth16Verifier` keeps `gas()` (the same
    ///      choice every circom verifier makes) and documents it.
    /// @return ok False iff the precompile rejected the input (a point off the
    ///         curve, or a non-canonical coordinate).
    /// @return value The pairing product equals one.
    function pairingCheck(uint256[PAIRS * 6] memory pairs, uint256 n)
        internal
        view
        returns (bool ok, bool value)
    {
        uint256[1] memory out;
        assembly ("memory-safe") {
            ok := staticcall(gas(), 0x08, pairs, mul(n, 0xC0), out, 0x20)
        }
        value = out[0] == 1;
    }
}
