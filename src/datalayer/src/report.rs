//! The pinned table (`scripts/m7b_output.txt`).
//!
//! Sections, in the order the acceptance criteria of plan §5.9 are stated:
//!
//! 1. the sealed audit equilibrium (`simulate_data_layer_v3.py`), reproduced row by
//!    row: `B*`, `n*(B)` floored and capped, coverage, detections, the attacker's
//!    and the verifier's profit, integrity;
//! 2. the binomial transcription, against numpy's own draws, with the stream
//!    consumption measured rather than assumed — because that measurement is *why*
//!    two rows of the sealed table print different fraud means for one model;
//! 3. `eq:ingestion`'s `f_c` as an interface, one declared instance of it, and the
//!    fraud proof `sec:datalayer` describes;
//! 4. provenance, so the file states what was resumed, what is declared, and what
//!    this milestone deliberately does not do.
//!
//! Everything here is deterministic and nothing is timed into the file: the
//! durations go to stderr, which is the discipline M5's and M6's pinned tables
//! follow.

use std::io::Write;

use crate::equilibrium::{self, B_GRID, N_ATTESTATIONS, N_VERIFIERS};
use crate::ingestion::{self, Ingestion, Published, Verdict, Window};
use crate::{commitment, fixture, line};

/// The `=` rule of the sealed scripts.
pub const SEP: &str =
    "==============================================================================";
/// The `-` rule of the sealed scripts.
pub const SUB: &str =
    "------------------------------------------------------------------------------";

/// What the report computed, for `main.rs` to print to stderr and to gate on.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Outcome {
    /// Whether every check in the report passed.
    pub all_pass: bool,
    /// Rows of the equilibrium table.
    pub rows: usize,
    /// numpy draws the transcription was checked on.
    pub draws: usize,
    /// Groups of `fixtures/numpy_binomial_seed42.txt` that matched.
    pub groups_ok: usize,
}

/// The chain the declared instance is for: Fuji, the network the rest of the
/// workspace targets. Nothing in this crate asserts that this formula is deployed.
const CHAIN: u64 = 43113;

/// The declared instance's scale: `score = WAD · a / (scale + a)`.
const SCALE: u64 = 1_000;

/// A declared window of finalized events, for the numbers of section 3.
const WINDOW: Window = Window {
    attestations: 40,
    governance: 7,
    liquidity: 3,
};

/// A declared validator address, for the epoch the fraud proof is checked against.
const VALIDATOR: [u8; 20] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1];

/// `PASS`/`FAIL`.
fn pass(ok: bool) -> &'static str {
    if ok { "PASS" } else { "FAIL" }
}

/// `0x`-prefixed lowercase hex, for digests and roots.
fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

/// A row of the sealed table is nine numbers and nothing else: the column header
/// has letters and the notes have prose, so this is exactly the shape a line of data
/// has — and it is what lets section 1 re-emit the sealed prose while *computing*
/// every number.
fn is_data_row(text: &str) -> bool {
    let mut columns = 0;
    for token in text.split_whitespace() {
        if token.parse::<f64>().is_err() {
            return false;
        }
        columns += 1;
    }
    columns == 9
}

/// One row, in the sealed script's own format string
/// (`f"{B:>6.2f} {n:>5d} {cov:>5.2f} ..."`), so the reproduction is comparable byte
/// for byte with the sealed file rather than merely close.
#[must_use]
pub fn render_row(s: &equilibrium::Scenario) -> String {
    format!(
        "{:>6.2} {:>5} {:>5.2} {:>10.1} {:>10.1} {:>10.3} {:>11.2} {:>11.2} {:>11.4}",
        s.b,
        s.n_auditors,
        s.coverage,
        s.frauds_mean,
        s.detections_mean,
        s.detection_rate,
        s.attacker_profit,
        s.verifier_profit,
        s.integrity,
    )
}

/// The sealed file, reproduced into `block`: its prose re-emitted from
/// `fixtures/sealed_reference.txt`, every numeric row computed here.
fn sealed_block(block: &mut Vec<u8>) {
    let table = equilibrium::table();
    let mut row = 0;
    for text in fixture::SEALED.lines() {
        if text.trim_start().starts_with('#') {
            continue;
        }
        if is_data_row(text) {
            if let Some(scenario) = table.get(row) {
                line(block, &render_row(scenario));
                row += 1;
            }
            continue;
        }
        line(block, text);
    }
    assert_eq!(row, table.len(), "every sealed row was reproduced");
}

