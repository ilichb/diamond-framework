//! AVIP off-chain prover — M4a measurement crate.
//!
//! Scope (plan §5.5.6): every number in the M4a note must be reproducible by one
//! documented command. Nothing here is a production circuit: M4 proves the
//! pipeline and its cost, not a deployment.
//!
//! | module | what it measures |
//! |---|---|
//! | [`fixture`] | the deterministic 500-entry tensor (§5.5.6) |
//! | [`range_proof`] | the aggregated Bulletproofs range proof — `512 × 64 = 32,768` bits, because the aggregated API offers no `k = 60` and no `N = 500` (§5.5.3) |
//! | [`native`] | constraints of commitment + norm in one BN254 circuit: **V3** implemented, **V2′** pending (§5.5.2) |
//! | [`report`] | the measured table of §5.5.6; durations go to stderr, not into the pinned table |

pub mod fixture;
pub mod native;
pub mod range_proof;
pub mod report;
