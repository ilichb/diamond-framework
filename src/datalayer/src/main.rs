//! `m7b-report` — the pinned table of `scripts/m7b_output.txt` (plan §5.9).
//!
//! The documented way to run this is `scripts/m7b_report.sh`, which replaces the
//! pinned file only after the drift guard passes; this binary is what it runs, and
//! is usable on its own to read the table.
//!
//! Determinism: the whole table is a function of the code — the stream is numpy's
//! PCG64 seeded at 42, resumed bit for bit, and nothing timed is written into it.
//! Durations go to stderr and the verdict goes to the exit code, non-zero if any
//! check failed.

use std::io::{BufWriter, Write};
use std::process::ExitCode;
use std::time::Instant;

use avip_datalayer::{fixture, report};

fn main() -> ExitCode {
    let started = Instant::now();
    let stdout = std::io::stdout();
    let mut out = BufWriter::new(stdout.lock());
    let outcome = report::write(&mut out);
    out.flush().expect("stdout is writable");
    let elapsed = started.elapsed();

    eprintln!(
        "m7b-report: transcription {}/{} groups, {} draws; {} rows of the sealed table",
        outcome.groups_ok,
        fixture::GROUPS.len(),
        outcome.draws,
        outcome.rows
    );
    eprintln!(
        "m7b-report: {} in {:.1}s",
        if outcome.all_pass {
            "all checks PASS"
        } else {
            "CHECKS FAILED"
        },
        elapsed.as_secs_f64()
    );

    if outcome.all_pass {
        ExitCode::SUCCESS
    } else {
        ExitCode::FAILURE
    }
}