/// Section 1: the sealed equilibrium, reproduced and then compared with the copy of
/// the sealed file.
fn section_sealed(out: &mut impl Write) -> bool {
    line(
        out,
        "1. THE SEALED AUDIT EQUILIBRIUM, REPRODUCED ROW BY ROW",
    );
    line(out, SUB);
    line(
        out,
        "   Source: verification/data-layer/simulate_data_layer_v3.py, sealed, never",
    );
    line(
        out,
        "   edited by M7b. Model: p_fraud = beta*p_fake = 0.2*0.5 = 0.10;",
    );
    line(
        out,
        "   B* = c_audit / p_fraud; n*(B) = B < B* ? 0 : min(floor(B/B*), N_VERIFIERS).",
    );
    line(
        out,
        "   Below is the sealed file, line for line: its prose comes from",
    );
    line(
        out,
        "   fixtures/sealed_reference.txt and every numeric row is computed here, from",
    );
    line(
        out,
        "   the transcribed binomial on a default_rng(42) restarted per row.",
    );
    line(out, SUB);

    let mut block = Vec::new();
    sealed_block(&mut block);
    let text = String::from_utf8(block.clone()).expect("the sealed block is ASCII prose");
    out.write_all(&block).expect("stdout is writable");
    line(out, SUB);

    let sealed: Vec<&str> = fixture::SEALED
        .lines()
        .filter(|l| !l.trim_start().starts_with('#') && !l.trim().is_empty())
        .collect();
    let missing: Vec<&&str> = sealed.iter().filter(|l| !text.contains(**l)).collect();
    for l in &missing {
        line(out, &format!("   missing from the reproduction: {l}"));
    }
    let ok = missing.is_empty();
    line(
        out,
        &format!(
            "   every line of the sealed file, byte for byte ....... {} ({} lines)",
            pass(ok),
            sealed.len()
        ),
    );
    line(
        out,
        &format!(
            "   {} rows x {} epochs; the stream restarts per row, as the script does",
            B_GRID.len(),
            equilibrium::N_EPOCHS,
        ),
    );
    line(
        out,
        &format!(
            "   p_fraud = {:.2}, B* = {:.4}, N_ATTESTATIONS = {}, N_VERIFIERS = {}",
            equilibrium::p_fraud(),
            equilibrium::b_star(),
            N_ATTESTATIONS,
            N_VERIFIERS,
        ),
    );
    line(
        out,
        &format!(
            "   n*(0.25) = {}, n*(B*) = {}, n*(1.5) = {}, n*(25) = {} ....... {}",
            equilibrium::equilibrium_auditors(0.25, equilibrium::b_star()),
            equilibrium::equilibrium_auditors(1.0, equilibrium::b_star()),
            equilibrium::equilibrium_auditors(1.5, equilibrium::b_star()),
            equilibrium::equilibrium_auditors(25.0, equilibrium::b_star()),
            pass(
                equilibrium::equilibrium_auditors(1.0, equilibrium::b_star()) == 1
                    && equilibrium::equilibrium_auditors(1.5, equilibrium::b_star()) == 1
                    && equilibrium::equilibrium_auditors(25.0, equilibrium::b_star())
                        == N_VERIFIERS
            )
        ),
    );
    line(
        out,
        "   floor, not round: the script says so, and n*(1.5) = 1 above is that",
    );
    line(
        out,
        "   sentence as a number. The cap shows up twice: n*(20) = n*(25) = 20, and",
    );
    line(
        out,
        "   the verifier's profit rises again at B = 25 while the cost stays pinned.",
    );
    line(out, &format!("   verdict = {}", pass(ok)));
    line(out, "");
    ok
}

