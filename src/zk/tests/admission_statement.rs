//! M4d: the admission statement must bind the validator (P-01) and the epoch
//! must be part of the same slot as the root (P-16), not a second, independently
//! writable slot.

use avip_zk_prover::admission::{self, STATEMENT_LEN, TREE_DEPTH, TREE_LEAVES};
use avip_zk_prover::fixture::{self, ADMISSION_EPOCH, ADMISSION_INDEX, N, WAD};
use avip_zk_prover::native;

fn entries() -> (Vec<[u8; 20]>, Vec<u64>) {
    (fixture::validators(), fixture::tensor().entries().to_vec())
}

#[test]
fn every_real_leaf_has_a_path_to_the_committed_root() {
    let (validators, norms) = entries();
    let params = native::poseidon_params();
    let root = admission::statement_root(&validators, &norms, &params);
    for index in [0, 1, 2, 255, 256, N - 1] {
        let leaf = admission::leaf(&validators[index], norms[index], &params);
        let path = admission::merkle_path(&validators, &norms, index, &params);
        assert_eq!(path.len(), TREE_DEPTH);
        assert_eq!(admission::root_from_path(leaf, &path, index, &params), root);
    }
}

#[test]
fn the_tree_is_the_declared_shape_and_padding_is_constant() {
    let (validators, norms) = entries();
    let params = native::poseidon_params();
    let leaves = admission::leaves(&validators, &norms, &params);
    assert_eq!(leaves.len(), TREE_LEAVES);
    assert!(
        leaves[..N]
            .iter()
            .all(|leaf| *leaf != ark_bn254::Fr::from(0u64))
    );
    assert!(
        leaves[N..]
            .iter()
            .all(|leaf| *leaf == ark_bn254::Fr::from(0u64))
    );
}

#[test]
fn the_circuit_binds_root_epoch_validator_and_norm() {
    let (validators, norms) = entries();
    let measurement = admission::measure(&validators, &norms, ADMISSION_INDEX, ADMISSION_EPOCH);
    assert!(measurement.verifies);
    assert_eq!(measurement.ic, STATEMENT_LEN + 1);
    assert_eq!(measurement.binding, [true; STATEMENT_LEN]);
    assert_eq!(measurement.validator, validators[ADMISSION_INDEX]);
    assert_eq!(measurement.norm_wad, norms[ADMISSION_INDEX]);
}

#[test]
fn a_proof_for_one_validator_does_not_admit_another() {
    let (validators, norms) = entries();
    let params = native::poseidon_params();
    let root = admission::statement_root(&validators, &norms, &params);
    let dev = admission::key_and_proof(&validators, &norms, ADMISSION_INDEX, ADMISSION_EPOCH);
    let (validator, norm) = (validators[ADMISSION_INDEX], norms[ADMISSION_INDEX]);

    let honest = admission::statement_inputs(root, ADMISSION_EPOCH, &validator, norm);
    assert!(admission::verifies(&dev.pk, &dev.proof, &honest));

    // P-01: the old M4b statement did not mention the validator, so this
    // replay succeeded. It must now fail.
    let stolen = admission::statement_inputs(root, ADMISSION_EPOCH, &validators[0], norm);
    assert!(!admission::verifies(&dev.pk, &dev.proof, &stolen));

    // P-16: changing only the epoch must also fail.
    let stale = admission::statement_inputs(root, ADMISSION_EPOCH + 1, &validator, norm);
    assert!(!admission::verifies(&dev.pk, &dev.proof, &stale));
}

#[test]
fn the_circuit_rejects_an_out_of_range_norm() {
    let (validators, norms) = entries();
    let index = 3;

    // Recompute the root and path for each malformed entry, so the *only*
    // failing constraint is the range check under test, not the root equality.
    for bad_norm in [WAD, WAD + 1] {
        let mut bad_norms = norms.clone();
        bad_norms[index] = bad_norm;
        let (cost, synthesized) = native::synthesize(admission::circuit_for(
            &validators,
            &bad_norms,
            index,
            ADMISSION_EPOCH,
        ));
        assert!(
            synthesized.is_err() || !cost.satisfied,
            "norm {bad_norm} (>= 1.0 WAD) must not satisfy the circuit"
        );
    }

    let mut bad_validators = validators.clone();
    bad_validators[index] = [0_u8; 20];
    let (cost, synthesized) = native::synthesize(admission::circuit_for(
        &bad_validators,
        &norms,
        index,
        ADMISSION_EPOCH,
    ));
    assert!(
        synthesized.is_err() || !cost.satisfied,
        "the zero address must not satisfy the circuit"
    );
}
