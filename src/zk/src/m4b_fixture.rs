//! M4b fixture emitter (plan §5.5.6, §5.5.9).
//!
//! Writes `integrations/avalanche/test/fixtures/M4bGroth16Fixtures.sol`: the
//! **real** key over V3 and the **real** fixture proof, in the shape
//! `Groth16Verifier` is installed with. `src/zk/scripts/m4b_fixture.sh` runs it
//! and then `forge fmt`; the result is committed and reproducible, because the
//! setup and the proof are seeded.
//!
//! Two independent things are emitted for the same key, and they are compared
//! on-chain and off-chain rather than trusted to agree:
//!
//! * the key itself, as decimal coordinates in the `Fp2` order `(c0, c1)` the
//!   contract documents, so `Groth16Verifier`'s constructor accepts it;
//! * [`on_chain_vk_digest`], `keccak256(abi.encode(vk))` — the value
//!   `Groth16Verifier.verifyingKeyDigest()` publishes — recomputed here from the
//!   ABI layout, so `test/M4bRealKey.t.sol` compares two implementations of the
//!   same encoding. ark's own canonical digest of the key stays in
//!   `scripts/m4b_output.txt`, where it pins reproducibility.

use std::fmt::Write as _;
use std::fs::File;
use std::io::Write as _;
use std::process::ExitCode;

use ark_bn254::{Bn254, Fq, G1Affine, G2Affine};
use ark_ec::AffineRepr;
use ark_ff::{BigInteger, PrimeField};
use ark_groth16::ProvingKey;
use sha3::{Digest, Keccak256};

use avip_zk_prover::{fixture, groth16};

/// Where the generated fixture lives, resolved from this crate rather than from
/// the working directory, so the script works from anywhere.
const OUTPUT: &str = concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/../../integrations/avalanche/test/fixtures/M4bGroth16Fixtures.sol"
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
/// publishes (and which `test/M4bRealKey.t.sol` compares against the contract's
/// own). A struct with a dynamic member is itself dynamic, so `abi.encode` heads
/// it with the offset to its contents; those contents are the key's fourteen
/// coordinates, the offset to `ic` (which is `15 * 32` bytes into them), and then
/// `ic` as its length followed by four points. Twenty-five words, 800 bytes --
/// the first version of this function wrote 24 and the Solidity test caught it.
fn on_chain_vk_digest(pk: &ProvingKey<Bn254>) -> [u8; 32] {
    let vk = &pk.vk;
    let mut bytes = Vec::with_capacity(25 * 32);
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
    assert_eq!(bytes.len(), 25 * 32, "the ABI encoding is 25 words");

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
    let tensor = fixture::tensor();
    let entries = tensor.entries().to_vec();
    let certified_norm_wad = tensor.wad_norm() as u64;

    // The same seeds and the same run the report measures, so the fixture and
    // `scripts/m4b_output.txt` cannot drift apart.
    let dev = groth16::key_and_proof(&entries, certified_norm_wad, 0);
    let (pk, proof) = (dev.pk, dev.proof);
    let root = groth16::circuit_for(&entries, certified_norm_wad, 0).root;
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
// Produced by `src/zk/scripts/m4b_fixture.sh`, which runs
// `cargo run --release --bin m4b-fixture` and then `forge fmt`. Regenerate with
//     src/zk/scripts/m4b_fixture.sh
//
// WHAT THIS IS
// ------------
// The real thing M3 waited for: a Groth16/BN254 verification key over the V3
// circuit of `docs/architecture/implementation-plan.md` 5.5.2 (Poseidon
// commitment + floor norm), and a real proof for the deterministic 500-entry
// fixture of 5.5.6. `test/M4bRealKey.t.sol` installs the key in the frozen
// `Groth16Verifier` and feeds the proof to `AVIPRegistry.verifyThreshold`, which
// builds the statement `[root, epoch, certifiedNorm]` from its own state -- no
// Solidity change anywhere.
//
// WHAT IT IS NOT
// --------------
// A *development* setup: one phase-2 contributor, with the transcript seeded, so
// anyone can derive the toxic waste and forge freely. It carries no security
// claim; the ceremony that would carries one stays out of M4's scope (5.5.4,
// 11). What it demonstrates is that the pipeline works end to end, and it makes
// the cost of that pipeline measurable.
//
// The statement's `root` is the Poseidon commitment of the fixture tensor, not a
// Merkle root: tying it to the registry's `keccak256` root is the Pedersen/
// Merkle bridge, gap A7, milestone M7 (5.5.7).

import {{Groth16Verifier}} from "../../contracts/verifiers/Groth16Verifier.sol";

library M4bGroth16Fixtures {{
    /// @notice The committed fixture (5.5.6): {n} entries, `keccak256` of their
    ///         8-byte little-endian words -- the anchor `m4a_output.txt` pins.
    bytes32 internal constant TENSOR_DIGEST = 0x{tensor_digest};
    /// @notice The Phase-2 transcript: 32 ASCII bytes, both committed, so this
    ///         file is reproducible and the toxic waste is public.
    string internal constant SETUP_SEED = "AVIP-M4b-dev-setup-1-contributor";
    /// @notice The proving randomness, committed so the proof is a pinned
    ///         artifact rather than a load-dependent observation.
    string internal constant PROOF_SEED = "AVIP-M4b-dev-proof-1-contributor";

    /// @notice The statement, in `AVIPRegistry.verifyThreshold`'s order.
    uint256 internal constant STATEMENT_ROOT = {root};
    /// @notice The epoch the statement belongs to.
    uint256 internal constant STATEMENT_EPOCH = 0;
    /// @notice `certifiedNorm = floor(sqrt(sum T_i^2))` in WAD (5.5.1).
    uint256 internal constant STATEMENT_NORM = {norm};

    /// @notice `keccak256(abi.encode(vk))`, which `verifyingKeyDigest()`
    ///         publishes. Computed off-chain from the ABI layout, so
    ///         `test/M4bRealKey.t.sol` compares two implementations of it.
    bytes32 internal constant KEY_DIGEST = 0x{key_digest};

    /// @notice The real key over V3: 3 public inputs, `ic.length == 4`.
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
        tensor_digest = tensor.digest_hex(),
        root = dec(&root),
        norm = certified_norm_wad,
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

    /// @notice `[root, epoch, certifiedNorm]`, the statement the registry builds.
    function statement() internal pure returns (uint256[] memory inputs) {{
        inputs = new uint256[](3);
        inputs[0] = STATEMENT_ROOT;
        inputs[1] = STATEMENT_EPOCH;
        inputs[2] = STATEMENT_NORM;
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
}}
"#,
        proof_a = g1(&proof.a, "        "),
        proof_b = g2(&proof.b, "        "),
        proof_c = g1(&proof.c, "        "),
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
        groth16::canonical_digest(&pk.vk)
    );
    eprintln!(
        "  proof digest (canonical): {}",
        groth16::canonical_digest(&proof)
    );
    eprintln!("  statement [root, epoch, norm] : [{root}, 0, {certified_norm_wad}]");

    ExitCode::SUCCESS
}
