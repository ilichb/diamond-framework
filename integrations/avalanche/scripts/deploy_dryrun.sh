#!/usr/bin/env bash
# M7a/M8 dry run: `DeployRegistry.s.sol`, `DeployValidatorManager.s.sol` and
# `DeployStakeVault.s.sol` against the environment, one fresh process per case.
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
#   G  vault, no environment                   MissingRole("TOKEN"), nothing deployed
#   H  vault, TOKEN/SINK/WAD_PER_UNIT          the custody half, left unbound (§5.12)
#   I  manager, CUSTODY that cannot bind       the handshake fails the deployment
#   J  registry, GUARDIAN == SEQUENCER         RolesCollapsed, nothing deployed
#   K  registry, GUARDIAN = 0x0                MissingRole("GUARDIAN")
#   L  registry, malformed SOURCE_CHAIN_ID     a revert, never the silent default
#   M  registry, origin pinned                 the environment wins
#   N  registry, FORMULA_DIGEST = 0x0          ZeroFormulaDigest
#   O  transport, source side                  three endpoints, one routing table each
#   P  phase 1, end to end                     registry + vault + manager, origin.* logged
#   Q  preflight_fase2.sh --offline            the artifact is the post-M-15 one
#
# Nothing is broadcast: without `--rpc-url ... --broadcast`, `forge script`
# simulates locally. No RPC endpoint, no keys, no funds, no network (`--offline`),
# so the addresses are the canonical first CREATE of `anvil` account 0 and the
# transcript is byte-stable across machines.
#
# On success it rewrites `scripts/deploy_dryrun_output.txt`. The transcript keeps
# only the `[m7a]` and `[m8]` lines the scripts log, so gas and timings never
# enter it; on any failed expectation the script exits non-zero and writes
# nothing.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=scripts/deploy_dryrun_output.txt
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# `anvil`'s first four accounts, and the address a first `CREATE` from account 0
# lands on in a fresh EVM (each case is a fresh process, so this is fixed).
ANVIL_0=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
ANVIL_1=0x70997970C51812dc3A010C7d01b50e0d17dc79C8
ANVIL_2=0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
ANVIL_3=0x90F79bf6EB2c4f870365E785982E1f101E93b906
FIRST_CREATE=0x5FbDB2315678afecb367f032d93F642f64180aa3

REGISTRY_SCRIPT=scripts/DeployRegistry.s.sol:DeployRegistry
MANAGER_SCRIPT=scripts/DeployValidatorManager.s.sol:DeployValidatorManager
# M8 (§5.12): the custody half of the handshake, plus the manager that completes
# it. The vault script logs `[m8]`, so `run_case` keeps both tags.
VAULT_SCRIPT=scripts/DeployStakeVault.s.sol:DeployStakeVault
TRANSPORT_SCRIPT=scripts/DeployTransport.s.sol:DeployTransport
# Phase 1 end to end: the only script that deploys registry + vault + manager in
# one run, and therefore the one phase 2 re-runs with a Safe as SLASH_AUTHORITY.
FUJI_SCRIPT=scripts/DeployFujiPhase1.s.sol:DeployFujiPhase1
# The origin pair the registry pins at construction (T-2/M-15) and the phase-1
# script must log. Same values as case A: the defaults of `DeployCommon`.
ORIGIN_CHAIN=0xce12864578eb11634416932021724652c9a481fbf6a42ba77cde799fad091bc1
ORIGIN_FORMULA=0x403af787fee703ec18c440a91e8405b72dc55ea700ec557263baaab0e24a4cfc

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
    env -u DEPLOYER -u SEQUENCER -u GUARDIAN -u SLASH_AUTHORITY -u VERIFIER -u REGISTRY \
        -u CUSTODY -u TOKEN -u SINK -u WAD_PER_UNIT \
        -u SOURCE_CHAIN_ID -u FORMULA_DIGEST \
        -u TRANSPORT_SIDE -u TELEPORTER -u LOCAL_BLOCKCHAIN_ID -u PEER_BLOCKCHAIN_ID \
        -u PEER_RELAY -u PEER_COLLUSION -u PEER_SLASHING -u ALERTER -u NOTIFIER -u MANAGER \
        ${env_args[@]+"${env_args[@]}"} "$@" >"$out" 2>&1
    echo $? >"$TMP_DIR/$tag.status"
    set -e

    grep -E '^  \[(m7a|m8|m7d|fuji)\] ' "$out" >"$TMP_DIR/$tag.log" || true
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
expect_line A "  [m7a] role.guardian=$ANVIL_3"
expect_line A "  [m7a] role.verifier=0x0000000000000000000000000000000000000000"
expect_line A "  [m7a] check.CHANGE_DELAY=172800"
# M-15: the origin is a deployment fact, so the no-environment run pins it too.
expect_line A "  [m7a] origin.sourceChainId=0xce12864578eb11634416932021724652c9a481fbf6a42ba77cde799fad091bc1"
expect_line A "  [m7a] origin.formulaDigest=0x403af787fee703ec18c440a91e8405b72dc55ea700ec557263baaab0e24a4cfc"
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
# M9a: `GUARDIAN` is unset here on purpose. The guardian is the one role with no
# zero default, so it falls back to anvil 3 rather than to the environment's
# sequencer — a collapse the script refuses (`RolesCollapsed`).
expect_line C "  [m7a] role.guardian=$ANVIL_3"

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

