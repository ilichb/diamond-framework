#!/usr/bin/env bash
# The one documented command of plan §5.6 — the M5 analogue of
# src/zk/scripts/m4b_report.sh.
#
#   src/rmt/scripts/m5_report.sh
#
# Reproduces the sealed RMT calibration (`verification/rmt/`) in Rust and pins the
# table to `scripts/m5_output.txt` (committed). The pinned file is deterministic:
# the MC phases resume numpy's own stream and are chunked in a way that does not
# depend on the machine, and every duration goes to stderr.
#
# Afterwards it checks the *drift guard* in both directions:
#   (a) every line of `fixtures/sealed_reference.txt` is still present verbatim in
#       `verification/rmt/results/` (M5 never edits those files, so a mismatch
#       means someone else did, and the reproduction is stale);
#   (b) every four-decimal number of that reference appears in the pinned output
#       (so the Rust numbers still match the sealed ones, not just the header).
# A failure exits non-zero and writes nothing.
set -euo pipefail
cd "$(dirname "$0")/.."

REFERENCE=fixtures/sealed_reference.txt
PINNED=scripts/m5_output.txt
SEALED_DIR=../../verification/rmt/results

cargo build --release --bin m5-report
# The reproduction goes to a temporary file: the pinned artefact is only replaced
# once it has passed the drift guard, so a drifting run leaves the committed file
# untouched instead of overwriting it (fail-closed).
RUN="$(mktemp)"
SEALED_UNION="$(mktemp)"
trap 'rm -f "$RUN" "$SEALED_UNION"' EXIT
cargo run --release --quiet --bin m5-report > "$RUN"

echo "m5_report.sh: checking $(basename "$REFERENCE") against the sealed outputs" >&2
cat \
    "$SEALED_DIR/calibration_modularity_output.txt" \
    "$SEALED_DIR/bipartite_power_output.txt" \
    "$SEALED_DIR/clique_spectra_output.txt" \
    "$SEALED_DIR/q99_standard_error_output.txt" > "$SEALED_UNION"

fail=0
while IFS= read -r line; do
    case "$line" in '' | '#'*) continue ;; esac
    if ! grep -Fq -- "$line" "$SEALED_UNION"; then
        echo "FAIL (a): not in verification/rmt/results/: $line" >&2
        fail=1
    fi
done < "$REFERENCE"

while IFS= read -r token; do
    [ -n "$token" ] || continue
    if ! grep -Fq -- "$token" "$RUN"; then
        echo "FAIL (b): sealed value $token is missing from the reproduction" >&2
        fail=1
    fi
done < <(grep -v '^#' "$REFERENCE" | grep -oE '[0-9]+\.[0-9]{4}' | sort -u)

[ "$fail" -eq 0 ] || { echo "m5_report.sh: DRIFT (${PINNED} left unchanged)" >&2; exit 1; }

mv "$RUN" "$PINNED"
chmod 644 "$PINNED"
echo "m5_report.sh: ${PINNED} updated; reproduction matches the sealed reference (both directions)" >&2
