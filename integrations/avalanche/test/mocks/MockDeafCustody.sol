// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAVIPCustody} from "../../contracts/interfaces/IAVIPCustody.sol";

/// @title MockDeafCustody
/// @notice A custody that accepts the handshake and then reports that it bound
///         nobody: the single case `IAVIPValidatorManager.CustodyNotBound` is
///         there to catch.
///
/// @dev Milestone M8 of `docs/architecture/implementation-plan.md` §5.12. A
///      manager's constructor calls `bindManager()` and *then reads `manager()`
///      back*, because a call that returns is not the same as a vault that
///      obeyed. This double returns from `bindManager()` without recording
///      anything, so a manager deployed against it must revert rather than exist
///      believing it has custody. It is the cheapest way to prove that the
///      verification half of the handshake is load-bearing.
contract MockDeafCustody is IAVIPCustody {
    /// @notice How many times the handshake was attempted.
    uint256 public binds;

    /// @inheritdoc IAVIPCustody
    function escrowed(address) external pure returns (uint256) {
        return 0;
    }

    /// @inheritdoc IAVIPCustody
    function manager() external pure returns (address) {
        return address(0);
    }

    /// @inheritdoc IAVIPCustody
    function bindManager() external {
        binds += 1;
    }

    /// @inheritdoc IAVIPCustody
    function debit(address, uint256, bytes32) external {}
}
