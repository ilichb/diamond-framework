// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IZKThresholdVerifier} from "../interfaces/IZKThresholdVerifier.sol";
import {Bn254} from "./Bn254.sol";

/// @title Groth16Verifier
/// @notice On-chain Groth16 verifier over BN254, milestone M3 of
///         `docs/architecture/implementation-plan.md`.
///
/// @dev The pairing equation is the standard Groth16 one:
///
///        e(-A, B) * e(alpha1, beta2) * e(vk_x, gamma2) * e(C, delta2) == 1
///
///      with `vk_x = ic[0] + sum_i(publicInputs[i] * ic[i + 1])`. Four pairings
///      is `k = 4`, the figure the paper measures (`181,142 gas` for the pairing
///      step in `GasBenchmarks.sol`, ~206k for a full verification).
///
///      **The verification key is installed, not hardcoded.** The repository
///      ships development keys for M4b's global statement and M4d's admission
///      statement (P-01/P-16); neither has a trusted-setup ceremony, so neither
///      carries a security claim. This contract therefore takes the
///      `VerifyingKey` in the constructor and exposes `verifyingKeyDigest()`, the
///      digest of exactly what it was installed with. A ceremony replaces the
///      key at deployment and *nothing else in this contract changes*; the digest
///      is what an off-chain prover compares against to know which key is live.
///
///      The key lives in storage rather than in the bytecode, which is where a
///      frozen key would end up: the snarkjs generator hardcodes it as literal
///      `IC`/`beta2` constants and saves that reload. That trade is deliberate
///      here — it is the difference between a verifier that can be deployed today
///      and one that cannot be deployed until a trusted setup ceremony has
///      happened. It is also part of the gap between the benchmark's ≈206k
///      (inlined key) and the 223,445 gas measured for `verify` in
///      `test/Groth16Verifier.t.sol::test_verify_costsAboutFourPairings`.
///
///      Deliberately NOT claimed:
///        - **No soundness claim about the statement.** This contract checks a
///          Groth16 equation correctly; whether the circuit ties
///          `[statementRoot, epoch, validator, certifiedNorm]` to the committed
///          tensor is a property of the circuit, not of this wrapper.
///        - **No circuit size independence claim of its own.** The paper's
///          "constant in circuit size" holds for the verification key's public
///          input count (4 here: statement root, epoch, validator, certified
///          norm), not for the witness the circuit constrains.
contract Groth16Verifier is IZKThresholdVerifier {
    /// @notice Groth16 verification key over BN254.
    /// @param alpha1 `alpha` in G1.
    /// @param beta2 `beta` in G2.
    /// @param gamma2 `gamma` in G2.
    /// @param delta2 `delta` in G2.
    /// @param ic Public-input commitments in G1, `ic.length = nPublic + 1`.
    /// @dev G2 coordinates are in the natural `Fp2` order `(c0, c1)`, i.e. the
    ///      order a prover emits; `Bn254.pushPair` reorders them for EIP-197.
    struct VerifyingKey {
        uint256[2] alpha1;
        uint256[2][2] beta2;
        uint256[2][2] gamma2;
        uint256[2][2] delta2;
        uint256[2][] ic;
    }

    /// @dev The key cannot verify anything: no `ic`, or a point that is not on
    ///      the curve (checked by running the pairing precompile over it).
    error InvalidVerifyingKey();

    /// @dev The caller supplied `got` public inputs where the installed key
    ///      commits to `expected`. The registry builds the statement itself, so
    ///      this is a wiring error, not an attacker-controlled path.
    error PublicInputsMismatch(uint256 expected, uint256 got);

    /// @notice Emitted once, with the digest of the installed key.
    event VerifyingKeyInstalled(bytes32 indexed digest, uint256 numPublicInputs);

    /// @notice `keccak256(abi.encode(VerifyingKey))` of the installed key.
    bytes32 internal immutable VERIFYING_KEY_DIGEST;

    VerifyingKey private _vk;

    /// @param vk The verification key. Its `ic` must be non-empty and every
    ///        point in it must be on the curve, which is checked by handing the
    ///        key to the pairing precompile in this constructor.
    constructor(VerifyingKey memory vk) {
        if (vk.ic.length == 0) revert InvalidVerifyingKey();
        if (!_wellFormed(vk)) revert InvalidVerifyingKey();

        _vk.alpha1 = vk.alpha1;
        _vk.beta2 = vk.beta2;
        _vk.gamma2 = vk.gamma2;
        _vk.delta2 = vk.delta2;
        for (uint256 i = 0; i < vk.ic.length; ++i) {
            _vk.ic.push(vk.ic[i]);
        }

        VERIFYING_KEY_DIGEST = keccak256(abi.encode(vk));
        emit VerifyingKeyInstalled(VERIFYING_KEY_DIGEST, vk.ic.length - 1);
    }

    /// @notice Digest of the installed key: `keccak256(abi.encode(vk))`.
    /// @dev What an off-chain prover compares against to know which key the
    ///      deployed verifier is checking against (the key is installed, not
    ///      hardcoded: see the contract header).
    function verifyingKeyDigest() external view returns (bytes32) {
        return VERIFYING_KEY_DIGEST;
    }

    /// @inheritdoc IZKThresholdVerifier
    function verify(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[] calldata publicInputs
    ) external view returns (bool) {
        uint256 expected = _vk.ic.length - 1;
        if (publicInputs.length != expected) {
            revert PublicInputsMismatch(expected, publicInputs.length);
        }

        uint256[24] memory pairs; // Bn254.PAIRS * 6 words
        uint256 n;
        n = Bn254.pushPair(pairs, n, Bn254.negate(a), b);
        n = Bn254.pushPair(pairs, n, _vk.alpha1, _vk.beta2);
        n = Bn254.pushPair(pairs, n, _vkX(publicInputs), _vk.gamma2);
        n = Bn254.pushPair(pairs, n, c, _vk.delta2);

        // Every pair was the identity: the equation is `1 == 1`. Not reachable
        // with a key that passed the constructor (an on-curve `alpha1` cannot be
        // `(0, 0)`), but stated rather than left as a silent fallthrough.
        if (n == 0) return true;

        (bool ok, bool value) = Bn254.pairingCheck(pairs, n);
        if (!ok) revert Bn254.PrecompileFailed(0x08);
        return value;
    }

    /// @notice Number of public inputs the installed key commits to.
    function numPublicInputs() external view returns (uint256) {
        return _vk.ic.length - 1;
    }

    /// @notice `ic` length, `numPublicInputs() + 1`.
    function icLength() external view returns (uint256) {
        return _vk.ic.length;
    }

    /// @notice `ic[i]`, the public-input commitment for input `i - 1`.
    function icAt(uint256 i) external view returns (uint256[2] memory) {
        return _vk.ic[i];
    }

    /// @notice `alpha` in G1.
    function alpha1() external view returns (uint256[2] memory) {
        return _vk.alpha1;
    }

    /// @notice `beta` in G2.
    function beta2() external view returns (uint256[2][2] memory) {
        return _vk.beta2;
    }

    /// @notice `gamma` in G2.
    function gamma2() external view returns (uint256[2][2] memory) {
        return _vk.gamma2;
    }

    /// @notice `delta` in G2.
    function delta2() external view returns (uint256[2][2] memory) {
        return _vk.delta2;
    }

    /// @notice `vk_x = ic[0] + sum_i(publicInputs[i] * ic[i + 1])`.
    /// @dev Zero inputs and zero commitments short-circuit in `Bn254`, so a
    ///      legitimate `certifiedNorm = 0` statement is verifiable rather than a
    ///      precompile failure.
    function _vkX(uint256[] calldata publicInputs) private view returns (uint256[2] memory vkx) {
        vkx = _vk.ic[0];
        for (uint256 i = 0; i < publicInputs.length; ++i) {
            if (publicInputs[i] == 0) continue;
            vkx = Bn254.ecAdd(vkx, Bn254.ecMul(_vk.ic[i + 1], publicInputs[i]));
        }
    }

    /// @dev True iff the pairing precompile accepts every point of the key. It
    ///      runs up to four pairs at a time (the precompile's Groth16 shape is
    ///      also its batch shape); the pairing product itself is ignored, only
    ///      the "did it reject the input" bit matters.
    function _wellFormed(VerifyingKey memory vk) private view returns (bool) {
        uint256[24] memory pairs; // Bn254.PAIRS * 6 words
        uint256 n;
        n = Bn254.pushPair(pairs, n, vk.alpha1, vk.beta2);
        n = Bn254.pushPair(pairs, n, vk.ic[0], vk.gamma2);
        n = Bn254.pushPair(pairs, n, vk.ic[0], vk.delta2);

        for (uint256 i = 1; i < vk.ic.length; ++i) {
            n = Bn254.pushPair(pairs, n, vk.ic[i], vk.gamma2);
            if (n == Bn254.PAIRS) {
                if (!_accepted(pairs, n)) return false;
                n = 0;
            }
        }

        if (n > 0 && !_accepted(pairs, n)) return false;
        return true;
    }

    function _accepted(uint256[24] memory pairs, uint256 n) private view returns (bool) {
        (bool ok,) = Bn254.pairingCheck(pairs, n);
        return ok;
    }
}
