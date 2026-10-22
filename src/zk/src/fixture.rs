//! The deterministic M4a fixture (plan §5.5.6).
//!
//! One fixed 500-entry tensor from a fixed seed, byte identical across runs —
//! the off-chain analogue of `scripts/generate_groth16_fixtures.py` (§5.4). The
//! `[0, WAD)` entry range and the `k = 60` width are the ones §5.5.3 derives,
//! so a measurement taken here exercises the same arithmetic the plan claims.

use rand_chacha::ChaCha8Rng;
use rand_core::{RngCore, SeedableRng};
use sha3::{Digest, Keccak256};

/// Number of tensor entries: `C·D·H = 500` (`main.tex` `eq:tensor`).
pub const N: usize = 500;
/// Bits per entry, `k` (plan §5.5.3): `2^60 = 1.1529215e18 > 1e18 = WAD`.
pub const ENTRY_BITS: usize = 60;
/// WAD convention: `1.0 = 1e18` (M3 fixture statement `[root, epoch, 5e17]`).
pub const WAD: u64 = 1_000_000_000_000_000_000;
/// The frozen seed. Changing it moves every measured number, so it is a constant
/// here and the fixture digest is asserted in this module's tests.
pub const SEED: u64 = 0x4D34_4156_4950_0001; // "M4AVIP" + 0x0001

/// Domain separator for the deterministic validator addresses. There is no
/// private key behind these addresses: they exist so the fixture has N distinct
/// leaves, which is what the admission statement commits to.
pub const VALIDATOR_DOMAIN: &[u8] = b"AVIP-M4d-validator";
/// The entry the committed Solidity fixture proves. It is the first fixture
/// entry whose norm reaches the manager's threshold (`Theta_r = 0.5e18`), so the
/// on-chain admission test is not rejected before the proof is checked. It is
/// deliberately not the first leaf: the fixture binds the *validator*, not a
/// position, and the path is private.
pub const ADMISSION_INDEX: usize = 4;
/// The epoch the committed fixture proves.
pub const ADMISSION_EPOCH: u64 = 0;

/// The fixture: `N` WAD entries, each in `[0, WAD)`.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Tensor {
    entries: Vec<u64>,
}

impl Tensor {
    /// The entries, in order.
    pub fn entries(&self) -> &[u64] {
        &self.entries
    }

    /// `Σ T_i²`, in `WAD²`.
    ///
    /// Precondition: the sum fits in `u128`, which this fixture satisfies
    /// (`2^128 ≈ 3.40e38`; the frozen tensor sums to ≈`1.7e38`). The plan's
    /// *worst* case, `N·1e36 = 5e38` (129 bits), does not fit `u128` — that one
    /// is only meaningful in `Fr_BN254`, which is where [`crate::native`] does
    /// it.
    pub fn sum_of_squares(&self) -> u128 {
        self.entries
            .iter()
            .map(|e| {
                let e = *e as u128;
                e.checked_mul(e).expect("entry² fits in u128")
            })
            .fold(0u128, |acc, sq| {
                acc.checked_add(sq).expect("fixture sum fits in u128")
            })
    }

    /// Largest entry.
    pub fn max_entry(&self) -> u64 {
        self.entries.iter().copied().max().unwrap_or(0)
    }

    /// `⌊√(Σ T_i²)⌋`, in WAD: the value the circuit certifies as an equality
    /// (§5.5.1 — the relation is `‖T‖_F = certifiedNorm`, not a bit).
    pub fn wad_norm(&self) -> u128 {
        isqrt(self.sum_of_squares())
    }

    /// Keccak-256 over the entries as 8-byte little-endian words. This is the
    /// byte-identical anchor: two runs, two machines, one digest.
    pub fn digest(&self) -> [u8; 32] {
        let mut hasher = Keccak256::new();
        for e in &self.entries {
            hasher.update(e.to_le_bytes());
        }
        hasher.finalize().into()
    }

    /// [`Tensor::digest`] in lowercase hex.
    pub fn digest_hex(&self) -> String {
        let mut s = String::with_capacity(64);
        for b in self.digest() {
            s.push_str(&format!("{b:02x}"));
        }
        s
    }
}

/// The committed fixture (plan §5.5.6).
pub fn tensor() -> Tensor {
    tensor_from_seed(SEED)
}

