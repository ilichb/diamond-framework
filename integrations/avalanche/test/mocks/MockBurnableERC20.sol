// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MockERC20} from "./MockERC20.sol";

/// @title MockBurnableERC20
/// @notice `MockERC20` plus the `burn(uint256)` the reference sink calls.
///
/// @dev Milestone M8 of `docs/architecture/implementation-plan.md` §5.12. The
///      bare `MockERC20` — which has no `burn` — is what a deployment whose token
///      cannot be burned looks like to `AVIPBurnSink`; this one is the token that
///      works with it. `burnReturnsFalse` covers the third case: a `burn` that
///      answers `false` instead of reverting, after doing nothing.
contract MockBurnableERC20 is MockERC20 {
    /// @dev When true, `burn` returns `false` and destroys nothing.
    bool public burnReturnsFalse;

    /// @dev Base units destroyed through `burn`.
    uint256 public totalBurned;

    constructor(string memory name_, uint8 decimals_) MockERC20(name_, decimals_) {}

    function setBurnReturnsFalse(bool value) external {
        burnReturnsFalse = value;
    }

    /// @notice Destroys `amount` base units of the caller's own balance.
    function burn(uint256 amount) external returns (bool) {
        if (burnReturnsFalse) return false;
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        totalBurned += amount;
        return true;
    }
}
