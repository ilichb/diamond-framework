//! M7c: the Pedersen/Poseidon ↔ keccak256 Merkle bridge, from the outside.
//!
//! The unit tests in `src/bridge.rs` check the bridge against a second
//! implementation of the fold and against the emitted Solidity fixture. This
//! file checks the two *artifacts* a reader trusts: the fixture the contract test
//! installs, and the pinned table `scripts/m7c_output.txt`. If the library moves
//! and the pinned table is not regenerated, `cargo test` fails here — the drift
//! guard of §5.10, in the direction the shell script cannot check.

use avip_zk_prover::bridge::{
    self, Claim, Mismatch, TENSOR_SIZE, Verdict, open, position_key, root_bytes, uint256_decimal,
    verify,
};
use avip_zk_prover::fixture;

/// The emitted M4b Solidity fixture: the historical global statement the M7c
/// bridge pins its table against. Admission moved to M4d (P-01/P-16), so these
/// constants are a frozen artifact, not a live contract input.
fn emitted_fixture() -> String {
    read(&format!(
        "{}/../../integrations/avalanche/test/fixtures/M4bGroth16Fixtures.sol",
        env!("CARGO_MANIFEST_DIR")
    ))
}

/// The pinned table of `scripts/m7c_report.sh`.
fn pinned_table() -> String {
    read(&format!(
        "{}/scripts/m7c_output.txt",
        env!("CARGO_MANIFEST_DIR")
    ))
}

fn read(path: &str) -> String {
    std::fs::read_to_string(path)
        .unwrap_or_else(|e| panic!("{path} is committed and readable: {e}"))
}

/// The first alphanumeric token after the `name` **declaration** in a Solidity
/// source. Matching `constant NAME` rather than the bare name keeps a comment
/// that mentions the constant from answering first.
fn solidity_token(source: &str, name: &str) -> String {
    let needle = format!("constant {name}");
    let at = source
        .find(&needle)
        .unwrap_or_else(|| panic!("{name} is declared in the emitted fixture"));
    let token: String = source[at + needle.len()..]
        .chars()
        .skip_while(|c| !c.is_ascii_alphanumeric())
        .take_while(char::is_ascii_alphanumeric)
        .collect();
    assert!(!token.is_empty(), "{name} has a value");
    token
}

/// The value of a `  label : value` row of the pinned table.
fn row(table: &str, label: &str) -> String {
    table
        .lines()
        .find_map(|line| line.strip_prefix(label))
        .unwrap_or_else(|| panic!("the pinned table carries `{label}`"))
        .trim_start_matches([' ', ':'])
        .to_string()
}

/// The root the contract installs is the digest this bridge computes over the
/// committed tensor, at the epoch the contract installs, with the norm the
/// contract certifies — read off the emitted artifact, not restated here.
#[test]
fn the_bridge_answers_to_the_emitted_solidity_statement() {
    let source = emitted_fixture();
    let tensor = fixture::tensor();
    let bridge = open(tensor.entries(), 0);
    assert_eq!(
        solidity_token(&source, "STATEMENT_ROOT"),
        uint256_decimal(bridge.statement_root)
    );
    assert_eq!(
        solidity_token(&source, "STATEMENT_EPOCH"),
        bridge.state.number.to_string()
    );
    assert_eq!(
        solidity_token(&source, "STATEMENT_NORM"),
        (tensor.wad_norm() as u64).to_string()
    );
    assert_eq!(
        solidity_token(&source, "TENSOR_DIGEST"),
        format!("0x{}", tensor.digest_hex())
    );
}

