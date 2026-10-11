// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20Minimal} from "./interfaces/IERC20Minimal.sol";
import {IERC20BurnableMinimal} from "./interfaces/IERC20BurnableMinimal.sol";
import {IFundSink} from "./interfaces/IFundSink.sol";

/// @title AVIPBurnSink
/// @notice The reference `IFundSink`: it destroys what it receives.
///
/// @dev Milestone M8 of `docs/architecture/implementation-plan.md` §5.12.
///
///      This contract is the smallest possible answer to the question M8 refuses
///      to decide globally: slashed stake and the `F_0*` fee have to go
///      *somewhere*, and the protocol does not say where. Burning them needs no
///      actor the paper does not model — no treasury, no beneficiary, no
///      governance address, no key that can spend them later — which is why this
///      is the reference choice and not, say, a contract that accumulates a
///      balance somebody would eventually have to be given the right to move.
///      A deployment that wants to keep the funds implements `IFundSink` itself;
///      nothing in the vault changes.
///
///      **What it is not.** It is not a proof that the supply fell: it calls the
///      token's own `burn`, so the *token's* implementation decides what burning
///      means (a token may ignore the call, or have no `burn` at all, in which
///      case this sink reverts `BurnFailed` and the deployment must pick another
///      sink). No supply is measured here and none is asserted anywhere in the
///      milestone.
///
///      **It holds nothing between calls.** Every `receiveFunds` burns exactly
///      the amount that arrived from the vault, so after a normal flow this
///      contract's balance is what it was before. Tokens sent here by any other
///      route are not burned, not counted in `totalBurned` and not swept: this
///      contract has no way to interpret them and no function that moves tokens
///      out, deliberately.
contract AVIPBurnSink is IFundSink {
    /// @notice The token whose `burn` this sink calls. Constructor-fixed: there
    ///         is no setter, so the sink cannot be repointed at another token.
    IERC20Minimal internal immutable TOKEN;

    /// @notice Base units destroyed by this sink, accumulated over every call.
    uint256 public totalBurned;

    /// @notice Emitted for every burn, with the reason the vault passed on.
    /// @param amount Base units destroyed.
    /// @param reason The slash's provenance id, or the vault's fee tag.
    /// @param totalBurned Running total after this burn.
    event FundsBurned(uint256 amount, bytes32 reason, uint256 totalBurned);

    /// @notice The token address is zero.
    error ZeroToken();

    /// @notice `receiveFunds` was called with `amount == 0`.
    error ZeroAmount();

    /// @notice The sink does not hold `amount` base units, or the token refused
    ///         the `burn` (no such function, a `false` return, or a revert).
    error BurnFailed(uint256 amount);

    /// @param token_ The token to burn; must implement `burn(uint256)`.
    constructor(address token_) {
        if (token_ == address(0)) revert ZeroToken();
        TOKEN = IERC20Minimal(token_);
    }

    /// @inheritdoc IFundSink
    function receiveFunds(uint256 amount, bytes32 reason) external {
        if (amount == 0) revert ZeroAmount();
        if (TOKEN.balanceOf(address(this)) < amount) revert BurnFailed(amount);

        // Low-level call, lenient decode: `burn(uint256)` returns nothing in the
        // dominant convention and `bool` in some tokens, and a token without the
        // function fails the call instead of returning `false`. All three are
        // `BurnFailed`, which is the documented signal for "this token cannot be
        // used with this sink".
        (bool ok, bytes memory ret) =
            address(TOKEN).call(abi.encodeWithSelector(IERC20BurnableMinimal.burn.selector, amount));
        if (!ok || (ret.length != 0 && !abi.decode(ret, (bool)))) revert BurnFailed(amount);

        totalBurned += amount;
        emit FundsBurned(amount, reason, totalBurned);
    }
}
