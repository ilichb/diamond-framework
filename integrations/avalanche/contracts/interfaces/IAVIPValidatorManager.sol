// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAVIPCustody} from "./IAVIPCustody.sol";

/// @title IAVIPValidatorManager
/// @notice Validator admission and slashing for the Andromeda Subnet L1.
///
/// @dev Implemented by `AVIPValidatorManager.sol` (milestone M2 of
///      `docs/architecture/implementation-plan.md`). Derived from
///      `docs/architecture/avalanche-integration.md` §2 and the paper's Payment
///      Rule section:
///
///        required stake   `S_f*(T) = max{ S_min, Theta(t) - C_R(T) }`
///        admission        `CoA(i) = S_f(i) + C_R(T(i)) >= Theta(t)`
///        collateral       `C_R(r) = 0.8 * r / (1 + r)`, `r = ||T||_F`
///        saturation       `C_R^inf = 0.8`, hence `S_min = Theta - C_R^inf = 0.2`
///
///      `Theta(t)` is frozen at genesis for the reference implementation.
///      The manager holds no tensor and no Merkle root: the norm comes from
///      `IAVIPRegistry.verifyThreshold(epoch, certifiedNorm, proof)`, the single
///      source of truth for it (§5.2.1).
///
///      Two limits of M2, stated here because this interface is the boundary:
///        - **the threshold `||T||_F >= Theta_r` is enforced here**, not in the
///          registry, so the economic parameter stays out of the trusted-setup
///          ceremony (§5.2.2);
///        - **no custody of its own.** M2 moves no token: it exposes the
///          `S_f*` / `F_0*` policy and, when a custody contract is configured
///          (M8, §5.12), it *checks the declaration against* that custody on
///          admission and asks it to move the funds on a slash. With
///          `custody == address(0)` the behaviour is the original M2 exactly:
///          `financialStake` is declared and not backed.
interface IAVIPValidatorManager {
    /// @notice Emitted when a validator is admitted.
    /// @param validator The admitted validator.
    /// @param stake The financial stake declared by the validator.
    /// @param collateral The reputational collateral `C_R(certifiedNorm)`.
    event ValidatorAdmitted(address indexed validator, uint256 stake, uint256 collateral);

    /// @notice Emitted when a validator is slashed.
    event ValidatorSlashed(address indexed validator, uint256 amount, bytes32 reason);

    /// @notice Emitted when a slash leaves the validator below `S_f*` and the
    ///         admission is therefore revoked: `isAdmitted` must keep implying
    ///         `stakeOf >= requiredStake`.
    event ValidatorEjected(address indexed validator, uint256 stake, uint256 requiredStake);

    /// @notice Emitted on every successful admission, for audit traceability of
    ///         the certified norm and of the amounts derived from it.
    /// @param validator The admitted validator.
    /// @param epoch The epoch whose commitment certified the norm.
    /// @param certifiedNorm The exact `||T||_F` the registry certified.
    /// @param collateral `C_R(certifiedNorm)`.
    /// @param requiredStake `S_f*(certifiedNorm)` the validator had to meet.
    event AdmissionEvaluated(
        address indexed validator,
        uint256 epoch,
        uint256 certifiedNorm,
        uint256 collateral,
        uint256 requiredStake
    );

    /// @notice `certifiedNorm` is below the admission threshold `Theta_r`.
    error NormBelowThreshold(uint256 certifiedNorm, uint256 threshold);

    /// @notice The declared stake is below `S_f*(certifiedNorm)`.
    error InsufficientFinancialStake(uint256 provided, uint256 required);

    /// @notice A custody contract is configured and it does not escrow
    ///         `declared` for that validator (M8, §5.12): the declaration is not
    ///         backed, and a slash would have nothing to seize.
    error FinancialStakeNotBacked(uint256 declared, uint256 escrowed);

    /// @notice `validator` is already admitted.
    error AlreadyAdmitted(address validator);

    error ZeroValidator();

    /// @notice `admit` was called by an address other than `validator`.
    error NotValidator(address caller);

    /// @notice `slash` was called by an address other than the slash authority.
    error NotSlashAuthority(address caller);

    /// @notice The slash would remove more stake than the validator has.
    error SlashExceedsStake(address validator, uint256 requested, uint256 available);

    error ZeroRegistry();
    error ZeroSlashAuthority();

    /// @notice The custody address given to the constructor did not end up bound
    ///         to this manager: it refused the handshake, or it was already bound
    ///         to another manager (§5.12).
    error CustodyNotBound(address custody);

    /// @notice Financial stake declared by `validator` (`0` if never admitted).
    function stakeOf(address validator) external view returns (uint256);

    /// @notice Reputational collateral `C_R(T)` credited to `validator`, i.e.
    ///         `Theta - requiredStake(validator)`. Derived, never stored
    ///         (`0` while the validator is not admitted), §5.2.4.
    function collateralOf(address validator) external view returns (uint256);

    /// @notice Minimum stake `S_f*(T)` required from `validator` at the
    ///         threshold that was certified when it was admitted (`0` if never
    ///         admitted).
    function requiredStake(address validator) external view returns (uint256);

    /// @notice True iff `CoA(validator) >= Theta(t)` at the certified norm.
    function isAdmitted(address validator) external view returns (bool);

    /// @notice The custody contract backing `financialStake`, or `address(0)`
    ///         when the manager is deployed without one (original M2, §5.2.3).
    /// @dev The manager never transfers: it reads `IAVIPCustody.escrowed` on
    ///      admission and calls `IAVIPCustody.debit` on a slash (§5.12). Typed
    ///      rather than `address` so a reader of this interface gets the custody
    ///      boundary and not a loose address; the deployment scripts compare the
    ///      value against the vault whose construction accepted the handshake.
    function custody() external view returns (IAVIPCustody);

    /// @notice The uniform posted price `F_0*`, in WAD. Read by the custody
    ///         contract so the fee has a single source of truth (§5.12).
    function F0_STAR() external view returns (uint256);

    /// @notice Admits `validator`, enforcing the hybrid collateral rule.
    /// @dev The validator admits itself (`msg.sender == validator`). `proof` must
    ///      be a proof for the *current* epoch: the manager reads
    ///      `registry.latestEpoch()` itself, so a proof built for an older epoch
    ///      is rejected by the registry.
    ///
    ///      With a custody contract configured, `financialStake` must be covered
    ///      by escrow there (`FinancialStakeNotBacked` otherwise), so the declared
    ///      stake is always a stake that a slash can actually seize.
    /// @param validator The validator to admit; must be `msg.sender`.
    /// @param financialStake The declared stake: escrowed when custody is set,
    ///        merely declared when it is not.
    /// @param certifiedNorm `||T||_F`, certified by the registry.
    /// @param proof Groth16-shaped proof for `certifiedNorm`.
    function admit(
        address validator,
        uint256 financialStake,
        uint256 certifiedNorm,
        bytes calldata proof
    ) external;

    /// @notice Slashes `amount` from `validator`.
    /// @dev With a custody contract configured, the funds leave custody in the
    ///      same call (`IAVIPCustody.debit`), so the record and the escrow cannot
    ///      diverge; a revert in custody reverts the whole slash.
    /// @param amount Must not exceed `stakeOf(validator)`.
    /// @param reason Machine-readable reason (e.g. a provenance id from the
    ///        slashing notification defined in avalanche-integration.md §4).
    function slash(address validator, uint256 amount, bytes32 reason) external;
}
