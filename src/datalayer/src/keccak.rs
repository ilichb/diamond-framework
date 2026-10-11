//! Keccak-256, with the padding the EVM uses.
//!
//! The epoch commitment of [`crate::commitment`] has to hash exactly the way
//! `AVIPRegistry` does, because the whole point of that module is that the root
//! M6 produces is verifiable by the deployed contract's `verifyInclusion`
//! **unchanged**. A crypto library would work, but it would be a second
//! implementation with its own padding decision (and it would put a registry
//! dependency in a crate that builds `--offline`); the permutation is 60 lines
//! and `fixtures/keccak256_vectors.txt` pins it against `cast keccak`, i.e.
//! against the EVM's own precompile.
//!
//! Two details that are easy to get wrong and are therefore stated:
//!
//! - **Keccak, not SHA3.** Ethereum's `keccak256` pads with the domain byte
//!   `0x01`; NIST's SHA3-256 pads with `0x06`. `keccak256("")` is
//!   `c5d24601...`, SHA3-256 of the empty string is `a7ffc6f8...`.
//! - **Little-endian lanes.** The rate is 136 bytes (1088 bits) read as 17
//!   little-endian `u64` lanes, and the digest is the first 32 bytes of the state
//!   read the same way. `136 = 17·8` exactly, so the padding byte can never straddle
//!   an `u64` boundary — the one case the code below has to handle explicitly is
//!   the last byte of the block, where `0x01` and `0x80` combine into `0x81`.

/// Keccak-f[1600] round constants (24 rounds).
const ROUND_CONSTANTS: [u64; 24] = [
    0x0000_0000_0000_0001,
    0x0000_0000_0000_8082,
    0x8000_0000_0000_808a,
    0x8000_0000_8000_8000,
    0x0000_0000_0000_808b,
    0x0000_0000_8000_0001,
    0x8000_0000_8000_8081,
    0x8000_0000_0000_8009,
    0x0000_0000_0000_008a,
    0x0000_0000_0000_0088,
    0x0000_0000_8000_8009,
    0x0000_0000_8000_000a,
    0x0000_0000_8000_808b,
    0x8000_0000_0000_008b,
    0x8000_0000_0000_8089,
    0x8000_0000_0000_8003,
    0x8000_0000_0000_8002,
    0x8000_0000_0000_0080,
    0x0000_0000_0000_800a,
    0x8000_0000_8000_000a,
    0x8000_0000_8000_8081,
    0x8000_0000_0000_8080,
    0x0000_0000_8000_0001,
    0x8000_0000_8000_8008,
];

/// ρ rotation offsets, indexed `x + 5y` like the state.
const RHO: [u32; 25] = [
    0, 1, 62, 28, 27, //
    36, 44, 6, 55, 20, //
    3, 10, 43, 25, 39, //
    41, 45, 15, 21, 8, //
    18, 2, 61, 56, 14,
];

/// Keccak-256's rate in bytes: `(1600 − 2·256)/8`.
pub const RATE: usize = 136;

/// `keccak256(data)`, Ethereum's hash.
#[must_use]
pub fn keccak256(data: &[u8]) -> [u8; 32] {
    let mut state = [0_u64; 25];
    let mut blocks = data.chunks_exact(RATE);
    for block in &mut blocks {
        absorb(&mut state, block);
    }
    let mut last = [0_u8; RATE];
    let rem = blocks.remainder();
    last[..rem.len()].copy_from_slice(rem);
    // pad10*1 with the Keccak domain byte: 0x01 ... 0x80. For a 135-byte
    // remainder both land on byte 135 and combine into 0x81.
    last[rem.len()] ^= 0x01;
    last[RATE - 1] ^= 0x80;
    absorb(&mut state, &last);

    let mut digest = [0_u8; 32];
    for (i, lane) in state.iter().take(4).enumerate() {
        digest[i * 8..i * 8 + 8].copy_from_slice(&lane.to_le_bytes());
    }
    digest
}

/// Absorb one 136-byte block: XOR it into the state as 17 little-endian lanes,
/// then run the permutation.
fn absorb(state: &mut [u64; 25], block: &[u8]) {
    debug_assert_eq!(block.len(), RATE);
    for (i, chunk) in block.chunks_exact(8).enumerate() {
        let mut lane = [0_u8; 8];
        lane.copy_from_slice(chunk);
        state[i] ^= u64::from_le_bytes(lane);
    }
    permute(state);
}

