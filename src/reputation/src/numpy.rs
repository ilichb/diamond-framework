//! Which numpy draws M6 can resume, and which are documented substitutes.
//!
//! The sealed `sim_positivity.py` makes four kinds of draw through
//! `np.random.default_rng(42)`. Two of them M6 follows exactly, because numpy
//! builds them out of `next_double` alone — the function [`crate::pcg64`] already
//! resumes bit for bit. The other two numpy serves from a 257-entry **ziggurat**
//! table (`wi_double`/`fi_double`/`ki_double` for the normal,
//! `we_double`/`fe_double`/`ke_double` for the exponential) that is compiled into
//! numpy's C extension: it is not in this repository, there is no numpy source
//! tree on this machine, and there is no network. Copying roughly 1500 constants
//! out of a binary would be a table dump with unverifiable provenance, so M6
//! declines it and states the substitute instead of pretending to exactness.
//!
//! | sealed call | numpy's algorithm | M6 |
//! |---|---|---|
//! | `rng.uniform(0.5, 1.0, size)` | `low + (high−low)·next_double` | **exact** (same function) |
//! | `rng.poisson(λ·dt, size)`, `λ·dt = 8e-4 < 10` | Knuth's product test (`random_poisson_mult`) | **exact**, tested in isolation against the fixture |
//! | `rng.normal(0, √dt, size)` | ziggurat (Marsaglia–Tsang), table-driven | **substitute**: Box–Muller from the same stream |
//! | `rng.exponential(0.15, size)` | ziggurat, table-driven | **substitute**: inverse CDF `−scale·ln(u)` |
//!
//! Because `normal` consumes a different number of raw draws than numpy's ziggurat
//! does, the *interleaved* stream of that script cannot be resumed at all: the
//! exactness of `poisson` is a property of the draw, not of the run. That is what
//! [`crate::cir`]'s reproduction reports — the mode and the sampling error, never
//! a false claim of bit-for-bit equality.

use crate::pcg64::Pcg64;

/// The draws M6 resumes bit for bit.
pub const EXACT: &[&str] = &["uniform (next_double)", "poisson (lambda*dt < 10, Knuth)"];

/// The draws M6 substitutes, with the substituted algorithm.
pub const SUBSTITUTED: &[&str] = &[
    "normal (numpy: ziggurat table; here: Box-Muller)",
    "exponential (numpy: ziggurat table; here: inverse CDF)",
];

/// numpy's `Generator`, as far as M6 can follow it, over one [`Pcg64`] stream.
#[derive(Clone, Debug)]
pub struct Distributions {
    rng: Pcg64,
    /// Box–Muller's second variate (numpy caches nothing; the substitute does).
    spare: Option<f64>,
}

impl Default for Distributions {
    fn default() -> Self {
        Self::seeded()
    }
}

impl Distributions {
    /// A generator at `np.random.default_rng(42)`'s first draw.
    #[must_use]
    pub fn seeded() -> Self {
        Self {
            rng: Pcg64::seeded(),
            spare: None,
        }
    }

    /// The underlying stream, for stream-position assertions.
    #[must_use]
    pub fn rng(&self) -> &Pcg64 {
        &self.rng
    }

    /// `rng.uniform(low, high)`: exact — numpy's expression, in numpy's order.
    pub fn uniform(&mut self, low: f64, high: f64) -> f64 {
        low + (high - low) * self.rng.next_double()
    }

    /// `rng.uniform(low, high, size)`, element by element.
    pub fn fill_uniform(&mut self, out: &mut [f64], low: f64, high: f64) {
        for x in out {
            *x = self.uniform(low, high);
        }
    }

    /// `rng.normal(0, 1)`, by Box–Muller (a substitute, see the module docs).
    pub fn standard_normal(&mut self) -> f64 {
        if let Some(z) = self.spare.take() {
            return z;
        }
        let u1 = 1.0 - self.rng.next_double(); // (0, 1], so ln is finite
        let u2 = self.rng.next_double();
        let (sin, cos) = (std::f64::consts::TAU * u2).sin_cos();
        let r = (-2.0 * u1.ln()).sqrt();
        self.spare = Some(r * sin);
        r * cos
    }

