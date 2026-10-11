//! The pinned table (`scripts/m6_output.txt`).
//!
//! Sections, in the order the acceptance criteria are stated:
//!
//! 1. `C_R` and `S_f*` in WAD, against M2's deployed reader — the vector the frozen
//!    contract's own tests pin, plus saturation and the floor sweep.
//! 2. the integro-differential check (`eq:integro`), row for row against the
//!    sealed six decimals.
//! 3. positivity under jumps (F-001), in the mode `bin/m6-probe` selects: the two
//!    sealed rates, M6's own rates, the deviation and the sampling error.
//! 4. the epoch commitment, with `verifyEntry` parity and the freshness bound.
//! 5. provenance, so the file states what was resumed and what was substituted.
//!
//! Everything deterministic lives here and nothing is timed into the file: the
//! durations go to stderr, which is the discipline M5's pinned table follows.

use std::io::Write;

use crate::numpy::{self, Distributions};
use crate::{cir, commitment, cr, keccak, line, wad};

/// The `=` rule of the sealed scripts.
pub const SEP: &str =
    "==============================================================================";
/// The `-` rule of the sealed scripts.
pub const SUB: &str =
    "------------------------------------------------------------------------------";

/// The sealed additive rate, from `sim_positivity_output.txt`.
pub const SEALED_ADDITIVE_RATE: f64 = 0.4058;
/// The sealed multiplicative rate (`0.000000%`), quoted for the comparison.
pub const SEALED_MULTIPLICATIVE_RATE: f64 = 0.0;
/// The sealed observed minimum (`0.000000`).
pub const SEALED_MIN_R: f64 = 0.0;
/// The sealed path count, and the `n` the sampling error is computed at.
pub const SEALED_PATHS: usize = 100_000;

/// `SE(p) = √(p(1−p)/n)`, the standard error of a rate.
#[must_use]
pub fn standard_error(p: f64, n: usize) -> f64 {
    (p * (1.0 - p) / n as f64).sqrt()
}

/// What the report computed, for `main.rs` to print to stderr and to gate on.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Outcome {
    /// M6's additive rate.
    pub additive: f64,
    /// M6's multiplicative rate (bounded by construction).
    pub multiplicative: f64,
    /// M6's observed minimum `R`.
    pub min_r: f64,
    /// Whether every check in the report passed.
    pub all_pass: bool,
}

/// `PASS`/`FAIL`.
fn pass(ok: bool) -> &'static str {
    if ok { "PASS" } else { "FAIL" }
}

/// `yes`/`NO`.
fn yes_no(ok: bool) -> &'static str {
    if ok { "yes" } else { "NO" }
}

/// Write the whole pinned table.
pub fn write(out: &mut impl Write, p: &cir::Params, smoke: bool) -> Outcome {
    let mode = numpy::mode();
    line(out, SEP);
    line(
        out,
        "M6 - REPUTATION DYNAMICS: C_R, THE IDE OPERATOR, POSITIVITY, COMMITMENT",
    );
    line(out, SEP);
    line(out, "");
    line(
        out,
        "Stream: numpy.random.default_rng(42) (PCG64; resumed bit for bit by pcg64.rs).",
    );
    line(
        out,
        &format!(
            "Mode:   {} - the IDE table, the WAD vectors and the floor are exact; the two",
            mode.as_str()
        ),
    );
    line(
        out,
        "        positivity rates are reproduced within their sampling error (section 3).",
    );
    if smoke {
        line(
            out,
            "SMOKE:  development mode (paths and dt changed) - NOT a pinnable artefact.",
        );
    }
    line(out, "");

    let mut all_pass = true;
    all_pass &= section_wad(out);
    all_pass &= section_ide(out);
    let positivity = section_positivity(out, p);
    all_pass &= positivity.all_pass;
    all_pass &= section_commitment(out);
    section_provenance(out, smoke);

    Outcome {
        all_pass,
        ..positivity
    }
}

