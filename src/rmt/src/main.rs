//! `m5-report` — the one documented command of plan §5.6.
//!
//! Prints the reproduced table to stdout (that is what `scripts/m5_output.txt`
//! pins: no durations, no thread counts) and the wall-clock observation to
//! stderr, the M4a discipline for anything load-dependent.
//!
//! ```text
//! cargo run --release --bin m5-report             # the sealed protocol
//! cargo run --release --bin m5-report -- --smoke  # seconds, not the pinned table
//! ```

use std::io::{self, Write};
use std::time::Instant;

use avip_rmt_detector::report::{self, Options};

/// Graphs the report reproduces, for the stderr counter only.
const CLIQUE_CONFIGS: usize = 5;
const BIPARTITE_CONFIGS: usize = 6;
const SPECTRA_GRAPHS: usize = 2;

fn main() {
    let smoke = std::env::args().any(|a| a == "--smoke");
    let opts = if smoke {
        Options::smoke()
    } else {
        Options::reference()
    };
    let started = Instant::now();
    let stdout = io::stdout();
    let mut out = io::BufWriter::new(stdout.lock());
    report::render(&mut out, &opts);
    out.flush().expect("stdout flush");
    let graphs = opts.n_h0 + opts.n_h1 * (CLIQUE_CONFIGS + BIPARTITE_CONFIGS) + SPECTRA_GRAPHS;
    eprintln!(
        "m5-report: n={} N_H0={} N_H1={} {graphs} graphs reproduced in {:.1} s (stderr, load-dependent)",
        opts.n,
        opts.n_h0,
        opts.n_h1,
        started.elapsed().as_secs_f64()
    );
}
