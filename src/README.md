# `src/` — Off-chain reference implementations

Status: **built**. Four crates are tracked here, each with its own tests,
fixtures and (where it measures) benches. The paper's verification suite is a
separate thing and stays in [`verification/`](../verification/). See
[`docs/architecture/implementation-plan.md`](../docs/architecture/implementation-plan.md).

This line said "skeleton ... no code has been written yet" until 2026-10-25,
while 88 files were tracked under `src/` and all four crates below compiled. The
external review of that date flagged the contradiction; the table is now what is
actually there.

## What lives here

`src/` hosts the **off-chain** reference implementations of the protocol that
are not part of the numerical verification suite:

| Directory | Crate | What it implements | Paper section | Milestone |
|-----------|-------|--------------------|---------------|-----------|
| `src/zk/` | `avip_zk_prover` | Pedersen commitment, Bulletproofs range proof, Groth16 statement shape, M7c admission bridge | [`sec:zk`](../docs/paper/main.tex) | M4 |
| `src/rmt/` | `avip_rmt_detector` | Modularity-spectrum collusion detector (production port of `verification/rmt/`) | [`sec:collusion`](../docs/paper/main.tex) | M5 |
| `src/reputation/` | `avip_reputation` | CIR-with-jumps reputation dynamics, `C_R(r)`, epoch commitment | [`sec:reputation`](../docs/paper/main.tex) | M6 |
| `src/datalayer/` | `avip_datalayer` | Ingestion, PCG64, binomial draw, Keccak commitment, equilibrium | [`sec:datalayer`](../docs/paper/main.tex) | M7b |

`src/reputation`, `src/rmt` and `src/datalayer` are std-only and build with
`cargo build --offline` from a clean checkout with no registry at all.
`src/zk` pins the `ark-*` and `bulletproofs` versions exactly and needs that
registry cache on its first build (plan §5.5.6). `target/` is ignored, not
tracked.

## What does NOT live here

- **The numerical verification suite** stays in [`verification/`](../verification/).
  That directory is **sealed by the repository anchor**
  (`verification/anchor_root.sha256`) and is not to be extended from here.
  See "Anchor boundary" in the implementation plan.
- **On-chain code** (Solidity) lives in
  [`integrations/avalanche/contracts/`](../integrations/avalanche/contracts/).

## Language

Rust. Decision D-1 in the implementation plan — Rust versus Python for `src/` —
is closed in favour of Rust, because the architecture names a Rust prover and
Python is already the language of `verification/`, which stays as-is. The crates
are `edition = "2024"`.

## Rules (from `CONTRIBUTING.md`)

1. Every quantitative claim requires a script.
2. Every script requires a stated sample size.
3. Every script requires reproducible output (declared seed).
4. Conjectures are labelled `[CONJECTURE]`.

