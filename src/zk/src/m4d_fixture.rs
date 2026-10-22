//! M4d fixture emitter (audit 2026-10-20, findings P-01 and P-16).
//!
//! Writes `integrations/avalanche/test/fixtures/M4dGroth16Fixtures.sol`: the
//! **real** key over the admission circuit and the **real** inclusion proof for
//! validator zero, in the shape `Groth16Verifier` is installed with.
//! `src/zk/scripts/m4d_fixture.sh` runs it and then `forge fmt`; the result is
//! committed and reproducible, because the setup and the proof are seeded.
//!
//! Two independent things are emitted for the same key, and they are compared
//! on-chain and off-chain rather than trusted to agree:
//!
//! * the key itself, as decimal coordinates in the `Fp2` order `(c0, c1)` the
//!   contract documents, so `Groth16Verifier`'s constructor accepts it;
//! * [`on_chain_vk_digest`], `keccak256(abi.encode(vk))` — the value
//!   `Groth16Verifier.verifyingKeyDigest()` publishes — recomputed here from the
//!   ABI layout, so `test/M4dRealKey.t.sol` compares two implementations of the
//!   same encoding. ark's own canonical digests of the key and proofs are
//!   printed to stderr by the binary, so a run pins reproducibility without
//!   making the committed Solidity depend on a measurement.

use std::fmt::Write as _;
use std::fs::File;
use std::io::Write as _;
use std::process::ExitCode;

use ark_bn254::{Bn254, Fq, G1Affine, G2Affine};
use ark_ec::AffineRepr;
use ark_ff::{BigInteger, PrimeField};
use ark_groth16::ProvingKey;
use sha3::{Digest, Keccak256};

use avip_zk_prover::{admission, fixture, native};

/// Where the generated fixture lives, resolved from this crate rather than from
/// the working directory, so the script works from anywhere.
const OUTPUT: &str = concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/../../integrations/avalanche/test/fixtures/M4dGroth16Fixtures.sol"
);

/// Lowercase hex of a 32-byte digest.
fn hex32(bytes: &[u8; 32]) -> String {
    let mut s = String::with_capacity(64);
    for b in bytes {
        let _ = write!(s, "{b:02x}");
    }
    s
}

/// One ABI word: a field element, big-endian, left-padded to 32 bytes.
fn word(v: &Fq, out: &mut Vec<u8>) {
    let be = v.into_bigint().to_bytes_be();
    out.resize(out.len() + 32 - be.len(), 0);
    out.extend_from_slice(&be);
}

/// One ABI word from a small count or offset.
fn word_usize(n: usize, out: &mut Vec<u8>) {
    let be = n.to_be_bytes();
    out.resize(out.len() + 32 - be.len(), 0);
    out.extend_from_slice(&be);
}

/// `keccak256(abi.encode(vk))`, the digest the frozen `Groth16Verifier`
/// publishes (and which `test/M4dRealKey.t.sol` compares against the contract's
/// own). A struct with a dynamic member is itself dynamic, so `abi.encode` heads
/// it with the offset to its contents; those contents are the key's fourteen
/// coordinates, the offset to `ic` (which is `15 * 32` bytes into them), and then
/// `ic` as its length followed by five points (four public inputs plus the
/// constant term). Twenty-seven words, 864 bytes.
fn on_chain_vk_digest(pk: &ProvingKey<Bn254>) -> [u8; 32] {
    let vk = &pk.vk;
    let mut bytes = Vec::with_capacity(27 * 32);
    word_usize(32, &mut bytes); // offset to the struct's own head
    word(&vk.alpha_g1.x, &mut bytes);
    word(&vk.alpha_g1.y, &mut bytes);
    for z in [
        &vk.beta_g2.x,
        &vk.beta_g2.y,
        &vk.gamma_g2.x,
        &vk.gamma_g2.y,
        &vk.delta_g2.x,
        &vk.delta_g2.y,
    ] {
        word(&z.c0, &mut bytes);
        word(&z.c1, &mut bytes);
    }
    word_usize(15 * 32, &mut bytes); // offset to `ic`, from the head's own start
    word_usize(vk.gamma_abc_g1.len(), &mut bytes);
    for point in &vk.gamma_abc_g1 {
        word(&point.x, &mut bytes);
        word(&point.y, &mut bytes);
    }
    assert_eq!(bytes.len(), 27 * 32, "the ABI encoding is 27 words");

    Keccak256::digest(&bytes).into()
}

