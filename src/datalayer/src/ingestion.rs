//! `eq:ingestion`: `T[c,d,h] = f_c(events in window h)`, as the interface the
//! paper states, plus the fraud proof that polices it (plan §5.9).
//!
//! The paper fixes `f_c`'s *properties* and not its formula (`main.tex`
//! `sec:datalayer`): it is **public**, **not changeable by the validator**, fixed
//! **before deployment**, **identical for all validators on chain `c`**, and its
//! values lie in `[0,1]`. The events it reads are consensus outputs — "signed
//! attestations, governance votes, and liquidity events that have been finalized on
//! the source chain" — and not subjective judgments.
//!
//! What M7 must **not** do is invent the formula: §5.7 draws the same line for
//! `f_c` that §10's D-7 draws for the `T → W` map, and guessing either would be the
//! same class of error. So this module delivers:
//!
//! - [`Ingestion`], the interface: a chain id, a genesis digest that pins *which*
//!   formula is in force, and `score(window) -> Score` with the range already
//!   enforced by the type;
//! - [`GenesisFormula`], **one declared instance** that satisfies those properties
//!   (`score = WAD · a / (scale + a)`, `a = Σ w_k · n_k`), stated as an
//!   instantiation and not as the paper's formula. Its weights and its scale are
//!   arguments, not constants of this crate: nothing here asserts that any
//!   particular `f_c` is the deployed one;
//! - [`adjudicate`], the fraud proof of `sec:datalayer` ("two state inclusion
//!   proofs against the same source-chain root that yield contradictory values for
//!   a single entry"): a published `(index, entry, Merkle path)` either agrees with
//!   `f_c(events)`, or is fraudulent, or is unproven.
//!
//! Scores are exact integers, never floats: `T` reaches the commitment as a WAD
//! value ([`crate::commitment::Entry::norm_wad`]), and a float rounding here would
//! be a different tensor from the one `AVIPRegistry` verifies.

use crate::commitment::{self, Entry};
use crate::keccak::keccak256;

/// `1e18`: the scale `T[c,d,h] ∈ [0,1]` is held at.
pub const WAD: u128 = 1_000_000_000_000_000_000;

/// A normalized score in `[0,1]`, as an exact WAD integer.
///
/// The range is a property of the type: [`Score::new`] is the only constructor and
/// it refuses anything above [`WAD`], which is what "a normalized score in `[0,1]`"
/// means once the value has to survive being hashed.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct Score(u128);

impl Score {
    /// The floor of the range, `T = 0`.
    pub const ZERO: Score = Score(0);
    /// The ceiling of the range, `T = 1`.
    pub const CEILING: Score = Score(WAD);

    /// The score `wad`, if it is inside `[0,1]`.
    #[must_use]
    pub fn new(wad: u128) -> Option<Self> {
        (wad <= WAD).then_some(Self(wad))
    }

    /// The score as the WAD integer `T` is committed at.
    #[must_use]
    pub fn wad(self) -> u128 {
        self.0
    }

    /// The score as a float, for reading — never for committing.
    #[must_use]
    pub fn as_f64(self) -> f64 {
        self.0 as f64 / WAD as f64
    }
}

/// The finalized consensus events of one window `h`: the three kinds the paper
/// names, counted. The `[c,d,h]` key itself is the caller's: `c` is the chain the
/// formula is for, `d` the domain and `h` the window.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Window {
    /// Signed attestations finalized on the source chain.
    pub attestations: u32,
    /// Governance votes finalized on the source chain.
    pub governance: u32,
    /// Liquidity events finalized on the source chain.
    pub liquidity: u32,
}

impl Window {
    /// Every countable event in the window.
    #[must_use]
    pub fn total(self) -> u64 {
        u64::from(self.attestations) + u64::from(self.governance) + u64::from(self.liquidity)
    }
}

/// `f_c`: the properties of `eq:ingestion`, and nothing about a particular formula.
pub trait Ingestion {
    /// The chain `c` this formula is for — `f_c` is a function of the chain, so two
    /// chains have two formulas and one chain has exactly one.
    fn chain(&self) -> u64;

