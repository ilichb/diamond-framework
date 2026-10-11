//! Epoch state → leaves → Merkle root, in `AVIPRegistry`'s convention.
//!
//! The map M6 owns is *state → commitment*, and it is not a free choice: M1's
//! `verifyEntry` fixes it — `node = keccak256(abi.encodePacked(leaf))` at the
//! bottom, and at every level `keccak256(abi.encodePacked(min, max))` with the two
//! children ordered by their 32-byte value. A root that follows that convention is
//! verifiable by the deployed contract's `verifyEntry` **unchanged**, which is the
//! acceptance criterion; the transport that carries the payload to the registry is
//! M7's, and how a norm is certified (M3's proof, `eq:ingestion`'s `T`) is not
//! M6's to invent.
//!
//! Two things the contract does *not* fix, so M6 states them as its own choices
//! rather than as findings:
//!
//! - **Odd node promotion.** A level with an odd number of nodes carries the last
//!   one up unchanged. The contract only checks a supplied proof, so the tree's
//!   shape is M6's; promotion keeps every proof the same length.
//! - **The leaf payload.** `abi.encodePacked(address validator, uint256 norm)`, 52
//!   bytes, i.e. exactly what a Solidity client would hash for an entry. The digest
//!   published per epoch is `keccak256(abi.encodePacked(uint256 epoch, bytes32
//!   root))`.
//!
//! Freshness is M1's own bound: `γ·N = (500 · 1000)/10_000 = 50` entries per epoch
//! (`eq:freshness`), which [`Epoch::freshness_ok`] enforces the same way
//! `commitEpoch` does.

use std::collections::BTreeMap;

use crate::keccak::keccak256;

/// `N = C·D·H`: the tensor this registry commits to (`AVIPRegistry.TENSOR_SIZE`).
pub const TENSOR_SIZE: u32 = 500;

/// `γ` in basis points (`GAMMA_BPS`).
pub const GAMMA_BPS: u32 = 1000;

/// The basis-point denominator.
pub const BPS_DENOMINATOR: u32 = 10_000;

/// `γ·N = 50`: the most entries an epoch may change (`MAX_DELTA_ENTRIES`).
pub const MAX_DELTA_ENTRIES: u32 = (TENSOR_SIZE * GAMMA_BPS) / BPS_DENOMINATOR;

/// One entry of the committed state: a validator and its certified norm, in WAD.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Entry {
    /// The validator address, as `AVIPValidatorManager` keys it.
    pub validator: [u8; 20],
    /// `r = ‖T‖_F` in WAD — the same quantity `collateralFor` takes.
    pub norm_wad: u128,
}

impl Entry {
    /// `abi.encodePacked(address, uint256)`: 20 + 32 bytes, the WAD value
    /// right-aligned in its 32-byte word.
    #[must_use]
    pub fn payload(&self) -> [u8; 52] {
        let mut out = [0_u8; 52];
        out[..20].copy_from_slice(&self.validator);
        out[36..].copy_from_slice(&self.norm_wad.to_be_bytes());
        out
    }

    /// The leaf the tree hashes: `keccak256(payload)`.
    #[must_use]
    pub fn leaf(&self) -> [u8; 32] {
        keccak256(&self.payload())
    }
}

/// `verifyEntry`'s bottom step: `keccak256(abi.encodePacked(leaf))`.
#[must_use]
pub fn leaf_hash(payload: &[u8]) -> [u8; 32] {
    keccak256(payload)
}

/// `verifyEntry`'s inner step: `keccak256(abi.encodePacked(min, max))`, ordered by
/// the 32-byte value, exactly as the contract's `node < sibling` test does.
#[must_use]
pub fn pair_hash(a: &[u8; 32], b: &[u8; 32]) -> [u8; 32] {
    let mut buf = [0_u8; 64];
    if a < b {
        buf[..32].copy_from_slice(a);
        buf[32..].copy_from_slice(b);
    } else {
        buf[..32].copy_from_slice(b);
        buf[32..].copy_from_slice(a);
    }
    keccak256(&buf)
}

