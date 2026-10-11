// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IFundSink} from "../../contracts/interfaces/IFundSink.sol";

/// @title MockFundSink
/// @notice A sink that keeps what it receives and *records how it was told*,
///         instead of destroying it: the "a deployment that keeps the funds"
///         branch of §5.12, and the instrument the vault tests read the reason
///         and the transferred amount from.
///
/// @dev The knobs mirror `MockERC20`'s on purpose, because the sink sits on the
///      same external boundary:
///
///        - `refuse` — revert instead of accepting. Claim: a refusing sink
///          reverts the *whole* slash, record and escrow together (`AVIPStakeVault`
///          propagates it and the manager's constructor has already written
///          `stakeOf`);
///        - `reentryTarget`/`reentryData` — call back into the vault from inside
///          `receiveFunds`, i.e. *after* the vault has already written everything
///          it was going to write. Claim: the re-entry finds final state and can
///          only do what that state allows.
contract MockFundSink is IFundSink {
    /// @notice Base units ever received.
    uint256 public totalReceived;
    /// @notice How many times `receiveFunds` was called.
    uint256 public calls;
    /// @notice The reason of the most recent call.
    bytes32 public lastReason;
    /// @notice The amount of the most recent call.
    uint256 public lastAmount;

    /// @dev Revert every call instead of accepting.
    bool public refuse;
    /// @dev Reason of the `refuse` revert.
    string public refusalReason = "mock: sink refuses";

    address public reentryTarget;
    bytes public reentryData;
    uint256 public reentryAttempts;
    bool public lastReentrySucceeded;

    function setRefuse(bool value) external {
        refuse = value;
    }

    function setRefusalReason(string calldata value) external {
        refusalReason = value;
    }

    function setReentry(address target, bytes calldata data) external {
        reentryTarget = target;
        reentryData = data;
    }

    function resetReentry() external {
        reentryAttempts = 0;
        lastReentrySucceeded = false;
    }

    /// @inheritdoc IFundSink
    function receiveFunds(uint256 amount, bytes32 reason) external {
        if (refuse) revert(refusalReason);

        calls += 1;
        totalReceived += amount;
        lastAmount = amount;
        lastReason = reason;

        address target = reentryTarget;
        if (target != address(0)) {
            reentryAttempts += 1;
            (bool ok,) = target.call(reentryData);
            lastReentrySucceeded = ok;
        }
    }
}
