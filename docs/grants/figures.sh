#!/usr/bin/env bash
#
# figures.sh — re-derive every number quoted in docs/grants/*.md
#
# A proposal that cites 299 tests is a proposal that will cite 299 tests after
# someone adds the three hundredth. This script prints the figures from the tree
# and compares them with the values the documents claim, so the drift is caught
# here instead of by a reviewer.
#
# Usage:
#   docs/grants/figures.sh             # record, tests, PDF, anchor, addresses
#   docs/grants/figures.sh --coverage  # adds per-contract coverage (~2 min)
#   docs/grants/figures.sh --full      # adds coverage and the audit gate
#
# PINNED SNAPSHOT. The CLAIM_* values below describe the 2026-10-25 submission:
# PDF 591,875 B (89e71837…), 311 tests, root abe9c553…. The tree has since moved
# to v0.2.3 (601,340 B / dd071071…, 316 tests, root 6fe5884b…), so a run at HEAD
# reports drift on those three by design. Re-base the CLAIM_* lines in the same
# commit that re-bases the proposal; until then the drift is the warning, not the
# bug.
#
# Exit: 0 if every checked figure matches the claim, 1 on drift.
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO}" || exit 2

AV="integrations/avalanche"
PDF="docs/paper/releases/diamond-framework-2026-10-25.pdf"

# The claims, as the documents state them. The test count is 311 total: 310 run
# offline (300 unit/fork tests plus 10 stateful-invariant tests, of which the
# 9 `invariant_` functions each run 48 x 32 calls) and one (SafeForkTest) skips
# without FUJI_RPC_URL, so the invariant to check is "0 failed, 311 total", not a
# fixed number of passes.
CLAIM_TOTAL=311
CLAIM_FAILED=0
CLAIM_PDF_SHA=89e718373158285821ac04d1a9280c7ff85baa8c03dbc4b8df9a6da481dd39b9
CLAIM_PDF_BYTES=591875
CLAIM_PDF_PAGES=43
CLAIM_ROOT=abe9c5535eb1dd7e462b49f19b52b828a9cfe235ccbcd32819f5daa37fe56bf7
CLAIM_CORE_LINES=2673
CLAIM_SCOPE_LINES=2856
# Test code as the appendix states it: 11 .t.sol files, the ten at test/ plus the
# stateful-invariant suite at test/invariant/.
CLAIM_TEST_LINES=7328
CLAIM_TEST_FILES=11
CLAIM_GATE_PASS=11

DRIFT=0
say() { printf '%-22s %s\n' "$1" "$2"; }
check() {
    if [ "$2" = "$3" ]; then say "$1" "$2  (matches)";
    else say "$1" "$2  <> claimed $3"; DRIFT=$((DRIFT + 1)); fi
}

echo "grants/figures.sh  repo=${REPO}"
echo "--------------------------------------------------------------------------"

# ---- the record -------------------------------------------------------------
say "commits"     "$(git rev-list --count HEAD)"
say "head"        "$(git log -1 --format='%h %s' | cut -c1-64)"
say "latest tag"  "$(git describe --tags --abbrev=0 2>/dev/null || echo none)"
say "pdf"         "${PDF}"
check "pdf bytes" "$(stat -c %s "${PDF}")" "${CLAIM_PDF_BYTES}"
check "pdf sha256" "$(sha256sum "${PDF}" | cut -d' ' -f1)" "${CLAIM_PDF_SHA}"
if command -v pdfinfo >/dev/null 2>&1; then
    check "pdf pages" "$(pdfinfo "${PDF}" | awk '/^Pages:/ {print $2}')" "${CLAIM_PDF_PAGES}"
else
    say "pdf pages" "skipped (no pdfinfo)"
fi

# ---- the seal ---------------------------------------------------------------
# The root is the SHA-256 of the manifest the anchor script derives.
check "anchor root" "$(sha256sum verification/anchor_root.sha256 | cut -d' ' -f1)" "${CLAIM_ROOT}"
say "anchor pairs" "$(grep -c . verification/anchor_root.sha256)"
if [ -f verification/anchor_root.sha256.ots ]; then
    say "ots bytes" "$(stat -c %s verification/anchor_root.sha256.ots)"
    say "ots attestations" "$(command -v ots >/dev/null 2>&1 && ots info verification/anchor_root.sha256.ots 2>/dev/null | grep -c 'BitcoinBlockHeaderAttestation') Bitcoin (0 = still pending)"
fi