# ---------------------------------------------------------------- case G
# M8's vault script with no environment: `TOKEN` is the first input it cannot
# invent, and the refusal names it. A vault pointed at no token escrows nothing.
run_case G -- forge script "$VAULT_SCRIPT" --offline
expect_failure G
expect_error G 'Error: script failed: MissingRole("TOKEN")'
grep -q '\[m8\] AVIPStakeVault=' "$TMP_DIR/G.log" &&
    fail "G: nothing must be deployed before the inputs are resolved"

# ---------------------------------------------------------------- case H
# The vault script with its three inputs: the custody half of the handshake, and
# the one state it must be in when the manager script is handed its address.
ENV_H=(DEPLOYER=$ANVIL_0 TOKEN=$ANVIL_1 SINK=$ANVIL_2 WAD_PER_UNIT=1000000000000)
run_case H ${ENV_H[@]+"${ENV_H[@]}"} -- forge script "$VAULT_SCRIPT" --offline
expect_ok H
expect_line H "  [m8] script=DeployStakeVault"
expect_line H "  [m8] role.token=$ANVIL_1"
expect_line H "  [m8] role.sink=$ANVIL_2"
expect_line H "  [m8] check.wadPerUnit=1000000000000"
expect_line H "  [m8] check.manager=unbound"
expect_line H "  [m8] status=ok"

# ---------------------------------------------------------------- case I
# The manager script handed a `CUSTODY` that cannot answer the handshake. In a
# fresh process the vault case H created does not exist, so any address here is
# either empty or has no `bindManager`: the manager's constructor calls it, gets
# nothing, and the deployment fails instead of producing a manager with no
# custody (§5.12).
ENV_I=(DEPLOYER=$ANVIL_0 REGISTRY=$FIRST_CREATE CUSTODY=$ANVIL_2)
run_case I ${ENV_I[@]+"${ENV_I[@]}"} -- forge script "$MANAGER_SCRIPT" --offline
expect_failure I
expect_error I "Error: script failed: call to non-contract address $ANVIL_2"
grep -q 'role.custody=' "$TMP_DIR/I.log" &&
    fail "I: a custody that cannot answer the bind must stop the deployment"

