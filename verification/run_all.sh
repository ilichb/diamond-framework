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
#     directory is irrelevant. The suite is CWD-independent: the three
#     scripts that emit a file write to a path relative to their own
#     location, and no script reads a data file.
#   - Writes nothing into the repository except under OUT_DIR (the
#     baseline directory). Those outputs are not committed.
#
# Usage:
#   bash verification/run_all.sh [OUT_DIR]
# Default OUT_DIR: verification/baseline_<YYYY-MM-DD>/
#
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
README="${SCRIPT_DIR}/README.md"
OUT_DIR="${1:-${SCRIPT_DIR}/baseline_$(date +%F)}"

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

printf '%-38s %6s %10s %13s\n' "script" "exit" "runtime_s" "output_bytes" > "${MANIFEST}"

echo "run_all.sh: ${#CMDS[@]} scripts -> ${OUT_DIR}"

for rel in "${CMDS[@]}"; do
    script_path="${SCRIPT_DIR}/${rel}"
    name="$(basename "${rel}")"
    stem="${name%.py}"
    out_file="${OUT_DIR}/${stem}_output.txt"

    if [ ! -f "${script_path}" ]; then
        printf '%-38s %6s %10s %13s\n' "${name}" "MISSING" "-" "-" >> "${MANIFEST}"
        continue
    fi

    start="$(date +%s.%N)"
    python3 "${script_path}" > "${out_file}" 2>&1
    rc=$?
    end="$(date +%s.%N)"
    runtime="$(awk "BEGIN{printf \"%.2f\", ${end} - ${start}}")"
    bytes="$(wc -c < "${out_file}")"

    printf '%-38s %6s %10s %13s\n' "${name}" "${rc}" "${runtime}" "${bytes}" >> "${MANIFEST}"
done

echo "run_all.sh: done. Manifest: ${MANIFEST}"
