//! numpy 2.2.6's `random_binomial`, transcribed (plan §5.9).
//!
//! Why this module exists at all: `verification/data-layer/simulate_data_layer_v3.py`
//! is sealed, its two printed fraud means (49.9 for `B < B*`, 50.2 for `B ≥ B*`)
//! come from `rng.binomial`, and M7b reproduces them from Rust. Nothing about
//! `Generator.binomial` is a documented interface at the level of *which* doubles
//! it consumes, so the only honest way to reproduce the numbers is to transcribe
//! the algorithm and prove the transcription with a pinned fixture.
//!
//! Source: `numpy/random/src/distributions/distributions.c`, tag `v2.2.6` —
//! `random_binomial` (lines 799-820), `random_binomial_btpe` (619-760),
//! `random_binomial_inversion` (762-797). Three behaviours are the reason the
//! milestone has to care, and all three are measured in
//! `fixtures/numpy_binomial_seed42.txt`:
//!
//! | call | doubles consumed | why |
//! |---|---|---|
//! | `binomial(n, 0.0)` | **0** | the dispatcher returns 0 before touching the stream |
//! | `binomial(n, 1.0)` | **1** | `q = 1 - p = 0`, so `q*n = 0 ≤ 30` and the `n - inversion(n, 0.0)` branch reads one `next_double` |
//! | `binomial(100, 0.5)` | **≥ 2**, plus rejection | `n*p = 50 > 30` → BTPE, two `next_double` per attempt |
//!
//! That table is the whole reason the sealed file prints two different means for
//! the same fraud model: the epochs with an active auditor make a *second* draw
//! that shifts the stream by one double, so the 500 fraud counts are a different
//! sample. M7b does not fix that up or average it away — it reproduces it.
//!
//! **One declared deviation, inherited from C.** In `Step30`/`Step40` numpy casts
//! `floor(xl + log(v)/laml)` (respectively `xr - log(v)/lamr`) to an integer and
//! then rejects on `y < 0` / `y > n`, with a comment that the cast is undefined
//! when `v == 0.0`. C leaves an out-of-range `double → int64_t` conversion
//! undefined; on x86-64 it yields `INT64_MIN`, which the following bound test
//! rejects. Rust's `as i64` saturates to `i64::MIN` for the same input, so the
//! *control flow* is identical — reject, redraw — and the draws match. The
//! `v == 0.0` case is rejected explicitly, exactly as numpy does, so saturation
//! is unreachable there. This is stated in `bin/m7b-probe`'s output rather than
//! hidden, because "the same as C" is not a claim a language without UB can make
//! in general.
//!
//! The fixture pins five independent `(n, p)` groups plus the sealed script's own
//! interleaving, so the transcription is checked on BTPE, on the inversion path,
//! on the mirrored `p > 0.5` branches, and on the two degenerate cases together.

use crate::pcg64::Pcg64;

/// numpy's `binomial_t`: the per-`(n, p)` cache threaded through consecutive
/// draws. Field names and their reuse follow the C struct literally — `q`, `r`,
/// `c` and `m` hold *different* quantities after `random_binomial_inversion` than
/// after `random_binomial_btpe`, because both write the same struct.
///
/// The cache never consumes a draw (both setups are pure arithmetic over `n` and
/// `p`), so it cannot affect reproducibility; it is carried for fidelity, and
/// `bin/m7b-probe` asserts the no-consumption claim directly by comparing the
/// stream state with and without a cache hit.
#[derive(Clone, Debug, Default)]
pub struct Cache {
    has_binomial: bool,
    nsave: i64,
    psave: f64,
    /// `btpe`: `MIN(p, 1-p)`; `inversion`: `qn = exp(n·log(q))`.
    r: f64,
    /// `btpe`: `1-r`; `inversion`: `1-p`.
    q: f64,
    /// `btpe`: `n·r + r`; `inversion`: `np = n·p`.
    fm: f64,
    /// `btpe`: `⌊fm⌋`; `inversion`: the rejection bound of the inversion loop.
    m: i64,
    c: f64,
    p1: f64,
    xm: f64,
    xl: f64,
    xr: f64,
    laml: f64,
    lamr: f64,
    p2: f64,
    p3: f64,
    p4: f64,
}

