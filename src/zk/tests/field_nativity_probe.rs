//! Nativity probe for plan §5.5.2: V2 says "Pedersen over BN254 G1, recomputed
//! inside the circuit" and claims "no curve mismatch: everything native".
//!
//! A BN254 G1 point has coordinates in `Fq`; a Groth16/BN254 circuit runs over
//! `Fr`. This probe asks the type system whether `ProjectiveVar<g1::Config, _>`
//! type-checks with the circuit field, which is the condition for V2 to be
//! implementable at all.
//!
//! Result (verified, not quoted) — with
//!
//! ```text
//! type V2CommitmentVar = ProjectiveVar<ark_bn254::g1::Config, FpVar<ark_bn254::Fr>>;
//! ```
//!
//! `cargo test` stops with:
//!
//! ```text
//! error[E0277]: the trait bound `FpVar<Fp<MontBackend<FrConfig, 4>, 4>>:
//!               FieldVar<Fp<..., 4>, ...>` is not satisfied
//! help: the trait `FieldVar<Fq, Fq>` is not implemented for `FpVar<Fr>`
//!       but trait `FieldVar<Fr, Fr>` is implemented for it
//!    --> ark-r1cs-std-0.6.0/src/fields/fp/mod.rs:856
//!       impl<F: PrimeField> FieldVar<F, F> for FpVar<F>
//! note: required by a bound in `ProjectiveVar`
//! ```
//!
//! So the only `FpVar` satisfying `ProjectiveVar`'s bound for BN254 G1 is
//! `FpVar<Fq>`, whose constraint field is `Fq` — not the field of the outer
//! Groth16 proof M4b installs. The line stays commented out because the evidence
//! *is* the compile error; uncommenting it reproduces the finding.

#[allow(dead_code)]
mod probe {
    // use ark_bn254::g1::Config as Bn254G1;
    // use ark_bn254::Fr;
    // use ark_r1cs_std::fields::fp::FpVar;
    // use ark_r1cs_std::groups::curves::short_weierstrass::ProjectiveVar;
    //
    // type V2CommitmentVar = ProjectiveVar<Bn254G1, FpVar<Fr>>;
}

/// The bound `ProjectiveVar` requires, checked against the two fields so the
/// finding cannot be reduced to prose.
#[test]
fn projective_var_requires_the_field_of_the_curve() {
    use ark_ec::CurveConfig;
    use ark_ff::PrimeField;
    // `ark_r1cs_std::groups::curves::short_weierstrass::ProjectiveVar`:
    //
    //     pub struct ProjectiveVar<
    //         P: SWCurveConfig,
    //         F: FieldVar<P::BaseField, BasePrimeField<P>>,
    //     > { .. }
    //
    // For BN254 G1: `P::BaseField = Fq`, `BasePrimeField<Fq> = Fq`.
    // For the outer proof: the constraint field must be `Fr`.
    use ark_bn254::g1::Config as Bn254G1;
    assert_eq!(
        <Bn254G1 as CurveConfig>::BaseField::MODULUS_BIT_SIZE,
        254,
        "G1 coordinates live in Fq"
    );
    assert_ne!(
        ark_bn254::Fq::MODULUS,
        ark_bn254::Fr::MODULUS,
        "Fq <> Fr: G1 coordinates are not native to a Fr circuit"
    );
}
