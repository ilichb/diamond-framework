# `integrations/avalanche/scripts/` — Deployment scripts and generators

Status: **three deployment scripts (dry runs only), two reports and two
generators**. `DeployRegistry.s.sol` and `DeployValidatorManager.s.sol` exist as of
M7a (`docs/architecture/implementation-plan.md` §5.8) and build the frozen M1/M2
contracts; `M7dReport.s.sol` plus `m7d_report.sh` exist as of M7d (§5.11) and drive
the three Teleporter/AWM message types of `avalanche-integration.md` §4 end to end;
`DeployStakeVault.s.sol`, `M8Report.s.sol` and `m8_report.sh` exist as of M8 (§5.12)
and deploy the custody half of the handshake and audit the whole fund lifecycle.
**Nothing is deployed anywhere**: not to mainnet, not to a testnet, and no line in
this directory claims otherwise — the deployment itself belongs to M7/P5 (§12), and
no script here has ever seen a real `TeleporterMessenger`. See
`docs/architecture/avalanche-integration.md` §6 (Deployment Phases) and §3
(statement that nothing here has been audited).

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
| `GUARDIAN` | anvil 3 | M9a's second authority (plan §12.1.2): it alone proposes and cancels a role change, which **anyone** may then execute once the 2-day `CHANGE_DELAY` has elapsed. A zero one reverts `MissingRole("GUARDIAN")`; `GUARDIAN == SEQUENCER` reverts `RolesCollapsed`, because one key proposing its own continuation is the capture the delay exists to prevent |
| `VERIFIER` | `address(0)` | the M3 threshold verifier; M7a deploys none, so the registry certifies nothing (`VerifierNotSet`) |
| `REGISTRY` | **none** | the manager's registry; absent reverts `MissingRole("REGISTRY")` |
| `SLASH_AUTHORITY` | anvil 2 | the manager's only slasher |
| `CUSTODY` | `address(0)` | M8's vault (§5.12): `0` is the M2 mode (stake declared, not backed); a non-zero one must answer the handshake or the manager's deployment reverts |
| `TOKEN`, `SINK` | **none** (vault script) | the ERC-20 the vault escrows and the `IFundSink` that receives a slash and the fee; either absent reverts `MissingRole` |
| `WAD_PER_UNIT` | **none** (vault script) | `10 ** (18 - decimals)`, read as a decimal; absent reverts `MissingRole("WAD_PER_UNIT")`, because `decimals()` is never read from the token |

An **absent or empty** variable falls back to a public anvil address (nothing to
steal, byte-reproducible dry runs); a **malformed** one is a hard error rather
than a silent fallback — `_roleOr` parses with `vm.parseAddress`, not `envOr`,
because `envOr` answers a typo with the default.

The chain guard is a `require`, not a comment: `43114` (C-Chain mainnet) reverts
with `MainnetRefused(43114)` **before a single role is read**; `43113` (Fuji) and
`31337` (anvil/dry run) pass. `deploy` then reads its own wiring back from the
instance it just created — `sequencer`, `verifier`, `guardian`,
`TENSOR_SIZE = 500`, `MAX_DELTA_ENTRIES = 50`, `CHANGE_DELAY = 172800`, and the
manager's `Theta = 1.0`, `C_R^inf = 0.8`,
`S_min = 0.2`, `Theta_r = 0.5`, `F_0* = 0.05`, the ejection surcharge `κ = 0.1`
(M9c: a deployment constant the paper gives no value for, so this is the artifact
that quotes it) plus both closed forms at
`r = Theta_r` — so a wrong argument fails the script instead of the first
validator.

### The dry run

```shell
bash scripts/deploy_dryrun.sh
```

Eleven cases, **one fresh `forge script` process each** (the environment is
process-wide, so two cases sharing a process could not prove how either was
read), and each case asserts what its transcript must contain. A to F are M7a's,
G to I M8's, J and K M9a's:

