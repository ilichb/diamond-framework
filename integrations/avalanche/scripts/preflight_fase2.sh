#!/usr/bin/env bash
# Phase-2 preflight: what must be true *before* the Fuji redeployment that
# replaces the phase-1 manager. That deployment cannot be repaired in place:
# `slashAuthority` is immutable and its phase-1 value is an EOA (P-39), and the
# registry predates M-15, so it has no `sourceChainId()`/`formulaDigest()` (P-40).
#
#   bash scripts/preflight_fase2.sh --offline        # artifacts only, no network
#   DEPLOYER=0x... SEQUENCER=0x... SLASH_AUTHORITY=0x... \
#       bash scripts/preflight_fase2.sh
#
# WHY A SEPARATE SCRIPT
# ---------------------
# `DeployFujiPhase1.s.sol` is already the phase-2 script: it deploys the current
# registry (with the origin pair), the vault and the manager, and it refuses a
# slasher without code off-local. What it cannot check is its own input: whether
# the Safe exists, whether it is the EOA it replaces, whether the deployer can
# pay, and whether the artifact about to be deployed is the one that emits
# `origin.*`. Those are the four ways this deployment has already gone wrong
# once, so they are checked here, read-only, before anything is signed.
#
# Exit status is 1 when any check fails. Nothing is broadcast: `cast call`,
# `cast code` and `forge inspect` are reads.
set -euo pipefail
cd "$(dirname "$0")/.."

# The phase-1 slasher, the value phase 2 exists to replace. If a deployment
# reuses it, the new manager has the same defect as the old one.
PHASE1_SLASHER=0xcdFBb0c0801d52Deb983C85F4e046B97D2362ec7
# Avalanche's Teleporter messenger on Fuji. Not needed by phase 2 itself; the
# transport (§4, M7d) cannot be deployed without it, and this is the one place
# that asks both questions at once.
TELEPORTER=0x253b2784c75e510dD0fF1da844684a1aC0aa5fcf
MIN_BALANCE_AVAX=0.05
TRANSCRIPT=scripts/fuji_20261018/fuji_phase1.txt

OFFLINE=0
usage() {
    cat <<'EOF'
Usage: preflight_fase2.sh [--offline] [--transcript FILE]

  --offline         check the artifacts only; no RPC, no environment
  --transcript FILE phase-1 transcript naming the registry still in use
                    (default: scripts/fuji_20261018/fuji_phase1.txt)

Environment for the on-chain checks:
  DEPLOYER, SEQUENCER, SLASH_AUTHORITY   (GUARDIAN optional)
  FUJI_RPC_URL, or ~/.config/avip/fuji_rpc.txt
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --offline)
            OFFLINE=1
            shift
            ;;
        --transcript)
            [ "$#" -ge 2 ] || { echo "preflight_fase2: --transcript needs a value" >&2; exit 2; }
            TRANSCRIPT=$2
            shift 2
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            echo "preflight_fase2: unknown argument $1" >&2
            exit 2
            ;;
    esac
done

N_PASS=0
N_FAIL=0
N_SKIP=0
pass() { printf 'PASS %s %s\n' "$1" "$2"; N_PASS=$((N_PASS + 1)); }
fail() { printf 'FAIL %s %s\n' "$1" "$2" >&2; N_FAIL=$((N_FAIL + 1)); }
skip() { printf 'SKIP %s %s\n' "$1" "$2"; N_SKIP=$((N_SKIP + 1)); }

# ---------------------------------------------------------------- artifacts

# P1. The registry about to be deployed must expose the M-15 origin pair. A
# stale build is what P-40 is made of, and it is invisible in the source: the
# artifact is the thing that gets deployed.
REGISTRY_IDS="$(forge inspect AVIPRegistry methodIdentifiers 2>/dev/null || true)"
if [ -z "$REGISTRY_IDS" ]; then
    fail P1 "AVIPRegistry artifact missing; run 'forge build'"