/// Section 2: the transcription, and the measurement that explains the table.
fn section_transcription(out: &mut impl Write) -> fixture::Transcription {
    line(
        out,
        "2. THE BINOMIAL TRANSCRIPTION (numpy 2.2.6 random_binomial)",
    );
    line(out, SUB);
    line(
        out,
        "   fixture: fixtures/numpy_binomial_seed42.txt, numpy's own draws, ten groups",
    );
    line(
        out,
        "   covering BTPE, inversion and both mirrored p > 0.5 branches.",
    );
    let verdict = fixture::transcription();
    line(
        out,
        &format!(
            "   groups matched .................... {}/{}",
            verdict.groups_ok,
            fixture::GROUPS.len()
        ),
    );
    line(
        out,
        &format!("   draws compared .................... {}", verdict.draws),
    );
    if let Some((group, index, numpy, rust)) = &verdict.divergence {
        line(
            out,
            &format!(
                "   first divergence .................. {group}[{index}]: numpy {numpy}, rust {rust}"
            ),
        );
    }
    line(
        out,
        "   stream consumption, measured against advance(k), not assumed:",
    );
    for (call, doubles) in fixture::consumption() {
        let shown = match doubles {
            Some(d) => format!("{d} double(s)"),
            None => "more than 64, a rejection loop".to_string(),
        };
        line(out, &format!("     {call:<20} -> {shown}"));
    }
    line(
        out,
        "   Why two rows of section 1 print different fraud means for one model:",
    );
    line(
        out,
        "   with coverage = 0.0 the detection draw binomial(n_frauds, 0.0) returns 0",
    );
    line(
        out,
        "   before consuming a double, so the fraud draw is the first draw of every",
    );
    line(
        out,
        "   epoch; with coverage = 1.0 the same call consumes one (p = 1 lands in",
    );
    line(
        out,
        "   inversion), so the fraud draw is every second. One PCG64 stream from seed",
    );
    line(
        out,
        "   42, displaced by that single double: 49.914 and 50.2 are the same model",
    );
    line(
        out,
        "   read at two offsets, not two models. n*p = 50 > 30, so both draws go",
    );
    line(out, "   through BTPE.");
    line(
        out,
        "   declared deviation: Step30/Step40 cast a double that can be far outside",
    );
    line(
        out,
        "   int64 range - undefined in C, saturating in Rust. Both reject and redraw,",
    );
    line(
        out,
        "   so the draws agree; bin/m7b-probe prints the same sentence.",
    );
    line(out, &format!("   verdict = {}", pass(verdict.holds())));
    line(out, "");
    verdict
}

