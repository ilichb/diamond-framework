# avip_rmt_detector — M5, the off-chain RMT collusion detector

Off-chain side of M5 (plan §5.6). The detector is the modularity-spectrum test of
`main.tex` §collusion: `B = W − ddᵀ/(2m)`, right tail `s[-1] = λ_max(B)` against
`9.0542`, left tail `−s[0] = −λ_min(B)` against `9.1371` (both `α = 0.01`). Nothing
here is on-chain logic — the alert is a struct, and slashing is M7/M8.

## Run

```text
src/rmt/scripts/m5_report.sh                     # reproduce the sealed calibration -> scripts/m5_output.txt
cargo test                                       # fast tests, the full protocol is #[ignore]d
cargo test --release -- --ignored                # the sealed protocol at n = 500 (~2.5 min)
cargo bench                                      # detection time on one 500-node graph
cargo run --release --bin m5-report -- --smoke   # the same pipeline in seconds, not for the table
cargo build --offline                            # no dependencies: no registry needed at all
```

## What is reproduced

M5's acceptance is §5's row: *reproduces `q99 = 9.0542` (right tail) and
`−λ_min > 9.1371` (left tail) from `verification/rmt/`, without editing it*. The
reproduction is **exact**, not statistical: it resumes numpy's own stream, so every
digit the sealed tables print is reproduced, including both power tables.

| Quantity | Sealed | Reproduced |
|---|---|---|
| null `λ_max(B)` | mean `8.7679` std `0.1115` q99 `9.0542` q95 `8.9663` | same |
| null `−λ_min(B)` | mean `8.8601` std `0.1101` q99 `9.1371` q95 `9.0428` | same |
| right-tail power (5 configs) | `9.7452`…`16.2281`, TPR@0.01 `0.9720`…`1.0000` | same |
| left-tail power (6 configs) | `9.6602`…`27.6546`, densities `0.0267`…`0.1528` | same |
| single draw `W`/`A_sym`/`B` | `8.6896`/`10.6439`, `0.4254`/`0.4316`, `8.6896`/`10.7011` | same |
| `SE(q99)` (derived) | `0.016802`, `SE/q99 = 0.1856 %` | `0.016802` from the sealed four-decimal moments (`0.016803` unrounded) |

`scripts/m5_output.txt` is the pinned artefact and it is committed; `--smoke` is a
development mode and must not be pinned.

## How an exact reproduction is possible

The sealed scripts are Monte Carlo, so agreeing "within the sampling error" would
be a much weaker claim — `q99` has `SE = 0.0168`, and a value one SE away would
still look like a match. M5 therefore **resumes the same stream**:

- **`pcg64.rs`** implements `numpy.random.default_rng(42)` exactly: PCG64 with
  XSL-RR output, the LCG step, numpy's `next_double` (`(u64 >> 11)·2⁻⁵³`) and the
  LCG jump-ahead. The reference is `fixtures/numpy_pcg64_seed42.txt` (raw `u64`s,
  double bit patterns, the first H0 draw's checksums), and the tests compare **bit
  for bit**. `SeedSequence(42)` is not reimplemented: its 128-bit PCG64 output is a
  documented constant, asserted against that pinned stream.
- **`graph.rs`** transcribes the three sealed generators call for call. The detail
  that matters: numpy draws a **full `n × n`** block of uniforms per replicate and
  the scripts then keep `i < j`, so the diagonal's uniforms are consumed too —
  a generator drawing only the upper triangle would seek the wrong window.
- **`reproduce.rs`** uses the sealed estimators: numpy's default `quantile`
  (`method="linear"`), the population `std` (`ddof = 0`), the Wilson interval, and
  the `q99_standard_error.py` derivation.
- **Parallel and still deterministic**: a phase runs in chunks of 50 replicates,
  each seeking its own window with `advance`, and results are reassembled in
  replicate order. The pinned file cannot depend on the thread count.

## Detection

```rust
use avip_rmt_detector::detector::{ALPHA_0_01, detect};
let detection = detect(&graph, &ALPHA_0_01);
detection.verdict();     // quiet | clique | bipartite | both
```

`detector.rs` carries both calibrations (`ALPHA_0_01`, `ALPHA_0_05`) with their
provenance, `modularity()` (with the `m = 0` branch the sealed scripts use),
`order_statistics()` (`k = 1` is the largest eigenvalue, and one tridiagonalization
serves every `k` asked for), `bulk_edge()` (`2√d̄`) and `bulk_edge_normalized()`
(`2/√d̄`, the edge of the `A_sym` row in the sealed table). One detection on a
500-node graph takes **0.060 s** (`cargo bench`, release, minimum of five).

`spectrum.rs` is the numerics: Householder tridiagonalization plus Sturm bisection
for the order statistic asked for (no eigenvectors — and no Lanczos, because the
null's extremal eigenvalues sit inside a dense bulk, where a Krylov error bound is
hard to trust). `jacobi_eigenvalues` is a second, independent solver used only as a
reference; the tests assert the two agree to `1e-9` on random matrices *and* that
the reduction preserves the trace and the Frobenius norm, so a transcription error
in the Householder step cannot survive both. `Cargo.toml` documents why the crate
is std-only.

## What is tested, and what is not

- `cargo test` → 32 unit tests + 4 integration tests: the PCG64 stream against the
  pinned numpy reference; the first H0 and H1 draws' checksums; the bipartite
  draw's edge counts; analytic spectra (cycle, complete graph); the Jacobi
  cross-check; `B·1 = 0`; `λ_max(B) = λ₂(W)` on regular graphs; and the thresholds
  and single-draw table against `fixtures/sealed_reference.txt`.
- `cargo test --release -- --ignored` → the **full** protocol (2000 null + 5 + 6
  configurations) against those same sealed values, through `clique_power` and
  `bipartite_power`.
- `scripts/m5_report.sh` → the drift guard in both directions: every referenced
  line must still exist verbatim under `verification/rmt/results/`, and every
  four-decimal number in it must appear in the pinned output. The pinned file is
  replaced **only** when the guard passes, so a drifting run leaves it untouched.

**Not** tested, and not claimed: anything on-chain (no slashing logic — M7/M8); a
real collaboration graph (none exists); the `heavy_tail_*` Chung–Lu scripts,
`clique_spectra_seeds.py` (needs numpy's bounded-integer path),
`max_statistic.py`/`recalibrate_top.py` (same ensembles as the null phase) and
`asym_weights.py` (weight ratios, not a spectral claim) — §5.6 gives the reason for
each.

## The M4 fixture, and the map that does not exist

`main.tex` defines `W` as the *collaboration* graph (`eq:collab`) and `T` as the
*reputation* tensor (`eq:tensor`); §collusion never relates them, so M5 does not
invent a projection — the missing map is plan §10 **D-7**. What `fixture.rs` does
is bind the detector's synthetic input to bytes M4 committed: the keccak digest in
`src/zk/fixtures/tensor_digest.txt`, read with `include_str!` so a missing artefact
is a build failure. The pinned table prints that digest beside the detection it
produced, which is the whole claim: the detector runs end to end on
fixture-derived input, and the verdict on that graph is quiet because a null-like
graph should be.

Milestone: **M5, delivered** (plan §5.6). Remaining: M6 (reputation dynamics),
then M7/M8.

