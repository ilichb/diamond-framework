//! `m6-report` — the pinned table of `scripts/m6_output.txt` (plan §5.7).
//!
//! The documented way to run this is `scripts/m6_report.sh`, which writes the
//! pinned file only after the drift guard passes; this binary is what it runs, and
//! is usable on its own to read the table.
//!
//! Determinism: the whole table is a function of the code, because the stream is
//! the sealed PCG64 seeded at 42 and nothing timed is written into it. Durations go
//! to stderr, and the verdict goes to the exit code — non-zero if a check failed.
//! `--smoke` shrinks the positivity run (a development mode, not pinnable), so it
//! reports the verdict without failing the exit code.

use std::io::{BufWriter, Write};
use std::process::ExitCode;
use std::time::Instant;

use avip_reputation::{cir, report};

fn main() -> ExitCode {
    let smoke = std::env::args().skip(1).any(|arg| arg == "--smoke");
    let params = if smoke {
        cir::Params::smoke()
    } else {
        cir::Params::sealed()
    };

    let started = Instant::now();
    let stdout = std::io::stdout();
    let mut out = BufWriter::new(stdout.lock());
    let outcome = report::write(&mut out, &params, smoke);
    out.flush().expect("stdout is writable");
    let elapsed = started.elapsed();

    eprintln!(
        "m6-report: additive positivity = {:.4}% (sealed 40.5800%), multiplicative = {:.6}% \
         (min R = {:.6})",
        outcome.additive * 100.0,
        outcome.multiplicative * 100.0,
        outcome.min_r
    );
    eprintln!(
        "m6-report: {} in {:.1}s (paths = {}, steps = {}, smoke = {})",
        if outcome.all_pass {
            "all checks PASS"
        } else {
            "CHECKS FAILED"
        },
        elapsed.as_secs_f64(),
        params.n_paths,
        params.n_steps(),
        smoke
    );

    if outcome.all_pass || smoke {
        ExitCode::SUCCESS
    } else {
        ExitCode::FAILURE
    }
}
