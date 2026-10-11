#!/usr/bin/env bash
# The one documented command of plan §6 — the M6 analogue of
# src/rmt/scripts/m5_report.sh.
#
#   src/reputation/scripts/m6_report.sh
#
# Reproduces the sealed reputation dynamics (`verification/stochastics/`,
# `verification/mechanism/`) in Rust and pins the table to `scripts/m6_output.txt`
# (committed). Sections 1, 2 and 4 are deterministic and byte-stable; section 3 is
# the statistical reproduction declared in `src/numpy.rs` (the substitute
# transforms), and its numbers are the ones a full run of the sealed path count
# produces. Every duration goes to stderr, never into the pinned file.
#
# `--smoke` is deliberately NOT passed: the pinned artefact is the sealed
# configuration (paths = 100000), which is what the reference was computed with.
#
# Afterwards it checks the drift guard in both directions:
#   (a) every line of `fixtures/sealed_reference.txt` still occurs byte for byte
#       in the file its block header names under `verification/` (M6 never edits
#       those files, so a mismatch means someone else did and the copy is stale);
#   (b) every token with four or more decimals in that reference appears in the
#       reproduction (so the Rust numbers still match the sealed ones, not just
#       the header text).
# A failure exits non-zero and writes nothing (fail-closed).
set -euo pipefail
cd "$(dirname "$0")/.."

REFERENCE=fixtures/sealed_reference.txt
PINNED=scripts/m6_output.txt

cargo build --release --bin m6-report
# The reproduction goes to a temporary file: the pinned artefact is only replaced
# once it has passed the drift guard, so a drifting run leaves the committed file
# untouched instead of overwriting it.
RUN="$(mktemp)"
trap 'rm -f "$RUN"' EXIT
cargo run --release --quiet --bin m6-report > "$RUN"

echo "m6_report.sh: checking $(basename "$REFERENCE") against the sealed outputs" >&2

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

[ "$fail" -eq 0 ] || { echo "m6_report.sh: DRIFT (${PINNED} left unchanged)" >&2; exit 1; }

mv "$RUN" "$PINNED"
chmod 644 "$PINNED"
trap - EXIT
echo "m6_report.sh: ${PINNED} updated; reproduction matches the sealed reference (both directions)" >&2