/// Every number in the pinned table is what this revision computes, and no check
/// in it fails: the committed reproduction cannot go stale behind the library.
#[test]
fn the_pinned_report_carries_the_values_this_revision_computes() {
    let table = pinned_table();
    let source = emitted_fixture();
    let tensor = fixture::tensor();
    let bridge = open(tensor.entries(), 0);

    assert_eq!(
        row(&table, "  statement root (V3, Poseidon, uint256)"),
        uint256_decimal(bridge.statement_root)
    );
    assert_eq!(
        row(&table, "  statement root (hex)"),
        format!("0x{}", hex32(&root_bytes(bridge.statement_root)))
    );
    assert_eq!(
        row(&table, "  Merkle root (AVIPRegistry convention)"),
        format!("0x{}", hex32(&bridge.merkle_root))
    );
    assert_eq!(
        row(&table, "  link digest"),
        format!("0x{}", hex32(&bridge.link))
    );
    assert_eq!(
        row(&table, "  tensor digest (keccak256, 8-byte LE words)"),
        format!("0x{}", tensor.digest_hex())
    );
    assert_eq!(row(&table, "  epoch"), bridge.state.number.to_string());
    assert_eq!(row(&table, "  entries (C·D·H)"), TENSOR_SIZE.to_string());
    // The table agrees with the Solidity fixture too, through the same value.
    assert!(table.contains(&solidity_token(&source, "STATEMENT_ROOT")));

    let checks = row(&table, "  bridge checks");
    let (passed, rest) = checks
        .split_once('/')
        .unwrap_or_else(|| panic!("the table reports `n/n hold`, got {checks:?}"));
    assert_eq!(
        passed,
        rest.split_whitespace().next().unwrap_or_default(),
        "the pinned run must have no failing check"
    );
    assert!(checks.ends_with("hold"));
}

/// The four rejections of §5.5.7, over the committed tensor: a moved entry, a
/// positional swap, an epoch that is not the tree's, and a link from elsewhere.
#[test]
fn the_link_binds_the_root_the_epoch_and_the_tree() {
    let tensor = fixture::tensor();
    let entries = tensor.entries();
    let bridge = open(entries, 0);
    let claim = bridge.claim();
    assert_eq!(verify(entries, &claim), Verdict::Bound);

    let mut changed = entries.to_vec();
    changed[0] ^= 1;
    assert_eq!(
        verify(&changed, &claim),
        Verdict::Unbound(Mismatch::StatementRoot)
    );

    let mut swapped = entries.to_vec();
    swapped.swap(0, 1);
    assert_eq!(
        verify(&swapped, &claim),
        Verdict::Unbound(Mismatch::StatementRoot)
    );
    assert_eq!(
        verify(entries, &Claim { epoch: 1, ..claim }),
        Verdict::Unbound(Mismatch::Link)
    );
    assert_eq!(
        verify(
            entries,
            &Claim {
                link: open(&swapped, 0).link,
                ..claim
            }
        ),
        Verdict::Unbound(Mismatch::Link)
    );
}

/// The registry's own inclusion proof verifies against the root the bridge ties
/// to the statement: the two commitments describe the same leaves.
#[test]
fn registry_inclusion_verifies_against_the_bridged_root() {
    let tensor = fixture::tensor();
    let contract = open(tensor.entries(), 0);
    let positions = [
        0_usize,
        1,
        TENSOR_SIZE / 2 - 1,
        TENSOR_SIZE / 2,
        TENSOR_SIZE - 1,
    ];
    for position in positions {
        let proof = contract
            .state
            .inclusion_proof(position)
            .expect("a position of a non-empty epoch");
        assert!(
            avip_datalayer::commitment::verify_entry(
                &contract.merkle_root,
                &contract.state.entries[position].payload(),
                &proof
            ),
            "position {position}"
        );
    }
    assert_eq!(contract.merkle_root, contract.state.root());
    // The key is the position of `T[i]` in the 20-byte `validator` slot.
    assert_eq!(
        position_key(TENSOR_SIZE as u32 - 1)[16..],
        [0x00, 0x00, 0x01, 0xf3]
    );
    assert_ne!(
        bridge::link_digest(&contract.merkle_root, contract.statement_root, 1),
        contract.link
    );
}

/// Lowercase hex of a 32-byte digest; the table prints digests with a `0x`.
fn hex32(bytes: &[u8; 32]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}
