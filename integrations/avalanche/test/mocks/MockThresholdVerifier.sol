// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IZKThresholdVerifier} from "../../contracts/interfaces/IZKThresholdVerifier.sol";

/// @title MockThresholdVerifier
/// @notice Test double for `IZKThresholdVerifier`: the real pairing check is
///         milestone M3. It performs no cryptography. What it does do is assert
///         the two properties the registry must guarantee before the pairing is
///         real:
///
///           1. `EXPECTED_A0` — the `bytes proof` blob is decoded and `(a, b, c)`
///              are forwarded **unchanged**;
///           2. `EXPECTED_STATEMENT` — the registry built the statement
///              `[statementRoot, epoch, uint160(validator), certifiedNorm]` from
///              its **own** state (`statementRootOf(epoch)`), not from anything
///              the caller passed (§5.2.1 of
///              `docs/architecture/implementation-plan.md`).
///
/// @dev `verify` is `view` in `IZKThresholdVerifier`, so the double cannot
///      record what it saw; it compares the call against constructor
///      expectations instead and reverts on a mismatch, which is what the
///      registry tests then assert on.
contract MockThresholdVerifier is IZKThresholdVerifier {
    bool internal immutable ANSWER;
    uint256 internal immutable EXPECTED_A0;
    bytes32 internal immutable EXPECTED_STATEMENT;

    /// @param answer_ The value `verify` returns.
    /// @param expectedA0_ Expected `a[0]`.
    /// @param expectedStatement_ `abi.encode(statement)` for the statement the
    ///        registry is expected to build.
    constructor(bool answer_, uint256 expectedA0_, bytes memory expectedStatement_) {
        ANSWER = answer_;
        EXPECTED_A0 = expectedA0_;
        EXPECTED_STATEMENT = keccak256(expectedStatement_);
    }

    function verify(
        uint256[2] calldata a,
        uint256[2][2] calldata,
        uint256[2] calldata,
        uint256[] calldata publicInputs
    ) external view returns (bool) {
        require(a[0] == EXPECTED_A0, "mock: proof not forwarded unchanged");
        require(
            keccak256(abi.encode(publicInputs)) == EXPECTED_STATEMENT, "mock: unexpected statement"
        );
        return ANSWER;
    }
}
