#!/usr/bin/env bash
# The one documented command of M8 — the ERC-20 stake vault that turns M2's
# *declared* `financialStake` into custody, the `F_0*` fee into a visited sink and
# a slash into a movement of real tokens (implementation plan §5.12).
#
#   bash integrations/avalanche/scripts/m8_report.sh
#
# Runs `M8Report.s.sol` offline and pins its `[m8]` transcript to
# `scripts/m8_output.txt` (committed). The transcript carries no gas, no timings
# and no network addresses, so a re-run on an unmodified revision reproduces it
# byte for byte; the script's own `require`s (and the `status=ok` row) exit
# non-zero if the custody stops behaving.
#
# Then the drift guards, against the *committed transcripts of the milestones the
# numbers come from*, in both directions — every value M8 prints must be in the
# upstream transcript, in the declared fixture, and in the fresh run:
#
#   (a) M7a, the deployment harness: the fee M8 charges in token units must be the
#       `F_0*` that `deploy_dryrun_output.txt` reads back from the manager,
#       divided by the scale M8's vault was deployed with. This is the one guard
#       that *derives* rather than compares, and it is the unit story of §5.12 in
#       one line: WAD policy in, base units out.
#   (b) M7d, the wire: the stake trajectory (`admit.stake`, `slash.stakeAfter`)
#       and the slashing reason M8 replays against real escrow must be the ones
#       M7d's notification carried. The same provenance id must be in M8's fixture
#       and in the M8 transcript. Since M9b the slash takes the whole record, so
#       `slash.stakeAfter` is `0` (see the note at the check itself).
#   (c) M4b, the proof: the norm M8 admits at must be the `certifiedNorm (WAD)` of
#       the real key's transcript — the M8 report admits with the real proof, so
#       the number is not free.
#   (d) The policy at the worst admissible type: `requiredStakeFor(Theta_r)` must
#       be the value M7a's transcript pins, so a manager redeployed with a
#       different policy cannot slip through.
#
# A failure exits non-zero and leaves the pinned file untouched (fail-closed).
set -euo pipefail
cd "$(dirname "$0")/.."

SCRIPT=scripts/M8Report.s.sol:M8Report
PINNED=scripts/m8_output.txt
FIXTURE=test/fixtures/M8CustodyFixtures.sol
M4B_FIXTURE=test/fixtures/M4bGroth16Fixtures.sol
DRYRUN=scripts/deploy_dryrun_output.txt
M7D=scripts/m7d_output.txt
M4B=../../src/zk/scripts/m4b_output.txt

for upstream in "$DRYRUN" "$M7D" "$M4B"; do
    [ -f "$upstream" ] || { echo "FAIL: the upstream transcript is missing: $upstream" >&2; exit 1; }
done

# The fresh transcript goes to a temporary file: the pinned artifact is only
# replaced once every guard has passed, so a drifting run leaves the committed
# file intact.
RUN="$(mktemp)"
trap 'rm -f "$RUN"' EXIT
echo "m8_report.sh: running $SCRIPT (offline, nothing broadcast)" >&2
forge script "$SCRIPT" --offline 2>&1 | grep -E '^  \[m8\] ' > "$RUN"

# The script reaches its last row only if every `require` in it held.
if ! grep -qx '  \[m8\] status=ok' "$RUN"; then
    echo "FAIL: the report did not reach status=ok:" >&2
    tail -n 5 "$RUN" >&2 || true
    exit 1
fi

fail=0
# require_in <label> <value> <file> — <file> must carry <value>, verbatim.
require_in() {
    local label=$1 value=$2 file=$3
    if [ -z "$value" ] || [ "$value" = "$file" ]; then
        echo "FAIL: could not read $label" >&2
        fail=1
    elif grep -Fq -- "$value" "$file"; then
        echo "  ok  $label = $value  ($(basename "$file"))" >&2
    else
        echo "FAIL: $label = $value is not in $(basename "$file")" >&2
        fail=1
    fi
}
# both <label> <value> <file> — the value must be in the fixture *and* in the run.
both() {
    require_in "$1" "$2" "$3"
    require_in "$1 (run)" "$2" "$RUN"
}
# run_only <label> <key> — read one `[m8] key=value` row out of the fresh run.
run_only() {
    local label=$1 key=$2 value
    value="$(sed -nE "s/^  \\[m8\\] ${key}=(.*)$/\\1/p" "$RUN" | head -n1)"
    if [ -z "$value" ]; then
        echo "FAIL: could not read $label from the run" >&2
        fail=1
    else
        printf '%s' "$value"
    fi
}

