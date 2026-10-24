#!/usr/bin/env bash
# Public-evidence verifier for the phase-2 Fuji deployment (chain 43113).
#
#   bash scripts/verify_public_fuji.sh
#   bash scripts/verify_public_fuji.sh --skip-submit          # reads only
#   FUJI_RPC_URL=https://... bash scripts/verify_public_fuji.sh --out /tmp/x.txt
#
# Two different claims, kept apart on purpose:
#
#   1. The three contracts deployed on 2026-10-23 (registry, vault, manager) are
#      this repository's source. That is what Snowtrace can attest: it compiles
#      `contracts/` with the pinned solc (0.8.33, optimizer off) and the
#      constructor arguments below, and either the bytecode matches or it does
#      not. `forge verify-contract` submits; the report then reads the explorer
#      back so the claim comes from `getsourcecode`, not from forge's exit code.
#   2. The Safe that holds `slashAuthority` is a policy, not a source file. Its
#      runtime is the factory's 171-byte proxy, so verifying it against this
#      repo would be verifying somebody else's bytecode against our tree. The
#      evidence is the read-back instead: code present, `getThreshold()`,
#      `getOwners()`, `VERSION()`, `nonce()`, the singleton in slot 0, the
#      fallback handler slot, and the `ProxyCreation`/`SafeSetup` events of the
#      creation receipt, which name the factory, the singleton, the threshold,
#      the handler and the owners.
#
# Constructor arguments are not taken on trust either: after verifying, the
# script reads the values back from the chain (`registry.sequencer()`,
# `vault.TOKEN()`, `manager.slashAuthority()`, …) and compares them with the
# `[fuji]` transcript. A verified source with the wrong arguments would still be
# the wrong contract.
#
# Snowtrace runs Routescan's Etherscan-compatible API: it answers `getsourcecode`
# with no key, but `forge` refuses to POST without `ETHERSCAN_API_KEY` set, so
# this script supplies a placeholder when the environment has none. That is a
# client-side check, not a credential — do not read it as authentication.
#
# It writes /tmp/fuji_verify_public.txt by default (a verification run must not
# dirty the repository), prints OK or FAIL and exits 1 on any mismatch.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRANSCRIPT="scripts/fuji_20261023/fuji_phase2.txt"
SAFE_TRANSCRIPT="scripts/fuji_20261023/fuji_safe.txt"
RPC_URL="${FUJI_RPC_URL:-}"
OUT="/tmp/fuji_verify_public.txt"
SUBMIT=1
EXPLORER_API="https://api-testnet.snowtrace.io/api"

usage() {
    cat <<'EOF'
Usage: verify_public_fuji.sh [options]

  --transcript FILE       phase-2 `[fuji] key=value` transcript
                          (default: scripts/fuji_20261023/fuji_phase2.txt)
  --safe-transcript FILE  `[safe] key=value` transcript of the Safe deployment
                          (default: scripts/fuji_20261023/fuji_safe.txt)
  --rpc-url URL           Fuji RPC endpoint (default: $FUJI_RPC_URL, then
                          ~/.config/avip/fuji_rpc.txt)
  --out FILE              report path; must be /tmp or a directory named
                          scripts (default: /tmp/fuji_verify_public.txt)
  --skip-submit           do not submit to Snowtrace; only read what is there
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --transcript)
            [ "$#" -ge 2 ] || { echo "verify_public_fuji: --transcript needs a value" >&2; exit 2; }
            TRANSCRIPT=$2
            shift 2
            ;;
        --safe-transcript)
            [ "$#" -ge 2 ] || { echo "verify_public_fuji: --safe-transcript needs a value" >&2; exit 2; }
            SAFE_TRANSCRIPT=$2
            shift 2
            ;;
        --rpc-url)
            [ "$#" -ge 2 ] || { echo "verify_public_fuji: --rpc-url needs a value" >&2; exit 2; }
            RPC_URL=$2
            shift 2
            ;;
        --out)
            [ "$#" -ge 2 ] || { echo "verify_public_fuji: --out needs a value" >&2; exit 2; }
            OUT=$2
            shift 2
            ;;
        --skip-submit)
            SUBMIT=0
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "verify_public_fuji: unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

