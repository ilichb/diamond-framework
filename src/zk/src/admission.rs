//! M4d — the admission statement the contracts actually need (audit 2026-10-20,
//! findings P-01 and P-16).
//!
//! The M4b statement certified a *global* norm of a 500-entry tensor and did not
//! mention the validator. A proof for that statement is a bearer token: anyone
//! may present it for any address. This module replaces it for admission with an
//! **inclusion proof of one leaf**:
//!
//! ```text
//! leaf_i  = Poseidon(validator_i, norm_i)
//! root    = Poseidon Merkle root over 2^9 leaves (500 real, zero-padded)
//! public  = [root, epoch, validator, norm]
//! witness = (merkle path, leaf index)
//! ```
//!
//! The circuit constrains `validator` and `norm` inside the leaf, so a proof for
//! validator `v` cannot be replayed for `u`: the verifier's statement changes.
//! The path and index are private, so the proving key is index-independent.
//!
//! This tree is deliberately not M1's keccak tree: keccak inside BN254 is
//! infeasible at this size. `AVIPRegistry` stores both roots per epoch — keccak
//! for `verifyEntry`, Poseidon for this statement — and the off-chain bridge
//! recomputes both from the same leaves. That is P-16's two-slot remediation.
//!
//! The score is the validator's own committed norm, not the Frobenius norm of
//! the 500-validator vector. This matches the data layer's `Entry` (one norm per
//! validator) and the paper's per-validator `T(i)`.

use std::time::{Duration, Instant};

use ark_bn254::Fr;
use ark_crypto_primitives::sponge::{
    CryptographicSponge, FieldBasedCryptographicSponge,
    constraints::CryptographicSpongeVar,
    poseidon::{PoseidonConfig, PoseidonSponge, constraints::PoseidonSpongeVar},
};
use ark_ff::{BigInteger, PrimeField, Zero};
use ark_groth16::{Groth16, Proof, ProvingKey, prepare_verifying_key};
use ark_r1cs_std::{
    alloc::AllocVar, eq::EqGadget, fields::FieldVar, fields::fp::FpVar, prelude::Boolean,
    select::CondSelectGadget,
};
use ark_relations::gr1cs::{ConstraintSynthesizer, ConstraintSystemRef, SynthesisError};
use ark_serialize::{CanonicalSerialize, Compress};
use sha3::{Digest, Keccak256};

use crate::fixture::{ENTRY_BITS, N, WAD};
use crate::native;

/// Public inputs: `[root, epoch, validator, norm]`.
pub const STATEMENT_LEN: usize = 4;
/// `Groth16Verifier` wants `ic.length == publicInputs + 1`.
pub const IC_LEN: usize = STATEMENT_LEN + 1;
/// `ceil(log2(512))`.
pub const TREE_DEPTH: usize = 9;
/// `2^TREE_DEPTH`.
pub const TREE_LEAVES: usize = 1 << TREE_DEPTH;
/// An address is a `uint160`.
pub const VALIDATOR_BITS: usize = 160;
/// Bits the epoch can reach.
pub const EPOCH_BITS: usize = 64;

/// Development seeds: public toxic waste, reproducible fixture.
pub const SETUP_SEED: [u8; 32] = *b"AVIP-M4d-dev-setup-1-admission!!";
/// Proof seed, pinned for a byte-identical Solidity fixture.
pub const PROOF_SEED: [u8; 32] = *b"AVIP-M4d-dev-proof-1-admission!!";

const _: () = assert!(SETUP_SEED.len() == 32);
const _: () = assert!(PROOF_SEED.len() == 32);

/// `address` as a field element. Twenty big-endian bytes, reduced modulo `Fr`;
/// the circuit separately enforces the 160-bit range.
#[must_use]
pub fn validator_fr(validator: &[u8; 20]) -> Fr {
    Fr::from_be_bytes_mod_order(validator)
}

/// Poseidon over two field elements: the tree's node and leaf function.
#[must_use]
pub fn hash2(left: Fr, right: Fr, params: &PoseidonConfig<Fr>) -> Fr {
    let mut sponge = PoseidonSponge::<Fr>::new(params);
    sponge.absorb(&vec![left, right]);
    sponge.squeeze_native_field_elements(1)[0]
}

/// The leaf of one validator's reputation entry.
#[must_use]
pub fn leaf(validator: &[u8; 20], norm_wad: u64, params: &PoseidonConfig<Fr>) -> Fr {
    hash2(validator_fr(validator), Fr::from(norm_wad), params)
}

