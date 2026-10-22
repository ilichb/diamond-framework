//! Evidence probe for P-37 (not a permanent test): compare the V3 Poseidon
//! permutation and sponge digest against circomlib's t=3 vectors.
//!
//! Run from the repository root:
//! `cp docs/audit/evidence/2026-10-20-pocs/pocs/new/PoseidonCircomlibProbe.rs \
//!    src/zk/tests/TmpPoseidonVector.rs`
//! `cd src/zk && cargo test --offline --test TmpPoseidonVector -- --nocapture`
//! The copy in `src/zk/tests/` is removed after the log is saved.

use ark_bn254::Fr;
use ark_ff::{AdditiveGroup, Field};
use avip_zk_prover::fixture;
use avip_zk_prover::native::{poseidon_commitment, poseidon_params};

/// One raw Poseidon permutation over a 3-element state, in the same order the
/// crate's `PoseidonSponge` uses (`[capacity, rate0, rate1]`).
fn permute(params: &ark_crypto_primitives::sponge::poseidon::PoseidonConfig<Fr>, state: &mut [Fr]) {
    let full_half = params.full_rounds / 2;
    let apply_ark = |state: &mut [Fr], round: usize| {
        for (i, s) in state.iter_mut().enumerate() {
            *s += params.ark[round][i];
        }
    };
    let sbox = |state: &mut [Fr], full: bool| {
        if full {
            for s in state.iter_mut() {
                *s = s.pow([params.alpha]);
            }
        } else {
            state[0] = state[0].pow([params.alpha]);
        }
    };
    let mix = |state: &mut [Fr]| {
        let old = state.to_vec();
        for i in 0..state.len() {
            let mut acc = Fr::ZERO;
            for j in 0..state.len() {
                acc += params.mds[i][j] * old[j];
            }
            state[i] = acc;
        }
    };
    for r in 0..full_half {
        apply_ark(state, r);
        sbox(state, true);
        mix(state);
    }
    for r in full_half..full_half + params.partial_rounds {
        apply_ark(state, r);
        sbox(state, false);
        mix(state);
    }
    for r in full_half + params.partial_rounds..params.full_rounds + params.partial_rounds {
        apply_ark(state, r);
        sbox(state, true);
        mix(state);
    }
}

/// The same absorption convention the crate's sponge implements, written out
/// independently of `PoseidonSponge`: add each rate-sized block into
/// `state[capacity..]`, permute between blocks, and permute once before the
/// squeeze. The digest is the first rate element (`state[capacity]`).
///
/// This does not model circomlib (which has no standard 500-input Poseidon);
/// it pins the repo's absorption for the fixed 500-entry case.
fn manual_digest(entries: &[u64], params: &ark_crypto_primitives::sponge::poseidon::PoseidonConfig<Fr>) -> Fr {
    let mut state = vec![Fr::ZERO; params.rate + params.capacity];
    let blocks = entries.len().div_ceil(params.rate);
    for (block, chunk) in entries.chunks(params.rate).enumerate() {
        for (i, element) in chunk.iter().enumerate() {
            state[params.capacity + i] += Fr::from(*element);
        }
        // The sponge permutes only when it needs to make room for the next
        // block; the squeeze performs the final permutation.
        if block + 1 < blocks {
            permute(params, &mut state);
        }
    }
    permute(params, &mut state);
    state[params.capacity]
}

#[test]
fn print_circomlib_vector_comparison() {
    let params = poseidon_params();

    for (a, b, expected) in [
        (
            1u64,
            2u64,
            "7853200120776062878684798364095072458815029376092732009249414926327459813530",
        ),
        (
            3u64,
            4u64,
            "14763215145315200506921711489642608356394854266165572616578112107564877678998",
        ),
    ] {
        let sponge = poseidon_commitment(&[a, b], &params);

        // circomlib `Poseidon(2)`: initialState = 0, inputs in positions 1..2.
        let mut state = [Fr::ZERO, Fr::from(a), Fr::from(b)];
        permute(&params, &mut state);

        let expected = expected.parse::<Fr>().expect("vector");
        println!("inputs [{a}, {b}]");
        println!("  circomlib expected        : {expected}");
        println!("  raw permutation state[0]  : {}", state[0]);
        println!("  arkworks sponge digest    : {sponge} (state[1])");
        println!("  raw permutation state[2]  : {}", state[2]);

        assert_eq!(state[0], expected, "permutation/constants differ from circomlib");
        assert_eq!(sponge, state[1], "sponge output is not state[1]");
        assert_ne!(sponge, expected, "digest convention unexpectedly matches circomlib");
    }
}

#[test]
fn manual_absorption_matches_sponge_for_multiple_lengths() {
    let params = poseidon_params();
    let tensor = fixture::tensor();
    let entries = tensor.entries();

    // Small lengths exercise a partial final block; 500 is the protocol's fixed
    // length, i.e. exactly 250 full rate-2 blocks. Neither case has a standard
    // circomlib counterpart, so the check is against the written-out sponge.
    let lengths = (1..=10).chain(core::iter::once(500));
    for len in lengths {
        let input = &entries[..len];
        let expected = manual_digest(input, &params);
        let actual = poseidon_commitment(input, &params);
        println!("len {len}: manual state[1] = {expected}, sponge = {actual}");
        assert_eq!(
            actual, expected,
            "absorption differs for {len} entries ({} blocks)",
            len.div_ceil(params.rate)
        );
    }
}

/// Documents the domain-separation gap, not a protocol finding: with additive
/// absorption and no length tag, a trailing zero is invisible. This is why the
/// fixed 500-entry path is safe from this ambiguity but the public
/// `poseidon_commitment(&[u64])` API is not length-separated.
#[test]
fn trailing_zero_length_ambiguity_is_visible() {
    let params = poseidon_params();
    let short = poseidon_commitment(&[5], &params);
    let padded = poseidon_commitment(&[5, 0], &params);
    println!("[5]   = {short}");
    println!("[5,0] = {padded}");
    assert_eq!(short, padded, "the sponge unexpectedly separates lengths");
}
