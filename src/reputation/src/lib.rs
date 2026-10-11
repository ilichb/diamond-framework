//! AVIP off-chain reputation dynamics — M6 (plan §5.7).
//!
//! Scope: the reputation layer of `main.tex` §2 and `sec:datalayer`, off-chain.
//! Nothing here moves funds: the epoch commitment this crate produces is a
//! payload a data layer publishes, and slashing/escrow is M8 (§5.2.3, §5.7's
//! non-goals). Three boundaries are deliberate and are checked in the report:
//!
//! - `C_R(r) = 0.8 r/(1+r)` is **M2's** deployed reader on-chain, so M6's
//!   obligation is parity with it in WAD, not a second decision;
//! - the ingestion formula `T[c,d,h] = f_c(events)` is **M7**'s (`eq:ingestion`);
//!   M6 defines the *state → commitment* map, not how events become state;
//! - the `T → W` map does not exist (plan §10 D-7, option (b), open), so nothing
//!   here derives a collaboration graph from a reputation tensor.
//!
//! | module | what it carries |
//! |---|---|
//! | [`pcg64`] | the sealed scripts' random stream, resumed bit for bit (`numpy.random.default_rng(42)`) |
//! | [`numpy`] | which numpy draws M6 can resume exactly and which are documented substitutes |
//! | [`cir`] | the CIR process with multiplicative jumps, transcribed from `sim_positivity.py` |
//! | [`cr`] | `C_R(r)`, its analytic derivatives, the stationary operator and `π(r)` (`eq:integro`) |
//! | [`wad`] | the WAD arithmetic of `AVIPValidatorManager.collateralFor`, 256-bit intermediate |
//! | [`keccak`] | Keccak-256, with the padding the EVM uses |
//! | [`commitment`] | epoch state → leaves → Merkle root in `AVIPRegistry`'s convention |
//! | [`report`] | the pinned table (`scripts/m6_output.txt`) |
//!
//! The one documented command is `src/reputation/scripts/m6_report.sh`; the
//! discipline (durations to stderr, counts in the pinned file, a declared
//! deterministic stream) is M5's.

pub mod cir;
pub mod commitment;
pub mod cr;
pub mod keccak;
pub mod numpy;
pub mod pcg64;
pub mod report;
pub mod wad;

use std::io::Write;

/// Print a line to stdout, aborting on a broken pipe (`| head`), the same way
/// `src/rmt` and `src/zk` do.
pub(crate) fn line(out: &mut impl Write, s: &str) {
    writeln!(out, "{s}").expect("stdout is writable");
}