impl Cache {
    /// numpy's reuse test, `!(has_binomial && nsave == n && psave == p)` negated.
    fn hits(&self, n: i64, p: f64) -> bool {
        self.has_binomial && self.nsave == n && self.psave == p
    }

    /// The stream position, for the no-consumption assertion in `bin/m7b-probe`.
    #[must_use]
    pub fn nsave(&self) -> i64 {
        self.nsave
    }
}

/// A `Generator.binomial(n, p)` drawn from **this** stream, with numpy's cache.
///
/// `n` is an integer count and `p` a probability, in the argument order of the C
/// function (`p` first there, `n` second — the Python signature is the reverse).
#[derive(Clone, Debug, Default)]
pub struct Binomial {
    cache: Cache,
}

impl Binomial {
    /// A fresh cache: the first draw of a generator always runs the setup path.
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    /// The cache, so a caller can assert what the last draw wrote into it.
    #[must_use]
    pub fn cache(&self) -> &Cache {
        &self.cache
    }

    /// `np.random.default_rng(...).binomial(n, p)`, for the integer `n` and
    /// floating-point `p` the sealed script uses.
    pub fn draw(&mut self, rng: &mut Pcg64, n: i64, p: f64) -> i64 {
        // `random_binomial` lines 803-819: the degenerate cases come *before* any
        // draw, and the `p == 0.0` test is a float comparison, so `-0.0` takes it.
        if n == 0 || p == 0.0 {
            return 0;
        }
        if p <= 0.5 {
            if p * (n as f64) <= 30.0 {
                self.inversion(rng, n, p)
            } else {
                self.btpe(rng, n, p)
            }
        } else {
            let q = 1.0 - p;
            if q * (n as f64) <= 30.0 {
                n - self.inversion(rng, n, q)
            } else {
                n - self.btpe(rng, n, q)
            }
        }
    }

    /// `random_binomial_inversion` (lines 762-797): walk the cumulative
    /// distribution, restarting from `x = 0` with a fresh `next_double` whenever
    /// the walk passes the truncation bound.
    fn inversion(&mut self, rng: &mut Pcg64, n: i64, p: f64) -> i64 {
        if !self.cache.hits(n, p) {
            let c = &mut self.cache;
            c.nsave = n;
            c.psave = p;
            c.has_binomial = true;
            let q = 1.0 - p;
            let qn = ((n as f64) * q.ln()).exp();
            let np = (n as f64) * p;
            c.q = q;
            c.r = qn;
            c.c = np;
            c.m = (n as f64).min(np + 10.0 * (np * q + 1.0).sqrt()) as i64;
        }
        let q = self.cache.q;
        let qn = self.cache.r;
        let bound = self.cache.m;

        let mut x = 0_i64;
        let mut px = qn;
        let mut u = rng.next_double();
        while u > px {
            x += 1;
            if x > bound {
                x = 0;
                px = qn;
                u = rng.next_double();
            } else {
                u -= px;
                px = ((n - x + 1) as f64 * p * px) / (x as f64 * q);
            }
        }
        x
    }