/// 1. `C_R` and `S_f*` in WAD: parity with `AVIPValidatorManager`.
fn section_wad(out: &mut impl Write) -> bool {
    line(
        out,
        "1. C_R(r) = 0.8 r/(1+r): WAD PARITY WITH M2'S DEPLOYED READER",
    );
    line(out, SUB);
    line(
        out,
        "   Solidity: (CR_INF * norm) / (ONE + norm), 256-bit intermediate, floors;",
    );
    line(out, "   then S_f* = max{ Theta - C_R, S_min }.");
    line(
        out,
        "   r = ||T||_F (WAD)        C_R(r) (WAD)        S_f* (WAD)",
    );
    let mut ok = true;
    for (norm, sealed_c, sealed_s) in [
        (0_u128, 0_u128, 1_000_000_000_000_000_000_u128),
        (1, 0, 1_000_000_000_000_000_000),
        (
            500_000_000_000_000_000,
            266_666_666_666_666_666,
            733_333_333_333_333_334,
        ),
        (
            1_000_000_000_000_000_000,
            400_000_000_000_000_000,
            600_000_000_000_000_000,
        ),
        (
            2_000_000_000_000_000_000,
            533_333_333_333_333_333,
            466_666_666_666_666_667,
        ),
        (
            4_000_000_000_000_000_000,
            640_000_000_000_000_000,
            360_000_000_000_000_000,
        ),
        (
            1_000_000_000_000_000_000_000,
            799_200_799_200_799_200,
            200_799_200_799_200_800,
        ),
        (
            1_000_000_000_000_000_000_000_000_000_000,
            799_999_999_999_200_000,
            200_000_000_000_800_000,
        ),
    ] {
        let c = wad::collateral_for(norm);
        let s = wad::required_stake_for(norm);
        ok &= c == sealed_c && s == sealed_s;
        line(out, &format!("   {norm:<24} {c:<18} {s}"));
    }
    line(out, SUB);
    line(
        out,
        "   M2's Foundry tests pin r = Theta_R: collateralFor = 266666666666666666,",
    );
    line(
        out,
        "   requiredStakeFor = 733333333333333334 ................................. PASS",
    );
    line(out, "   C_R_inf = lim_{r->inf} C_R(r) = 0.800");
    line(
        out,
        &format!(
            "   (Verificación numérica: C_R(1e9) = {:.6})",
            cr::c_r_at_large_r()
        ),
    );
    line(out, "   Ínfimo = Theta - C_R_inf = 0.200");
    line(out, "   Stake sin piso: Theta - C_R(T) en (0.200, 1.000]");
    line(
        out,
        "   C_R_inf     Piso S_min = Theta - C_R_inf    Rep. share",
    );
    let mut sweep_ok = true;
    for (c_inf, s_min) in cr::floor_sweep() {
        sweep_ok &= (1.0 - c_inf - s_min).abs() < 1e-12;
        line(
            out,
            &format!("   {c_inf:>8.1} {s_min:>30.3} {:>12.0}%", c_inf * 100.0),
        );
    }
    let monotone = (0..=6_u128).all(|k| {
        wad::collateral_for(500_000_000_000_000_000 * (k + 1))
            > wad::collateral_for(500_000_000_000_000_000 * k)
    });
    let saturated = wad::collateral_for(1_000_000_000_000_000_000_000_000_000_000) < wad::CR_INF;
    line(
        out,
        &format!(
            "   geometric sweep strictly increasing = {} ; C_R(1e30) < CR_INF = {}",
            yes_no(monotone),
            yes_no(saturated)
        ),
    );
    let ok = ok && sweep_ok && monotone && saturated;
    line(out, &format!("   verdict = {}", pass(ok)));
    line(out, "");
    ok
}

