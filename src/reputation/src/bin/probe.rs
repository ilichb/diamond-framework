//! `m6-probe` — which of the sealed script's draws M6 can resume, measured.
//!
//! `scripts/m6_output.txt` says "statistical", and this binary is the evidence
//! behind that word: it re-derives the mode from `numpy.rs`'s own declarations,
//! counts how many of the fixture's draws each implementation reproduces, and
//! prints the moments of the substitutes. Nothing here is pinned; it is the
//! diagnostic the report's prose points at.
//!
//! The exit code is non-zero when a draw declared **exact** fails to match its
//! fixture — that is a regression. The substitutes are not failures: they are
//! declared, and their *distribution* is what gets measured.

use std::io::{BufWriter, StdoutLock, Write};
use std::process::ExitCode;

use avip_reputation::numpy::{self, Distributions, EXACT, SUBSTITUTED};
use avip_reputation::pcg64::Pcg64;

/// The `=` rule and the `-` rule, as in `report.rs`: a `[[bin]]` is a separate
/// crate and cannot see the library's `pub(crate)` helpers, so the probe carries
/// its own two.
const SEP: &str = "==============================================================================";
const SUB: &str = "------------------------------------------------------------------------------";

/// `numpy 2.2.6`'s draws from `np.random.default_rng(42)`, each from a fresh
/// generator, with the regeneration command at the top of the file.
const DISTRIBUTIONS: &str = include_str!("../../fixtures/numpy_distributions_seed42.txt");

/// The `u64` payload after `key = ` in the fixture, bracketed or not.
fn bits_after(key: &str) -> Vec<u64> {
    DISTRIBUTIONS
        .lines()
        .find(|line| line.starts_with(key))
        .unwrap_or_else(|| panic!("fixture has no line starting with {key:?}"))
        .split_once('=')
        .expect("the fixture's lines are `key = values`")
        .1
        .trim()
        .trim_start_matches('[')
        .trim_end_matches(']')
        .split(|c: char| c == ',' || c.is_whitespace())
        .filter(|token| !token.is_empty())
        .map(|token| token.parse::<u64>().expect("a u64 bit pattern"))
        .collect()
}

/// Print one line to the buffered stdout.
fn say(out: &mut BufWriter<StdoutLock<'_>>, s: &str) {
    writeln!(out, "{s}").expect("stdout is writable");
}

