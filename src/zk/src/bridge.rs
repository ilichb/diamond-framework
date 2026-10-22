//! M7c — the Pedersen ↔ Merkle bridge: option (c) of plan §5.4 item 4, owed by
//! §5.5.7 and §5.5.10, delivered in §5.10 (gap **A7**).
//!
//! **The gap, in one paragraph.** The statement `AVIPRegistry.verifyThreshold`
//! builds today is four words — `[statementRoot, epoch, uint160(validator),
//! certifiedNorm]` since M4d (`AVIPRegistry.sol:386-394`); in M4b it was the
//! three-word global statement `[root, epoch, certifiedNorm]` — and the root it
//! carries is the **Poseidon** commitment of the tensor (V3, §5.5.2) — a field
//! element of `Fr_BN254`, written by the circuit. The root the *registry* stores
//! for an epoch is a **`keccak256` Merkle root** over leaves, the one
//! `verifyEntry` folds (M1/M6). A Groth16 proof over BN254 cannot compute keccak
//! inside the circuit at any price the plan is willing to pay, so the two roots
//! are two readings of the same 500 numbers with **nothing tying them
//! together**: a verifier that trusts the Merkle root learns nothing about the
//! tensor a proof certified, and vice versa. That is gap A7.
//!
//! **What option (c) does about it.** It leaves keccak canonical on-chain and
//! Pedersen/Poseidon canonical in the circuit, and puts the tie **off-chain, in
//! the data layer** — this module — as a *recomputable* link:
//!
//! ```text
//! link = keccak256(abi.encodePacked(bytes32 merkleRoot, uint256 statementRoot, uint256 epoch))
//! ```
//!
//! Anyone holding the tensor performs three cheap computations — fold the
//! leaves, digest with Poseidon, hash three words — and either the
//! `statementRoot` in an accepted proof is the digest of *that* tensor, at
//! *that* epoch, behind *that* Merkle root, or it is not. The link is a
//! commitment, not a proof.
//!
//! **The tree is M1's tree, not a copy of it.** [`open`] builds an
//! `avip_datalayer::commitment::Epoch`, i.e. the very structure
//! `AVIPRegistry.verifyEntry` verifies, and the leaves are `Entry::leaf`'s
//! `keccak256(abi.encodePacked(bytes20 key, uint256 value))` — folded by that
//! crate's `merkle_root`, which is pinned against `cast keccak`. There is one
//! implementation of the convention in the repository, so the bridge cannot
//! drift from the contract the way a second copy would.
//!
//! **What the key is, and what it is not.** The `key` of entry `i` is
//! [`position_key`]`(i)` — the **position** of the tensor entry, not a validator
//! address. `Entry`'s field is named `validator` because M1 stores reputation
//! per validator; here it carries the index `i` of `T[i]`, which is what the
//! tensor is indexed by (`main.tex` `eq:tensor`). Identifying a tensor position
//! with a validator — the `T → W` map — is **not** claimed here and is not
//! closed by M7: §10 keeps it open as **D-7**. What *is* claimed is the
//! arithmetic: this Merkle root is the root of these 500 entries under the
//! convention the contract verifies, and this link ties it to the statement.
//!
//! **What the bridge does not do.** A link is as strong as the tensor it is
//! recomputed from. It gives a verifier that *has* the tensor the tie; it does
//! not give one that only has the roots anything, and it does not make the proof
//! itself talk about keccak. Making the tie part of the proof would need a
//! keccak gadget inside the circuit (infeasible at this size) or the two roots
//! published side by side and trusted together — a statement-shape change
//! (`ic.length`, M3's frozen contract) that §5.5.7 does not decide. The link is
//! the option (c) answer: **the data layer certifies the tie, the proof
//! certifies the norm.**
//!
//! Two variants reach here identically: the link takes whatever `uint256` the
//! statement carries, so V3's Poseidon digest and V2′'s Pedersen x-coordinate
//! are both linkable with the same 3-word hash. For V2′ that leaves §5.5.10's
//! residual standing — the x-coordinate alone does not bind the point — which
//! the M7c report states as a measured row rather than a footnote.
//!
//! The one documented command is `scripts/m7c_report.sh`.

use ark_bn254::Fr;
use ark_ff::{BigInteger, PrimeField};

use avip_datalayer::commitment::{Entry, Epoch, merkle_root};
use avip_datalayer::keccak::keccak256;

use crate::fixture;
use crate::native;

/// `C·D·H = 500` (`main.tex` `eq:tensor`), the size the bridge is defined for.
pub const TENSOR_SIZE: usize = fixture::N;

/// A `uint256` word in `abi.encodePacked`.
const WORD: usize = 32;

