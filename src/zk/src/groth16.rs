//! M4b — the outer layer: a real Groth16 key over V3, and the statement the
//! frozen contract actually builds (plan §5.5.4, §5.5.6, §5.5.9).
//!
//! Three things this module is, and one it is not:
//!
//! * **A real key.** [`measure`] runs
//!   `Groth16::generate_random_parameters_with_reduction` over [`StatementCircuit`],
//!   producing the `ProvingKey`/`VerifyingKey` pair that replaces M3's synthetic
//!   one. It is a *development* setup — §5.5.4 says so in plain words — and the
//!   consequence is worth repeating where the code lives: the seed
//!   [`SETUP_SEED`] is **committed**, so the toxic waste (`alpha`, `beta`,
//!   `gamma`, `delta`) is derivable by anyone and **forgeries are free**. The key
//!   is an instrument for measuring the pipeline, not a key that carries a claim;
//!   §11 keeps the ceremony that would carry one out of scope for M4.
//! * **The contract's statement.** `AVIPRegistry.verifyThreshold` is frozen since
//!   M3 and builds `statement = [uint256(root), epoch, certifiedNorm]` from its
//!   own state, with the installed key required to have `ic.length == 4`
//!   (`Groth16Verifier` checks it in its constructor). [`StatementCircuit`]
//!   allocates its public inputs in exactly that order and number, so M4b needs
//!   **no Solidity change**.
//! * **A bound epoch.** An *unused* public input is not bound: the R1CS-to-QAP
//!   reduction gives it the zero polynomial, so its `gamma_abc_g1` entry is the
//!   identity and verification ignores its value entirely. `epoch` is therefore
//!   constrained (`< 2^64`, which is all a sequencer counter can reach), and
//!   [`M4bMeasurement::binding`] *checks* the consequence instead of asserting it.
//! * Not a new circuit: the constraints are V3's, the ones §5.5.6 pinned. This
//!   module adds the statement wrapper around them, and that the wrapper costs
//!   what the pinned table says is a test, not a comment
//!   (`tests/groth16_statement_shape.rs`).
//! * **Variant-agnostic.** §5.5.2 leaves the commitment open (`D-M4-0`), so the
//!   same wrapper, seeds and fixture are run over either variant —
//!   [`Variant::V3`] or [`Variant::V2Pedersen`], V2′ — and [`render_duel`] prints
//!   the comparison the decision is made from. The M4b fixture stays on V3: a
//!   contract-facing artifact is not re-derived from an undecided variant.

use std::time::{Duration, Instant};

use ark_bn254::{Bn254, Fr};
use ark_crypto_primitives::sponge::{
    constraints::CryptographicSpongeVar,
    poseidon::{PoseidonConfig, constraints::PoseidonSpongeVar},
};
use ark_ff::PrimeField;
use ark_groth16::{Groth16, Proof, ProvingKey, prepare_verifying_key};
use ark_r1cs_std::{
    alloc::AllocVar, boolean::Boolean, eq::EqGadget, fields::fp::FpVar, groups::CurveVar,
};
use ark_relations::gr1cs::{ConstraintSynthesizer, ConstraintSystemRef, SynthesisError};
use ark_serialize::{CanonicalSerialize, Compress};
use rand_chacha::ChaCha20Rng;
use rand_core::SeedableRng;
use sha3::{Digest, Keccak256};

use crate::native;

/// The statement `AVIPRegistry.verifyThreshold` builds, in its own order:
/// `[root, epoch, certifiedNorm]`.
pub const STATEMENT_LEN: usize = 3;

/// `Groth16Verifier` requires `ic.length == publicInputs + 1`, and
/// `AVIPRegistry` requires it too by construction (it reads `ic.length - 1` as
/// the public-input count it may pass).
pub const IC_LEN: usize = STATEMENT_LEN + 1;

/// Bits the epoch counter can reach. A `uint256` epoch is bounded in-circuit so
/// its `gamma_abc_g1` entry stops being the identity — see the module docs.
pub const EPOCH_BITS: usize = 64;

/// The dev-setup seed. Committed on purpose: the transcript is reproducible, and
/// the toxic waste is public. See the module docs for what that costs.
pub const SETUP_SEED: [u8; 32] = *b"AVIP-M4b-dev-setup-1-contributor";

