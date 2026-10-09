// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IZKThresholdVerifier
/// @notice Verifier for the succinct proof that the committed reputation
///         tensor satisfies `||T||_F >= Theta_r`.
///
/// @dev PROVISIONAL INTERFACE. There is no implementation yet (milestone M3).
///
///      Which proof goes on-chain is fixed by the paper (section
///      "Zero-Knowledge Threshold Proof", subsection "Recursive Verification"):
///
///        - The original R1CS circuit is unsound (it never binds the witness
///          to the committed tensor). It is replaced by Option B: a Pedersen
///          commitment to the flattened tensor plus a Bulletproofs
///          inner-product argument.
///        - Direct on-chain Bulletproofs verification is rejected as too
///          expensive (~6.5M gas at n = 500, ~31x a Groth16 verification).
///        - The Bulletproofs verification is performed OFF-CHAIN and a
///          **recursive SNARK** attests to it. Only the recursive proof is
///          posted (~250k gas).
///
///      The signature below is the standard Groth16 shape (the recursive
///      outer proof is a Groth16 over BN254), so it is stable across the
///      recursion frameworks left open by the paper.
///
///      Measured local costs (main.tex §9, `GasBenchmarks.sol`):
///        ecAdd 292 gas, ecMul 6,142 gas, ecPairing k=4 181,142 gas
///        => Groth16 verification ~206k gas, constant in circuit size.
interface IZKThresholdVerifier {
    /// @notice Verifies a Groth16-shaped proof over BN254.
    /// @param a Proof element A (G1).
    /// @param b Proof element B (G2).
    /// @param c Proof element C (G1).
    /// @param publicInputs Public inputs: the epoch commitment and `Theta_r`.
    /// @return True iff the proof is valid.
    function verify(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[] calldata publicInputs
    ) external view returns (bool);
}
