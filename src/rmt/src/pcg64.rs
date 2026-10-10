//! The sealed calibration's random stream, resumed bit for bit (plan §5.6).
//!
//! `verification/rmt/` is sealed: M5 may not edit it. Its quantiles are Monte
//! Carlo estimates, so "reproduces `q99 = 9.0542`" can only mean resuming the
//! *same* stream — sampling the same ensemble with a different generator would
//! give a value that merely agrees within its own sampling error. Every graph in
//! `calibration_modularity.py`, `bipartite_power.py` and `clique_spectra.py`
//! comes from the same two calls:
//!
//! ```text
//! rng = np.random.default_rng(42)
//! A   = (rng.random((n, n)) < p)     # n² uniform doubles, row-major, all consumed
//! ```
//!
//! so M5 implements numpy's `PCG64` (O'Neill 2014, XSL-RR 128/64) exactly, and
//! the sealed stream is *seekable*: [`Pcg64::advance`] is the LCG jump-ahead, so
//! chunk `c` of a parallel run starts at the state the sequential script would
//! have reached. That keeps the reproduction deterministic under any thread
//! count — the pinned file cannot depend on the machine (the M4a discipline).
//!
//! | element | value | source |
//! |---|---|---|
//! | output function | `(hi ^ lo).rotate_right((hi >> 58) & 63)` | XSL-RR, numpy `pcg64.h` |
//! | state step | `state ← state·MULT + inc` | PCG LCG, numpy `pcg64.h` |
//! | `MULT` | `0x2360ed051fc65da44385df649fccf645` | `PCG_DEFAULT_MULTIPLIER_128` |
//! | double | `(u64 >> 11) · 2⁻⁵³` | numpy `distributions.c`, `next_double` |
//! | seed `state`/`inc` | [`NUMPY42_STATE`], [`NUMPY42_INC`] | `default_rng(42).bit_generator.state` |
//! | increment applied **before** the first output | the seed state is pre-advance | measured: `random_raw(6)` vs this module, pinned in `fixtures/numpy_pcg64_seed42.txt` |
//!
//! The stream is documented as stable across numpy versions, which is why
//! resuming it from the seed is a durable bridge to the sealed files rather than
//! a snapshot of one machine.

/// `numpy.random.default_rng(42)`: the PCG64 state `SeedSequence(42)` produces,
/// as reported *before* the first draw.
pub const NUMPY42_STATE: u128 = 274_674_114_334_540_486_603_088_602_300_644_985_544;

/// The matching increment (odd, so the LCG has full period).
pub const NUMPY42_INC: u128 = 332_724_090_758_049_132_448_979_897_138_935_081_983;

/// `PCG_DEFAULT_MULTIPLIER_128`.
pub const MULTIPLIER: u128 = 0x2360_ed05_1fc6_5da4_4385_df64_9fcc_f645;

/// numpy's `next_double` scale: `2⁻⁵³`.
const TWO_POW_M53: f64 = 1.0 / 9_007_199_254_740_992.0;

/// numpy's `PCG64`, with the state and increment the sealed scripts start from.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Pcg64 {
    state: u128,
    inc: u128,
}

impl Default for Pcg64 {
    fn default() -> Self {
        Self::seeded()
    }
}

impl Pcg64 {
    /// `np.random.default_rng(42)`, at the position of its first draw.
    #[must_use]
    pub fn seeded() -> Self {
        Self {
            state: NUMPY42_STATE,
            inc: NUMPY42_INC,
        }
    }

    /// A generator with an explicit state. `inc` is forced odd: an even
    /// increment breaks the LCG period (numpy `pcg64.h`).
    #[must_use]
    pub fn from_state(state: u128, inc: u128) -> Self {
        Self {
            state,
            inc: inc | 1,
        }
    }

    /// The raw 128-bit state, for a stream-position assertion.
    #[must_use]
    pub fn state(&self) -> u128 {
        self.state
    }

    /// One raw 64-bit output: advance, then emit (numpy's order).
    pub fn next_u64(&mut self) -> u64 {
        self.state = self.state.wrapping_mul(MULTIPLIER).wrapping_add(self.inc);
        xsl_rr(self.state)
    }

    /// numpy's `next_double`: the top 53 bits of one raw output, scaled by `2⁻⁵³`.
    pub fn next_double(&mut self) -> f64 {
        (self.next_u64() >> 11) as f64 * TWO_POW_M53
    }

    /// Fill a slice as `rng.random(size)`: one `next_double` per element, in order.
    pub fn fill(&mut self, out: &mut [f64]) {
        for x in out {
            *x = self.next_double();
        }
    }
}

