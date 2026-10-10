//! The native BN254 circuit of plan §5.5.3: commitment + norm in one circuit.
//!
//! Field discipline (what makes "native" checkable): the outer proof M4b
//! installs is a Groth16 proof over BN254 whose **constraint field is `Fr`**, so
//! every variable in the circuit lives in `Fr`. The norm is `Fr` arithmetic; a
//! commitment is native only if its group is defined over `Fr`.
//!
//! That is why the variants differ. §5.5.2's V2 row cannot be taken literally
//! (its group is defined over `Fq`) — see [`v2`] for the recorded evidence *and*
//! for **V2′**, the native repair, which this module implements.

use std::time::{Duration, Instant};

use ark_bn254::Fr;
use ark_crypto_primitives::sponge::{
    CryptographicSponge, FieldBasedCryptographicSponge,
    constraints::CryptographicSpongeVar,
    poseidon::{
        PoseidonConfig, PoseidonSponge, constraints::PoseidonSpongeVar, find_poseidon_ark_and_mds,
    },
};
use ark_ff::PrimeField;
use ark_r1cs_std::{
    alloc::AllocVar,
    eq::EqGadget,
    fields::FieldVar,
    fields::fp::FpVar,
    prelude::{Boolean, ToBitsGadget},
};
use ark_relations::gr1cs::{
    ConstraintSynthesizer, ConstraintSystem, ConstraintSystemRef, SynthesisError,
};

use crate::fixture::ENTRY_BITS;

/// What one synthesized circuit costs. `generate_constraints` is the proof-generation
/// pass, so these are the numbers a Groth16 key would be sized against.
#[derive(Clone, Copy, Debug)]
pub struct CircuitCost {
    pub constraints: usize,
    pub instance_variables: usize,
    pub witness_variables: usize,
    pub synthesize_time: Duration,
    pub satisfied: bool,
}

/// Synthesize `circuit` in a fresh constraint system and report its cost.
pub fn synthesize<C: ConstraintSynthesizer<Fr>>(
    circuit: C,
) -> (CircuitCost, Result<(), SynthesisError>) {
    let cs = ConstraintSystem::<Fr>::new_ref();
    let started = Instant::now();
    let result = circuit.generate_constraints(cs.clone());
    let synthesize_time = started.elapsed();
    let cost = CircuitCost {
        constraints: cs.num_constraints(),
        instance_variables: cs.num_instance_variables(),
        witness_variables: cs.num_witness_variables(),
        synthesize_time,
        satisfied: cs.is_satisfied().unwrap_or(false),
    };
    (cost, result)
}

/// The entries as `k = 60` Booleans each. This *is* the range check of §5.5.3: an
/// out-of-range entry has no witness, so no numerical comparison that could
/// overflow is needed.
///
/// Exposed separately because a commitment can consume the *bits* directly — V2′
/// does (§5.5.2), since Baby Jubjub's scalar field is not `Fr_BN254` — and it
/// would then pay for a second decomposition if it had to start from
/// [`allocate_entries`]'s `FpVar`s.
pub fn allocate_entry_bits(
    cs: &ConstraintSystemRef<Fr>,
    entries: &[u64],
) -> Result<Vec<Vec<Boolean<Fr>>>, SynthesisError> {
    entries
        .iter()
        .map(|e| {
            (0..ENTRY_BITS)
                .map(|j| {
                    let bit = (e >> j) & 1 == 1;
                    Boolean::new_witness(cs.clone(), || Ok(bit))
                })
                .collect::<Result<Vec<_>, _>>()
        })
        .collect()
}

/// [`allocate_entry_bits`], with each entry rebuilt as an `Fr` element.
pub fn allocate_entries(
    cs: &ConstraintSystemRef<Fr>,
    entries: &[u64],
) -> Result<Vec<FpVar<Fr>>, SynthesisError> {
    allocate_entry_bits(cs, entries)?
        .iter()
        .map(|bits| Boolean::le_bits_to_fp(bits))
        .collect()
}

