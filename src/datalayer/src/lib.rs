//! AVIP off-chain data layer — M7b (plan §5.9).
//!
//! Scope: `main.tex` `sec:datalayer`, off-chain. Three pieces belong here: the
//! first two are this milestone's (§5.9) and the bridge is M7c's (§5.10).
//!
//! - the **audit equilibrium** of `eq:revenue`, `eq:bstar`, `eq:equilibrium`:
//!   `B* = c_audit / p_fraud`, `n*(B) = min(⌊B/B*⌋, N_VERIFIERS)`, with the
//!   attacker and verifier profits and the integrity the sealed script prints;
//! - the **ingestion formula** `T[c,d,h] = f_c(events in window h)`
//!   (`eq:ingestion`) as an interface with the properties the paper states —
//!   public, deterministic, in `[0,1]`, fixed at genesis, identical for every
//!   validator on chain `c` — plus the fraud proof that punishes a wrong `f_c`;
//! - the **Pedersen ↔ Merkle bridge** (option (c) of §5.4 item 4), delivered by
//!   M7c in `src/zk/src/bridge.rs` (§5.10): it needs the prover's own
//!   commitments, so it lives with the prover and only *uses* [`commitment`]'s
//!   fold and [`keccak`], never a second copy of either.
//!
//! Nothing here moves funds: the bounty `B` and the slash `S_slash` are the
//! paper's model parameters, and the code that actually escrows or burns is M8.
//! The `T → W` map does not exist here either (plan §10 D-7, option (b), open).
//!
//! | module | what it carries |
//! |---|---|
//! | [`pcg64`] | the sealed scripts' random stream, resumed bit for bit (`default_rng(42)`) |
//! | [`binomial`] | numpy 2.2.6's `random_binomial`, transcribed (BTPE + inversion + the degenerate cases) |
//! | [`equilibrium`] | `B*`, `n*(B)`, coverage, attacker/verifier profit, integrity (`eq:revenue`–`eq:equilibrium`) |
//! | [`ingestion`] | `f_c` as an interface with the paper's properties, plus the fraud proof |
//! | [`commitment`] | epoch → Merkle root, in `AVIPRegistry`'s convention (M6's, carried over) |
//! | [`keccak`] | Keccak-256, with the padding the EVM uses (M6's, for the commitment side) |
//! | [`fixture`] | the pinned numpy draws and the sealed lines, and the transcription verdict |
//! | [`report`] | the pinned table (`scripts/m7b_output.txt`) |
//!
//! The one documented command is `src/datalayer/scripts/m7b_report.sh`; the
//! discipline (durations to stderr, counts in the pinned file, a declared
//! deterministic stream, a drift guard in both directions) is M5's and M6's.

use std::io::Write;

pub mod binomial;
pub mod commitment;
pub mod equilibrium;
pub mod fixture;
pub mod ingestion;
pub mod keccak;
pub mod pcg64;
pub mod report;

/// Write one `\n`-terminated line, failing loudly: a report that silently lost a
/// line would be a pinned table with a hole in it.
pub(crate) fn line(out: &mut impl Write, text: &str) {
    writeln!(out, "{text}").expect("the report is written");
}
