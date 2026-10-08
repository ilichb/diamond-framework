#!/usr/bin/env bash
#
# fase0_anchor.sh — Generador del ancla (Fase 0), versionado. Cierra P-6.
#
# Reconstruye la cadena de custodia a partir de la lista CERRADA de outputs
# que deja el harness. No usa `find` en ningun punto:
#
#   verification/output_manifest.txt   (lista cerrada; la escribe run_all.sh)
#            |
#            v   sha256sum (orden canonico, sin locale)
#   verification/output_manifest.sha256
#            |
#            v   sello de procedencia
#   verification/audit_manifest.sha256 = timestamp UTC + HEAD + main.tex
#                                        + output_manifest.sha256
#
# Cadena que verifica la guarda G10 de verification/audit-gate.sh:
#
#   outputs <- output_manifest.sha256 <- audit_manifest.sha256 <- main.tex
#
# ORDEN CANONICO. La clave de ordenacion es la ruta SIN guiones bajos,
# comparada con LC_ALL=C. Motivo: el ancla de Bloque B se genero con
# `find ... -name "*_output.txt" | sort | xargs sha256sum` bajo el locale
# del sistema (docs/audit/bloque-b-report.md §4), y esa colacion glibc
# ignora la puntuacion. Por eso el manifiesto commiteado NO esta en orden
# LC_ALL=C puro (se desvia en recalibrate_top/r_std_specification): el
# resultado dependia del locale de la maquina. Esta regla reproduce el
# ancla commiteada byte a byte y es reproducible en cualquier maquina.
#
# El sello UTC es la unica linea no determinista: registra *cuando* se
# produjo el ancla. Lo determinista, y lo que G10 verifica, es la cadena de
# hashes (HEAD + los 2 pares sha256), que se reproduce identica.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"

LIST_REL="verification/output_manifest.txt"
OUT_SHA_REL="verification/output_manifest.sha256"
AUDIT_SHA_REL="verification/audit_manifest.sha256"
PAPER_REL="docs/paper/main.tex"

usage() {
    cat <<'EOF'
Uso: fase0_anchor.sh [--check]

  (sin argumentos)  Escribe verification/output_manifest.sha256 y
                    verification/audit_manifest.sha256 en el repo.
  --check           Genera en un directorio temporal y compara con el ancla
                    commiteada; exit != 0 si algo discrepa.
  OUT_DIR=DIR       Escribe los manifiestos en DIR (por defecto verification/).
EOF
}

CHECK=0
for arg in "$@"; do
    case "${arg}" in
        --check) CHECK=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "fase0_anchor.sh: argumento desconocido: ${arg} (mira --help)" >&2; exit 2 ;;
    esac
done

cd "${REPO_DIR}"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

if [ "${CHECK}" -eq 1 ]; then
    OUT_DIR="${WORK}"
else
    OUT_DIR="${OUT_DIR:-verification}"
    mkdir -p "${OUT_DIR}"
fi
OUT_DIR="$(cd "${OUT_DIR}" && pwd)"

# ---- 1. Entradas -----------------------------------------------------------
[ -f "${LIST_REL}" ]  || { echo "fase0_anchor.sh: falta ${LIST_REL}" >&2; exit 1; }
[ -f "${PAPER_REL}" ] || { echo "fase0_anchor.sh: falta ${PAPER_REL}" >&2; exit 1; }
git rev-parse HEAD >/dev/null 2>&1 \
    || { echo "fase0_anchor.sh: ${REPO_DIR} no es un repo git con HEAD" >&2; exit 1; }