/// The 512 leaves: one per validator, then zero padding.
#[must_use]
pub fn leaves(validators: &[[u8; 20]], norms: &[u64], params: &PoseidonConfig<Fr>) -> Vec<Fr> {
    assert_eq!(validators.len(), N, "the tree is defined for N validators");
    assert_eq!(norms.len(), N, "one norm per validator");
    let mut out = Vec::with_capacity(TREE_LEAVES);
    for i in 0..TREE_LEAVES {
        if i < N {
            out.push(leaf(&validators[i], norms[i], params));
        } else {
            out.push(Fr::zero());
        }
    }
    out
}

/// The tree, level by level, leaves first.
#[must_use]
pub fn levels(validators: &[[u8; 20]], norms: &[u64], params: &PoseidonConfig<Fr>) -> Vec<Vec<Fr>> {
    let mut levels = vec![leaves(validators, norms, params)];
    while levels.last().expect("at least one level").len() > 1 {
        let current = levels.last().expect("level");
        let next = current
            .chunks_exact(2)
            .map(|pair| hash2(pair[0], pair[1], params))
            .collect();
        levels.push(next);
    }
    levels
}

/// The Poseidon Merkle root of the admission tree.
#[must_use]
pub fn statement_root(validators: &[[u8; 20]], norms: &[u64], params: &PoseidonConfig<Fr>) -> Fr {
    *levels(validators, norms, params)
        .last()
        .expect("root level")
        .first()
        .expect("one root")
}

/// The nine siblings of `index`, bottom-up.
#[must_use]
pub fn merkle_path(
    validators: &[[u8; 20]],
    norms: &[u64],
    index: usize,
    params: &PoseidonConfig<Fr>,
) -> Vec<Fr> {
    assert!(index < N, "only a real entry has an admission proof");
    let mut all = levels(validators, norms, params);
    let mut i = index;
    let mut path = Vec::with_capacity(TREE_DEPTH);
    for level in all.drain(..TREE_DEPTH) {
        path.push(level[i ^ 1]);
        i /= 2;
    }
    path
}

/// Recompute a root from a leaf, path and index: the off-circuit twin of the
/// circuit's fold.
#[must_use]
pub fn root_from_path(leaf: Fr, path: &[Fr], index: usize, params: &PoseidonConfig<Fr>) -> Fr {
    let mut node = leaf;
    for (level, sibling) in path.iter().enumerate() {
        node = if (index >> level) & 1 == 0 {
            hash2(node, *sibling, params)
        } else {
            hash2(*sibling, node, params)
        };
    }
    node
}

/// R1CS Poseidon over two variables.
fn hash2_var(
    cs: ConstraintSystemRef<Fr>,
    params: &PoseidonConfig<Fr>,
    left: &FpVar<Fr>,
    right: &FpVar<Fr>,
) -> Result<FpVar<Fr>, SynthesisError> {
    let mut sponge = PoseidonSpongeVar::<Fr>::new(cs, params);
    sponge.absorb(&vec![left.clone(), right.clone()])?;
    Ok(sponge.squeeze_field_elements(1)?[0].clone())
}

/// Public `[root, epoch, validator, norm]`, private `(path[9], index[9])`.
pub struct AdmissionCircuit {
    /// Public: the Poseidon Merkle root posted for the epoch.
    pub root: Fr,
    /// Public: the epoch the root belongs to.
    pub epoch: u64,
    /// Public: the validator whose entry is proven.
    pub validator: [u8; 20],
    /// Public: that validator's certified norm, in WAD.
    pub norm_wad: u64,
    /// Witness: nine siblings, bottom-up.
    pub path: Vec<Fr>,
    /// Witness: the leaf index, used only for the left/right order.
    pub index: usize,
    /// Poseidon parameters.
    pub params: PoseidonConfig<Fr>,
}

