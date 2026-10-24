<div align="center">

# 💎 Diamond Framework

**Reputation-Weighted Validator Selection via Verifiable Non-Transferable Reputation**

[![Status: research in progress](https://img.shields.io/badge/status-research%20in%20progress-yellow)](#status)
[![Code license: MIT](https://img.shields.io/badge/code%20license-MIT-blue)](LICENSE)
[![Paper license: CC BY 4.0](https://img.shields.io/badge/paper%20license-CC%20BY%204.0-lightgrey)](docs/paper/LICENSE)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23268373.svg)](https://doi.org/10.5281/zenodo.23268373)
[![Python 3.10+](https://img.shields.io/badge/python-3.10%2B-blue)](verification)
[![Solidity 0.8.33](https://img.shields.io/badge/solidity-0.8.33-blue)](integrations/avalanche)
[![Paper: v0.2.1](https://img.shields.io/badge/paper-v0.2.1-orange)](docs/paper/releases/)

[Overview](#overview) · [Status](#status) · [Repository layout](#repository-layout) ·
[Reproducibility](#reproducibility) · [Falsification log](#falsification-log) ·
[Architecture](#architecture) · [Roadmap](#roadmap) · [Contributing](#contributing)

</div>

---

## Overview

The **Diamond Framework** is a cryptoeconomic protocol that replaces a fraction of the
financial stake required to become a Proof-of-Stake validator with **verifiable,
non-transferable reputation**. The goal is to lower the entry barrier for honest but
capital-constrained validators by discounting the stake the rule requires. Whether this
preserves the network's **Cost of Attack** is an open question in v0.2.1 (paper §6.3 and
§10), not a claim of this release.

The core insight is an opportunity-cost argument:

> A validator with a long, verifiable history faces a large opportunity cost if it
> misbehaves, because destruction of its reputation eliminates all future income
> streams. That forfeited stream can serve as **partial collateral**.

### Design principles

| Principle | What it means in the protocol |
|-----------|-------------------------------|
| **Non-transferable** | Reputation cannot be bought, sold, or delegated in the reputation state. It accrues to a validator's own verifiable history. v1 assumes an identity layer rather than providing one: selling a signing key would transfer the income stream even though the token cannot be transferred (paper §10). |
| **Verifiable** | Possession is proven with V3/Groth16 threshold proofs in the delivered circuit (measured; a development-key verifier is deployed on Fuji, no ceremony key is), and the statement binds the validator address, so a proof cannot be replayed for another address. Proving it does not remove trust in the roles below. |
| **Partial** | Reputation never replaces stake entirely. A capital floor remains, so the financial component is bounded below by capital; the full Cost of Attack is not established in this version. |
| **Out of the security path by default** | Research tooling that only reduces cost (e.g. tensor compression) never decides admission or slashing. |

### Trust assumptions in v1

v1 does not remove trust; it places it in five roles, all of them visible in the contracts (paper §10.2):

| Role | What it can do | Why it is a trust anchor |
|------|----------------|--------------------------|
| `sequencer` | The only address that may publish commitments. The root that `admit` reads is the one this role posts. | Admission is only as sound as the published root. |
| `guardian` | The only address that may propose a change of `sequencer` or of `verifier`; the change takes effect after `CHANGE_DELAY = 2 days`, and executing it is permissionless. | A compromised guardian can install a verifier that returns `true` for any proof. The guardian is immutable and there is no rotation path yet. |
| `slashAuthority` | The only address that may slash, and a slash debits the validator's whole recorded stake. | The debit is not adjudicated by an on-chain court; it is authorised by this role. In the Fuji phase-2 deployment it is a 2-of-3 Safe. |
| `NOTIFIER` of the slashing channel | The only address that may request a cross-chain slash. | The destination executes without re-checking the fraud; the reference M7d report uses an EOA. |
| `verifier` | Verifies the admission statement for a given validator. | It is mutable by design, so a circuit defect does not force a registry redeploy. In the Fuji phase-2 deployment a development-key verifier was announced on 2026-10-24 and installs after `CHANGE_DELAY`; until then `verifier` is `address(0)` and `verifyThreshold` reverts `VerifierNotSet`. No ceremony key exists, so the deployed key certifies nothing worth trusting. |

### Non-goals

- **Not a finished protocol.** Sections 2 through 11 are written; each closes with a summary table and each claim is labelled Verified, Measured, Estimated, Design, or Deferred. The remaining open items are consolidated in §10: external audit, real-data calibration, testnet benchmarks, the on-chain verifier, and the deferred recursive option.
- **Not audited.** No external security review has been performed, and there is no mainnet deployment. Fuji phase 2 (chain 43113) is a testnet deployment only.
- **Not formally verified.** All proofs are mathematical arguments, not machine-checked proofs.
- **Not a production implementation.** The off-chain components under `src/` (`reputation/`,
  `rmt/`, `zk/`, `datalayer/`) are built and tested against their own design notes, but they
  are research code: the protocol's Fuji phase 2 is deployed, nothing has been audited, and the V3 circuit is measured, the on-chain verifier carries a development key (no ceremony), and the
  recursive option is deferred. What exists, what is missing and in what order it is
  being built is in
  [`docs/architecture/implementation-plan.md`](docs/architecture/implementation-plan.md).

---

## Status

> **Repository status:** research in progress. The tree, the paper and the verification
> scripts are published incrementally. Every number marked measured or verified in the
> table below is published together with the script that produces it; estimates are
> labelled, per [CONTRIBUTING.md](CONTRIBUTING.md).

| Component | Result | Verification artifact |
|-----------|--------|-----------------------|
| Reputation dynamics | Positive under multiplicative jumps (0% violations) | [`verification/stochastics/`](verification/stochastics) |
| Tensor compression | Tucker reduces storage by 70.8%; **not** used in the security path | [`verification/`](verification) |
| ZK threshold proof | **Measured** — V3/Groth16: 94,438 constraints, 3.9 s proving, 128 B compressed proof (256 B on-chain); original circuit unsound; development-key verifier on Fuji, no ceremony key | [`src/zk/`](src/zk), [`verification/zk/`](verification/zk) |
| RMT collusion detection | Modularity matrix; TPR characterized for cliques | [`verification/rmt/`](verification/rmt) |
| Data layer / fraud proofs | Equilibrium `n* = floor(B/B*)`; attacker profit `-502` (seed-42 mean with `S_slash = 10`; model bookkeeping, not an executable loss) | [`verification/data-layer/`](verification/data-layer) |
| Bootstrap dynamics | Verified — δ/g sweep: R_std peaks at δ/g = 1.5 (0.0424, five seeds); 1.0–2.0 form a plateau | [`verification/bootstrap/`](verification/bootstrap) |
| Mechanism design (payment) | Fee rule specified: posted price F0* = π_val − ω̄·Θ, saturated at highest-cost type | [`verification/mechanism/`](verification/mechanism) |
| Avalanche integration | **Partial** — Fuji phase 2 deployed (chain 43113; 2-of-3 Safe as `slashAuthority`, development-key verifier announced 2026-10-24 and installable after 2026-10-26T17:22:54Z); `AVIPRegistry`, `AVIPStakeVault`, `AVIPValidatorManager` and `AVIPBurnSink` deployed and wired (Table 4.4), the three phase-2 contracts verified on Snowtrace; benchmarks done (ecPairing k=4: 181,142 gas; five creations: 7,787,000 gas total); transport latency pending | [`integrations/avalanche/contracts/`](integrations/avalanche/contracts) |

Rows without a **Partial**/**Pending** marker carry numerical backing in the paper's
verification program; claims in the paper without numerical backing are marked
`[CONJECTURE]`.

---

## Repository layout

```
diamond-framework/
├── docs/
│   ├── architecture/     # design notes (Avalanche integration, ACP-77, Teleporter/AWM)
│   ├── audit/            # numerical verification log + falsification history
│   └── paper/            # theoretical paper (PDF / LaTeX)
├── integrations/
│   └── avalanche/        # chain integration (Foundry, solc 0.8.33)
│       ├── benchmarks/   # gas benchmarks (separate Foundry project)
│       ├── contracts/    # on-chain code (registry, manager, verifiers, M7d transport)
│       └── scripts/      # deployment scripts (offline dry run; Fuji phase 2 deployed)
├── src/                  # off-chain layers (Rust, built and tested offline)
│   ├── datalayer/        # audit equilibrium + ingestion formula (M7b)
│   ├── reputation/       # reputation dynamics
│   ├── rmt/              # spectral collusion detection
│   └── zk/               # threshold proof circuits
├── verification/         # one script per quantitative claim
│   ├── stochastics/      # sim_positivity.py
│   ├── mechanism/        # frobenius_counterexample.py
│   ├── zk/               # soundness_zk_check.py
│   ├── rmt/              # calibration_modularity.py
│   ├── data-layer/       # simulate_data_layer_v3.py
│   └── bootstrap/
├── CITATION.cff
├── CONTRIBUTING.md
├── LICENSE
└── README.md
```

---

## Reproducibility

### Method

1. **Every quantitative claim that is not labelled as an estimate, design choice, or conjecture requires a script.** If such a number appears in a document, the
   script that produced it lives in `verification/`.
2. **Every script states its sample size.** Monte Carlo runs declare `N_REPLICATES`;
   empirical quantiles declare the estimation method (empirical, Wilson, etc.).
3. **Every script is reproducible.** Runs are deterministic given a seed, and the seed is
   declared in the output.
4. **Conjectures are labelled `[CONJECTURE]`** in the paper.

Each script prints its parameters, its sample size, its seed and its result summary.
Result summaries are committed next to the script; raw `.csv` / `.npy` / `.pkl` dumps are
git-ignored.

### Quickstart

```bash
git clone https://github.com/ilichb/diamond-framework.git
cd diamond-framework/verification
pip install -r requirements.txt

python stochastics/sim_positivity.py
python mechanism/frobenius_counterexample.py
python zk/soundness_zk_check.py
python rmt/calibration_modularity.py
python data-layer/simulate_data_layer_v3.py
```

The five scripts above write their outputs to `verification/*/results/`.

### Chain of custody

The suite is closed over its own documents, so a claim can be re-derived rather than trusted.
[`verification/audit-gate.sh`](verification/audit-gate.sh) runs the eleven checks (G1–G11) that
hold the tree together;
[`verification/fase0_anchor.sh`](verification/fase0_anchor.sh) derives the root of
[`verification/anchor_root.sha256`](verification/anchor_root.sha256), which commits the eleven
files of the chain — this paper among them — so that no document of the chain can be edited
without invalidating the root.

That root is then timestamped **outside** the repository with OpenTimestamps, so the state of
the audit is witnessed by something the project does not control. The receipts, the blocks they
are aggregated into, and the command that derives each value live in
[`docs/audit/anchor-receipts.md`](docs/audit/anchor-receipts.md), deliberately *outside* the
root: a receipt sealed inside it would be circular. Bitcoin appears only as that external
witness — it plays no part in the protocol, which targets Avalanche. A change to any of the eleven
files invalidates the seal and requires re-anchoring. The session index is
[`docs/audit/SESSIONS.md`](docs/audit/SESSIONS.md), with one record per session under
[`docs/audit/sessions/`](docs/audit/sessions/).

---

## Falsification log

This project documents its own error correction. The history of claims that were made,
tested and either confirmed or refuted lives in
[`docs/audit/numerical-verification.md`](docs/audit/numerical-verification.md), and the
content audit of `docs/paper/main.tex` is recorded as a worksheet in
[`docs/audit/content-audit-pending.md`](docs/audit/content-audit-pending.md) — 50
findings (C-01…C-50), all closed, with the script or edit that closed each one. Notable
corrections so far:

| Original claim | Correction | Why it changed |
|----------------|------------|----------------|
| 4.7% of trajectories go negative | **40.58%** | The early simulation claim was fabricated: it was presented as the result of a simulation that was never run. With standard parameters the real figure is 40.58%. |
| RMT collusion test on `A_sym` | **Modularity matrix** `B = W - dd^T/(2m)` | Normalized adjacency attenuates cliques: TPR **0.972 vs 0.033** (29.2×) for a single clique of size 20. |
| Tracy–Widom threshold | **Empirically calibrated quantiles** | The theoretical TW threshold is not applicable to sparse heavy-tailed collaboration graphs. |
| Myerson optimal auction rule | **Misapplied; rejected** | F-006: the allocation is independent of the private cost ω, so there is no revelation game. The adopted rule is a saturated **uniform posted price** `F₀*`, not a Myerson auction. F-004 is only the Frobenius-norm projection test. |

If you find a claim that is not reproducible, open an issue with the label `falsification`.
We will correct the claim or remove it.

---

## Architecture

The protocol integrates with Avalanche through:

- **ACP-77 Subnet L1** — validators are admitted to the Subnet based on hybrid collateral.
- **Teleporter / AWM** — reputation commitments propagate cross-subnet.
- **EVM precompiles** — Groth16 verification for ZK threshold proofs.

See [`docs/architecture/`](docs/architecture) for the design notes. The code under
[`integrations/avalanche/`](integrations/avalanche) has **no mainnet deployment** and
has **not** been audited. Fuji phase 2 (chain 43113) is a testnet deployment with a
2-of-3 Safe as `slashAuthority`, a development-key verifier announced on 2026-10-24
(installed by anyone after 2026-10-26T17:22:54Z) and no transport.

---

## Roadmap

| Item | Component | Status |
|------|-----------|--------|
| δ/g sweep over bootstrap dynamics | Bootstrap | **Done** (δ/g = 1.5 maximizes R_std; F-005) |
| Payment rule specification | Mechanism design | **Done** (posted price F0*, IR verified) |
| Gas benchmarks | Avalanche integration | **Done** (Foundry, integrations/avalanche/benchmarks/) |
| Deployment scripts | Avalanche integration | **Done** (M7a: `DeployRegistry`/`DeployValidatorManager`, dry run + tests; Fuji **phase 2** deployed 2026-10-23, chain 43113, 2-of-3 Safe as `slashAuthority`; phase 1 of 2026-10-19 remains on chain as history) |
| Data layer: audit equilibrium + `f_c` | Off-chain (Rust) | **Done** (M7b: the sealed table reproduced row by row on numpy's own stream, `eq:ingestion` as an interface plus the three-valued fraud proof; `src/datalayer/scripts/m7b_report.sh`. M7c: the Pedersen/Poseidon ↔ keccak Merkle bridge over M1's own fold, `src/zk/src/bridge.rs`, `src/zk/scripts/m7c_report.sh`) |
| Teleporter / AWM transport | Avalanche integration | **Done** (M7d: the three message types of `avalanche-integration.md` §4 as a wire format plus one contract per type — per-kind origin allowlists, at-most-once delivery, the commitment recorded once per epoch, the alert flag that cannot be erased, and a slashing notification whose `reason` is derived from the envelope; `integrations/avalanche/scripts/m7d_report.sh`. Offline against a Teleporter double; **the transport is not deployed**) |
| Teleporter latency | Avalanche integration | Pending (requires a deployed Subnet L1/transport; phase 2 is C-Chain only) |
| Paper sections | Paper | **Done** — Sections 2–11 written and verified |
| External security review | Whole protocol | Not started |

---

## Paper

The paper source is [`docs/paper/main.tex`](docs/paper/main.tex) (LaTeX). Ten of the eleven
sections close with a "Summary of the Section" table — every one but the Introduction. Its
second column, headed `Status` everywhere except in the Limitations table, which calls it
`Category`, records the nature of each claim rather than a pass/fail: `Verified`,
`Measured` (once `Measured + estimate`), `Estimated` (once `Estimate`), `Arithmetic`,
`Analytical`, `Logical`, `Design`, `Selection`, `Method`, `Deferred`, `Conjecture`. The
Conclusion's table also uses that column for repository-level items: `Open`,
`Not performed`, `22 entries`. The third column names the backing script, source path
or section — `---` when there is none. Claims that resist measurement are marked
`[CONJECTURE]` in the prose. The paper closes with an appendix, *Reproduction Protocol*: it
states the chain of custody end to end and pins the outputs of the suite in the order of the
closed list of the manifest.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The four core rules:

1. Every quantitative claim not labelled as an estimate, design choice, or conjecture requires a script.
2. Every script requires a stated sample size.
3. Every script requires reproducible output (with a declared seed).
4. Conjectures must be labelled `[CONJECTURE]`.

Changes to [`integrations/avalanche/`](integrations/avalanche) additionally require unit
tests plus an explicit statement of what is tested and what is not.

---

## License

Two licenses, because the code and the paper are reused differently:

- **The repository** — its software, its scripts, its verification suite and its
  documentation — is **MIT**, see [`LICENSE`](LICENSE).
- **The paper** — the manuscript [`docs/paper/main.tex`](docs/paper/main.tex) and
  the frozen PDF snapshots under [`docs/paper/releases/`](docs/paper/releases) —
  is **CC BY 4.0**, see [`docs/paper/LICENSE`](docs/paper/LICENSE).

---

## Citation

The latest **DOI-published** version is **v0.1.0** (2026-10-12).
**v0.2.1** (2026-10-20) is published as a GitHub Release; its version DOI
will be assigned after the Zenodo deposit. **v0.2.0** was tagged but not
deposited: it is superseded by v0.2.1 and must not be cited. Cite the
version DOI when it exists, or the concept DOI that always resolves to the
latest version:

- Concept DOI (all versions): [10.5281/zenodo.23268373](https://doi.org/10.5281/zenodo.23268373)
- v0.1.0 (2026-10-12): [10.5281/zenodo.23268374](https://doi.org/10.5281/zenodo.23268374)
- v0.2.1 (2026-10-20): DOI pending Zenodo deposit
- v0.2.1 GitHub Release: [v0.2.1](https://github.com/ilichb/diamond-framework/releases/tag/v0.2.1)

Machine-readable metadata lives in [`CITATION.cff`](CITATION.cff).

```bibtex
@software{blanco2026diamond,
  author  = {Blanco, Ilich},
  title   = {Diamond Framework: Reputation-Weighted Validator Selection via Verifiable Non-Transferable Reputation},
  year    = {2026},
  version = {0.2.1},
  doi     = {10.5281/zenodo.23268373},
  url     = {https://github.com/ilichb/diamond-framework/releases/tag/v0.2.1},
  note    = {Concept DOI; resolves to v0.1.0 until the v0.2.1 version DOI is assigned}
}
```

---

## Contact

Ilich Blanco — Andromeda Computer. Contact:
[ilichblanco@andromedacomputer.net](mailto:ilichblanco@andromedacomputer.net).
Questions, issues and discussions: use
[GitHub Issues](https://github.com/ilichb/diamond-framework/issues).

<div align="center"><sub>Research in progress — every measured number ships with its script; estimates are labelled.</sub></div>
