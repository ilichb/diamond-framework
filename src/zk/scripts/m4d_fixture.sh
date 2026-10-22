#!/usr/bin/env bash
# Generates the Solidity fixture for the admission circuit (audit 2026-10-20,
# findings P-01 and P-16):
#
#   src/zk/scripts/m4d_fixture.sh
#
# The key and the inclusion proofs come from `src/zk`, so the fixture and the
# `admission_statement` tests cannot drift apart. It is deterministic, and
# `forge fmt` is the second half of the output step.
set -euo pipefail
cd "$(dirname "$0")/.."

cargo build --release --bin m4d-fixture
cargo run --release --quiet --bin m4d-fixture

(cd ../../integrations/avalanche && forge fmt test/fixtures/M4dGroth16Fixtures.sol)
