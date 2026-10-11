//! AVIP off-chain prover — M4's pipeline and the M7c bridge.
//!
//! Scope (plan §5.5.6): every number in the M4a note must be reproducible by one
//! documented command, and §5.10 adds M7c's bridge table. Nothing here is a
//! production circuit: M4 proves the pipeline and its cost, not a deployment.
//!
//! | module | what it measures |
//! |---|---|
//! | [`fixture`] | the deterministic 500-entry tensor (§5.5.6) |
//! | [`range_proof`] | the aggregated Bulletproofs range proof — `512 × 64 = 32,768` bits, because the aggregated API offers no `k = 60` and no `N = 500` (§5.5.3) |
//! | [`native`] | constraints of commitment + norm in one BN254 circuit: **V3** implemented, **V2′** pending (§5.5.2) |
//! | [`report`] | the measured table of §5.5.6; durations go to stderr, not into the pinned table |
//! | [`groth16`] | M4b: the real Groth16 key over V3, the contract's statement, the end-to-end prover (§5.5.4) |
//! | [`bridge`] | M7c: the tie between the statement's root and the registry's `keccak256` Merkle root (§5.4 item 4 (c), §5.5.7; delivered in §5.10) |

pub mod bridge;
pub mod fixture;
pub mod groth16;
pub mod native;
pub mod range_proof;
pub mod report;