/// A fixture from an explicit seed. `tensor()` is `tensor_from_seed(SEED)`; the
/// seeded form exists so tests can show that the digest tracks the seed.
pub fn tensor_from_seed(seed: u64) -> Tensor {
    let mut rng = ChaCha8Rng::seed_from_u64(seed);
    let entries = (0..N).map(|_| next_below(&mut rng, WAD)).collect();
    Tensor { entries }
}

/// The `N` deterministic validator addresses paired with [`tensor`]'s entries.
///
/// `keccak256(VALIDATOR_DOMAIN ‖ u32_le(i))`, last 20 bytes. They are labels,
/// not keys; their only job is to make every leaf distinct and reproducible.
#[must_use]
pub fn validators() -> Vec<[u8; 20]> {
    (0..N)
        .map(|i| {
            let mut hasher = Keccak256::new();
            hasher.update(VALIDATOR_DOMAIN);
            hasher.update((i as u32).to_le_bytes());
            let digest: [u8; 32] = hasher.finalize().into();
            let mut address = [0_u8; 20];
            address.copy_from_slice(&digest[12..]);
            // The chance of a zero address is 2^-160, but the contract rejects
            // it; make the fixture total rather than astronomically lucky.
            if address == [0_u8; 20] {
                address[19] = 1;
            }
            address
        })
        .collect()
}

/// Unbiased draw in `[0, bound)`: rejection over the largest multiple of
/// `bound` that fits in a `u64`. Written out instead of pulling `rand` in, so
/// the fixture's only RNG dependency is the pinned `rand_chacha`.
fn next_below(rng: &mut impl RngCore, bound: u64) -> u64 {
    assert!(bound > 1, "bound must be > 1");
    let zone = (u64::MAX / bound) * bound;
    loop {
        let x = rng.next_u64();
        if x < zone {
            return x % bound;
        }
    }
}

/// `⌊√n⌋` by Newton's method: no float rounding at 38-digit scale.
pub fn isqrt(n: u128) -> u128 {
    if n < 2 {
        return n;
    }

    let bits = 128 - n.leading_zeros();
    let mut x = 1u128 << bits.div_ceil(2);
    loop {
        let y = (x + n / x) / 2;
        if y >= x {
            return x;
        }
        x = y;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The plan's own arithmetic at `N = 500`, `k = 60`, checked against the
    /// frozen tensor instead of asserted in prose.
    #[test]
    fn fixture_respects_the_derived_entry_width() {
        let t = tensor();
        assert_eq!(t.entries().len(), N);
        assert!(
            t.max_entry() < (1u64 << ENTRY_BITS),
            "entry exceeds 2^{ENTRY_BITS}: {}",
            t.max_entry()
        );
        assert!(t.max_entry() < WAD);
        // Σ T_i² must land inside `Fr_BN254` without wrapping (§5.5.3). The
        // margin is checked in `native`, where the sum is taken in the field;
        // here we only require that the u128 report is meaningful.
        assert!(t.sum_of_squares() < u128::MAX);
        assert!(t.wad_norm() > 0);
    }

    #[test]
    fn fixture_is_byte_identical_across_runs() {
        // Independently constructed instances of the same fixture.
        assert_eq!(tensor().digest(), tensor().digest());
        assert_eq!(tensor().digest_hex(), tensor().digest_hex());
    }

    /// The digest is *frozen*: if this fails, a measurement moved and the M4a
    /// note is stale.
    #[test]
    fn fixture_digest_is_pinned() {
        let expected = include_str!("../fixtures/tensor_digest.txt")
            .trim()
            .to_string();
        assert_eq!(
            tensor().digest_hex(),
            expected,
            "fixture digest moved; regenerate fixtures/tensor_digest.txt"
        );
    }

    #[test]
    fn a_different_seed_gives_a_different_fixture() {
        assert_ne!(
            tensor_from_seed(SEED).digest(),
            tensor_from_seed(SEED ^ 0xFF).digest()
        );
    }

    #[test]
    fn isqrt_is_the_integer_square_root() {
        for n in [0u128, 1, 2, 3, 4, 8, 9, 10, 30, 1_000_000, u64::MAX as u128] {
            let r = isqrt(n);
            assert!(r * r <= n, "isqrt({n}) = {r} too large");
            assert!(
                r.checked_add(1)
                    .and_then(|rp1| rp1.checked_mul(rp1))
                    .is_none_or(|x| x > n)
            );
        }
    }
}