| Case | Environment | Expects |
|------|-------------|---------|
| A | none | the documented defaults: anvil 0 deploys, anvil 1 sequences, anvil 3 guards, no verifier |
| B | none, manager | `MissingRole("REGISTRY")` |
| C | `SEQUENCER`, `VERIFIER`, `DEPLOYER` | the environment wins over the defaults |
| D | `REGISTRY` = the address case C printed | the manager chains onto it |
| E | `SEQUENCER=0xnot-an-address` | a revert, not the default |
| F | `--chain 43114` | `MainnetRefused(43114)` |
| G | none, vault script | `MissingRole("TOKEN")`, and nothing is deployed before the inputs resolve |
| H | vault script: `TOKEN`, `SINK`, `WAD_PER_UNIT` | the custody half of §5.12, wired and left unbound (`check.manager=unbound`) |
| I | manager script: `CUSTODY` = an address with no code | the handshake refuses: the deployment fails instead of producing a manager with no custody |
| J | registry: `GUARDIAN` = `SEQUENCER` | `RolesCollapsed("GUARDIAN", "SEQUENCER")`, and nothing is created |
| K | registry: `GUARDIAN=0x0` | `MissingRole("GUARDIAN")` — the one role with no zero default is refused, not guessed |

It writes `deploy_dryrun_output.txt` (committed) and, if any expectation fails,
exits non-zero **without rewriting it**. The transcript keeps only the `[m7a]` and
`[m8]` lines the scripts log — no gas, no timings — so it is byte-stable: two runs
diff clean (`md5 d68537cdb33ba64c33f45129c0538646` after M9c's one extra check row,
`check.EJECTION_SURCHARGE`). It is not a deployment, and the addresses in it are the
ones a fresh EVM hands out, not Fuji addresses.

## `M7dReport.s.sol` and `m7d_report.sh` (milestone M7d)

The one documented command of the AWM transport, and the only script here that has
no Fuji counterpart at all:

```shell
bash scripts/m7d_report.sh
```

It runs the report offline and pins its `[m7d]` transcript to
`scripts/m7d_output.txt` (committed, 62 rows). The report wires the three message
types of `avalanche-integration.md` §4 across two chain ids — a commitment relay,
a collusion-alert channel and a slashing channel, each deployed once per chain —
and then exercises each one end to end, printing one machine-readable line per
fact **including one per refusal** (13 of them: an uncommitted epoch, a link that
does not tie its own words, an unlisted origin, a second delivery of one message,
a rewritten epoch, a quiet alert, a rewritten flag, a notification the manager
refuses — `NothingToSlash`, since the slashed amount is the record in full and the
second notification has nothing left to take (§12.1.2, M9b) — and so on).

Three things about it are deliberate:

1. **Nothing is live and nothing is broadcast.** `forge script` without
   `--broadcast` simulates locally, the messenger is
   `../test/mocks/MockTeleporterMessenger.sol` (there is no Teleporter on a local
   EVM), and `--offline` keeps the run hermetic. The addresses in the transcript
   are `anvil` account 0's own CREATEs, reproducible run to run and **not** Fuji
   addresses.
2. **The transcript is byte-stable**: no gas, no timings, no block numbers, 62
   rows, `md5 40130315ec07f2f3fc469cf43d36e7f1`. (M9b removed one row — the
   payload's `notify.amountWad`, which no longer travels — and the transcript was
   regenerated and pinned again: §5.13.)
3. **The numbers answer to the milestones they come from, in both directions.**
   `m7d_report.sh` reads each upstream value out of its committed transcript,
   requires it in the declared fixture *and* in the fresh run, and checks that the
   link the contract computes is the link M7c published — M5's sealed `q99` pair
   (scaled to the 4 decimals the alert carries), M7b's `f_c` digest and adjudicated
   `Verdict::Fraud` pair, and M7c's two roots plus `bridge::link_digest`. A
   failure exits non-zero and **leaves the pinned file untouched**; the guard was
   exercised negatively during development (M7c's published link perturbed in
   `src/zk/scripts/m7c_output.txt` → three `FAIL` lines, exit 1, transcript
   unchanged).