    /// `rng.normal(loc, scale, size)`, element by element.
    pub fn fill_normal(&mut self, out: &mut [f64], loc: f64, scale: f64) {
        for x in out {
            *x = loc + scale * self.standard_normal();
        }
    }

    /// `rng.exponential(scale)`, by inverse CDF (a substitute).
    pub fn exponential(&mut self, scale: f64) -> f64 {
        scale * -((1.0 - self.rng.next_double()).ln())
    }

    /// `rng.exponential(scale, size)`, element by element.
    pub fn fill_exponential(&mut self, out: &mut [f64], scale: f64) {
        for x in out {
            *x = self.exponential(scale);
        }
    }

    /// `rng.poisson(lam)` for `lam < 10`: numpy's `random_poisson_mult`, i.e.
    /// Knuth's product test, one `next_double` per trial.
    ///
    /// `lam >= 10` is refused rather than approximated: numpy switches to PTRS
    /// there, so continuing would be a silent divergence. The sealed script only
    /// ever calls this with `λ·dt = 8e-4`.
    pub fn poisson(&mut self, lam: f64) -> u64 {
        self.poisson_with_enlam(lam, (-lam).exp())
    }

    /// `rng.poisson(lam, size)`, element by element. Hoisting `exp(-lam)` out of
    /// the loop is exact — it is the same constant numpy recomputes per variate.
    pub fn fill_poisson(&mut self, out: &mut [u64], lam: f64) {
        assert!(
            lam < 10.0,
            "lam = {lam} >= 10: numpy uses PTRS there; M6 only resumes lambda*dt = 8e-4"
        );
        if lam == 0.0 {
            out.fill(0);
            return;
        }
        let enlam = (-lam).exp();
        for x in out {
            *x = self.poisson_with_enlam(lam, enlam);
        }
    }

    fn poisson_with_enlam(&mut self, lam: f64, enlam: f64) -> u64 {
        assert!(lam < 10.0, "lam = {lam} >= 10 is outside M6's range");
        if lam == 0.0 {
            return 0;
        }
        let mut prod = 1.0;
        let mut x = 0_u64;
        loop {
            prod *= self.rng.next_double();
            if prod > enlam {
                x += 1;
            } else {
                return x;
            }
        }
    }
}

/// The Box–Muller pair `normal` uses, exposed so `bin/m6-probe` can show *why* a
/// substitute cannot equal numpy's ziggurat draw from the same two doubles.
#[must_use]
pub fn box_muller_pair(u1: f64, u2: f64) -> (f64, f64) {
    let (sin, cos) = (std::f64::consts::TAU * u2).sin_cos();
    let r = (-2.0 * u1.ln()).sqrt();
    (r * cos, r * sin)
}

/// The inverse-CDF exponential of one uniform, same purpose as [`box_muller_pair`].
#[must_use]
pub fn inverse_cdf_exponential(scale: f64, u: f64) -> f64 {
    scale * -(1.0 - u).ln()
}

/// Which regime a reproduction runs in.
///
/// `Exact` means every draw the sealed script makes is resumed bit for bit;
/// `Statistical` means at least one draw is a declared substitute, so the
/// achievement is a claim about the *distribution* — checked within its sampling
/// error — and never about the sealed digits.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum DistributionMode {
    /// Every draw of the sealed script is resumed bit for bit.
    Exact,
    /// At least one draw is a substitute, so runs are compared statistically.
    Statistical,
}

impl DistributionMode {
    /// The word the report and `bin/m6-probe` print.
    #[must_use]
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Exact => "exact",
            Self::Statistical => "statistical",
        }
    }
}

