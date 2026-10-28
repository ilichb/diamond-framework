# Which key produced the paper's 286,144 gas

Evidence for the v0.2.3 errata entry `E-01`
([`../../../paper/releases/v0.2.3-errata.md`](../../../paper/releases/v0.2.3-errata.md)).

## The question

`main.tex` prices the deployed path at **286,144 gas** (cold
`AVIPRegistry.verifyThreshold`) and derives four figures from it: the
break-even gas price, the ingress-over-verification ratio, the Bulletproofs
ratio and the margin at 25 gwei. The registry installs **M4d's** key, which the
implementation plan prices at 306,275 cold. If 286,144 belongs to a different
key, the paper presents an uninstalled key's cost as the deployed one.

## The answer, from three places that agree

1. **The paper says it is V3's.** `main.tex:1294`: "The V3 Groth16 proof of
   Section~\ref{sec:zk} verifies directly at 286,144 gas on the cold path of
   `AVIPRegistry.verifyThreshold` (223,403 warm), measured with the real proof".
   `main.tex:555` adds that V3 "is no longer the admission statement the manager
   accepts ... the figures priced here are V3's".
2. **The harness was V3's.** `test/fixtures/M4bGroth16Fixtures.sol` is the
   three-input artifact and its header records the retired
   `test/M4bRealKey.t.sol`, which "installed the key in the frozen
   `Groth16Verifier` and fed the proof to `AVIPRegistry.verifyThreshold`". That
   is the measurement `docs/audit/evidence/2026-10-20-pocs/logs/gas_break_even.txt`
   records as "verifyThreshold, frío (harness nuevo)" — dated 2026-10-20, before
   M4d existed (P-01/P-16).
3. **A three-input key cannot be installed today.** `Groth16Verifier.verify`
   requires `publicInputs.length == ic.length - 1`, and `verifyThreshold` builds
   **four** inputs (`[root, epoch, validator, certifiedNorm]`). Measured below:
   the V3 key declares 3 inputs, the registry passes 4, and the call reverts
   `PublicInputsMismatch(3, 4)`.

## The measurement

`TmpV3ColdPath.t.sol` in this directory, run from
`integrations/avalanche/test/` and deleted afterwards (a test file there is not
in the anchor; the same reason the audit's PoCs were deleted). Output in
`logs/v3_vs_m4d_key.txt`:

| Key | Public inputs | `ic.length` | `verify` gas | 
|---|---:|---:|---:|
| V3 (`M4bGroth16Fixtures`) | 3 | 4 | 223,137 |
| M4d (`M4dGroth16Fixtures`) | 4 | 5 | 232,010 |

The verifier-only difference is **8,873 gas** — one more `ic` scalar
multiplication. That is *not* the whole 20,131-gas gap between 286,144 and
306,275: the rest is `AVIPRegistry`'s own growth between 2026-10-20 and today
(`Bn254.decodeProof`'s coordinate validation, the `MAX_NORM` domain check). This
evidence decomposes the key's share and leaves the contract's share
undecomposed rather than attributing all of it to the key.

V3's 223,137 reproduces the paper's 223,403 warm to within 266 gas (toolchain),
which is the check that both are the same measurement.

## Reproduce

```
cd integrations/avalanche
cp ../../docs/audit/evidence/2026-10-28-v3-vs-m4d-gas/TmpV3ColdPath.t.sol test/
forge test --match-path 'test/TmpV3ColdPath.t.sol' -vv
rm test/TmpV3ColdPath.t.sol
python3 ../../docs/audit/evidence/2026-10-28-v3-vs-m4d-gas/recompute.py
```
