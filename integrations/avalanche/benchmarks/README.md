# `integrations/avalanche/benchmarks/` — gas benchmarks

Status: **runnable, offline**. This is a self-contained Foundry project (its own
`foundry.toml`); it is not compiled together with the project rooted one level
up, and the on-chain code under `../contracts/` is not compiled here.

The numbers below are the ones the paper cites for the EVM precompile costs of
Groth16 verification, plus the raw artefacts they come from.

## What is measured

| Benchmark | Entry point | Result |
|-----------|-------------|--------|
| `ecAdd` precompile, EIP-196 (`0x06`) | `GasBenchmarks.benchEcAdd` | 292 gas |
| `ecMul` precompile, EIP-196 (`0x07`) | `GasBenchmarks.benchEcMul` | 6,142 gas |
| `ecPairing` k = 1, EIP-197 (`0x08`) | `GasBenchmarks.benchEcPairing(1)` | 79,142 gas |
| `ecPairing` k = 2, EIP-197 (`0x08`) | `GasBenchmarks.benchEcPairing(2)` | 113,142 gas |
| `ecPairing` k = 4, EIP-197 (`0x08`) | `GasBenchmarks.benchEcPairing(4)` | 181,142 gas |
| Poseidon-2 over BN254 (t = 2) | `GasBenchmarks.benchPoseidon2` | 104,963 gas |
| Tensor ingestion, `||T||_F^2` with N = 500 | `GasBenchmarks.benchmarkIngestFrobeniusNorm` | 428,064 gas (unoptimized) |

Cited in `docs/paper/main.tex` (§9, Evaluation) and
`docs/architecture/avalanche-integration.md` §3 for `ecAdd`, `ecMul` and
`ecPairing` k = 4; the remaining rows are raw artefacts only. Groth16
verification is composed of k = 4 pairings, so the paper's ~206k gas figure is
this pairing cost plus the surrounding logic. The measured values agree with
the EIP-196 / EIP-197 cost models; that cross-check is
`verification/eip_cost_check.py`.

## Reproduce

```shell
cd integrations/avalanche/benchmarks
forge build --offline
forge test -vv
```

No network access and no RPC are required. Each benchmark calls the precompile
directly with `staticcall` and measures the delta with `gasleft()`.

## Artefacts

| File | Compiler | Content |
|------|----------|---------|
| `results/gas_ingest_output.txt` | solc **0.8.24** | ingestion benchmark, unoptimized (foundry default) and optimized |
| `../benchmark_output.txt` | solc **0.8.33** | older run, pairing test with one `k` value |
| `../benchmark_output_v2.txt` | solc **0.8.33** | current run: `k` = 1…4, Poseidon-2 |

**Known discrepancy (gap B5).** The paper cites solc **0.8.33**
(`main.tex` §9) and the two `benchmark_output*.txt` artefacts were produced with
0.8.33, but `results/gas_ingest_output.txt` was produced with **0.8.24**. The
ingestion gas is the same under both versions (`MULMOD` and `ADD` cost does not
depend on operand values), but the artefact has *not* been regenerated under
0.8.33, so it is left untouched rather than edited by hand. Until it is
re-measured, treat that file as an 0.8.24 artefact. This repository's Foundry
projects pin 0.8.33, the version the paper cites.

## What is NOT tested here

- No threshold, admission, slashing or Merkle logic. Those belong to the
  `AVIPRegistry` / `AVIPValidatorManager` milestones; their tests live in
  `../test/`.
- The precompile inputs are trivial curve points, not real Groth16 proofs. Only
  the *cost* of the call is claimed here, never the soundness of a proof.
- `benchPoseidon2` uses the standard Poseidon structure (t = 2, RF = 8,
  RP = 56, x^5 S-box, Cauchy MDS) but deterministic placeholder round
  constants, not the literal standard ones. Gas is unaffected because
  `MULMOD`/`ADD` cost does not depend on operand values.
- Teleporter / AWM latency is not measurable without a testnet
  (`avalanche-integration.md` §7), and the recursive SNARK proving time is not
  measurable before the circuit exists.
