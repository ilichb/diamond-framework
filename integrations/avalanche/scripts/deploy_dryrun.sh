#!/usr/bin/env bash
# M7a dry run: `DeployRegistry.s.sol` and `DeployValidatorManager.s.sol` against
# the environment, one fresh process per case.
#
#   bash scripts/deploy_dryrun.sh
#
# WHY THIS IS A SHELL SCRIPT AND NOT A TEST
# -----------------------------------------
# `vm.setEnv` is process-wide, it outlives the test that wrote it, and the
# precedence of a later write over an earlier one is not something a test can
# rely on (see the note in `test/DeployScripts.t.sol`, which is why that suite
# drives `deploy(Plan)` instead). The environment → `Plan` mapping — the part of
# the scripts that *does* read the environment — is a fresh-process property, so
# it is asserted here, where every case gets a pristine process and the real CLI
# is exercised end to end.
#
# WHAT IT CHECKS
# --------------
#   A  registry, no environment                the anvil defaults, no verifier
#   B  manager, no environment                 MissingRole("REGISTRY")
#   C  registry, DEPLOYER/SEQUENCER/VERIFIER   the environment wins over the defaults
#   D  manager, chained on C's registry        the hand-off a Fuji deployment performs
#   E  registry, SEQUENCER malformed           reverts; never the silent default
#   F  registry, --chain 43114                 MainnetRefused
#
# Nothing is broadcast: without `--rpc-url ... --broadcast`, `forge script`
# simulates locally. No RPC endpoint, no keys, no funds, no network (`--offline`),
# so the addresses are the canonical first CREATE of `anvil` account 0 and the
# transcript is byte-stable across machines.
#
# On success it rewrites `scripts/deploy_dryrun_output.txt`. The transcript keeps
# only the `[m7a]` lines the scripts log, so gas and timings never enter it; on
# any failed expectation the script exits non-zero and writes nothing.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=scripts/deploy_dryrun_output.txt
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# `anvil`'s first three accounts, and the address a first `CREATE` from account 0
# lands on in a fresh EVM (each case is a fresh process, so this is fixed).
ANVIL_0=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
ANVIL_1=0x70997970C51812dc3A010C7d01b50e0d17dc79C8
ANVIL_2=0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
FIRST_CREATE=0x5FbDB2315678afecb367f032d93F642f64180aa3

REGISTRY_SCRIPT=scripts/DeployRegistry.s.sol:DeployRegistry
MANAGER_SCRIPT=scripts/DeployValidatorManager.s.sol:DeployValidatorManager

FAILURES=0
fail() {
    echo "FAIL: $*" >&2
    FAILURES=$((FAILURES + 1))
}

# run_case <tag> [VAR=value...] -- <forge args...>
# Runs with every role variable unset unless the case sets it, keeps the raw
# output in <tag>.out, the exit status in <tag>.status, and the script's own
# transcript lines in <tag>.log.
run_case() {
    local tag=$1
    shift
    local env_args=()
    while [ "$1" != "--" ]; do
        env_args+=("$1")
        shift
    done
    shift

    local out="$TMP_DIR/$tag.out"
    set +e
    env -u DEPLOYER -u SEQUENCER -u SLASH_AUTHORITY -u VERIFIER -u REGISTRY \
        ${env_args[@]+"${env_args[@]}"} "$@" >"$out" 2>&1
    echo $? >"$TMP_DIR/$tag.status"
    set -e

    grep -E '^  \[m7a\] ' "$out" >"$TMP_DIR/$tag.log" || true
}

expect_ok() {
    local tag=$1 status
    status=$(cat "$TMP_DIR/$tag.status")
    [ "$status" -eq 0 ] || fail "$tag: expected success, exit status $status"
}

expect_failure() {
    local tag=$1 status
    status=$(cat "$TMP_DIR/$tag.status")
    [ "$status" -ne 0 ] || fail "$tag: expected a failure, exit status 0"
}

expect_line() {
    local tag=$1 line=$2
    grep -qxF -- "$line" "$TMP_DIR/$tag.log" || fail "$tag: expected line: $line"
}

expect_error() {
    local tag=$1 line=$2
    grep -qF -- "$line" "$TMP_DIR/$tag.out" || fail "$tag: expected error: $line"
}


# ---------------------------------------------------------------- case A
# No environment at all: the defaults the scripts document must appear.
run_case A -- forge script "$REGISTRY_SCRIPT" --offline
expect_ok A
expect_line A "  [m7a] sender=$ANVIL_0"
expect_line A "  [m7a] AVIPRegistry=$FIRST_CREATE"
expect_line A "  [m7a] role.sequencer=$ANVIL_1"
expect_line A "  [m7a] role.verifier=0x0000000000000000000000000000000000000000"
expect_line A "  [m7a] status=ok"

# ---------------------------------------------------------------- case B
# `REGISTRY` is the one role with no default: the manager must refuse, not guess.
run_case B -- forge script "$MANAGER_SCRIPT" --offline
expect_failure B
expect_error B 'Error: script failed: MissingRole("REGISTRY")'

