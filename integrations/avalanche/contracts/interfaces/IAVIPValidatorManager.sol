// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IAVIPValidatorManager
/// @notice Validator admission and slashing for the Andromeda Subnet L1.
///
/// @dev PROVISIONAL INTERFACE. There is no implementation yet (milestone M2).
///      Derived from `docs/architecture/avalanche-integration.md` §2 and the
///      paper's Payment Rule section:
///
///        required stake   `S_f*(T) = max{ S_min, Theta(t) - C_R(T) }`
///        admission        `CoA(i) = S_f(i) + C_R(T(i)) >= Theta(t)`
///        collateral       `C_R(r) = 0.8 * r / (1 + r)`, `r = ||T||_F`
///        saturation       `C_R^inf = 0.8`, hence `S_min = Theta - C_R^inf = 0.2`
///
///      `Theta(t)` is frozen at genesis for the reference implementation.
///      The manager reads reputation from `IAVIPRegistry` and never stores
///      the tensor itself.
interface IAVIPValidatorManager {
    /// @notice Emitted when a validator is admitted.
    event ValidatorAdmitted(address indexed validator, uint256 stake, uint256 collateral);

    /// @notice Emitted when a validator is slashed.
    event ValidatorSlashed(address indexed validator, uint256 amount, bytes32 reason);

    /// @notice Financial stake locked by `validator`.
    function stakeOf(address validator) external view returns (uint256);

    /// @notice Reputational collateral `C_R(T)` credited to `validator`.
    function collateralOf(address validator) external view returns (uint256);

    /// @notice Minimum stake `S_f*(T)` required from `validator` at the
    ///         current admission threshold.
    function requiredStake(address validator) external view returns (uint256);

    /// @notice True iff `CoA(validator) >= Theta(t)`.
    function isAdmitted(address validator) external view returns (bool);

    /// @notice Admits `validator`, enforcing the hybrid collateral rule.
    function admit(address validator) external;

    /// @notice Slashes `amount` from `validator`.
    /// @param reason Machine-readable reason (e.g. a provenance id from the
    ///        slashing notification defined in avalanche-integration.md §4).
    function slash(address validator, uint256 amount, bytes32 reason) external;
}
