#!/usr/bin/env bash
# Reproduce the §5.5.5 finding: the published `bulletproofs 5.0.0` cannot build
# its R1CS API.  The `yoloproofs` feature is declared in the crate manifest and
# the `src/r1cs/` sources ship in the tarball, but enabling the feature fails to
# compile against the crate's own declared dependency range, because the module
# still expects the `curve25519-dalek` 3.x signature `Option<Scalar>` for
# `Scalar::from_canonical_bytes` while 4.x returns `CtOption<Scalar>`.
#
#   expectation: 3 x E0599 in src/r1cs/proof.rs (L180-L182)  => gate CONFIRMED
#
# Usage:  src/zk/scripts/check-yoloproofs-gate.sh
#
# Network: the first run downloads `bulletproofs` and its dependency tree into
# the cargo registry cache; afterwards it resolves from the cache.  This is the
# dependency exception §5.5.6 asks to state: the crate itself still builds
# offline, this probe needs one fetch.
set -uo pipefail

BULLETPROOFS_VERSION="${BULLETPROOFS_VERSION:-=5.0.0}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

mkdir -p "${WORKDIR}/src"
cat > "${WORKDIR}/Cargo.toml" <<TOML
[package]
name = "yoloproofs_gate_probe"
version = "0.0.0"
edition = "2021"

[dependencies]
bulletproofs = { version = "${BULLETPROOFS_VERSION}", features = ["yoloproofs"] }
TOML
cat > "${WORKDIR}/src/lib.rs" <<'RS'
// Touch the gated module so the feature is actually exercised.
pub fn _gate() -> Option<bulletproofs::r1cs::R1CSProof> {
    None
}
RS

echo "== bulletproofs ${BULLETPROOFS_VERSION} + feature \"yoloproofs\" =="
( cd "${WORKDIR}" && cargo build 2>&1 ) | tee "${WORKDIR}/build.log"
rc="${PIPESTATUS[0]}"

hits="$(grep -c '^error\[E0599\]' "${WORKDIR}/build.log" || true)"
covered="$(grep -c 'src/r1cs/proof\.rs:18[0-2]' "${WORKDIR}/build.log" || true)"

echo
echo "--------------------------------------------------------------------"
echo "build exit code     : ${rc}   (expected: non-zero)"
echo "E0599 occurrences   : ${hits}   (expected: 3)"
echo "at r1cs/proof.rs L180-L182 : ${covered}   (expected: >= 1)"
if [ "${rc}" -ne 0 ] && [ "${hits}" -ge 3 ]; then
  echo "RESULT: gate CONFIRMED - the published crate cannot build yoloproofs"
  exit 0
fi
echo "RESULT: gate NOT reproduced - re-check §5.5.5 against the crate sources"
exit 1