/// The Merkle root of `leaves`: `verifyEntry`'s tree, odd node promoted.
#[must_use]
pub fn merkle_root(leaves: &[[u8; 32]]) -> [u8; 32] {
    assert!(!leaves.is_empty(), "an empty epoch has no root");
    let mut level = leaves.to_vec();
    while level.len() > 1 {
        level = level
            .chunks(2)
            .map(|pair| match pair {
                [a, b] => pair_hash(a, b),
                [a] => *a,
                _ => unreachable!("chunks(2) yields one or two elements"),
            })
            .collect();
    }
    level[0]
}

/// The contract's `verifyEntry`, for a proof produced by
/// [`Epoch::inclusion_proof`] — the parity check that the root M6 posts is
/// verifiable by the deployed registry without changing it.
#[must_use]
pub fn verify_entry(root: &[u8; 32], payload: &[u8], proof: &[[u8; 32]]) -> bool {
    if root == &[0_u8; 32] {
        return false;
    }
    let mut node = leaf_hash(payload);
    for sibling in proof {
        node = pair_hash(&node, sibling);
    }
    &node == root
}

/// One epoch's committed state.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Epoch {
    /// The epoch number the registry keys the root by.
    pub number: u64,
    /// The entries, in the order they are leaves.
    pub entries: Vec<Entry>,
}

impl Epoch {
    /// A new epoch's state.
    #[must_use]
    pub fn new(number: u64, entries: Vec<Entry>) -> Self {
        Self { number, entries }
    }

    /// The leaves, in entry order.
    #[must_use]
    pub fn leaves(&self) -> Vec<[u8; 32]> {
        self.entries.iter().map(Entry::leaf).collect()
    }

    /// The Merkle root `AVIPRegistry` will store for this epoch.
    #[must_use]
    pub fn root(&self) -> [u8; 32] {
        merkle_root(&self.leaves())
    }

    /// `keccak256(abi.encodePacked(uint256 epoch, bytes32 root))` — the payload a
    /// data layer publishes; the root inside it is the part M1 verifies.
    #[must_use]
    pub fn digest(&self) -> [u8; 32] {
        let mut buf = [0_u8; 64];
        // `abi.encodePacked(uint256 epoch, ...)`: 32 bytes, value right-aligned.
        buf[24..32].copy_from_slice(&self.number.to_be_bytes());
        buf[32..].copy_from_slice(&self.root());
        keccak256(&buf)
    }

    /// The inclusion proof for leaf `index`, bottom-up, in `verifyEntry`'s order
    /// (each element is the sibling at that level; an odd node contributes none).
    #[must_use]
    pub fn inclusion_proof(&self, index: usize) -> Option<Vec<[u8; 32]>> {
        let mut level = self.leaves();
        if index >= level.len() {
            return None;
        }
        let mut proof = Vec::new();
        let mut i = index;
        while level.len() > 1 {
            let sibling = if i.is_multiple_of(2) {
                level.get(i + 1).copied() // promoted when odd: no sibling
            } else {
                level.get(i - 1).copied()
            };
            if let Some(s) = sibling {
                proof.push(s);
            }
            let mut next = Vec::with_capacity(level.len().div_ceil(2));
            for pair in level.chunks(2) {
                match pair {
                    [a, b] => next.push(pair_hash(a, b)),
                    [a] => next.push(*a),
                    _ => unreachable!("chunks(2) yields one or two elements"),
                }
            }
            level = next;
            i /= 2;
        }
        Some(proof)
    }

    /// The number of entries that differ from `previous`, counting a validator
    /// that appears or disappears as one change — the `changedEntries` the
    /// registry checks against `γ·N`.
    #[must_use]
    pub fn changed_entries(&self, previous: &Self) -> u32 {
        let map = |epoch: &Self| {
            epoch
                .entries
                .iter()
                .map(|e| (e.validator, e.norm_wad))
                .collect::<BTreeMap<_, _>>()
        };
        let (now, before) = (map(self), map(previous));
        let changed = now
            .iter()
            .filter(|&(&v, n)| before.get(&v) != Some(n))
            .count()
            + before.keys().filter(|&v| !now.contains_key(v)).count();
        u32::try_from(changed).expect("a tensor has 500 entries")
    }

