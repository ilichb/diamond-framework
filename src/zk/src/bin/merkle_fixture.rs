//! `merkle-fixture` — writes `integrations/avalanche/test/fixtures/
//! DatalayerInclusion.sol` (R5-1/R5-2).
//!
//! Run it through `src/zk/scripts/merkle_fixture.sh`, which follows it with
//! `forge fmt`; the emission itself is in [`avip_zk_prover::merkle_fixture`], so the
//! drift guard in `tests/datalayer_inclusion.rs` can call the same function the
//! binary writes with.

use std::fs::File;
use std::io::Write as _;
use std::process::ExitCode;

use avip_zk_prover::merkle_fixture;

fn main() -> ExitCode {
    let out = merkle_fixture::solidity();
    let mut file = match File::create(merkle_fixture::OUTPUT) {
        Ok(file) => file,
        Err(err) => {
            eprintln!("cannot write {}: {err}", merkle_fixture::OUTPUT);
            return ExitCode::FAILURE;
        }
    };
    if let Err(err) = file.write_all(out.as_bytes()) {
        eprintln!("cannot write {}: {err}", merkle_fixture::OUTPUT);
        return ExitCode::FAILURE;
    }
    eprintln!("wrote {} ({} bytes)", merkle_fixture::OUTPUT, out.len());
    ExitCode::SUCCESS
}