# ---------------------------------------------------------------- case C
# The environment wins over the defaults.
ENV_C=(DEPLOYER=$ANVIL_0 SEQUENCER=$ANVIL_2 VERIFIER=$ANVIL_1)
run_case C ${ENV_C[@]+"${ENV_C[@]}"} -- forge script "$REGISTRY_SCRIPT" --offline
expect_ok C
expect_line C "  [m7a] role.sequencer=$ANVIL_2"
expect_line C "  [m7a] role.verifier=$ANVIL_1"

# ---------------------------------------------------------------- case D
# The hand-off: the manager is pointed at the registry case C created, which is
# exactly how a Fuji deployment would be chained (and why it is a separate
# process here too).
ENV_D=(DEPLOYER=$ANVIL_0 SLASH_AUTHORITY=$ANVIL_1 REGISTRY=$FIRST_CREATE)
run_case D ${ENV_D[@]+"${ENV_D[@]}"} -- forge script "$MANAGER_SCRIPT" --offline
expect_ok D
expect_line D "  [m7a] AVIPValidatorManager=$FIRST_CREATE"
expect_line D "  [m7a] role.registry=$FIRST_CREATE"
expect_line D "  [m7a] role.slashAuthority=$ANVIL_1"
expect_line D "  [m7a] status=ok"

# ---------------------------------------------------------------- case E
# A typo must stop the deployment. Falling back to the default here would deploy
# a protocol whose sequencer is a public anvil account.
ENV_E=(SEQUENCER=0xnot-an-address)
run_case E ${ENV_E[@]+"${ENV_E[@]}"} -- forge script "$REGISTRY_SCRIPT" --offline
expect_failure E
expect_error E 'failed parsing "0xnot-an-address"'
grep -q 'role.sequencer=' "$TMP_DIR/E.log" &&
    fail "E: the malformed value must not be replaced by the default"

# ---------------------------------------------------------------- case F
# The guard is in the script, not in an operator's memory.
run_case F -- forge script "$REGISTRY_SCRIPT" --offline --chain 43114
expect_failure F
expect_error F 'Error: script failed: MainnetRefused(43114'

# ------------------------------------------------------------- transcript

if [ "$FAILURES" -ne 0 ]; then
    echo "deploy_dryrun: $FAILURES expectation(s) failed; $OUT left untouched" >&2
    exit 1
fi

# The last `Error:` line of a failing case: the first one is forge's raw
# undecodable-return dump, the last one is the script's own revert.
case_error() {
    grep '^Error: ' "$TMP_DIR/$1.out" | tail -n1 || true
}

section() { # section <tag> <title> <expects> <command>
    printf '\n%s. %s\n' "$1" "$2"
    printf '  expects: %s\n' "$3"
    printf '  $ %s\n' "$4"
    if [ -s "$TMP_DIR/$1.log" ]; then
        cat "$TMP_DIR/$1.log"
    else
        printf '  <the script stopped before it logged anything>\n'
    fi
    local err
    err=$(case_error "$1")
    [ -z "$err" ] || printf '  %s\n' "$err"
}

{
    cat <<'HEADER'
M7a dry run: DeployRegistry.s.sol and DeployValidatorManager.s.sol
==================================================================

Produced by scripts/deploy_dryrun.sh, which runs the real CLI — offline, no RPC,
no keys, nothing broadcast — once per case. Every case gets its own process
because the environment is process-wide (`vm.setEnv` outlives the test that wrote
it; see the note in test/DeployScripts.t.sol). This is therefore where the
environment → Plan mapping is asserted, and every case also checks the values it
must produce. `--offline` and a fresh EVM are why the addresses repeat from run to
run: a dry run deploys to nothing.

Gas and timings are deliberately absent — the transcript keeps only the `[m7a]`
lines the scripts log — so it is byte-stable and carries no cost claim.
HEADER

    section A "DeployRegistry, no environment" \
        "the defaults the contract documents: anvil 0 deploys, anvil 1 sequences, no verifier" \
        "forge script $REGISTRY_SCRIPT --offline"
    section B "DeployValidatorManager, no environment" \
        "MissingRole(\"REGISTRY\"): the one role with no default is refused, not guessed" \
        "forge script $MANAGER_SCRIPT --offline"
    section C "DeployRegistry, roles pinned" \
        "the environment wins over the defaults: anvil 2 sequences, anvil 1 verifies" \
        "${ENV_C[*]} forge script $REGISTRY_SCRIPT --offline"
    section D "DeployValidatorManager, chained on C's registry" \
        "the address C created is wired in, and anvil 1 may slash" \
        "${ENV_D[*]} forge script $MANAGER_SCRIPT --offline"
    section E "DeployRegistry, malformed SEQUENCER" \
        "a revert: a typo must never be replaced by the default" \
        "${ENV_E[*]} forge script $REGISTRY_SCRIPT --offline"
    section F "DeployRegistry, C-Chain mainnet" \
        "MainnetRefused(43114): the guard fires before a single role is read" \
        "forge script $REGISTRY_SCRIPT --offline --chain 43114"

    cat <<'FOOTER'

WHAT THIS IS NOT
  A deployment. Nothing here touches an RPC endpoint, and the addresses are the
  ones a fresh EVM hands out: they are not, and must not be presented as, Fuji
  addresses. Phase 1 of docs/architecture/avalanche-integration.md §6 is the Fuji
  deployment, and it is deliberately not automated by this milestone.
FOOTER
} >"$OUT"

echo "deploy_dryrun: 6 cases ok; wrote $OUT"

