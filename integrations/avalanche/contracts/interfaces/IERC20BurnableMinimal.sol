// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IERC20BurnableMinimal
/// @notice The one function the reference sink needs beyond `IERC20Minimal`:
///         `burn`, which destroys tokens from the caller's own balance.
///
/// @dev Milestone M8 of `docs/architecture/implementation-plan.md` §5.12. The
///      declaration returns nothing because that is the dominant convention
///      (OZ's `ERC20Burnable` returns nothing); `AVIPBurnSink` nevertheless calls
///      it through a low-level call and tolerates a `bool` return too, for the
///      same reason `AVIPStakeVault` does not trust `transfer`'s boolean.
///
///      A token without `burn` cannot be used with that sink: the sink documents
///      the revert and the deployment picks another `IFundSink` (§5.12). The
///      interface exists so that the requirement is written down in one place
///      rather than discovered by a failing deployment.
interface IERC20BurnableMinimal {
    /// @notice Destroys `amount` base units from `msg.sender`'s balance.
    function burn(uint256 amount) external;
}