    /// `random_binomial_btpe` (lines 619-760): the BTPE algorithm of
    /// Kachitvichyanukul & Schmeiser as numpy implements it. The C `goto`s are
    /// kept as a labelled `loop` (`continue 'step10` = retry, `return step60` =
    /// accept) so the transcription can be compared with the source line by line;
    /// collapsing them into idiomatic control flow would hide exactly the kind of
    /// mistake this module cannot afford.
    fn btpe(&mut self, rng: &mut Pcg64, n: i64, p: f64) -> i64 {
        if !self.cache.hits(n, p) {
            let c = &mut self.cache;
            c.nsave = n;
            c.psave = p;
            c.has_binomial = true;
            let r = p.min(1.0 - p);
            let q = 1.0 - r;
            let fm = (n as f64) * r + r;
            let m = fm.floor() as i64;
            let p1 = (2.195 * ((n as f64) * r * q).sqrt() - 4.6 * q).floor() + 0.5;
            let xm = m as f64 + 0.5;
            let xl = xm - p1;
            let xr = xm + p1;
            let cc = 0.134 + 20.5 / (15.3 + m as f64);
            let a = (fm - xl) / (fm - xl * r);
            let laml = a * (1.0 + a / 2.0);
            let a = (xr - fm) / (xr * q);
            let lamr = a * (1.0 + a / 2.0);
            let p2 = p1 * (1.0 + 2.0 * cc);
            let p3 = p2 + cc / laml;
            let p4 = p3 + cc / lamr;
            c.r = r;
            c.q = q;
            c.fm = fm;
            c.m = m;
            c.p1 = p1;
            c.xm = xm;
            c.xl = xl;
            c.xr = xr;
            c.c = cc;
            c.laml = laml;
            c.lamr = lamr;
            c.p2 = p2;
            c.p3 = p3;
            c.p4 = p4;
        }
        let c = self.cache.clone();
        let (r, q, m, p1, xm, xl, xr, cc, laml, lamr, p2, p3, p4) = (
            c.r, c.q, c.m, c.p1, c.xm, c.xl, c.xr, c.c, c.laml, c.lamr, c.p2, c.p3, c.p4,
        );

        'step10: loop {
            let nrq = (n as f64) * r * q;
            let u = rng.next_double() * p4;
            let mut v = rng.next_double();
            let y: i64;
            if u > p1 {
                if u > p2 {
                    if u > p3 {
                        // Step40: right exponential tail.
                        y = (xr - v.ln() / lamr).floor() as i64;
                        if y > n || v == 0.0 {
                            continue 'step10;
                        }
                        v = v * (u - p3) * lamr;
                    } else {
                        // Step30: left exponential tail.
                        y = (xl + v.ln() / laml).floor() as i64;
                        if y < 0 || v == 0.0 {
                            continue 'step10;
                        }
                        v = v * (u - p2) * laml;
                    }
                } else {
                    // Step20: parallelogram.
                    let x = xl + (u - p1) / cc;
                    v = v * cc + 1.0 - (((m as f64) - x + 0.5).abs()) / p1;
                    if v > 1.0 {
                        continue 'step10;
                    }
                    y = x.floor() as i64;
                }
            } else {
                // The central triangle: `goto Step60` directly.
                y = (xm - p1 * v + u).floor() as i64;
                return step60(n, p, y);
            }

            // Step50: accept against the exact point probability.
            let k = (y - m).abs();
            if k > 20 && (k as f64) < (nrq / 2.0 - 1.0) {
                // Step52: the squeezing test, then the Stirling-type correction.
                let kf = k as f64;
                let rho =
                    (kf / nrq) * ((kf * (kf / 3.0 + 0.625) + 0.16666666666666666) / nrq + 0.5);
                let t = -((k * k) as f64) / (2.0 * nrq);
                let a = v.ln();
                if a < t - rho {
                    return step60(n, p, y);
                }
                if a > t + rho {
                    continue 'step10;
                }
                let x1 = (y as f64) + 1.0;
                let f1 = (m as f64) + 1.0;
                let z = (n as f64) + 1.0 - (m as f64);
                let w = (n as f64) - (y as f64) + 1.0;
                let (x2, f2, z2, w2) = (x1 * x1, f1 * f1, z * z, w * w);
                // C: `(13680. - (...)/f2) / f1 / 166320.` — the division order is
                // `A / f / 166320.`, not `A / 166320. / f`: in floating point the
                // two differ in the last bit, which is all this module needs to
                // get wrong for the draws to drift.
                let poly = |s: f64, f: f64| {
                    (13680.0 - (462.0 - (132.0 - (99.0 - 140.0 / s) / s) / s) / s) / f / 166320.0
                };
                if a > xm * (f1 / x1).ln()
                    + ((n - m) as f64 + 0.5) * (z / w).ln()
                    + ((y - m) as f64) * ((w * r) / (x1 * q)).ln()
                    + poly(f2, f1)
                    + poly(z2, z)
                    + poly(x2, x1)
                    + poly(w2, w)
                {
                    continue 'step10;
                }
                return step60(n, p, y);
            }

            let s = r / q;
            let a = s * ((n as f64) + 1.0);
            let mut f = 1.0;
            if m < y {
                for i in (m + 1)..=y {
                    f *= a / (i as f64) - s;
                }
            } else if m > y {
                for i in (y + 1)..=m {
                    f /= a / (i as f64) - s;
                }
            }
            if v > f {
                continue 'step10;
            }
            return step60(n, p, y);
        }
    }
}