# ---------------------------------------------------------------- case J
# M9a. The pair collapsed: `RolesCollapsed` is not a busybody check. A registry
# whose guardian is its own sequencer has no second authority at all, so the
# delay would merely announce the capture it was installed to prevent — and the
# refusal below also proves `GUARDIAN` is read, since both addresses are pinned
# by the environment here rather than defaulted.
ENV_J=(DEPLOYER=$ANVIL_0 SEQUENCER=$ANVIL_2 GUARDIAN=$ANVIL_2)
run_case J ${ENV_J[@]+"${ENV_J[@]}"} -- forge script "$REGISTRY_SCRIPT" --offline
expect_failure J
expect_error J 'Error: script failed: RolesCollapsed("GUARDIAN", "SEQUENCER")'
grep -q 'AVIPRegistry=' "$TMP_DIR/J.log" &&
    fail "J: a collapsed pair must be refused before anything is deployed"

# ---------------------------------------------------------------- case K
# The guardian is the one role with no zero default, in the contract and in the
# script: an explicit zero is refused with the name of the variable instead of
# being replaced by anvil 3 (which is what an absent variable gets).
ENV_K=(DEPLOYER=$ANVIL_0 SEQUENCER=$ANVIL_1 GUARDIAN=0x0000000000000000000000000000000000000000)
run_case K ${ENV_K[@]+"${ENV_K[@]}"} -- forge script "$REGISTRY_SCRIPT" --offline
expect_failure K
expect_error K 'Error: script failed: MissingRole("GUARDIAN")'
grep -q 'AVIPRegistry=' "$TMP_DIR/K.log" &&
    fail "K: an explicit zero guardian must be refused, not defaulted"

# ---------------------------------------------------------------- case L
# M-15. The origin is read with the same strict parser as the roles: a malformed
# `SOURCE_CHAIN_ID` must stop the deployment, never fall back to the C-Chain
# default and silently attribute every future epoch to the wrong chain.
ENV_L=(DEPLOYER=$ANVIL_0 SOURCE_CHAIN_ID=0xnot-a-bytes32)
run_case L ${ENV_L[@]+"${ENV_L[@]}"} -- forge script "$REGISTRY_SCRIPT" --offline
expect_failure L
expect_error L 'failed parsing "0xnot-a-bytes32"'
grep -q 'AVIPRegistry=' "$TMP_DIR/L.log" &&
    fail "L: a malformed origin must not be replaced by the default"

# ---------------------------------------------------------------- case M
# The environment wins over the default, and the transcript carries the origin
# the registry was actually deployed with — which is the value every epoch will
# have to declare in `postCommitment`.
ORIGIN_M=0x1111111111111111111111111111111111111111111111111111111111111111
FORMULA_M=0x2222222222222222222222222222222222222222222222222222222222222222
ENV_M=(DEPLOYER=$ANVIL_0 SOURCE_CHAIN_ID=$ORIGIN_M FORMULA_DIGEST=$FORMULA_M)
run_case M ${ENV_M[@]+"${ENV_M[@]}"} -- forge script "$REGISTRY_SCRIPT" --offline
expect_ok M
expect_line M "  [m7a] origin.sourceChainId=$ORIGIN_M"
expect_line M "  [m7a] origin.formulaDigest=$FORMULA_M"
expect_line M "  [m7a] status=ok"

# ---------------------------------------------------------------- case N
# A zero formula reaches the contract and is refused there (`ZeroFormulaDigest`),
# so the script cannot deploy a registry whose tensor has no defined meaning.
ENV_N=(DEPLOYER=$ANVIL_0 FORMULA_DIGEST=0x0000000000000000000000000000000000000000000000000000000000000000)
run_case N ${ENV_N[@]+"${ENV_N[@]}"} -- forge script "$REGISTRY_SCRIPT" --offline
expect_failure N
expect_error N 'Error: script failed: ZeroFormulaDigest()'
grep -q 'AVIPRegistry=' "$TMP_DIR/N.log" &&
    fail "N: a zero formula must be refused before anything is deployed"

