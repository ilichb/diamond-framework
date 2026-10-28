#!/usr/bin/env bash
# Generates the Solidity fixture for R5-1 and R5-2 (audit 2026-10-28):
#
#   src/zk/scripts/merkle_fixture.sh
#
# The payloads, leaves, roots and inclusion proofs come from `avip_datalayer`'s
# `commitment` module through `src/zk`'s bridge, so the fixture and the Rust tests
# cannot drift apart: `tests/datalayer_inclusion.rs` calls the same `solidity()`
# function this script writes with. It is deterministic, and `forge fmt` is the
# second half of the output step.
#
# The fixture is the *cross-language* half of the two findings: the deployed
# `AVIPRegistry.verifyEntry` is run against a root and proofs the Rust side
# produced, with no Solidity code computing them.
set -euo pipefail
cd "$(dirname "$0")/.."

cargo build --offline --release --bin merkle-fixture
cargo run --offline --release --quiet --bin merkle-fixture

(cd ../../integrations/avalanche && forge fmt test/fixtures/DatalayerInclusion.sol)
