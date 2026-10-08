#!/usr/bin/env bash
#
# audit-gate.sh — Gate de auditoria (Bloque B), guardas G1..G10.
#
# Las definiciones son las RATIFICADAS por el Auditor en las resoluciones del
# Bloque B. Cada guarda re-deriva su valor con el comando exacto que lo
# verifica (regla de este repo: un valor derivable no se teclea).
#
# Adaptaciones autorizadas por el Auditor ("Ajustar segun el formato real del
# log del harness") van marcadas [ADAPTED].  Toda desviacion respecto de la
# definicion literal esta documentada en docs/audit/bloque-b-report.md.
#
# Salida: linea por guarda (PASS / FAIL / SKIP) + resumen.  Exit != 0 si hay
# algun FAIL.
#
# Variables de entorno (opcionales):
#   EVID      (def verification/fase1_determinism_evidence.txt)
#   MANIFEST  (def verification/baseline_verified/manifest.txt)
#   PAPER     (def docs/paper/main.tex)
#
set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_DIR}" || exit 2

EVID="${EVID:-verification/fase1_determinism_evidence.txt}"
MANIFEST="${MANIFEST:-verification/baseline_verified/manifest.txt}"
PAPER="${PAPER:-docs/paper/main.tex}"
OUT_SHA="verification/output_manifest.sha256"
AUDIT_SHA="verification/audit_manifest.sha256"

PASS=0; FAIL=0; SKIP=0; LINE=()
emit() {
    LINE+=("$(printf '%-4s %-5s %s' "$1" "$2" "$3")")
    case "$2" in
        PASS) PASS=$((PASS+1)) ;;
        FAIL) FAIL=$((FAIL+1)) ;;
        SKIP) SKIP=$((SKIP+1)) ;;
    esac
}
count() { grep -c "$1" "$2" 2>/dev/null || true; }

# ---- G1: Scripts presentes --------------------------------------------------
# Definicion: find verification -maxdepth 2 -name "*.py" | wc -l  -> >= 35
G1="$(find verification -maxdepth 2 -name '*.py' | wc -l)"
[ "${G1:-0}" -ge 35 ] \
    && emit G1 PASS "scripts .py (verification, depth 2) = ${G1} (>= 35)" \
    || emit G1 FAIL "scripts .py = ${G1} (< 35)"

# ---- G2: Exits (el harness ya los valido; el gate los reafirma) -------------
# Definicion: grep -c "EXIT 0" "${EVID}"
# [ADAPTED] el log del harness se emite con una linea "<script> EXIT <code>"
# por script; el esperado es el nº de scripts con codigo numerico del
# manifiesto de la corrida durable (0 MISSING).
want="$(awk 'NR>1 && $2 ~ /^[0-9]+$/ {n++} END{print n+0}' "${MANIFEST}" 2>/dev/null || echo 0)"
G2="$(count 'EXIT 0' "${EVID}")"
if [ "${want:-0}" -gt 0 ] && [ "${G2:-0}" -eq "${want}" ]; then
    emit G2 PASS "EXIT 0 = ${G2}/${want} scripts"
else
    emit G2 FAIL "EXIT 0 = ${G2:-0}/${want} (esperado: todos)"
fi

# ---- G3: Reproducibilidad (0 DRIFT) ----------------------------------------
# Definicion: grep -c "DRIFT" "${EVID}"  -> debe ser 0.
# El log solo escribe "DRIFT <fichero>" cuando el cmp byte a byte discrepa.
G3="$(count 'DRIFT' "${EVID}")"
[ "${G3:-0}" -eq 0 ] \
    && emit G3 PASS "lineas DRIFT = 0" \
    || emit G3 FAIL "lineas DRIFT = ${G3}"

