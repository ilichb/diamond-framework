//! M7c driver — the Pedersen/Poseidon ↔ keccak Merkle bridge (plan §5.4 item 4
//! option (c), §5.5.7, gap A7; delivered in §5.10).
//!
//! ```text
//! src/zk/scripts/m7c_report.sh
//! ```
//!
//! Runs [`bridge`] over the committed fixture of §5.5.6 and prints both readings
//! of the same 500 entries — the `keccak256` Merkle root `AVIPRegistry` stores
//! and the `root` the Groth16 statement carries — plus the link that ties them,
//! what the link rejects, and what it does not claim. Every number is a
//! recomputation over the fixture; nothing is quoted from an earlier run, and
//! there are no durations, so the table is byte-stable between runs.
//!
//! The script also checks the table against `M4bGroth16Fixtures.sol` (the
//! `STATEMENT_ROOT` / `STATEMENT_EPOCH` / `TENSOR_DIGEST` it prints are the ones
//! the M4b fixture declares), which is what makes the bridge answer to the
//! emitted artifact and not only to this crate's own idea of it. The fixture is
//! historical after M4d (P-01/P-16): it fixes the global statement this bridge
//! was built for, and admission no longer consumes it.

use std::fmt::Write as _;

use avip_datalayer::commitment::verify_entry;

use avip_zk_prover::bridge::{self, Mismatch, Verdict};
use avip_zk_prover::fixture;
use avip_zk_prover::groth16::{Variant, variant_root};

/// Lowercase hex of a 32-byte digest.
fn hex32(bytes: &[u8; 32]) -> String {
    let mut s = String::with_capacity(64);
    for b in bytes {
        let _ = write!(s, "{b:02x}");
    }
    s
}

/// `Unbound(reason)` / `Bound`, as the table prints it.
fn verdict_label(verdict: Verdict) -> String {
    match verdict {
        Verdict::Bound => "Bound".to_string(),
        Verdict::Unbound(reason) => format!("Unbound({reason})"),
    }
}

/// The table under construction, with the checks it carries: a later paragraph
/// should not be able to rest on a claim this run did not test, so the rows that
/// *are* claims are counted and a failure exits non-zero (`--quiet`-safe).
struct Table {
    out: String,
    checks: usize,
    passed: usize,
    failed: Vec<String>,
}

impl Table {
    fn new() -> Self {
        Self {
            out: String::new(),
            checks: 0,
            passed: 0,
            failed: Vec::new(),
        }
    }

    /// A measured row.
    fn fact(&mut self, label: &str, detail: &str) {
        let _ = writeln!(self.out, "  {label:<44}: {detail}");
    }

    /// A measured row that also has to hold.
    fn check(&mut self, label: &str, detail: &str, ok: bool) {
        self.fact(label, detail);
        self.checks += 1;
        if ok {
            self.passed += 1;
        } else {
            self.failed.push(label.to_string());
        }
    }

    /// A `yes`/`no` row that has to hold.
    fn holds(&mut self, label: &str, ok: bool, detail: &str) {
        let mark = if ok { "yes" } else { "no " };
        self.check(label, &format!("{mark} — {detail}"), ok);
    }

    fn section(&mut self, header: &str) {
        let _ = writeln!(self.out);
        let _ = writeln!(self.out, "{header}");
    }
}

