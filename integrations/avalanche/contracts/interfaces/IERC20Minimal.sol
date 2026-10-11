// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IERC20Minimal
/// @notice The subset of ERC-20 that M8's custody uses: three functions, no
///         events, no metadata.
///
/// @dev Milestone M8 of `docs/architecture/implementation-plan.md` §5.12.
///      Deliberately *not* OpenZeppelin's `IERC20`: this repository vendors no
///      dependency but `forge-std` (§8 of the plan), and a custody contract has
///      to decide for itself what it does with a token that does not behave.
///      `AVIPStakeVault` therefore never trusts the returned boolean and never
///      calls `decimals()`, `name()` or `symbol()` — a token that omits them is
///      still a token there, because the deployment states its scale instead
///      (`WAD_PER_UNIT`).
///
///      The three functions are the three the vault needs: read a balance (to
///      measure what actually moved), pull from a validator, push to the sink.
interface IERC20Minimal {
    /// @notice Token base units held by `account`.
    function balanceOf(address account) external view returns (uint256);

    /// @notice Moves `amount` base units from the caller to `to`.
    /// @return Some tokens return `true`, some return nothing (USDT-style),
    ///         some return `false` instead of reverting. Callers of this
    ///         interface must handle all three.
    function transfer(address to, uint256 amount) external returns (bool);

    /// @notice Moves `amount` base units from `from` to `to`, against an
    ///         allowance the caller must have been granted.
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
