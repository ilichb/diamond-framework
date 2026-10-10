#!/usr/bin/env bash
# Generates the Solidity fixture that M4b's own key and proof are committed in:
# `integrations/avalanche/test/fixtures/M4bGroth16Fixtures.sol`.
#
#   src/zk/scripts/m4b_fixture.sh
#
# The key and the proof come from `src/zk` (the crate that owns the circuit), not
# from a script that imitates them: the emitter runs the same seeded setup and
# the same seeded proof `scripts/m4b_report.sh` measures, so the fixture and the
# report cannot drift apart. It is deterministic, and `forge fmt` is the second
# half of the output step — the emitter writes Solidity, it is not a formatter —
# so two runs produce the same committed file byte for byte.
set -euo pipefail
cd "$(dirname "$0")/.."

cargo build --release --bin m4b-fixture
cargo run --release --quiet --bin m4b-fixture

(cd ../../integrations/avalanche && forge fmt test/fixtures/M4bGroth16Fixtures.sol)