/// A decimal field element, the form the Solidity fixture carries.
fn dec<F: PrimeField>(v: &F) -> String {
    v.into_bigint().to_string()
}

/// A G1 point as the Solidity `uint256[2]` the fixture uses: `[x, y]`, and the
/// identity as `[0, 0]` (ark stores it that way).
fn g1(p: &G1Affine, indent: &str) -> String {
    let (x, y) = if p.is_zero() {
        (Fq::from(0u64), Fq::from(0u64))
    } else {
        (p.x, p.y)
    };
    format!(
        "{indent}[\n{indent}    uint256({}),\n{indent}    uint256({})\n{indent}]",
        dec(&x),
        dec(&y)
    )
}

/// A G2 point as the Solidity `uint256[2][2]` the fixture uses, in the natural
/// `Fp2` order `(c0, c1)` that `Groth16Verifier` documents and `Bn254.pushPair`
/// reorders for EIP-197.
fn g2(p: &G2Affine, indent: &str) -> String {
    let zero = Fq::from(0u64);
    let (x0, x1, y0, y1) = if p.is_zero() {
        (zero, zero, zero, zero)
    } else {
        (p.x.c0, p.x.c1, p.y.c0, p.y.c1)
    };
    format!(
        "{indent}[\n{indent}    [\n{indent}        uint256({}),\n{indent}        uint256({})\n\
         {indent}    ],\n{indent}    [\n{indent}        uint256({}),\n{indent}        uint256({})\n\
         {indent}    ]\n{indent}]",
        dec(&x0),
        dec(&x1),
        dec(&y0),
        dec(&y1)
    )
}