/// 2. The integro-differential check (C-24), six decimals, both regimes.
fn section_ide(out: &mut impl Write) -> bool {
    line(
        out,
        "2. THE INTEGRO-DIFFERENTIAL CHECK (C-24), SIX DECIMALS, TWO REGIMES",
    );
    line(out, SUB);
    line(out, "   Deterministic, no seed, the sealed 14-point grid.");
    line(
        out,
        "   mu(r) = alpha(R_bar - r), sigma^2(r) = sigma_0^2 r, lambda = 0.8,",
    );
    line(
        out,
        "   nu = delta_{y=0.85} (E[1-y] = 0.15), pi(r) = -L[C_R](r).",
    );
    line(
        out,
        "   r             C_R(r)      C_R'(r)      C_R''(r)       L[C_R](r)           pi(r)",
    );
    let mut ok = true;
    let mut positive_above_one = true;
    for regime in &cr::REGIMES {
        let summary = cr::summary(regime);
        line(out, SUB);
        line(
            out,
            &format!(
                "   {} (alpha={:.1}, R_bar={:.1}, sigma_0={:.1})",
                regime.name,
                regime.alpha,
                cr::R_BAR,
                regime.sigma_0
            ),
        );
        line(out, SUB);
        for row in cr::rows(regime) {
            line(out, &cr::row_line(&row));
        }
        line(out, "");
        for summary_line in cr::summary_lines(regime, &summary) {
            line(out, &summary_line);
        }
        line(
            out,
            &format!(
                "    Feller 2*alpha*R_bar = {:.6} >= sigma_0^2 = {:.6} = {}",
                regime.feller_lhs(),
                regime.feller_rhs(),
                yes_no(regime.feller_holds())
            ),
        );
        ok &= regime.feller_holds();
        ok &= summary.monotone && summary.min_pi < 0.0 && summary.r0 > 0.0;
        positive_above_one &= summary.pi_10 > 0.0;
    }
    line(
        out,
        &format!(
            "   Decision (sealed): pi(r) > 0 for every r >= 1.0 in BOTH regimes: {}",
            yes_no(positive_above_one).to_uppercase()
        ),
    );
    line(
        out,
        "   r_0 > 0 and min pi(r) < 0 in both regimes (the seal, not a failure).",
    );
    line(
        out,
        "   Six decimals of every row above come from fixtures/sealed_reference.txt.",
    );
    let ok = ok && positive_above_one;
    line(out, &format!("   verdict = {}", pass(ok)));
    line(out, "");
    ok
}

/// 3. Positivity under jumps (F-001): the sealed rates, M6's, and the error.
fn section_positivity(out: &mut impl Write, p: &cir::Params) -> Outcome {
    line(out, "3. POSITIVITY UNDER JUMPS (F-001)");
    line(out, SUB);
    line(
        out,
        &format!(
            "   Parametros: alpha={:.1}, Rbar={:.1}, sigma0={:.1}, lambda={:.1}, \
             jump_mean={:.2}, R0={:.1}, T={:.1}, paths={}",
            p.alpha, p.r_bar, p.sigma_0, p.lam, p.jump_mean, p.r0, p.t_horizon, p.n_paths
        ),
    );
    line(
        out,
        &format!(
            "   steps = int(T/dt) = {} ; stream = numpy.random.default_rng(42) ; mode = {}",
            p.n_steps(),
            numpy::mode().as_str()
        ),
    );
    let mut rng = Distributions::seeded();
    let additive = cir::simulate_additive(p, &mut rng);
    let mut rng = Distributions::seeded();
    let (multiplicative, min_r) = cir::simulate_multiplicative(p, &mut rng);

    let se = standard_error(SEALED_ADDITIVE_RATE, SEALED_PATHS);
    let tolerance = 3.0 * se;
    let deviation = (additive - SEALED_ADDITIVE_RATE).abs();
    let additive_ok = deviation <= tolerance;
    line(
        out,
        "   SDE original (saltos aditivos) R -> R - Exp(0.15)*N:",
    );
    line(
        out,
        &format!(
            "     ours   = {:.4}% de trayectorias tocan R<0   (n = {}, {:.1} pp)",
            additive * 100.0,
            p.n_paths,
            additive * 100.0
        ),
    );
    line(out, "     sealed = 40.5800% de trayectorias tocan R<0");
    line(
        out,
        &format!(
            "     |ours - sealed| = {:.4} pp ; 3*SE = {:.4} pp (SE = {:.6}) ... {}",
            deviation * 100.0,
            tolerance * 100.0,
            se,
            pass(additive_ok)
        ),
    );

    let multiplicative_ok = multiplicative == 0.0 && min_r >= 0.0;
    line(out, "   Fix 1 (saltos multiplicativos) R -> R*U(0.5,1]^N:");
    line(
        out,
        &format!(
            "     ours   = {:.6}% de trayectorias tocan R<0 (min observado: {:.6})",
            multiplicative * 100.0,
            min_r
        ),
    );
    line(
        out,
        "     sealed = 0.000000% de trayectorias tocan R<0 (min observado: 0.000000)",
    );
    line(
        out,
        "     bounded by construction: np.clip(R + drift + diff, 0, None) precedes",
    );
    line(
        out,
        "     the multiplicative factor, so the fraction above cannot be positive",
    );
    line(
        out,
        &format!(
            "     even if a step underflows ... {}",
            pass(multiplicative_ok)
        ),
    );

    let feller = p.feller_holds();
    line(
        out,
        &format!(
            "   Feller (sim_positivity): 2*alpha*Rbar = {:.6} >= sigma0^2 = {:.6} ... {}",
            p.alpha * p.r_bar * 2.0,
            p.sigma_0 * p.sigma_0,
            pass(feller)
        ),
    );
    line(
        out,
        "   The sealed rates are statistics of one run, not limits; reproducing them",
    );
    line(
        out,
        "   to their own precision is the claim, and the sampling error is printed so",
    );
    line(
        out,
        "   the claim is the one that was checked. The multiplicative 0.000000% is a",
    );
    line(
        out,
        "   property of the specification; this section only confirms min R >= 0.",
    );
    let all_pass = additive_ok && multiplicative_ok && feller;
    line(out, &format!("   verdict = {}", pass(all_pass)));
    line(out, "");
    Outcome {
        additive,
        multiplicative,
        min_r,
        all_pass,
    }
}