/// `Σ T_i²`, in `Fr`. The plan's worst case (`N·1e36 = 5e38`, 129 bits) lives
/// here, not in `u128`: `Fr` is 254 bits, so the sum cannot wrap (§5.5.3).
pub fn sum_of_squares(entries: &[FpVar<Fr>]) -> Result<FpVar<Fr>, SynthesisError> {
    let mut sum = FpVar::<Fr>::zero();
    for x in entries {
        sum += x * x;
    }
    Ok(sum)
}

/// Bits of headroom for `Σ T_i²` and for the differences below. Entries are
/// `k = 60` bits and `N = 500`, so `Σ T_i² < N·2^120 < 2^129` — the margin is the
/// plan's own (§5.5.3). A difference that wraps does so to ≈`r − 2^129`, which
/// no bound this size can pass, which is what makes the checks sound.
const SUM_BOUND_BITS: usize = 130;
/// A WAD norm is below `3e18 < 2^62` (the plan's `[0, 3]` simulated range), so 64
/// bits bounds it. The bound matters for soundness and not just for taste: it
/// keeps `certified² < 2^128 ≪ r`, so a `certified` that exceeds the real norm
/// cannot wrap into a small difference and pass.
const CERTIFIED_BOUND_BITS: usize = 64;

/// Enforce `value < 2^bound_bits` by decomposing and zeroing the high bits.
/// Nothing here compares two variables: the comparison gadgets available in
/// `ark-r1cs-std 0.6.0` are not used, and `CmpGadget for [T]` is not correct for
/// this purpose (its `∧ᵢ (aᵢ > bᵢ ∨ equal_up_to_i)` rejects `"10" ≥ "09"`),
/// so the inequalities below are decided by a bound plus a difference.
pub fn enforce_below_pow2(value: &FpVar<Fr>, bound_bits: usize) -> Result<(), SynthesisError> {
    for bit in value.to_bits_le()?.iter().skip(bound_bits) {
        bit.enforce_equal(&Boolean::FALSE)?;
    }
    Ok(())
}

/// `certifiedNorm = ⌊√(Σ T_i²)⌋`, encoded **without** a square root:
/// `c² ≤ Σ T_i² < (c+1)²`.
///
/// §5.5.1 states the relation as equality on squares, `Σ T_i² = certifiedNorm²`.
/// M4a verified against a real tensor that the exact form has no witness:
/// entries `[1..8]` give `Σ T_i² = 204` while `⌊√204⌋ = 14` and `14² = 196`, so
/// the two sides cannot be equal — and a WAD tensor whose sum of squares is a
/// perfect square is a measure-zero event, not a case a protocol can require.
/// The floor encoding is the satisfiable form. It preserves the on-chain
/// semantics, because `Θ_r` is an integer: `⌊‖T‖_F⌋ ≥ Θ_r ⟺ ‖T‖_F ≥ Θ_r`, so
/// `AVIPRegistry.verifyThreshold`'s comparison is unchanged.
///
/// Soundness, in one paragraph: `c < 2^64` is enforced, so `c² < 2^128` and
/// `(c+1)² < 2^130`; `Σ T_i² < 2^129` by construction. Both checks are of the
/// form "a difference is below `2^130`", and a difference that is *negative*
/// wraps into `[r − 2^130, r)`, which cannot pass. Hence passing implies
/// `Σ T_i² ≥ c²` and `(c+1)² > Σ T_i²` as integers, which is the floor.
pub fn enforce_floor_norm(squares: FpVar<Fr>, certified: FpVar<Fr>) -> Result<(), SynthesisError> {
    let one = FpVar::<Fr>::constant(Fr::from(1u64));
    let lower = certified.clone() * certified.clone();
    let upper = {
        let next = certified.clone() + one.clone();
        next.clone() * next
    };

    enforce_below_pow2(&certified, CERTIFIED_BOUND_BITS)?;
    enforce_below_pow2(&(squares.clone() - lower), SUM_BOUND_BITS)?;
    enforce_below_pow2(&(upper - squares - one), SUM_BOUND_BITS)
}

