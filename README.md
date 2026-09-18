<div align="center">

# 💎 Diamond Framework

**Reputation-Weighted Validator Selection via Verifiable Non-Transferable Reputation**

[![Status: research in progress](https://img.shields.io/badge/status-research%20in%20progress-yellow)](#status)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![Python 3.11+](https://img.shields.io/badge/python-3.11%2B-blue)](verification)
[![Solidity 0.8.24](https://img.shields.io/badge/solidity-0.8.24-blue)](integrations/avalanche)
[![Paper: in revision](https://img.shields.io/badge/paper-in%20revision-orange)](docs/paper)

[Overview](#overview) · [Status](#status) · [Repository layout](#repository-layout) ·
[Reproducibility](#reproducibility) · [Falsification log](#falsification-log) ·
[Architecture](#architecture) · [Roadmap](#roadmap) · [Contributing](#contributing)

</div>

---

## Overview

The **Diamond Framework** is a cryptoeconomic protocol that replaces a fraction of the
financial stake required to become a Proof-of-Stake validator with **verifiable,
non-transferable reputation**. The goal is to lower the entry barrier for honest but
capital-constrained validators **without degrading the Cost of Attack** that secures the
network.

The core insight is an opportunity-cost argument:

> A validator with a long, verifiable history faces a large opportunity cost if it
> misbehaves, because destruction of its reputation eliminates all future income
> streams. That forfeited stream can serve as **partial collateral**.

### Design principles

| Principle | What it means in the protocol |
|-----------|-------------------------------|
| **Non-transferable** | Reputation cannot be bought, sold, or delegated. It accrues to a validator's own verifiable history, so it cannot be rented from the capital market. |
| **Verifiable** | Possession is proven with ZK threshold proofs (Bulletproofs), not by trusting a committee or a centralized registry. |
| **Partial** | Reputation never replaces stake entirely. A capital floor remains, so the Cost of Attack is bounded below by capital and not by history. |
| **Out of the security path by default** | Research tooling that only reduces cost (e.g. tensor compression) never decides admission or slashing. |

### Non-goals

- **Not a finished protocol.** Sections 2 through 11 are written and verified; the open items are external audit, real-data calibration, and testnet benchmarks.
- **Not audited.** No external security review has been performed and nothing here is deployed to mainnet.
- **Not formally verified.** All proofs are mathematical arguments, not machine-checked proofs.
- **Not a production implementation.** `src/` contains reference implementations, not production code.

---

## Status

> **Repository status:** research in progress. The tree, the paper and the verification
> scripts are published incrementally. Every number in the table below is published only
> together with the script that produces it, per [CONTRIBUTING.md](CONTRIBUTING.md).

| Component | Result | Verification artifact |
|-----------|--------|-----------------------|
| Reputation dynamics | Positive under multiplicative jumps (0% violations) | [`verification/stochastics/`](verification/stochastics) |
| Tensor compression | Tucker reduces storage by 70.8%; **not** used in the security path | [`verification/`](verification) |
| ZK threshold proof | Bulletproofs: 0 R1CS constraints, 0.72 KB proof | [`verification/zk/`](verification/zk) |
| RMT collusion detection | Modularity matrix; TPR characterized for cliques | [`verification/rmt/`](verification/rmt) |
| Data layer / fraud proofs | Equilibrium `n* = floor(B/B*)`; attacker profit `-502` | [`verification/data-layer/`](verification/data-layer) |
| Bootstrap dynamics | Verified | μ sweep done: band μ/g ∈ [1, 2]; argmax R_std = 0.0424 at μ/g = 1.5 — [`verification/bootstrap/`](verification/bootstrap) |
| Mechanism design (payment) | Fee rule specified: posted price F0* = π_val − ω̄·Θ, saturated at highest-cost type | [`verification/mechanism/`](verification/mechanism) |
| Avalanche integration | **Partial** — gas benchmarks done (181,142); latency pending | [`integrations/avalanche/benchmarks/`](integrations/avalanche/benchmarks) |

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
│   └── avalanche/        # chain integration reference code
│       ├── contracts/    # Solidity 0.8.24
│       └── scripts/      # deployment and benchmarking
├── src/                  # reference implementations (not production code)
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

1. **Every quantitative claim requires a script.** If a number appears in a document, the
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

Outputs are written to `verification/*/results/`.

---

## Falsification log

This project documents its own error correction. The history of claims that were made,
tested and either confirmed or refuted lives in
[`docs/audit/numerical-verification.md`](docs/audit/numerical-verification.md). Notable
corrections so far:

| Original claim | Correction | Why it changed |
|----------------|------------|----------------|
| 4.7% of trajectories go negative | **40.58%** | The early simulation claim was fabricated: it was presented as the result of a simulation that was never run. With standard parameters the real figure is 40.58%. |
| RMT collusion test on `A_sym` | **Modularity matrix** `B = W - dd^T/(2m)` | Normalized adjacency attenuates cliques: 24.8% vs 3.3% TPR for a single small clique. |
| Tracy–Widom threshold | **Empirically calibrated quantiles** | The theoretical TW threshold is not applicable to sparse heavy-tailed collaboration graphs. |
| Myerson projection via Frobenius norm | **Applied to capital cost only** | F-004 (projection); F-006: allocation is independent of ω, IC is tautological |

If you find a claim that is not reproducible, open an issue with the label `falsification`.
We will correct the claim or remove it.

---

## Architecture

The protocol integrates with Avalanche through:

- **ACP-77 Subnet L1** — validators are admitted to the Subnet based on hybrid collateral.
- **Teleporter / AWM** — reputation commitments propagate cross-subnet.
- **EVM precompiles** — Groth16 verification for ZK threshold proofs.

See [`docs/architecture/`](docs/architecture) for the design notes. The code under
[`integrations/avalanche/`](integrations/avalanche) has **not** been deployed to mainnet and
has **not** been audited.

---

## Roadmap

| Item | Component | Status |
|------|-----------|--------|
| `mu` sweep over bootstrap dynamics | Bootstrap | **Done** (μ/g ∈ [1, 2]; F-005) |
| Payment rule specification | Mechanism design | **Done** (posted price F0*, IR verified) |
| Gas benchmarks | Avalanche integration | **Done** (Foundry, integrations/avalanche/benchmarks/) |
| Teleporter latency | Avalanche integration | Pending (requires testnet) |
| Paper sections | Paper | **Done** — Sections 2–11 written and verified |
| External security review | Whole protocol | Not started |

---

## Paper

The theoretical paper sections are in [`docs/paper/`](docs/paper). Sections marked
`[VERIFIED]` have numerical backing in `verification/`; sections marked `[PENDING]` have open
items; claims without numerical backing are marked `[CONJECTURE]`.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The four core rules:

1. Every quantitative claim requires a script.
2. Every script requires a stated sample size.
3. Every script requires reproducible output (with a declared seed).
4. Conjectures must be labelled `[CONJECTURE]`.

Changes to [`integrations/avalanche/`](integrations/avalanche) additionally require unit
tests plus an explicit statement of what is tested and what is not.

---

## License

MIT — see [LICENSE](LICENSE).

---

## Citation

```bibtex
@misc{blanco2026diamond,
  title={Diamond Framework: Reputation-Weighted Validator Selection via Verifiable Non-Transferable Reputation},
  author={Blanco, Ilich and Andromeda Core Research Team},
  year={2026},
  howpublished={\url{https://github.com/ilichb/diamond-framework}}
}
```

Machine-readable metadata lives in [`CITATION.cff`](CITATION.cff).

---

## Contact

Ilich Blanco — Andromeda Computer. Questions, issues and discussions: use
[GitHub Issues](https://github.com/ilichb/diamond-framework/issues).

<div align="center"><sub>Research in progress — every number ships with its script.</sub></div>
