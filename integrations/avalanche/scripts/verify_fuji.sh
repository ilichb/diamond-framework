#!/usr/bin/env bash
# Fuji phase-1 verifier: read the five wiring facts back from the chain and
# compare them with the `[fuji] key=value` transcript emitted by
# DeployFujiPhase1.s.sol.
#
#   bash scripts/verify_fuji.sh /tmp/fuji_phase1_transcript.txt
#   FUJI_RPC_URL=https://... bash scripts/verify_fuji.sh transcript.txt
#   bash scripts/verify_fuji.sh transcript.txt --out-dir scripts
#
# On mismatch it prints one explicit diff per fact and exits 1. On success it
# writes `fuji_<date>_verify.txt` with the five on-chain reads and `OK`.
# The default output directory is /tmp: a verification run must not dirty the
# repository. `--out-dir` is restricted to /tmp or a path ending in `scripts/`.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: verify_fuji.sh <transcript> [--rpc-url URL] [--out-dir DIR]

  <transcript>       file containing the `[fuji] key=value` lines printed by
                     DeployFujiPhase1.s.sol
  --rpc-url URL      Fuji RPC endpoint (default: $FUJI_RPC_URL, then
                     ~/.config/avip/fuji_rpc.txt)
  --out-dir DIR      where to write fuji_<date>_verify.txt; must be /tmp or a
                     directory named scripts (default: /tmp)
EOF
}

case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
esac

TRANSCRIPT="${1:-}"
if [ -z "$TRANSCRIPT" ]; then
    usage >&2
    exit 2
fi
shift || true

RPC_URL="${FUJI_RPC_URL:-}"
OUT_DIR="${OUT_DIR:-/tmp}"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --rpc-url)
            [ "$#" -ge 2 ] || { echo "verify_fuji: --rpc-url needs a value" >&2; exit 2; }
            RPC_URL=$2
            shift 2
            ;;
        --out-dir)
            [ "$#" -ge 2 ] || { echo "verify_fuji: --out-dir needs a value" >&2; exit 2; }
            OUT_DIR=$2
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "verify_fuji: unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

die() {
    printf 'verify_fuji: %s\n' "$*" >&2
    exit 1
}

[ -r "$TRANSCRIPT" ] || die "transcript not readable: $TRANSCRIPT"
command -v cast >/dev/null 2>&1 || die "cast is not in PATH"

# The runbook keeps the endpoint in ~/.config/avip/fuji_rpc.txt. Read it only
# when neither the argument nor the environment supplied one; never print it.
if [ -z "$RPC_URL" ] && [ -r "$HOME/.config/avip/fuji_rpc.txt" ]; then
    RPC_URL="$(tr -d '\r\n' < "$HOME/.config/avip/fuji_rpc.txt")"
fi
[ -n "$RPC_URL" ] || die "no RPC URL: pass --rpc-url or set FUJI_RPC_URL"

case "$OUT_DIR" in
    /tmp|/tmp/*|scripts|scripts/|*/scripts|*/scripts/) ;;
    *) die "refusing output outside /tmp or a scripts/ directory: $OUT_DIR" ;;
esac

# First `[fuji] key=value` line for `key`, or an empty string. Forge indents
# the log lines of a script run, so the match starts after any leading spaces.
line_for() {
    awk -v key="$1" '
        {
            line = $0
            sub(/^[[:space:]]+/, "", line)
            if (index(line, "[fuji] " key "=") == 1) {
                print line
                exit
            }
        }
    ' "$TRANSCRIPT"
}

# Value after the first `=`; returns 1 when the key is absent.
value_for() {
    local key=$1 line
    line="$(line_for "$key")" || true
    [ -n "$line" ] || return 1
    printf '%s\n' "${line#*=}"
}

for key in chain.id chain.name registry vault manager sequencer verifier TENSOR_SIZE status; do
    value_for "$key" >/dev/null || die "transcript has no [fuji] $key=..."
done

[ "$(value_for status)" = "ok" ] || die "transcript status is not ok"
[ "$(value_for chain.id)" = "43113" ] || die "transcript is not Fuji (chain.id=$(value_for chain.id))"

CHAIN_ID_ONCHAIN="$(cast chain-id --rpc-url "$RPC_URL")" ||
    die "cast chain-id failed (is the RPC reachable?)"
[ "$CHAIN_ID_ONCHAIN" = "43113" ] || die "RPC is not Fuji (chain-id=$CHAIN_ID_ONCHAIN)"
[ "$CHAIN_ID_ONCHAIN" = "$(value_for chain.id)" ] ||
    die "transcript chain.id=$(value_for chain.id) does not match RPC chain-id=$CHAIN_ID_ONCHAIN"