else
    missing=""
    grep -q 'sourceChainId()' <<<"$REGISTRY_IDS" || missing="sourceChainId()"
    grep -q 'formulaDigest()' <<<"$REGISTRY_IDS" || missing="${missing:+$missing }formulaDigest()"
    if [ -z "$missing" ]; then
        pass P1 "AVIPRegistry exposes sourceChainId()/formulaDigest()"
    else
        fail P1 "AVIPRegistry artifact lacks $missing (pre-M-15 build)"
    fi
fi

# P2. The two one-shot handshakes phase 2 relies on: the manager's slasher and
# the vault's single `bindManager` call (both are written once and never again).
MANAGER_IDS="$(forge inspect AVIPValidatorManager methodIdentifiers 2>/dev/null || true)"
VAULT_IDS="$(forge inspect AVIPStakeVault methodIdentifiers 2>/dev/null || true)"
missing=""
grep -q 'slashAuthority()' <<<"$MANAGER_IDS" || missing="manager.slashAuthority()"
grep -q 'bindManager()' <<<"$VAULT_IDS" || missing="${missing:+$missing }vault.bindManager()"
grep -q 'manager()' <<<"$VAULT_IDS" || missing="${missing:+$missing }vault.manager()"
if [ -z "$missing" ]; then
    pass P2 "manager and vault expose the one-shot handshake"
else
    fail P2 "artifact lacks $missing"
fi

# P3. The contract is not the only side of P-40: the *script* must log the
# origin, or `verify_fuji.sh` cannot verify the deployment it just made. Case P
# of the dry run proves it end to end; this is the source-level trip, so the
# check works before the dry run has ever been run.
if grep -q '_logBytes32("origin.sourceChainId"' scripts/DeployFujiPhase1.s.sol &&
    grep -q '_logBytes32("origin.formulaDigest"' scripts/DeployFujiPhase1.s.sol; then
    pass P3 "DeployFujiPhase1 logs origin.sourceChainId/formulaDigest"
else
    fail P3 "DeployFujiPhase1 does not log origin.*; verify_fuji.sh would reject its transcript"
fi

if [ "$OFFLINE" -eq 1 ]; then
    for id in P4 P5 P6 P7 P8 P9 P10; do skip "$id" "offline"; done
    printf 'preflight: PASS=%d FAIL=%d SKIP=%d\n' "$N_PASS" "$N_FAIL" "$N_SKIP"
    [ "$N_FAIL" -eq 0 ] || exit 1
    exit 0
fi

# ---------------------------------------------------------------- on-chain

RPC_URL="${FUJI_RPC_URL:-}"
if [ -z "$RPC_URL" ] && [ -r "$HOME/.config/avip/fuji_rpc.txt" ]; then
    RPC_URL="$(tr -d '\r\n' <"$HOME/.config/avip/fuji_rpc.txt")"
fi
[ -n "$RPC_URL" ] || { echo "preflight_fase2: no RPC URL: set FUJI_RPC_URL" >&2; exit 2; }

lower() { tr '[:upper:]' '[:lower:]' <<<"$1"; }

# P4. The right chain, or every address below means something else.
CHAIN_ID="$(cast chain-id --rpc-url "$RPC_URL" 2>/dev/null || true)"
if [ "$CHAIN_ID" = "43113" ]; then
    pass P4 "RPC is Fuji (43113)"
else
    fail P4 "RPC is not Fuji (chain-id=${CHAIN_ID:-unreachable})"
fi

# P5-P7. The slasher is the whole point. It must be set, it must be a contract,
# and it must not be a key that already holds another power.
UNSET_ROLES=""
for role in DEPLOYER SEQUENCER SLASH_AUTHORITY; do
    [ -n "${!role:-}" ] || UNSET_ROLES="${UNSET_ROLES:+$UNSET_ROLES }$role"
done
[ -z "$UNSET_ROLES" ] || fail P5 "unset: $UNSET_ROLES"

