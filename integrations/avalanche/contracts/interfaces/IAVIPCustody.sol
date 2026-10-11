// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IAVIPCustody
/// @notice What the validator manager is allowed to know about the custody of
///         the stake it declares: how much is escrowed for a validator, and how
///         to move an amount out when it decides a slash.
///
/// @dev Milestone M8 of `docs/architecture/implementation-plan.md` §5.12.
///
///      **The direction is the design.** The manager owns the admission rule and
///      the decision to slash; the custody contract owns the funds. The only
///      thing that crosses the boundary is this interface — one read
///      (`escrowed`) and one write (`debit`) that the manager performs itself,
///      inside the same transaction as its own accounting. There is no callback
///      into the manager, so custody can never re-enter admission or slashing,
///      and a slash cannot half-happen: if `debit` reverts, the manager's stake
///      update and its ejection revert with it. That is what makes the two
///      numbers (`stakeOf` and `escrowed`) impossible to desynchronise.
///
///      **`address(0)` implements none of this.** A manager deployed with no
///      custody is the M2 manager: `financialStake` is declared and not backed,
///      and every rule of §5.2.3 stands unchanged. A manager deployed with a
///      custody address is the amended M2 of §5.12, where the declaration must be
///      covered by real escrow. The two behaviours are one constructor argument
///      apart, and both are tested.
///
///      **Units.** `escrowed` is WAD, the same unit as
///      `IAVIPValidatorManager.stakeOf`, so no comparison ever mixes units. The
///      custody contract converts from the token's own base units at its
///      boundary, with the scale it was constructed with.
///
///      **The handshake.** The two contracts point at each other — custody
///      authorises `debit` by its manager, the manager reads and debits its
///      custody — so neither address can be a constructor fact of the other.
///      The custody is deployed first and the manager's constructor fills the one
///      hole: it calls `bindManager()` (once) and then checks `manager()`. A
///      manager whose custody already points somewhere else reverts at deployment
///      rather than producing a pair that is wired to nothing.
interface IAVIPCustody {
    /// @notice Stake escrowed for `validator`, in WAD (`0` if none).
    /// @dev An admitted validator must satisfy
    ///      `escrowed(validator) >= stakeOf(validator)`; the amended manager
    ///      checks the declaration against this value and the invariant is kept
    ///      by `debit` moving exactly what the manager asks it to move (rounded
    ///      down, so escrow can only ever be short of the request by a fraction
    ///      of one token base unit, never short of the manager's own record).
    function escrowed(address validator) external view returns (uint256);

    /// @notice The manager this custody moved from, or `address(0)` while the
    ///         handshake has not happened.
    function manager() external view returns (address);

    /// @notice Binds the caller as this custody's manager. Called by the
    ///         manager's constructor and therefore successful at most once ever.
    /// @dev A custody that is already bound reverts, which is what makes the
    ///      manager's constructor fail loudly instead of deploying a manager that
    ///      no vault will obey.
    function bindManager() external;

    /// @notice Moves `amount` WAD of `validator`'s escrow out of custody.
    /// @dev Called by the validator manager only, after it has already reduced
    ///      its `stakeOf` record, so the amount is bounded by that record and
    ///      never by a caller's ambition. The implementation transfers to its
    ///      configured sink and tells it `reason`; a revert propagates, rolling
    ///      the manager's accounting back with it.
    /// @param validator The validator whose escrow is debited.
    /// @param amount WAD to move out; must not exceed `escrowed(validator)`.
    /// @param reason Why, for the sink's record: the slash's provenance id.
    function debit(address validator, uint256 amount, bytes32 reason) external;
}