/// Poseidon parameters for `Fr_BN254`: `t = 3` (`rate = 2`, `capacity = 1`),
/// `alpha = 5`, `Rf = 8`, `Rp = 57` — the parameters of the widely deployed
/// BN254 Poseidon instance. Derived here rather than copied as constants, so the
/// `ark`/`mds` tables come from the crate's own LFSR.
pub fn poseidon_params() -> PoseidonConfig<Fr> {
    const RATE: usize = 2;
    const CAPACITY: usize = 1;
    const FULL_ROUNDS: u64 = 8;
    const PARTIAL_ROUNDS: u64 = 57;
    const ALPHA: u64 = 5;
    let (ark, mds) = find_poseidon_ark_and_mds::<Fr>(
        Fr::MODULUS_BIT_SIZE as u64,
        RATE,
        FULL_ROUNDS,
        PARTIAL_ROUNDS,
        0,
    );
    PoseidonConfig {
        full_rounds: FULL_ROUNDS as usize,
        partial_rounds: PARTIAL_ROUNDS as usize,
        alpha: ALPHA,
        ark,
        mds,
        rate: RATE,
        capacity: CAPACITY,
    }
}

/// The native Poseidon digest of the entries: the value V3's circuit proves it
/// computed, the analogue of the `keccak256` root on the chain side.
pub fn poseidon_commitment(entries: &[u64], params: &PoseidonConfig<Fr>) -> Fr {
    let elements: Vec<Fr> = entries.iter().copied().map(Fr::from).collect();
    let mut sponge = PoseidonSponge::<Fr>::new(params);
    sponge.absorb(&elements);
    sponge.squeeze_native_field_elements(1)[0]
}

/// `certifiedNorm = ⌊√(Σ T_i²)⌋` (§5.5.1: an equality the contract reads, tested
/// without a square root), with the range folded into [`allocate_entries`]. The
/// exact-square form §5.5.1 writes is unsatisfiable for real tensors — see
/// [`enforce_floor_norm`] for the verification and the reason the floor keeps
/// the on-chain semantics.
///
/// The public input is `certifiedNorm` in WAD, the same value M3's statement
/// carries as `certifiedNorm`; `root` and `epoch` are not circuit inputs — M4b
/// binds them through the Groth16 public-input vector.
pub struct NormCircuit {
    /// Witness: the `N` WAD entries.
    pub entries: Vec<u64>,
    /// Public: the norm the statement certifies, in WAD.
    pub certified_norm_wad: u64,
}

impl ConstraintSynthesizer<Fr> for NormCircuit {
    fn generate_constraints(self, cs: ConstraintSystemRef<Fr>) -> Result<(), SynthesisError> {
        let entry_vars = allocate_entries(&cs, &self.entries)?;
        let squares = sum_of_squares(&entry_vars)?;
        let certified = FpVar::new_input(cs.clone(), || Ok(Fr::from(self.certified_norm_wad)))?;
        enforce_floor_norm(squares, certified)
    }
}

/// V3 of §5.5.2: Poseidon over the 500 entries, in-circuit, plus the same norm.
///
/// The commitment is a *public input* of the circuit: the prover claims the
/// digest of its private tensor, and the contract side can bind it to the posted
/// root (§5.5.7 keeps that bridge, option (c), for **M7**).
pub struct PoseidonNormCircuit {
    /// Witness: the `N` WAD entries.
    pub entries: Vec<u64>,
    /// Public: the norm the statement certifies, in WAD.
    pub certified_norm_wad: u64,
    /// Public: the Poseidon digest, from [`poseidon_commitment`].
    pub commitment: Fr,
    /// The instantiated parameters, from [`poseidon_params`].
    pub params: PoseidonConfig<Fr>,
}

