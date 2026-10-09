# `src/` — Off-chain reference implementations

Status: **skeleton**. The subdirectories below are placeholders; no code has
been written yet. See [`docs/architecture/implementation-plan.md`](../docs/architecture/implementation-plan.md).

## What lives here

`src/` hosts the **off-chain** reference implementations of the protocol that
are not part of the numerical verification suite:

| Directory | Module | Paper section | Milestone |
|-----------|--------|---------------|-----------|
| `src/reputation/` | CIR-with-jumps reputation dynamics, `C_R(r)`, epoch commitment | [`sec:reputation`](../docs/paper/main.tex) | M6 |
| `src/rmt/` | Modularity-spectrum collusion detector (production port of `verification/rmt/`) | [`sec:collusion`](../docs/paper/main.tex) | M5 |
| `src/zk/` | Pedersen commitment + Bulletproofs proof generation, recursive SNARK composition | [`sec:zk`](../docs/paper/main.tex) | M4 |

## What does NOT live here

- **The numerical verification suite** stays in [`verification/`](../verification/).
  That directory is **sealed by the repository anchor**
  (`verification/anchor_root.sha256`) and is not to be extended from here.
  See "Anchor boundary" in the implementation plan.
- **On-chain code** (Solidity) lives in
  [`integrations/avalanche/contracts/`](../integrations/avalanche/contracts/).

## Language

The target architecture (`docs/architecture/avalanche-integration.md` §1) names
an **off-chain prover in Rust**. Whether `src/` is implemented in Rust or Python
is an open decision (D-1 in the implementation plan); the directory layout above
is language-agnostic.

## Rules (from `CONTRIBUTING.md`)

1. Every quantitative claim requires a script.
2. Every script requires a stated sample size.
3. Every script requires reproducible output (declared seed).
4. Conjectures are labelled `[CONJECTURE]`.
