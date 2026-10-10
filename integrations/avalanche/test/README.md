# `integrations/avalanche/test/` — Foundry tests

Status: **107 tests over four contracts (plus two libraries), all green with
`forge test --offline`**:

| File | Tests | Scope |
|------|-------|-------|
| `AVIPRegistry.t.sol` | 32 | M1 registry: Merkle convention, sequential epochs, freshness bound, statement binding of `verifyThreshold` |
| `AVIPValidatorManager.t.sol` | 34 | M2 manager: `C_R`/`S_f*` parameters, admission, anti-replay, slashing and ejection, plus 2 fuzz tests |
| `Bn254.t.sol` | 16 | M3 library: field/group parameters, proof decoding (length, canonicality, trailing bytes) and the `0x06`/`0x07`/`0x08` wrappers |
| `Groth16Verifier.t.sol` | 18 | M3 verifier: key installation and digest, accept/reject verdicts, off-curve revert, gas, and the `AVIPRegistry`/`AVIPValidatorManager` integration |
| `M4bRealKey.t.sol` | 7 | M4b: the real key over the V3 circuit and the real fixture proof, accepted by `Groth16Verifier.verify` and by `AVIPRegistry.verifyThreshold` with no contract change, with every statement component bound |
| `fixtures/Groth16Fixtures.sol` | — | **generated** by `../scripts/generate_groth16_fixtures.py`; do not edit by hand |
| `fixtures/M4bGroth16Fixtures.sol` | — | **generated** by `../../../../src/zk/scripts/m4b_fixture.sh` (the Rust crate that owns the circuit); do not edit by hand |
| `mocks/MockThresholdVerifier.sol` | — | the `IZKThresholdVerifier` double used by the M1/M2 suites |

`mocks/MockThresholdVerifier.sol` does not simply answer `true`: it asserts the
`(a, b, c)` it receives and the `keccak256` of the public statement it is called
with, and reverts otherwise. That is what makes "the registry forwards the proof
unchanged" and "the registry builds `[root, epoch, certifiedNorm]` itself"
properties of the double rather than assumptions of the test. The M3 suites are
the ones that run the real pairing check (`Groth16Verifier`), and they still keep
the double for the M1/M2 semantics.

## Rule (from `CONTRIBUTING.md`)

> Code in `integrations/avalanche/` is merged only with unit tests **and** an
> explicit statement of what is tested and what is not.

Every test file must therefore ship with, at the top of the file as a NatSpec
block or comment:

- **What is tested**: the properties asserted, with the paper section they
  trace to.
- **What is NOT tested**: the gaps (e.g. "the recursive SNARK is not verified;
  `IZKThresholdVerifier` is mocked").

## Conventions

- One test file per contract: `test/AVIPRegistry.t.sol`,
  `test/AVIPValidatorManager.t.sol`, `test/Groth16Verifier.t.sol`; libraries are
  tested through `test/Bn254.t.sol` plus the harness in the same file (a
  library's `internal` functions are inlined, so they need a wrapper contract
  to be observed from outside). Shared doubles in `test/mocks/`, generated
  fixtures in `test/fixtures/`.
- `forge-std` is reused from the benchmarks project via the remapping in
  `../foundry.toml`; do not vendor a second copy.
- Numeric assertions must trace to a paper claim or to a `verification/`
  script. Invented constants are not accepted.
- Tests must pass offline: `forge test` must not require network access.

## Run

```shell
cd integrations/avalanche
forge test -vv
```