impl ConstraintSynthesizer<Fr> for PoseidonNormCircuit {
    fn generate_constraints(self, cs: ConstraintSystemRef<Fr>) -> Result<(), SynthesisError> {
        let entry_vars = allocate_entries(&cs, &self.entries)?;
        let squares = sum_of_squares(&entry_vars)?;
        let certified = FpVar::new_input(cs.clone(), || Ok(Fr::from(self.certified_norm_wad)))?;
        enforce_floor_norm(squares, certified)?;

        let mut sponge = PoseidonSpongeVar::<Fr>::new(cs.clone(), &self.params);
        sponge.absorb(&entry_vars)?;
        let squeezed = sponge.squeeze_field_elements(1)?;
        let committed = FpVar::new_input(cs.clone(), || Ok(self.commitment))?;
        squeezed[0].enforce_equal(&committed)
    }
}

/// The recorded status of §5.5.2's **V2 row**, which is what M4a's source-level
/// method found. This module has no code on purpose: what it records is that the
/// code V2 describes cannot be written natively.
///
/// §5.5.2 says V2 is "Pedersen over BN254 G1, recomputed **inside** the circuit"
/// with "**no** curve mismatch: everything native". Checked against the crates:
///
/// - A BN254 G1 point has coordinates in `Fq` (`ark_bn254::g1::Config` declares
///   `COEFF_A: Fq`), and `Fq ≠ Fr` (`Fq::MODULUS` and `Fr::MODULUS` differ).
/// - A variable holding a G1 point is
///   `ProjectiveVar<P, F>` with `F: FieldVar<P::BaseField, BasePrimeField<P>>`,
///   i.e. `FpVar<Fq>` for BN254 — and that constraint field is `Fq`.
/// - M4b installs a Groth16 proof over **BN254**, whose constraint field is `Fr`.
///   Proving a circuit over `Fq` would need a pairing curve with scalar field
///   `Fq`; the alt_bn128 verifier M3 froze is not one.
/// - So `ProjectiveVar<ark_bn254::g1::Config, FpVar<Fr>>` does not type-check
///   (E0277: `FpVar<Fr>` does not implement `FieldVar<Fq, Fq>`), and the
///   alternative — `Fq` arithmetics emulated inside `Fr` — needs the non-native
///   **curve** gadget §5.5.4 established `ark-r1cs-std 0.6.0` does not have.
///
/// This is the §5.5.5 wall one level down: V1 needed Ristretto inside `Fr`, V2 as
/// written needs `Fq` inside `Fr`. The live repairs are V2′ — Pedersen over a
/// curve defined **over `Fr`** (`ark-ed-on-bn254`, Baby Jubjub), which is native
/// but is *not* "Pedersen over BN254 G1" — or V3, which needs no curve at all.
pub mod v2 {
    use ark_ec::{AdditiveGroup, CurveGroup, PrimeGroup, VariableBaseMSM};
    use ark_ed_on_bn254::{EdwardsConfig, EdwardsProjective, Fr as JubjubScalar};
    use ark_ff::PrimeField;
    use ark_r1cs_std::{
        alloc::AllocVar,
        eq::EqGadget,
        groups::{CurveVar, curves::twisted_edwards::AffineVar},
    };
    use rand_chacha::ChaCha20Rng;
    use rand_core::{RngCore, SeedableRng};

    use super::{
        Boolean, ConstraintSynthesizer, ConstraintSystemRef, ENTRY_BITS, FpVar, Fr, SynthesisError,
        allocate_entry_bits, enforce_floor_norm, sum_of_squares,
    };

    /// One line for the measured table.
    pub const STATUS: &str = "V2 as written (Pedersen over BN254 G1 in a Fr circuit): \
        blocked — non-native, and 0.6.0 has no non-native curve gadget (§5.5.4); \
        V2' (Pedersen over Baby Jubjub, base field Fr) is the native repair";

