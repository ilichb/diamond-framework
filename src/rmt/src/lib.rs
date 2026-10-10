//! AVIP off-chain RMT collusion detector — M5 (plan §5.6).
//!
//! Scope: reproduce the sealed RMT calibration of `verification/rmt/` in Rust,
//! *without editing it*, and expose the detector the protocol's off-chain layer
//! consumes. Nothing here is on-chain logic: the alert this crate returns is a
//! struct a caller reads, and turning it into a slashing decision or an AWM
//! message is M7/M8 (§5.6's non-goals).
//!
//! | module | what it carries |
//! |---|---|
//! | [`pcg64`] | the sealed calibration's random stream, resumed bit for bit (`numpy.random.default_rng(42)`) |
//! | [`graph`] | `W` and the three sealed generators (ER null, planted cliques, bipartite polarization) |
//! | [`spectrum`] | dense symmetric order statistics (Householder + Sturm bisection) and the Jacobi reference that checks them |
//! | [`detector`] | `B = W − ddᵀ/(2m)`, the two tails, the sealed thresholds, the verdict |
//! | [`reproduce`] | the sealed protocol end to end: null quantiles, both power tables, the single-draw spectra |
//! | [`report`] | the pinned table (`scripts/m5_output.txt`) |
//! | [`fixture`] | the wiring to M4's committed fixture digest |
//!
//! The one documented command is `src/rmt/scripts/m5_report.sh`; the discipline
//! (durations to stderr, counts/digests in the pinned file, a declared
//! deterministic seed) is M4a's.

pub mod detector;
pub mod fixture;
pub mod graph;
pub mod pcg64;
pub mod report;
pub mod reproduce;
pub mod spectrum;

use std::io::Write;

/// Print a line to stdout, aborting on a broken pipe (`| head`), the same way
/// `src/zk`'s `report.rs` does.
pub(crate) fn line(out: &mut impl Write, s: &str) {
    writeln!(out, "{s}").expect("stdout is writable");
}