/// The mode [`EXACT`] and [`SUBSTITUTED`] imply, computed rather than asserted:
/// a substitution added or removed moves this without anyone editing the prose.
#[must_use]
pub fn mode() -> DistributionMode {
    if SUBSTITUTED.is_empty() {
        DistributionMode::Exact
    } else {
        DistributionMode::Statistical
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// numpy's own output, read through `include_str!`: the fixture is generated
    /// by the command in its own header, so a failure here is a disagreement with
    /// numpy, never with M6's prose.
    const FIXTURE: &str = include_str!("../fixtures/numpy_distributions_seed42.txt");

    /// The value of one fixture key, comments stripped.
    fn field(key: &str) -> &'static str {
        FIXTURE
            .lines()
            .filter(|l| !l.trim_start().starts_with('#'))
            .find_map(|l| l.strip_prefix(&format!("{key} = ")))
            .unwrap_or_else(|| panic!("the fixture has no `{key}`"))
            .trim()
    }

    /// A whitespace-separated list of integers.
    fn ints(key: &str) -> Vec<u64> {
        field(key)
            .split_whitespace()
            .map(|t| t.parse().expect("a fixture integer"))
            .collect()
    }

    /// A whitespace-separated list of doubles.
    fn floats(key: &str) -> Vec<f64> {
        field(key)
            .split_whitespace()
            .map(|t| t.parse().expect("a fixture double"))
            .collect()
    }

    /// A Python `[1, 2, 3]` list.
    fn py_list(key: &str) -> Vec<u64> {
        field(key)
            .trim_start_matches('[')
            .trim_end_matches(']')
            .split(',')
            .map(|t| t.trim().parse().expect("a fixture count"))
            .collect()
    }

    #[test]
    fn uniform_is_bit_identical_to_numpy() {
        let want = ints("uniform(0.5,1.0) bits");
        let mut rng = Distributions::seeded();
        let got: Vec<u64> = want
            .iter()
            .map(|_| rng.uniform(0.5, 1.0).to_bits())
            .collect();
        assert_eq!(got, want, "uniform must resume numpy's stream bit for bit");
    }

    #[test]
    fn uniform_bits_and_values_describe_the_same_draws() {
        let bits = ints("uniform(0.5,1.0) bits");
        let values = floats("uniform(0.5,1.0) values");
        let decoded: Vec<f64> = bits.iter().map(|b| f64::from_bits(*b)).collect();
        assert_eq!(decoded, values, "the two fixture lines must agree");
        assert_eq!(values.len(), 12);
    }

    #[test]
    fn poisson_is_exact_at_both_sealed_rates() {
        let want = py_list("poisson(0.8)");
        let mut rng = Distributions::seeded();
        let got: Vec<u64> = (0..want.len()).map(|_| rng.poisson(0.8)).collect();
        assert_eq!(got, want, "Knuth's product test must agree with numpy");

        // lambda*dt = 8e-4: the rate the sealed script actually draws at.
        let want = py_list("poisson(0.0008)");
        let mut rng = Distributions::seeded();
        let got: Vec<u64> = (0..want.len()).map(|_| rng.poisson(0.0008)).collect();
        assert_eq!(got, want, "the sealed step rate must agree with numpy");
        assert_eq!(got.len(), 20);
        assert_eq!(got.iter().sum::<u64>(), 0, "20 draws of 8e-4 are all zero");
    }

    #[test]
    fn fill_poisson_agrees_with_scalar_poisson() {
        let mut scalar = Distributions::seeded();
        let want: Vec<u64> = (0..32).map(|_| scalar.poisson(0.8)).collect();
        let mut filled = Distributions::seeded();
        let mut got = vec![0_u64; 32];
        filled.fill_poisson(&mut got, 0.8);
        assert_eq!(got, want);
        assert_eq!(scalar.rng(), filled.rng(), "the same raw draws consumed");
    }

    #[test]
    fn poisson_of_zero_is_zero_and_consumes_nothing() {
        let mut rng = Distributions::seeded();
        let before = rng.rng().state();
        assert_eq!(rng.poisson(0.0), 0);
        let mut out = [7_u64; 4];
        rng.fill_poisson(&mut out, 0.0);
        assert_eq!(out, [0_u64; 4]);
        assert_eq!(rng.rng().state(), before, "no raw draw for zero jumps");
    }

    /// numpy uses PTRS above `lam = 10`, so continuing would be a silent
    /// divergence; the crate refuses instead.
    #[test]
    #[should_panic(expected = "PTRS")]
    fn poisson_refuses_numpy_s_other_branch() {
        let mut rng = Distributions::seeded();
        let mut out = [0_u64; 1];
        rng.fill_poisson(&mut out, 10.0);
    }

    /// The `0/12` of `bin/m6-probe`, as a test: if a substitute ever started
    /// matching numpy, what to revisit is `EXACT` and `SUBSTITUTED`.
    #[test]
    fn normal_and_exponential_do_not_reproduce_numpy() {
        let numpy_normal = ints("normal(0,1) bits");
        let mut rng = Distributions::seeded();
        let got: Vec<u64> = numpy_normal
            .iter()
            .map(|_| rng.standard_normal().to_bits())
            .collect();
        assert_ne!(got, numpy_normal);
        assert!(got.iter().zip(&numpy_normal).all(|(a, b)| a != b));

        let numpy_exp = ints("exponential(1.0) bits");
        let mut rng = Distributions::seeded();
        let got: Vec<u64> = numpy_exp
            .iter()
            .map(|_| rng.exponential(1.0).to_bits())
            .collect();
        assert_ne!(got, numpy_exp);
        assert!(got.iter().zip(&numpy_exp).all(|(a, b)| a != b));

        assert_eq!(EXACT.len(), 2);
        assert_eq!(SUBSTITUTED.len(), 2);
        assert_eq!(mode(), DistributionMode::Statistical);
        assert_eq!(mode().as_str(), "statistical");
    }

    #[test]
    fn standard_normal_is_box_muller_over_the_same_stream() {
        let mut direct = Pcg64::seeded();
        let u1 = 1.0 - direct.next_double();
        let u2 = direct.next_double();
        let (first, second) = box_muller_pair(u1, u2);

        let mut rng = Distributions::seeded();
        assert_eq!(rng.standard_normal(), first);
        // The spare is cached — numpy caches nothing, which is exactly why the
        // interleaved stream cannot be resumed.
        assert_eq!(rng.standard_normal(), second);
        assert_eq!(rng.rng().state(), direct.state(), "two raw doubles");
    }

    #[test]
    fn exponential_is_the_inverse_cdf_of_one_double() {
        let mut direct = Pcg64::seeded();
        let u = direct.next_double();
        let want = inverse_cdf_exponential(0.15, u);
        let mut rng = Distributions::seeded();
        assert_eq!(rng.exponential(0.15), want);
        assert_eq!(rng.rng().state(), direct.state(), "one raw double");
    }

    #[test]
    fn fill_normal_shifts_and_scales() {
        let mut direct = Distributions::seeded();
        let want: Vec<f64> = (0..4)
            .map(|_| 0.3 + 0.1 * direct.standard_normal())
            .collect();
        let mut rng = Distributions::seeded();
        let mut got = vec![0.0; 4];
        rng.fill_normal(&mut got, 0.3, 0.1);
        assert_eq!(got, want);
    }

    #[test]
    fn fill_uniform_is_the_scalar_loop() {
        let mut direct = Distributions::seeded();
        let want: Vec<f64> = (0..5).map(|_| direct.uniform(0.5, 1.0)).collect();
        let mut rng = Distributions::seeded();
        let mut got = vec![0.0; 5];
        rng.fill_uniform(&mut got, 0.5, 1.0);
        assert_eq!(got, want);
    }
}