/// The proving randomness. Committed for the same reason as [`SETUP_SEED`]: the
/// fixture proof is then byte-identical across runs, the way §5.5.6 requires. It
/// forfeits zero knowledge **for the fixture only**, which is what makes the
/// proof a pinned artifact instead of a load-dependent observation.
pub const PROOF_SEED: [u8; 32] = *b"AVIP-M4b-dev-proof-1-contributor";

const _: () = assert!(SETUP_SEED.len() == 32);
const _: () = assert!(PROOF_SEED.len() == 32);

/// V3's commitment + norm, wrapped in the statement the contract verifies.
///
/// Public inputs, allocated in this exact order (`AVIPRegistry` lines 187-190):
///
/// | index | value | Solidity source |
/// |---|---|---|
/// | 0 | `root` | `uint256(root)` for the epoch's posted root |
/// | 1 | `epoch` | the epoch whose root is being read |
/// | 2 | `certifiedNorm` | the norm the manager compares against `Θ_r` |
///
/// `root` is the Poseidon commitment of §5.5.2 V3 here, not the `keccak256` root
/// of §5.2: bridging the two is the `(c)` option §5.5.7 reserves for **M7**.
pub struct StatementCircuit {
    /// Witness: the `N` WAD entries.
    pub entries: Vec<u64>,
    /// Public: the commitment the entries hash to.
    pub root: Fr,
    /// Public: the epoch the commitment is posted at.
    pub epoch: u64,
    /// Public: the norm the statement certifies, in WAD.
    pub certified_norm_wad: u64,
    /// The instantiated V3 parameters, from [`native::poseidon_params`].
    pub params: PoseidonConfig<Fr>,
}

impl ConstraintSynthesizer<Fr> for StatementCircuit {
    fn generate_constraints(self, cs: ConstraintSystemRef<Fr>) -> Result<(), SynthesisError> {
        let root = FpVar::new_input(cs.clone(), || Ok(self.root))?;
        let epoch = FpVar::new_input(cs.clone(), || Ok(Fr::from(self.epoch)))?;
        let certified = FpVar::new_input(cs.clone(), || Ok(Fr::from(self.certified_norm_wad)))?;

        // The witness, and V3's own constraints, unchanged from §5.5.6.
        let entry_vars = native::allocate_entries(&cs, &self.entries)?;
        let squares = native::sum_of_squares(&entry_vars)?;
        native::enforce_floor_norm(squares, certified)?;

        let mut sponge = PoseidonSpongeVar::<Fr>::new(cs.clone(), &self.params);
        sponge.absorb(&entry_vars)?;
        let squeezed = sponge.squeeze_field_elements(1)?;
        squeezed[0].enforce_equal(&root)?;

        // `epoch` must appear in a constraint, or its IC entry is the identity
        // and the proof would verify for *every* epoch. One bound is enough: the
        // variable is then carried by that constraint's QAP polynomial.
        native::enforce_below_pow2(&epoch, EPOCH_BITS)
    }
}

/// The V3 statement for a tensor: commitment as `root`, the floor norm in WAD,
/// at `epoch`. The commitment is computed by [`native::poseidon_commitment`], so
/// the `root` a proof certifies is the one the fixture's entries hash to.
pub fn circuit_for(entries: &[u64], certified_norm_wad: u64, epoch: u64) -> StatementCircuit {
    let params = native::poseidon_params();
    let root = native::poseidon_commitment(entries, &params);
    StatementCircuit {
        entries: entries.to_vec(),
        root,
        epoch,
        certified_norm_wad,
        params,
    }
}

/// Which §5.5.2 variant the wrapper is built around. The wrapper — the contract's
/// three public inputs in its own order, with a bound epoch — is **the same code
/// for both**; only the commitment inside differs.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Variant {
    /// Poseidon over the entries, in-circuit (§5.5.2 V3).
    V3,
    /// Pedersen over Baby Jubjub — a curve whose base field *is* `Fr_BN254` —
    /// recomputed in-circuit: the native repair of §5.5.2's V2 row.
    V2Pedersen,
}

impl Variant {
    /// The name the tables use.
    pub const fn name(self) -> &'static str {
        match self {
            Self::V3 => "V3",
            Self::V2Pedersen => "V2′",
        }
    }

    /// The commitment line of the rendered tables.
    pub const fn commitment(self) -> &'static str {
        match self {
            Self::V3 => "V3 in the statement wrapper (§5.5.6's circuit + the bound epoch)",
            Self::V2Pedersen => {
                "V2′ in the statement wrapper (Pedersen over Baby Jubjub + the bound epoch)"
            }
        }
    }

    /// How many elliptic curves an implementation of this variant must carry —
    /// the tie-break [`duel_verdict`] uses, and a fact about the variant rather
    /// than about a run. V3's commitment is field arithmetic inside the circuit
    /// and needs no group of its own; V2′'s is a Pedersen commitment, so its
    /// group has to be implemented as well, and that is the price the "native"
    /// repair pays for being native.
    pub const fn curves(self) -> usize {
        match self {
            Self::V3 => 1,
            Self::V2Pedersen => 2,
        }
    }
}