fn main() -> ExitCode {
    let stdout = std::io::stdout();
    let mut out = BufWriter::new(stdout.lock());
    let mut ok = true;

    say(&mut out, SEP);
    say(
        &mut out,
        "m6-probe: which of the sealed script's draws M6 can resume",
    );
    say(&mut out, SEP);
    say(
        &mut out,
        "sealed script: verification/stochastics/sim_positivity.py",
    );
    say(
        &mut out,
        "stream:        np.random.default_rng(42), resumed by pcg64.rs",
    );
    say(&mut out, "");

    // 1. The stream itself: numpy's own first doubles, straight from the fixture.
    let doubles = bits_after("first doubles bits");
    let mut stream = Pcg64::seeded();
    let matched = doubles
        .iter()
        .filter(|&&want| stream.next_double().to_bits() == want)
        .count();
    ok &= matched == doubles.len();
    say(
        &mut out,
        &format!(
            "stream         {}/{} numpy doubles reproduce bit for bit    {}",
            matched,
            doubles.len(),
            if matched == doubles.len() {
                "OK"
            } else {
                "MISMATCH"
            }
        ),
    );
    say(&mut out, "");

    // 2. The draws `numpy.rs` declares exact, measured against the fixture.
    say(&mut out, SUB);
    say(&mut out, "declared exact, measured against fixtures/:");
    for name in EXACT {
        say(&mut out, &format!("  {name}"));
    }
    let uniform = bits_after("uniform(0.5,1.0) bits");
    let mut rng = Distributions::seeded();
    let matched = uniform
        .iter()
        .filter(|&&want| rng.uniform(0.5, 1.0).to_bits() == want)
        .count();
    ok &= matched == uniform.len();
    say(
        &mut out,
        &format!(
            "  measurement    uniform            {}/{} bit-identical",
            matched,
            uniform.len()
        ),
    );
    for (key, lam) in [("poisson(0.8)", 0.8), ("poisson(0.0008)", 0.0008)] {
        let want = bits_after(key);
        let mut rng = Distributions::seeded();
        let matched = want.iter().filter(|&&w| rng.poisson(lam) == w).count();
        ok &= matched == want.len();
        say(
            &mut out,
            &format!(
                "  measurement    {key:<18} {matched}/{} identical",
                want.len()
            ),
        );
    }
    say(&mut out, "");

    // 3. The substitutes: why no fixture can exist, and what they do satisfy.
    say(&mut out, SUB);
    say(
        &mut out,
        "declared substituted, measured against fixtures/:",
    );
    for name in SUBSTITUTED {
        say(&mut out, &format!("  {name}"));
    }
    let normal = bits_after("normal(0,1) bits");
    let mut rng = Distributions::seeded();
    let matched = normal
        .iter()
        .filter(|&&want| rng.standard_normal().to_bits() == want)
        .count();
    say(
        &mut out,
        &format!(
            "  measurement    normal             {}/{} bit-identical: numpy draws ziggurat, \
             this draws Box-Muller",
            matched,
            normal.len()
        ),
    );
    let exponential = bits_after("exponential(1.0) bits");
    let mut rng = Distributions::seeded();
    let matched = exponential
        .iter()
        .filter(|&&want| rng.exponential(1.0).to_bits() == want)
        .count();
    say(
        &mut out,
        &format!(
            "  measurement    exponential        {}/{} bit-identical",
            matched,
            exponential.len()
        ),
    );
    say(
        &mut out,
        "  stream cost    Box-Muller takes exactly 2 raw doubles per variate and keeps",
    );
    say(
        &mut out,
        "                 one spare; numpy's ziggurat takes 1 or 2 depending on the",
    );
    say(
        &mut out,
        "                 rejection test, so the streams diverge at the first variate",
    );
    say(
        &mut out,
        "                 and never resynchronise. That is why the sealed script's",
    );
    say(
        &mut out,
        "                 interleaved run cannot be resumed even though its Poisson and",
    );
    say(
        &mut out,
        "                 uniform draws can be reproduced on their own.",
    );
    say(&mut out, "");

    // 4. What a substitute does satisfy, so "statistical" is a measured claim.
    const DRAWS: usize = 1_000_000;
    let n = DRAWS as f64;
    let mut rng = Distributions::seeded();
    let (mut sum, mut sum_sq) = (0.0, 0.0);
    for _ in 0..DRAWS {
        let z = rng.standard_normal();
        sum += z;
        sum_sq += z * z;
    }
    let mean = sum / n;
    let sd = (sum_sq / n - mean * mean).sqrt();
    say(
        &mut out,
        &format!("moments of the substitutes, {DRAWS} variates from the seeded stream:"),
    );
    say(
        &mut out,
        &format!(
            "  normal(0,1)        mean = {mean:+.6} (SE {:.6})   sd = {sd:.6} (SE {:.6})",
            1.0 / n.sqrt(),
            1.0 / (2.0 * n).sqrt()
        ),
    );
    ok &= mean.abs() <= 4.0 / n.sqrt() && (sd - 1.0).abs() <= 4.0 / (2.0 * n).sqrt();
    let mut rng = Distributions::seeded();
    let mut sum = 0.0;
    for _ in 0..DRAWS {
        sum += rng.exponential(0.15);
    }
    let mean = sum / n;
    say(
        &mut out,
        &format!(
            "  exponential(0.15)  mean = {mean:.6} (target 0.150000, SE {:.6})",
            0.15 / n.sqrt()
        ),
    );
    ok &= (mean - 0.15).abs() <= 4.0 * 0.15 / n.sqrt();
    say(&mut out, "");
    say(
        &mut out,
        &format!(
            "mode = {} (numpy::mode(), derived from EXACT and SUBSTITUTED)",
            numpy::mode().as_str()
        ),
    );
    say(
        &mut out,
        "therefore every number of scripts/m6_output.txt that depends on normal or",
    );
    say(
        &mut out,
        "exponential is reproduced statistically, with its sampling error printed",
    );
    say(
        &mut out,
        "(section 3); everything else in that table is exact.",
    );
    out.flush().expect("stdout is writable");

    if ok {
        ExitCode::SUCCESS
    } else {
        ExitCode::FAILURE
    }
}