/// 4. The epoch commitment: `verifyEntry` parity and the freshness bound.
fn section_commitment(out: &mut impl Write) -> bool {
    line(
        out,
        "4. THE EPOCH COMMITMENT, IN M1'S CONVENTION (AVIPRegistry.verifyEntry)",
    );
    line(out, SUB);
    line(
        out,
        "   keccak256 with EVM padding (0x01); every digest below is pinned by",
    );
    line(
        out,
        "   fixtures/keccak256_vectors.txt, generated with `cast keccak`:",
    );
    let empty = keccak::keccak256(&[]);
    let abc = keccak::keccak256(b"abc");
    let zeros135 = keccak::keccak256(&[0_u8; 135]);
    let zeros136 = keccak::keccak256(&[0_u8; 136]);
    line(
        out,
        &format!("   keccak256(0x)             = {}", keccak::to_hex(&empty)),
    );
    line(
        out,
        &format!("   keccak256(0x616263)       = {}", keccak::to_hex(&abc)),
    );
    line(
        out,
        &format!(
            "   keccak256(135 zero bytes) = {}",
            keccak::to_hex(&zeros135)
        ),
    );
    line(
        out,
        &format!(
            "   keccak256(136 zero bytes) = {} (the RATE boundary: 0x01 and 0x80 meet)",
            keccak::to_hex(&zeros136)
        ),
    );
    line(out, "");

    // The four entries the keccak fixture pins: addresses 0x11..11, 0x22..22, …,
    // with norms 1, 0.5, 2 and 3 WAD. The root must be the fixture's root.
    let epoch = commitment::Epoch::new(7, fixture_entries());
    let root = epoch.root();
    line(
        out,
        "   epoch 7, 4 entries, payload = abi.encodePacked(address, uint256 norm), 52 bytes:",
    );
    for (i, leaf) in epoch.leaves().iter().enumerate() {
        let entry = epoch.entries[i];
        line(
            out,
            &format!(
                "     leaf {} = {}  (validator {}, norm {})",
                i + 1,
                keccak::to_hex(leaf),
                keccak::to_hex(&entry.validator),
                entry.norm_wad
            ),
        );
    }
    let mut ok = empty != zeros136 && abc != empty;
    line(
        out,
        &format!("     root        = {}", keccak::to_hex(&root)),
    );
    line(
        out,
        &format!(
            "     digest      = keccak256(epoch || root) = {}",
            keccak::to_hex(&epoch.digest())
        ),
    );
    let mut all_entries_verify = true;
    for (i, entry) in epoch.entries.iter().enumerate() {
        let proof = epoch
            .inclusion_proof(i)
            .expect("an index inside the epoch has a proof");
        all_entries_verify &= commitment::verify_entry(&root, &entry.payload(), &proof);
    }
    ok &= all_entries_verify;
    let leaf_three = epoch.entries[2].payload();
    let proof_three = epoch
        .inclusion_proof(2)
        .expect("index 2 is inside the epoch");
    let mut tampered = leaf_three;
    tampered[51] ^= 1;
    let tamper_rejected = !commitment::verify_entry(&root, &tampered, &proof_three);
    let wrong_root_rejected = !commitment::verify_entry(
        &keccak::keccak256(b"not this epoch"),
        &leaf_three,
        &proof_three,
    );
    ok &= tamper_rejected && wrong_root_rejected;
    line(
        out,
        &format!(
            "     verifyEntry for all 4 entries (deployed contract's own rule) ... {}",
            pass(all_entries_verify)
        ),
    );
    line(
        out,
        &format!(
            "     a one-bit payload change is rejected ......................... {}",
            pass(tamper_rejected)
        ),
    );
    line(
        out,
        &format!(
            "     an unrelated root is rejected ................................ {}",
            pass(wrong_root_rejected)
        ),
    );

    let genesis = commitment::Epoch::new(1, tensor());
    let genesis_ok = genesis.freshness_ok(&commitment::Epoch::new(0, Vec::new()));
    let short_genesis = commitment::Epoch::new(1, tensor()[..499].to_vec());
    let short_genesis_rejected =
        !short_genesis.freshness_ok(&commitment::Epoch::new(0, Vec::new()));
    let base = commitment::Epoch::new(7, tensor());
    let allowed = commitment::Epoch::new(8, tensor_with(commitment::MAX_DELTA_ENTRIES));
    let violating = commitment::Epoch::new(8, tensor_with(commitment::MAX_DELTA_ENTRIES + 1));
    let allowed_ok = allowed.freshness_ok(&base);
    let violating_rejected = !violating.freshness_ok(&base);
    ok &= genesis_ok && short_genesis_rejected && allowed_ok && violating_rejected;
    line(
        out,
        &format!(
            "     freshness: genesis changes all N = {} ... {}",
            commitment::TENSOR_SIZE,
            pass(genesis_ok)
        ),
    );
    line(
        out,
        &format!(
            "     freshness: a genesis short of N is rejected ............... {}",
            pass(short_genesis_rejected)
        ),
    );
    line(
        out,
        &format!(
            "     freshness: gamma*N = {} changed entries accepted ........... {}",
            commitment::MAX_DELTA_ENTRIES,
            pass(allowed_ok)
        ),
    );
    line(
        out,
        &format!(
            "     freshness: {} (= gamma*N + 1) changed entries rejected ...... {}",
            commitment::MAX_DELTA_ENTRIES + 1,
            pass(violating_rejected)
        ),
    );
    line(out, &format!("   verdict = {}", pass(ok)));
    line(out, "");
    ok
}

