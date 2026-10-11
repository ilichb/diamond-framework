# `integrations/avalanche/scripts/` — Deployment scripts and generators

Status: **two deployment scripts (dry runs only) and two generators**.
`DeployRegistry.s.sol` and `DeployValidatorManager.s.sol` exist as of M7a
(`docs/architecture/implementation-plan.md` §5.8) and build the frozen M1/M2
contracts. **Nothing is deployed anywhere**: not to mainnet, not to a testnet,
and no line in this directory claims otherwise — the deployment itself belongs to
M7/P5 (§12). See `docs/architecture/avalanche-integration.md` §6 (Deployment
Phases) and §3 (statement that nothing here has been audited).

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

## `DeployCommon.sol`, `DeployRegistry.s.sol`, `DeployValidatorManager.s.sol` (milestone M7a)

The phase-1 pair of `avalanche-integration.md` §6 over one shared floor. Each
script is split in two so that the part a test cannot reach is as thin as
possible:

| Entry point | What it does |
|-------------|--------------|
| `run()` | the CLI entry point: `_refuseMainnet()`, then `deploy(plan())` |
| `plan()` | reads the environment and returns the roles as a `Plan` struct |
| `deploy(Plan)` | the chain guard, the plan validation, the broadcast, the **read-back assertions** and the transcript — the only function that creates state, so tests can drive it with no environment at all |

Roles come from the environment, never from the deployer:

| Variable | Default | Role |
|----------|---------|------|
| `DEPLOYER` | anvil 0 | the sender of `vm.startBroadcast` |
| `SEQUENCER` | anvil 1 | the registry's only writer of commitments; a zero one reverts `MissingRole("SEQUENCER")` |
| `VERIFIER` | `address(0)` | the M3 threshold verifier; M7a deploys none, so the registry certifies nothing (`VerifierNotSet`) |
| `REGISTRY` | **none** | the manager's registry; absent reverts `MissingRole("REGISTRY")` |
| `SLASH_AUTHORITY` | anvil 2 | the manager's only slasher |

An **absent or empty** variable falls back to a public anvil address (nothing to
steal, byte-reproducible dry runs); a **malformed** one is a hard error rather
than a silent fallback — `_roleOr` parses with `vm.parseAddress`, not `envOr`,
because `envOr` answers a typo with the default.

The chain guard is a `require`, not a comment: `43114` (C-Chain mainnet) reverts
with `MainnetRefused(43114)` **before a single role is read**; `43113` (Fuji) and
`31337` (anvil/dry run) pass. `deploy` then reads its own wiring back from the
instance it just created — `sequencer`, `verifier`, `TENSOR_SIZE = 500`,
`MAX_DELTA_ENTRIES = 50`, and the manager's `Theta = 1.0`, `C_R^inf = 0.8`,
`S_min = 0.2`, `Theta_r = 0.5`, `F_0* = 0.05` plus both closed forms at
`r = Theta_r` — so a wrong argument fails the script instead of the first
validator.

### The dry run

```shell
bash scripts/deploy_dryrun.sh
```

Six cases, **one fresh `forge script` process each** (the environment is
process-wide, so two cases sharing a process could not prove how either was
read), and each case asserts what its transcript must contain:

| Case | Environment | Expects |
|------|-------------|---------|
| A | none | the documented defaults: anvil 0 deploys, anvil 1 sequences, no verifier |
| B | none, manager | `MissingRole("REGISTRY")` |
| C | `SEQUENCER`, `VERIFIER`, `DEPLOYER` | the environment wins over the defaults |
| D | `REGISTRY` = the address case C printed | the manager chains onto it |
| E | `SEQUENCER=0xnot-an-address` | a revert, not the default |
| F | `--chain 43114` | `MainnetRefused(43114)` |

It writes `deploy_dryrun_output.txt` (committed) and, if any expectation fails,
exits non-zero **without rewriting it**. The transcript keeps only the `[m7a]`
lines the scripts log — no gas, no timings — so it is byte-stable: two runs diff
clean. It is not a deployment, and the addresses in it are the ones a fresh EVM
hands out, not Fuji addresses.

## Layout (deployment, M7)

| Script | Purpose | Phase | State |
|--------|---------|-------|-------|
| `DeployRegistry.s.sol` | Deploy `AVIPRegistry` to a testnet C-Chain | 1 | **dry-run only** (M7a) |
| `DeployValidatorManager.s.sol` | Deploy `AVIPValidatorManager` | 1 | **dry-run only** (M7a) |
| `RegisterSubnetL1.s.sol` | ACP-77 Subnet L1 registration on the P-Chain | 4 | intended |

These are the four phases of `avalanche-integration.md` §6:
registry + validator manager, off-chain prover, RMT detector, Subnet L1.

## Rules

- Target **testnet (Fuji) only**. There is no audited mainnet deployment.
- A deployment script must never be run against a chain with real value.
- `foundry.toml` sets `script = "scripts"`, so this directory is the Foundry
  `script/` directory of the project rooted at `integrations/avalanche/`. The
  Python generator is not a Foundry script: keep new `.s.sol` files here and new
  generators beside this file, and say which is which in this README.

## Run

Dry run — no network, no keys, nothing broadcast:

```shell
cd integrations/avalanche
forge script scripts/DeployRegistry.s.sol:DeployRegistry   # defaults, no environment needed
REGISTRY=0x... forge script \
    scripts/DeployValidatorManager.s.sol:DeployValidatorManager
bash scripts/deploy_dryrun.sh                             # the six cases above
```

Against Fuji (M7 — deliberately **not** automated by this milestone, and never
against C-Chain mainnet, which the script refuses):

```shell
forge script scripts/DeployRegistry.s.sol:DeployRegistry \
    --rpc-url "$FUJI_RPC_URL" --broadcast
```
