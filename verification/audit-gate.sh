#!/usr/bin/env bash
#
# audit-gate.sh — Gate de auditoria (Bloque B, paso 5).
#
# ---------------------------------------------------------------------------
# AVISO DE SPEC (transparencia).  Los IDs de guarda "G1..G10" citados por el
# Auditor NO existen en el repositorio; verificado con:
#     grep -rniE '\bG([1-9]|10)\b' . --include='*.md' --include='*.sh' --include='*.py'  ->  0
# Las guardas de abajo son el conjunto DERIVADO (de los ejes de auditoria, de
# las afirmaciones del paper y de la suite de verificacion).  Deben
# reconciliarse con la spec autoritativa del Auditor antes de tomar este gate
# como definitivo.  Ningun valor se teclea de memoria: cada guarda re-deriva
# el suyo con el comando exacto que lo verifica (regla de la auditoria).
# ---------------------------------------------------------------------------
#
# Salida: PASS / FAIL / SKIP por guarda + resumen.  Exit != 0 si hay algun FAIL.
# Variables de entorno (opcionales):
#   FROZEN_DIR   (def verification/baseline_2026-10-06)
#   RUN1_DIR     (def /tmp/baseline_verify)
#   RUN2_DIR     (def /tmp/baseline_verify2)
#   OUT_MANIFEST (def verification/output_manifest.txt)
#   SHA_MANIFEST (def verification/audit_manifest.sha256)
#
set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_DIR}" || exit 2

FINDINGS_FILE="docs/audit/numerical-verification.md"
CLAIMS_FILE="docs/audit/content-audit-pending.md"
FROZEN_DIR="${FROZEN_DIR:-verification/baseline_2026-10-06}"
RUN1_DIR="${RUN1_DIR:-/tmp/baseline_verify}"
RUN2_DIR="${RUN2_DIR:-/tmp/baseline_verify2}"
OUT_MANIFEST="${OUT_MANIFEST:-verification/output_manifest.txt}"
SHA_MANIFEST="${SHA_MANIFEST:-verification/audit_manifest.sha256}"

PASS=0; FAIL=0; SKIP=0; LINE=()
emit() { LINE+=("$(printf '%-4s %-5s %s' "$1" "$2" "$3")"); case "$2" in PASS) PASS=$((PASS+1));; FAIL) FAIL=$((FAIL+1));; SKIP) SKIP=$((SKIP+1));; esac; }
count() { grep -c "$1" "$2" 2>/dev/null || true; }

# G1 — nº de findings F- == 21
n="$(count '^### F-' "${FINDINGS_FILE}")"
[ "${n:-0}" -eq 21 ] && emit G1 PASS "F- findings = ${n}" || emit G1 FAIL "F- findings = ${n} (expected 21)"

# G2 — nº de claims C- == 50
n="$(count '^### C-' "${CLAIMS_FILE}")"
[ "${n:-0}" -eq 50 ] && emit G2 PASS "C- claims = ${n}" || emit G2 FAIL "C- claims = ${n} (expected 50)"

# G3 — aritmetica de gas EIP-196/197 (finding C-51)
if python3 verification/eip_cost_check.py >/tmp/audit-gate-g3.txt 2>&1; then
    emit G3 PASS "eip_cost_check PASS"
else
    emit G3 FAIL "eip_cost_check FAIL (ver /tmp/audit-gate-g3.txt)"
fi

# G4 — tokens huerfanos del crosscheck == 0 (filas de 4 columnas: sin match)
if [ -f docs/audit/eje-iv-crosscheck.py ]; then
    n="$(python3 docs/audit/eje-iv-crosscheck.py 2>/dev/null | grep -cE '^\| *[0-9]+ *\|[^|]*\|[^|]*\| *`[^`]+` *\| *$' || true)"
    [ "${n:-0}" -eq 0 ] && emit G4 PASS "orphan tokens = 0" || emit G4 FAIL "orphan tokens = ${n} (pending adjudication)"
else
    emit G4 SKIP "crosscheck not found"
fi

# G5 / G6 — determinismo (cmp byte a byte de cada *_output.txt)
cmp_dir() { # id A B label
    if [ ! -d "$2" ] || [ ! -d "$3" ]; then emit "$1" SKIP "missing $2 or $3"; return; fi
    local drift=0 b f
    for f in "$2"/*_output.txt; do
        b="$(basename "$f")"
        if [ -f "$3/$b" ]; then cmp -s "$f" "$3/$b" || drift=$((drift+1)); else drift=$((drift+1)); fi
    done
    [ "$drift" -eq 0 ] && emit "$1" PASS "$4 (0 drift)" || emit "$1" FAIL "$4 drift = ${drift}"
}
cmp_dir G5 "${FROZEN_DIR}" "${RUN1_DIR}" "run1 == frozen"
cmp_dir G6 "${RUN1_DIR}"  "${RUN2_DIR}" "run2 == run1"

# G7 — lista cerrada de outputs (output_manifest.txt) existe y no esta vacia
if [ -s "${OUT_MANIFEST}" ]; then
    emit G7 PASS "closed list: $(wc -l < "${OUT_MANIFEST}") outputs"
else
    emit G7 FAIL "missing ${OUT_MANIFEST}"
fi

# G8 — pdflatex limpio (^! = 0 y Undefined = 0), dos pasadas
if command -v pdflatex >/dev/null 2>&1; then
    tmp="$(mktemp -d)"
    ( cd docs/paper && \
      pdflatex -interaction=nonstopmode -output-directory="${tmp}" main.tex >/dev/null 2>&1; \
      pdflatex -interaction=nonstopmode -output-directory="${tmp}" main.tex >"${tmp}/l.txt" 2>&1 )
    e="$(grep -c '^!' "${tmp}/l.txt" || true)"
    u="$(grep -c 'Undefined' "${tmp}/l.txt" || true)"
    rm -rf "${tmp}"
    if [ "${e:-0}" -eq 0 ] && [ "${u:-0}" -eq 0 ]; then
        emit G8 PASS "pdflatex clean (errors=0, Undefined=0)"
    else
        emit G8 FAIL "pdflatex: errors=${e:-?}, Undefined=${u:-?}"
    fi
else
    emit G8 SKIP "pdflatex not installed"
fi

# G9 — arbol git sin cambios en ficheros versionados
if [ -z "$(git status --porcelain --untracked-files=no)" ]; then
    emit G9 PASS "no uncommitted tracked changes"
else
    emit G9 FAIL "tracked changes present (git status --porcelain)"
fi

# G10 — manifiesto sha256 (Fase 0) presente y verificable
if [ -s "${SHA_MANIFEST}" ]; then
    if ( cd "$(dirname "${SHA_MANIFEST}")" && sha256sum -c "$(basename "${SHA_MANIFEST}")" >/dev/null 2>&1 ); then
        emit G10 PASS "sha256 manifest verifies"
    else
        emit G10 FAIL "sha256 manifest mismatch"
    fi
else
    emit G10 SKIP "no sha256 manifest yet (Fase 0)"
fi

echo "audit-gate.sh  repo=${REPO_DIR}"
echo "--------------------------------------------------------------------------"
for l in "${LINE[@]}"; do echo "${l}"; done
echo "--------------------------------------------------------------------------"
printf 'PASS=%d FAIL=%d SKIP=%d\n' "${PASS}" "${FAIL}" "${SKIP}"
[ "${FAIL}" -eq 0 ] || exit 1
exit 0