# ---- 2. Rutas de la lista cerrada (sin find) -------------------------------
# Acepta lista de una columna (formato actual) y lista de dos columnas
# (`<sha256>  <ruta>`), por si la lista viniera ya hasheada: en ese caso la
# ruta es la columna 2. Se rechaza cualquier ruta que no exista (nada se
# omite en silencio).
: > "${WORK}/paths"
n=0
while IFS= read -r raw || [ -n "${raw}" ]; do
    line="${raw%%#*}"                                   # sin comentarios
    line="${line#"${line%%[![:space:]]*}"}"             # sin espacios iniciales
    line="${line%"${line##*[![:space:]]}"}"             # sin espacios finales
    [ -n "${line}" ] || continue
    declare -a f=()
    read -r -a f <<< "${line}" || true
    path="${line}"
    if [ "${#f[@]}" -ge 2 ] && [[ "${f[0]}" =~ ^[0-9a-f]{64}$ ]]; then
        path="${line#"${f[0]}"}"
        path="${path#"${path%%[![:space:]]*}"}"
    fi
    [ -f "${path}" ] \
        || { echo "fase0_anchor.sh: ruta de la lista inexistente: ${path}" >&2; exit 1; }
    printf '%s\n' "${path}" >> "${WORK}/paths"
    n=$((n + 1))
done < "${LIST_REL}"
[ "${n}" -gt 0 ] || { echo "fase0_anchor.sh: ${LIST_REL} sin rutas" >&2; exit 1; }

# ---- 3. output_manifest.sha256 (pares, orden canonico) ---------------------
awk '{k = $0; gsub(/_/, "", k); printf "%s\t%s\n", k, $0}' "${WORK}/paths" \
    | LC_ALL=C sort | cut -f2- > "${WORK}/paths.sorted"
while IFS= read -r p; do sha256sum -- "${p}"; done < "${WORK}/paths.sorted" \
    > "${OUT_DIR}/output_manifest.sha256"

sha256sum -c --quiet "${OUT_DIR}/output_manifest.sha256" \
    || { echo "fase0_anchor.sh: los pares recien generados no verifican" >&2; exit 1; }

# ---- 4. audit_manifest.sha256 (sello de procedencia) -----------------------
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
HEAD_REV="$(git rev-parse HEAD)"
H_PAPER="$(sha256sum -- "${PAPER_REL}" | cut -d' ' -f1)"
H_OUT="$(sha256sum -- "${OUT_DIR}/output_manifest.sha256" | cut -d' ' -f1)"
{
    printf '# Audit Manifest (UTC) %s\n' "${TS}"
    printf '%s\n' "${HEAD_REV}"
    printf '%s  %s\n' "${H_PAPER}" "${PAPER_REL}"
    printf '%s  %s\n' "${H_OUT}" "${OUT_SHA_REL}"
} > "${OUT_DIR}/audit_manifest.sha256"

printf 'fase0_anchor: %d outputs -> %s\n' "${n}" "${OUT_SHA_REL}"
printf 'fase0_anchor: sello UTC %s, HEAD %s\n' "${TS}" "${HEAD_REV}"

# ---- 5. --check: prueba de determinismo contra el ancla commiteada ---------
# Lo determinista es la cadena derivada de ficheros: los 2 pares sha256 y el
# propio output_manifest.sha256.  Lo NO determinista es el timestamp y el HEAD
# anclado (el generador sella el HEAD *actual*, y la guarda G10 acepta el HEAD
# anclado como ancestro del actual: D7-b).
if [ "${CHECK}" -eq 1 ]; then
    status=0
    if cmp -s "${OUT_DIR}/output_manifest.sha256" "${OUT_SHA_REL}"; then
        echo "fase0_anchor: output_manifest.sha256  IDENTICO byte a byte (35 pares)"
    else
        echo "fase0_anchor: output_manifest.sha256  DISCREPA de ${OUT_SHA_REL}" >&2
        status=1
    fi
    if [ ! -f "${AUDIT_SHA_REL}" ]; then
        echo "fase0_anchor: ${AUDIT_SHA_REL} no existe todavia (nada que comparar)"
        exit "${status}"
    fi
    if diff <(grep -E '^[0-9a-f]{64}  ' "${OUT_DIR}/audit_manifest.sha256") \
            <(grep -E '^[0-9a-f]{64}  ' "${AUDIT_SHA_REL}") >/dev/null; then
        echo "fase0_anchor: audit_manifest.sha256   pares sha256 identicos (main.tex + output_manifest)"
    else
        echo "fase0_anchor: audit_manifest.sha256   pares sha256 DISCREPAN" >&2
        status=1
    fi
    NEW_HEAD="$(grep -E '^[0-9a-f]{40}$' "${OUT_DIR}/audit_manifest.sha256" | head -1)"
    OLD_HEAD="$(grep -E '^[0-9a-f]{40}$' "${AUDIT_SHA_REL}" | head -1)"
    if [ "${NEW_HEAD}" = "${OLD_HEAD}" ]; then
        echo "fase0_anchor: HEAD anclado ${OLD_HEAD} (igual al actual)"
    elif git merge-base --is-ancestor "${OLD_HEAD}" "${NEW_HEAD}"; then
        echo "fase0_anchor: HEAD anclado ${OLD_HEAD} -> ancestro de ${NEW_HEAD} (criterio G10/D7-b)"
    else
        echo "fase0_anchor: HEAD anclado ${OLD_HEAD} NO es ancestro de ${NEW_HEAD}" >&2
        status=1
    fi
    echo "fase0_anchor: la linea de timestamp sella el momento de la generacion"
    exit "${status}"
fi

echo "fase0_anchor: verifica con  bash verification/audit-gate.sh  (guarda G10)"