/// Section 3: `eq:ingestion` as an interface, one declared instance, and the fraud
/// proof.
fn section_ingestion(out: &mut impl Write) -> bool {
    line(
        out,
        "3. THE INGESTION FORMULA f_c (eq:ingestion) AND THE FRAUD PROOF",
    );
    line(out, SUB);
    line(
        out,
        "   The paper fixes f_c's properties, not its formula: public, not changeable",
    );
    line(
        out,
        "   by the validator, fixed before deployment, identical for every validator on",
    );
    line(
        out,
        "   chain c, values in [0,1]. M7 does not invent the formula - the same line",
    );
    line(
        out,
        "   §5.7 draws for the T -> W map. What the crate carries is the interface:",
    );
    line(
        out,
        "   Ingestion { chain, parameters_digest, score -> Score }, with Score a WAD",
    );
    line(
        out,
        "   integer in [0, 1e18] by construction, never a float.",
    );

    let weights = ingestion::Weights {
        attestation: 3,
        governance: 5,
        liquidity: 2,
    };
    let formula = ingestion::GenesisFormula::freeze(CHAIN, weights, SCALE);
    let window = WINDOW;
    let score = formula.score(window);
    line(out, "   one declared instance, and NOT the paper's f_c:");
    line(
        out,
        &format!("     chain c ......................... {}", formula.chain()),
    );
    line(
        out,
        &format!(
            "     weights (att, gov, liq) ......... {} / {} / {}",
            weights.attestation, weights.governance, weights.liquidity
        ),
    );
    line(
        out,
        &format!("     scale ........................... {}", formula.scale()),
    );
    line(
        out,
        &format!(
            "     genesis digest .................. 0x{}",
            hex(&formula.parameters_digest())
        ),
    );
    line(
        out,
        &format!(
            "     score(no events) ................ {} WAD",
            formula.score(Window::default()).wad()
        ),
    );
    line(
        out,
        &format!(
            "     score(({}, {}, {})) .......... {} WAD = {:.6}",
            window.attestations,
            window.governance,
            window.liquidity,
            score.wad(),
            score.as_f64()
        ),
    );

    let honest = score.wad();
    let epoch = commitment::Epoch::new(
        1,
        vec![commitment::Entry {
            validator: VALIDATOR,
            norm_wad: honest,
        }],
    );
    let root = epoch.root();
    let published = Published {
        index: 0,
        entry: epoch.entries[0],
        path: epoch
            .inclusion_proof(0)
            .expect("index 0 is inside the epoch"),
    };
    let committed = ingestion::adjudicate(&root, &published, &formula, window);
    let lying_epoch = commitment::Epoch::new(
        1,
        vec![commitment::Entry {
            validator: VALIDATOR,
            norm_wad: honest + 1,
        }],
    );
    let lying = Published {
        index: 0,
        entry: lying_epoch.entries[0],
        path: lying_epoch
            .inclusion_proof(0)
            .expect("index 0 is inside the epoch"),
    };
    let fraudulent = ingestion::adjudicate(&lying_epoch.root(), &lying, &formula, window);
    let unproven = ingestion::adjudicate(&lying_epoch.root(), &published, &formula, window);
    let mut forged = published.clone();
    forged.entry.norm_wad += 1;
    let binding = ingestion::adjudicate(&root, &forged, &formula, window);

    line(
        out,
        "   the fraud proof, on an epoch committed at f_c's own value:",
    );
    line(
        out,
        &format!(
            "     the committed value is f_c(events) .............. {}",
            if committed == Verdict::Consistent {
                "Consistent"
            } else {
                "NOT consistent"
            }
        ),
    );
    line(
        out,
        &format!(
            "     re-hashed at value + 1 (root 0x{}..) ...... {}",
            &hex(&lying_epoch.root())[..8],
            match fraudulent {
                Verdict::Fraud {
                    published_wad,
                    formula_wad,
                } => format!("Fraud: published {published_wad}, f_c {formula_wad}"),
                other => format!("{other:?}"),
            }
        ),
    );
    line(
        out,
        &format!(
            "     the honest witness against the lying root ....... {}",
            if unproven == Verdict::Unproven {
                "Unproven (never a slash)"
            } else {
                "NOT unproven"
            }
        ),
    );
    line(
        out,
        &format!(
            "     one value, one leaf: a second opening of the ... {}",
            if binding == Verdict::Unproven {
                "same position does not verify"
            } else {
                "position verified - binding broken"
            }
        ),
    );
    line(
        out,
        "   The paper phrases the proof as two inclusion proofs against one root with",
    );
    line(
        out,
        "   contradictory values. Against the tensor's own Merkle root that pair is",
    );
    line(
        out,
        "   unsatisfiable - a leaf has one value - and that unsatisfiability *is* the",
    );
    line(
        out,
        "   binding property. The misconduct that can exist is the value above: a",
    );
    line(
        out,
        "   published value that is not f_c(events), which is why f_c has to be public,",
    );
    line(
        out,
        "   deterministic and frozen before deployment for the adjudicator to tell the",
    );
    line(out, "   two apart.");
    let ok = committed == Verdict::Consistent
        && matches!(fraudulent, Verdict::Fraud { .. })
        && unproven == Verdict::Unproven
        && binding == Verdict::Unproven;
    line(out, &format!("   verdict = {}", pass(ok)));
    line(out, "");
    ok
}

/// Section 4: what was resumed, what is declared, and what this milestone does not
/// do — the last part being what keeps the file honest.
fn section_provenance(out: &mut impl Write) {
    line(out, "4. PROVENANCE, MODE, AND WHAT THIS TABLE IS NOT");
    line(out, SUB);
    line(out, "   sealed inputs, read and never edited by M7b:");
    line(
        out,
        "     verification/data-layer/simulate_data_layer_v3.py",
    );
    line(
        out,
        "     verification/data-layer/results/simulate_data_layer_v3_output.txt",
    );
    line(out, "   written for this milestone:");
    line(
        out,
        "     binomial.rs   - numpy's binomial, transcribed and checked in section 2",
    );
    line(out, "   resumed unchanged from earlier milestones:");
    line(
        out,
        "     pcg64.rs      - M5's generator, its own fixture, no re-derivation",
    );
    line(
        out,
        "     commitment.rs - M6's epoch -> root, carried over unchanged so the digest",
    );
    line(
        out,
        "                     the registry verifies has one implementation",
    );
    line(
        out,
        "   mode ......... exact; no draw here is approximated, and none is sampled",
    );
    line(out, "                  twice");
    line(out, "   deliberately not done here:");
    line(
        out,
        "     - no f_c formula is asserted: section 3's instance is declared, and",
    );
    line(out, "       which f_c is in force is fixed at genesis;");
    line(
        out,
        "     - the T -> W collaboration map is open (plan §10 D-7), so nothing here",
    );
    line(out, "       derives a graph from the tensor;");
    line(
        out,
        "     - no transport: the root is not sent anywhere, no Teleporter message is",
    );
    line(out, "       built, and no source-chain quorum is read;");
    line(
        out,
        "     - no Pedersen <-> Merkle bridge: that is M7c, and until it exists the",
    );
    line(
        out,
        "       norm proof and the published root are not tied together in code;",
    );
    line(
        out,
        "     - no funds: B and S_slash are model parameters, and the escrow and the",
    );
    line(out, "       burn are M8's;");
    line(
        out,
        "     - no security, liveness or economic claim about a deployed registry:",
    );
    line(
        out,
        "       this file reproduces a model, it is not evidence about a chain.",
    );
    line(
        out,
        "   the checks that keep this honest, outside the crate:",
    );
    line(
        out,
        "     scripts/m7b_report.sh - the table against the sealed file in both",
    );
    line(
        out,
        "       directions, plus every 4-decimal number of the sealed file surviving",
    );
    line(out, "       somewhere in the reproduction");
    line(out, "");
}

