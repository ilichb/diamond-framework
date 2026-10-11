// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IFundSink
/// @notice Where funds go when they leave custody: the slashed stake and the
///         collected `F_0*`.
///
/// @dev Milestone M8 of `docs/architecture/implementation-plan.md` §5.12.
///
///      **This interface is an undecided fact made explicit.** The paper says a
///      slash *happens* (`S_slash = 10`, Data Layer) and that `F_0` is "a fee
///      charged for participation" (`main.tex` §6) — and it says nothing about
///      whether the slashed tokens are destroyed or kept, and it names no
///      recipient for the fee. Neither does M2, which declares the policy and
///      moves nothing (§5.2.3). M8 therefore does not decide it either: the
///      vault transfers to a sink it was constructed with, and what the sink
///      does with the funds is a deployment fact. `AVIPBurnSink` in this
///      repository is the reference choice (destroy them); a deployment that
///      keeps them points at its own implementation of this interface.
///
///      **The vault transfers first, then notifies.** `receiveFunds` is a
///      notification that `amount` base units *arrived at `msg.sender`*, which is
///      why the amount is what the vault measured and not necessarily what it
///      asked the token to send. A sink needs no allowance, no `transferFrom` and
///      no way to refuse the funds; refusing would revert the whole operation
///      (the vault propagates a sink revert, so a slash is atomic and cannot
///      half-happen).
///
///      **The reason is derived, not chosen.** The vault passes on the provenance
///      id the validator manager recorded for the slash (M7d's
///      `AVIPMessageCodec.provenanceId(sourceBlockchainId, nonce)`, §5.11) or its
///      own constant for a fee. A sink gets one `bytes32` that identifies *why*
///      the funds arrived, and cannot be told an arbitrary story by a caller:
///      `debit` is manager-only and `payFee` is paid by its own subject.
interface IFundSink {
    /// @notice `amount` base units of the vault's token arrived at this sink.
    /// @param amount Base units that arrived, as measured by the vault.
    /// @param reason Machine-readable reason: a slash's provenance id, or the
    ///        vault's fee tag.
    function receiveFunds(uint256 amount, bytes32 reason) external;
}
