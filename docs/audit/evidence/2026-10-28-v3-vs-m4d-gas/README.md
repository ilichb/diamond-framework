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
multiplication. That is *not* the whole gap: 20,109 to 306,253 (measured today) or
20,131 to 306,275 (§5.5.11). The rest is `AVIPRegistry`'s own growth between
2026-10-20 and today (`Bn254.decodeProof`'s coordinate validation, the `MAX_NORM`
domain check). This evidence decomposes the key's share and leaves the contract's
share undecomposed rather than attributing all of it to the key.

V3's 223,137 reproduces the paper's 223,403 warm to within 266 gas (toolchain),
which is the check that both are the same measurement.

## The deployed figure, and the 35 gas that are the harness

The committed test (`test/M4dRealKey.t.sol`, no probe needed) logs **306,253** cold
/ **247,211** warm / **234,284** verifier-only. The same call measured with the proof
blob built *inline*, instead of through the test's internal helper, is **306,218**
cold / **247,176** warm: 35 gas less, in both directions, which is what a constant
offset looks like.

`TmpManagerAdmitM4d.t.sol` carries the bisection:

| Variant | Cold gas | What moved |
|---|---:|---|
| `test_mirrorWithoutManager` | 306,218 | blob inline |
| `test_mirrorWithHelper` | 306,253 | blob through an internal helper |
| `test_mirrorWithCallerMemory` | 306,221 | inline, plus 0x400 bytes of caller memory (+3) |

So the 35 gas is the helper's call inside the measured window, not the registry.
306,253 is the figure the errata quotes because it is the one the committed test
produces, and 306,218 is stated beside it so that a re-measurer who writes the call
inline does not think they found a discrepancy.

## The admission path, measured for the first time

`AVIPValidatorManager.admit` calls `registry.verifyThreshold` internally, so its cost
is the verification plus the manager's own work. Before 2026-10-28 only the V3-era
figure existed (376,588, `logs` of P-25) and it had never been re-measured.

| Path | Gas | Convention |
|---|---:|---|
| `manager.admit` cold | **395,255** | first call in the transaction, blob via helper |
| `manager.admit` cold | 395,220 | blob inline (the same −35) |
| `manager.admit`, second admission, other validator | 329,682 | code and epoch slots warm |
| `manager.admit` cold, V3 era | 376,588 | 2026-10-20, not comparable |

The manager's own overhead is **89,002 gas**, and it is the same in both conventions
(395,255 − 306,253 and 395,220 − 306,218), which is the check that the two series are
one measurement.

**376,588 is not comparable, and the evidence says so instead of subtracting it.**
admit moved 18,667 gas while the verification moved 20,109, so the remaining 1,442 is
*not* the key's: `AVIPValidatorManager` also changed between 2026-10-20 and today
(M9b/M9c, the custody handshake), and the probe that produced 376,588 was deleted.
The key's share of the verification gap (8,873 of 20,109) is measured; the manager's
share of the admission gap is not, and is left open.

## Reproduce

```
cd integrations/avalanche
cp ../../docs/audit/evidence/2026-10-28-v3-vs-m4d-gas/TmpV3ColdPath.t.sol test/
forge test --offline --match-path 'test/TmpV3ColdPath.t.sol' -vv
rm test/TmpV3ColdPath.t.sol

cp ../../docs/audit/evidence/2026-10-28-v3-vs-m4d-gas/TmpManagerAdmitM4d.t.sol test/
forge test --offline --match-path 'test/TmpManagerAdmitM4d.t.sol' -vv
rm test/TmpManagerAdmitM4d.t.sol

# the committed test, no probe: 306,253 / 247,211 / 234,284
forge test --offline --match-test test_theAdmissionVerificationCostsFiveIcPoints -vv

python3 ../../docs/audit/evidence/2026-10-28-v3-vs-m4d-gas/recompute.py
```

Provenance for every number above: contracts at commit `be49336`, forge
`1.5.1-stable`, solc `0.8.33`, `optimizer = false`, `evm_version = "cancun"`.
Outputs: [`logs/v3_vs_m4d_key.txt`](logs/v3_vs_m4d_key.txt) and
[`logs/manager_admit_m4d.txt`](logs/manager_admit_m4d.txt).