    /// The two fields the wall is made of.
    pub fn field_facts() -> (u64, u64) {
        (
            ark_bn254::Fq::MODULUS_BIT_SIZE as u64,
            ark_bn254::Fr::MODULUS_BIT_SIZE as u64,
        )
    }

    // ---- V2′: the native repair -------------------------------------------------

    /// The dev seed for V2′'s Pedersen bases. Committed on purpose, exactly like
    /// `groth16::SETUP_SEED`: it makes the parameter set reproducible, **and** it
    /// makes the discrete-log relations between the bases public, so this
    /// commitment binds nobody. §11 owns what a deployment would need.
    pub const PEDERSEN_SEED: [u8; 32] = *b"AVIP-M4-v2p-dev-bases-0000000001";

    /// The public parameters of V2′: `n` Pedersen bases over Baby Jubjub, with
    /// the `ENTRY_BITS` power-of-two multiples the fixed-base gadget consumes.
    ///
    /// Baby Jubjub's **base field is `Fr_BN254`** (`ark_ed_on_bn254::Fq =
    /// ark_bn254::Fr`), which is why its coordinates are native in the
    /// Groth16/BN254 circuit — and why V2′ is *not* V2: they are different groups.
    /// Its **scalar field is a different 251-bit prime**, so an in-circuit scalar
    /// cannot be an `FpVar<Fr_BN254>`. It is the entry's bit decomposition, which
    /// is exactly what §5.5.3's range check already allocates.
    #[derive(Clone, Debug)]
    pub struct PedersenParams {
        bases: Vec<EdwardsProjective>,
        multiples: Vec<Vec<EdwardsProjective>>,
    }

    impl PedersenParams {
        /// `n` bases from [`PEDERSEN_SEED`]: `Gᵢ = sᵢ·G`, each `sᵢ` drawn from
        /// the seed and reduced into Baby Jubjub's scalar field.
        pub fn new(n: usize) -> Self {
            let mut rng = ChaCha20Rng::from_seed(PEDERSEN_SEED);
            let generator = EdwardsProjective::generator();
            let bases: Vec<EdwardsProjective> = (0..n)
                .map(|_| {
                    let mut bytes = [0u8; 32];
                    rng.fill_bytes(&mut bytes);
                    generator * JubjubScalar::from_le_bytes_mod_order(&bytes)
                })
                .collect();
            let multiples = bases
                .iter()
                .map(|base| {
                    let mut powers = Vec::with_capacity(ENTRY_BITS);
                    let mut point = *base;
                    for _ in 0..ENTRY_BITS {
                        powers.push(point);
                        point.double_in_place();
                    }
                    powers
                })
                .collect();
            Self { bases, multiples }
        }

        /// The `n` bases, for the out-of-circuit commitment.
        pub fn bases(&self) -> &[EdwardsProjective] {
            &self.bases
        }

        /// Per base, `[Gᵢ, 2Gᵢ, …, 2^(ENTRY_BITS−1)Gᵢ]`: the tables the gadget
        /// looks up.
        pub fn multiples(&self) -> &[Vec<EdwardsProjective>] {
            &self.multiples
        }

        /// `Σ Tᵢ·Gᵢ`, **outside** the circuit, by one multi-scalar
        /// multiplication. This is a second, independent implementation of the
        /// gadget's semantics, and a test asserts the two agree — so "the circuit
        /// proves the commitment" is checked rather than believed.
        pub fn commitment(&self, entries: &[u64]) -> EdwardsProjective {
            let scalars: Vec<JubjubScalar> =
                entries.iter().copied().map(JubjubScalar::from).collect();
            let affine = EdwardsProjective::normalize_batch(&self.bases);
            EdwardsProjective::msm(&affine, &scalars).expect("one base per entry, by construction")
        }

        /// The commitment's x-coordinate: the single field element the frozen
        /// statement has room for (`uint256 root`). A full point would need two
        /// words, which is a §5.5.7 (M7) question — the statement shape is M3's
        /// and neither this decision nor the measurement moves it.
        pub fn commitment_x(&self, entries: &[u64]) -> Fr {
            self.commitment(entries).into_affine().x
        }
    }

