// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title M8CustodyFixtures
/// @notice The numbers M8's custody audit carries that come from *other*
///         milestones, in one place — the same shape as `M7dProvenanceFixtures.sol`
///         and `M7cBridgeFixtures.sol`, and declared rather than generated.
///
/// @dev `integrations/avalanche/scripts/m8_report.sh` checks each literal below
///      against the committed transcript it comes from, in both directions: the
///      literal must be in the upstream transcript, and the same value must appear
///      in the fresh M8 run. One file rather than two copies is what stops the
///      report and the suite from disagreeing about which numbers M8 is talking
///      about.
///
///      Provenance:
///        - `M7D_*`: `integrations/avalanche/scripts/m7d_output.txt` (§5.11, amended
///          by §5.13/M9b). M7d's slashing notification carried a stake of
///          `1000000000000000000` WAD and the slash took **all of it**: the
///          transcript's `slash.stakeAfter` is `0`, because the amount is the
///          record and no longer travels. The reason is `0x9ee878…298c` — the
///          provenance id M8's custody now forwards to the sink. M8's report
///          replays *that* trajectory against real escrow, which is what ties the
///          wire milestone to the funds milestone.
///        - `WAD_PER_UNIT = 1e12`: six decimals, the USDC-like case §5.12 discusses.
///          Not from a transcript: it is the token scale the report deploys, and
///          the fee guard derives `F_0*` in units from it.
///        - the certified norm M8 admits at is `M4bGroth16Fixtures.STATEMENT_NORM`
///          (`src/zk/scripts/m4b_output.txt`, `certifiedNorm (WAD)`), imported
///          directly rather than copied here.
library M8CustodyFixtures {
    /// @notice The provenance id M7d derived for its slashing notification
    ///         (`m7d_output.txt`, `slash.reason` / `slash.managerEvent.reason`).
    bytes32 internal constant M7D_SLASH_REASON =
        0x9ee878158fd03ad640d4a0705a30c697ca9fe067e51ec5dde8bf6b55f41c298c;

    /// @notice The stake M7d's notification declared (`m7d_output.txt`,
    ///         `admit.stake`), in WAD.
    uint256 internal constant M7D_ADMIT_STAKE = 1e18;

    /// @notice What M7d's notification left after the slash (`m7d_output.txt`,
    ///         `slash.stakeAfter`), in WAD. Zero, and not a placeholder: M9b's
    ///         slash takes the whole record, so the trajectory M8 replays ends at
    ///         the empty record rather than at a remainder.
    uint256 internal constant M7D_SLASH_STAKE_AFTER = 0;

    /// @notice The slash M7d's two rows imply: `M7D_ADMIT_STAKE - M7D_SLASH_STAKE_AFTER`,
    ///         i.e. the record itself.
    uint256 internal constant M7D_SLASHED_STAKE = 1e18;

    /// @notice `10 ** (18 - 6)`: the scale of the six-decimal token the report
    ///         deploys, so every WAD number above is a whole number of base units
    ///         (`1e18 / 1e12 = 1_000_000`, `0 / 1e12 = 0`).
    uint256 internal constant WAD_PER_UNIT = 1e12;

    /// @notice The escrow that covers `M7D_ADMIT_STAKE` exactly, in base units.
    uint256 internal constant ESCROW_UNITS = 1_000_000;

    /// @notice What the slash moves, in base units (`M7D_SLASHED_STAKE / 1e12`):
    ///         the whole escrow, which is the point of M9b's derived amount — a
    ///         validator whose record is taken has no unseized remainder left.
    uint256 internal constant SLASH_UNITS = 1_000_000;
}