# ---------------------------------------------------------------- case O
# The transport's source half: three endpoints, one routing entry each. The peer
# addresses are inputs (a deployment is told them, §4), and the registry is a
# wiring target only — a dry run publishes nothing.
PEER_CHAIN=0x$(printf '%064x' 2827)
ENV_O=(
    TRANSPORT_SIDE=source
    LOCAL_BLOCKCHAIN_ID=0xce12864578eb11634416932021724652c9a481fbf6a42ba77cde799fad091bc1
    PEER_BLOCKCHAIN_ID=$PEER_CHAIN
    PEER_RELAY=0x000000000000000000000000000000000000b0b1
    PEER_COLLUSION=0x000000000000000000000000000000000000b0b2
    PEER_SLASHING=0x000000000000000000000000000000000000b0b3
    REGISTRY=$FIRST_CREATE
    SEQUENCER=$ANVIL_1
    ALERTER=$ANVIL_2
    NOTIFIER=$ANVIL_3
)
run_case O ${ENV_O[@]+"${ENV_O[@]}"} -- forge script "$TRANSPORT_SCRIPT" --offline
expect_ok O
expect_line O "  [m7d] side=source"
expect_line O "  [m7d] teleporter=$FIRST_CREATE"
expect_line O "  [m7d] peerBlockchainId=$PEER_CHAIN"
expect_line O "  [m7d] status=ok"

# ---------------------------------------------------------------- case P
# Phase 1 end to end on the local chain: this is the script phase 2 re-runs with
# a Safe as SLASH_AUTHORITY. The `origin.*` rows are the half P-40 was missing —
# without them `verify_fuji.sh` cannot verify the deployment it just made, so a
# correct phase-2 registry would still fail verification.
ENV_P=(
    DEPLOYER=$ANVIL_0
    SEQUENCER=$ANVIL_1
    SLASH_AUTHORITY=$ANVIL_2
    TOKEN=$ANVIL_2
    SINK=$ANVIL_3
    WAD_PER_UNIT=1000000000000
    GUARDIAN=$ANVIL_3
)
run_case P ${ENV_P[@]+"${ENV_P[@]}"} -- forge script "$FUJI_SCRIPT" --offline
expect_ok P
expect_line P "  [fuji] chain.id=31337"
expect_line P "  [fuji] manager=0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0"
expect_line P "  [fuji] slash_authority=$ANVIL_2"
expect_line P "  [fuji] origin.sourceChainId=$ORIGIN_CHAIN"
expect_line P "  [fuji] origin.formulaDigest=$ORIGIN_FORMULA"
expect_line P "  [fuji] status=ok"

# ---------------------------------------------------------------- case Q
# The phase-2 preflight, offline: the artifacts must already be the post-M-15
# ones, because a stale build is what P-40 is made of and it is invisible in the
# source. The on-chain half needs a Safe and an RPC, so it is not exercised here.
run_case Q -- bash scripts/preflight_fase2.sh --offline
expect_ok Q
expect_error Q "preflight: PASS="
expect_error Q " FAIL=0 "

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
M7a/M8 dry run: DeployRegistry.s.sol, DeployValidatorManager.s.sol and
DeployStakeVault.s.sol
========================================================================

Produced by scripts/deploy_dryrun.sh, which runs the real CLI — offline, no RPC,
no keys, nothing broadcast — once per case. Every case gets its own process
because the environment is process-wide (`vm.setEnv` outlives the test that wrote
it; see the note in test/DeployScripts.t.sol). This is therefore where the
environment → Plan mapping is asserted, and every case also checks the values it
must produce. `--offline` and a fresh EVM are why the addresses repeat from run to
run: a dry run deploys to nothing.

Cases G to I are M8's (§5.12): the vault script deploys the custody half of the
handshake and leaves it unbound, and the manager script can only complete the
handshake against a custody that answers it.

Cases J and K are M9a's (§12.1.2): the authority pair the registry now carries is
refused when it collapses (GUARDIAN == SEQUENCER — the capture the proposal delay
exists to prevent, since one key would be proposing its own continuation) and when
the guardian is the zero address. Neither refusal creates a contract.