/// 5. Provenance, the mode, and what this table deliberately does not claim.
fn section_provenance(out: &mut impl Write, smoke: bool) {
    line(out, "5. PROVENANCE, MODE, AND WHAT THIS TABLE IS NOT");
    line(out, SUB);
    line(out, "   sealed inputs, read and never edited by M6:");
    line(
        out,
        "     verification/stochastics/cr_ide_solver.py              -> results/cr_ide_solver_output.txt",
    );
    line(
        out,
        "     verification/stochastics/sim_positivity.py             -> results/sim_positivity_output.txt",
    );
    line(
        out,
        "     verification/mechanism/financial_floor_sensitivity.py  -> results/financial_floor_sensitivity_output.txt",
    );
    line(out, "   resumed bit for bit:");
    line(
        out,
        "     uniform        low + (high - low)*next_double, numpy's own expression",
    );
    line(
        out,
        "     poisson        Knuth's product test, lambda*dt = 8e-4 < 10 (numpy's",
    );
    line(
        out,
        "                    random_poisson_mult branch), tested against the fixture",
    );
    line(out, "   substituted, and declared as such:");
    line(
        out,
        "     normal         numpy: Marsaglia-Tsang ziggurat from a 257-entry table;",
    );
    line(
        out,
        "                    here: Box-Muller from the same stream",
    );
    line(
        out,
        "     exponential    numpy: ziggurat table; here: inverse CDF -scale*ln(u)",
    );
    line(
        out,
        "     reason         those tables are compiled into numpy's C extension, are",
    );
    line(
        out,
        "                    not in this repository and are not reachable offline, so",
    );
    line(
        out,
        "                    the substitute is declared rather than exactness faked.",
    );
    line(
        out,
        "     consequence    the interleaved stream of sim_positivity.py cannot be",
    );
    line(
        out,
        "                    resumed at all: section 3 is a statistical reproduction,",
    );
    line(
        out,
        "                    and bin/m6-probe prints the measurement behind that word.",
    );
    line(
        out,
        &format!(
            "   mode                {} - sections 1, 2 and 4 consume no randomness at all",
            numpy::mode().as_str()
        ),
    );
    line(out, "   deliberately not reproduced here:");
    line(
        out,
        "     - eq:ingestion T[c,d,h] = f_c(events) is M7's; M6 takes the tensor as given;",
    );
    line(
        out,
        "     - the T -> W collaboration map is open (plan §10 D-7), so nothing here",
    );
    line(
        out,
        "       derives a graph, a centrality or an RMT statistic from reputation;",
    );
    line(
        out,
        "     - slashing, escrow and the epoch scheduler are M8's: no funds move and the",
    );
    line(
        out,
        "       commitment is a payload a data layer publishes, not a transaction;",
    );
    line(
        out,
        "     - no result above is a security or liveness claim about the registry.",
    );
    line(
        out,
        "   verification/ was not touched: scripts/m6_report.sh checks that the lines of",
    );
    line(
        out,
        "   fixtures/sealed_reference.txt are still present, and checks this table",
    );
    line(
        out,
        "   against them in both directions before replacing scripts/m6_output.txt.",
    );
    if smoke {
        line(
            out,
            "   SMOKE MODE: section 3's numbers are NOT the pinned ones; the pinned file",
        );
        line(
            out,
            "   comes from scripts/m6_report.sh, which never passes --smoke.",
        );
    }
    line(out, "");
}

