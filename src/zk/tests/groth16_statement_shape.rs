//! M4b/M4c: the contract-facing shape of the key, and what the statement wrapper
//! costs on top of §5.5.6's pinned V3.
//!
//! A small tensor on purpose: the assertions are about *shape* (how many public
//! inputs, how many `ic` entries, whether every statement component is bound) and
//! about *derived* differences between §5.5.2's two variants, not about the
//! 500-entry cost, which `scripts/m4b_report.sh` measures. It runs the same
//! `groth16::measure` the driver runs, so a change that breaks the driver breaks
//! this too.

use ark_bn254::Fr;
use ark_r1cs_std::{alloc::AllocVar, fields::fp::FpVar};
use ark_relations::gr1cs::ConstraintSystem;
use avip_zk_prover::{fixture, groth16, native};

/// Four entries, and the floor norm that goes with them.
fn small() -> (Vec<u64>, u64) {
    let head: Vec<u64> = fixture::tensor().entries()[..4].to_vec();
    let sum: u128 = head.iter().map(|e| (*e as u128) * (*e as u128)).sum();
    (head, fixture::isqrt(sum) as u64)
}

/// `AVIPRegistry` reads `ic.length - 1` as its public-input count and
/// `Groth16Verifier` reverts unless `ic.length` matches the statement it is
/// handed. M4b's key must therefore carry exactly four `ic` entries.
#[test]
fn the_key_carries_the_contracts_public_input_count() {
    let (entries, norm) = small();
    let m = groth16::measure(&entries, norm, 0);
    assert_eq!(groth16::STATEMENT_LEN, 3);
    assert_eq!(groth16::IC_LEN, 4);
    assert_eq!(m.key.ic, groth16::IC_LEN, "ic must be public inputs + 1");
    assert_eq!(m.instance_variables, groth16::IC_LEN);
    assert!(m.verifies, "the fixture proof must verify");
    assert_eq!(m.proof_on_chain_bytes, 8 * 32);
}

/// The wrapper adds `epoch` to V3's statement — one more public input, plus the
/// cost of *binding* it. That cost is derived here from the gadget itself rather
/// than pinned as a number, so the test states why the two circuits differ by
/// what they differ by.
#[test]
fn the_statement_wrapper_adds_exactly_the_bound_epoch() {
    let (entries, norm) = small();
    let params = native::poseidon_params();
    let commitment = native::poseidon_commitment(&entries, &params);
    let (v3, synthesis) = native::synthesize(native::PoseidonNormCircuit {
        entries: entries.clone(),
        certified_norm_wad: norm,
        commitment,
        params,
    });
    synthesis.expect("V3 must synthesize");
    let m = groth16::measure(&entries, norm, 0);

    // V3's two public inputs are the norm and the commitment; the statement's
    // three are root, epoch and norm.
    assert_eq!(m.instance_variables, v3.instance_variables + 1);

    // Binding the epoch is `to_bits_le` (254 bits, `Fr`'s modulus) followed by
    // the zero-checks above `2^64`. Measured on a system of its own, the same way
    // the wrapper allocates it, so the equalities below are derived, not quoted.
    let cs = ConstraintSystem::<Fr>::new_ref();
    let epoch = FpVar::<Fr>::new_input(cs.clone(), || Ok(Fr::from(0u64))).expect("allocate epoch");
    native::enforce_below_pow2(&epoch, groth16::EPOCH_BITS).expect("bound the epoch");
    assert_eq!(groth16::EPOCH_BITS, 64);
    assert_eq!(cs.num_instance_variables(), 2, "the constant and the epoch");
    assert_eq!(
        m.witness_variables,
        v3.witness_variables + cs.num_witness_variables()
    );
    assert_eq!(m.constraints, v3.constraints + cs.num_constraints());
}

/// The whole point of wrapping: every component of the statement the contract
/// builds must be bound. `epoch` is the one that an *unused* public input would
/// silently survive — its `gamma_abc_g1` entry would be the identity — so it is
/// checked, not assumed.
#[test]
fn every_statement_component_is_bound() {
    let (entries, norm) = small();
    let m = groth16::measure(&entries, norm, 0);
    assert!(m.verifies, "the honest statement must verify");
    assert!(m.binding.epoch, "epoch+1 must be rejected");
    assert!(m.binding.root, "root+1 must be rejected");
    assert!(m.binding.norm, "norm+1 must be rejected");
}

/// The fixture must be reproducible: two runs of the same seeds, one proof. This
/// is what lets the table pin `keccak256(canonical)` instead of a duration.
#[test]
fn the_seeded_proof_is_byte_identical_across_runs() {
    let (entries, norm) = small();
    let first = groth16::measure(&entries, norm, 0);
    let second = groth16::measure(&entries, norm, 0);
    assert_eq!(first.vk_canonical_digest, second.vk_canonical_digest);
    assert_eq!(first.proof_canonical_digest, second.proof_canonical_digest);
    assert_eq!(first.proof_compressed_bytes, 128);
}

/// A different epoch is a different statement, and a different commitment is a
/// different statement: neither may inherit the other's proof.
#[test]
fn a_different_statement_does_not_reuse_the_proof() {
    let (entries, norm) = small();
    let at_zero = groth16::measure(&entries, norm, 0);
    let at_one = groth16::measure(&entries, norm, 1);
    assert_ne!(
        at_zero.proof_canonical_digest,
        at_one.proof_canonical_digest
    );
}

// ---- M4c: §5.5.2's two variants, through the same wrapper ---------------------

