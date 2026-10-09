# `integrations/avalanche/scripts/` — Deployment scripts

Status: **empty**. Nothing is deployed anywhere: not to mainnet, not to a
testnet. See `docs/architecture/avalanche-integration.md` §6 (Deployment
Phases) and §3 (statement that nothing here has been audited).

## Intended layout

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
  `script/` directory of the project rooted at `integrations/avalanche/`.

## Run (once deployed to a testnet)

```shell
cd integrations/avalanche
forge script scripts/DeployRegistry.s.sol:DeployRegistry \
    --rpc-url "$FUJI_RPC_URL" --broadcast
```