fn main() -> ExitCode {
    let validators = fixture::validators();
    let norms = fixture::tensor().entries().to_vec();
    let params = native::poseidon_params();

    // The same seeds and the same circuit the admission tests measure, so the
    // fixture and the measurement cannot drift apart.
    let dev = admission::key_and_proof(
        &validators,
        &norms,
        fixture::ADMISSION_INDEX,
        fixture::ADMISSION_EPOCH,
    );
    // The shape and the two durations stay on stderr: a key digest pins the
    // artefact, a constraint count pins the circuit, and neither belongs in a
    // Solidity file that must be byte-identical across runs.
    let (setup_time, prove_time) = (dev.setup_time, dev.prove_time);
    let (cost, synthesized) = native::synthesize(admission::circuit_for(
        &validators,
        &norms,
        fixture::ADMISSION_INDEX,
        fixture::ADMISSION_EPOCH,
    ));
    assert!(
        synthesized.is_ok() && cost.satisfied,
        "the emitted statement must satisfy the emitted circuit"
    );
    let other_index = fixture::ADMISSION_INDEX + 1;
    let dev_other =
        admission::key_and_proof(&validators, &norms, other_index, fixture::ADMISSION_EPOCH);
    assert_eq!(dev.pk.vk, dev_other.pk.vk, "one key, one statement shape");

    let (pk, proof) = (dev.pk, dev.proof);
    let other_proof = dev_other.proof;
    let root = admission::statement_root(&validators, &norms, &params);
    let validator = validators[fixture::ADMISSION_INDEX];
    let norm = norms[fixture::ADMISSION_INDEX];
    let validator_other = validators[other_index];
    let norm_other = norms[other_index];
    let vk = &pk.vk;
    let key_digest = on_chain_vk_digest(&pk);

    let mut out = String::new();
    let w = &mut out;
    let _ = write!(
        w,
        r#"// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// GENERATED FILE - do not edit by hand.
//
// Produced by `src/zk/scripts/m4d_fixture.sh`, which runs
// `cargo run --release --bin m4d-fixture` and then `forge fmt`. Regenerate with
//     src/zk/scripts/m4d_fixture.sh
//
// WHAT THIS IS
// ------------
// A Groth16/BN254 verification key over the **admission** circuit (audit
// 2026-10-20, P-01 and P-16), and a real inclusion proof for one validator of
// the deterministic 500-entry fixture. The statement is
//
//     [statementRoot, epoch, validator, certifiedNorm]
//
// and the witness is the validator's Merkle path and leaf index. The circuit
// constrains `validator` and `norm` inside the leaf, so this proof admits that
// one validator and no other: the replay that P-01 describes now changes a
// public input and fails.
//
// WHAT IT IS NOT
// --------------
// A *development* setup: one phase-2 contributor, with the transcript seeded, so
// anyone can derive the toxic waste and forge freely. It carries no security
// claim; the ceremony that would carries one stays out of scope.
//
// `statementRoot` is the Poseidon Merkle root of the admission tree. It is stored
// in its own per-epoch slot, separate from the keccak root `verifyEntry` uses
// (P-16), and `AVIPRegistry` binds it to the epoch in the same post.

import {{Groth16Verifier}} from "../../contracts/verifiers/Groth16Verifier.sol";

library M4dGroth16Fixtures {{
    /// @notice The committed fixture (5.5.6): {n} entries, `keccak256` of their
    ///         8-byte little-endian words -- the anchor `m4a_output.txt` pins.
    bytes32 internal constant TENSOR_DIGEST = 0x{tensor_digest};
    /// @notice The Phase-2 transcript: 32 ASCII bytes, both committed, so this
    ///         file is reproducible and the toxic waste is public.
    string internal constant SETUP_SEED = "AVIP-M4d-dev-setup-1-admission!!";
    /// @notice The proving randomness, committed so the proof is a pinned
    ///         artifact rather than a load-dependent observation.
    string internal constant PROOF_SEED = "AVIP-M4d-dev-proof-1-admission!!";

    /// @notice The statement, in `AVIPRegistry.verifyThreshold`'s order.
    uint256 internal constant STATEMENT_ROOT = {root};
    /// @notice The epoch the statement belongs to.
    uint256 internal constant STATEMENT_EPOCH = {epoch};
    /// @notice The address the committed proof admits (`fixture::ADMISSION_INDEX`).
    uint256 internal constant STATEMENT_VALIDATOR = {validator};
    /// @notice That validator's committed norm in WAD.
    uint256 internal constant STATEMENT_NORM = {norm};

    /// @notice A second admitted validator, for tests that need two records.
    uint256 internal constant STATEMENT_VALIDATOR_OTHER = {validator_other};
    /// @notice The second validator's committed norm in WAD.
    uint256 internal constant STATEMENT_NORM_OTHER = {norm_other};

    /// @notice `keccak256(abi.encode(vk))`, which `verifyingKeyDigest()`
    ///         publishes. Computed off-chain from the ABI layout, so
    ///         `test/M4dRealKey.t.sol` compares two implementations of it.
    bytes32 internal constant KEY_DIGEST = 0x{key_digest};

    /// @notice The real admission key: 4 public inputs, `ic.length == 5`.
    /// @dev G2 coordinates are in the natural `Fp2` order `(c0, c1)`; the
    ///      contract reorders them for EIP-197.
    function verifyingKey() internal pure returns (Groth16Verifier.VerifyingKey memory vk) {{
        vk.alpha1 = {alpha1};
        vk.beta2 = {beta2};
        vk.gamma2 = {gamma2};
        vk.delta2 = {delta2};
        vk.ic = new uint256[2][]({ic_len});
"#,
        n = fixture::N,
        tensor_digest = fixture::tensor().digest_hex(),
        root = dec(&root),
        epoch = fixture::ADMISSION_EPOCH,
        validator = dec(&admission::validator_fr(&validator)),
        norm = norm,
        validator_other = dec(&admission::validator_fr(&validator_other)),
        norm_other = norm_other,
        key_digest = hex32(&key_digest),
        alpha1 = g1(&vk.alpha_g1, "        "),
        beta2 = g2(&vk.beta_g2, "        "),
        gamma2 = g2(&vk.gamma_g2, "        "),
        delta2 = g2(&vk.delta_g2, "        "),
        ic_len = vk.gamma_abc_g1.len(),
    );
    for (i, point) in vk.gamma_abc_g1.iter().enumerate() {
        let _ = writeln!(w, "        vk.ic[{i}] = {};", g1(point, "        "));
    }

    let _ = write!(
        w,
        r#"    }}

    /// @notice `[root, epoch, validator, certifiedNorm]`, the statement the
    ///         registry builds.
    function statement() internal pure returns (uint256[] memory inputs) {{
        inputs = new uint256[](4);
        inputs[0] = STATEMENT_ROOT;
        inputs[1] = STATEMENT_EPOCH;
        inputs[2] = STATEMENT_VALIDATOR;
        inputs[3] = STATEMENT_NORM;
    }}

    /// @notice The proof's `A`.
    function proofA() internal pure returns (uint256[2] memory) {{
        return {proof_a};
    }}

    /// @notice The proof's `B`.
    function proofB() internal pure returns (uint256[2][2] memory) {{
        return {proof_b};
    }}

    /// @notice The proof's `C`.
    function proofC() internal pure returns (uint256[2] memory) {{
        return {proof_c};
    }}

    /// @notice `abi.encode(a, b, c)`: the 256-byte blob `Bn254.decodeProof`
    ///         reads and `AVIPRegistry.verifyThreshold` takes.
    function proof() internal pure returns (bytes memory) {{
        return abi.encode(proofA(), proofB(), proofC());
    }}

    /// @notice The same, for `STATEMENT_VALIDATOR_OTHER`.
    function proofOther() internal pure returns (bytes memory) {{
        return abi.encode(proofOtherA(), proofOtherB(), proofOtherC());
    }}

    function proofOtherA() internal pure returns (uint256[2] memory) {{
        return {proof_other_a};
    }}

    function proofOtherB() internal pure returns (uint256[2][2] memory) {{
        return {proof_other_b};
    }}

    function proofOtherC() internal pure returns (uint256[2] memory) {{
        return {proof_other_c};
    }}
}}
"#,
        proof_a = g1(&proof.a, "        "),
        proof_b = g2(&proof.b, "        "),
        proof_c = g1(&proof.c, "        "),
        proof_other_a = g1(&other_proof.a, "        "),
        proof_other_b = g2(&other_proof.b, "        "),
        proof_other_c = g1(&other_proof.c, "        "),
    );

    let mut file = match File::create(OUTPUT) {
        Ok(file) => file,
        Err(err) => {
            eprintln!("cannot write {OUTPUT}: {err}");
            return ExitCode::FAILURE;
        }
    };
    if let Err(err) = file.write_all(out.as_bytes()) {
        eprintln!("cannot write {OUTPUT}: {err}");
        return ExitCode::FAILURE;
    }

    eprintln!("wrote {OUTPUT}");
    eprintln!("  key digest (on-chain)  : 0x{}", hex32(&key_digest));
    eprintln!(
        "  key digest (canonical) : {}",
        admission::canonical_digest(&pk.vk)
    );
    eprintln!(
        "  proof digest (canonical): {}",
        admission::canonical_digest(&proof)
    );
    eprintln!(
        "  other proof digest      : {}",
        admission::canonical_digest(&other_proof)
    );
    eprintln!(
        "  statement [root, epoch, validator, norm] : [{root}, {}, {}, {norm}]",
        fixture::ADMISSION_EPOCH,
        admission::validator_hex(&validator)
    );
    eprintln!("  constraints              : {}", cost.constraints);
    eprintln!("  setup / prove            : {setup_time:?} / {prove_time:?}");

    ExitCode::SUCCESS
}
