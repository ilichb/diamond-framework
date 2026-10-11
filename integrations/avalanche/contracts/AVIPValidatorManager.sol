// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAVIPRegistry} from "./interfaces/IAVIPRegistry.sol";
import {IAVIPCustody} from "./interfaces/IAVIPCustody.sol";
import {IAVIPValidatorManager} from "./interfaces/IAVIPValidatorManager.sol";

/// @title AVIPValidatorManager
/// @notice Hybrid validator admission for the Andromeda Subnet L1.
///
/// @dev Milestone M2 of `docs/architecture/implementation-plan.md` (§5.2). The
///      rule is the paper's payment rule, in WAD:
///
///        `CoA(i)  = S_f(i) + C_R(||T||_F) >= Theta`
///        `S_f*(r) = max{ S_min, Theta - C_R(r) }`
///        `C_R(r)  = C_R^inf * r / (1 + r)`, `C_R^inf = 0.8`, `r = ||T||_F`
///
///      With `Theta = 1.0` and `C_R^inf = 0.8`, `Theta - C_R(r) =
///      0.2 + 0.2/(1 + r) > S_min = 0.2` for every finite `r`: the floor is
///      **inert** and `S_f*` is the first term. The `max` is kept because it is
///      what the paper specifies, and because it would start to bind if `S_min`
///      were ever raised above `Theta - C_R^inf` (§5.2.4).
///
///      Division of labour with the registry (§5.2.1, §5.2.2):
///        - the registry certifies the **exact** norm (`||T||_F =
///          certifiedNorm`) from its own committed root, and is `view`: it holds
///          no per-validator state, so nobody can consume a proof slot that is
///          not theirs;
///        - this contract enforces the admission threshold
///          (`certifiedNorm >= Theta_r`), the stake rule and the anti-replay
///          rule (`!isAdmitted[validator]`).
///
///      NOT implemented here, deliberately:
///        - **custody** and slashing fund management: `financialStake` is
///          *declared* here and, when a custody contract is configured (M8, the
///          Treasury Module, §5.12), backed by escrow there. This contract still
///          moves no token: it checks the declaration against
///          `IAVIPCustody.escrowed` on admission and calls `IAVIPCustody.debit`
///          on a slash. With `custody == address(0)` the behaviour is the
///          original M2 exactly (§5.2.3);
///        - **reputation weights** / voting power dynamics (deferred to M6);
///        - **the data layer** that decides a slash: this contract only receives
///          the decision, from one authorised address (M7).
///
///      One consequence of the custody pair worth stating where the code is: the
///      custody contract cannot know this manager's address and this manager
///      cannot know the custody's, since each needs the other. The custody is
///      therefore deployed first and the constructor below performs the
///      handshake (`bindManager` + a check of the result), so §5.12 leaves no
///      winding order a deployer can silently get wrong.
contract AVIPValidatorManager is IAVIPValidatorManager {
    /// @notice WAD unit of the fixed-point parameters.
    uint256 public constant ONE = 1e18;

    /// @notice Admission threshold `Theta(t)`, frozen at genesis
    ///         (paper, Payment Rule).
    uint256 public constant THETA = 1e18;

    /// @notice Saturation of the collateral: `C_R^inf = 0.8`
    ///         (paper, Reputation Dynamics).
    uint256 public constant CR_INF = 8e17;

    /// @notice Floor on the financial stake, `S_min = Theta - C_R^inf = 0.2`
    ///         (`verification/mechanism/financial_floor_sensitivity.py`).
    uint256 public constant S_MIN = 2e17;

    /// @notice Frobenius threshold `Theta_r = 0.5` **[CONJECTURE]** (main.tex,
    ///         Zero-Knowledge Threshold Proof). Enforced here, not in the
    ///         circuit: the circuit proves equality, so this economic parameter
    ///         stays out of the trusted-setup ceremony (§5.2.2).
    uint256 public constant THETA_R = 5e17;

    /// @notice Uniform posted price `F_0* = 0.05` (paper §6.4, Payment Rule).
    /// @dev Exposed here and *collected* only by the custody contract, which reads
    ///      this value so the policy has one source of truth (§5.12): M2 itself
    ///      moves no token. On the
    ///      admissible domain `||T||_F >= Theta_r` the optimum is
    ///      `0.07666...` (`76666666666666667`); `0.05` is kept because it is the
    ///      paper's value, it is individually rational (a lower fee only relaxes
    ///      `U >= 0`) and it is a safe lower bound (§5.2.3).
    uint256 public constant F0_STAR = 5e16;

    /// @notice Registry that certifies `||T||_F` (M1, amended by M2 §5.2).
    /// @dev Storage rather than `immutable`, to keep the same shape as
    ///      `AVIPRegistry.sol`. There is no setter: the constructor fixes it.
    IAVIPRegistry public registry;

    /// @notice The only address allowed to call `slash`: the role that carries
    ///         the data layer's slashing decision
    ///         (`avalanche-integration.md` §4). No setter: fixed by the
    ///         constructor.
    address public slashAuthority;

    /// @notice Custody of the stake this contract records (M8, §5.12), or
    ///         `address(0)` for the original M2 behaviour: declared and not
    ///         backed. Storage rather than `immutable`, like `registry`, and no
    ///         setter — the constructor fixes it *and* binds the custody to this
    ///         address in the same call (§5.12).
    IAVIPCustody public custody;

    mapping(address => uint256) private _stakes;
    mapping(address => uint256) private _requiredStakes;
    mapping(address => bool) private _admitted;

    /// @param registry_ The registry to read epoch commitments from.
    /// @param slashAuthority_ The only address allowed to slash.
    /// @param custody_ Custody backing `financialStake`, or `address(0)` to
    ///        declare it without backing it (§5.2.3).
    constructor(address registry_, address slashAuthority_, address custody_) {
        if (registry_ == address(0)) revert ZeroRegistry();
        if (slashAuthority_ == address(0)) revert ZeroSlashAuthority();
        registry = IAVIPRegistry(registry_);
        slashAuthority = slashAuthority_;
        if (custody_ != address(0)) {
            // The handshake of §5.12: custody is deployed first (it cannot know
            // this manager's address), and this constructor fills its single hole
            // and then verifies the result. If another manager already took the
            // hole, or the address is not a custody at all, the call reverts and
            // this deployment fails — a manager wired to somebody else's vault is
            // a failure this constructor must not allow to exist.
            IAVIPCustody(custody_).bindManager();
            if (IAVIPCustody(custody_).manager() != address(this)) {
                revert CustodyNotBound(custody_);
            }
        }
        custody = IAVIPCustody(custody_);
    }

    // ------------------------------------------------------------ the policy

    /// @notice Reputational collateral `C_R(r) = C_R^inf * r / (1 + r)`, in WAD.
    /// @param norm The Frobenius norm `r = ||T||_F`, in WAD.
    function collateralFor(uint256 norm) public pure returns (uint256) {
        return (CR_INF * norm) / (ONE + norm);
    }

    /// @notice Minimum stake `S_f*(r) = max{ S_min, Theta - C_R(r) }`, in WAD.
    /// @param norm The Frobenius norm `r = ||T||_F`, in WAD.
    function requiredStakeFor(uint256 norm) public pure returns (uint256) {
        uint256 stake = THETA - collateralFor(norm);
        return stake > S_MIN ? stake : S_MIN;
    }

    // ----------------------------------------------------------------- views

    /// @inheritdoc IAVIPValidatorManager
    function stakeOf(address validator) external view returns (uint256) {
        return _stakes[validator];
    }

    /// @inheritdoc IAVIPValidatorManager
    function requiredStake(address validator) external view returns (uint256) {
        return _requiredStakes[validator];
    }

    /// @inheritdoc IAVIPValidatorManager
    function isAdmitted(address validator) external view returns (bool) {
        return _admitted[validator];
    }

    /// @inheritdoc IAVIPValidatorManager
    function collateralOf(address validator) external view returns (uint256) {
        // Derived, never stored: `Theta - S_f*` is `C_R` by construction, so
        // there is no second source of truth to keep in sync (§5.2.4). A
        // validator that is not admitted has no collateral to its name.
        if (!_admitted[validator]) return 0;
        return THETA - _requiredStakes[validator];
    }

    // ------------------------------------------------------------- admission

    /// @inheritdoc IAVIPValidatorManager
    function admit(
        address validator,
        uint256 financialStake,
        uint256 certifiedNorm,
        bytes calldata proof
    ) external {
        if (validator == address(0)) revert ZeroValidator();
        // Admission is something a validator declares about itself. A third
        // party cannot do it, and so cannot consume the admission slot.
        if (msg.sender != validator) revert NotValidator(msg.sender);
        if (_admitted[validator]) revert AlreadyAdmitted(validator);

        // The registry certifies the exact norm and enforces no threshold: that
        // is this contract's job (§5.2.2). `Theta_r` sits outside the circuit on
        // purpose, so the admissible domain starts at `||T||_F = Theta_r` and
        // `T = 0` is no longer an admissible type (§5.2.3).
        if (certifiedNorm < THETA_R) revert NormBelowThreshold(certifiedNorm, THETA_R);

        uint256 collateral = collateralFor(certifiedNorm);
        uint256 stake = requiredStakeFor(certifiedNorm);
        if (financialStake < stake) revert InsufficientFinancialStake(financialStake, stake);

        // With custody configured, the declaration must be covered by escrow:
        // what a validator declares is what this contract's `slash` can later
        // take out of custody (§5.12). The check is a `view` on the custody it
        // was constructed with, so it adds no trust in a caller. With no custody
        // this is the original M2: declared, not backed (§5.2.3).
        if (address(custody) != address(0)) {
            uint256 escrowed = custody.escrowed(validator);
            if (financialStake > escrowed) {
                revert FinancialStakeNotBacked(financialStake, escrowed);
            }
        }

        // The registry reads `commitmentOf(epoch)` itself and builds
        // `[uint256(root), epoch, certifiedNorm]`, so a proof for another epoch,
        // another root or another norm cannot pass (§5.2.1). The latest epoch
        // keeps the admission bound to the freshest tensor; with no commitment
        // posted `latestEpoch()` is `type(uint256).max` and the registry reverts
        // with `UnknownEpoch`.
        uint256 epoch = registry.latestEpoch();
        if (!registry.verifyThreshold(epoch, certifiedNorm, proof)) {
            revert IAVIPRegistry.InvalidZKProof();
        }

        _admitted[validator] = true;
        _stakes[validator] = financialStake;
        _requiredStakes[validator] = stake;

        emit AdmissionEvaluated(validator, epoch, certifiedNorm, collateral, stake);
        emit ValidatorAdmitted(validator, financialStake, collateral);
    }

    // -------------------------------------------------------------- slashing

    /// @inheritdoc IAVIPValidatorManager
    function slash(address validator, uint256 amount, bytes32 reason) external {
        if (msg.sender != slashAuthority) revert NotSlashAuthority(msg.sender);

        uint256 available = _stakes[validator];
        if (amount > available) revert SlashExceedsStake(validator, amount, available);

        uint256 remaining = available - amount;
        _stakes[validator] = remaining;

        emit ValidatorSlashed(validator, amount, reason);

        // `isAdmitted` must keep implying `stakeOf >= requiredStake`: once the
        // slash leaves less than `S_f*`, the admission rule no longer holds and
        // the validator stops being admitted.
        if (_admitted[validator] && remaining < _requiredStakes[validator]) {
            _admitted[validator] = false;
            emit ValidatorEjected(validator, remaining, _requiredStakes[validator]);
        }

        // Funds last, and only now: every write on this side has already
        // happened, so the custody contract is the last thing to act and a
        // revert in it (a failing token, a refusing sink) rolls this whole call
        // back — record and escrow move together or not at all (§5.12). A
        // zero-amount slash moves nothing and is a no-op in custody.
        if (address(custody) != address(0)) {
            custody.debit(validator, amount, reason);
        }
    }
}
