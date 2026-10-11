// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20Minimal} from "./interfaces/IERC20Minimal.sol";
import {IAVIPCustody} from "./interfaces/IAVIPCustody.sol";
import {IAVIPValidatorManager} from "./interfaces/IAVIPValidatorManager.sol";
import {IFundSink} from "./interfaces/IFundSink.sol";

/// @title AVIPStakeVault
/// @notice Custody of the `financialStake` that M2 used to only *declare*:
///         escrow, release, and the two movements that take funds out — a slash
///         and the `F_0*` fee.
///
/// @dev Milestone M8 of `docs/architecture/implementation-plan.md` §5.12. It is
///      the custody half of `§5.2.3`, where M2 states its own limit: it "does not
///      implement token custody or transfer (ERC-20 or native); that is delegated
///      to the M8 Treasury Module".
///
///      **Two owners of truth, and no third.** The manager owns the admission
///      rule, the decision to slash and the number `stakeOf`. This contract owns
///      the funds. The boundary is `IAVIPCustody`: the manager reads `escrowed`
///      when it admits and calls `debit` when it slashes, *inside its own
///      transaction*, so with custody configured the invariant
///
///        `isAdmitted(v)  =>  escrowed(v) >= stakeOf(v)`
///
///      holds by construction rather than by reconciliation — there is no window
///      in which one moved and the other did not, because a revert anywhere rolls
///      back both. `isBacked` exposes exactly that predicate.
///
///      **The one hole, and who fills it.** This contract is deployed *before*
///      the manager, because the manager needs its address. So the manager
///      address is not a constructor fact here: it starts empty and
///      `bindManager` fills it exactly once, called by the manager's own
///      constructor, which then checks `manager() == address(this)` and reverts
///      otherwise. Until that happens the vault is a plain escrow — anyone can
///      deposit and withdraw, nobody can be charged a fee and nobody can be
///      debited — which is also the state a vault left unbound stays in.
///
///      **Where the funds go is not decided here.** A slash and the fee are
///      pushed to a constructor-fixed `IFundSink`; the reference sink in this
///      repository burns them. The protocol says a slash happens and that `F_0`
///      is a participation fee; it does not say whether the tokens are destroyed
///      or kept, and it names no recipient. M8 refuses to invent that actor, so
///      the destination is a deployment fact (§5.12, decision `D-M8-0`).
///
///      **Units.** Escrow is accounted in the token's own base units and is
///      *reported* in WAD (`escrowed`), so every comparison against
///      `stakeOf`/`requiredStake` is unit-clean. `WAD_PER_UNIT` is
///      `10 ** (18 - decimals)`, e.g. `1e12` for a 6-decimal token; the
///      deployment states it, because reading `decimals()` would put a
///      non-standard call on the custody path. Two boundaries follow from it and
///      are stated rather than hidden: `debit` floors (`floor(amount / unit)`),
///      so a slash smaller than one base unit moves nothing and leaves the
///      difference as withdrawable surplus; `withdrawable` ceils the stake on
///      record, so at most one base unit beyond the exact `stakeOf` stays locked,
///      and it is released when the validator stops being admitted. With
///      `WAD_PER_UNIT = 1` neither boundary exists.
///
///      **Which tokens it accepts.** No boolean is trusted: a USDT-style token
///      that returns nothing and a token that returns `false` instead of
///      reverting are both handled by `_call`. Every movement is checked against
///      the recipient's measured balance delta, so a **fee-on-transfer**,
///      rebasing or otherwise inexact token reverts `InexactTransfer` instead of
///      quietly breaking the accounting. That is a deliberate refusal, not an
///      oversight: this contract's conservation identity is exact.
///
///      **Reentrancy.** Every state write happens before the first external call
///      (checks-effects-interactions), and every path out is bounded by state
///      that was already written: a token or a sink that re-enters during
///      `transfer`/`transferFrom` finds the escrow already debited or already
///      capped, so it can only ever spend what the validator had before the call.
///      No guard is added on top, and the suite tests the attempted re-entry
///      rather than trusting the argument.
///
///      **What this contract does NOT do.** It does not admit anyone or decide a
///      slash (the manager does both); it does not hold a second token, take a
///      management fee, pay interest or rewards, or keep a per-epoch fee ledger
///      (`payFee` charges the caller, who is the only address that can be
///      charged, so the per-epoch rule of the paper is a caller policy);
///      it has no owner, no setter, no pause and no upgrade path; and tokens sent
///      to it by any route other than `deposit` are not attributable to any
///      validator and no function here can move them.
contract AVIPStakeVault is IAVIPCustody {
    /// @notice WAD unit (1.0), the unit of every policy number in the protocol.
    uint256 public constant ONE = 1e18;

    /// @notice The escrowed token. Constructor-fixed; there is no setter.
    IERC20Minimal public immutable TOKEN;

    /// @notice The manager this vault obeys, or `address(0)` while the handshake
    ///         has not happened. Mutable by necessity and bound exactly once
    ///         (see `bindManager`); the public getter is
    ///         `IAVIPCustody.manager()`.
    IAVIPValidatorManager private _manager;

    /// @notice Where a slash and the fee are pushed. Constructor-fixed.
    IFundSink public immutable SINK;

    /// @notice WAD units per token base unit: `10 ** (18 - decimals)`.
    uint256 public immutable WAD_PER_UNIT;

    /// @notice Reason tag this contract passes to the sink for the fee. Derived
    ///         from a constant, so an auditor recomputes it and no caller
    ///         chooses it (`IFundSink`).
    bytes32 public constant FEE_REASON = keccak256("AVIP:F0_STAR");

    /// @notice Escrow per validator, in token base units.
    mapping(address => uint256) private _escrowedUnits;

    /// @notice Aggregate of the map above, in base units. The only aggregate
    ///         this contract stores — a sum over a map cannot be derived — and
    ///         every path that moves escrow updates it in the same statement,
    ///         which is what the suite checks it against.
    uint256 public totalEscrowedUnits;

    /// @notice Base units ever credited by `deposit`.
    uint256 public totalDeposited;

    /// @notice Base units ever returned to validators by `withdraw`.
    uint256 public totalReleased;

    /// @notice Base units ever moved out of escrow to the sink by `debit`.
    uint256 public totalDebited;

    /// @notice Base units paid straight to the sink by `payFee`. Not part of
    ///         `totalDebited`: a fee never becomes this contract's balance.
    uint256 public totalFeesPaid;

    /// @notice Emitted when a validator escrows tokens.
    /// @param validator The depositor, credited with exactly what arrived.
    /// @param units Base units credited.
    event Deposited(address indexed validator, uint256 units);

    /// @notice Emitted when a validator takes escrow back.
    /// @param validator The withdrawer.
    /// @param units Base units returned.
    event Withdrawn(address indexed validator, uint256 units);

    /// @notice Emitted when the manager takes escrow out of custody.
    /// @param validator The slashed validator.
    /// @param amountWad What the manager asked for, in WAD.
    /// @param units What actually left custody, in base units (never more than
    ///        `amountWad / WAD_PER_UNIT`).
    /// @param reason The manager's provenance id for the slash.
    event StakeDebited(address indexed validator, uint256 amountWad, uint256 units, bytes32 reason);

    /// @notice Emitted when a validator pays the participation fee.
    /// @param validator The payer, which is `msg.sender` and therefore the only
    ///        address that can be charged.
    /// @param feeWad `F_0*` as the manager declares it, in WAD.
    /// @param units Base units that arrived at the sink.
    event FeePaid(address indexed validator, uint256 feeWad, uint256 units);

    /// @notice Emitted once, when the manager binds itself to this vault.
    /// @param manager The manager address the vault will obey.
    event ManagerBound(address indexed manager);

    /// @notice A constructor argument is the zero address.
    error ZeroToken(address token);
    error ZeroSink(address sink);

    /// @notice `bindManager` was called on a vault that already has a manager.
    error ManagerAlreadyBound(address manager);

    /// @notice A manager-only door was used while no manager is bound.
    error ManagerNotBound();

    /// @notice `wadPerUnit` is zero, or does not divide `1e18` (which is also how
    ///         a token with more than 18 decimals is refused): the wrong scale
    ///         would silently mis-price every comparison against `stakeOf`.
    error InvalidWadPerUnit(uint256 wadPerUnit);

    /// @notice `debit` was called by an address other than the manager.
    error NotManager(address caller);

    /// @notice An amount of zero was requested.
    error ZeroAmount();

    /// @notice `debit` asks for more than `validator` has escrowed here.
    error InsufficientEscrow(address validator, uint256 requestedUnits, uint256 availableUnits);

    /// @notice The withdrawal exceeds what is not standing behind `stakeOf`.
    error StakeLocked(address validator, uint256 requestedUnits, uint256 withdrawableUnits);

    /// @notice `payFee` was called by a validator the manager does not admit,
    ///         i.e. somebody who is not taking part in this epoch's set.
    error NotAdmitted(address validator);

    /// @notice `F_0*` is smaller than one base unit of this token, so the
    ///         participation fee cannot be charged exactly. A deployment whose
    ///         token is that coarse needs another token or another scale.
    error FeeRoundsToZero(uint256 feeWad, uint256 wadPerUnit);

    /// @notice The token reported success, yet the recipient's balance moved by
    ///         `received != requested`: a fee-on-transfer or rebasing token.
    error InexactTransfer(uint256 requested, uint256 received);

    /// @notice The token call reverted with no data.
    error TokenCallFailed(bytes4 selector);

    /// @notice The token returned `false` instead of reverting.
    error TokenReturnedFalse(bytes4 selector);

    /// @param token_ The escrowed token.
    /// @param sink_ Where slashed stake and the fee go.
    /// @param wadPerUnit_ `10 ** (18 - decimals)` of `token_`.
    constructor(address token_, address sink_, uint256 wadPerUnit_) {
        if (token_ == address(0)) revert ZeroToken(token_);
        if (sink_ == address(0)) revert ZeroSink(sink_);
        if (wadPerUnit_ == 0 || ONE % wadPerUnit_ != 0) revert InvalidWadPerUnit(wadPerUnit_);
        TOKEN = IERC20Minimal(token_);
        SINK = IFundSink(sink_);
        WAD_PER_UNIT = wadPerUnit_;
    }

    // ------------------------------------------------------------- the manager

    /// @inheritdoc IAVIPCustody
    /// @dev One-shot by construction: the second call ever reverts. It is
    ///      called by the manager's constructor, which then verifies
    ///      `manager() == address(this)`, so a vault bound to the wrong manager
    ///      makes that deployment fail instead of existing quietly. A vault left
    ///      unbound is a working escrow in which `withdrawable` is the whole
    ///      balance, `payFee` reverts `ManagerNotBound` and no address is the
    ///      manager — i.e. nothing here is a trapdoor for a stranger, only a
    ///      missing link.
    function bindManager() external {
        address bound = address(_manager);
        if (bound != address(0)) revert ManagerAlreadyBound(bound);
        _manager = IAVIPValidatorManager(msg.sender);
        emit ManagerBound(msg.sender);
    }

    // ------------------------------------------------------------------- views

    /// @inheritdoc IAVIPCustody
    function escrowed(address validator) public view returns (uint256) {
        return _escrowedUnits[validator] * WAD_PER_UNIT;
    }

    /// @notice Escrow of `validator` in the token's own base units.
    function escrowedUnits(address validator) public view returns (uint256) {
        return _escrowedUnits[validator];
    }

    /// @inheritdoc IAVIPCustody
    /// @dev The manager this vault obeys, or `address(0)` while the handshake has
    ///      not happened. Typed as an address in the interface so that the custody
    ///      boundary does not depend on the manager's own interface.
    function manager() external view returns (address) {
        return address(_manager);
    }

    /// @notice True iff the manager's record for `validator` is covered by escrow
    ///         here — the milestone's invariant as a view. It holds for every
    ///         validator that ever deposited, admitted or not. While no manager is
    ///         bound there is no record to cover, so it is trivially true.
    function isBacked(address validator) external view returns (bool) {
        IAVIPValidatorManager m = _manager;
        if (address(m) == address(0)) return true;
        return escrowed(validator) >= m.stakeOf(validator);
    }

    /// @notice Base units of `validator`'s escrow not standing behind the stake on
    ///         record: everything, if the manager does not admit it (never
    ///         admitted, or ejected by a slash, or no manager bound yet);
    ///         otherwise the escrow above `ceil(stakeOf / WAD_PER_UNIT)`.
    function withdrawable(address validator) public view returns (uint256) {
        uint256 units = _escrowedUnits[validator];
        IAVIPValidatorManager m = _manager;
        if (address(m) == address(0)) return units;
        if (!m.isAdmitted(validator)) return units;
        uint256 locked = _ceilUnits(m.stakeOf(validator));
        return units > locked ? units - locked : 0;
    }

    /// @notice What `payFee` charges, in base units: `F_0* / WAD_PER_UNIT`, read
    ///         from the manager so the policy has one source of truth. Zero while
    ///         no manager is bound, because there is no `F_0*` to read.
    function feeInUnits() public view returns (uint256) {
        IAVIPValidatorManager m = _manager;
        if (address(m) == address(0)) return 0;
        return m.F0_STAR() / WAD_PER_UNIT;
    }

    /// @notice Token base units this contract is holding.
    function heldUnits() public view returns (uint256) {
        return TOKEN.balanceOf(address(this));
    }

    // ------------------------------------------------------------------ escrow

    /// @notice Escrows `units` of the token for the caller.
    /// @dev The caller must have approved this contract for `units`. The credit
    ///      is the balance delta measured at this contract and it must equal
    ///      `units` exactly (`InexactTransfer` otherwise), so a validator is
    ///      credited with what it actually delivered.
    /// @param units Base units to escrow.
    /// @return credited Base units credited to the caller.
    function deposit(uint256 units) external returns (uint256 credited) {
        if (units == 0) revert ZeroAmount();

        credited = _pullTo(address(this), msg.sender, units);

        _escrowedUnits[msg.sender] += credited;
        totalEscrowedUnits += credited;
        totalDeposited += credited;

        emit Deposited(msg.sender, credited);
    }

    /// @notice Returns `units` of the caller's own escrow.
    /// @dev Capped by `withdrawable(msg.sender)`: an admitted validator can never
    ///      withdraw the stake the manager has on record, so custody and `stakeOf`
    ///      cannot be pulled apart from this side either. No cooldown and no exit
    ///      queue: leaving the set is the manager's business, and M8 adds no exit
    ///      path of its own.
    /// @param units Base units to return.
    function withdraw(uint256 units) external {
        if (units == 0) revert ZeroAmount();

        uint256 free = withdrawable(msg.sender);
        if (units > free) revert StakeLocked(msg.sender, units, free);

        _escrowedUnits[msg.sender] -= units;
        totalEscrowedUnits -= units;
        totalReleased += units;

        emit Withdrawn(msg.sender, units);

        _transferOut(msg.sender, units);
    }

    // ------------------------------------------------------------- the manager

    /// @inheritdoc IAVIPCustody
    /// @dev Manager-only, and deliberately the *last* step of a slash: the
    ///      manager has already reduced `stakeOf` when it calls this, so the
    ///      request can never exceed what its own record allows, and a revert
    ///      here (a failing token, a refusing sink) rolls that reduction back.
    function debit(address validator, uint256 amount, bytes32 reason) external {
        if (msg.sender != address(_manager)) revert NotManager(msg.sender);

        uint256 units = _floorUnits(amount);
        uint256 available = _escrowedUnits[validator];
        if (units > available) revert InsufficientEscrow(validator, units, available);
        // A slash smaller than one base unit moves no funds. The manager's own
        // record still drops, so the difference stays behind as withdrawable
        // surplus: the rounding boundary of the contract header, chosen on the
        // side that keeps `escrowed >= stakeOf` true.
        if (units == 0) return;

        _escrowedUnits[validator] = available - units;
        totalEscrowedUnits -= units;
        totalDebited += units;

        emit StakeDebited(validator, amount, units, reason);

        uint256 arrived = _transferOut(address(SINK), units);
        SINK.receiveFunds(arrived, reason);
    }

    // --------------------------------------------------------------- the fee

    /// @notice Charges the caller the participation fee `F_0*` of the epoch.
    /// @dev The fee goes from the payer straight to the sink: it is not escrow,
    ///      it never becomes this contract's balance, and only `msg.sender` can be
    ///      charged, so no third party can charge a validator. There is no
    ///      per-epoch ledger here — charging once per epoch is the caller's
    ///      policy, and this contract makes no claim about it.
    /// @return units Base units charged.
    function payFee() external returns (uint256 units) {
        IAVIPValidatorManager m = _manager;
        if (address(m) == address(0)) revert ManagerNotBound();
        if (!m.isAdmitted(msg.sender)) revert NotAdmitted(msg.sender);

        units = m.F0_STAR() / WAD_PER_UNIT;
        if (units == 0) revert FeeRoundsToZero(m.F0_STAR(), WAD_PER_UNIT);

        uint256 arrived = _pullTo(address(SINK), msg.sender, units);
        totalFeesPaid += arrived;

        emit FeePaid(msg.sender, m.F0_STAR(), arrived);

        SINK.receiveFunds(arrived, FEE_REASON);
    }

    // ------------------------------------------------------------- the token

    /// @dev Pulls `amount` from `from` to `to` with `transferFrom`, measuring the
    ///      recipient's delta. `to` is a parameter because the same hop serves a
    ///      deposit (into this contract) and the fee (payer to sink).
    function _pullTo(address to, address from, uint256 amount) internal returns (uint256 received) {
        uint256 before = TOKEN.balanceOf(to);
        _call(
            address(TOKEN),
            abi.encodeWithSelector(IERC20Minimal.transferFrom.selector, from, to, amount)
        );
        received = TOKEN.balanceOf(to) - before;
        if (received != amount) revert InexactTransfer(amount, received);
    }

    /// @dev Pushes `amount` to `to` with `transfer`, measuring `to`'s delta.
    function _transferOut(address to, uint256 amount) internal returns (uint256 received) {
        uint256 before = TOKEN.balanceOf(to);
        _call(address(TOKEN), abi.encodeWithSelector(IERC20Minimal.transfer.selector, to, amount));
        received = TOKEN.balanceOf(to) - before;
        if (received != amount) revert InexactTransfer(amount, received);
    }

    /// @dev Calls a token and refuses to guess what it answered: success with no
    ///      return data is accepted (USDT-style), a `false` return is not, and a
    ///      revert is bubbled up unchanged so the token's own reason survives.
    function _call(address token, bytes memory data) internal {
        (bool ok, bytes memory ret) = token.call(data);
        if (!ok) {
            if (ret.length == 0) {
                // casting to 'bytes4' is safe because `data` is calldata this
                // contract built with `abi.encodeWithSelector`, so its first four
                // bytes *are* the selector of the call that failed.
                // forge-lint: disable-next-line(unsafe-typecast)
                revert TokenCallFailed(bytes4(data));
            }
            assembly ("memory-safe") {
                revert(add(ret, 0x20), mload(ret))
            }
        }
        if (ret.length != 0 && !abi.decode(ret, (bool))) {
            // casting to 'bytes4' is safe for the same reason as above.
            // forge-lint: disable-next-line(unsafe-typecast)
            revert TokenReturnedFalse(bytes4(data));
        }
    }

    /// @dev WAD -> base units, rounding down.
    function _floorUnits(uint256 amountWad) internal view returns (uint256) {
        return amountWad / WAD_PER_UNIT;
    }

    /// @dev WAD -> base units, rounding up. Used only to *lock*: rounding up is
    ///      what stops a validator from withdrawing the stake on record.
    function _ceilUnits(uint256 amountWad) internal view returns (uint256) {
        return (amountWad + WAD_PER_UNIT - 1) / WAD_PER_UNIT;
    }
}