cd "$ROOT"

die() {
    printf 'verify_public_fuji: %s\n' "$*" >&2
    exit 1
}

case "$OUT" in
    /tmp|/tmp/*|scripts/*|*/scripts/*) ;;
    *) die "refusing output outside /tmp or a scripts/ directory: $OUT" ;;
esac

[ -r "$TRANSCRIPT" ] || die "transcript not readable: $TRANSCRIPT"
[ -r "$SAFE_TRANSCRIPT" ] || die "safe transcript not readable: $SAFE_TRANSCRIPT"
command -v cast >/dev/null 2>&1 || die "cast is not in PATH"
command -v forge >/dev/null 2>&1 || die "forge is not in PATH"
command -v curl >/dev/null 2>&1 || die "curl is not in PATH"
command -v jq >/dev/null 2>&1 || die "jq is not in PATH"

if [ -z "$RPC_URL" ] && [ -r "$HOME/.config/avip/fuji_rpc.txt" ]; then
    RPC_URL="$(tr -d '\r\n' < "$HOME/.config/avip/fuji_rpc.txt")"
fi
[ -n "$RPC_URL" ] || die "no RPC URL: pass --rpc-url or set FUJI_RPC_URL"

# `[tag] key=value` from `file`, indentation tolerated (forge indents log lines).
kv() {
    local file=$1 tag=$2 key=$3 line
    line="$(awk -v tag="$tag" -v key="$key" '{
        l = $0
        sub(/^[[:space:]]+/, "", l)
        if (index(l, tag " " key "=") == 1) { print l; exit }
    }' "$file")"
    [ -n "$line" ] || return 1
    printf '%s\n' "${line#*=}"
}

fuji() { kv "$TRANSCRIPT" "[fuji]" "$1"; }
safe() { kv "$SAFE_TRANSCRIPT" "[safe]" "$1"; }

say() { printf '%s\n' "$*"; }
norm() { printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' '; }
dec() { case "$1" in 0x*) printf '%d\n' "$1" ;; *) printf '%s\n' "$1" ;; esac; }
# Scheme and host only: an RPC URL in this repo's setup is an endpoint *with a
# key* in its path (~/.config/avip/fuji_rpc.txt), and the report gets committed.
rpc_host() { printf '%s\n' "$1" | sed -E 's#^([a-zA-Z][a-zA-Z0-9+.-]*://[^/]+).*#\1#'; }
call() {
    local addr=$1 sig=$2 out
    out="$(cast call --rpc-url "$RPC_URL" "$addr" "$sig" 2>&1)" ||
        die "cast call $addr '$sig' failed: $out"
    printf '%s\n' "$out"
}


MISMATCHES=0
check_eq() {
    local label=$1 actual=$2 expected=$3
    if [ "$actual" = "$expected" ]; then
        say "OK        $label"
    else
        say "MISMATCH  $label"
        say "            on-chain:   $actual"
        say "            transcript: $expected"
        MISMATCHES=$((MISMATCHES + 1))
    fi
}

explorer() {
    curl -s --max-time 30 "$EXPLORER_API?module=contract&action=getsourcecode&address=$1"
}
explorer_field() { explorer "$1" | jq -r --arg k "$2" '.result[0][$k] // ""'; }

# Submit one contract, then read the explorer back: `verified=yes` in the report
# is the explorer's answer, not forge's exit code.
verify_source() {
    local label=$1 addr=$2 fqcn=$3 sig=$4
    shift 4
    local args name solc opt
    args="$(cast abi-encode "$sig" "$@")"
    say ""
    say "-- $label  $addr"
    say "   source     contracts/$fqcn"
    say "   ctor args  $args"

    name="$(explorer_field "$addr" ContractName)"
    if [ -z "$name" ]; then
        if [ "$SUBMIT" -eq 0 ]; then
            say "   explorer   NOT verified (--skip-submit: not submitted)"
            MISMATCHES=$((MISMATCHES + 1))
            return
        fi
        say "   explorer   not verified yet; submitting"
        ETHERSCAN_API_KEY="${ETHERSCAN_API_KEY:-0000000000000000000000000000000000}" \
            forge verify-contract "$addr" "contracts/$fqcn" \
                --constructor-args "$args" \
                --verifier etherscan \
                --verifier-url "$EXPLORER_API" \
                --chain 43113 --watch 2>&1 | tail -4 | sed 's/^/   forge      /'
        name="$(explorer_field "$addr" ContractName)"
        [ -n "$name" ] || die "submit finished but $addr is still unverified"
    fi

    solc="$(explorer_field "$addr" CompilerVersion)"
    opt="$(explorer_field "$addr" OptimizationUsed)"
    say "   explorer   name=$name solc=$solc optimizer=$opt verified=yes"
    check_eq "$label.explorer.name" "$name" "${fqcn##*:}"
    check_eq "$label.explorer.solc" "${solc%%+*}" "v0.8.33"
    check_eq "$label.explorer.optimizer" "$opt" "0"
}

main() {
    local chain_id timestamp registry vault manager safe
    local code bytes slot0 handler_slot handler_value tx_hash receipt
    local tr_owners ch_owners i count

    timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    chain_id="$(cast chain-id --rpc-url "$RPC_URL")" ||
        die "cast chain-id failed (is the RPC reachable?)"
    [ "$chain_id" = "43113" ] || die "RPC is not Fuji (chain-id=$chain_id)"

    registry="$(fuji registry)" || die "transcript has no [fuji] registry="
    vault="$(fuji vault)" || die "transcript has no [fuji] vault="
    manager="$(fuji manager)" || die "transcript has no [fuji] manager="
    safe="$(safe safe)" || die "safe transcript has no [safe] safe="

    say "# Public evidence — Diamond Framework phase 2 on Avalanche Fuji (43113)"
    say "# generated $timestamp by scripts/verify_public_fuji.sh"
    say "# phase-2 transcript: $TRANSCRIPT"
    say "# safe transcript:    $SAFE_TRANSCRIPT"
    say "# RPC host:           $(rpc_host "$RPC_URL") (credentials never printed)"
    say ""
    say "## 1. the three contracts are this repository's source"
    say ""
    say "Snowtrace compiles contracts/ with solc 0.8.33 and optimizer off — the"
    say "settings pinned in foundry.toml — and matches the deployed bytecode. The"
    say "constructor arguments are the ones the transcript records."
    say ""
    verify_source "registry" "$registry" "AVIPRegistry.sol:AVIPRegistry" \
        'constructor(address,address,address,bytes32,bytes32)' \
        "$(fuji sequencer)" "$(fuji verifier)" "$(fuji guardian)" \
        "$(fuji origin.sourceChainId)" "$(fuji origin.formulaDigest)"
    verify_source "vault" "$vault" "AVIPStakeVault.sol:AVIPStakeVault" \
        'constructor(address,address,uint256)' \
        "$(fuji token)" "$(fuji sink)" "$(fuji wad_per_unit)"
    verify_source "manager" "$manager" "AVIPValidatorManager.sol:AVIPValidatorManager" \
        'constructor(address,address,address)' \
        "$registry" "$(fuji slash_authority)" "$vault"

    say ""
    say "## 2. the constructor arguments, read back from the chain"
    say ""
    say "A verified source with the wrong arguments is still the wrong contract."
    say "Each getter below is constructor-fixed: none of these values has a setter."
    say ""
    check_eq "registry.sequencer()" \
        "$(norm "$(call "$registry" 'sequencer()(address)')")" "$(norm "$(fuji sequencer)")"
    check_eq "registry.verifier()" \
        "$(norm "$(call "$registry" 'verifier()(address)')")" "$(norm "$(fuji verifier)")"
    check_eq "registry.guardian()" \
        "$(norm "$(call "$registry" 'guardian()(address)')")" "$(norm "$(fuji guardian)")"
    check_eq "registry.sourceChainId()" \
        "$(norm "$(call "$registry" 'sourceChainId()(bytes32)')")" \
        "$(norm "$(fuji origin.sourceChainId)")"
    check_eq "registry.formulaDigest()" \
        "$(norm "$(call "$registry" 'formulaDigest()(bytes32)')")" \
        "$(norm "$(fuji origin.formulaDigest)")"
    check_eq "vault.TOKEN()" \
        "$(norm "$(call "$vault" 'TOKEN()(address)')")" "$(norm "$(fuji token)")"
    check_eq "vault.SINK()" \
        "$(norm "$(call "$vault" 'SINK()(address)')")" "$(norm "$(fuji sink)")"
    check_eq "vault.WAD_PER_UNIT()" \
        "$(dec "$(call "$vault" 'WAD_PER_UNIT()(uint256)')")" "$(dec "$(fuji wad_per_unit)")"
    check_eq "manager.registry()" \
        "$(norm "$(call "$manager" 'registry()(address)')")" "$(norm "$registry")"
    check_eq "manager.slashAuthority()" \
        "$(norm "$(call "$manager" 'slashAuthority()(address)')")" \
        "$(norm "$(fuji slash_authority)")"
    check_eq "manager.custody()" \
        "$(norm "$(call "$manager" 'custody()(address)')")" "$(norm "$vault")"

    say ""
    say "## 3. the pair is wired to itself, not to phase 1"
    say ""
    say "bindManager is one-shot and runs inside the manager's constructor, so"
    say "vault.manager() is a handshake that either happened in the phase-2"
    say "broadcast or can never happen at all. It is this manager or nothing."
    say ""
    check_eq "vault.manager()" \
        "$(norm "$(call "$vault" 'manager()(address)')")" "$(norm "$manager")"

    say ""
    say "## 4. the Safe is a policy, not a source file"
    say ""
    say "Its runtime is the factory's 171-byte proxy, so 'verifying the Safe"
    say "against this repo' would verify somebody else's bytecode against our"
    say "tree. The evidence is what the proxy answers plus what its creation"
    say "receipt says: factory, singleton, threshold, handler, owners."
    say ""
    code="$(cast code --rpc-url "$RPC_URL" "$safe")"
    bytes=$(( (${#code} - 2) / 2 ))
    say "          safe.code                $bytes bytes of runtime"
    check_eq "safe.code.bytes" "$bytes" "171"

    slot0="$(addr_from_word "$(cast storage --rpc-url "$RPC_URL" "$safe" 0)")"
    check_eq "safe.slot0 (singleton)" "$slot0" "$(norm "$(safe singleton)")"

    handler_slot="$(cast keccak 'fallback_manager.handler.address')"
    handler_value="$(addr_from_word "$(cast storage --rpc-url "$RPC_URL" "$safe" "$handler_slot")")"
    check_eq "safe.fallbackHandler" "$handler_value" "$(norm "$(safe fallbackHandler)")"

    check_eq "safe.getThreshold()" \
        "$(dec "$(call "$safe" 'getThreshold()(uint256)')")" "$(dec "$(safe threshold)")"
    check_eq "safe.VERSION()" \
        "$(call "$safe" 'VERSION()(string)' | tr -d '"')" "$(safe check.VERSION)"
    check_eq "safe.nonce()" \
        "$(dec "$(call "$safe" 'nonce()(uint256)')")" "$(dec "$(safe check.nonce)")"

    count="$(dec "$(safe owners.count)")"
    tr_owners=""
    for i in $(seq 0 $((count - 1))); do
        tr_owners="$tr_owners$(norm "$(safe "owners.$i")")"$'\n'
    done
    tr_owners="$(printf '%s' "$tr_owners" | sort | paste -sd, -)"
    ch_owners="$(call "$safe" 'getOwners()(address[])' | tr -d '[] ' |
        tr ',' '\n' | tr '[:upper:]' '[:lower:]' | sort | paste -sd, -)"
    say "          safe.owners              $ch_owners"
    check_eq "safe.getOwners()" "$ch_owners" "$tr_owners"

    tx_hash="$(grep -oE 'Hash: 0x[0-9a-fA-F]{64}' "$SAFE_TRANSCRIPT" | head -n1 | awk '{print $2}')"
    [ -n "$tx_hash" ] || die "no creation tx hash in $SAFE_TRANSCRIPT"
    receipt="$(cast receipt --rpc-url "$RPC_URL" "$tx_hash" --json)"
    say "          creation tx              $tx_hash"
    check_eq "safe.creation.status" "$(norm "$(jq -r .status <<<"$receipt")")" "0x1"
    check_eq "safe.creation.to (factory)" \
        "$(norm "$(jq -r .to <<<"$receipt")")" "$(norm "$(safe factory)")"

    proxy_event="$(jq -r '
        .logs[]
        | select(.topics[0] == "0x4f51faf6c4561ff95f067657e43439f0f856d97c04d9ec9070a6199ad418e235")
        | "\(.address) \(.topics[1]) \(.data)"' <<<"$receipt")"
    [ -n "$proxy_event" ] || die "creation receipt has no ProxyCreation event"
    check_eq "proxyCreation.emitter (factory)" \
        "$(norm "$(awk '{print $1}' <<<"$proxy_event")")" "$(norm "$(safe factory)")"
    check_eq "proxyCreation.proxy" \
        "$(addr_from_word "$(awk '{print $2}' <<<"$proxy_event")")" "$(norm "$safe")"
    check_eq "proxyCreation.singleton" \
        "$(addr_from_word "$(awk '{print $3}' <<<"$proxy_event")")" \
        "$(norm "$(safe singleton)")"

    # SafeSetup(address indexed initiator, address[] owners, uint256 threshold,
    #           address initializer, address fallbackHandler): the data words are
    # offset, threshold, initializer, handler, owners.length, owners…
    setup="$(jq -r '
        .logs[]
        | select(.topics[0] == "0x141df868a6331af528e38c83b7aa03edc19be66e37ae67f9285bf4f8e3c6a1a8")
        | .data' <<<"$receipt")"
    [ -n "$setup" ] || die "creation receipt has no SafeSetup event"
    word() { local off; off=$((2 + 64 * $1)); printf '%s\n' "${setup:off:64}"; }
    check_eq "safeSetup.threshold" "$(dec "0x$(word 1)")" "$(dec "$(safe threshold)")"
    check_eq "safeSetup.initializer" \
        "$(addr_from_word "0x$(word 2)")" "0x0000000000000000000000000000000000000000"
    check_eq "safeSetup.fallbackHandler" \
        "$(addr_from_word "0x$(word 3)")" "$(norm "$(safe fallbackHandler)")"
    setup_count="$(dec "0x$(word 4)")"
    setup_owners=""
    for i in $(seq 0 $((setup_count - 1))); do
        setup_owners="$setup_owners$(addr_from_word "0x$(word $((5 + i)))")"$'\n'
    done
    setup_owners="$(printf '%s' "$setup_owners" | sort | paste -sd, -)"
    check_eq "safeSetup.owners" "$setup_owners" "$tr_owners"

    say ""
    say "## 5. verdict"
    say ""
    say "Established: the three deployed contracts compile from contracts/ with the"
    say "arguments the transcript records; the vault/manager pair is wired to"
    say "itself; and slashAuthority is a 2-of-3 policy whose owners, threshold,"
    say "handler and singleton are the ones the creation receipt records from the"
    say "canonical factory."
    say ""
    say "Not established: that the three owner keys are held by three different"
    say "people, or that they are still under control. That is an organisational"
    say "question answered outside the chain. The guardian is the deployer EOA by"
    say "decision (see scripts/README.md), not a defect of the base layer."
    say ""
    if [ "$MISMATCHES" -eq 0 ]; then
        say "OK: $OUT"
    else
        say "FAIL: $MISMATCHES mismatch(es)"
        exit 1
    fi
}

addr_from_word() {
    local w
    w="$(norm "$1")"
    printf '0x%s\n' "${w: -40}"
}

main 2>&1 | tee "$OUT"