/// `Step60` of `random_binomial_btpe`: the final `p > 0.5` mirror. Every
/// accepting path reaches it, so it lives in one place.
fn step60(n: i64, p: f64, y: i64) -> i64 {
    if p > 0.5 { n - y } else { y }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// numpy's own draws, pinned: if the transcription drifts, the table in
    /// `scripts/m7b_output.txt` drifts with it, so `cargo test` reads the
    /// fixture directly instead of only through the equilibrium.
    const FIXTURE: &str = include_str!("../fixtures/numpy_binomial_seed42.txt");

    fn field(key: &str) -> Vec<i64> {
        FIXTURE
            .lines()
            .filter(|l| !l.trim_start().starts_with('#'))
            .find_map(|l| l.strip_prefix(&format!("{key} =")))
            .unwrap_or_else(|| panic!("fixture has no `{key}`"))
            .split_whitespace()
            .map(|t| t.parse().expect("i64"))
            .collect()
    }

    fn draws(n: i64, p: f64, count: usize) -> Vec<i64> {
        let mut rng = Pcg64::seeded();
        let mut binomial = Binomial::new();
        (0..count).map(|_| binomial.draw(&mut rng, n, p)).collect()
    }

    /// `n*p = 50 > 30`: the sealed script's first draw is BTPE.
    #[test]
    fn btpe_draws_match_numpy() {
        assert_eq!(draws(100, 0.5, 500), field("btpe100_05(500)"));
    }

    /// The rejection loop has to be exercised too, and `n = 1000` does it.
    #[test]
    fn btpe_with_rejection_matches_numpy() {
        assert_eq!(draws(1000, 0.5, 200), field("btpe1000_05(200)"));
    }

    /// `n*p = 1.5 ≤ 30`: the cumulative-search path.
    #[test]
    fn inversion_draws_match_numpy() {
        assert_eq!(draws(3, 0.5, 200), field("inv3_05(200)"));
    }

    /// `p > 0.5` mirrors the draw; both mirrored branches, small and large `q*n`.
    #[test]
    fn mirrored_draws_match_numpy() {
        assert_eq!(draws(100, 0.9, 200), field("highp100_09(200)"));
        assert_eq!(draws(1000, 0.9, 200), field("highp1000_09(200)"));
    }

    /// The two degenerate cases the sealed numbers depend on, with the count of
    /// doubles each consumes — the reason the file prints two different means.
    #[test]
    fn degenerate_cases_consume_what_numpy_consumes() {
        let p_zero = consumed(|rng| {
            Binomial::new().draw(rng, 50, 0.0);
        });
        let p_one = consumed(|rng| {
            Binomial::new().draw(rng, 50, 1.0);
        });
        assert_eq!(p_zero, Some(0), "p == 0 returns before touching the stream");
        assert_eq!(p_one, Some(1), "p == 1 goes through inversion with q == 0");

        let mut rng = Pcg64::seeded();
        let mut binomial = Binomial::new();
        assert_eq!(binomial.draw(&mut rng, 5, 0.0), 0);
        assert_eq!(binomial.draw(&mut rng, 5, 1.0), 5);
    }

    /// A cache hit must not consume anything: two consecutive draws of the same
    /// `(n, p)` read the stream exactly the way two cold draws do.
    #[test]
    fn the_cache_never_moves_the_stream() {
        let cached = consumed(|rng| {
            let mut b = Binomial::new();
            b.draw(rng, 100, 0.5);
            b.draw(rng, 100, 0.5);
        });
        let cold = consumed(|rng| {
            Binomial::new().draw(rng, 100, 0.5);
            let mut b = Binomial::new();
            b.draw(rng, 100, 0.5);
        });
        assert_eq!(cached, cold, "the set-up arithmetic is free");
        assert_eq!(cached, Some(4), "BTPE reads two doubles per accepted draw");
    }

    /// `k` doubles after the first: the smallest `advance(k)` matching the state.
    fn consumed(f: impl FnOnce(&mut Pcg64)) -> Option<u128> {
        let mut rng = Pcg64::seeded();
        f(&mut rng);
        let after = rng.state();
        (0..=64).find(|&k| {
            let mut probe = Pcg64::seeded();
            probe.advance(k);
            probe.state() == after
        })
    }
}
