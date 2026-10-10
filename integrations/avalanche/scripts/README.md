# `integrations/avalanche/scripts/` — Deployment scripts and generators

Status: **no deployment scripts; one fixture generator**. Nothing is deployed
anywhere: not to mainnet, not to a testnet. Neither M1 nor M2 added a deploy
script — deployment belongs to M7/P5 (`docs/architecture/implementation-plan.md`
§12). See `docs/architecture/avalanche-integration.md` §6 (Deployment Phases) and
§3 (statement that nothing here has been audited).

## `generate_groth16_fixtures.py` (milestone M3)

Generates `../test/fixtures/Groth16Fixtures.sol`, the Verifying Key and proof the
M3 tests verify against the real `0x06`/`0x07`/`0x08` precompiles. Pure Python,
no dependencies, deterministic. Run it from anywhere:

```shell
python3 integrations/avalanche/scripts/generate_groth16_fixtures.py
```

It writes the Solidity fixture and a human-readable transcript
(`groth16_fixtures_output.txt`); both are committed. Read its module docstring
before trusting a number: **it is a synthetic BN254 instance, not a circuit.** It
solves a Groth16-shaped pairing equation by construction (no witness, no R1CS,
no trusted setup, no soundness claim), which is what makes the on-chain wrapper
testable before the real circuit exists. The real circuit and ceremony are a
parallel workstream; when they land, regenerate the fixture and the key — the
verifier contract does not change.

## Intended layout (deployment, M7)

| Script | Purpose | Phase |
|--------|---------|-------|
| `DeployRegistry.s.sol` | Deploy `AVIPRegistry` to a testnet C-Chain | 1 |
| `DeployValidatorManager.s.sol` | Deploy `AVIPValidatorManager` | 1 |
| `RegisterSubnetL1.s.sol` | ACP-77 Subnet L1 registration on the P-Chain | 4 |

These are the four phases of `avalanche-integration.md` §6:
registry + validator manager, off-chain prover, RMT detector, Subnet L1.

## Rules

- Target **testnet (Fuji) only**. There is no audited mainnet deployment.
- A deployment script must never be run against a chain with real value.
- `foundry.toml` sets `script = "scripts"`, so this directory is the Foundry
  `script/` directory of the project rooted at `integrations/avalanche/`. The
  Python generator is not a Foundry script: keep new `.s.sol` files here and new
  generators beside this file, and say which is which in this README.

## Run (once deployed to a testnet)

```shell
cd integrations/avalanche
forge script scripts/DeployRegistry.s.sol:DeployRegistry \
    --rpc-url "$FUJI_RPC_URL" --broadcast
```