/// Write the whole report and return what it found.
pub fn write(out: &mut impl Write) -> Outcome {
    line(out, SEP);
    line(
        out,
        "M7b - DATA LAYER: THE AUDIT EQUILIBRIUM AND THE INGESTION FORMULA",
    );
    line(out, SEP);
    line(out, "");
    line(
        out,
        "Stream: numpy.random.default_rng(42), resumed bit for bit by pcg64.rs;",
    );
    line(
        out,
        "        restarted per row, exactly as the sealed script does.",
    );
    line(
        out,
        "Mode:   exact - every draw is numpy's own, and 3306 of them are compared",
    );
    line(
        out,
        "        against numpy's output in section 2. The tables are pinned:",
    );
    line(out, "        regenerate them rather than editing them.");
    line(out, "");

    let sealed = section_sealed(out);
    let transcription = section_transcription(out);
    let ingestion_ok = section_ingestion(out);
    section_provenance(out);

    let all_pass = sealed && transcription.holds() && ingestion_ok;
    line(out, SEP);
    line(out, &format!("OVERALL: {}", pass(all_pass)));
    line(out, SEP);
    Outcome {
        all_pass,
        rows: B_GRID.len(),
        draws: transcription.draws,
        groups_ok: transcription.groups_ok,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn rendered() -> String {
        let mut out = Vec::new();
        let outcome = write(&mut out);
        assert!(outcome.all_pass, "the report's own checks hold");
        String::from_utf8(out).expect("the report is text")
    }

    /// No clock and no randomness: the pinned table cannot drift between two runs.
    #[test]
    fn the_report_holds_and_is_deterministic() {
        assert_eq!(rendered(), rendered());
    }

    /// Every sealed data row appears in the reproduction, byte for byte.
    #[test]
    fn the_reproduction_carries_the_sealed_rows() {
        let text = rendered();
        let rows: Vec<&str> = fixture::SEALED.lines().filter(|l| is_data_row(l)).collect();
        assert_eq!(rows.len(), B_GRID.len());
        for row in rows {
            assert!(text.contains(row), "row not reproduced: {row}");
        }
    }

    /// The reproduction uses the sealed script's own format: nine numeric columns,
    /// 87 characters wide, so a diff against the sealed file is readable.
    #[test]
    fn a_row_is_the_sealed_scripts_own_format() {
        let table = equilibrium::table();
        assert_eq!(table.len(), B_GRID.len());
        for scenario in &table {
            let row = render_row(scenario);
            assert!(is_data_row(&row), "not a data row: {row:?}");
            assert_eq!(row.len(), 87, "the sealed row width: {row:?}");
        }
    }

    /// The header and the notes of the sealed file are prose, never mistaken for
    /// data — the distinction section 1 depends on.
    #[test]
    fn only_numeric_rows_are_data_rows() {
        let header = fixture::SEALED
            .lines()
            .find(|l| l.contains("Integridad"))
            .expect("the sealed column header");
        assert!(!is_data_row(header));
        for note in fixture::SEALED
            .lines()
            .filter(|l| l.trim_start().starts_with("1. ") || l.trim_start().starts_with("5. "))
        {
            assert!(!is_data_row(note), "prose read as data: {note}");
        }
    }
}
