#!/usr/bin/env bash
# The one documented command of plan §5.5.6: runs every M4a measurement and
# writes the table to scripts/m4a_output.txt (committed), the off-chain analogue
# of M3's scripts/groth16_fixtures_output.txt.
#
#   src/zk/scripts/m4a_report.sh
#
# The table is deterministic: re-running this script on an unmodified revision
# reproduces the file byte for byte. The wall-clock durations (`prove`, `verify`,
# `synthesized`) are printed to stderr instead, because they vary with machine
# load; they are reported as an observation, not as a pinned number.
#
# First run fetches the dependency tree; afterwards `cargo build --offline`
# works (see the note in Cargo.toml).
set -euo pipefail
cd "$(dirname "$0")/.."

cargo build --release --bin m4a-report
cargo run --release --quiet --bin m4a-report | tee scripts/m4a_output.txt