/// The 20-byte key of tensor position `i`, for the leaf payload.
///
/// `AVIPRegistry` keys its entries by a 20-byte address; this reuses that slot
/// for the position, because that is the only key the tensor has. See the module
/// docs for what that does and does not claim (`D-7` keeps `T → W` open).
#[must_use]
pub fn position_key(position: u32) -> [u8; 20] {
    let mut key = [0_u8; 20];
    key[16..].copy_from_slice(&position.to_be_bytes());
    key
}

/// The tensor as the state M1/M6 commit: entry `i` = (position `i`, `T[i]` WAD).
///
/// This is the bridge's whole modelling decision, and it is one line on purpose:
/// `Epoch`/`Entry` are reused **as they are**, so the leaves, the fold, the
/// inclusion proofs and `verifyEntry` are the deployed `AVIPRegistry`'s
/// behaviour rather than a re-description of it.
///
/// # Panics
/// If `entries.len() != TENSOR_SIZE` (500): the bridge is defined for
/// `eq:tensor`'s shape, and a silently different length would change every
/// number in the pinned table.
#[must_use]
pub fn tensor_state(entries: &[u64], epoch: u64) -> Epoch {
    assert_eq!(
        entries.len(),
        TENSOR_SIZE,
        "the bridge is defined for eq:tensor's C·D·H = {TENSOR_SIZE} entries"
    );
    Epoch::new(
        epoch,
        entries
            .iter()
            .enumerate()
            .map(|(i, value)| Entry {
                validator: position_key(i as u32),
                norm_wad: u128::from(*value),
            })
            .collect(),
    )
}

/// `uint256(root)` as the contract reads it: the field element in 32 big-endian
/// bytes. `STATEMENT_ROOT` in `M4bGroth16Fixtures.sol` is this value in decimal,
/// and the test module compares the two.
#[must_use]
pub fn root_bytes(root: Fr) -> [u8; WORD] {
    let mut out = [0_u8; WORD];
    let bytes = root.into_bigint().to_bytes_be();
    out[WORD - bytes.len()..].copy_from_slice(&bytes);
    out
}

/// `keccak256(abi.encodePacked(bytes32 merkleRoot, uint256 statementRoot, uint256 epoch))`.
///
/// Three fixed-width words, so the encoding is unambiguous — the property
/// `abi.encodePacked` does *not* have in general and does have for these types.
#[must_use]
pub fn link_digest(merkle_root: &[u8; 32], statement_root: Fr, epoch: u64) -> [u8; 32] {
    let mut buf = [0_u8; 3 * WORD];
    buf[..WORD].copy_from_slice(merkle_root);
    buf[WORD..2 * WORD].copy_from_slice(&root_bytes(statement_root));
    buf[2 * WORD + 24..].copy_from_slice(&epoch.to_be_bytes());
    keccak256(&buf)
}

/// The `root` the V3 statement carries for a tensor, recomputed off-circuit:
/// [`native::poseidon_commitment`] with the instantiated parameters, i.e. the
/// same function that fills [`crate::groth16::circuit_for`]'s public input.
#[must_use]
pub fn statement_root(entries: &[u64]) -> Fr {
    native::poseidon_commitment(entries, &native::poseidon_params())
}

/// The `uint256(root)` **decimal** the contract's Solidity fixture prints, from
/// the 32 big-endian bytes: long division by `10^9`, so no big-integer crate and
/// no dependence on how a field element happens to implement `Display`. This is
/// what makes `STATEMENT_ROOT` in `M4bGroth16Fixtures.sol` comparable to the
/// `root` a proof carries.
#[must_use]
pub fn uint256_decimal(root: Fr) -> String {
    let mut limbs = root_bytes(root);
    let mut chunks: Vec<u32> = Vec::new();
    loop {
        let mut rem: u64 = 0;
        for b in &mut limbs {
            let cur = (rem << 8) | u64::from(*b);
            *b = (cur / 1_000_000_000) as u8;
            rem = cur % 1_000_000_000;
        }
        chunks.push(rem as u32);
        if limbs.iter().all(|b| *b == 0) {
            break;
        }
    }
    chunks.reverse();
    let mut s = chunks[0].to_string();
    for c in &chunks[1..] {
        use core::fmt::Write as _;
        let _ = write!(s, "{c:09}");
    }
    s
}

/// The tensor, in both of the bridge's readings, plus the link between them.
pub struct Bridge {
    /// The tensor as M1/M6 state: 500 entries, keyed by position.
    pub state: Epoch,
    /// `AVIPRegistry`'s tree over [`Bridge::state`]'s leaves.
    pub merkle_root: [u8; 32],
    /// The `root` the Groth16 statement carries (V3: Poseidon).
    pub statement_root: Fr,
    /// The tie: `link_digest(merkle_root, statement_root, epoch)`.
    pub link: [u8; 32],
}

