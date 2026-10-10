//! M4a measurement driver (plan §5.5.6).
//!
//! `cargo run --release --bin m4a-report` runs every measurement and prints the
//! table; `scripts/m4a_report.sh` also writes it to `scripts/m4a_output.txt`.
//! `--write-digest` refreshes `fixtures/tensor_digest.txt`, the pin the fixture
//! test compares against.

use std::fs;
use std::path::PathBuf;

use avip_zk_prover::{fixture, report};

fn digest_path() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("fixtures/tensor_digest.txt")
}

fn main() {
    let mut args = std::env::args().skip(1);
    if let Some(arg) = args.next() {
        if arg == "--write-digest" {
            let digest = fixture::tensor().digest_hex();
            fs::write(digest_path(), format!("{digest}\n")).expect("write digest pin");
            println!("wrote {} = {digest}", digest_path().display());
            return;
        }
        eprintln!("unknown argument: {arg}\nusage: m4a-report [--write-digest]");
        std::process::exit(2);
    }
    let report = report::run();
    print!("{}", report.render());
    eprint!("{}", report.render_timings());
}