fn main() {
    let tensor = fixture::tensor();
    let entries: Vec<u64> = tensor.entries().to_vec();
    let certified_norm_wad = tensor.wad_norm() as u64;
    let epoch = 0_u64;

    let bridge = bridge::open(&entries, epoch);
    let claim = bridge.claim();
    let state = &bridge.state;
    let root_hex = hex32(&bridge::root_bytes(bridge.statement_root));

    let mut t = Table::new();
    let _ = writeln!(
        t.out,
        "M7c — the Pedersen/Poseidon ↔ keccak Merkle bridge (plan §5.4 item 4 (c), §5.5.7; delivered in §5.10)"
    );

    t.section("[1] the committed tensor, in both readings");
    t.check(
        "entries (C·D·H)",
        &format!("{}", entries.len()),
        entries.len() == bridge::TENSOR_SIZE,
    );
    t.fact(
        "tensor digest (keccak256, 8-byte LE words)",
        &format!("0x{}", tensor.digest_hex()),
    );
    t.fact(
        "Merkle root (AVIPRegistry convention)",
        &format!("0x{}", hex32(&bridge.merkle_root)),
    );
    t.fact(
        "statement root (V3, Poseidon, uint256)",
        &bridge::uint256_decimal(bridge.statement_root),
    );
    t.fact("statement root (hex)", &format!("0x{root_hex}"));
    t.fact("epoch", &format!("{epoch}"));
    t.fact("certifiedNorm (WAD)", &format!("{certified_norm_wad}"));
    t.fact("link digest", &format!("0x{}", hex32(&bridge.link)));

    t.section("[2] the link is recomputed from the tensor, not asserted");
    t.fact(
        "leaf key of entry 0 / 499",
        &format!(
            "0x{} / 0x{}",
            hex32(&{
                let mut padded = [0_u8; 32];
                padded[12..].copy_from_slice(&state.entries[0].validator);
                padded
            }),
            hex32(&{
                let mut padded = [0_u8; 32];
                padded[12..].copy_from_slice(&state.entries[499].validator);
                padded
            })
        ),
    );
    let poseidon = bridge::statement_root(&entries);
    t.holds(
        "statement root == Poseidon(tensor)",
        poseidon == bridge.statement_root,
        "native::poseidon_commitment with the instantiated parameters",
    );
    let from_circuit = variant_root(Variant::V3, &entries, certified_norm_wad, epoch);
    t.holds(
        "statement root == variant_root(V3)",
        from_circuit == bridge.statement_root,
        "the value groth16::circuit_for fills as public input 0",
    );
    let v2_x = variant_root(Variant::V2Pedersen, &entries, certified_norm_wad, epoch);
    t.holds(
        "V3 and V2′ disagree (different commitments)",
        v2_x != bridge.statement_root,
        &format!("V2′ Pedersen x = 0x{}", hex32(&bridge::root_bytes(v2_x))),
    );
    for index in [0_usize, 499] {
        let proof = state
            .inclusion_proof(index)
            .expect("every position of a 500-leaf epoch has a proof");
        let ok = verify_entry(&bridge.merkle_root, &state.entries[index].payload(), &proof);
        t.holds(
            &format!("verifyEntry over entry {index}"),
            ok,
            &format!("M1's own contract step, {} siblings", proof.len()),
        );
    }
    t.fact(
        "epoch digest (M1's commitment side)",
        &format!("0x{}", hex32(&state.digest())),
    );

    t.section("[3] what the link rejects (every row recomputed from the tensor)");
    let honest = bridge::verify(&entries, &claim);
    t.check(
        "the honest claim",
        &verdict_label(honest),
        honest == Verdict::Bound,
    );

    let mut changed = entries.clone();
    changed[0] ^= 1;
    let moved = bridge::open(&changed, epoch);
    t.fact(
        "T[0] ^ 1, both roots move",
        &format!(
            "merkle 0x{} → 0x{}",
            hex32(&bridge.merkle_root),
            hex32(&moved.merkle_root)
        ),
    );
    let verdict = bridge::verify(&changed, &claim);
    t.check(
        "that claim, over the changed tensor",
        &verdict_label(verdict),
        verdict == Verdict::Unbound(Mismatch::StatementRoot),
    );

    let mut swapped = entries.clone();
    swapped.swap(0, 1);
    let verdict = bridge::verify(&swapped, &claim);
    t.check(
        "entries 0 and 1 swapped (positional)",
        &verdict_label(verdict),
        verdict == Verdict::Unbound(Mismatch::StatementRoot),
    );

    let later = bridge::Claim {
        epoch: epoch + 1,
        ..claim
    };
    let verdict = bridge::verify(&entries, &later);
    t.check(
        "epoch 0 → 1, same roots and link",
        &verdict_label(verdict),
        verdict == Verdict::Unbound(Mismatch::Link),
    );

    let foreign = bridge::Claim {
        link: bridge::open(&swapped, epoch).link,
        ..claim
    };
    let verdict = bridge::verify(&entries, &foreign);
    t.check(
        "a link built over another tensor",
        &verdict_label(verdict),
        verdict == Verdict::Unbound(Mismatch::Link),
    );

    t.section("[4] what the bridge does not do (option (c), §5.5.7)");
    t.fact(
        "keccak inside the circuit",
        "no — the tie is off-chain and recomputable; the proof certifies the norm",
    );
    t.fact(
        "a verifier with only the two roots",
        "nothing — the link needs the tensor; side-by-side roots are an ic.length change §5.5.7 does not decide",
    );
    t.fact(
        "V2′: x binds the whole point",
        "no — a full point needs a second word (§5.5.10); the link takes whatever uint256 the statement carries",
    );
    t.fact(
        "position → validator (T → W)",
        "not claimed — §10 keeps D-7 open",
    );

    t.section("[5] verdict");
    let summary = format!("{}/{} hold", t.passed, t.checks);
    t.fact("bridge checks", &summary);

    print!("{}", t.out);
    if t.failed.is_empty() {
        eprintln!(
            "m7c-report: {}/{} bridge checks hold — the link is off-chain (option (c) of §5.4 item 4)",
            t.passed, t.checks
        );
    } else {
        eprintln!("m7c-report: CHECKS FAILED: {}", t.failed.join("; "));
        std::process::exit(1);
    }
}