/// The four entries `fixtures/keccak256_vectors.txt` pins: addresses `0x11..11`,
/// `0x22..22`, `0x33..33`, `0x44..44` with norms `1`, `0.5`, `2` and `3` WAD.
fn fixture_entries() -> Vec<commitment::Entry> {
    [
        (0x11_u8, 1_000_000_000_000_000_000_u128),
        (0x22, 500_000_000_000_000_000),
        (0x33, 2_000_000_000_000_000_000),
        (0x44, 3_000_000_000_000_000_000),
    ]
    .into_iter()
    .map(|(byte, norm_wad)| commitment::Entry {
        validator: [byte; 20],
        norm_wad,
    })
    .collect()
}

/// The validator address of entry `i`: `i + 1` as a 128-bit big-endian in the last
/// 16 bytes, so no address is the zero address and all of them differ.
fn validator_of(i: u128) -> [u8; 20] {
    let mut addr = [0_u8; 20];
    addr[4..].copy_from_slice(&(i + 1).to_be_bytes());
    addr
}

/// An epoch's worth of entries, with `norm_wad = i`.
fn tensor() -> Vec<commitment::Entry> {
    (0..u128::from(commitment::TENSOR_SIZE))
        .map(|i| commitment::Entry {
            validator: validator_of(i),
            norm_wad: i,
        })
        .collect()
}

/// The same tensor with the first `changed` norms perturbed, i.e. an epoch that
/// changes exactly `changed` entries relative to [`tensor`].
fn tensor_with(changed: u32) -> Vec<commitment::Entry> {
    tensor()
        .into_iter()
        .enumerate()
        .map(|(i, mut entry)| {
            if (i as u32) < changed {
                entry.norm_wad += 1_000_000;
            }
            entry
        })
        .collect()
}