/// V2′'s statement: the same three public inputs as [`StatementCircuit`], with
/// the Pedersen commitment in place of Poseidon's digest.
///
/// `root` is the commitment's **x-coordinate**, because the frozen statement has
/// one `uint256` for the root (`AVIPRegistry.verifyThreshold`); a full point would
/// be a second word, which is a §5.5.7 (M7) question and not this measurement's.
/// The wrapper costs the same whichever value sits in `root`, so the comparison
/// [`render_duel`] prints is commitment-only.
pub struct V2StatementCircuit {
    /// Witness: the `N` WAD entries.
    pub entries: Vec<u64>,
    /// Public: the commitment's x-coordinate, from
    /// [`native::v2::PedersenParams::commitment_x`].
    pub root: Fr,
    /// Public: the epoch the commitment is posted at.
    pub epoch: u64,
    /// Public: the norm the statement certifies, in WAD.
    pub certified_norm_wad: u64,
    /// The instantiated V2′ parameters, from [`native::v2::PedersenParams::new`].
    pub params: native::v2::PedersenParams,
}

impl ConstraintSynthesizer<Fr> for V2StatementCircuit {
    fn generate_constraints(self, cs: ConstraintSystemRef<Fr>) -> Result<(), SynthesisError> {
        // The same three inputs, allocated in the same order as
        // `StatementCircuit`: the two wrappers must be indistinguishable to the
        // contract, and `ic.length == 4` is what the installed key is checked for.
        let root = FpVar::new_input(cs.clone(), || Ok(self.root))?;
        let epoch = FpVar::new_input(cs.clone(), || Ok(Fr::from(self.epoch)))?;
        let certified = FpVar::new_input(cs.clone(), || Ok(Fr::from(self.certified_norm_wad)))?;

        let bits = native::allocate_entry_bits(&cs, &self.entries)?;
        let entry_vars: Vec<FpVar<Fr>> = bits
            .iter()
            .map(|entry_bits| Boolean::le_bits_to_fp(entry_bits))
            .collect::<Result<_, _>>()?;
        let squares = native::sum_of_squares(&entry_vars)?;
        native::enforce_floor_norm(squares, certified)?;

        let commitment = native::v2::pedersen_commit(&bits, &self.params)?;
        commitment.affine_xy()?.0.enforce_equal(&root)?;

        native::enforce_below_pow2(&epoch, EPOCH_BITS)
    }
}

/// Either variant behind one synthesizer, so the pipeline above can measure both
/// without being written twice.
pub enum VariantCircuit {
    V3(StatementCircuit),
    V2Pedersen(Box<V2StatementCircuit>),
}

impl ConstraintSynthesizer<Fr> for VariantCircuit {
    fn generate_constraints(self, cs: ConstraintSystemRef<Fr>) -> Result<(), SynthesisError> {
        match self {
            Self::V3(circuit) => circuit.generate_constraints(cs),
            Self::V2Pedersen(circuit) => circuit.generate_constraints(cs),
        }
    }
}

/// [`circuit_for`] for either variant. The V3 arm *is* [`circuit_for`], so the
/// pinned M4b fixture and the measurement cannot drift apart.
pub fn variant_circuit_for(
    variant: Variant,
    entries: &[u64],
    certified_norm_wad: u64,
    epoch: u64,
) -> VariantCircuit {
    match variant {
        Variant::V3 => VariantCircuit::V3(circuit_for(entries, certified_norm_wad, epoch)),
        Variant::V2Pedersen => {
            let params = native::v2::PedersenParams::new(entries.len());
            let root = params.commitment_x(entries);
            VariantCircuit::V2Pedersen(Box::new(V2StatementCircuit {
                entries: entries.to_vec(),
                root,
                epoch,
                certified_norm_wad,
                params,
            }))
        }
    }
}

