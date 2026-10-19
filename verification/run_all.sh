#!/usr/bin/env bash
#
# run_all.sh — Baseline orchestrator for the verification suite.
#
# Runs every script listed in `verification/README.md` (the `## Running`
# block), capturing each one's stdout+stderr to a per-script file and
# recording exit code, runtime and output size in a manifest.
#
# Guarantees:
#   - Does not stop on a failing script: it records the exit code and
#     continues to the next one.
#   - Invokes every script by absolute path, so the caller's working
#     directory is irrelevant. The suite is CWD-independent: no script
#     reads a data file, and no script writes one either. Exception (P10):
#     fuji/read_fuji_gas.py reads the three pinned Fuji broadcast JSONs and
#     writes a copy of its table to verification/baseline_verified/
#     fuji_gas_output.txt; its stdout, captured here, is the same table.
#   - Writes the run outputs under OUT_DIR (the baseline directory) plus a
#     closed list of their exact repo-relative paths at
#     verification/output_manifest.txt (and a canonical copy at
#     OUT_DIR/output_manifest.txt). No `find` glob is used downstream;
#     Fase 0 hashes exactly the listed files. None of these is committed by
#     this script.
#
# Options:
#   --resume   Keep the existing manifest and skip any script that already
#              has a completed (numeric exit-code) row *and* whose output
#              file still exists and is non-empty. Re-invoking after an
#              interruption continues where the last run stopped; deleting
#              an output forces that script to re-run.
#
# Usage:
#   bash verification/run_all.sh [--resume] [OUT_DIR]
# Default OUT_DIR: verification/baseline_verified/  (durable path inside the
# repo; ratified by the Auditor for the Fase 0 tamper-evident anchor). /tmp
# is NOT acceptable for the final manifest.
#
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"
README="${SCRIPT_DIR}/README.md"
OUT_DIR=""
RESUME=0

for arg in "$@"; do
    case "${arg}" in
        --resume) RESUME=1 ;;
        *) OUT_DIR="${arg}" ;;
    esac
done
OUT_DIR="${OUT_DIR:-${SCRIPT_DIR}/baseline_verified}"

if [ ! -f "${README}" ]; then
    echo "run_all.sh: README not found: ${README}" >&2
    exit 1
fi

mapfile -t CMDS < <(
    grep -oE '^[[:space:]]*python3 [^[:space:]]+' "${README}" | awk '{print $2}'
)

if [ "${#CMDS[@]}" -eq 0 ]; then
    echo "run_all.sh: no 'python3 ...' commands found in ${README}" >&2
    exit 1
fi

mkdir -p "${OUT_DIR}"
MANIFEST="${OUT_DIR}/manifest.txt"
# Closed list of the output files this run produces. Emitted at the end as
# output_manifest.txt so downstream steps (Fase 0 hashing) never glob.
declare -a OUTPUTS=()

# When resuming, keep the existing manifest and note which scripts are done.
declare -A DONE=()
if [ "${RESUME}" -eq 1 ] && [ -f "${MANIFEST}" ]; then
    while read -r name exit_code _rest; do
        case "${exit_code}" in
            ''|*[!0-9]*) continue ;;   # header line or MISSING row
        esac
        # Only treat a script as done if its output still exists and is
        # non-empty. A phantom row (its output since deleted) must not be
        # trusted, or --resume would skip a script whose artifact is gone.
        stem="${name%.py}"
        if [ -s "${OUT_DIR}/${stem}_output.txt" ]; then
            DONE["${name}"]=1
        fi
    done < "${MANIFEST}"
else
    printf '%-38s %6s %10s %13s\n' "script" "exit" "runtime_s" "output_bytes" > "${MANIFEST}"
fi

echo "run_all.sh: ${#CMDS[@]} scripts -> ${OUT_DIR} (resume=${RESUME})"

for rel in "${CMDS[@]}"; do
    script_path="${SCRIPT_DIR}/${rel}"
    name="$(basename "${rel}")"
    stem="${name%.py}"
    out_file="${OUT_DIR}/${stem}_output.txt"

    if [ "${RESUME}" -eq 1 ] && [ "${DONE[${name}]:-0}" = "1" ]; then
        echo "run_all.sh: skip (already done): ${name}"
        OUTPUTS+=("${out_file}")
        continue
    fi

    if [ ! -f "${script_path}" ]; then
        printf '%-38s %6s %10s %13s\n' "${name}" "MISSING" "-" "-" >> "${MANIFEST}"
        continue
    fi

    if [ "${RESUME}" -eq 1 ]; then
        # Drop any stale row for this script before re-executing, so a
        # phantom row (output deleted) does not duplicate on re-run.
        grep -v "^${name}[[:space:]]" "${MANIFEST}" > "${MANIFEST}.tmp" || true
        mv "${MANIFEST}.tmp" "${MANIFEST}"
    fi

    echo "run_all.sh: running ${name}"
    start="$(date +%s.%N)"
    python3 "${script_path}" > "${out_file}" 2>&1
    rc=$?
    end="$(date +%s.%N)"
    runtime="$(awk "BEGIN{printf \"%.2f\", ${end} - ${start}}")"
    bytes="$(wc -c < "${out_file}")"
    OUTPUTS+=("${out_file}")

    printf '%-38s %6s %10s %13s\n' "${name}" "${rc}" "${runtime}" "${bytes}" >> "${MANIFEST}"
done

# Emit the closed output list: exact paths, one per line, non-empty only.
# Written next to the run outputs (canonical, self-consistent with OUT_DIR)
# and at the top-level path requested by the audit. Paths are emitted
# RELATIVE to the repo root (D6 fix, Bloque B) so the manifest is portable
# across clones and machines; anything outside the repo stays absolute.
rel_of() {
    case "$1" in
        "${REPO_ROOT}/"*) printf '%s\n' "${1#"${REPO_ROOT}/"}" ;;
        *) printf '%s\n' "$1" ;;
    esac
}
{
    for f in "${OUTPUTS[@]}"; do
        [ -s "${f}" ] && rel_of "${f}"
    done
} > "${OUT_DIR}/output_manifest.txt"
cp "${OUT_DIR}/output_manifest.txt" "${SCRIPT_DIR}/output_manifest.txt"

echo "run_all.sh: done. Manifest: ${MANIFEST}"
echo "run_all.sh: output list: ${OUT_DIR}/output_manifest.txt (copy: ${SCRIPT_DIR}/output_manifest.txt)"