It is **not** a deployment script: it does not read a role from the environment
(the roles are `anvil` accounts 0-3, because the environment → plan mapping is
M7a's business, asserted by `deploy_dryrun.sh`), and it refuses C-Chain mainnet
through the same `DeployCommon` guard as the M7a pair. What it shares with them is
the transcript discipline: `[m7a]` and `[m7d]` prefixes are separate on purpose, so
neither harness can absorb the other's lines.

## `DeployStakeVault.s.sol` (milestone M8)

The custody half of §5.12, and the third phase-1-shaped script: it deploys
`AVIPStakeVault` wired to the token it escrows, the `IFundSink` that receives a
slash and the fee, and the scale `WAD_PER_UNIT = 10 ** (18 - decimals)`.

| Variable | Absent | Why it is required |
|----------|--------|--------------------|
| `TOKEN` | `MissingRole("TOKEN")` | a vault pointed at nobody escrows nothing |
| `SINK` | `MissingRole("SINK")` | the vault refuses `address(0)` too: the destination is a deployment fact (`D-M8-0`), not a default |
| `WAD_PER_UNIT` | `MissingRole("WAD_PER_UNIT")` | `decimals()` is never read from the token, so the scale must be told — a wrong one mis-prices every comparison against `stakeOf` |

It logs `[m8]` rather than the shared `[m7a]` (the harness's `_log` is `virtual`
for exactly this), and it asserts the one state the next script depends on:
`check.manager=unbound`, because the vault cannot know the manager's address and
the manager's constructor is what fills that hole. The manager script completes the
handshake by taking this vault as `CUSTODY`, calling `bindManager()` and then
verifying `manager() == address(this)` — see the dry-run cases H and I below, which
are the positive and negative halves of that.

## `M8Report.s.sol` and `m8_report.sh` (milestone M8)

The one documented command of the custody milestone, and the transcript the numbers
are audited through:

```shell
bash scripts/m8_report.sh
```

It builds the whole layer (six-decimal token, burn sink, vault, registry with the
M4b development key, manager), and then walks a validator through the lifecycle —
escrow, admission bound to that escrow, the `F_0*` fee, and a slash that leaves
custody for the sink — the whole of the record the manager holds, since M9b
(§12.1.2) — printing one `[m8]` line per fact and **one per refusal**
(six of them: a second `bindManager`, a manager deployed against an already-bound
custody, an unbacked admission, `debit` from a stranger, the fee from a
non-admitted payer, and a fee-on-transfer token). Every line is reproducible, and
the script's own `require`s plus the `status=ok` row are what fail the run when the
custody stops behaving. The pinned transcript is 42 rows
(`md5 2955c738f2c2a56cb0f6936c4b8e5ff8`), byte-identical across runs. The stake
trajectory it replays is **M7d's own** (`admit.stake`, `slash.stakeAfter` — the
latter `0` since M9b: the slash takes the whole record) and the reason it hands the
sink is **the provenance id M7d derived**, so the wire milestone and the funds
milestone are checked against the same numbers. The destination is not hidden: the
report wires the reference sink and says so.

**Nothing here is a deployment and no key is used**: the token and sink are the test
doubles, the proof is real (M4b's key and fixture, through the frozen verifier), and
the addresses are this script's own CREATEs — reproducible run to run and not Fuji
addresses.

## Layout (deployment, M7)

| Script | Purpose | Phase | State |
|--------|---------|-------|-------|
| `DeployRegistry.s.sol` | Deploy `AVIPRegistry` to a testnet C-Chain | 1 | **dry-run only** (M7a) |
| `DeployValidatorManager.s.sol` | Deploy `AVIPValidatorManager`, with `CUSTODY` optional | 1 | **dry-run only** (M7a, amended by M8) |
| `DeployStakeVault.s.sol` | Deploy `AVIPStakeVault`, the custody the manager binds | 1 | **dry-run only** (M8) |
| `M7dReport.s.sol` | Drive the three §4 message types end to end; pinned by `m7d_report.sh` | 1 + transport | **offline only** (M7d) |
| `M8Report.s.sol` | Audit the fund lifecycle end to end; pinned by `m8_report.sh` | 1 + custody | **offline only** (M8) |
| `RegisterSubnetL1.s.sol` | ACP-77 Subnet L1 registration on the P-Chain | 4 | intended |

It is worth saying why M7d adds **no** deployment script for the transport: the
origins and destinations of a channel are a per-network fact (chain ids and the
address of a real `TeleporterMessenger`), which belongs with the Fuji deployment
that A8 still owes, not with a dry run whose every address is a fresh-EVM artefact.

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
TOKEN=0x... SINK=0x... WAD_PER_UNIT=1000000000000 forge script \
    scripts/DeployStakeVault.s.sol:DeployStakeVault        # M8: custody first
bash scripts/deploy_dryrun.sh                             # the eleven cases above
bash scripts/m8_report.sh                                 # M8's audit, offline
```

Against Fuji (M7 — deliberately **not** automated by this milestone, and never
against C-Chain mainnet, which the script refuses):

```shell
forge script scripts/DeployRegistry.s.sol:DeployRegistry \
    --rpc-url "$FUJI_RPC_URL" --broadcast
```