/// [`key_and_proof`] for either variant: the same two seeds, drawn in the same
/// order, so V3's key and proof are the ones the fixture pins.
pub fn variant_key_and_proof(
    variant: Variant,
    entries: &[u64],
    certified_norm_wad: u64,
    epoch: u64,
) -> DevKey {
    let mut rng = ChaCha20Rng::from_seed(SETUP_SEED);
    let started = Instant::now();
    let pk = Groth16::<Bn254>::generate_random_parameters_with_reduction(
        variant_circuit_for(variant, entries, certified_norm_wad, epoch),
        &mut rng,
    )
    .expect("development setup");
    let setup_time = started.elapsed();

    let mut rng = ChaCha20Rng::from_seed(PROOF_SEED);
    let started = Instant::now();
    let proof = Groth16::<Bn254>::create_random_proof_with_reduction(
        variant_circuit_for(variant, entries, certified_norm_wad, epoch),
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

/// The public root a given variant's statement carries, computed outside the
/// circuit: V3's Poseidon digest, or V2′'s commitment x-coordinate.
pub fn variant_root(variant: Variant, entries: &[u64], certified_norm_wad: u64, epoch: u64) -> Fr {
    match variant {
        Variant::V3 => circuit_for(entries, certified_norm_wad, epoch).root,
        Variant::V2Pedersen => native::v2::PedersenParams::new(entries.len()).commitment_x(entries),
    }
}

/// What one key is made of. These are the lengths a real setup pays for, and the
/// ones `Groth16Verifier` reads back: `ic` is the contract-facing number.
#[derive(Clone, Copy, Debug)]
pub struct KeyShape {
    pub a_query: usize,
    pub b_g1_query: usize,
    pub b_g2_query: usize,
    pub h_query: usize,
    pub l_query: usize,
    pub ic: usize,
}

impl KeyShape {
    fn of<E>(pk: &ProvingKey<E>) -> Self
    where
        E: ark_ec::pairing::Pairing,
    {
        Self {
            a_query: pk.a_query.len(),
            b_g1_query: pk.b_g1_query.len(),
            b_g2_query: pk.b_g2_query.len(),
            h_query: pk.h_query.len(),
            l_query: pk.l_query.len(),
            ic: pk.vk.gamma_abc_g1.len(),
        }
    }
}

/// Whether a proof survives a tampered statement. `true` means the proof was
/// **rejected** — the component is bound. `norm`/`root` changing the statement
/// is the whole point of Groth16; `epoch` is the one that an unused public input
/// would silently survive, so it is checked rather than assumed.
#[derive(Clone, Copy, Debug)]
pub struct StatementBinding {
    pub epoch: bool,
    pub root: bool,
    pub norm: bool,
}

/// Everything one M4b run measured. The durations are kept apart from the rest
/// for the same reason [`crate::report`] keeps them apart: they are wall-clock.
pub struct M4bMeasurement {
    /// Which §5.5.2 variant the statement wraps ([`Variant`]).
    pub variant: Variant,
    pub constraints: usize,
    pub instance_variables: usize,
    pub witness_variables: usize,
    pub key: KeyShape,
    /// Compressed canonical serialization: `a ‖ b ‖ c` as ark writes them.
    pub proof_compressed_bytes: usize,
    /// What the contract reads: `a[2]`, `b[2][2]`, `c[2]`, 32 bytes each.
    pub proof_on_chain_bytes: usize,
    /// Identity of the key: `keccak256` of its canonical serialization. The
    /// *on-chain* digest is `keccak256(abi.encode(vk))`, which the contract
    /// computes over its own layout; M4b's fixture step checks that one against
    /// `Groth16Verifier.verifyingKeyDigest()`.
    pub vk_canonical_digest: String,
    /// Identity of the proof, same encoding: the pin that the committed
    /// [`PROOF_SEED`] makes the fixture reproducible.
    pub proof_canonical_digest: String,
    pub root: Fr,
    pub epoch: u64,
    pub certified_norm_wad: u64,
    pub verifies: bool,
    pub binding: StatementBinding,
    pub setup_time: Duration,
    pub prove_time: Duration,
    pub verify_time: Duration,
}

/// Lowercase hex of a 32-byte digest.
fn hex32(bytes: [u8; 32]) -> String {
    use std::fmt::Write as _;
    let mut s = String::with_capacity(64);
    for b in bytes {
        let _ = write!(s, "{b:02x}");
    }
    s
}

/// Identity of a value under ark's canonical serialization: the pin a fixture
/// can be compared against without shipping the whole key. `pub` because the
/// Solidity fixture emitter of §5.5.6 prints it next to the key it writes.
pub fn canonical_digest<T: CanonicalSerialize>(value: &T) -> String {
    let mut bytes = Vec::new();
    value
        .serialize_with_mode(&mut bytes, Compress::Yes)
        .expect("serialize into a Vec");
    hex32(Keccak256::digest(&bytes).into())
}

/// The public input vector, in the contract's order.
pub fn statement_inputs(m: &M4bMeasurement) -> [Fr; STATEMENT_LEN] {
    [m.root, Fr::from(m.epoch), Fr::from(m.certified_norm_wad)]
}

/// What one development run produced: the real key, the fixture proof, and the
/// two clocks, kept apart so no caller can report a setup's cost as a prover's.
pub struct DevKey {
    pub pk: ProvingKey<Bn254>,
    pub proof: Proof<Bn254>,
    pub setup_time: Duration,
    pub prove_time: Duration,
}

/// Generate the development key and the fixture proof, timed apart. The seeds
/// are [`SETUP_SEED`] and [`PROOF_SEED`], and [`measure`] goes through here, so
/// the digests the report pins are the values the Solidity fixture is emitted
/// from.
pub fn key_and_proof(entries: &[u64], certified_norm_wad: u64, epoch: u64) -> DevKey {
    let mut rng = ChaCha20Rng::from_seed(SETUP_SEED);
    let started = Instant::now();
    let pk = Groth16::<Bn254>::generate_random_parameters_with_reduction(
        circuit_for(entries, certified_norm_wad, epoch),
        &mut rng,
    )
    .expect("development setup");
    let setup_time = started.elapsed();

    let mut rng = ChaCha20Rng::from_seed(PROOF_SEED);
    let started = Instant::now();
    let proof = Groth16::<Bn254>::create_random_proof_with_reduction(
        circuit_for(entries, certified_norm_wad, epoch),
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

/// Run the M4b pipeline over V3: the pinned delivery of §5.5.9. It keeps its own
/// name because the fixture and the contract-facing artifact are built from it.
pub fn measure(entries: &[u64], certified_norm_wad: u64, epoch: u64) -> M4bMeasurement {
    measure_variant(Variant::V3, entries, certified_norm_wad, epoch)
}

/// The same pipeline over either variant: cost in the statement wrapper,
/// development key, fixture proof, verification, and the statement-binding
/// checks. `D-M4-0` (§5.5.2) is decided on two of these, and [`render_duel`]
/// prints the comparison.
pub fn measure_variant(
    variant: Variant,
    entries: &[u64],
    certified_norm_wad: u64,
    epoch: u64,
) -> M4bMeasurement {
    let root = variant_root(variant, entries, certified_norm_wad, epoch);

    // 1. The cost, measured the way §5.5.6 measures a variant (the same
    //    `synthesize`), so the tables are comparable line by line.
    let (cost, synthesis) = native::synthesize(variant_circuit_for(
        variant,
        entries,
        certified_norm_wad,
        epoch,
    ));
    synthesis.expect("the statement circuit must synthesize");

    // 2. The development key, then the proof. Both RNGs are seeded from the
    //    committed `SETUP_SEED`/`PROOF_SEED`: the run is reproducible, and the
    //    toxic waste is public, so the key measures the pipeline rather than
    //    protecting a claim.
    let dev = variant_key_and_proof(variant, entries, certified_norm_wad, epoch);
    let (setup_time, prove_time) = (dev.setup_time, dev.prove_time);
    let (pk, proof) = (dev.pk, dev.proof);

    // 4. Verify, and check each component is bound: a tampered statement must be
    //    rejected. `epoch` is the one an unused public input would survive.
    let pvk = prepare_verifying_key(&pk.vk);
    let inputs = [root, Fr::from(epoch), Fr::from(certified_norm_wad)];
    let started = Instant::now();
    let verifies = Groth16::<Bn254>::verify_proof(&pvk, &proof, &inputs).expect("verify");
    let verify_time = started.elapsed();

    let rejected = |modified: [Fr; STATEMENT_LEN]| -> bool {
        !Groth16::<Bn254>::verify_proof(&pvk, &proof, &modified).expect("verify a tampered one")
    };
    let binding = StatementBinding {
        epoch: rejected([root, Fr::from(epoch + 1), Fr::from(certified_norm_wad)]),
        root: rejected([
            root + Fr::from(1u64),
            Fr::from(epoch),
            Fr::from(certified_norm_wad),
        ]),
        norm: rejected([root, Fr::from(epoch), Fr::from(certified_norm_wad + 1)]),
    };

    M4bMeasurement {
        variant,
        constraints: cost.constraints,
        instance_variables: cost.instance_variables,
        witness_variables: cost.witness_variables,
        key: KeyShape::of(&pk),
        proof_compressed_bytes: proof.serialized_size(Compress::Yes),
        // `a[2]`, `b[2][2]`, `c[2]`: the eight elements `Bn254.decodeProof` reads.
        proof_on_chain_bytes: 8 * 32,
        vk_canonical_digest: canonical_digest(&pk.vk),
        proof_canonical_digest: canonical_digest(&proof),
        root,
        epoch,
        certified_norm_wad,
        verifies,
        binding,
        setup_time,
        prove_time,
        verify_time,
    }
}

/// The threshold §5.5.4 declares for re-opening V1: outer proving `≤ 120 s`.
/// V1 is dropped (§5.5.5), so the threshold now bounds whatever outer layer M4
/// installs — which is this one.
pub const OUTER_PROVE_THRESHOLD: Duration = Duration::from_secs(120);

impl M4bMeasurement {
    /// The pinned table: only quantities a re-run reproduces byte for byte.
    /// Durations are in [`Self::render_timings`], which goes to stderr.
    pub fn render(&self) -> String {
        use std::fmt::Write as _;
        let mut s = String::new();
        let _ = writeln!(
            s,
            "AVIP M4b — real Groth16 key + end-to-end prover over {}",
            self.variant.name()
        );
        let _ = writeln!(s, "plan §5.5.4 (key) and §5.5.9 (delivery)");
        let _ = writeln!(s, "==================================================");
        let _ = writeln!(s);
        let _ = writeln!(
            s,
            "statement — the vector `AVIPRegistry.verifyThreshold` builds, in its order"
        );
        let _ = writeln!(s, "  [0] root                : {}", self.root.into_bigint());
        let _ = writeln!(s, "  [1] epoch               : {}", self.epoch);
        let _ = writeln!(s, "  [2] certifiedNorm (WAD) : {}", self.certified_norm_wad);
        let _ = writeln!(s);
        let _ = writeln!(s, "{}", self.variant.commitment());
        let _ = writeln!(s, "  constraints             : {}", self.constraints);
        let _ = writeln!(
            s,
            "  instance variables      : {} ({} public + the constant)",
            self.instance_variables, STATEMENT_LEN
        );
        let _ = writeln!(s, "  witness variables       : {}", self.witness_variables);
        let _ = writeln!(s);
        let _ = writeln!(
            s,
            "Groth16 development key — one contributor, seeded, no security claim"
        );
        let _ = writeln!(
            s,
            "  a_query / b_g1_query    : {} / {}",
            self.key.a_query, self.key.b_g1_query
        );
        let _ = writeln!(s, "  b_g2_query              : {}", self.key.b_g2_query);
        let _ = writeln!(
            s,
            "  h_query / l_query       : {} / {}",
            self.key.h_query, self.key.l_query
        );
        let _ = writeln!(
            s,
            "  ic                      : {} (public inputs + 1, what Groth16Verifier requires)",
            self.key.ic
        );
        let _ = writeln!(
            s,
            "  keccak256(canonical)    : {}",
            self.vk_canonical_digest
        );
        let _ = writeln!(s);
        let _ = writeln!(s, "proof — fixture, seeded so two runs agree byte for byte");
        let _ = writeln!(
            s,
            "  a ‖ b ‖ c (compressed)  : {} bytes",
            self.proof_compressed_bytes
        );
        let _ = writeln!(
            s,
            "  on-chain encoding       : {} bytes (8 × uint256)",
            self.proof_on_chain_bytes
        );
        let _ = writeln!(
            s,
            "  keccak256(canonical)    : {}",
            self.proof_canonical_digest
        );
        let _ = writeln!(s, "  verifies                : {}", self.verifies);
        let _ = writeln!(s, "  rejected after epoch+1  : {}", self.binding.epoch);
        let _ = writeln!(s, "  rejected after root+1   : {}", self.binding.root);
        let _ = writeln!(s, "  rejected after norm+1   : {}", self.binding.norm);
        s
    }

    /// Load-dependent durations, for **stderr** (the M4a discipline: a committed
    /// table that changes on every run is not a pinned table).
    pub fn render_timings(&self) -> String {
        use std::fmt::Write as _;
        let mut s = String::new();
        let _ = writeln!(
            s,
            "timings — {} (wall-clock, load-dependent — not part of the pinned table):",
            self.variant.name()
        );
        let _ = writeln!(
            s,
            "  setup / prove / verify : {:.3?} / {:.3?} / {:.3?}",
            self.setup_time, self.prove_time, self.verify_time
        );
        let _ = writeln!(
            s,
            "  §5.5.4 outer prove ≤ {} s : {} ({:.3?})",
            OUTER_PROVE_THRESHOLD.as_secs(),
            if self.prove_time <= OUTER_PROVE_THRESHOLD {
                "PASS"
            } else {
                "FAIL"
            },
            self.prove_time
        );
        s
    }
}

/// `D-M4-0` (§5.5.2): the two variants through one pipeline — the same statement
/// wrapper, the same seeded key and fixture, the same tensor — so the only thing
/// the table compares is the commitment.
///
/// The verdict is **computed** from the two measurements, not written into the
/// string: §5.5.4 declares no numeric threshold for this decision ("decided on
/// the measured cost"), so the criterion is printed next to the numbers it
/// applies to. Constraints come first because the key's size and the prover's
/// work follow from them; the number of curves an implementation must carry
/// breaks a tie, and it is a fact about the variants, not about this run.
pub fn render_duel(v3: &M4bMeasurement, v2: &M4bMeasurement) -> String {
    use std::fmt::Write as _;
    let mut s = String::new();
    let (a, b) = (v3.variant.name(), v2.variant.name());

    fn row(out: &mut String, label: &str, first: String, second: String, delta: String) {
        let _ = writeln!(out, "  {label:<26}{first:<18}{second:<18}{delta}");
    }

    let _ = writeln!(s);
    let _ = writeln!(
        s,
        "D-M4-0 — §5.5.2's two variants: one wrapper, one fixture, one pair of seeds"
    );
    let _ = writeln!(s, "==================================================");
    let _ = writeln!(s);
    let _ = writeln!(s, "  {:<26}{a:<18}{b:<18}Δ", "quantity");

    let delta = |first: usize, second: usize| -> String {
        format!(
            "{:+} ({:+.1}%)",
            second as i128 - first as i128,
            if first == 0 {
                0.0
            } else {
                100.0 * (second as f64 / first as f64 - 1.0)
            }
        )
    };
    let same = |first: usize, second: usize| -> String {
        if first == second {
            "same".to_string()
        } else {
            format!("{:+}", second as i128 - first as i128)
        }
    };

    row(
        &mut s,
        "constraints",
        v3.constraints.to_string(),
        v2.constraints.to_string(),
        delta(v3.constraints, v2.constraints),
    );
    row(
        &mut s,
        "witness variables",
        v3.witness_variables.to_string(),
        v2.witness_variables.to_string(),
        delta(v3.witness_variables, v2.witness_variables),
    );
    row(
        &mut s,
        "instance variables",
        v3.instance_variables.to_string(),
        v2.instance_variables.to_string(),
        same(v3.instance_variables, v2.instance_variables),
    );
    row(
        &mut s,
        "a_query",
        v3.key.a_query.to_string(),
        v2.key.a_query.to_string(),
        delta(v3.key.a_query, v2.key.a_query),
    );
    row(
        &mut s,
        "b_g1_query",
        v3.key.b_g1_query.to_string(),
        v2.key.b_g1_query.to_string(),
        delta(v3.key.b_g1_query, v2.key.b_g1_query),
    );
    row(
        &mut s,
        "b_g2_query",
        v3.key.b_g2_query.to_string(),
        v2.key.b_g2_query.to_string(),
        same(v3.key.b_g2_query, v2.key.b_g2_query),
    );
    row(
        &mut s,
        "h_query",
        v3.key.h_query.to_string(),
        v2.key.h_query.to_string(),
        delta(v3.key.h_query, v2.key.h_query),
    );
    row(
        &mut s,
        "l_query",
        v3.key.l_query.to_string(),
        v2.key.l_query.to_string(),
        delta(v3.key.l_query, v2.key.l_query),
    );
    row(
        &mut s,
        "ic (contract-facing)",
        v3.key.ic.to_string(),
        v2.key.ic.to_string(),
        same(v3.key.ic, v2.key.ic),
    );
    row(
        &mut s,
        "proof on-chain bytes",
        v3.proof_on_chain_bytes.to_string(),
        v2.proof_on_chain_bytes.to_string(),
        same(v3.proof_on_chain_bytes, v2.proof_on_chain_bytes),
    );
    row(
        &mut s,
        "verifies",
        v3.verifies.to_string(),
        v2.verifies.to_string(),
        String::new(),
    );
    row(
        &mut s,
        "every component bound",
        (v3.binding.epoch && v3.binding.root && v3.binding.norm).to_string(),
        (v2.binding.epoch && v2.binding.root && v2.binding.norm).to_string(),
        String::new(),
    );
    let passed = |m: &M4bMeasurement| (m.prove_time <= OUTER_PROVE_THRESHOLD).to_string();
    row(
        &mut s,
        &format!("§5.5.4 prove ≤ {} s", OUTER_PROVE_THRESHOLD.as_secs()),
        passed(v3),
        passed(v2),
        String::new(),
    );
    let _ = writeln!(s);
    let _ = writeln!(
        s,
        "  keccak256(canonical vk)   : {a} {}",
        v3.vk_canonical_digest
    );
    let _ = writeln!(
        s,
        "                              {b} {}",
        v2.vk_canonical_digest
    );
    let _ = writeln!(
        s,
        "  keccak256(canonical proof): {a} {}",
        v3.proof_canonical_digest
    );
    let _ = writeln!(
        s,
        "                              {b} {}",
        v2.proof_canonical_digest
    );

    let _ = writeln!(s);
    let _ = writeln!(
        s,
        "curves an implementation must carry (a fact about the variant)"
    );
    let _ = writeln!(
        s,
        "  {a:<26}{} — BN254: the commitment is field arithmetic and needs no group",
        v3.variant.curves()
    );
    let _ = writeln!(
        s,
        "  {b:<26}{} — BN254 + Baby Jubjub (the commitment's group), whose base field",
        v2.variant.curves()
    );
    let _ = writeln!(s, "  {:<26}is Fr_BN254, i.e. native in this circuit", "");

    let _ = writeln!(s);
    let _ = writeln!(s, "verdict (D-M4-0)");
    let _ = writeln!(
        s,
        "  criterion                 §5.5.4 declares no numeric threshold here — the decision"
    );
    let _ = writeln!(
        s,
        "                            is \"decided on the measured cost\", so the rows above are"
    );
    let _ = writeln!(
        s,
        "                            the criterion: constraints first (the key's size and the"
    );
    let _ = writeln!(
        s,
        "                            prover's work follow from them), curves to break a tie"
    );
    let (winner, why) = duel_verdict(v3, v2);
    let loser = if winner == v3.variant {
        v2.variant
    } else {
        v3.variant
    };
    let _ = writeln!(
        s,
        "  decision                  {} — {} pays {}",
        winner.name(),
        loser.name(),
        why
    );
    s
}

/// The `D-M4-0` decision as a value: which variant the measured pair selects, and
/// why, in one sentence. Public so that a test asserts the **decision** rather
/// than a substring of the table, and so the renderer cannot print a verdict the
/// numbers do not support.
///
/// The rule §5.5.4 states is "decided on the measured cost", so the rule is what
/// this function implements: the constraint count comes first — the key's size and
/// the prover's work follow from it — and [`Variant::curves`] breaks a tie. Both
/// inputs are facts the measurements carry, and neither is a threshold the plan
/// would have to have declared.
pub fn duel_verdict(v3: &M4bMeasurement, v2: &M4bMeasurement) -> (Variant, String) {
    use std::fmt::Write as _;
    let (winner, loser, winner_cost, loser_cost) = if v2.constraints > v3.constraints {
        (v3.variant, v2.variant, v3.constraints, v2.constraints)
    } else if v3.constraints > v2.constraints {
        (v2.variant, v3.variant, v2.constraints, v3.constraints)
    } else if v3.variant.curves() <= v2.variant.curves() {
        (v3.variant, v2.variant, v3.constraints, v2.constraints)
    } else {
        (v2.variant, v3.variant, v2.constraints, v3.constraints)
    };

    let mut why = if winner_cost == loser_cost {
        "the same constraint count".to_string()
    } else {
        format!(
            "{} more constraints ({} vs {})",
            loser_cost - winner_cost,
            loser_cost,
            winner_cost
        )
    };
    let extra = loser.curves() as i64 - winner.curves() as i64;
    if extra > 0 {
        let _ = write!(
            why,
            " and {} more curve{}",
            extra,
            if extra == 1 { "" } else { "s" }
        );
    }
    (winner, why)
}
