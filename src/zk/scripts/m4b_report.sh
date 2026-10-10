#!/usr/bin/env bash
# The one documented command of plan §5.5.4 / §5.5.9: runs the whole M4b pipeline
# (measure V3 in the statement wrapper, generate the development key, prove the
# fixture statement, verify it, check that every statement component is bound)
# and writes the table to scripts/m4b_output.txt (committed), the off-chain
# analogue of M3's scripts/groth16_fixtures_output.txt and M4a's
# scripts/m4a_output.txt.
#
#   src/zk/scripts/m4b_report.sh
#
# The table is deterministic — the setup and proof RNGs are seeded from the
# committed SETUP_SEED / PROOF_SEED — so re-running this script on an unmodified
# revision reproduces the file byte for byte. The wall-clock durations (`setup`,
# `prove`, `verify`) go to stderr instead, because they vary with machine load;
# they are reported as an observation, not as a pinned number.
#
# `--smoke` (8 entries instead of 500) runs the same pipeline in seconds; it is
# for checking a change during development, not for the committed table.
#
# First run fetches the dependency tree; afterwards `cargo build --offline`
# works (see the note in Cargo.toml).
set -euo pipefail
cd "$(dirname "$0")/.."

cargo build --release --bin m4b-report
cargo run --release --quiet --bin m4b-report | tee scripts/m4b_output.txt