# ---- G4: Huerfanos resueltos ------------------------------------------------
# Definicion (literal del Auditor): nº de filas del registro de claims con
# class == 'Orphan' o class vacia -> debe ser 0.
G4="$(python3 -c "import csv; r=list(csv.DictReader(open('docs/audit/claim-registry.csv'))); print(sum(1 for row in r if row['class']=='Orphan' or not row['class']))" 2>/dev/null || echo ERR)"
G4N="$(python3 -c "import csv; print(sum(1 for _ in csv.DictReader(open('docs/audit/claim-registry.csv'))))" 2>/dev/null || echo '?')"
if [ "${G4:-ERR}" = "0" ]; then
    emit G4 PASS "claims Orphan/sin clase = 0 (registro: ${G4N} filas clasificadas)"
else
    emit G4 FAIL "claims Orphan/sin clase = ${G4} (registro: ${G4N} filas)"
fi

# ---- G5: F-Log count -------------------------------------------------------
# Definicion: grep -c '^### F-' docs/audit/numerical-verification.md -> 21.
# (Corregido de 19 a 21 por el Auditor en el cierre del Bloque B — D1: el
# artefacto derivado da 21 y el propio paper escribe "twenty-one" en
# main.tex L48/L87. La cifra 19 provenia del session-report de la sesion 3.)
G5="$(count '^### F-' docs/audit/numerical-verification.md)"
[ "${G5:-0}" -eq 21 ] \
    && emit G5 PASS "F- entries = ${G5} (ratificado: 21)" \
    || emit G5 FAIL "F- entries = ${G5} (esperado 21)"

# ---- G6: Worksheet count ----------------------------------------------------
# Definicion: grep -c '^### C-' docs/audit/content-audit-pending.md -> 50.
G6="$(count '^### C-' docs/audit/content-audit-pending.md)"
[ "${G6:-0}" -eq 50 ] \
    && emit G6 PASS "C- worksheets = ${G6}" \
    || emit G6 FAIL "C- worksheets = ${G6} (esperado 50)"

# ---- G7: Gas exacto ---------------------------------------------------------
# Definicion: python3 verification/eip_cost_check.py -> exit 0.
python3 verification/eip_cost_check.py >/dev/null 2>&1
rc=$?
[ "${rc}" -eq 0 ] \
    && emit G7 PASS "eip_cost_check exit 0" \
    || emit G7 FAIL "eip_cost_check exit ${rc}"

# ---- G8: Etiquetas coherentes ----------------------------------------------
# Definicion: grep -c 'Estimate.*Verified\|Verified.*Estimate' main.tex -> 0.
G8="$(count 'Estimate.*Verified\|Verified.*Estimate' "${PAPER}")"
[ "${G8:-0}" -eq 0 ] \
    && emit G8 PASS "ninguna mezcla Estimate/Verified en ${PAPER}" \
    || emit G8 FAIL "mezcla Estimate/Verified = ${G8}"

# ---- G9: Compilacion limpia -------------------------------------------------
# Definicion: pdflatex main.tex x2 en docs/paper; G9_ERR = grep -c '^!' main.log
# y G9_UNDEF = grep -c 'Undefined' main.log; PASS si ambos son 0.
# [ADAPTED] se compila con -output-directory a un temporal para no dejar
# main.aux/main.log en el arbol; el .log leido es el mismo que produciria la
# compilacion en sitio.
if command -v pdflatex >/dev/null 2>&1; then
    tmp9="$(mktemp -d)"
    ( cd docs/paper && \
      pdflatex -interaction=nonstopmode -output-directory="${tmp9}" main.tex >/dev/null 2>&1; \
      pdflatex -interaction=nonstopmode -output-directory="${tmp9}" main.tex >/dev/null 2>&1 )
    G9_ERR="$(grep -c '^!' "${tmp9}/main.log" 2>/dev/null || true)"
    G9_UNDEF="$(grep -c 'Undefined' "${tmp9}/main.log" 2>/dev/null || true)"
    rm -rf "${tmp9}"
    if [ "${G9_ERR:-1}" -eq 0 ] && [ "${G9_UNDEF:-1}" -eq 0 ]; then
        emit G9 PASS "pdflatex limpio (errors=0, Undefined=0)"
    else
        emit G9 FAIL "pdflatex errors=${G9_ERR:-?} Undefined=${G9_UNDEF:-?}"
    fi
