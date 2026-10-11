#!/usr/bin/env bash
# The one documented command of `src/zk/README.md` for M7c — the
# Pedersen/Poseidon ↔ keccak Merkle bridge (option (c) of plan §5.4 item 4,
# delivered in §5.10, gap A7).
#
#   src/zk/scripts/m7c_report.sh
#
# Runs `m7c-report` over the committed fixture of §5.5.6 and pins the table to
# `scripts/m7c_output.txt` (committed). The table carries no durations, so a
# re-run on an unmodified revision reproduces it byte for byte, and the binary's
# own checks (`n/n hold`) exit non-zero if the link stops binding.
#
# Then the drift guard, in both directions, against the *emitted* artifact:
#   (a) every statement value the contract test installs — `STATEMENT_ROOT`,
#       `STATEMENT_EPOCH`, `STATEMENT_NORM` and `TENSOR_DIGEST` from
#       `integrations/avalanche/test/fixtures/M4bGroth16Fixtures.sol` — appears in
#       the fresh table, so the bridge answers to the Solidity fixture and not
#       only to this crate's idea of it;
#   (b) the link pinned in `scripts/m7c_output.txt` is the link this revision
#       computes, so the committed tie cannot go stale silently.
# A failure exits non-zero and leaves the pinned file untouched (fail-closed).
set -euo pipefail
cd "$(dirname "$0")/.."

SOLIDITY=../../integrations/avalanche/test/fixtures/M4bGroth16Fixtures.sol
PINNED=scripts/m7c_output.txt

cargo build --offline --release --bin m7c-report
# The fresh table goes to a temporary file: the pinned artifact is only replaced
# once the guard has passed, so a drifting run leaves the committed file intact.
RUN="$(mktemp)"
trap 'rm -f "$RUN"' EXIT
cargo run --offline --release --quiet --bin m7c-report > "$RUN"

[ -f "$SOLIDITY" ] || { echo "FAIL: the emitted fixture is missing: $SOLIDITY" >&2; exit 1; }
echo "m7c_report.sh: checking the table against $(basename "$SOLIDITY")" >&2

# The fixture's constants, whitespace removed: `forge fmt` breaks a long line
# after the `=`, so `NAME = value;` can span two lines in the file.
flat="$(tr -d '[:space:]' < "$SOLIDITY")"
sol_value() { printf '%s' "$flat" | sed -E "s/.*${1}=([0-9a-fA-Fx]+).*/\1/"; }

fail=0
for name in STATEMENT_ROOT STATEMENT_EPOCH STATEMENT_NORM TENSOR_DIGEST; do
    value="$(sol_value "$name")"
    if [ -z "$value" ] || [ "$value" = "$flat" ]; then
        echo "FAIL: $name is not in $SOLIDITY" >&2
        fail=1
    elif grep -Fq -- "$value" "$RUN"; then
        echo "  ok  $name = $value" >&2
    else
        echo "FAIL (a): $name = $value (from $(basename "$SOLIDITY")) is not in the bridge's table" >&2
        fail=1
    fi
done

# (b) the committed link against the fresh run.
if [ ! -f "$PINNED" ]; then
    echo "  ok  $PINNED does not exist yet — this run creates it" >&2
else
    link="$(grep -F 'link digest' "$PINNED" | sed -E 's/.*(0x[0-9a-f]{64}).*/\1/')"
    if [ -z "$link" ]; then
        echo "FAIL (b): no link digest in $PINNED" >&2
        fail=1
    elif grep -Fq -- "$link" "$RUN"; then
        echo "  ok  link = $link" >&2
    else
        echo "FAIL (b): the pinned link $link is not the link this revision computes" >&2
        fail=1
    fi
fi

[ "$fail" -eq 0 ] || { echo "m7c_report.sh: DRIFT (${PINNED} left unchanged)" >&2; exit 1; }

if [ -f "$PINNED" ] && ! diff -q "$RUN" "$PINNED" > /dev/null; then
    echo "m7c_report.sh: note — the table changed and is being rewritten" >&2
fi

mv "$RUN" "$PINNED"
chmod 644 "$PINNED"
trap - EXIT
echo "m7c_report.sh: ${PINNED} updated; the table matches the emitted fixture (both directions)" >&2
