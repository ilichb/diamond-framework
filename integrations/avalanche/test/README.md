# `integrations/avalanche/test/` — Foundry tests

Status: **66 tests over two contracts, all green with `forge test --offline`**:

| File | Tests | Scope |
|------|-------|-------|
| `AVIPRegistry.t.sol` | 32 | M1 registry: Merkle convention, sequential epochs, freshness bound, statement binding of `verifyThreshold` |
| `AVIPValidatorManager.t.sol` | 34 | M2 manager: `C_R`/`S_f*` parameters, admission, anti-replay, slashing and ejection, plus 2 fuzz tests |
| `mocks/MockThresholdVerifier.sol` | — | the `IZKThresholdVerifier` double used by both suites |

`mocks/MockThresholdVerifier.sol` does not simply answer `true`: it asserts the
`(a, b, c)` it receives and the `keccak256` of the public statement it is called
with, and reverts otherwise. That is what makes "the registry forwards the proof
unchanged" and "the registry builds `[root, epoch, certifiedNorm]` itself"
properties of the double rather than assumptions of the test.

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
  `test/AVIPValidatorManager.t.sol`; shared doubles in `test/mocks/`.
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