# ---- the code ---------------------------------------------------------------
check "core sol lines" "$(wc -l "${AV}"/contracts/AVIP*.sol | tail -1 | awk '{print $1}')" "${CLAIM_CORE_LINES}"
check "scope sol lines" "$(wc -l "${AV}"/contracts/AVIP*.sol "${AV}"/contracts/verifiers/Bn254.sol | tail -1 | awk '{print $1}')" "${CLAIM_SCOPE_LINES}"
say "all sol lines"  "$(wc -l "${AV}"/contracts/*.sol "${AV}"/contracts/*/*.sol | tail -1 | awk '{print $1}')"
say "sol files"      "$(ls "${AV}"/contracts/*.sol "${AV}"/contracts/*/*.sol | wc -l)"
TEST_LINES=$(wc -l "${AV}"/test/*.t.sol "${AV}"/test/invariant/*.t.sol | tail -1 | awk '{print $1}')
TEST_FILES=$(ls "${AV}"/test/*.t.sol "${AV}"/test/invariant/*.t.sol | wc -l)
check "test lines"   "${TEST_LINES}" "${CLAIM_TEST_LINES}"
check "test files"   "${TEST_FILES}" "${CLAIM_TEST_FILES}"

# ---- the tests --------------------------------------------------------------
# --force: Forge's incremental cache went stale on this machine and reported
# "300 total tests" for a tree that had 310 (the new suite was not in `out/`).
# A drift check that can read a cached summary is not a drift check.
OUT="$(cd "${AV}" && forge test --force 2>&1 | tail -1)"
say "forge test" "${OUT}"
check "tests failed" "$(printf '%s' "${OUT}" | awk '{for (i=1;i<=NF;i++) if ($i=="failed,") {print $(i-1); exit}}')" "${CLAIM_FAILED}"
check "tests total"  "$(printf '%s' "${OUT}" | sed -n 's/.*(\([0-9]*\) total tests).*/\1/p')" "${CLAIM_TOTAL}"
say "tests skipped"  "$(printf '%s' "${OUT}" | awk '{for (i=1;i<=NF;i++) if ($i=="skipped") {print $(i-1); exit}}') (SafeForkTest skips without FUJI_RPC_URL)"

# ---- addresses actually on chain (read back, not quoted) --------------------
if [ -n "${FUJI_RPC_URL:-}" ]; then
    REG=0x8DE8C8436D0cc9ED85ea630D5324B8A580EAd69a
    VER=0x125f2054EaCFbd9e34F991cF7A437b3dC95E3eCa
    say "registry.verifier"    "$(cast call "${REG}" 'verifier()(address)' --rpc-url "${FUJI_RPC_URL}" 2>/dev/null || echo unreachable)"
    say "registry.pendingVer"  "$(cast call "${REG}" 'pendingVerifier()(address)' --rpc-url "${FUJI_RPC_URL}" 2>/dev/null || echo unreachable)"
    CODE="$(cast code "${VER}" --rpc-url "${FUJI_RPC_URL}" 2>/dev/null | tr -d '\n')"
    if [ -n "${CODE}" ]; then
        say "verifier bytecode" "$(( (${#CODE} - 2) / 2 )) bytes"
    else
        say "verifier bytecode" "unreachable"
    fi
else
    say "chain reads" "skipped (export FUJI_RPC_URL to check the chain)"
fi

# ---- optional: coverage ------------------------------------------------------
if [ "${1:-}" = "--coverage" ] || [ "${1:-}" = "--full" ]; then
    echo "--- coverage (forge coverage, this takes a couple of minutes) ---"
    ( cd "${AV}" && forge coverage --report summary 2>/dev/null ) \
        | grep -E '^\| contracts/(AVIP|verifiers)' \
        | sed 's/^| //; s/ *|/ |/g'
fi

# ---- optional: the gate ------------------------------------------------------
if [ "${1:-}" = "--full" ]; then
    echo "--- audit gate ---"
    GATE="$(bash verification/audit-gate.sh 2>&1 | tail -1)"
    say "gate" "${GATE}"
    check "gate passes" "$(printf '%s' "${GATE}" | sed -n 's/.*PASS=\([0-9]*\).*/\1/p')" "${CLAIM_GATE_PASS}"
fi

echo "--------------------------------------------------------------------------"
if [ "${DRIFT}" -eq 0 ]; then
    echo "figures match the proposal."
    exit 0
fi
echo "DRIFT in ${DRIFT} figure(s): update docs/grants/*.md before sending."
exit 1