Cases L to N are M-15's: the registry's origin (`SOURCE_CHAIN_ID`,
`FORMULA_DIGEST`) is read as strictly as a role, it wins over the reference
default when the environment sets it, and a zero formula is refused by the
contract (`ZeroFormulaDigest`) rather than deployed.

Gas and timings are deliberately absent — the transcript keeps only the `[m7a]`
and `[m8]` lines the scripts log — so it is byte-stable and carries no cost claim.
HEADER

    section A "DeployRegistry, no environment" \
        "the defaults the contract documents: anvil 0 deploys, anvil 1 sequences, anvil 3 guards, no verifier" \
        "forge script $REGISTRY_SCRIPT --offline"
    section B "DeployValidatorManager, no environment" \
        "MissingRole(\"REGISTRY\"): the one role with no default is refused, not guessed" \
        "forge script $MANAGER_SCRIPT --offline"
    section C "DeployRegistry, roles pinned" \
        "the environment wins over the defaults: anvil 2 sequences, anvil 1 verifies, anvil 3 guards unasked" \
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
    section G "DeployStakeVault, no environment" \
        "MissingRole(\"TOKEN\"): the inputs a vault cannot invent are refused, not guessed" \
        "forge script $VAULT_SCRIPT --offline"
    section H "DeployStakeVault, token/sink/scale pinned" \
        "the custody half of §5.12, wired and left unbound for the manager to bind" \
        "${ENV_H[*]} forge script $VAULT_SCRIPT --offline"
    section I "DeployValidatorManager, a custody that cannot bind" \
        "the handshake is not a formality: a CUSTODY with no code fails the deployment" \
        "${ENV_I[*]} forge script $MANAGER_SCRIPT --offline"
    section J "DeployRegistry, GUARDIAN pinned to the SEQUENCER" \
        "RolesCollapsed(\"GUARDIAN\", \"SEQUENCER\"): the capture the delay exists to prevent, refused" \
        "${ENV_J[*]} forge script $REGISTRY_SCRIPT --offline"
    section K "DeployRegistry, GUARDIAN pinned to zero" \
        "MissingRole(\"GUARDIAN\"): the one role with no zero default is refused, not guessed" \
        "${ENV_K[*]} forge script $REGISTRY_SCRIPT --offline"
    section L "DeployRegistry, malformed SOURCE_CHAIN_ID" \
        "a revert: the origin is parsed as strictly as the roles, never defaulted" \
        "${ENV_L[*]} forge script $REGISTRY_SCRIPT --offline"
    section M "DeployRegistry, origin pinned" \
        "the environment wins: the transcript carries the chain and formula every epoch must declare" \
        "${ENV_M[*]} forge script $REGISTRY_SCRIPT --offline"
    section N "DeployRegistry, FORMULA_DIGEST pinned to zero" \
        "ZeroFormulaDigest: a registry whose tensor has no defined meaning is refused" \
        "${ENV_N[*]} forge script $REGISTRY_SCRIPT --offline"
    section O "DeployTransport, source side" \
        "three endpoints on one chain, each with one routing entry; the local mock messenger makes it runnable offline" \
        "${ENV_O[*]} forge script $TRANSPORT_SCRIPT --offline"
    section P "DeployFujiPhase1, end to end" \
        "registry + vault + manager in one run, with the origin rows verify_fuji.sh compares against the chain" \
        "${ENV_P[*]} forge script $FUJI_SCRIPT --offline"
    section Q "preflight_fase2.sh --offline" \
        "the artifact about to be deployed is the post-M-15 one: the check P-40 was missing" \
        "bash scripts/preflight_fase2.sh --offline"

    cat <<'FOOTER'

WHAT THIS IS NOT
  A deployment. Nothing here touches an RPC endpoint, and the addresses are the
  ones a fresh EVM hands out: they are not, and must not be presented as, Fuji
  addresses. Phase 1 of docs/architecture/avalanche-integration.md §6 is the Fuji
  deployment, and it is deliberately not automated by this milestone.
FOOTER
} >"$OUT"

echo "deploy_dryrun: 17 cases ok; wrote $OUT"

