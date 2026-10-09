# `integrations/avalanche/test/` — Foundry tests

Status: **empty**. No test exists yet because no implementation exists yet.

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
  `test/AVIPValidatorManager.t.sol`.
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