    /// `Σᵢ Σⱼ bᵢⱼ·2ʲ·Gᵢ` — the fixed-base Pedersen commitment the circuit proves.
    ///
    /// The bases are **public parameters**, known outside the circuit, so the
    /// gadget's tables are constants and each 2-bit window costs two lookups and
    /// one addition. `bits` are the entries' bit decompositions: the same Booleans
    /// §5.5.3's range check already pays for, so the commitment adds no
    /// decomposition of its own.
    pub fn pedersen_commit(
        bits: &[Vec<Boolean<Fr>>],
        params: &PedersenParams,
    ) -> Result<AffineVar<EdwardsConfig, FpVar<Fr>>, SynthesisError> {
        let mut commit = AffineVar::<EdwardsConfig, FpVar<Fr>>::zero();
        for (entry_bits, multiples) in bits.iter().zip(params.multiples()) {
            commit.precomputed_base_scalar_mul_le(entry_bits.iter().zip(multiples.iter()))?;
        }
        Ok(commit)
    }

    /// V2′ of §5.5.2: Pedersen over Baby Jubjub, recomputed in-circuit, plus the
    /// norm both variants share.
    ///
    /// Public inputs: the commitment's x-coordinate and the certified norm. The
    /// statement's third word (`epoch`) belongs to the wrapper [`crate::groth16`]
    /// adds, and that wrapper is the same for V2′ and V3 — which is what makes the
    /// two variants' costs comparable line by line.
    pub struct PedersenNormCircuit {
        /// Witness: the `N` WAD entries.
        pub entries: Vec<u64>,
        /// Public: the norm the statement certifies, in WAD.
        pub certified_norm_wad: u64,
        /// Public, as its x-coordinate: the Pedersen commitment, from
        /// [`PedersenParams::commitment`].
        pub commitment: EdwardsProjective,
        /// The public parameters, from [`PedersenParams::new`].
        pub params: PedersenParams,
    }

    impl ConstraintSynthesizer<Fr> for PedersenNormCircuit {
        fn generate_constraints(self, cs: ConstraintSystemRef<Fr>) -> Result<(), SynthesisError> {
            let committed = FpVar::new_input(cs.clone(), || Ok(self.commitment.into_affine().x))?;
            let certified = FpVar::new_input(cs.clone(), || Ok(Fr::from(self.certified_norm_wad)))?;

            let bits = allocate_entry_bits(&cs, &self.entries)?;
            let entries: Vec<FpVar<Fr>> = bits
                .iter()
                .map(|entry_bits| Boolean::le_bits_to_fp(entry_bits))
                .collect::<Result<_, _>>()?;
            let squares = sum_of_squares(&entries)?;
            enforce_floor_norm(squares, certified)?;

            let point = pedersen_commit(&bits, &self.params)?;
            point.affine_xy()?.0.enforce_equal(&committed)
        }
    }
}

#[cfg(test)]
mod tests {
    use ark_ec::AdditiveGroup;

    use super::*;

    /// Small tensor: the shape tests run in debug time.
    fn small() -> Vec<u64> {
        vec![1, 2, 3, 4, 5, 6, 7, 8]
    }

    fn norm_wad(entries: &[u64]) -> u64 {
        let sum: u128 = entries.iter().map(|e| (*e as u128) * (*e as u128)).sum();
        crate::fixture::isqrt(sum) as u64
    }

    #[test]
    fn norm_circuit_is_satisfied_at_the_true_norm() {
        let entries = small();
        let (cost, result) = synthesize(NormCircuit {
            entries: entries.clone(),
            certified_norm_wad: norm_wad(&entries),
        });
        result.expect("synthesis");
        assert!(cost.satisfied, "true norm must satisfy the circuit");
        // k booleans per entry, one squaring each, plus the public input.
        assert_eq!(cost.instance_variables, 2);
        assert!(
            cost.witness_variables >= entries.len() * ENTRY_BITS,
            "witness carries the k-bit decomposition: {cost:?}"
        );
        assert!(cost.constraints > entries.len());
    }