impl Pcg64 {
    /// A generator seeded from 32 fixed bytes, e.g. a keccak digest.
    ///
    /// This is the only seeding M5 adds to the sealed one, and it is *not* a
    /// numpy stream: it exists so the detector can be wired to a committed
    /// artefact (the M4 fixture digest, plan §5.6) without depending on the
    /// `src/zk` crate. The two halves of the digest become `state`/`inc`.
    #[must_use]
    pub fn from_seed_bytes(bytes: &[u8; 32]) -> Self {
        let mut hi = [0u8; 16];
        let mut lo = [0u8; 16];
        hi.copy_from_slice(&bytes[..16]);
        lo.copy_from_slice(&bytes[16..]);
        Self::from_state(u128::from_le_bytes(hi), u128::from_le_bytes(lo))
    }

    /// Consume `delta` raw outputs in `O(log delta)`: the PCG LCG jump-ahead
    /// (`pcg_advance_lcg_128`), i.e.
    /// `state ← state·MULT^delta + inc·(MULT^delta − 1)/(MULT − 1)`.
    ///
    /// Used to start a parallel chunk at the position the sequential script would
    /// have reached, so the pinned output does not depend on the thread count.
    pub fn advance(&mut self, delta: u128) {
        let mut acc_mult: u128 = 1;
        let mut acc_plus: u128 = 0;
        let mut cur_mult = MULTIPLIER;
        let mut cur_plus = self.inc;
        let mut delta = delta;
        while delta > 0 {
            if delta & 1 == 1 {
                acc_mult = acc_mult.wrapping_mul(cur_mult);
                acc_plus = acc_plus.wrapping_mul(cur_mult).wrapping_add(cur_plus);
            }
            cur_plus = cur_mult.wrapping_add(1).wrapping_mul(cur_plus);
            cur_mult = cur_mult.wrapping_mul(cur_mult);
            delta >>= 1;
        }
        self.state = acc_mult.wrapping_mul(self.state).wrapping_add(acc_plus);
    }
}

/// numpy's `pcg_output_xsl_rr`: `rotr64(hi ^ lo, top 6 bits of hi)`.
#[inline]
#[must_use]
fn xsl_rr(state: u128) -> u64 {
    let hi = (state >> 64) as u64;
    let lo = state as u64;
    let rot = ((state >> 122) & 63) as u32;
    (hi ^ lo).rotate_right(rot)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The fixture's reference values, parsed from the committed file.
    fn fixture() -> Vec<String> {
        let path = concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/fixtures/numpy_pcg64_seed42.txt"
        );
        std::fs::read_to_string(path)
            .expect("fixtures/numpy_pcg64_seed42.txt is committed")
            .lines()
            .filter(|l| !l.trim_start().starts_with('#') && !l.trim().is_empty())
            .map(str::to_owned)
            .collect()
    }

    fn field<'a>(lines: &'a [String], key: &str) -> &'a str {
        lines
            .iter()
            .find_map(|l| l.strip_prefix(&format!("{key} =")))
            .unwrap_or_else(|| panic!("fixture has no `{key}`"))
            .trim()
    }

    #[test]
    fn stream_matches_numpy_raw_u64() {
        let lines = fixture();
        let expected: Vec<u64> = field(&lines, "raw(6)")
            .split_whitespace()
            .map(|t| t.parse().expect("u64"))
            .collect();
        let mut rng = Pcg64::seeded();
        let got: Vec<u64> = (0..expected.len()).map(|_| rng.next_u64()).collect();
        assert_eq!(got, expected, "PCG64 raw stream diverges from numpy");
    }

    #[test]
    fn stream_matches_numpy_double_bits() {
        let lines = fixture();
        let expected: Vec<u64> = field(&lines, "double bits(4)")
            .split_whitespace()
            .map(|t| t.parse().expect("u64"))
            .collect();
        let mut rng = Pcg64::seeded();
        let got: Vec<u64> = (0..expected.len())
            .map(|_| rng.next_double().to_bits())
            .collect();
        assert_eq!(got, expected, "numpy's double conversion diverges");
    }

    #[test]
    fn lcg_advance_matches_six_single_steps() {
        let lines = fixture();
        let after6: u128 = field(&lines, "state after raw(6)").parse().expect("u128");
        let mut rng = Pcg64::seeded();
        for _ in 0..6 {
            rng.next_u64();
        }
        assert_eq!(rng.state(), after6);
        let mut jumped = Pcg64::seeded();
        jumped.advance(6);
        assert_eq!(jumped.state(), after6, "jump-ahead must equal six steps");
    }

    #[test]
    fn advance_is_seekable_at_large_offsets() {
        let mut one = Pcg64::seeded();
        one.advance(1_000);
        let mut many = Pcg64::seeded();
        many.advance(600);
        many.advance(400);
        assert_eq!(one, many);
        assert_eq!(one.next_u64(), many.next_u64());
    }

    #[test]
    fn increments_are_forced_odd() {
        assert_eq!(Pcg64::from_state(1, 2).state(), 1);
        assert_eq!(
            Pcg64::from_seed_bytes(&[0u8; 32]).state(),
            Pcg64::from_state(0, 0).state()
        );
    }
}