impl ConstraintSynthesizer<Fr> for AdmissionCircuit {
    fn generate_constraints(self, cs: ConstraintSystemRef<Fr>) -> Result<(), SynthesisError> {
        let root = FpVar::new_input(cs.clone(), || Ok(self.root))?;
        let epoch = FpVar::new_input(cs.clone(), || Ok(Fr::from(self.epoch)))?;
        let validator = FpVar::new_input(cs.clone(), || Ok(validator_fr(&self.validator)))?;
        let norm = FpVar::new_input(cs.clone(), || Ok(Fr::from(self.norm_wad)))?;

        // A Solidity address is 160 bits and cannot be zero. Without the width
        // check, field aliasing would let two addresses share a leaf; without
        // the zero check, only the manager's guard would reject the empty one.
        native::enforce_below_pow2(&validator, VALIDATOR_BITS)?;
        validator.enforce_not_equal(&FpVar::zero())?;

        // P-33: the score is a WAD value strictly below 1.0. The old circuit
        // accepted up to 2^60, i.e. more than 1.0 WAD.
        //
        // The remaining bound is one-sided. `WAD - norm - 1` is computed in the
        // field and required to be below `2^60`, so a `norm` within `2^60` of
        // the modulus — `[-2^60 + WAD, -1]`, i.e. `[p - 152_921_504_606_846_977,
        // p - 1]` — wraps that difference back into range and satisfies the
        // check. This crate cannot express such a witness (`norm_wad` is a
        // `u64`), but the circuit description and the key are public: a prover
        // with its own witness generator can. Nothing in this constraint stops
        // it, and nothing in the proof system can, because a public input *is*
        // a field element with no canonical representative. Two closures:
        // `AVIPRegistry.verifyThreshold` refuses `certifiedNorm >= WAD` before
        // the pairing (the only way the value reaches a state machine), and the
        // in-circuit lower bound — one more `enforce_below_pow2(norm,
        // ENTRY_BITS)`, which is the bit decomposition `to_bits_le` allocates —
        // is owed to the key regeneration that P-03 forces, since it changes
        // the `vk`, the fixture and the gas figures.
        let wad = FpVar::constant(Fr::from(WAD));
        native::enforce_below_pow2(&(wad - norm.clone() - FpVar::one()), ENTRY_BITS)?;

        // The leaf is public data: the proof says "this (validator, norm) pair
        // is in the committed tree", not "I know a secret score".
        let mut node = hash2_var(cs.clone(), &self.params, &validator, &norm)?;

        let mut siblings = Vec::with_capacity(TREE_DEPTH);
        for i in 0..TREE_DEPTH {
            siblings.push(FpVar::new_witness(cs.clone(), || {
                Ok(*self.path.get(i).unwrap_or(&Fr::zero()))
            })?);
        }

        for (level, sibling) in siblings.iter().enumerate() {
            let bit = Boolean::new_witness(cs.clone(), || Ok(((self.index >> level) & 1) == 1))?;
            let ordered_left = FpVar::conditionally_select(&bit, sibling, &node)?;
            let ordered_right = FpVar::conditionally_select(&bit, &node, sibling)?;
            node = hash2_var(cs.clone(), &self.params, &ordered_left, &ordered_right)?;
        }

        node.enforce_equal(&root)?;
        native::enforce_below_pow2(&epoch, EPOCH_BITS)
    }
}

/// The circuit for one entry of a committed tree.
#[must_use]
pub fn circuit_for(
    validators: &[[u8; 20]],
    norms: &[u64],
    index: usize,
    epoch: u64,
) -> AdmissionCircuit {
    let params = native::poseidon_params();
    AdmissionCircuit {
        root: statement_root(validators, norms, &params),
        epoch,
        validator: validators[index],
        norm_wad: norms[index],
        path: merkle_path(validators, norms, index, &params),
        index,
        params,
    }
}

/// The public input vector in the contract's order.
#[must_use]
pub fn statement_inputs(
    root: Fr,
    epoch: u64,
    validator: &[u8; 20],
    norm_wad: u64,
) -> [Fr; STATEMENT_LEN] {
    [
        root,
        Fr::from(epoch),
        validator_fr(validator),
        Fr::from(norm_wad),
    ]
}

/// A seeded development key and the fixture proof.
pub struct DevKey {
    pub pk: ProvingKey<ark_bn254::Bn254>,
    pub proof: Proof<ark_bn254::Bn254>,
    pub setup_time: Duration,
    pub prove_time: Duration,
}

