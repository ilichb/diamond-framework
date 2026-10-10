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

## `../../src/zk/scripts/m4b_fixture.sh` (milestone M4b)

The M4b analogue, and the one that produces a *real* instance:
`../test/fixtures/M4bGroth16Fixtures.sol` is emitted by the Rust crate that owns
the circuit (`src/zk`), so it is generated where the key is derived rather than by
a script that imitates it. It writes the development key over V3, the fixture
proof, the statement `[root, epoch, certifiedNorm]` and the on-chain
`keccak256(abi.encode(vk))` digest; `test/M4bRealKey.t.sol` then verifies all of
it against the frozen contracts, with no contract change. Read plan §5.5.9 before
quoting a number: the setup is a *development* setup — one phase-2 contributor
with the seeds committed — so the key carries no security claim.

```shell
src/zk/scripts/m4b_fixture.sh
```

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