    /// `keccak256` of the frozen parameters: the digest a deployment publishes so
    /// that "the formula is fixed before deployment" is checkable rather than
    /// promised. Two validators that disagree on how to score will disagree on this.
    fn parameters_digest(&self) -> [u8; 32];

    /// `T[c,d,h]`, in `[0,1]` by construction.
    fn score(&self, window: Window) -> Score;
}

/// The weights a genesis deployment fixes, one per event kind.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Weights {
    /// Weight of one finalized attestation.
    pub attestation: u32,
    /// Weight of one finalized governance vote.
    pub governance: u32,
    /// Weight of one finalized liquidity event.
    pub liquidity: u32,
}

impl Weights {
    /// `a = Σ w_k · n_k`, the window's weighted event mass.
    ///
    /// The bound is what keeps the score exact: with `u32` counts and `u32` weights,
    /// `a ≤ 3·(2³²−1)² ≈ 5.5·10¹⁹`, so `WAD·a ≈ 5.5·10³⁷ < 2¹²⁸` and the numerator
    /// below never saturates.
    #[must_use]
    pub fn mass(self, window: Window) -> u128 {
        u128::from(self.attestation) * u128::from(window.attestations)
            + u128::from(self.governance) * u128::from(window.governance)
            + u128::from(self.liquidity) * u128::from(window.liquidity)
    }
}

/// **One declared instance** of [`Ingestion`] — an instantiation that satisfies the
/// paper's properties, not the paper's `f_c`.
///
/// `score = WAD · a / (scale + a)` with `a` the window's weighted mass: non-negative,
/// strictly increasing in `a`, below `1` for every finite `a`, and computed with
/// integer division so two validators cannot disagree by a rounding mode. Its three
/// weights and its `scale` are the deployment's, taken as arguments — this crate
/// asserts no particular value for them.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct GenesisFormula {
    chain: u64,
    weights: Weights,
    scale: u64,
    digest: [u8; 32],
}

impl GenesisFormula {
    /// Freeze a formula for chain `c`. The digest is `keccak256` of the five
    /// parameters, one 32-byte word each — an encoding this crate states rather than
    /// borrows, because what must be identical for every validator is *which*
    /// formula is in force, not how it is written down.
    #[must_use]
    pub fn freeze(chain: u64, weights: Weights, scale: u64) -> Self {
        assert!(scale > 0, "a genesis formula needs a positive scale");
        let mut buf = [0_u8; 160];
        let mut word = |i: usize, value: u128| {
            buf[i * 32 + 16..(i + 1) * 32].copy_from_slice(&value.to_be_bytes());
        };
        word(0, u128::from(chain));
        word(1, u128::from(weights.attestation));
        word(2, u128::from(weights.governance));
        word(3, u128::from(weights.liquidity));
        word(4, u128::from(scale));
        Self {
            chain,
            weights,
            scale,
            digest: keccak256(&buf),
        }
    }

    /// The formula's weights.
    #[must_use]
    pub fn weights(&self) -> Weights {
        self.weights
    }

    /// The formula's scale.
    #[must_use]
    pub fn scale(&self) -> u64 {
        self.scale
    }
}

impl Ingestion for GenesisFormula {
    fn chain(&self) -> u64 {
        self.chain
    }

    fn parameters_digest(&self) -> [u8; 32] {
        self.digest
    }

    fn score(&self, window: Window) -> Score {
        let a = self.weights.mass(window);
        let numerator = WAD.checked_mul(a).expect("a <= 3*(2^32-1)^2 < 2^128 / WAD");
        // `a < scale + a`, so the quotient is strictly below `WAD`: the range the
        // paper states is a theorem here, not a clamp.
        Score::new(numerator / (u128::from(self.scale) + a)).expect("a/(scale + a) < 1")
    }
}