else
    emit G9 SKIP "pdflatex no instalado"
fi

# ---- G10: Integridad del manifiesto (Fase 0) --------------------------------
# Definicion: se evalua tras la Fase 0 (verification/output_manifest.sha256 +
# verification/audit_manifest.sha256). PASS si todos los pares <sha>  <path>
# del manifiesto maestro verifican y el HEAD registrado ancla el HEAD actual.
# [ADAPTED] ancla de HEAD (Bloque B, D7-b): un commit no puede contener un
# manifiesto que ancle su propio hash (el hash del commit depende de su
# contenido), asi que la igualdad estricta solo es satisfacible ANTES de
# commitear el manifiesto. Se exige que el HEAD anclado sea ANCESTRO del actual
# (git merge-base --is-ancestor); la evidencia de manipulacion queda intacta
# porque los 35 hashes de outputs y el de main.tex se comparan byte a byte.
if [ -s "${OUT_SHA}" ] && [ -s "${AUDIT_SHA}" ]; then
    tmp10="$(mktemp -d)"
    grep -E '^[0-9a-f]{64}  ' "${AUDIT_SHA}" > "${tmp10}/pairs" 2>/dev/null || true
    ok=1; why=""
    if [ -s "${tmp10}/pairs" ]; then
        # (i) cadena maestra: main.tex + el propio output_manifest.sha256
        ( cd "${REPO_DIR}" && sha256sum -c --quiet "${tmp10}/pairs" ) >/dev/null 2>&1 \
            || { ok=0; why="manifiesto maestro"; }
    else
        ok=0; why="manifiesto maestro sin pares"
    fi
    # (ii) Cadena completa (Bloque B, D8): el manifiesto maestro ancla el fichero
    # output_manifest.sha256, NO los 35 outputs. Sin este paso la cadena quedaba
    # abierta: manipular un output pasaba como PASS (el "35 outputs" del mensaje
    # era solo un conteo). Cadena verificada:
    #   outputs <- output_manifest.sha256 <- audit_manifest.sha256 <- main.tex
    ( cd "${REPO_DIR}" && sha256sum -c --quiet "${OUT_SHA}" ) >/dev/null 2>&1 \
        || { ok=0; why="${why:+${why}; }hashes de outputs"; }
    nout="$(wc -l < "${OUT_SHA}")"
    rec="$(grep -E '^[0-9a-f]{40}$' "${AUDIT_SHA}" 2>/dev/null | head -1 || true)"
    now="$(git rev-parse HEAD)"
    # (iii) ancla de procedencia: el HEAD anclado debe ser ancestro del actual
    [ -n "${rec}" ] && git merge-base --is-ancestor "${rec}" HEAD 2>/dev/null \
        || { ok=0; why="${why:+${why}; }HEAD '${rec:0:7}' no ancla '${now:0:7}'"; }
    rm -rf "${tmp10}"
    if [ "${ok}" -eq 1 ]; then
        emit G10 PASS "manifiesto verifica (${nout} outputs; HEAD anclado ${rec:0:7} -> actual ${now:0:7})"
    else
        emit G10 FAIL "manifiesto no verifica (${nout} outputs): ${why}"
    fi
else
    emit G10 SKIP "sin manifiestos sha256 todavia (Fase 0)"
fi

echo "audit-gate.sh  repo=${REPO_DIR}"
echo "--------------------------------------------------------------------------"
for l in "${LINE[@]}"; do echo "${l}"; done
echo "--------------------------------------------------------------------------"
printf 'PASS=%d FAIL=%d SKIP=%d\n' "${PASS}" "${FAIL}" "${SKIP}"
[ "${FAIL}" -eq 0 ] || exit 1
exit 0

