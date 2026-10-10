//! `benches/m4a.rs`, `harness = false`: the M4a measurement entry point.
//!
//! No criterion: the numbers M4a needs are *constraint counts* and *sizes*,
//! which do not need a statistical harness, and the timings it does report must
//! be the ones inside the measured run (proof generation, synthesis), not a
//! loop averaged over a modified setup. `cargo bench` runs the same code path as
//! `cargo run --release --bin m4a-report`, including the durations on stderr.

fn main() {
    let report = avip_zk_prover::report::run();
    print!("{}", report.render());
    eprint!("{}", report.render_timings());
}