/// Generate the seeded key and proof for one admission statement.
#[must_use]
pub fn key_and_proof(validators: &[[u8; 20]], norms: &[u64], index: usize, epoch: u64) -> DevKey {
    use ark_std::rand::SeedableRng;
    use rand_chacha::ChaCha20Rng;

    let mut rng = ChaCha20Rng::from_seed(SETUP_SEED);
    let started = Instant::now();
    let pk = Groth16::<ark_bn254::Bn254>::generate_random_parameters_with_reduction(
        circuit_for(validators, norms, index, epoch),
        &mut rng,
    )
    .expect("development setup");
    let setup_time = started.elapsed();

    let mut rng = ChaCha20Rng::from_seed(PROOF_SEED);
    let started = Instant::now();
    let proof = Groth16::<ark_bn254::Bn254>::create_random_proof_with_reduction(
        circuit_for(validators, norms, index, epoch),
        &pk,
        &mut rng,
    )
    .expect("prove");
    let prove_time = started.elapsed();

    DevKey {
        pk,
        proof,
        setup_time,
        prove_time,
    }
}

/// Whether a proof verifies against its key and statement.
#[must_use]
pub fn verifies(
    pk: &ProvingKey<ark_bn254::Bn254>,
    proof: &Proof<ark_bn254::Bn254>,
    inputs: &[Fr; STATEMENT_LEN],
) -> bool {
    let pvk = prepare_verifying_key(&pk.vk);
    Groth16::<ark_bn254::Bn254>::verify_proof(&pvk, proof, &inputs[..]).unwrap_or(false)
}

/// A measurement of the admission circuit.
#[derive(Clone, Debug)]
pub struct Measurement {
    pub constraints: usize,
    pub instance_variables: usize,
    pub witness_variables: usize,
    pub ic: usize,
    pub root: Fr,
    pub epoch: u64,
    pub validator: [u8; 20],
    pub norm_wad: u64,
    pub verifies: bool,
    pub binding: [bool; STATEMENT_LEN],
    pub vk_digest: String,
    pub proof_digest: String,
    pub setup_time: Duration,
    pub prove_time: Duration,
}

/// Synthesize, key, prove, verify and mutate one admission statement.
#[must_use]
pub fn measure(validators: &[[u8; 20]], norms: &[u64], index: usize, epoch: u64) -> Measurement {
    let params = native::poseidon_params();
    let (cost, synthesized) = native::synthesize(circuit_for(validators, norms, index, epoch));
    synthesized.expect("the admission circuit must synthesize");
    assert!(
        cost.satisfied,
        "the fixture statement must satisfy its own circuit"
    );

    let dev = key_and_proof(validators, norms, index, epoch);
    let root = statement_root(validators, norms, &params);
    let inputs = statement_inputs(root, epoch, &validators[index], norms[index]);
    let verified = verifies(&dev.pk, &dev.proof, &inputs);

    let mut binding = [true; STATEMENT_LEN];
    for i in 0..STATEMENT_LEN {
        let mut changed = inputs;
        changed[i] += Fr::from(1u64);
        binding[i] = !verifies(&dev.pk, &dev.proof, &changed);
    }

    Measurement {
        constraints: cost.constraints,
        instance_variables: cost.instance_variables,
        witness_variables: cost.witness_variables,
        ic: dev.pk.vk.gamma_abc_g1.len(),
        root,
        epoch,
        validator: validators[index],
        norm_wad: norms[index],
        verifies: verified,
        binding,
        vk_digest: canonical_digest(&dev.pk.vk),
        proof_digest: canonical_digest(&dev.proof),
        setup_time: dev.setup_time,
        prove_time: dev.prove_time,
    }
}

/// `keccak256` of the canonical compressed serialization, lowercase hex.
#[must_use]
pub fn canonical_digest<T: CanonicalSerialize>(value: &T) -> String {
    let mut bytes = Vec::new();
    value
        .serialize_with_mode(&mut bytes, Compress::Yes)
        .expect("serialize into a Vec");
    let digest: [u8; 32] = Keccak256::digest(&bytes).into();
    let mut s = String::with_capacity(64);
    for b in digest {
        s.push_str(&format!("{b:02x}"));
    }
    s
}

/// A field element in 32 big-endian bytes, the `uint256` the contract reads.
#[must_use]
pub fn root_bytes(root: Fr) -> [u8; 32] {
    let mut out = [0_u8; 32];
    let bytes = root.into_bigint().to_bytes_be();
    out[32 - bytes.len()..].copy_from_slice(&bytes);
    out
}

/// Lowercase hex of a 20-byte address.
#[must_use]
pub fn validator_hex(validator: &[u8; 20]) -> String {
    let mut s = String::with_capacity(40);
    for b in validator {
        s.push_str(&format!("{b:02x}"));
    }
    s
}