    #[test]
    fn norm_circuit_rejects_a_forged_norm() {
        let entries = small();
        let (cost, result) = synthesize(NormCircuit {
            entries: entries.clone(),
            certified_norm_wad: norm_wad(&entries) + 1,
        });
        result.expect("synthesis");
        assert!(!cost.satisfied, "a forged norm must not be satisfiable");
    }

    /// §5.5.1 writes the relation as `Σ T_i² = certifiedNorm²`. This is the M4a
    /// verification that the exact form has no witness for a real tensor, and
    /// therefore why [`enforce_floor_norm`] certifies the floor.
    #[test]
    fn exact_square_equality_has_no_witness_for_a_real_tensor() {
        let entries = small();
        let sum: u128 = entries.iter().map(|e| (*e as u128) * (*e as u128)).sum();
        let floor = crate::fixture::isqrt(sum);
        assert_eq!(sum, 204);
        assert_eq!(floor, 14);
        assert_ne!(
            sum,
            floor * floor,
            "204 vs 196: the exact-square relation is unsatisfiable here"
        );
    }

    #[test]
    fn poseidon_circuit_is_satisfied_at_the_true_digest() {
        let entries = small();
        let params = poseidon_params();
        let (cost, result) = synthesize(PoseidonNormCircuit {
            commitment: poseidon_commitment(&entries, &params),
            entries: entries.clone(),
            certified_norm_wad: norm_wad(&entries),
            params,
        });
        result.expect("synthesis");
        assert!(
            cost.satisfied,
            "digest and norm together must be satisfiable"
        );
        assert!(cost.instance_variables >= 3, "norm + digest are public");
    }

    #[test]
    fn v3_parameters_are_the_bn254_poseidon_instance() {
        let p = poseidon_params();
        assert_eq!((p.rate, p.capacity), (2, 1));
        assert_eq!((p.full_rounds, p.partial_rounds), (8, 57));
        assert_eq!(p.alpha, 5);
        assert_eq!(p.ark.len(), 8 + 57);
        assert_eq!(p.mds.len(), 3);
    }

    #[test]
    fn fq_and_fr_are_different_fields() {
        assert_eq!(v2::field_facts(), (254, 254));
        assert_ne!(ark_bn254::Fq::MODULUS, ark_bn254::Fr::MODULUS);
    }

    /// V2′'s parameters come from one committed seed: two constructions, one set
    /// of bases. Without this the "reproducible measurement" of §5.5.6 would hold
    /// for V3 only.
    #[test]
    fn v2p_params_are_reproducible() {
        let first = v2::PedersenParams::new(4);
        let second = v2::PedersenParams::new(4);
        assert_eq!(first.bases(), second.bases());
        assert_eq!(first.multiples()[3][2], first.bases()[3].double().double());
    }

    /// The circuit must certify `Σ Tᵢ·Gᵢ` and nothing else. The commitment fed to
    /// it here comes from `PedersenParams::commitment`, i.e. from one **multi-scalar
    /// multiplication outside the circuit** — while the gadget recomputes the same
    /// point from 2-bit-window tables. Satisfied therefore means the two
    /// implementations agree, which is the cross-check V2′ needs to be believed.
    #[test]
    fn v2p_circuit_is_satisfied_at_the_true_commitment() {
        let entries = small();
        let params = v2::PedersenParams::new(entries.len());
        let (cost, result) = synthesize(v2::PedersenNormCircuit {
            commitment: params.commitment(&entries),
            entries: entries.clone(),
            certified_norm_wad: norm_wad(&entries),
            params,
        });
        result.expect("synthesis");
        assert!(cost.satisfied, "true commitment and norm must satisfy");
        assert_eq!(
            cost.instance_variables, 3,
            "commitment, norm and the constant"
        );
        assert!(cost.witness_variables >= entries.len() * ENTRY_BITS);
    }