/// One published entry of `T`, with the witness that ties it to the committed
/// tensor: its leaf position and the Merkle path `AVIPRegistry.verifyEntry` checks.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Published {
    /// The entry's index among the epoch's leaves.
    pub index: usize,
    /// The leaf: the validator and the value it was published at.
    pub entry: Entry,
    /// The siblings, bottom-up, in `verifyEntry`'s order.
    pub path: Vec<[u8; 32]>,
}

/// What a fraud proof established about one published entry.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Verdict {
    /// The entry is in the committed tensor and its value is `f_c(events)`.
    Consistent,
    /// The entry is in the committed tensor and its value is **not** `f_c(events)`:
    /// the fraud `sec:datalayer` punishes, with the bounty `B` for the reporter and
    /// the slash for the validator.
    Fraud {
        /// The value the validator published.
        published_wad: u128,
        /// The value `f_c(events)` gives, which the reporter recomputed.
        formula_wad: u128,
    },
    /// The witness does not link the entry to the root, so nothing is established —
    /// not a fraud proof, and never a reason to slash.
    Unproven,
}

/// `sec:datalayer`'s fraud proof, in the shape it can actually take.
///
/// The paper phrases it as "two state inclusion proofs against the same source-chain
/// root that yield contradictory values for a single entry `T[c,d,h]`". Against the
/// tensor's own Merkle root that pair is *unsatisfiable by construction*: a leaf has
/// one value, so two proofs that both verify open the same position to the same
/// value, and a second proof with another value simply fails to verify. That
/// unsatisfiability **is** the binding property, and the test below asserts it rather
/// than pretending to catch a contradiction that cannot exist in the tree.
///
/// The fraud that *can* exist is the one this function catches, and it is the same
/// misconduct: the published value is not what the public, genesis-frozen `f_c`
/// computes from the finalized events. The adjudicator recomputes `f_c`, checks the
/// inclusion proof, and can tell the two apart — which is exactly why the paper can
/// require `f_c` to be public, deterministic and fixed before deployment.
#[must_use]
pub fn adjudicate(
    root: &[u8; 32],
    published: &Published,
    formula: &impl Ingestion,
    window: Window,
) -> Verdict {
    if !commitment::verify_entry(root, &published.entry.payload(), &published.path) {
        return Verdict::Unproven;
    }
    let expected = formula.score(window).wad();
    if published.entry.norm_wad == expected {
        Verdict::Consistent
    } else {
        Verdict::Fraud {
            published_wad: published.entry.norm_wad,
            formula_wad: expected,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::commitment::Epoch;

    fn weights() -> Weights {
        Weights {
            attestation: 3,
            governance: 5,
            liquidity: 2,
        }
    }

    fn window() -> Window {
        Window {
            attestations: 40,
            governance: 7,
            liquidity: 3,
        }
    }

    fn formula() -> GenesisFormula {
        GenesisFormula::freeze(43113, weights(), 1_000)
    }

    /// Distinct, non-zero addresses, as `commitment.rs` builds them.
    fn validator_of(i: u128) -> [u8; 20] {
        let mut addr = [0_u8; 20];
        addr[4..].copy_from_slice(&(i + 1).to_be_bytes());
        addr
    }

    fn published(epoch: &Epoch, index: usize) -> Published {
        Published {
            index,
            entry: epoch.entries[index],
            path: epoch
                .inclusion_proof(index)
                .expect("an index inside the epoch"),
        }
    }

    /// `[0,1]` is a property of `Score`, not a clamp applied somewhere downstream.
    #[test]
    fn the_score_range_is_a_property_of_the_type() {
        assert_eq!(Score::ZERO.wad(), 0);
        assert_eq!(Score::CEILING.wad(), WAD);
        assert_eq!(Score::CEILING.as_f64(), 1.0);
        assert!(Score::new(WAD).is_some(), "the ceiling itself is a score");
        assert!(Score::new(WAD + 1).is_none(), "above the ceiling is not");
    }

    /// The genesis digest pins *which* formula is in force: change any parameter and
    /// a validator computing the same digest is telling a different story.
    #[test]
    fn the_genesis_digest_pins_the_formula() {
        let f = formula();
        assert_eq!(f.chain(), 43113);
        assert_eq!(f.weights(), weights());
        assert_eq!(f.scale(), 1_000);
        assert_eq!(
            f.parameters_digest(),
            GenesisFormula::freeze(43113, weights(), 1_000).parameters_digest(),
            "the same parameters freeze to the same digest"
        );
        for other in [
            GenesisFormula::freeze(43114, weights(), 1_000),
            GenesisFormula::freeze(
                43113,
                Weights {
                    attestation: 4,
                    ..weights()
                },
                1_000,
            ),
            GenesisFormula::freeze(43113, weights(), 1_001),
        ] {
            assert_ne!(f.parameters_digest(), other.parameters_digest());
        }
        assert_ne!(f.parameters_digest(), [0_u8; 32]);
    }

    /// Deterministic, monotone in the event mass, and strictly inside `[0,1]`.
    #[test]
    fn the_instance_is_deterministic_and_inside_the_range() {
        let f = formula();
        assert_eq!(
            f.score(Window::default()),
            Score::ZERO,
            "no events, no score"
        );

        let one = f.score(Window {
            attestations: 1,
            ..Window::default()
        });
        let many = f.score(Window {
            attestations: u32::MAX,
            governance: u32::MAX,
            liquidity: u32::MAX,
        });
        assert!(one > Score::ZERO && one < many, "more events, more score");
        assert!(many < Score::CEILING, "1 is the limit, not a value");
        assert_eq!(f.score(window()), f.score(window()), "no state, no drift");
        assert!(f.score(window()).as_f64() > 0.0);
    }

    /// The fraud the paper punishes: the value is in the committed tensor, and it is
    /// not what `f_c(events)` computes.
    #[test]
    fn a_value_that_is_not_the_formula_is_fraud() {
        let f = formula();
        let honest = f.score(window()).wad();
        let epoch = Epoch::new(
            1,
            vec![Entry {
                validator: validator_of(0),
                norm_wad: honest,
            }],
        );
        assert_eq!(
            adjudicate(&epoch.root(), &published(&epoch, 0), &f, window()),
            Verdict::Consistent
        );

        // The same leaf re-hashed at a lying value: the witness is valid *for the
        // lying root*, so it is the value that convicts, not the path.
        let lying = Epoch::new(
            1,
            vec![Entry {
                validator: validator_of(0),
                norm_wad: honest + 1,
            }],
        );
        assert_ne!(epoch.root(), lying.root(), "a value change moves the root");
        assert_eq!(
            adjudicate(&lying.root(), &published(&lying, 0), &f, window()),
            Verdict::Fraud {
                published_wad: honest + 1,
                formula_wad: honest,
            }
        );

        // And the honest witness no longer verifies against the lying root: an
        // unproven claim is never a reason to slash.
        assert_eq!(
            adjudicate(&lying.root(), &published(&epoch, 0), &f, window()),
            Verdict::Unproven
        );
    }

    /// The binding property, asserted as unsatisfiability: two proofs against one
    /// root cannot open one position to two values, because a leaf has one value.
    #[test]
    fn the_root_binds_every_value_it_commits() {
        let f = formula();
        let honest = f.score(window()).wad();
        let epoch = Epoch::new(
            1,
            (0..4)
                .map(|i| Entry {
                    validator: validator_of(i),
                    norm_wad: honest + i,
                })
                .collect(),
        );
        let root = epoch.root();

        let mut forged = published(&epoch, 2);
        forged.entry.norm_wad += 1;
        assert_eq!(
            adjudicate(&root, &forged, &f, window()),
            Verdict::Unproven,
            "the same path, another value: the path stops verifying"
        );

        // A first index outside the epoch has no path at all.
        assert!(epoch.inclusion_proof(epoch.entries.len()).is_none());
        assert!(epoch.inclusion_proof(0).is_some());
    }
}