/// What a verifier is handed when a root and an epoch are announced: the
/// statement's public root, its epoch, and the link that is supposed to tie them
/// to the registry's tree.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Claim {
    /// `statement[0]`, as the contract reads it.
    pub statement_root: Fr,
    /// `statement[1]`.
    pub epoch: u64,
    /// The published link.
    pub link: [u8; 32],
}

/// Why a claim did not bind.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Mismatch {
    /// The claimed `root` is not the Poseidon digest of the tensor presented.
    StatementRoot,
    /// The two roots are this tensor's, but the link does not tie them at the
    /// claimed epoch: either the epoch moved, or the link was built from another
    /// tree.
    Link,
}

impl core::fmt::Display for Mismatch {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        match self {
            Self::StatementRoot => f.write_str("statement root is not this tensor's digest"),
            Self::Link => f.write_str("link does not tie these roots at this epoch"),
        }
    }
}

/// The link's verdict over a tensor.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Verdict {
    /// The statement's root, the epoch and the link are this tensor's.
    Bound,
    /// One of the three is not, with the first check that failed.
    Unbound(Mismatch),
}

impl Bridge {
    /// The claim this tensor's proof would announce.
    #[must_use]
    pub fn claim(&self) -> Claim {
        Claim {
            statement_root: self.statement_root,
            epoch: self.state.number,
            link: self.link,
        }
    }
}

/// Open the bridge over a tensor: fold M1's tree, digest with Poseidon, hash the
/// link.
#[must_use]
pub fn open(entries: &[u64], epoch: u64) -> Bridge {
    let state = tensor_state(entries, epoch);
    let merkle_root = merkle_root(&state.leaves());
    let statement_root = statement_root(entries);
    let link = link_digest(&merkle_root, statement_root, epoch);
    Bridge {
        state,
        merkle_root,
        statement_root,
        link,
    }
}

/// Recompute the bridge **from the tensor** and decide a claim. Nothing is
/// trusted: the only inputs are the entries and the claim, and every check is a
/// recomputation. This is the function a data-layer peer runs when it sees a
/// root published for an epoch.
#[must_use]
pub fn verify(entries: &[u64], claim: &Claim) -> Verdict {
    let recomputed = statement_root(entries);
    if recomputed != claim.statement_root {
        return Verdict::Unbound(Mismatch::StatementRoot);
    }
    let root = merkle_root(&tensor_state(entries, claim.epoch).leaves());
    if link_digest(&root, recomputed, claim.epoch) != claim.link {
        return Verdict::Unbound(Mismatch::Link);
    }
    Verdict::Bound
}

#[cfg(test)]
mod tests {
    use super::*;
    use avip_datalayer::commitment::verify_entry;
    use sha3::{Digest, Keccak256};

    /// The emitted M4b Solidity fixture: the historical *global* statement the
    /// M7c bridge reads. The M4b contract test has been retired in favour of M4d,
    /// so this ties the bridge to the committed artifact and its pinned table,
    /// not to an active admission path.
    fn emitted_fixture() -> String {
        let path = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../../integrations/avalanche/test/fixtures/M4bGroth16Fixtures.sol");
        std::fs::read_to_string(&path)
            .unwrap_or_else(|e| panic!("the M4b fixture is committed at {}: {e}", path.display()))
    }

    /// The first alphanumeric token after the `name` **declaration** in a
    /// Solidity source: the value of `… constant NAME = …`, decimal or `0x…`,
    /// without a Solidity parser. Matching the declaration and not the bare
    /// name is what keeps a comment that mentions `NAME` from answering first.
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

    /// The contract's fold, rewritten from its rule — `keccak256` of the
    /// *ordered* pair, odd node promoted — so that "the tree is the registry's"
    /// is checked against a second implementation instead of assumed.
    fn independent_root(leaves: &[[u8; 32]]) -> [u8; 32] {
        let mut level = leaves.to_vec();
        while level.len() > 1 {
            level = level
                .chunks(2)
                .map(|pair| match pair {
                    [a, b] => {
                        let (lo, hi) = if a < b { (a, b) } else { (b, a) };
                        let mut buf = [0_u8; 64];
                        buf[..WORD].copy_from_slice(lo);
                        buf[WORD..].copy_from_slice(hi);
                        Keccak256::digest(buf).into()
                    }
                    [a] => *a,
                    _ => unreachable!("chunks(2) yields one or two elements"),
                })
                .collect();
        }
        level[0]
    }

    #[test]
    fn the_leaf_is_abi_encode_packed_of_key_and_value() {
        let tensor = fixture::tensor();
        let state = tensor_state(tensor.entries(), 0);
        for (position, entry) in state.entries.iter().enumerate() {
            let mut payload = [0_u8; 52];
            payload[..20].copy_from_slice(&entry.validator);
            payload[36..].copy_from_slice(&entry.norm_wad.to_be_bytes());
            assert_eq!(payload, entry.payload(), "position {position}");
            let digest: [u8; 32] = Keccak256::digest(payload).into();
            assert_eq!(digest, entry.leaf(), "position {position}");
        }
    }

