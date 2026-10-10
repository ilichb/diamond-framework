//! The wiring to M4's committed fixture digest (plan §5.6).
//!
//! `main.tex`'s `W` is the *collaboration* graph (§collab: interactions between
//! validators) while `T` is the *reputation* tensor (§tensor: `C·D·H = 500`
//! entries of one validator's scores). The paper defines **no map** from one to
//! the other, so M5 does not invent one; the missing map is recorded as an open
//! item in plan §10.
//!
//! What M5 does instead is bind the detector's synthetic input to bytes M4
//! committed: the keccak digest of the 500-entry fixture
//! (`src/zk/fixtures/tensor_digest.txt`, written by M4a's `--write-digest` and
//! asserted by M4a's tests). The digest seeds the detector's graph, so a run of
//! `m5-report` carries the same anchor as the prover's fixture. `include_str!`
//! makes the coupling a *build* dependency: if M4's artefact disappears, the
//! detector stops compiling instead of silently picking a seed of its own.
//!
//! Swap this module out the day a real collaboration graph exists; the detector
//! itself only ever sees a [`Graph`].

use crate::graph::Graph;
use crate::pcg64::Pcg64;

/// M4a's committed fixture digest, in lowercase hex.
pub const M4_TENSOR_DIGEST_HEX: &str = include_str!("../../zk/fixtures/tensor_digest.txt");

/// The fixture digest as 32 bytes.
///
/// # Panics
/// If the committed artefact is not 64 lowercase hex characters, which would mean
/// M4's anchor changed shape.
#[must_use]
pub fn m4_tensor_digest() -> [u8; 32] {
    let hex = M4_TENSOR_DIGEST_HEX.trim();
    assert_eq!(hex.len(), 64, "M4's tensor digest must be 32 bytes of hex");
    let mut out = [0u8; 32];
    for (i, byte) in out.iter_mut().enumerate() {
        *byte = u8::from_str_radix(&hex[2 * i..2 * i + 2], 16)
            .unwrap_or_else(|_| panic!("digest is not hex at byte {i}"));
    }
    out
}

/// A deterministic collaboration graph derived from fixed bytes: the M4 fixture's
/// digest decides the stream, the same null ensemble the calibration uses decides
/// the shape.
#[must_use]
pub fn graph_from_bytes(bytes: &[u8; 32], n: usize, d_bar: f64) -> Graph {
    let mut rng = Pcg64::from_seed_bytes(bytes);
    Graph::er_h0(&mut rng, n, d_bar)
}

/// [`graph_from_bytes`] on M4's committed digest.
#[must_use]
pub fn m4_wired_graph(n: usize, d_bar: f64) -> Graph {
    graph_from_bytes(&m4_tensor_digest(), n, d_bar)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::detector::{ALPHA_0_01, detect};

    #[test]
    fn digest_is_read_from_m4s_committed_artifact() {
        // The value M4a wrote (src/zk/README.md quotes the same digest).
        assert_eq!(
            M4_TENSOR_DIGEST_HEX.trim(),
            "c2309377a00b109a6c44d83a5cc759108977ffe207fba6f83215a9cdf77d9aa9"
        );
        assert_eq!(m4_tensor_digest().len(), 32);
        assert_eq!(m4_tensor_digest()[0], 0xc2);
        assert_eq!(m4_tensor_digest()[31], 0xa9);
    }

    #[test]
    fn wiring_is_deterministic_and_reaches_the_detector() {
        let a = m4_wired_graph(500, 20.0);
        let b = m4_wired_graph(500, 20.0);
        assert_eq!(a, b, "the wired graph must not depend on the run");
        let d = detect(&a, &ALPHA_0_01);
        assert_eq!(d.n, 500);
        assert!(d.edges > 0.0);
        // A different digest must give a different graph, or the wiring is inert.
        let mut other = m4_tensor_digest();
        other[0] ^= 0x01;
        assert_ne!(graph_from_bytes(&other, 500, 20.0), a);
    }
}