/// Keccak-f[1600]: 24 rounds of θ, ρ+π, χ, ι.
fn permute(a: &mut [u64; 25]) {
    for rc in ROUND_CONSTANTS {
        // theta
        let mut c = [0_u64; 5];
        for x in 0..5 {
            c[x] = a[x] ^ a[x + 5] ^ a[x + 10] ^ a[x + 15] ^ a[x + 20];
        }
        let mut d = [0_u64; 5];
        for x in 0..5 {
            d[x] = c[(x + 4) % 5] ^ c[(x + 1) % 5].rotate_left(1);
        }
        for x in 0..5 {
            for y in 0..5 {
                a[x + 5 * y] ^= d[x];
            }
        }
        // rho + pi: B[y + 5·((2x + 3y) mod 5)] = rotl(A[x + 5y])
        let mut b = [0_u64; 25];
        for x in 0..5 {
            for y in 0..5 {
                b[y + 5 * ((2 * x + 3 * y) % 5)] = a[x + 5 * y].rotate_left(RHO[x + 5 * y]);
            }
        }
        // chi
        for y in 0..5 {
            for x in 0..5 {
                a[x + 5 * y] = b[x + 5 * y] ^ (!b[(x + 1) % 5 + 5 * y] & b[(x + 2) % 5 + 5 * y]);
            }
        }
        // iota
        a[0] ^= rc;
    }
}

/// `0x`-prefixed lowercase hex, the form `cast keccak` prints.
#[must_use]
pub fn to_hex(bytes: &[u8]) -> String {
    use std::fmt::Write as _;
    let mut s = String::with_capacity(2 + bytes.len() * 2);
    s.push_str("0x");
    for b in bytes {
        write!(s, "{b:02x}").expect("writing to a String cannot fail");
    }
    s
}

#[cfg(test)]
mod tests {
    use super::*;

    /// `cast keccak` output — the EVM precompile the deployed `AVIPRegistry`
    /// calls, not a library's idea of Keccak.
    const FIXTURE: &str = include_str!("../fixtures/keccak256_vectors.txt");

    /// `0x`-prefixed hex → bytes.
    fn decode(s: &str) -> Vec<u8> {
        let hex = s.strip_prefix("0x").expect("0x-prefixed hex");
        assert_eq!(hex.len() % 2, 0, "an even number of hex digits");
        (0..hex.len() / 2)
            .map(|i| u8::from_str_radix(&hex[2 * i..2 * i + 2], 16).expect("hex"))
            .collect()
    }

    /// One fixture value, comments stripped.
    fn field(key: &str) -> String {
        FIXTURE
            .lines()
            .filter(|l| !l.trim_start().starts_with('#'))
            .find_map(|l| l.strip_prefix(&format!("{key} = ")))
            .unwrap_or_else(|| panic!("the fixture has no `{key}`"))
            .trim()
            .to_string()
    }

    /// The digest the fixture pins for one named vector.
    fn fixture_digest(name: &str) -> Vec<u8> {
        decode(&field(&format!("digest {name}")))
    }

    /// The names of the pinned vectors, in file order.
    fn vector_names() -> Vec<String> {
        FIXTURE
            .lines()
            .filter_map(|l| l.strip_prefix("vector "))
            .filter_map(|l| l.split_once(" = "))
            .map(|(name, _)| name.to_string())
            .collect()
    }

    #[test]
    fn digests_match_cast_keccak() {
        let names = vector_names();
        assert_eq!(names.len(), 4, "the fixture pins four vectors");
        for name in names {
            let input = decode(&field(&format!("vector {name}")));
            assert_eq!(keccak256(&input).to_vec(), fixture_digest(&name), "{name}");
        }
    }

    #[test]
    fn the_domain_byte_is_keccak_s_and_not_sha3_s() {
        assert_eq!(to_hex(&keccak256(b"")), to_hex(&fixture_digest("empty")));
        assert!(to_hex(&keccak256(b"")).starts_with("0xc5d24601"));
        // SHA3-256 pads with 0x06 and hashes the empty string to this instead.
        assert_ne!(
            to_hex(&keccak256(b"")),
            "0xa7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a"
        );
    }

    #[test]
    fn the_rate_boundary_is_padded_once() {
        // At 135 zeros the domain byte 0x01 and the final 0x80 meet in byte 135
        // and combine into 0x81 — the one case that needs handling explicitly.
        let zeros_135 = vec![0_u8; RATE - 1];
        let zeros_136 = vec![0_u8; RATE];
        assert_eq!(
            keccak256(&zeros_135).to_vec(),
            fixture_digest("135 zero bytes")
        );
        assert_eq!(
            keccak256(&zeros_136).to_vec(),
            fixture_digest("136 zero bytes")
        );
        assert_ne!(keccak256(&zeros_135), keccak256(&zeros_136));
    }

    #[test]
    fn to_hex_is_lowercase_and_prefixed() {
        assert_eq!(to_hex(&[]), "0x");
        assert_eq!(to_hex(&[0x00, 0xab, 0xff]), "0x00abff");
    }
}