    /// `commitEpoch`'s freshness rule: at most `γ·N` changed entries, or the
    /// genesis case where the first epoch changes *all* `N` entries.
    #[must_use]
    pub fn freshness_ok(&self, previous: &Self) -> bool {
        let changed = self.changed_entries(previous);
        if previous.entries.is_empty() {
            changed == TENSOR_SIZE
        } else {
            changed <= MAX_DELTA_ENTRIES
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The same `cast keccak` fixture `src/keccak.rs` is pinned by: the leaves,
    /// the pairs and the root below are what a Solidity client would compute for
    /// these four entries.
    const FIXTURE: &str = include_str!("../fixtures/keccak256_vectors.txt");

    /// `0x`-prefixed hex → bytes.
    fn decode(s: &str) -> Vec<u8> {
        let hex = s.strip_prefix("0x").expect("0x-prefixed hex");
        assert_eq!(hex.len() % 2, 0, "an even number of hex digits");
        (0..hex.len() / 2)
            .map(|i| u8::from_str_radix(&hex[2 * i..2 * i + 2], 16).expect("hex"))
            .collect()
    }

    /// One fixture value as bytes, comments stripped.
    fn field(key: &str) -> Vec<u8> {
        decode(
            FIXTURE
                .lines()
                .filter(|l| !l.trim_start().starts_with('#'))
                .find_map(|l| l.strip_prefix(&format!("{key} = ")))
                .unwrap_or_else(|| panic!("the fixture has no `{key}`"))
                .trim(),
        )
    }

    /// One fixture value as a 32-byte digest.
    fn digest32(key: &str) -> [u8; 32] {
        field(key).try_into().expect("a 32-byte digest")
    }

    /// The four entries the fixture pins: `0x11..11`, `0x22..22`, `0x33..33` and
    /// `0x44..44`, with norms 1, 0.5, 2 and 3 WAD.
    fn fixture_entries() -> Vec<Entry> {
        [
            (0x11_u8, 1_000_000_000_000_000_000_u128),
            (0x22, 500_000_000_000_000_000),
            (0x33, 2_000_000_000_000_000_000),
            (0x44, 3_000_000_000_000_000_000),
        ]
        .into_iter()
        .map(|(byte, norm_wad)| Entry {
            validator: [byte; 20],
            norm_wad,
        })
        .collect()
    }

    /// A full tensor: distinct addresses, `norm_wad = i`.
    fn tensor() -> Vec<Entry> {
        (0..TENSOR_SIZE)
            .map(|i| {
                let mut validator = [0_u8; 20];
                validator[4..].copy_from_slice(&u128::from(i + 1).to_be_bytes());
                Entry {
                    validator,
                    norm_wad: u128::from(i),
                }
            })
            .collect()
    }

    /// The same tensor with the first `changed` norms perturbed.
    fn tensor_with(changed: u32) -> Vec<Entry> {
        tensor()
            .into_iter()
            .enumerate()
            .map(|(i, mut entry)| {
                if i < changed as usize {
                    entry.norm_wad += 1_000_000;
                }
                entry
            })
            .collect()
    }

    #[test]
    fn payload_is_abi_encode_packed() {
        let entry = Entry {
            validator: [0x11; 20],
            norm_wad: 1_000_000_000_000_000_000,
        };
        assert_eq!(entry.payload().to_vec(), field("payload 1"));
        assert_eq!(
            entry.payload().len(),
            52,
            "20 bytes address, 32 bytes uint256"
        );
        assert_eq!(&entry.payload()[..20], &[0x11_u8; 20]);
        assert!(
            entry.payload()[20..36].iter().all(|&b| b == 0),
            "the WAD value is right-aligned in its 32-byte word"
        );
        assert_eq!(
            entry.payload()[36..].to_vec(),
            1_000_000_000_000_000_000_u128.to_be_bytes().to_vec()
        );
    }

    #[test]
    fn leaves_pairs_and_root_match_cast_keccak() {
        let epoch = Epoch::new(7, fixture_entries());
        let leaves = epoch.leaves();
        for (i, key) in ["leaf 1", "leaf 2", "leaf 3", "leaf 4"].iter().enumerate() {
            assert_eq!(leaves[i], digest32(key), "{key}");
        }
        assert_eq!(pair_hash(&leaves[0], &leaves[1]), digest32("pair 1"));
        assert_eq!(pair_hash(&leaves[2], &leaves[3]), digest32("pair 2"));
        assert_eq!(epoch.root(), digest32("root(4)"));
        assert_eq!(
            merkle_root(&leaves),
            digest32("root(4)"),
            "the free function and the epoch agree"
        );
    }

    #[test]
    fn every_entry_verifies_and_odd_levels_are_handled() {
        for entries in [
            fixture_entries(),
            tensor()[..3].to_vec(),
            tensor()[..8].to_vec(),
            tensor(),
        ] {
            let epoch = Epoch::new(7, entries);
            let root = epoch.root();
            for (i, entry) in epoch.entries.iter().enumerate() {
                let proof = epoch.inclusion_proof(i).expect("an index inside the epoch");
                assert!(verify_entry(&root, &entry.payload(), &proof), "entry {i}");
            }
            assert!(
                epoch.inclusion_proof(epoch.entries.len()).is_none(),
                "the first index outside the epoch is not provable"
            );
        }
    }

    #[test]
    fn tampered_payloads_and_roots_are_rejected() {
        let epoch = Epoch::new(7, fixture_entries());
        let root = epoch.root();
        let payload = epoch.entries[2].payload();
        let proof = epoch
            .inclusion_proof(2)
            .expect("index 2 is inside the epoch");
        assert!(verify_entry(&root, &payload, &proof));

        let mut flipped = payload;
        flipped[51] ^= 1;
        assert!(
            !verify_entry(&root, &flipped, &proof),
            "one bit of the norm"
        );
        let mut moved = payload;
        moved[0] ^= 0x80;
        assert!(
            !verify_entry(&root, &moved, &proof),
            "one bit of the address"
        );

        assert!(
            !verify_entry(&root, &payload, &[]),
            "a proof missing a level"
        );
        let mut longer = proof.clone();
        longer.push([0_u8; 32]);
        assert!(!verify_entry(&root, &payload, &longer), "a bogus sibling");
        assert!(
            !verify_entry(&keccak256(b"another epoch"), &payload, &proof),
            "the wrong root"
        );
        assert!(
            !verify_entry(&[0_u8; 32], &payload, &proof),
            "the zero root"
        );
    }

    #[test]
    fn digest_is_keccak_of_the_epoch_number_and_root() {
        let epoch = Epoch::new(7, fixture_entries());
        let mut buf = [0_u8; 64];
        buf[24..32].copy_from_slice(&7_u64.to_be_bytes());
        buf[32..].copy_from_slice(&epoch.root());
        assert_eq!(epoch.digest(), keccak256(&buf));

        let other = Epoch::new(8, fixture_entries());
        assert_eq!(other.root(), epoch.root(), "the entries are the same");
        assert_ne!(other.digest(), epoch.digest(), "the epoch number is not");
        assert_ne!(epoch.digest(), [0_u8; 32]);
    }

    #[test]
    fn changed_entries_counts_appearances_and_disappearances() {
        let base = Epoch::new(7, tensor());
        assert_eq!(base.changed_entries(&base), 0, "an epoch against itself");
        assert_eq!(
            base.changed_entries(&Epoch::new(0, Vec::new())),
            TENSOR_SIZE,
            "every entry is new against the empty tensor"
        );
        assert_eq!(Epoch::new(8, tensor_with(50)).changed_entries(&base), 50);

        // one validator disappears: newcomers and departures both count, once
        let mut shrunk = tensor();
        let _ = shrunk.remove(0);
        assert_eq!(Epoch::new(8, shrunk).changed_entries(&base), 1);
    }

    #[test]
    fn freshness_is_gamma_n_and_treats_genesis_specially() {
        let base = Epoch::new(7, tensor());
        assert_eq!(MAX_DELTA_ENTRIES, 50, "gamma*N = N/10 of 500");
        assert!(Epoch::new(8, tensor_with(MAX_DELTA_ENTRIES)).freshness_ok(&base));
        assert!(!Epoch::new(8, tensor_with(MAX_DELTA_ENTRIES + 1)).freshness_ok(&base));

        // genesis: the whole tensor must appear at once, no more and no less
        let genesis = Epoch::new(0, Vec::new());
        assert!(Epoch::new(1, tensor()).freshness_ok(&genesis));
        assert!(
            !Epoch::new(1, tensor()[..TENSOR_SIZE as usize - 1].to_vec()).freshness_ok(&genesis)
        );
        assert!(!Epoch::new(1, tensor()[..1].to_vec()).freshness_ok(&genesis));
    }
}