REGISTRY="$(value_for registry)"
VAULT="$(value_for vault)"
MANAGER="$(value_for manager)"
SEQUENCER="$(value_for sequencer)"
VERIFIER="$(value_for verifier)"
TENSOR_SIZE="$(value_for TENSOR_SIZE)"
normalize_addr() {
    printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]'
}

to_dec() {
    case "$1" in
        0x*) printf '%d\n' "$1" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

MISMATCHES=0
check_eq() {
    local label=$1 actual=$2 expected=$3
    if [ "$actual" != "$expected" ]; then
        printf 'MISMATCH %s\n  on-chain:   %s\n  transcript: %s\n' \
            "$label" "$actual" "$expected" >&2
        MISMATCHES=$((MISMATCHES + 1))
    fi
}

# The five reads A2 requires. `cast call` is the only network access here.
ONCHAIN_SEQUENCER="$(cast call --rpc-url "$RPC_URL" "$REGISTRY" "sequencer()(address)")" ||
    die "registry.sequencer() failed"
ONCHAIN_TENSOR="$(cast call --rpc-url "$RPC_URL" "$REGISTRY" "TENSOR_SIZE()(uint32)")" ||
    die "registry.TENSOR_SIZE() failed"
ONCHAIN_CUSTODY="$(cast call --rpc-url "$RPC_URL" "$MANAGER" "custody()(address)")" ||
    die "manager.custody() failed"
ONCHAIN_MANAGER="$(cast call --rpc-url "$RPC_URL" "$VAULT" "manager()(address)")" ||
    die "vault.manager() failed"
ONCHAIN_VERIFIER="$(cast call --rpc-url "$RPC_URL" "$REGISTRY" "verifier()(address)")" ||
    die "registry.verifier() failed"

check_eq "registry.sequencer()" \
    "$(normalize_addr "$ONCHAIN_SEQUENCER")" "$(normalize_addr "$SEQUENCER")"
check_eq "registry.TENSOR_SIZE()" \
    "$(to_dec "$ONCHAIN_TENSOR")" "$(to_dec "$TENSOR_SIZE")"
check_eq "manager.custody()" \
    "$(normalize_addr "$ONCHAIN_CUSTODY")" "$(normalize_addr "$VAULT")"
check_eq "vault.manager()" \
    "$(normalize_addr "$ONCHAIN_MANAGER")" "$(normalize_addr "$MANAGER")"
check_eq "registry.verifier()" \
    "$(normalize_addr "$ONCHAIN_VERIFIER")" "$(normalize_addr "$VERIFIER")"

# Not one of the five, but free and useful: the delta cap is a constant the
# contract exposes alongside TENSOR_SIZE. Check it when the transcript has it.
MAX_DELTA_TRANSCRIPT="$(value_for MAX_DELTA_ENTRIES || true)"
if [ -n "$MAX_DELTA_TRANSCRIPT" ]; then
    ONCHAIN_MAX_DELTA="$(cast call --rpc-url "$RPC_URL" "$REGISTRY" "MAX_DELTA_ENTRIES()(uint32)")" ||
        die "registry.MAX_DELTA_ENTRIES() failed"
    check_eq "registry.MAX_DELTA_ENTRIES()" \
        "$(to_dec "$ONCHAIN_MAX_DELTA")" "$(to_dec "$MAX_DELTA_TRANSCRIPT")"
fi

if [ "$MISMATCHES" -ne 0 ]; then
    printf 'verify_fuji: %s mismatch(es); no verification file written\n' "$MISMATCHES" >&2
    exit 1
fi

mkdir -p "$OUT_DIR"
umask 077
OUT_FILE="$OUT_DIR/fuji_$(date +%Y%m%d_%H%M%S)_verify.txt"
{
    printf 'transcript=%s\n' "$TRANSCRIPT"
    printf 'chain.id=%s\n' "$CHAIN_ID_ONCHAIN"
    printf 'registry.sequencer=%s\n' "$ONCHAIN_SEQUENCER"
    printf 'registry.TENSOR_SIZE=%s\n' "$ONCHAIN_TENSOR"
    printf 'manager.custody=%s\n' "$ONCHAIN_CUSTODY"
    printf 'vault.manager=%s\n' "$ONCHAIN_MANAGER"
    printf 'registry.verifier=%s\n' "$ONCHAIN_VERIFIER"
    printf 'status=OK\n'
} >"$OUT_FILE"

printf 'OK: %s\n' "$OUT_FILE"
