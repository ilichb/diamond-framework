// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Bn254} from "../contracts/verifiers/Bn254.sol";

/// WHAT IS TESTED
/// --------------
/// 1. Parameter provenance: `FIELD_MODULUS` is the BN254 base field `p` (the
///    modulus EIP-197 uses) and `GROUP_ORDER` its subgroup order `r`; one
///    encoded proof is `8 * 32 = 256` bytes (two coordinates for `a`, four for
///    `b`, two for `c`); four pairs is the Groth16 maximum.
/// 2. Decoding: the eight coordinates are read from the first 256 bytes; a blob
///    shorter than that reverts with `MalformedProof`, a non-canonical
///    coordinate (`>= p`) reverts with `CoordinateOutOfRange` *before* any
///    precompile sees it, and trailing bytes are ignored (the M1 blob shape,
///    §5.2.4).
/// 3. The identity. EIP-196 cannot encode the point at infinity, this codebase
///    encodes it as `(0, 0)`, so `ecAdd`/`ecMul`/`negate` must handle it and
///    `pushPair` must drop pairs that contain it.
/// 4. `ecAdd`/`ecMul` agree with the precompiles they wrap, on the scalars a
///    real verifier uses (`0`, `1`, `2`, `r`) and on the identity.
/// 5. `pushPair` writes the EIP-197 layout: the pairing product it produces for
///    `e(G1, G2) * e(-G1, G2)` is one, which holds only if the `Fp2`
///    coefficients are ordered the way the precompile reads them.
/// 6. `pairingCheck` distinguishes "rejected the input" (a point off the curve)
///    from "the product is not one", and reports both instead of reverting.
///
/// WHAT IS NOT TESTED
/// ------------------
/// - Nothing here is a proof: there is no witness and no circuit (M3 scope).
///   `test/Groth16Verifier.t.sol` is where a full Groth16 equation is checked.
/// - No gas claim: `benchmarks/src/GasBenchmarks.sol` owns the precompile costs
///   the paper cites; this file asserts behaviour.
contract Bn254Test is Test {
    /// @dev `decodeProof` takes `bytes calldata`; see the harness at the bottom.
    Bn254DecoderHarness internal decoder;

    function setUp() public {
        decoder = new Bn254DecoderHarness();
    }

    /// @dev The G1 generator, `(1, 2)`.
    uint256[2] internal g1 = [uint256(1), uint256(2)];

    /// @dev The G2 generator, in the `(c0, c1)` order `Bn254` documents, as
    ///      specified by EIP-197.
    uint256[2][2] internal g2 = [
        [
            uint256(10857046999023057135944570762232829481370756359578518086990519993285655852781),
            uint256(11559732032986387107991004021392285783925812861821192530917403151452391805634)
        ],
        [
            uint256(8495653923123431417604973247489272438418190587263600148770280649306958101930),
            uint256(4082367875863433681332203403145435568316851327593401208105741076214120093531)
        ]
    ];

    uint256[2] internal identity = [uint256(0), uint256(0)];

    // ------------------------------------------------------------- parameters

    function test_parameters_areTheBn254OnesThePrecompilesUse() public pure {
        // `p` and `r` are the canonical alt_bn128 constants; `r` is the order of
        // the subgroups the precompiles multiply inside.
        assertEq(
            Bn254.FIELD_MODULUS,
            21888242871839275222246405745257275088696311157297823662689037894645226208583
        );
        assertEq(
            Bn254.GROUP_ORDER,
            21888242871839275222246405745257275088548364400416034343698204186575808495617
        );
        assertEq(Bn254.COORDINATES, 8);
        assertEq(Bn254.PROOF_LENGTH, 256);
        assertEq(Bn254.PROOF_LENGTH, Bn254.COORDINATES * 32);
        assertEq(Bn254.PAIRS, 4);
    }

    function test_generator_isOnTheG1Curve() public view {
        // y^2 = x^3 + 3: the assertion the pairing cases below rest on.
        assertEq(
            (g1[1] * g1[1]) % Bn254.FIELD_MODULUS, (g1[0] * g1[0] * g1[0] + 3) % Bn254.FIELD_MODULUS
        );
    }

    // --------------------------------------------------------------- decoding

    function test_decodeProof_readsTheEightCoordinates() public view {
        uint256[2] memory a = [uint256(11), uint256(12)];
        uint256[2][2] memory b = [[uint256(21), uint256(22)], [uint256(23), uint256(24)]];
        uint256[2] memory c = [uint256(31), uint256(32)];

        (uint256[2] memory da, uint256[2][2] memory db, uint256[2] memory dc) =
            decoder.decode(abi.encode(a, b, c));

        assertEq(da[0], 11);
        assertEq(da[1], 12);
        assertEq(db[0][0], 21);
        assertEq(db[0][1], 22);
        assertEq(db[1][0], 23);
        assertEq(db[1][1], 24);
        assertEq(dc[0], 31);
        assertEq(dc[1], 32);
    }

    function test_decodeProof_ignoresTrailingBytes() public view {
        uint256[2] memory a = [uint256(11), uint256(12)];
        uint256[2][2] memory b = [[uint256(21), uint256(22)], [uint256(23), uint256(24)]];
        uint256[2] memory c = [uint256(31), uint256(32)];

        // M1's blob was `(a, b, c, publicInputs)`: the trailing array must not
        // change the decoding, and must not be read as public inputs (§5.2.4).
        uint256[] memory legacyInputs = new uint256[](3);
        legacyInputs[0] = 999;
        legacyInputs[1] = 998;
        legacyInputs[2] = 997;
        bytes memory legacy = abi.encode(a, b, c, legacyInputs);
        assertGt(legacy.length, Bn254.PROOF_LENGTH);

        (uint256[2] memory da, uint256[2][2] memory db, uint256[2] memory dc) =
            decoder.decode(legacy);

        assertEq(da[0], a[0]);
        assertEq(db[0][0], b[0][0]);
        assertEq(db[1][1], b[1][1]);
        assertEq(dc[1], c[1]);
    }

    function test_decodeProof_rejectsBlobsShorterThanEightWords() public {
        uint256[2] memory a = [uint256(11), uint256(12)];
        uint256[2][2] memory b = [[uint256(21), uint256(22)], [uint256(23), uint256(24)]];
        uint256[2] memory c = [uint256(31), uint256(32)];

        vm.expectRevert(abi.encodeWithSelector(Bn254.MalformedProof.selector, 0));
        decoder.decode("");

        vm.expectRevert(abi.encodeWithSelector(Bn254.MalformedProof.selector, 192));
        decoder.decode(abi.encode(a, b));

        // One byte short is still short, and the error carries the length that
        // arrived, not the length that was expected.
        bytes memory full = abi.encode(a, b, c);
        bytes memory oneByteShort = new bytes(255);
        for (uint256 i = 0; i < 255; ++i) {
            oneByteShort[i] = full[i];
        }
        vm.expectRevert(abi.encodeWithSelector(Bn254.MalformedProof.selector, 255));
        decoder.decode(oneByteShort);
    }

    function test_decodeProof_acceptsExactlyEightWords() public view {
        uint256[2] memory a = [uint256(11), uint256(12)];
        uint256[2][2] memory b = [[uint256(21), uint256(22)], [uint256(23), uint256(24)]];
        uint256[2] memory c = [uint256(31), uint256(32)];

        bytes memory proof = abi.encode(a, b, c);
        assertEq(proof.length, Bn254.PROOF_LENGTH);

        (uint256[2] memory da,,) = decoder.decode(proof);
        assertEq(da[0], 11);
    }

    function test_decodeProof_rejectsNonCanonicalCoordinates() public {
        uint256[2] memory a = [Bn254.FIELD_MODULUS, uint256(12)];
        uint256[2][2] memory b = [[uint256(21), uint256(22)], [uint256(23), Bn254.FIELD_MODULUS]];
        uint256[2] memory c = [Bn254.FIELD_MODULUS, uint256(32)];

        // Index order: 0-1 `a`, 2-3 `b.x`, 4-5 `b.y`, 6-7 `c`.
        vm.expectRevert(abi.encodeWithSelector(Bn254.CoordinateOutOfRange.selector, 0));
        decoder.decode(abi.encode(a, b, c));

        a[0] = 11;
        vm.expectRevert(abi.encodeWithSelector(Bn254.CoordinateOutOfRange.selector, 5));
        decoder.decode(abi.encode(a, b, c));

        b[1][1] = 24;
        vm.expectRevert(abi.encodeWithSelector(Bn254.CoordinateOutOfRange.selector, 6));
        decoder.decode(abi.encode(a, b, c));

        // `p - 1` is the largest canonical coordinate and must pass.
        a[0] = Bn254.FIELD_MODULUS - 1;
        c[0] = 31;
        (uint256[2] memory da,,) = decoder.decode(abi.encode(a, b, c));
        assertEq(da[0], Bn254.FIELD_MODULUS - 1);
    }

    // ------------------------------------------------------------ arithmetic

    function test_negate_flipsTheSignAndKeepsTheIdentity() public view {
        uint256[2] memory negated = Bn254.negate(g1);
        assertEq(negated[0], 1);
        assertEq(negated[1], Bn254.FIELD_MODULUS - 2);

        assertTrue(Bn254.isInfinity(Bn254.ecAdd(g1, negated)));
        assertTrue(Bn254.isInfinity(Bn254.negate(identity)));
    }

    function test_ecAdd_matchesThePrecompileOnRealPoints() public view {
        // 2*G1 through the adder (0x06) and through the multiplier (0x07).
        uint256[2] memory doubled = Bn254.ecAdd(g1, g1);
        uint256[2] memory doubledViaMul = Bn254.ecMul(g1, 2);
        assertEq(doubled[0], doubledViaMul[0]);
        assertEq(doubled[1], doubledViaMul[1]);
        assertFalse(Bn254.isInfinity(doubled));

        // 3*G1 = 2*G1 + G1 = G1 * 3: two independent routes.
        uint256[2] memory tripled = Bn254.ecAdd(doubled, g1);
        uint256[2] memory tripledViaMul = Bn254.ecMul(g1, 3);
        assertEq(tripled[0], tripledViaMul[0]);
        assertEq(tripled[1], tripledViaMul[1]);
    }

    function test_ecAdd_isTheIdentityAwareVariant() public view {
        uint256[2] memory withIdentityRight = Bn254.ecAdd(g1, identity);
        assertEq(withIdentityRight[0], g1[0]);
        assertEq(withIdentityRight[1], g1[1]);

        uint256[2] memory withIdentityLeft = Bn254.ecAdd(identity, g1);
        assertEq(withIdentityLeft[0], g1[0]);
        assertEq(withIdentityLeft[1], g1[1]);

        assertTrue(Bn254.isInfinity(Bn254.ecAdd(identity, identity)));
    }

    function test_ecMul_matchesThePrecompileOnTheScalarsAProverUses() public view {
        // A zero scalar short-circuits: `(0, 0)` cannot be handed to 0x07.
        assertTrue(Bn254.isInfinity(Bn254.ecMul(g1, 0)));
        assertTrue(Bn254.isInfinity(Bn254.ecMul(identity, 7)));

        uint256[2] memory one = Bn254.ecMul(g1, 1);
        assertEq(one[0], g1[0]);
        assertEq(one[1], g1[1]);

        // `r * G1 = O`, and the precompile encodes the identity as `(0, 0)`.
        assertTrue(Bn254.isInfinity(Bn254.ecMul(g1, Bn254.GROUP_ORDER)));

        // `k` and `k mod r` select the same multiple. This is why a public
        // input (a 32-byte root, which usually exceeds `r`) needs no reduction
        // before the verifier multiplies with it.
        uint256[2] memory atTwo = Bn254.ecMul(g1, 2);
        uint256[2] memory atTwoPlusR = Bn254.ecMul(g1, 2 + Bn254.GROUP_ORDER);
        assertEq(atTwo[0], atTwoPlusR[0]);
        assertEq(atTwo[1], atTwoPlusR[1]);
    }

    // --------------------------------------------------------------- pairing

    function test_pushPair_dropsPairsThatContainTheIdentity() public view {
        uint256[2][2] memory identityX = [[uint256(0), uint256(0)], [uint256(0), uint256(0)]];
        identityX[1][0] = g2[1][0];
        identityX[1][1] = g2[1][1];

        uint256[24] memory pairs;
        assertEq(Bn254.pushPair(pairs, 0, identity, g2), 0); // e(O, G2) = 1
        assertEq(Bn254.pushPair(pairs, 0, g1, identityX), 0); // e(G1, O) = 1
        assertEq(Bn254.pushPair(pairs, 0, g1, g2), 1); // kept
    }

    function test_pushPair_writesTheEip197Layout() public view {
        uint256[24] memory pairs;
        uint256 n = Bn254.pushPair(pairs, 0, g1, g2);
        assertEq(n, 1);

        // EIP-197 reads (x_imag, x_real, y_imag, y_real), while the prover
        // emits (real, imaginary): this is the single place that reorders.
        assertEq(pairs[0], g1[0]);
        assertEq(pairs[1], g1[1]);
        assertEq(pairs[2], g2[0][1]);
        assertEq(pairs[3], g2[0][0]);
        assertEq(pairs[4], g2[1][1]);
        assertEq(pairs[5], g2[1][0]);
    }

    function test_pairingCheck_acceptsAProductOfOne() public view {
        // e(G1, G2) * e(-G1, G2) = 1, assembled through `pushPair`, so the Fp2
        // ordering of case 5 of the header is exercised end to end.
        uint256[24] memory pairs;
        uint256 n = Bn254.pushPair(pairs, 0, g1, g2);
        n = Bn254.pushPair(pairs, n, Bn254.negate(g1), g2);
        assertEq(n, 2);

        (bool ok, bool value) = Bn254.pairingCheck(pairs, n);
        assertTrue(ok);
        assertTrue(value);
    }

    function test_pairingCheck_rejectsAProductThatIsNotOne() public view {
        uint256[24] memory pairs;
        uint256 n = Bn254.pushPair(pairs, 0, g1, g2);

        (bool ok, bool value) = Bn254.pairingCheck(pairs, n);
        assertTrue(ok);
        assertFalse(value);
    }

    function test_pairingCheck_reportsAnInputItCannotRead() public view {
        // `(1, 1)` is not on `y^2 = x^3 + 3`: 0x08 rejects its input instead of
        // answering, and `ok` is what says which of the two happened.
        uint256[2] memory offCurve = [uint256(1), uint256(1)];
        uint256[24] memory pairs;
        uint256 n = Bn254.pushPair(pairs, 0, offCurve, g2);
        assertEq(n, 1);

        (bool ok, bool value) = Bn254.pairingCheck(pairs, n);
        assertFalse(ok);
        assertFalse(value);
    }
}

/// @dev `Bn254.decodeProof` takes `bytes calldata` — that is the shape the
///      registry hands it (a `calldata` parameter is not copied), while a test
///      builds its blobs in memory. This harness is the shortest honest path to
///      the same function: it reimplements nothing.
contract Bn254DecoderHarness {
    function decode(bytes calldata proof)
        external
        pure
        returns (uint256[2] memory a, uint256[2][2] memory b, uint256[2] memory c)
    {
        return Bn254.decodeProof(proof);
    }
}
