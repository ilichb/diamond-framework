//! M4b: the contract-facing shape of the key, and what the statement wrapper
//! costs on top of §5.5.6's pinned V3.
//!
//! A small tensor on purpose: the assertions are about *shape* (how many public
//! inputs, how many `ic` entries, whether every statement component is bound),
//! not about the 500-entry cost, which `scripts/m4b_report.sh` measures. It runs
//! the same `groth16::measure` the driver runs, so a change that breaks the
//! driver breaks this too.

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
