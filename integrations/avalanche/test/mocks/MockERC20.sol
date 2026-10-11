// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20Minimal} from "../../contracts/interfaces/IERC20Minimal.sol";

/// @title MockERC20
/// @notice The token double M8 needs: one ERC-20 whose *behaviour* is a knob, so
///         that every token quirk the vault claims to handle (or refuse) is
///         exercised against the same accounting.
///
/// @dev Milestone M8 of `docs/architecture/implementation-plan.md` §5.12. The
///      knobs, and the vault claim each one tests:
///
///        - `returnsNothing` — USDT-style: the movement happens and the call
///          returns **no data at all** (`return(0, 0)` in assembly, which is what
///          a real no-return token does; a `bool`-returning function cannot
///          emulate it). Claim: `AVIPStakeVault._call` accepts it;
///        - `returnsFalse` — the movement happens and the call returns `false`.
///          Claim: the vault trusts no boolean, so a `false` is a failure and the
///          whole call reverts (`TokenReturnedFalse`), leaving no accounting
///          behind;
///        - `blocked` — every movement reverts *with a reason string*.
///          Claim: the vault bubbles the token's own reason unchanged, and a
///          failing token mid-slash rolls the manager's record back with it;
///        - `feeBps` — a fee-on-transfer token: the recipient receives less than
///          the amount sent. Claim: `InexactTransfer`, never a silent gap between
///          escrow and custody;
///        - `reentryTarget`/`reentryData` — the token calls back into the vault
///          in the middle of a movement (after its own balances moved, i.e. the
///          ERC-777-like hook position). Claim: checks-effects-interactions makes
///          the re-entry land on already-written state; the mock records whether
///          the attempt succeeded (`lastReentrySucceeded`) so the test asserts on
///          the *attempt*, not on an argument in a comment.
///
///      `mint` is unrestricted and `allowance` is a plain ERC-20 one: this is a
///      test double, and nothing here is deployed.
contract MockERC20 is IERC20Minimal {
    /// @notice Basis points denominator used by `feeBps`.
    uint256 internal constant BPS = 10_000;

    string public name;
    // ERC-20 metadata keeps its conventional name here on purpose: the double is
    // read by tests that are emulating a real token, and `decimals` is the name
    // every reader of a token expects.
    // forge-lint: disable-next-line(screaming-snake-case-immutable)
    uint8 public immutable decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    /// @dev Return no data from `transfer`/`transferFrom` (USDT-style).
    bool public returnsNothing;
    /// @dev Return `false` from `transfer`/`transferFrom`, after moving.
    bool public returnsFalse;
    /// @dev Revert every movement with `blockedReason`.
    bool public blocked;
    /// @dev Revert every movement with no data at all, like an old token that
    ///      bails out in assembly. Only meaningful while `blocked` is set.
    bool public blockSilently;
    /// @dev Human-readable reason of the `blocked` revert.
    string public blockedReason = "mock: token blocked";
    /// @dev Fee kept (burned) per movement, in basis points.
    uint256 public feeBps;

    /// @dev Re-entry: called during every movement, after the balances moved.
    address public reentryTarget;
    bytes public reentryData;
    /// @dev How many re-entry attempts happened.
    uint256 public reentryAttempts;
    /// @dev Whether the most recent re-entry attempt returned successfully.
    bool public lastReentrySucceeded;

    constructor(string memory name_, uint8 decimals_) {
        name = name_;
        decimals = decimals_;
    }

    // -------------------------------------------------------------- the knobs

    function setReturnsNothing(bool value) external {
        returnsNothing = value;
    }

    function setReturnsFalse(bool value) external {
        returnsFalse = value;
    }

    function setBlocked(bool value) external {
        blocked = value;
    }

    function setBlockSilently(bool value) external {
        blockSilently = value;
    }

    function setBlockedReason(string calldata value) external {
        blockedReason = value;
    }

    function setFeeBps(uint256 value) external {
        feeBps = value;
    }

    function setReentry(address target, bytes calldata data) external {
        reentryTarget = target;
        reentryData = data;
    }

    /// @notice Clears the re-entry recording so a test reads one attempt.
    function resetReentry() external {
        reentryAttempts = 0;
        lastReentrySucceeded = false;
    }

    // --------------------------------------------------------------- the token

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        bool moved = _move(msg.sender, to, amount);
        if (returnsNothing) {
            assembly ("memory-safe") {
                return(0, 0)
            }
        }
        return moved;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;
        bool moved = _move(from, to, amount);
        if (returnsNothing) {
            assembly ("memory-safe") {
                return(0, 0)
            }
        }
        return moved;
    }

    // ------------------------------------------------------------- the movement

    /// @dev Moves `amount` from `from` to `to`, minus the fee, which is burned.
    function _move(address from, address to, uint256 amount) internal returns (bool) {
        if (blocked) {
            if (blockSilently) {
                assembly ("memory-safe") {
                    revert(0, 0)
                }
            }
            revert(blockedReason);
        }

        uint256 fee = amount * feeBps / BPS;
        balanceOf[from] -= amount;
        balanceOf[to] += amount - fee;
        if (fee != 0) totalSupply -= fee;

        _reenter();

        // `returnsFalse` reports failure *after* the movement, which is the
        // harshest shape for a caller that trusts the boolean: the funds moved
        // and the token still said no. The vault must revert the whole call.
        return !returnsFalse;
    }

    /// @dev Calls the configured target with the configured calldata and records
    ///      what happened, so a test can assert on the re-entry attempt itself.
    function _reenter() internal {
        address target = reentryTarget;
        if (target == address(0)) return;
        reentryAttempts += 1;
        (bool ok,) = target.call(reentryData);
        lastReentrySucceeded = ok;
    }
}