# ------------------------------------------- (a) M7a: the fee is F_0* in units
f0_star="$(grep -E '\[m7a\] check\.F0_STAR=' "$DRYRUN" | sed -E 's/.*=//' | head -n1)"
scale="$(run_only "vault.wadPerUnit" "vault.wadPerUnit")"
fee_units="$(run_only "custody.feeInUnits" "custody.feeInUnits")"
if [ -z "$f0_star" ] || [ -z "$scale" ] || [ -z "$fee_units" ]; then
    echo "FAIL: could not read the fee triangle (F_0*, scale, units)" >&2
    fail=1
elif [ "$((f0_star / scale))" -ne "$fee_units" ]; then
    echo "FAIL: F_0* / WAD_PER_UNIT = $((f0_star / scale)) but the vault charges $fee_units" >&2
    fail=1
else
    echo "  ok  F_0* ($f0_star WAD) / $scale = $fee_units units  (derived, M7a -> M8)" >&2
    require_in "fee.units" "  [m8] fee.units=$fee_units" "$RUN"
fi

# ------------------------------------------------- (b) M7d: stake and reason
m7d_stake="$(grep -E '^  \[m7d\] admit\.stake=' "$M7D" | sed -E 's/.*=//' | head -n1)"
m7d_after="$(grep -E '^  \[m7d\] slash\.stakeAfter=' "$M7D" | sed -E 's/.*=//' | head -n1)"
m7d_reason="$(grep -E '^  \[m7d\] slash\.reason=' "$M7D" | sed -E 's/.*=//' | head -n1)"
both m7d.admit_stake "$m7d_stake" "$FIXTURE"
both m7d.slash_reason "$m7d_reason" "$FIXTURE"
# `slash.stakeAfter` is `0` since M9b — the slash takes the whole record — and a
# substring guard looking for "0" would match a line of any file, which is a guard
# that cannot fail. So the fixture tie for this row is the whole declaration, and
# the run side is compared numerically, in both directions, just below.
if [ "$m7d_after" != "0" ]; then
    both m7d.slash_stake_after "$m7d_after" "$FIXTURE"
else
    require_in "m7d.slash_stake_after (fixture)" "M7D_SLASH_STAKE_AFTER = 0;" "$FIXTURE"
fi

# The tie itself: what the *contracts* recorded in the fresh run must be M7d's.
run_stake="$(run_only "slash.stakeAfter" "slash.stakeAfter")"
run_escrow="$(run_only "slash.escrowedAfter" "slash.escrowedAfter")"
run_reason="$(run_only "slash.reason" "slash.reason")"
if [ "$run_stake" = "$m7d_after" ] && [ "$run_escrow" = "$m7d_after" ]; then
    echo "  ok  custody and record agree with M7d's slash.stakeAfter = $m7d_after" >&2
else
    echo "FAIL: custody left $run_escrow and the record $run_stake; M7d says $m7d_after" >&2
    fail=1
fi
if [ "$run_reason" = "$m7d_reason" ]; then
    echo "  ok  the sink was told M7d's provenance id: $m7d_reason" >&2
else
    echo "FAIL: the sink was told $run_reason, M7d derived $m7d_reason" >&2
    fail=1
fi

# ------------------------------------------------------------ (c) M4b: the norm
# The norm is not copied into M8's fixture: it is *M4b's* fixture the report
# imports, so that file is where the literal has to live. Both directions: the
# fixture must carry it and the fresh run must print it.
m4b_norm="$(grep -E 'certifiedNorm \(WAD\)' "$M4B" | grep -oE '[0-9]{20,}' | head -n1)"
both m4b.certified_norm "$m4b_norm" "$M4B_FIXTURE"

# ----------------------------------------- (d) M7a: the policy at Theta_r, again
theta_r_stake="$(grep -E '\[m7a\] check\.requiredStakeFor\(THETA_R\)=' "$DRYRUN" | sed -E 's/.*=//' | head -n1)"
require_in "policy.requiredStakeAtThetaR" "$theta_r_stake" "$RUN"

[ "$fail" -eq 0 ] || { echo "m8_report.sh: DRIFT (${PINNED} left unchanged)" >&2; exit 1; }

if [ -f "$PINNED" ] && ! diff -q "$RUN" "$PINNED" > /dev/null; then
    echo "m8_report.sh: note — the transcript changed and is being rewritten" >&2
fi

mv "$RUN" "$PINNED"
chmod 644 "$PINNED"
trap - EXIT
echo "m8_report.sh: ${PINNED} updated; the numbers match M7a, M7d and M4b (both directions)" >&2