    #[test]
    fn the_fold_is_the_contracts_fold() {
        let tensor = fixture::tensor();
        let bridge = open(tensor.entries(), 0);
        let leaves = bridge.state.leaves();
        assert_eq!(leaves.len(), TENSOR_SIZE);
        // 500 leaves: 500 → 250 → 125 → … → 1, so the promoted-odd-node branch is
        // on the path (125, 63) and not dead code.
        assert_eq!(bridge.merkle_root, independent_root(&leaves));
        assert_eq!(bridge.merkle_root, bridge.state.root());
    }

    #[test]
    fn the_statement_root_is_the_emitted_solidity_statement() {
        let source = emitted_fixture();
        let tensor = fixture::tensor();
        let bridge = open(tensor.entries(), 0);
        assert_eq!(
            solidity_token(&source, "STATEMENT_ROOT"),
            uint256_decimal(bridge.statement_root),
            "the root the contract installs is the Poseidon digest of this tensor"
        );
        assert_eq!(
            solidity_token(&source, "STATEMENT_EPOCH"),
            bridge.state.number.to_string()
        );
        assert_eq!(
            solidity_token(&source, "STATEMENT_NORM"),
            (tensor.wad_norm() as u64).to_string(),
            "certifiedNorm = floor(sqrt(sum T_i^2)), the value M4b bound"
        );
        assert_eq!(
            solidity_token(&source, "TENSOR_DIGEST"),
            format!("0x{}", tensor.digest_hex())
        );
    }

    #[test]
    fn the_link_is_three_words_of_abi_encode_packed() {
        let tensor = fixture::tensor();
        let bridge = open(tensor.entries(), 0);
        let mut buf = [0_u8; 96];
        buf[..32].copy_from_slice(&bridge.merkle_root);
        buf[32..64].copy_from_slice(&root_bytes(bridge.statement_root));
        buf[88..96].copy_from_slice(&bridge.state.number.to_be_bytes());
        let direct: [u8; 32] = Keccak256::digest(buf).into();
        assert_eq!(bridge.link, direct);
        // The epoch is the low word, so moving it moves the digest.
        assert_ne!(
            bridge.link,
            link_digest(&bridge.merkle_root, bridge.statement_root, 1)
        );
    }

    #[test]
    fn the_link_binds_root_epoch_and_tree() {
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
            Verdict::Unbound(Mismatch::StatementRoot),
            "the binding is positional"
        );

        let other = Claim { epoch: 1, ..claim };
        assert_eq!(
            verify(entries, &other),
            Verdict::Unbound(Mismatch::Link),
            "the epoch is inside the link, not beside it"
        );

        let foreign = Claim {
            link: open(&swapped, 0).link,
            ..claim
        };
        assert_eq!(verify(entries, &foreign), Verdict::Unbound(Mismatch::Link));
    }

    #[test]
    fn inclusion_proofs_verify_against_the_bridge_root() {
        let tensor = fixture::tensor();
        let bridge = open(tensor.entries(), 0);
        for position in [0_usize, 1, 249, 250, 499] {
            let proof = bridge
                .state
                .inclusion_proof(position)
                .expect("a position of a non-empty epoch");
            assert!(
                verify_entry(
                    &bridge.merkle_root,
                    &bridge.state.entries[position].payload(),
                    &proof
                ),
                "position {position}"
            );
        }
        // The proof is for *this* leaf: another entry's payload does not verify.
        let proof = bridge.state.inclusion_proof(0).expect("proof");
        assert!(!verify_entry(
            &bridge.merkle_root,
            &bridge.state.entries[1].payload(),
            &proof
        ));
    }

    #[test]
    fn position_keys_are_distinct() {
        let keys: std::collections::BTreeSet<[u8; 20]> =
            (0..TENSOR_SIZE as u32).map(position_key).collect();
        assert_eq!(keys.len(), TENSOR_SIZE);
        assert_eq!(position_key(499), {
            let mut key = [0_u8; 20];
            key[16..].copy_from_slice(&499_u32.to_be_bytes());
            key
        });
    }

    #[test]
    #[should_panic(expected = "C·D·H")]
    fn tensor_state_rejects_another_size() {
        let _ = tensor_state(&[1, 2, 3, 4], 0);
    }

    #[test]
    fn uint256_decimal_matches_the_field_element() {
        // 1, then a value whose decimal is not a round number of chunks.
        assert_eq!(uint256_decimal(Fr::from(1_u64)), "1");
        let many = Fr::from(123_456_789_012_345_678_901_234_567_890_u128);
        assert_eq!(uint256_decimal(many), "123456789012345678901234567890");
    }
}
