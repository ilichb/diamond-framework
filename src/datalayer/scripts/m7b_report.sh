#!/usr/bin/env bash
# The one documented command of plan §5.9 — the M7b analogue of
# src/rmt/scripts/m5_report.sh and src/reputation/scripts/m6_report.sh.
#
#   src/datalayer/scripts/m7b_report.sh
#
# Reproduces the sealed audit equilibrium (`verification/data-layer/`) in Rust and
# pins the table to `scripts/m7b_output.txt` (committed). The reproduction is
# deterministic and byte-stable: every draw is numpy's own PCG64 stream seeded at
# 42, and the transcribed binomial is checked against numpy's draws before any
# number is printed. Every duration goes to stderr, never into the pinned file.
#
# Afterwards it checks the drift guard in both directions:
#   (a) every line of `fixtures/sealed_reference.txt` still occurs byte for byte
#       in the file its block header names under `verification/` (M7b never edits
#       those files, so a mismatch means someone else did and the copy is stale);
#   (b) every token with four or more decimals in that reference appears in the
#       reproduction (so the Rust numbers still match the sealed ones, not just
#       the header text).
# A failure exits non-zero and writes nothing (fail-closed).
set -euo pipefail
cd "$(dirname "$0")/.."

REFERENCE=fixtures/sealed_reference.txt
PINNED=scripts/m7b_output.txt

cargo build --release --bin m7b-report
# The reproduction goes to a temporary file: the pinned artefact is only replaced
# once it has passed the drift guard, so a drifting run leaves the committed file
# untouched instead of overwriting it.
RUN="$(mktemp)"
trap 'rm -f "$RUN"' EXIT
cargo run --release --quiet --bin m7b-report > "$RUN"

echo "m7b_report.sh: checking $(basename "$REFERENCE") against the sealed outputs" >&2

fail=0
# (a) verbatim, block by block, against the file named in each `# ---` header.
sealed=""
while IFS= read -r line; do
    case "$line" in
        '# --- '*) sealed="../../${line#\# --- }"; sealed="${sealed%%:*}" ;;
        '' | '#'*) continue ;;
        *)
            if [ -z "$sealed" ] || [ ! -f "$sealed" ]; then
                echo "FAIL (a): no sealed file for: $line" >&2
                fail=1
            elif ! grep -Fqx -- "$line" "$sealed"; then
                echo "FAIL (a): not in $sealed: $line" >&2
                fail=1
            fi
            ;;
    esac
done < "$REFERENCE"

# (b) the sealed numbers themselves, out of the reproduction.
while IFS= read -r token; do
    [ -n "$token" ] || continue
    if ! grep -Fq -- "$token" "$RUN"; then
        echo "FAIL (b): sealed value $token is missing from the reproduction" >&2
        fail=1
    fi
done < <(grep -v '^#' "$REFERENCE" | grep -oE '[0-9]+\.[0-9]{4}' | sort -u)

[ "$fail" -eq 0 ] || { echo "m7b_report.sh: DRIFT (${PINNED} left unchanged)" >&2; exit 1; }

mv "$RUN" "$PINNED"
chmod 644 "$PINNED"
trap - EXIT
echo "m7b_report.sh: ${PINNED} updated; reproduction matches the sealed reference (both directions)" >&2
