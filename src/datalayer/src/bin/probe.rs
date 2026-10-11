//! `m7b-probe`: does the transcription of numpy's binomial actually hold?
//!
//! `src/binomial.rs` claims to reproduce `np.random.default_rng(42).binomial(n, p)`
//! bit for bit, including *how many* doubles each call consumes. This binary is
//! the test of that claim, and it prints its verdict rather than asserting it,
//! because the claim is what the milestone's headline numbers rest on:
//!
//! - the **draws** are compared against `fixtures/numpy_binomial_seed42.txt`,
//!   five independent `(n, p)` groups (BTPE, inversion, and the mirrored
//!   `p > 0.5` branches of both) plus the sealed script's own interleaving at
//!   `coverage = 1.0` and `coverage = 0.0`, 500 pairs each;
//! - the **stream consumption** is measured, not assumed: the generator's state
//!   after a draw is compared with `advance(k)` for the smallest `k` that
//!   matches, which is why this binary can state that `binomial(n, 0.0)` consumes
//!   nothing while `binomial(n, 1.0)` consumes one double and so shifts every
//!   later draw of the sealed script.
//!
//! The fixture, the reproduction rules and the measurement live in
//! `src/fixture.rs`, shared with `m7b-report`: the probe and the pinned table
//! cannot end up checking different things.
//!
//! Exit code 0 means every group matched; 1 means a divergence, with the index
//! and both values printed. A mismatch here is not a tolerance question: the
//! pinned table in `scripts/m7b_output.txt` would be wrong, so the milestone
//! fails loudly instead.
//!
//! Known, declared deviation: `Step30`/`Step40` of `random_binomial_btpe` cast a
//! `double` that can be far out of `int64_t` range — undefined behaviour in C, a
//! saturating cast in Rust. Both reject and redraw, so the draws agree, and
//! `scripts/m7b_output.txt` prints the same sentence. `v == 0.0` is rejected
//! explicitly, exactly as numpy does.

use std::process::ExitCode;

use avip_datalayer::fixture::{self, GROUPS};

/// The one line each measured call is annotated with, in `consumption`'s order.
const NOTES: [&str; 4] = [
    "(returns 0 before the stream)",
    "(q = 0 lands in inversion)",
    "(BTPE: 2 per attempt, no rejection here)",
    "(the cache itself consumes nothing)",
];

fn main() -> ExitCode {
    println!("numpy 2.2.6 `random_binomial`, transcribed — m7b-probe");
    println!("fixture: src/datalayer/fixtures/numpy_binomial_seed42.txt");
    println!();

    let mut failures = 0_usize;
    let verdict = fixture::transcription();
    let checked = verdict.draws;

    for group in GROUPS {
        let expected = fixture::values(group);
        let got = fixture::reproduce(group);
        if got == expected {
            println!("  ok    {group:<26} {} draws", expected.len());
        } else {
            failures += 1;
            let first = expected
                .iter()
                .zip(&got)
                .position(|(a, b)| a != b)
                .unwrap_or(expected.len().min(got.len()));
            println!(
                "  FAIL  {group:<26} first divergence at index {first}: numpy {:?}, rust {:?}",
                expected.get(first),
                got.get(first)
            );
        }
    }

    println!();
    println!("stream consumption (measured against `advance(k)`):");
    for ((call, doubles), note) in fixture::consumption().iter().zip(NOTES) {
        println!("  {call:<16}  -> {doubles:?} doubles  {note}");
    }

    println!();
    println!("declared deviation: Step30/Step40 cast an out-of-range double to an integer —");
    println!("  undefined in C, saturating in Rust; both reject on `y < 0` / `y > n`, so the");
    println!("  draws agree. `v == 0.0` is rejected explicitly first, as numpy does.");

    println!();
    if failures == 0 {
        println!(
            "verdict: transcription holds — {checked} draws, {}/10 groups",
            GROUPS.len()
        );
        ExitCode::SUCCESS
    } else {
        println!("verdict: transcription FAILS — {failures}/10 groups diverge");
        ExitCode::FAILURE
    }
}