    /// Binding, checked rather than asserted: the same witness with another
    /// tensor's commitment must not satisfy the circuit.
    #[test]
    fn v2p_circuit_rejects_a_forged_commitment() {
        let entries = small();
        let mut forged_entries = entries.clone();
        forged_entries[0] += 1;
        let params = v2::PedersenParams::new(entries.len());
        assert_ne!(
            params.commitment_x(&entries),
            params.commitment_x(&forged_entries),
            "another tensor commits to another x"
        );
        let (cost, result) = synthesize(v2::PedersenNormCircuit {
            commitment: params.commitment(&forged_entries),
            entries,
            certified_norm_wad: norm_wad(&forged_entries),
            params,
        });
        result.expect("synthesis");
        assert!(!cost.satisfied, "a foreign commitment must not certify");
    }

    #[test]
    fn v2p_circuit_rejects_a_forged_norm() {
        let entries = small();
        let params = v2::PedersenParams::new(entries.len());
        let (cost, result) = synthesize(v2::PedersenNormCircuit {
            commitment: params.commitment(&entries),
            entries: entries.clone(),
            certified_norm_wad: norm_wad(&entries) + 1,
            params,
        });
        result.expect("synthesis");
        assert!(!cost.satisfied, "a forged norm must not be satisfiable");
    }

    /// The commitment part of the cost: V2′'s circuit minus the norm circuit,
    /// which for the same entries is exactly the Pedersen gadget's share.
    fn commitment_cost(n: usize) -> usize {
        commitment_cost_of(&vec![1u64; n])
    }

    fn commitment_cost_of(entries: &[u64]) -> usize {
        let certified = norm_wad(entries);
        let params = v2::PedersenParams::new(entries.len());
        let (with_commit, first) = synthesize(v2::PedersenNormCircuit {
            commitment: params.commitment(entries),
            entries: entries.to_vec(),
            certified_norm_wad: certified,
            params,
        });
        first.expect("synthesis");
        let (norm_only, second) = synthesize(NormCircuit {
            entries: entries.to_vec(),
            certified_norm_wad: certified,
        });
        second.expect("synthesis");
        with_commit.constraints - norm_only.constraints
    }

    /// `ENTRY_BITS = 60` bits are consumed in 2-bit windows, so the gadget's cost
    /// is **affine in the entry count**: adding `k` entries costs the same
    /// whatever the count, which the first equality states by doubling an
    /// increment. The second is the window structure: the per-entry cost divides
    /// by the 30 windows, i.e. every window costs the same. Both are derived from
    /// the gadget rather than pinned as numbers (§5.5.9's method for the wrapper),
    /// so a future `ark-r1cs-std` that windows differently still satisfies them.
    #[test]
    fn v2p_commitment_cost_is_affine_in_the_entries() {
        let (eight, sixteen, thirty_two) =
            (commitment_cost(8), commitment_cost(16), commitment_cost(32));
        assert_eq!(
            (sixteen - eight) * 2,
            thirty_two - sixteen,
            "the per-entry cost is constant: {eight}, {sixteen}, {thirty_two}"
        );
        let windows = ENTRY_BITS.div_ceil(2);
        let per_entry = (thirty_two - sixteen) / 16;
        assert_eq!(
            per_entry % windows,
            0,
            "every 2-bit window costs the same: {per_entry} over {windows} windows"
        );
    }

    /// One circuit, one shape: the commitment's cost does not depend on the
    /// entries' values, only on their count. (The window tables are constants, so
    /// a value that flips more bits cannot cost more.)
    #[test]
    fn v2p_commitment_cost_does_not_depend_on_the_values() {
        let sparse = vec![1u64; 16];
        let dense: Vec<u64> = (1..=16).map(|i| (1u64 << 59) + i as u64).collect();
        assert_eq!(commitment_cost_of(&sparse), commitment_cost_of(&dense));
    }
}
