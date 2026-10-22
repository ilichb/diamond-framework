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
///        `CoA(i)  = S_f(i) + C_R(T(i)) >= Theta`
///        `S_f*(r) = max{ S_min, Theta - C_R(r) }`
///        `C_R(r)  = C_R^inf * r / (1 + r)`, `C_R^inf = 0.8`, `r = T(i)`
///
///      With `Theta = 1.0` and `C_R^inf = 0.8`, `Theta - C_R(r) =
///      0.2 + 0.2/(1 + r) > S_min = 0.2` for every finite `r`: the floor is
///      **inert** and `S_f*` is the first term. The `max` is kept because it is
///      what the paper specifies, and because it would start to bind if `S_min`
///      were ever raised above `Theta - C_R^inf` (§5.2.4).
///
///      One amendment of §12.1.2 sits on top of the paper's rule (M9c): the stake
///      a **re-admission** must post is `S_f*(r) + ejections * kappa`, while the
///      credit `C_R(r)` is untouched. The surcharge is a separate term rather than
///      an inflation of `S_f*`, because `Theta - S_f*` is the collateral the norm
///      earns: inflating it would make that credit shrink with a validator's
///      history and go negative for a serial ejectee.
///
///      Division of labour with the registry (§5.2.1, §5.2.2):
///        - the registry certifies the **exact** per-validator norm
///          (`T(v) = certifiedNorm`) from its own committed Poseidon root, and
///          is `view`: it holds no per-validator state, so nobody can consume a
///          proof slot that is not theirs;
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
    ///      admissible domain `T(i) >= Theta_r` the optimum is
    ///      `0.07666...` (`76666666666666667`); `0.05` is kept because it is the
    ///      paper's value, it is individually rational (a lower fee only relaxes
    ///      `U >= 0`) and it is a safe lower bound (§5.2.3).
    uint256 public constant F0_STAR = 5e16;

    /// @notice The ejection surcharge **κ** (§12.1.2, M9c), in WAD: each past
    ///         ejection adds this much to the next admission's requirement, i.e.
    ///         `requiredStake(v) = S_f*(r) + ejectionsOf(v) * κ`.
    /// @dev A **deployment constant with no paper value** (§6): the paper names the
    ///      term symbolically and claims no magnitude for it, so no
    ///      `verification/` script and no `F-` entry are opened for it (§9's
    ///      code→paper rule). `0.1` is a choice of this deployment and not a
    ///      measurement: a visible fraction of `Theta = 1.0`, large enough to be a
    ///      whole base unit even for a one-decimal token, small enough that the
    ///      third chance (not the second) is what a serial ejectee cannot afford.
    ///      What the *rule* buys does not depend on it: the re-entry cost is a
    ///      separate term rather than an inflation of `S_f*`, so `Theta - C_R`
    ///      cannot go negative however many times a validator is ejected —
    ///      inflating `S_f*` would make a many-times-ejected validator's implied
    ///      collateral negative long before its requirement became unpayable.
    uint256 public constant EJECTION_SURCHARGE = 1e17;

    /// @notice Registry that certifies one validator's `T(v)` (M1, amended by
    ///         M2 §5.2 and M4d).
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
    /// @dev The requirement the validator is held to while admitted, in WAD:
    ///      `S_f*(r)` **plus** the surcharge it was admitted against (§12.1.2,
    ///      M9c), so the ejection rule below keeps comparing `stakeOf` against one
    ///      number and the norm's credit stays a separate quantity.
    mapping(address => uint256) private _requiredStakes;
    mapping(address => bool) private _admitted;
    /// @dev How many times each validator has been ejected. Never reset, and read
    ///      by the next `admit` to price the re-entry; it is also what makes the
    ///      surcharge inside `_requiredStakes` recoverable without storing a second
    ///      copy of it (`collateralOf`).
    mapping(address => uint256) private _ejections;

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
            //
            // This call is also why `bindManager` cannot demand code from its
            // caller (`msg.sender.code.length > 0`): the binding happens inside
            // this constructor, where `address(this)` still reports
            // `EXTCODESIZE 0`, so such a guard would refuse the legitimate
            // manager. What the vault can lose to an EOA that binds first is
            // stated in `AVIPStakeVault.sol` and in plan §5.12; the close is
            // operational — deploy the custody and this manager in one
            // broadcast — not a guard.
            IAVIPCustody(custody_).bindManager();
            if (IAVIPCustody(custody_).manager() != address(this)) {
                revert CustodyNotBound(custody_);
            }
        }
        custody = IAVIPCustody(custody_);
    }

    // ------------------------------------------------------------ the policy

    /// @notice Reputational collateral `C_R(r) = C_R^inf * r / (1 + r)`, in WAD.
    /// @param norm The validator's committed norm `r = T(i)`, in WAD.
    function collateralFor(uint256 norm) public pure returns (uint256) {
        return (CR_INF * norm) / (ONE + norm);
    }

    /// @notice Minimum stake `S_f*(r) = max{ S_min, Theta - C_R(r) }`, in WAD.
    /// @param norm The validator's committed norm `r = T(i)`, in WAD.
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
    function ejectionsOf(address validator) external view returns (uint256) {
        return _ejections[validator];
    }

    /// @inheritdoc IAVIPValidatorManager
    function isAdmitted(address validator) external view returns (bool) {
        return _admitted[validator];
    }

    /// @inheritdoc IAVIPValidatorManager
    function collateralOf(address validator) external view returns (uint256) {
        if (!_admitted[validator]) return 0;
        // The norm's credit is `Theta - S_f*(r)`, and `_requiredStakes` holds
        // `S_f*(r) + surcharge` (§12.1.2, M9c). While a validator is admitted its
        // ejection count cannot have moved since its admission — an ejection
        // revokes the admission in the same call — so `_ejections * κ` *is* the
        // surcharge that was added, and subtracting it recovers the image: the
        // credit stays a function of the certified norm alone, with no second copy
        // of it stored (§5.2.4).
        uint256 image = _requiredStakes[validator] - _ejections[validator] * EJECTION_SURCHARGE;
        return THETA - image;
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
        // purpose, so the admissible domain starts at `T(i) = Theta_r` and
        // `T = 0` is no longer an admissible type (§5.2.3).
        if (certifiedNorm < THETA_R) revert NormBelowThreshold(certifiedNorm, THETA_R);

        uint256 collateral = collateralFor(certifiedNorm);
        // The requirement is the norm's image *plus* what this validator's history
        // costs (§12.1.2, M9c). The surcharge is a separate term on purpose:
        // inflating `requiredStakeFor` would make `Theta - requiredStake` — the
        // collateral the norm earns — shrink with every ejection, and go negative
        // for a serial ejectee.
        uint256 surcharge = _ejections[validator] * EJECTION_SURCHARGE;
        uint256 stake = requiredStakeFor(certifiedNorm) + surcharge;
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

        // The registry reads `statementRootOf(epoch)` itself and builds
        // `[root, epoch, uint160(validator), certifiedNorm]`, so a proof for
        // another epoch, another validator, another root or another norm cannot
        // pass (§5.2.1, M4d). The latest epoch keeps the admission bound to the
        // freshest tensor; with no commitment posted `latestEpoch()` is
        // `type(uint256).max` and the registry reverts with `UnknownEpoch`.
        uint256 epoch = registry.latestEpoch();
        if (!registry.verifyThreshold(epoch, validator, certifiedNorm, proof)) {
            revert IAVIPRegistry.InvalidZKProof();
        }

        _admitted[validator] = true;
        _stakes[validator] = financialStake;
        _requiredStakes[validator] = stake;

        emit AdmissionEvaluated(validator, epoch, certifiedNorm, collateral, stake, surcharge);
        emit ValidatorAdmitted(validator, financialStake, collateral);
    }

    // -------------------------------------------------------------- slashing

    /// @inheritdoc IAVIPValidatorManager
    function slash(address validator, bytes32 reason) external {
        if (msg.sender != slashAuthority) revert NotSlashAuthority(msg.sender);

        // The amount is the record itself (§12.1.2, M9b). There is no argument
        // to bound, so the bound M2 needed cannot be violated: nothing here can
        // exceed `_stakes[validator]`. An absent record has nothing to take.
        uint256 available = _stakes[validator];
        if (available == 0) revert NothingToSlash(validator);

        uint256 amount = available;
        _stakes[validator] = 0;

        emit ValidatorSlashed(validator, amount, reason);

        // `isAdmitted` must keep implying `stakeOf >= requiredStake`, and a zero
        // record satisfies that for no admitted validator: `requiredStakeFor` is
        // at least `S_MIN > 0` for every admitted norm (§5.2.3). So taking the
        // whole record always ejects, and the ejection reports the record it
        // leaves behind — the state the admission rule is now false in.
        if (_admitted[validator] && _stakes[validator] < _requiredStakes[validator]) {
            _admitted[validator] = false;
            // The count is the record the *next* admission is priced from
            // (§12.1.2, M9c), so it is written with the ejection and never reset.
            _ejections[validator] += 1;
            emit ValidatorEjected(validator, _stakes[validator], _requiredStakes[validator]);
        }

        // Funds last, and only now: every write on this side has already
        // happened, so the custody contract is the last thing to act and a
        // revert in it (a failing token, a refusing sink) rolls this whole call
        // back — record and escrow move together or not at all (§5.12). The
        // amount here is never zero: the guard above refuses an empty record, so
        // custody always has something to move.
        if (address(custody) != address(0)) {
            custody.debit(validator, amount, reason);
        }
    }
}
