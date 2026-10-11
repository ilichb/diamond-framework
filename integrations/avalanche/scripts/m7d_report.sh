#!/usr/bin/env bash
# The one documented command of M7d — the Teleporter/AWM transport of the three
# message types of `docs/architecture/avalanche-integration.md` §4
# (implementation plan §5.11, gap A9).
#
#   bash integrations/avalanche/scripts/m7d_report.sh
#
# Runs `M7dReport.s.sol` offline and pins its `[m7d]` transcript to
# `scripts/m7d_output.txt` (committed). The transcript carries no gas, no timings
# and no network addresses, so a re-run on an unmodified revision reproduces it
# byte for byte; the script's own `require`s (and the `status=ok` row) exit
# non-zero if the wire stops behaving.
#
# Then the drift guards, against the *committed transcripts of the milestones the
# numbers come from*, in both directions: every value the M7d payloads carry must
# be in the upstream transcript, in the declared fixture, and in the fresh run.
#
#   (a) M5, the sealed calibration: `q99 = 9.0542` right and `9.1371` left, scaled
#       to the 4 decimals that decide the alert's `rightThresholdQ`/`leftThresholdQ`.
#   (b) M7b, the data layer: the `f_c` instance's genesis digest and the one
#       adjudicated `Verdict::Fraud` pair the slashing notification transports.
#   (c) M7c, the bridge: the two roots, the epoch and the link — and in particular
#       the link the *contract* recomputes, which must be the one the Rust crate
#       published (`linkDigest` versus `bridge::link_digest`).
#
# A failure exits non-zero and leaves the pinned file untouched (fail-closed).
set -euo pipefail
cd "$(dirname "$0")/.."

SCRIPT=scripts/M7dReport.s.sol:M7dReport
PINNED=scripts/m7d_output.txt
FIXTURE_C=test/fixtures/M7cBridgeFixtures.sol
FIXTURE_D=test/fixtures/M7dProvenanceFixtures.sol
M5=../../src/rmt/scripts/m5_output.txt
M7B=../../src/datalayer/scripts/m7b_output.txt
M7C=../../src/zk/scripts/m7c_output.txt

for upstream in "$M5" "$M7B" "$M7C"; do
    [ -f "$upstream" ] || { echo "FAIL: the upstream transcript is missing: $upstream" >&2; exit 1; }
done

# The fresh transcript goes to a temporary file: the pinned artifact is only
# replaced once every guard has passed, so a drifting run leaves the committed
# file intact.
RUN="$(mktemp)"
trap 'rm -f "$RUN"' EXIT
echo "m7d_report.sh: running $SCRIPT (offline, nothing broadcast)" >&2
forge script "$SCRIPT" --offline 2>&1 | grep -E '^  \[m7d\] ' > "$RUN"

# The script reaches its last row only if every `require` in it held.
if ! grep -qx '  \[m7d\] status=ok' "$RUN"; then
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
# both <label> <value> — the value must be in the fixture *and* in the fresh run.
both() {
    require_in "$1" "$2" "$3"
    require_in "$1 (run)" "$2" "$RUN"
}

# ---------------------------------------------------------------- (a) M5, §5.6
m5_right_q="$(grep -E 'right  s\[-1\] = lambda_max' "$M5" | grep -oE 'q99=[0-9.]+' | head -n1 |
    sed -E 's/q99=//; s/\.//')"
m5_left_q="$(grep -E 'left  -s\[0\] = -lambda_min' "$M5" | grep -oE 'q99=[0-9.]+' | head -n1 |
    sed -E 's/q99=//; s/\.//')"
both m5.right_q "$m5_right_q" "$FIXTURE_D"
both m5.left_q "$m5_left_q" "$FIXTURE_D"

# --------------------------------------------------------------- (b) M7b, §5.9
m7b_digest="$(grep -E 'genesis digest' "$M7B" | grep -oE '0x[0-9a-f]{64}' | head -n1)"
m7b_pair="$(grep -oE 'published [0-9]+, f_c [0-9]+' "$M7B" | head -n1)"
m7b_published="$(printf '%s' "$m7b_pair" | sed -E 's/published ([0-9]+), f_c [0-9]+/\1/')"
m7b_formula="$(printf '%s' "$m7b_pair" | sed -E 's/published [0-9]+, f_c ([0-9]+)/\1/')"
both m7b.ingestion_digest "$m7b_digest" "$FIXTURE_D"
both m7b.published_wad "$m7b_published" "$FIXTURE_D"
both m7b.formula_wad "$m7b_formula" "$FIXTURE_D"

# --------------------------------------------------------------- (c) M7c, §5.10
m7c_merkle="$(grep -E 'Merkle root' "$M7C" | grep -oE '0x[0-9a-f]{64}' | head -n1)"
m7c_statement="$(grep -E 'statement root \(V3' "$M7C" | grep -oE '[0-9]{20,}' | head -n1)"
m7c_link="$(grep -E 'link digest' "$M7C" | grep -oE '0x[0-9a-f]{64}' | head -n1)"
both m7c.merkle_root "$m7c_merkle" "$FIXTURE_C"
both m7c.statement_root "$m7c_statement" "$FIXTURE_C"
both m7c.link "$m7c_link" "$FIXTURE_C"

# The tie itself: what the contract computed in the fresh run must be M7c's link.
computed="$(grep -E '^  \[m7d\] link\.recomputed=' "$RUN" | sed -E 's/.*link\.recomputed=//')"
if [ "$computed" = "$m7c_link" ]; then
    echo "  ok  linkDigest(x, y, epoch) = M7c's bridge::link_digest" >&2
else
    echo "FAIL: the contract computed $computed, M7c published $m7c_link" >&2
    fail=1
fi

[ "$fail" -eq 0 ] || { echo "m7d_report.sh: DRIFT (${PINNED} left unchanged)" >&2; exit 1; }

if [ -f "$PINNED" ] && ! diff -q "$RUN" "$PINNED" > /dev/null; then
    echo "m7d_report.sh: note — the transcript changed and is being rewritten" >&2
fi

mv "$RUN" "$PINNED"
chmod 644 "$PINNED"
trap - EXIT
echo "m7d_report.sh: ${PINNED} updated; the numbers match M5, M7b and M7c (both directions)" >&2