SLASHER="${SLASH_AUTHORITY:-}"
SLASHER_CODE=""
if [ -n "$SLASHER" ]; then
    SLASHER_CODE="$(cast code --rpc-url "$RPC_URL" "$SLASHER" 2>/dev/null || true)"
    if [ -n "$SLASHER_CODE" ] && [ "$SLASHER_CODE" != "0x" ]; then
        pass P5 "SLASH_AUTHORITY $SLASHER has code"
    else
        fail P5 "SLASH_AUTHORITY $SLASHER has no code: _requireSlasher would refuse it"
    fi

    if [ "$(lower "$SLASHER")" = "$(lower "$PHASE1_SLASHER")" ]; then
        fail P6 "SLASH_AUTHORITY is the phase-1 EOA $PHASE1_SLASHER; phase 2 must not reuse it"
    else
        pass P6 "SLASH_AUTHORITY is not the phase-1 EOA"
    fi

    if [ -n "${SEQUENCER:-}" ] && [ "$(lower "$SLASHER")" = "$(lower "$SEQUENCER")" ]; then
        fail P7 "SLASH_AUTHORITY == SEQUENCER: the hot key would decide every slash"
    elif [ -n "${DEPLOYER:-}" ] && [ "$(lower "$SLASHER")" = "$(lower "$DEPLOYER")" ]; then
        fail P7 "SLASH_AUTHORITY == DEPLOYER: the deploying key would decide every slash"
    else
        if [ -n "${GUARDIAN:-}" ] && [ "$(lower "$SLASHER")" = "$(lower "$GUARDIAN")" ]; then
            printf 'WARN P7 SLASH_AUTHORITY == GUARDIAN: one policy holds two powers; acceptable for a Safe, but say so in the runbook\n' >&2
        fi
        pass P7 "SLASH_AUTHORITY is distinct from SEQUENCER and DEPLOYER"
    fi
fi

# P8. Registry + vault + manager is roughly 6M gas; 0.05 AVAX leaves room for a
# gas spike and for the transport, and refuses an obviously unfunded deployer.
if [ -z "${DEPLOYER:-}" ]; then
    fail P8 "DEPLOYER is unset"
else
    BALANCE="$(cast balance --rpc-url "$RPC_URL" --ether "$DEPLOYER" 2>/dev/null || echo 0)"
    if awk -v b="$BALANCE" -v m="$MIN_BALANCE_AVAX" 'BEGIN { exit (b + 0 >= m + 0) ? 0 : 1 }'; then
        pass P8 "DEPLOYER balance $BALANCE AVAX >= $MIN_BALANCE_AVAX"
    else
        fail P8 "DEPLOYER balance $BALANCE AVAX < $MIN_BALANCE_AVAX"
    fi
fi

# P9. Not phase 2, but the same trip: the transport (M7d, I-1.4) needs this
# messenger, and a missing one is better learned here than mid-deployment.
TELEPORTER_CODE="$(cast code --rpc-url "$RPC_URL" "$TELEPORTER" 2>/dev/null || true)"
if [ -n "$TELEPORTER_CODE" ] && [ "$TELEPORTER_CODE" != "0x" ]; then
    pass P9 "Teleporter messenger present at $TELEPORTER"
else
    fail P9 "no Teleporter messenger at $TELEPORTER; DeployTransport cannot run on Fuji"
fi

# P10. Is the redeployment still needed? A registry that answers the M-15 getters
# means somebody already deployed one, and phase 2 would be a second one.
REGISTRY="$(sed -n 's/^[[:space:]]*\[fuji\] registry=//p' "$TRANSCRIPT" 2>/dev/null | head -n1)"
if [ -z "$REGISTRY" ]; then
    skip P10 "no transcript at $TRANSCRIPT"
elif cast call --rpc-url "$RPC_URL" "$REGISTRY" "sourceChainId()(bytes32)" >/dev/null 2>&1; then
    skip P10 "$REGISTRY already answers sourceChainId(); phase 2 already happened"
else
    pass P10 "phase-1 registry $REGISTRY still predates M-15 (P-40 confirmed)"
fi

printf 'preflight: PASS=%d FAIL=%d SKIP=%d\n' "$N_PASS" "$N_FAIL" "$N_SKIP"
[ "$N_FAIL" -eq 0 ] || exit 1