/// V2′ goes through the *same* statement wrapper as V3 — the same three public
/// inputs, in the same order — so `AVIPRegistry` cannot tell the variants apart
/// and the rows of `D-M4-0`'s duel are comparable. Checked on the circuits, with
/// no key: the shape is a property of the wrapper, not of this run.
#[test]
fn both_variants_carry_the_contract_shape() {
    let (entries, norm) = small();
    let (v3, r3) = native::synthesize(groth16::variant_circuit_for(
        groth16::Variant::V3,
        &entries,
        norm,
        0,
    ));
    let (v2, r2) = native::synthesize(groth16::variant_circuit_for(
        groth16::Variant::V2Pedersen,
        &entries,
        norm,
        0,
    ));
    r3.expect("V3 must synthesize");
    r2.expect("V2′ must synthesize");
    assert_eq!(v3.instance_variables, groth16::IC_LEN);
    assert_eq!(
        v2.instance_variables,
        groth16::IC_LEN,
        "one wrapper, one shape"
    );
    assert!(v3.satisfied, "V3 must be satisfied at its own root");
    assert!(
        v2.satisfied,
        "V2′ must be satisfied at the commitment it computes outside the circuit"
    );
}

/// The duel's headline number, **derived** rather than quoted: the wrapper is the
/// same code in both arms, so the gap between the two keys is exactly the gap
/// between the two commitments at the same `N`. The direction is asserted because
/// that is what `D-M4-0` turns on — `scripts/m4b_output.txt` carries the `N = 500`
/// numbers this test deliberately does not pay for.
#[test]
fn the_variant_gap_is_the_commitments_gap() {
    let (entries, norm) = small();
    let params = native::poseidon_params();
    let (v3_native, _) = native::synthesize(native::PoseidonNormCircuit {
        commitment: native::poseidon_commitment(&entries, &params),
        entries: entries.clone(),
        certified_norm_wad: norm,
        params,
    });
    let params = native::v2::PedersenParams::new(entries.len());
    let (v2_native, _) = native::synthesize(native::v2::PedersenNormCircuit {
        commitment: params.commitment(&entries),
        entries: entries.clone(),
        certified_norm_wad: norm,
        params,
    });
    let (v3, _) = native::synthesize(groth16::variant_circuit_for(
        groth16::Variant::V3,
        &entries,
        norm,
        0,
    ));
    let (v2, _) = native::synthesize(groth16::variant_circuit_for(
        groth16::Variant::V2Pedersen,
        &entries,
        norm,
        0,
    ));

    assert_eq!(
        v2.constraints - v2_native.constraints,
        v3.constraints - v3_native.constraints,
        "the wrapper is the same code, so it must cost the same on both sides"
    );
    assert_eq!(
        v2.constraints - v3.constraints,
        v2_native.constraints - v3_native.constraints
    );
    assert_eq!(
        v2.witness_variables - v3.witness_variables,
        v2_native.witness_variables - v3_native.witness_variables
    );
    assert!(
        v2_native.constraints > v3_native.constraints,
        "at this N the Pedersen commitment is the costly one"
    );
    assert!(
        v2.constraints > v3.constraints,
        "and the wrapper neither hides nor reverses that"
    );
}

/// A commitment is not a digest: the two variants' roots are different `Fr`
/// values, so neither variant's proof can be replayed as the other's statement.
#[test]
fn the_two_variants_have_different_roots() {
    let (entries, norm) = small();
    assert_ne!(
        groth16::variant_root(groth16::Variant::V3, &entries, norm, 0),
        groth16::variant_root(groth16::Variant::V2Pedersen, &entries, norm, 0)
    );
}

/// V2′ end to end: the key the contract would need, the proof, every component of
/// the statement bound, and the verdict the two measurements imply. The same
/// assertions M4b made of V3, plus the one M4c adds — that they are two different
/// statements — and the decision read as a value rather than as a substring.
#[test]
fn the_v2_prime_pipeline_meets_the_contracts_shape() {
    let (entries, norm) = small();
    let v3 = groth16::measure(&entries, norm, 0);
    let v2 = groth16::measure_variant(groth16::Variant::V2Pedersen, &entries, norm, 0);

    assert_eq!(v2.variant, groth16::Variant::V2Pedersen);
    assert_eq!(v2.key.ic, groth16::IC_LEN);
    assert_eq!(v2.instance_variables, groth16::IC_LEN);
    assert_eq!(v2.proof_on_chain_bytes, 8 * 32);
    assert!(v2.verifies, "V2′'s honest statement must verify");
    assert!(
        v2.binding.epoch && v2.binding.root && v2.binding.norm,
        "every component of V2′'s statement must be bound"
    );
    assert!(v2.render().contains("over V2′"), "the table must name it");

    assert_ne!(v2.vk_canonical_digest, v3.vk_canonical_digest);
    assert_ne!(v2.proof_canonical_digest, v3.proof_canonical_digest);

    // The verdict is computed from the two measurements, never written into the
    // string, so this is the same decision `scripts/m4b_output.txt` renders for
    // `N = 500` — with the numbers quoted there instead of here.
    let (winner, why) = groth16::duel_verdict(&v3, &v2);
    assert_eq!(winner, groth16::Variant::V3);
    assert!(
        why.contains("more constraints"),
        "the reason must name the gap: {}",
        why
    );
    assert!(
        groth16::render_duel(&v3, &v2).contains(&format!(
            "  decision                  {} — {} pays {}",
            winner.name(),
            groth16::Variant::V2Pedersen.name(),
            why
        )),
        "the table must state the verdict the numbers imply"
    );
}
