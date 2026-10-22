# Diamond Framework — Implementation Plan

Status: **living document**. This is the rector plan for turning the verified
*paper* into a built *system*. It complements
[`avalanche-integration.md`](avalanche-integration.md) (the target design) and
[`../../README.md`](../../README.md) (the public status). It writes no protocol
logic; it fixes the module map, the interfaces, the milestones and the rules.

Related: [`../../verification/README.md`](../../verification/README.md),
[`../../CONTRIBUTING.md`](../../CONTRIBUTING.md),
[`../audit/handoff.md`](../audit/handoff.md).

---

## 1. Purpose and scope

The repository contains three things today, all verified:

1. the **paper** (`docs/paper/main.tex`, sections 2–11),
2. the **numerical verification suite** (`verification/`, 38 scripts, a
   harness, an audit gate G1–G11 and a tamper-evident anchor),
3. the **EVM gas benchmarks** (`integrations/avalanche/benchmarks/`, Foundry).

The repository did **not** contain the protocol when this plan was written.
`src/reputation/`, `src/rmt/`, `src/zk/`, `integrations/avalanche/contracts/`
and `integrations/avalanche/scripts/` were placeholder directories holding only
a `.gitkeep`, and `avalanche-integration.md` §*Status of the code* said exactly
that: `AVIPRegistry.sol`, `AVIPValidatorManager.sol` and the off-chain prover
were *"specified in this document but not yet implemented"*. Those directories
are placeholders no longer: M1–M7 have filled them (§5.1–§5.11) —
`AVIPRegistry.sol` (M1, §5.1), `AVIPValidatorManager.sol` (M2, §5.3), the
verifier pair `contracts/verifiers/{Bn254,Groth16Verifier}.sol` (M3, §5.4),
the off-chain crates (M4–M6, §5.5–§5.7), M7a's deploy scripts (§5.8), the M7b
data layer (§5.9), the M7c bridge (§5.10) and M7d's transport contracts
(§5.11). §2.2 is therefore the gap-by-gap record of what closed what. Fuji phase 1
is deployed (chain 43113, 2026-10-19T01:46:52Z UTC); what is still missing is the
phase-4 Subnet L1 and transport deployment, not the code.

This plan closes that gap. It does not reopen what is already verified: the
paper's claims, their scripts and their anchor are inputs, not work items.

**Out of scope here** (handled in later phases, see §12): protection of the
document (license, PDF metadata, OpenTimestamps, Zenodo) and any arXiv
submission.

## 2. Current state: what exists and what does not

### 2.1 Exists and is verified

| Artefact | Path | Anchor-sealed |
|----------|------|---------------|
| Paper (11 sections, 40 pp) | `docs/paper/main.tex` | **yes** (pair #1) |
| Numerical suite (38 scripts) | `verification/{stochastics,mechanism,zk,rmt,tensor,data-layer,bootstrap}/` | outputs yes (38 pairs) |
| Harness | `verification/run_all.sh` | **yes** (pair #6) |
| Audit gate G1–G11 | `verification/audit-gate.sh` | **yes** (pair #4) |
| Anchor generator | `verification/fase0_anchor.sh` | **yes** (pair #5) |
| CI | `.github/workflows/audit-gate.yml` | **yes** (pair #7) |
| Claim registry | `docs/audit/claim-registry.csv` | **yes** (pair #8) |
| Numerical record | `docs/audit/numerical-verification.md` | **yes** (pair #9) |
| Content audit (C-01…C-50) | `docs/audit/content-audit-pending.md` | **yes** (pair #10) |
| Gas benchmarks (Foundry) | `integrations/avalanche/benchmarks/` | no |
| Reputation registry (M1) | `integrations/avalanche/contracts/AVIPRegistry.sol` + `test/AVIPRegistry.t.sol` | no |

Local gate status at the time of writing: `PASS=11 FAIL=0 SKIP=0`;
`bash verification/fase0_anchor.sh --check` exits 0
(`IDENTICO byte a byte (10 pares)`).

### 2.2 Does not exist (this plan's work)

| # | Gap | Evidence |
|---|-----|----------|
| A1 | `AVIPRegistry.sol` | `contracts/.gitkeep`; architecture §2, §6.1 |
| A2 | `AVIPValidatorManager.sol` | `contracts/.gitkeep`; architecture §2, §6.1 |
| A3 | On-chain ZK verifier (`verifiers/`) | only gas benchmarks exist; architecture §3 |
| A4 | Off-chain prover (Pedersen + Bulletproofs + recursive SNARK) | `src/zk/` (Rust crate `avip_zk_prover`, M4); architecture §6.2 |
| A5 | Production RMT detector | `src/rmt/.gitkeep`; today only `verification/rmt/` simulations |
| A6 | Reputation dynamics: the off-chain `C_R` crate (the on-chain reader already ships in M2) | `src/reputation/` (crate `avip_reputation`, M6); on-chain half in `AVIPValidatorManager.collateralFor` (M2) |
| A7 | Data layer: event ingestion, transport, fraud proof | architecture §5, §6.3 |
| A8 | Deployment scripts | `scripts/.gitkeep`; architecture §6 |
| A9 | Teleporter / AWM (3 message types) | architecture §4; README roadmap "Pending" |
| A10 | Unit tests for everything above | required by `CONTRIBUTING.md` |
| A11 | Deferred benchmarks (recursive SNARK proving time, Teleporter latency) | paper §9.4; architecture §7 |

Status: **A1, A2, A3 and A6 are closed** by M1, M2, M3 and M6 (§5.1, §5.3, §5.4,
§5.7); **A4 is closed by M4** except the paper-literal recursive construction
(§5.5.7 stays open) and **A5 by M5** (§5.6). **A7 and A9 are closed by M7b, M7c and
M7d**: M7b (§5.9) is the ingestion/fraud-proof half of the data layer, M7c (§5.10)
ties the prover's root to the registry's root, and M7d (§5.11) is the transport —
the three Teleporter/AWM message types of §4, with their wire format, their origin
allowlists and their replay rule. M7a (§5.8) delivered A8's scripts, so what is
missing there is the deployment itself, not the code. The `Evidence` column records
what the gap looked like when this plan was written, not its current status.

### 2.3 Documental inconsistencies (closed in P2; zero anchor risk)

| # | Inconsistency | Evidence | Resolution |
|---|---------------|----------|------------|
| B1 | README said `src/` holds "reference implementations"; it held only `.gitkeep` | `README.md:49` | README now says the off-chain layers are design notes, links this plan, and the layout block no longer claims "reference code" |
| B2 | README badge required "Python 3.11+"; this machine runs 3.10.12 and the suite passes | `README.md:9` | badge lowered to 3.10+ |
| B3 | `benchmarks/README.md` was `forge init` boilerplate; it did not document the benchmark | 64 generic lines | rewritten: what is measured, how to reproduce it offline, artefact provenance, what is **not** tested |
| B4 | `CITATION.cff` published a GitHub `url` and a release date for a private, unreleased repo | `CITATION.cff` | `url` and `date-released` removed; an `abstract` states there is no release, tag or DOI |
| B5 | The paper cites **solc 0.8.33**; the README badge and one benchmark artefact cite **0.8.24** | `main.tex:1265` vs `benchmarks/results/gas_ingest_output.txt:4` | badge aligned to 0.8.33, which is what both Foundry projects pin; the 0.8.24 artefact is left untouched as evidence and its provenance is documented in `benchmarks/README.md` |

### 2.4 Paper apparatus gaps (require a re-anchor — later phase)

| # | Gap | Measured |
|---|-----|----------|
| C1 | No numbered figures or tables (31 inline `center`+`tabular`, 0 `\label`) | `0` `table`/`figure` environments |
| C2 | 7 theorem environments declared, 0 invoked | `7` declared / `0` used |
| C3 | No appendix | `0` |
| C4 | 2 orphan bibliography entries (`bauer2012`, `tracy1994`) | 16 declared / 14 cited |

Deferred on purpose: every change to `main.tex` invalidates the anchor **and**
reopens the content audit (`claim-registry.csv` and `numerical-verification.md`
are themselves anchor-sealed). All C-phase edits are batched into a single
re-anchoring. See §9.

**Status.** C1–C4 were closed in P6b and the PDF-metadata item in P7a, each with
its own re-anchor (§12). The two batches differ in cost: P6b moved 156 lines and
had to re-derive every sealed citation, while P7a wrote into a line that already
existed and moved **one** pair of the root's ten (§R-4.1).

---

## 3. The anchor boundary (read before writing any file)

`verification/anchor_root.sha256` seals ten file hashes. Editing **any** of them
invalidates the anchor and requires re-running the Fase 0 generator
(`bash verification/fase0_anchor.sh`), updating
`docs/audit/anchor-receipts.md` and re-sealing. On any discrepancy the rule is
unchanged: `git reset --hard HEAD` and report — no improvising.

| Zone | Paths | Editing it invalidates the anchor? |
|------|-------|-----------------------------------|
| 🔴 Sealed | `docs/paper/main.tex`; `verification/output_manifest.txt`; `verification/output_manifest.sha256`; `verification/audit-gate.sh`; `verification/fase0_anchor.sh`; `verification/run_all.sh`; `.github/workflows/audit-gate.yml`; `docs/audit/claim-registry.csv`; `docs/audit/numerical-verification.md`; `docs/audit/content-audit-pending.md` | **YES** |
| 🟢 Free | everything else — `src/**`, `integrations/**`, `docs/architecture/**`, `README.md`, `CONTRIBUTING.md`, `CITATION.cff`, `.gitignore`, `verification/README.md` | no |

**The one trap.** `verification/README.md` is *not* sealed, but
`verification/run_all.sh` parses its `## Running` block to build the script
list, and `run_all.sh` regenerates `verification/output_manifest.txt`, which
**is** sealed (and is the input of `output_manifest.sha256`, pair #3).

> Therefore: **do not add scripts to the `## Running` block of
> `verification/README.md`, and do not run `verification/run_all.sh`** while
> building the system. New code goes in `src/` and `integrations/`; the
> verification suite stays frozen.

Corollary: guard G1 is `find verification -maxdepth 2 -name '*.py' | wc -l >= 35`
(not `== 35`), so adding a `.py` there would not fail G1 — but it cannot help
either, and the risk of touching `output_manifest.txt` is real. Keep out.

## 4. Target architecture

Three layers, already fixed by `avalanche-integration.md` §1 (only the language
of `src/` is open, see D-1):

| Layer | Responsibility | Language | Where |
|-------|----------------|----------|-------|
| **On-chain (C-Chain)** | Reputation registry (epoch Merkle roots + inclusion proofs), admission/slashing rule, ZK verifier | Solidity (`^0.8.24`, solc 0.8.33, evm `cancun`) | `integrations/avalanche/contracts/` |
| **Off-chain, security-relevant** | Pedersen commitment, Bulletproofs proof generation, recursive SNARK composition, RMT detector, epoch commitment | Rust (target) | `src/{zk,rmt,reputation}/` |
| **Cross-subnet** | Commitment propagation, collusion alert, slashing notification (Teleporter/AWM) | Solidity + AWM messages | `integrations/avalanche/scripts/` + `contracts/` |

The **numerical suite** (`verification/`) is not a layer: it is the evidence
record for the paper and stays frozen (§3).

Design invariants carried from the paper:

- Reputation is **non-transferable** and **verified**, never delegated.
- Reputation is **partial**: `S_min = Θ − C_R^∞ = 0.2 > 0`. The Cost of Attack
  stays bounded below by capital.
- Tucker compression is **never in the security path** (paper §3, "Tucker Is
  Not in the Security Path"). The on-chain object is the full tensor commitment.
- The registry stores **roots, not the tensor**.

---

## 5. Module map and milestones

Every milestone is *done* only when its code, its tests and its short doc exist
and `forge test` / `cargo test` is green. Acceptance criteria cite the paper
claim they trace to; **no invented constants**.

| # | Milestone | Gap | Deliverable | Acceptance |
|---|-----------|-----|-------------|------------|
| M1 | Reputation registry | A1 | `contracts/AVIPRegistry.sol` — **done** | Merkle root per epoch; inclusion proof; rejects a root violating `γ·N = 0.10·500` (Data Layer) |
| M2 | Validator manager | A2 | `contracts/AVIPValidatorManager.sol` — **done** | `S_f*(T) = max{0.2, Θ − C_R(T)}` with `C_R(r)=0.8r/(1+r)`; admission and slashing events; vectors match `verification/mechanism/` |
| M3 | ZK verifier | A3 | `contracts/verifiers/Groth16Verifier.sol` — **done** (§5.4) | Groth16 k=4 over BN254 via 0x06/0x07/0x08; gas ≈ 206k (cross-check `GasBenchmarks.sol`; 223,445 measured on the deployed shape, §5.4) |
| M4 | Off-chain prover | A4, A11 | `src/zk/` (Rust) — **M4a, M4b, M4c and M4d done** (§5.5.8–§5.5.11) | Bulletproofs aggregated range proof over the 500-entry tensor (`512 × 64` padded, measured 1248 B against the paper's 0.72 KB, §5.5.8); the in-circuit commitment is **V3** — `D-M4-0` closed in M4c (§5.5.10); the derived key and proof are accepted by the frozen contracts (§5.5.9); M4d binds the proof to one validator by leaf inclusion and separates the Poseidon statement root from the keccak commitment (audit P-01/P-16, §5.5.11); reports local proving time (**3.9 s** against §5.5.4's 120 s gate); the *paper-literal* recursive SNARK stays open (§5.5.7) |
| M5 | RMT detector | A5 | `src/rmt/` — **done** (§5.6) | Reproduces `q99 = 9.0542` (right tail) and `−λ_min > 9.1371` (left tail) from `verification/rmt/`, without editing it |
| M6 | Reputation dynamics | A6 | `src/reputation/` — **done** (§5.7.1) | `C_R(r)` closed form, WAD parity with M2's deployed reader (`collateralFor(Θ_R)`/`requiredStakeFor(Θ_R)` pinned) + the epoch commitment in M1's convention; positivity under multiplicative jumps (paper §2) — F-001 reproduced: additive **40.2510%** against the sealed **40.5800%** (0.3290 pp, inside `3·SE`), multiplicative **0.000000%** by construction; the IDE solver reproduces `cr_ide_solver_output.txt` (14-point grid, two regimes, `r_0`, monotone, `π(r)/r → 0.799992`) |
| M7 | Data layer, deploy, AWM | A7, A8, A9 | `src/datalayer/` + `src/zk/src/bridge.rs` + `contracts/AVIP*` + `scripts/` — **M7a, M7b, M7c and M7d done** (§5.8, §5.9, §5.10, §5.11) | Fraud-proof equilibrium `n*(B)=⌊B/B*⌋`, `S_slash=10` (Data Layer): the sealed table reproduced row by row on numpy's own stream (`scripts/m7b_output.txt`), with `eq:ingestion` delivered as an interface plus the three-valued fraud proof (§5.9); the Pedersen/Poseidon ↔ keccak bridge ties the statement's `root` to the registry's Merkle root **over M1's own fold**, off-chain and recomputable (`src/zk/src/bridge.rs`, `src/zk/scripts/m7c_output.txt`, §5.10); the three Teleporter/AWM message types of §4 exist as a wire format plus one contract per type, with per-kind origin allowlists, at-most-once delivery, the commitment recorded once per epoch, the alert flag that cannot be erased and the slashing notification whose `reason` is derived from the envelope (`contracts/AVIP*`, `scripts/m7d_output.txt`, `test/M7dTransport.t.sol`, §5.11) — all of it offline against a Teleporter double; the phase-1 `Deploy*.s.sol` exist and are verified offline, and phase 1 is deployed on Fuji (chain 43113, 2026-10-19T01:46:52Z UTC, `verifier = address(0)`); the transport and the phase-4 L1 remain open |
| M8 | Treasury / custody | A2 (deferred half) | `contracts/AVIPStakeVault.sol` + `contracts/AVIPBurnSink.sol` + the amended `contracts/AVIPValidatorManager.sol` + `scripts/DeployStakeVault.s.sol` — **done** (§5.12) | Token custody and fund movement: escrow of `financialStake` behind `IAVIPCustody`, a slash that moves it to an `IFundSink`, and collection of `F_0*` that never touches the vault's balance; the destination of the funds is a deployment fact (`D-M8-0`, reference sink = burn), because the paper names no recipient and no burn/retain decision (§5.12); `custody == address(0)` is the original M2 exactly |

Ordering rationale: M1 → M2 → M3 are on-chain and unblock each other; M4 and M5
are the heavy off-chain work; M6 and M7 close the loop. A10 (tests) is not a
separate milestone: it is a gate on every milestone. A11 is split:
the recursive SNARK proving time is delivered by M4; the Teleporter latency
stays deferred until a live testnet exists.

M8 is not part of the original ordering: it is the custody half that M2 left
open (§5.2.3), split out rather than appended to M4. M4 is off-chain and its
acceptance gate is `cargo test`; custody moves funds on-chain and is
security-sensitive, so it gets its own amendment, its own invariants (fund
conservation, non-standard ERC-20, reentrancy) and its own phase. Note that the
labels inside `AVIPValidatorManager.sol` used to read "M4" for the reputation
weights: that is **M6**, and the stale label was corrected.

### 5.1 M1 as delivered

`contracts/AVIPRegistry.sol` + `test/AVIPRegistry.t.sol` (30 tests,
`forge test --offline` green). Accepted:

- one Merkle root per epoch, 0-based and strictly sequential (`postCommitment`
  rejects gaps, re-posting and a zero root);
- inclusion proofs under the convention documented in the contract
  (`keccak256` leaf prefix, sorted pairs, single-leaf root = leaf hash), checked
  against an 8-leaf tree and against the full 500-leaf tensor;
- a declared delta above the freshness bound `γ·N = 0.10 × 500 = 50` is
  rejected with `FreshnessViolation`; genesis must declare the whole tensor.

Boundaries that are **not** covered by M1 and must not be assumed from it:

- The freshness bound is enforced on the delta the sequencer **declares**. The
  registry does not hold the tensor and cannot recompute it; the paper places
  soundness on the data layer's fraud proof (gap A7, milestone M7).
- `verifyThreshold` binds the proof to `(root, epoch)` and forwards it to
  `IZKThresholdVerifier`. Since M3 that interface is implemented by
  `Groth16Verifier` and the tests exercise the real pairing check (§5.4); the
  recursive SNARK is still M4.
- No admission, slashing or reputation-weight logic (M2).

### 5.2 Amendment M2: AVIPValidatorManager, registry hardening, and the admissible domain

**Objective.** Implement the hybrid admission rule, close the parameter-injection
and DoS vectors M1 left open, state the ZK circuit semantics explicitly, and
record the economic effect of restricting the domain to `||T||_F >= Θ_r`
(paper, "Zero-Knowledge Threshold Proof").

#### 5.2.1 One source of truth for the certified norm

The M1 sketch let the manager receive `tensorNorm` as a free parameter. The
registry did validate `root` and `epoch` (anything else reverted with
`PublicInputMismatch`), but the `norm` the manager used to compute `C_R` was
**not bound to the proof**: two sources of truth for the same quantity.

M2 removes the caller-supplied array. The manager passes only `certifiedNorm`;
the registry reads `root = commitmentOf(epoch)` from its own state and builds the
statement itself:

    statement = [uint256(root), epoch, certifiedNorm]

and the registry signature becomes:

```solidity
function verifyThreshold(uint256 epoch, uint256 certifiedNorm, bytes calldata proof)
    external
    view
    returns (bool);
```

The `validator` argument is gone: with that statement it had no binding role. As
a `view` function the registry writes no state, so the DoS that let an attacker
burn `thresholdProven[epoch][validator]` in their own transaction is closed, and
a ~20k-gas SSTORE disappears. In the real circuit (M3) the binding is
arithmetic: the norm is a public input, so a false `certifiedNorm` changes `vk_x`
and the pairing fails. Since M3 the verifier is real (`Groth16Verifier`, §5.4),
so this is now a tested property: `test/Groth16Verifier.t.sol` passes a genuine
proof for `Θ_r` together with a declared `Θ_r + 1` and gets `InvalidZKProof`. The
*norm itself* is still only as sound as the circuit and the Pedersen ↔ Merkle
bridge, which do not exist yet (M4, §5.4).

> **Superseded by M4d (§5.5.11).** Audit findings P-01 and P-16 showed that this
> three-word statement admits a proof for any validator, and that storing the
> Poseidon root in `commitmentOf(epoch)` gave one slot two meanings. The
> registry now keeps `statementRootOf(epoch)` beside `commitmentOf(epoch)` and
> `verifyThreshold(epoch, validator, certifiedNorm, proof)` builds
> `[statementRoot, epoch, validator, certifiedNorm]`. The M2 text above is the
> recorded history of that milestone; the current interface is §5.5.11.

#### 5.2.2 Circuit semantics and the M3 bridge

- **The circuit proves equality; the manager proves the threshold.** The circuit
  proves `||T||_F = certifiedNorm`; the manager enforces
  `certifiedNorm >= Θ_r` and reverts with `NormBelowThreshold`.
- **Declared deviation from the paper (main.tex §4.1, "Circuit
  Specification").** §4.1 specifies a circuit that verifies `||T||_F >= Θ_r`
  (`eq:threshold`). The implementation deviates on purpose: keeping `Θ_r` out of
  the circuit keeps the economic policy parameter out of the trusted-setup
  ceremony, so changing `Θ_r` does not require a new ceremony. Because the
  circuit certifies the exact norm, the manager's comparison reproduces the
  paper's predicate on-chain, without redundant constraints. The proof stays
  reusable across `Θ_r` values; the price is that the exact `||T||_F` becomes
  public, which the paper already assumes (§4.1: "The tensor `T` is public ...
  the proof exists for succinctness, not for privacy").
- **Mock caveat.** Until M3, `MockThresholdVerifier` performs no pairing check;
  no claim is made about the pairing or the recursive SNARK.
- **Open M3 risk (Merkle <-> Pedersen bridge).** M1 commits a keccak256 Merkle
  root; the paper (§4.3, "Repair Options", Option B) proves the norm over a
  Pedersen commitment with Bulletproofs. keccak256 inside a SNARK is
  prohibitively expensive, so this is not a cosmetic migration. M3 must choose
  between: (a) making Pedersen the canonical on-chain commitment, which breaks
  `verifyEntry` inclusion proofs and invalidates previously posted roots — a
  commitment-scheme migration, not a change of the freshness rule, which is
  computed from the declared `changedEntries` alone; (b) proving the equivalence
  between the Merkle root and the Pedersen commitment inside the circuit
  (expensive); or (c) keeping Merkle as the canonical on-chain commitment, using
  Pedersen strictly for the norm proof and linking the two in the off-chain data
  layer (M7). This risk stays explicitly open for M3.

#### 5.2.3 The admissible domain and the optimal fee

- **Admissible domain.** With `Θ_r = 0.5`, a validator with `||T||_F < 0.5` is
  rejected by the **manager**. `T = 0` is therefore no longer an admissible type.
- **Worst-case admissible type.** The paper's worst case is `(omega_max, T = 0)`
  — the highest private cost of capital combined with the lowest reputation
  (main.tex §6.4, "The Uniform Posted Price"). On the admissible domain it
  becomes `(omega_max, ||T||_F = Θ_r = 0.5)`:
  - `C_R(0.5) = 0.8 * 0.5 / (1 + 0.5) = 0.26666...` (`266666666666666666`)
  - `S_f*(0.5) = max(S_min, Θ - C_R(0.5)) = 0.73333...` (`733333333333333334`)
  - `F_0* = pi_val - omega_max * S_f*(0.5) = 0.15 - 0.10 * 0.73333... =`
    `0.07666...` (`76666666666666667`), i.e. 1.53x the paper's `0.05`.
- **M2 decision.** `F0_STAR = 5e16` (0.05), the paper's value (main.tex §6.4,
  `F_0* = pi_val - omega_max * Θ = 0.15 - 0.10 * 1.0 = 0.0500`), stays the
  constant. It is IR-safe — a lower fee only relaxes `U >= 0` — but sub-optimal:
  it collects ~65% of the optimum on the admissible domain. The paper's claim
  that the saturation is exact holds for the unrestricted domain only.
- **Provenance note.** `verification/mechanism/fee_specification.py` and
  `financial_floor_sensitivity.py` describe the domain *without* the `Θ_r`
  restriction. They are **not** modified: their outputs are listed in the sealed
  `verification/output_manifest.txt`, so editing them would invalidate the
  anchor. The claim that 0.05 is a safe lower bound — rather than the exact
  optimum of the admissible domain — is recorded here, and can be promoted to
  `docs/audit/claim-registry.csv` in the next batched re-anchor (§9).
- **Custody (M8).** M2 exposes the `F0*`/`S_f*` policy. It does not implement token
  custody or transfer (ERC-20 or native); that is delegated to the **M8 Treasury
  Module** (§5), the milestone that owns fund movement. This is why
  `financialStake` is *declared*, never escrowed.

#### 5.2.4 Anti-replay, state, and contract documentation

- **Anti-replay lives in the manager.** `verifyThreshold` is `view`, so the
  registry keeps no per-validator state; double admission is impossible because
  `admit` requires `!isAdmitted[validator]`. `thresholdProven` and the
  `ThresholdProven` event are removed.
- **Collateral as a `view`.** `collateralOf(validator)` returns
  `Θ - requiredStake[validator]` and stores nothing, so there is no second source
  of truth. The identity holds by parameter construction, not by luck: the
  saturation `C_R^inf = 0.8` and `S_min = Θ - C_R^inf = 0.2` guarantee
  `Θ - C_R(r) >= S_min` for every finite `r`, so `requiredStake` is `Θ - C_R` and
  never the floor standing alone. It would only fail if `S_min` were raised above
  `Θ - C_R^inf`.
- **Events.** `ValidatorAdmitted(address indexed validator, uint256 stake, uint256
  collateral)` unchanged, exactly as `IAVIPValidatorManager` declares it, plus
  `AdmissionEvaluated(address indexed validator, uint256 epoch, uint256
  certifiedNorm, uint256 collateral, uint256 requiredStake)` for audit
  traceability of the certified norm and the amounts derived from it, plus
  `ValidatorEjected(address indexed validator, uint256 stake, uint256
  requiredStake)` — see the next bullet.
- **Slashing revokes the admission, it does not zero the stake.** `slash` is
  authority-only and bounded by `stakeOf`, and when the remaining stake falls
  below `requiredStake` the validator is ejected. This is a design decision taken
  while implementing M2, not a line of the plan: without it `isAdmitted` stops
  implying `stakeOf >= S_f*`, which is the definition of admission. The stake
  keeps whatever is left (M2 holds no funds, so there is nothing to seize), and
  re-admission is a new `admit` call with a fresh proof for the then-current
  epoch. `M2` also leaves the *consequences* of an ejection (removal from the
  validator set, weight) to M6/M7.
- **Error migration.**
  - manager: adds `NormBelowThreshold`, `InsufficientFinancialStake`,
    `AlreadyAdmitted`, `NotValidator`, `NotSlashAuthority`, `SlashExceedsStake`,
    `ZeroRegistry`, `ZeroSlashAuthority`; `ZeroValidator` moves here (`admit`
    still rejects `address(0)`).
  - registry: adds `InvalidZKProof`; `UnknownEpoch` is retained and becomes
    load-bearing, because the registry now reads the root from
    `commitmentOf(epoch)` (it is also what reports `latestEpoch() == type(uint256).max`
    on a registry with nothing posted). The other seven M1 errors
    (`NotSequencer`, `ZeroSequencer`, `ZeroRoot`, `NonSequentialEpoch`,
    `GenesisDelta`, `FreshnessViolation`, `VerifierNotSet`) are unchanged.
  - removed from the registry: `PublicInputMismatch` (no caller-supplied inputs
    left) and `ThresholdAlreadyProven`.
- **Contract NatSpec** (contracts are not sealed, so this is safe): both
  `AVIPRegistry.sol` and the reference-parameter block of `IAVIPRegistry.sol`
  were reworded to "certifies the exact norm; the threshold is enforced by
  `AVIPValidatorManager`".
- **Verifier and mock.** `IZKThresholdVerifier` keeps the exact Groth16 shape
  `verify(uint256[2] a, uint256[2][2] b, uint256[2] c, uint256[] input)`; the
  registry decodes the `bytes proof`. The existing `MockThresholdVerifier` was
  moved out of `AVIPRegistry.t.sol` into `test/mocks/MockThresholdVerifier.sol`,
  so there is one mock, not two. While doing so it was made to *check* rather
  than merely answer: it requires `a[0]` to be the expected element and the
  `keccak256` of the statement to be the expected one, so "the registry forwards
  `(a, b, c)` unchanged" and "the registry builds `[root, epoch, certifiedNorm]`
  itself" are asserted by the double instead of assumed. A consequence found
  while testing: `abi.decode` does not require the whole payload to be consumed,
  so a legacy `(a, b, c, publicInputs)` blob still decodes with the trailing
  array unread. That is harmless — the caller cannot inject a public input either
  way — and is now asserted as a property
  (`test_verifyThreshold_ignoresTrailingBytesInTheProof`) rather than left as an
  accident.

### 5.3 M2 as delivered

Delivered: `contracts/AVIPValidatorManager.sol`,
`contracts/interfaces/IAVIPValidatorManager.sol` (signatures, events, errors),
`test/AVIPValidatorManager.t.sol`, `test/mocks/MockThresholdVerifier.sol`
(extracted from the registry test, see §5.2.4), and the §5.2 amendment applied to
`AVIPRegistry.sol` + `IAVIPRegistry.sol` + `AVIPRegistry.t.sol`.

Order of the checks in `admit` (nothing is written before the last one passes):
`validator != 0` → `msg.sender == validator` → `!isAdmitted[validator]` →
`certifiedNorm >= Θ_r` → `financialStake >= S_f*(certifiedNorm)` →
`registry.verifyThreshold(registry.latestEpoch(), certifiedNorm, proof)`, whose
`false` becomes `InvalidZKProof`.

Deviations from §5.2, all deliberate and all stated in code:

1. **`slash` ejects.** §5.2.4 asked only for a bounded, authority-only slash. The
   implementation also revokes the admission when the remaining stake drops below
   `requiredStake` (new `ValidatorEjected` event): otherwise `isAdmitted` would
   stop implying `stakeOf >= S_f*`. The stake is not zeroed — M2 has no custody
   and nothing to seize.
2. **`registry` and `slashAuthority` are storage, not `immutable`.** They are
   fixed by the constructor and have no setter; storage keeps one shape across
   the two contracts (`AVIPRegistry` declares `sequencer`/`verifier` the same way)
   and keeps `forge lint` silent.
3. **`requiredStakeFor(norm)` and `collateralFor(norm)` are `public`.** §5.2 only
   named the per-validator readers. Exposing the policy *on a norm* is what lets
   M4 and the off-chain prover compute `C_R` and `S_f*` without reading
   per-validator state, and what the tests use to assert monotonicity, concavity,
   saturation and the inert floor over ranges of `r`.
4. **A proof for an older epoch cannot be replayed.** `admit` reads
   `registry.latestEpoch()` instead of taking an epoch argument; on a registry
   with nothing posted that is `type(uint256).max` and the call reverts with
   `UnknownEpoch`.
5. **The proof blob is `(a, b, c)`** and trailing bytes are ignored (§5.2.4, last
   bullet): asserted as a property, not assumed. (Since M3 the ignoring is done
   by `Bn254.decodeProof` rather than by `abi.decode`; the property is unchanged
   and the truncated case now reverts with `Bn254.MalformedProof`, §5.4.)

Validated locally: `forge build --offline --force` → clean with Solc 0.8.33, no
warnings, no `forge lint` notes; `forge test --offline` → **66 passed** (32
registry + 34 manager, two of them fuzz — the admission invariant and the policy);
`bash verification/audit-gate.sh` → `PASS=11 FAIL=0`, i.e. the anchor is
untouched, as expected since nothing under `integrations/` is sealed (§3).

### 5.4 M3 as delivered

Delivered: `contracts/verifiers/Bn254.sol` (library),
`contracts/verifiers/Groth16Verifier.sol`, `test/Bn254.t.sol`,
`test/Groth16Verifier.t.sol`, `test/fixtures/Groth16Fixtures.sol` (generated by
`scripts/generate_groth16_fixtures.py` and committed together with its
transcript), plus the one-line change in `AVIPRegistry.verifyThreshold` promised
by §5.2.4 (`abi.decode` → `Bn254.decodeProof`) and its two tests updated.

The verifier implements `IZKThresholdVerifier` **unchanged**: `verify(a, b, c,
input)` returns `true` iff

    e(−A, B) · e(α, β) · e(vk_x, γ) · e(C, δ) = 1,   vk_x = IC[0] + Σ_i input[i] · IC[i+1]

over BN254 with `i < 3` and `input = [root, epoch, certifiedNorm]`. Four pairs,
three of them constant: the only `0x07` calls are the two `vk_x` multiples plus
one `0x06` add.

Numbers, measured rather than asserted: `verify` costs **223,445 gas** in the
harness (`test_verify_costsAboutFourPairings`), of which
`45,000 + 34,000 × 4 = 181,000` is EIP-197 alone — consistent with the paper's
`181,142` for the pairing step. The paper's `≈206k` (`benchmarks/src/
GasBenchmarks.sol`) is a verifier with the key **inlined in the byte code**; the
deployed shape reloads the key from storage and copies the arrays into calldata,
which is the difference. The benchmark is the cross-check, not the target: this
milestone quotes both numbers instead of forcing them to agree.

Deviations and boundaries, all deliberate:

1. **The fixture is synthetic and this is the honest limitation.**
   `Groth16Fixtures.sol` holds a BN254 instance built by
   `scripts/generate_groth16_fixtures.py`: `A`, `B`, `C` and a verifying key
   whose pairing equation holds **by construction** (the script solves the scalar
   in the exponent for `C`), with `[root, epoch, 5e17]` as the statement that
   verifies. The real `keccak256` Merkle root is kept as `input[0]` (it is far
   below `r`, so it is a valid scalar). There is no circuit, no witness, no
   trusted setup and **no soundness claim**: what the tests prove is that the
   wrapper drives the **real precompiles** correctly and that every reject path
   returns `false` rather than reverting.
   `test/Groth16Verifier.t.sol::test_fixtureCertifiesTheManagersThreshold` pins
   the fixture's statement to `Θ_r`, so regenerating it cannot silently drift
   away from the parameter the manager enforces.
2. **A rejected proof is a `false`; a malformed one reverts.** Circom convention.
   `0x08` on a rejected input **consumes the entire gas budget** (measured
   ≈ 1.06e9 in `test_constructor_rejectsAKeyWithAnOffCurvePoint` and the
   off-curve proof test), so `verify` cannot answer `false` for a malformed
   proof: it reverts with `PrecompileFailed`/`CoordinateOutOfRange`. A caller
   that budgets gas per call must therefore treat "out of gas" as a failure and
   not as a rejection. Documented in `Bn254.sol` and in the test header.
3. **The Verifying Key is data, not code.** The constructor installs it and
   validates every point on the curve; `verifyingKeyDigest()` exposes
   `keccak256` of the installed key so a deployment can be checked against the
   ceremony transcript. Since no ceremony exists yet, that digest currently
   certifies the generator's placeholder key — it is the hook, not the evidence.
4. **Decision on the open Merkle ↔ Pedersen risk of §5.2.2: option (c).** The
   Keccak Merkle root stays the canonical on-chain commitment, so `verifyEntry`
   and every previously posted root keep their meaning and the freshness rule
   (which reads only the declared `changedEntries`) is untouched. The circuit
   proves the norm over a Pedersen commitment, and linking the two is the
   off-chain data layer's job (M7). The registry never sees a Pedersen
   commitment. Residual risk, stated rather than closed: an accepted norm is a
   norm of *some* committed tensor, and M3 alone does not prove it is the tensor
   behind the posted Merkle root.
5. **Only the on-chain half of A3 is closed.** The off-chain prover (Pedersen,
   Bulletproofs, recursive SNARK) and therefore any real proof remain M4 (planned
   in §5.5), and no
   proving-time or testnet-latency claim is made (§9: a new quantitative claim
   needs a backing script before it can reach `main.tex`).

Validated locally: `forge build --offline` clean, `forge fmt --check` clean, no
`forge lint` notes; `forge test --offline` → **100 passed** (32 registry + 34
manager + 16 `Bn254` + 18 `Groth16Verifier`), including the integration pair that
runs a real proof through `AVIPRegistry.verifyThreshold` and through
`AVIPValidatorManager.admit`.

### 5.5 M4 as planned (off-chain prover)

Status: **plan, not code.** `src/zk/` is the `cargo init` output committed as
`99db3fe` (`avip_zk_prover`, edition 2024): no dependencies, no significant
source, nothing to run but the generated `main`. This section is the gate §12
requires, and it follows the amendment pattern of §5.2 (M2) and §5.4 (M3): the
milestone's design, deviations and acceptance live with the plan, not in a
separate document that would drift from it. No `Cargo.toml` dependency and no
circuit is added until this section is reviewed.

The two risks §5.4 handed to M4 (the Ristretto ↔ BN254 mismatch, and the range
proof) are settled here, and neither waits for circuit code: the range proof is
decided analytically — mandatory, with its width derived — and the curve
mismatch is **dissolved by dropping the variant that carries it** (§5.5.5),
because the statement Option B needs turns out not to be expressible through a
deployable API. The measurement methods are still written down, with their
thresholds declared before any run, so that a future V1 inherits them.

Provenance of every constant used below — none of it invented:

| Quantity | Value | Source |
|---|---|---|
| Tensor, `N` entries | `T ∈ [0,1]^(C×D×H)`, `C·D·H = 500` | `main.tex` `eq:tensor` (L327, L331–333) |
| Object compared to `Θ_r` | the norm `‖T‖_F` | `main.tex` L333 |
| `Θ_r` | `0.5` | `main.tex` L463–464; enforced on chain since M2 |
| WAD convention | `1.0 = 1e18` | M3 fixture statement `[root, epoch, 5e17]` (§5.4) |
| Simulated norm range | `‖T‖_F ∈ [0, 3]` | `main.tex` L882; `threshold_quantization.py` L20, L40 |
| Bulletproofs at `N=500` | `≈6.5e6` gas off-chain, `0.72 KB` | `main.tex` L526, cited by `threshold_quantization.py` L25, L48 |
| Paper's design table | A: 1,080,501 constr. / ~470M gas; A′: 240,261 / ~30M; B: 0 / ~6.5M; proof sizes 0.20 / 0.20 / 0.72 KB | `main.tex` L515–518 |
| Recursive proof cost / proving time | `≈250k` gas; proving time **not measured**, estimated "tens of seconds" | `main.tex` L546, L548 |
| `bulletproofs 5.0.0` deployable surface | `RangeProof`, `LinearProof` (⟨a,b⟩ with **b public**), `range_proof_mpc`; the R1CS API (`yoloproofs`) is **UNSUITABLE FOR DEPLOYMENT** and **fails to build** (E0599 ×3, `r1cs/proof.rs` L180–182 vs `curve25519-dalek` 4.1.3) | `README.md` L43–50, L165–167; `src/lib.rs` L47–49; verified build (§5.5.5) |

#### 5.5.1 The relation: equality, not the paper's bit

`main.tex` §4.1 (`eq:threshold`) poses `‖T‖_F ≥ Θ_r` and returns a **bit**.
§5.2.2 already deviated deliberately: the circuit proves
**`‖T‖_F = certifiedNorm`**, and the *manager* applies `≥`. That is why the M3
statement is `[root, epoch, certifiedNorm]` and why `verifyThreshold` already
rejects a certificate that does not clear `Θ_r`.

The deviation is not cosmetic: it is what lets M4 close half of `Finding C-01`.
`verification/zk/threshold_quantization.py` (sealed) showed that the bit cannot
feed `eq:allocation` — `S_f*(T) = max{S_min, Θ − C_R(T)}` needs `C_R(T)` as a
**continuous** function of `‖T‖_F` (script L9–11, L127–128) — and that the paper
never connects the two (L166–184). With equality the certificate is a *value*,
and the on-chain readers `requiredStakeFor(norm)` / `collateralFor(norm)`
(§5.3 item 3) compute `C_R` from it. C-01's **soundness** layer stays closed
exactly as §4.3–4.4 intended; its **allocability** layer stops being blocked by
the circuit. What remains open is what M3 already left open: linking the Pedersen
commitment to the posted Keccak root (option (c), §5.4 item 4 → **M7**).

Arithmetic consequence of the range in the table: entries are non-negative and
`‖T‖_F = certifiedNorm ≥ 0`, so equality is tested on **squares**,
`Σ_i T_i² = certifiedNorm²`, with no square root in the circuit.

M4a corrected that last line, and the correction is recorded here rather than
only in the code. Over WAD integers the exact form has **no witness** unless
`Σ T_i²` happens to be a perfect square: with entries `[1..8]`, `Σ T_i² = 204`
and `⌊√204⌋ = 14`, so `204 ≠ 196`, and the two sides of the relation cannot be
made equal. A tensor whose sum of squares is a perfect square is a measure-zero
event, not a case a protocol can require. The relation the circuit enforces is
therefore the **floor**,

    certifiedNorm = ⌊√(Σ T_i²)⌋, encoded as  c² ≤ Σ T_i² < (c+1)²,

which is satisfiable for every tensor and needs no comparison gadget: `c` is
bounded by 64 bits, `Σ T_i² < 2^129` follows from `N·k` (§5.5.3), so both
inequalities are decided by "this difference is below `2^130`", and a negative
difference wraps to ≈`r − 2^129` and cannot pass. This preserves the contract's
semantics because `Θ_r` is an integer: `⌊‖T‖_F⌋ ≥ Θ_r ⟺ ‖T‖_F ≥ Θ_r`, so
`AVIPRegistry.verifyThreshold` and `collateralFor` reach the same decision they
reached with the exact form. The statement shape `[root, epoch, certifiedNorm]`
of M3 is unchanged, so no Solidity file moves.

#### 5.5.2 Three implementable variants (decision D-M4-0)

The paper fixes the primitive in Option B (Pedersen + Bulletproofs) but leaves
the recursion framework explicitly open: "The choice of recursion framework
(Groth16 recursion, Plonk recursion, Halo2 recursion) is not fixed in this
paper. All three produce constant-size on-chain proofs at similar gas cost; the
difference is the proving time and the trusted setup requirements" (§4.3).
Three things can actually be built in `src/zk/`, and they are not equivalent:

| | Commitment | Norm proved by | Outer proof | Curve mismatch |
|---|---|---|---|---|
| **V1** — paper literal | Pedersen over Ristretto (dalek) | Bulletproofs IPA over `⟨T,T⟩` | recursive SNARK/BN254 verifying the IPA | **yes**: Curve25519 ops inside `Fr_BN254` |
| **V2** — native adaptation | Pedersen over BN254 G1, recomputed **inside** the circuit | the same circuit: `Σ T_i²`, range folded into the bit decomposition | one Groth16/BN254, no recursion | **yes**: `Fq` coordinates inside an `Fr` circuit — corrected in M4a, below |
| **V3** — Option A′ revisited | Poseidon over the 500 entries, in-circuit | the same circuit: `Σ T_i²` + range | one Groth16/BN254, no recursion | no: everything native |

The **V2 row is corrected by M4a**, on type-level evidence rather than on
inspection. "Everything native" does not survive "Pedersen over BN254 G1,
recomputed inside the circuit": a G1 point has coordinates in `Fq`
(`ark_bn254::g1::Config` declares `COEFF_A: Fq`) while the outer proof M4b
installs is a Groth16 proof over BN254 whose **constraint field is `Fr`**, and
`Fq ≠ Fr`. The type check says it directly —
`ProjectiveVar<ark_bn254::g1::Config, FpVar<Fr>>` does not compile:

    error[E0277]: the trait bound `FpVar<...FrConfig...>:
                  FieldVar<Fp<...FqConfig...>, Fp<...FqConfig...>>` is not satisfied
    note: required by a bound in `ProjectiveVar`

because `ark-r1cs-std 0.6.0` implements `FieldVar<F, F> for FpVar<F>` and
nothing else (`src/fields/fp/mod.rs` L856). The only `FpVar` satisfying
`ProjectiveVar`'s bound for BN254 G1 is `FpVar<Fq>`, whose constraint field is
`Fq`, and no pairing curve with scalar field `Fq` exists to prove *that*
circuit. The native repair is a Pedersen group defined **over `Fr`** — Baby
Jubjub, `ark-ed-on-bn254`, whose base field *is* `Fr_BN254` — which is native
but is no longer "Pedersen over BN254 G1". So V2 as written meets the V1 wall one
level down: it needs `Fq` inside `Fr`, i.e. the emulated-field cost §5.5.4
quantifies, through the non-native **curve** gadget §5.5.4 established
`ark-r1cs-std 0.6.0` does not have. M4a therefore compares V3 against **V2′**
(Pedersen over Baby Jubjub), and the probe is kept in
`src/zk/tests/field_nativity_probe.rs` so the finding stays re-runnable.

V1 is the paper's own construction and the only one that needs the recursion of
`subsec:recursive`; §5.5.5 records why it leaves the implementation path, which
is what makes V2 and V3 the live candidates for `D-M4-0`. V2 keeps the paper's
commitment primitive (Pedersen,
`sec:zk` L428–440) but moves the linear/non-linear split from the proof system
into the circuit. V3 keeps Option A′'s primitive and drops the one-proof-per-entry
batching that the paper set aside on an **unmeasured practicality claim**, not on
a measurement: "With 240,261 constraints the circuit is still too large for
practical Groth16 proving on consumer hardware" (L502 — the neighbouring
Option A claim carries the explicit `[CONJECTURE]` tag, and L537 records that
"The proving time of the recursive proof is not measured."). All three emit
the **same public statement** — a Groth16 proof
over BN254 with `input = [root, epoch, certifiedNorm]` — so **M3's verifier and
every Solidity file are unchanged by the choice**; only the key changes.

D-M4-0 is resolved in M4a **by measurement**, against thresholds declared before
the runs (§5.5.4, §5.5.6), but the branch it decides is narrower than it was when
this section was drafted: §5.5.5 takes V1 out of the implementation path on
crate-level evidence, so M4a compares V2 against V3. The paper's `[CONJECTURE]` ("too large for practical
Groth16 proving on consumer hardware") is not treated as a result: §9 requires
that a claim contradicting it carry its own backing script before it can reach
`main.tex`. **The measurement closed the decision in M4c (§5.5.10): V3** — by
59,250 constraints (94,438 against 153,688) and by one curve, because V2′'s
commitment costs 240 constraints per entry against Poseidon's ≈121. The verdict is
returned by `duel_verdict` rather than declared here, so the branch is a computed
value and not a preference (§10 D-6).

#### 5.5.3 Why the range proof is mandatory, and how its width is derived

This is risk 2, and it is not a corner case: **without a range proof the equality
is trivial to forge.** The commitment lives over the free scalars of `Fr`, so a
validator with no reputation can pick witnesses satisfying
`Σ T_i² ≡ certifiedNorm² (mod r)` while none of the `T_i` is an admissible score.
The degenerate witness `T_1 = r − 1` gives `T_1² ≡ 1 (mod r)` — computed:
`(r−1)² mod r = 1` — so a single entry absorbs arbitrary leftovers. This is the
same failure class §4.5 records for the original construction (a property of a
value the prover controls completely), one level down. The range check is
therefore part of the relation in **all three** variants; it is not an
optimisation.

Its width is derivable rather than conventional. With WAD, an entry is at most
`1e18`, and `2^60 = 1152921504606846976 > 1e18`, so

    k = 60 bits per entry is sufficient, and N·k = 30,000 bits in total.

There is no wraparound in the norm provided `N·2^(2k) < r_BN254`. Computed:

| Quantity | Value |
|---|---|
| `r_BN254` | `21888242871839275222246405745257275088548364400416034343698204186575808495617` (`log2 r = 253.60`) |
| `N·2^120` at `k = 60` | `6.646e38` |
| margin `r / (N·2^120)` | `3.29e37` |
| largest `k` with `N·2^(2k) < r` | `122` |
| `Σ T_i²` worst case, WAD | `N·1e36 = 5e38 < r` |
| `certifiedNorm²` at `‖T‖_F = 3` | `9e36` |

`k = 60` sits inside the 62 bits of headroom the arithmetic allows, so the bound
is not tight and cannot be argued away by a clever witness: any `k ≤ 122` is
wraparound-free, and every entry outside `[0, 2^60)` is excluded by *bits*, not
by a numerical comparison that could overflow.

Where the check is paid differs by variant:

- **V2 / V3**: it is free in the sense that the scalar is *defined* as
  `Σ_j 2^j · b_j` from `k` Booleans, so out-of-range witnesses are not
  representable and no separate proof object exists;
- **V1** (archived, §5.5.5): it would be an **aggregated Bulletproofs range proof
  of 30,000 bits** — a second non-linear object whose verifier must itself sit
  inside the BN254 circuit, so risks 1 and 2 compound instead of cancelling. That
  compounding is part of why V1 is not the cheap option it looks like.

One published number needs care, and M4a reports its own: `0.72 KB` (`main.tex`
L498) is quoted from the literature for `N = 500`, and
`threshold_quantization.py` already treats it as **per threshold** (L145–146:
`k × 0.72 KB`, "una prueba de rango por umbral").

**M4a measured it, and the aggregate §5.5.3 writes down is not constructible.**
Two parameters of this bulletproof are not available in the aggregated API of
`bulletproofs 5.0.0`:

- the width must be one of `n ∈ {8, 16, 32, 64}` — `range_proof/dealer.rs` L45
  and `range_proof/party.rs` L44 reject everything else, for proving *and* for
  verifying — so the derived `k = 60` cannot be used and the measurement runs at
  `k = 64`, the nearest supported width above it. Nothing is lost: §5.5.3 already
  shows any `k ≤ 122` is wraparound-free;
- the value count must be a power of two (`Dealer::new`:
  `if !m.is_power_of_two() { return Err(MPCError::InvalidAggregation) }`,
  `dealer.rs` L48). `N = 500` is not one, so an aggregated proof covers 512
  values (twelve zero-padded) and the object is `512 × 64 = 32,768` bits, not
  `30,000`.

Measured on the reference machine, with the deterministic fixture:
**1248 bytes (39 elements), 1.696× the paper's `0.72 KB`**, over a generator set
of `2 · 64 · 512 = 65,536` points. The size matches the format's own prediction,
`2·lg(n) + 9` elements for `n` bits (`RangeProof::to_bytes`, crate
`range_proof/mod.rs` L477–487), which is the check that the measurement is not
misread. The paper's figure is therefore the estimate it is — and it is an
*under*-estimate, by a factor of 1.70, before any `k × 0.72 KB` multiplication
for thresholds or the padding for `N = 500`. Both API restrictions are pinned by
fast tests in `src/zk/src/range_proof.rs`, so the finding is re-runnable rather
than remembered.

The durations are reported separately, and that separation is itself a decision
worth recording: proving took **3.2–5.4 s** and verifying **0.27–0.44 s** across
runs of the *same* revision — `verify` alone moved by 66% between two
consecutive runs — so they cannot sit in a committed table that re-running must
reproduce byte for byte (§5.5.6). `scripts/m4a_report.sh` writes the
deterministic quantities to `scripts/m4a_output.txt` and prints the durations to
stderr; the split, and the two-run check that confirmed it, are in §5.5.8.

#### 5.5.4 Risk 1 — the Ristretto ↔ BN254 mismatch, and how it would be measured

Status after §5.5.5: **off the critical path.** The mismatch exists only in V1,
which §5.5.5 drops, so this measurement no longer gates the build. It is kept
because it is the quantified evidence a P6b amendment needs, and because it is
the method M4a would run if V1 ever returned. It does not start from the
literature; it starts from the crate sources, inspected for this plan:

- `ark-r1cs-std 0.6.0` **has** non-native field arithmetic, under a renamed
  module: `fields::emulated_fp::EmulatedFpVar<TargetF, BaseF>`, with
  `NonNativeFieldConfig`, `OptimizationType` and `MulResultVar` (found by
  unpacking the published crate tarball, 117,561 bytes).
- `ark-r1cs-std 0.6.0` has **no non-native curve gadget**. `groups/` contains
  only `curves/`; the `CurveVar` trait lives in
  `groups/curves/short_weierstrass`, is implemented for curves whose base field
  *is* the R1CS field, and `AffineVar` is parameterised by
  `F: FieldVar<P::BaseField, …>`. There is no `groups::non_native` module and no
  `NonNativeAffineVar` type.
- Same crate family, versions confirmed from the registry: `ark-groth16 0.6.0`,
  `ark-bn254 0.6.0`, `ark-ff 0.6.0`; and for V1:
  `bulletproofs 5.0.0` ("a pure-Rust implementation of Bulletproofs using
  Ristretto"), `curve25519-dalek 5.0.0`, `merlin 3.0.0`.

So V1 could not delegate the emulation: a Ristretto/Curve25519 point operation
inside `Fr_BN254` would have to be written on top of `EmulatedFpVar`. That was
the obligation that made this subsection necessary, and it fixes the method —
**unit cost × operation count**, not a guess — for anyone who re-opens V1:

1. measure `c_emu`: constraints for one emulated multiplication in a 255-bit
   target field, for both `OptimizationType::OptimizedForConstraints` and
   `OptimizedForWeight`;
2. multiply by the operation counts, taken from the paper rather than assumed:
   the on-chain Bulletproofs verification for `n = 500` "requires `2n` scalar
   multiplications and `2n` point additions" (L1170), i.e. 1,000 group
   operations of each kind, on Curve25519 emulated inside `Fr_BN254`;
3. report the product as an **upper bound with its assumptions**, next to the
   native baseline `c_nat` for the same point operation over BN254;
4. report `c_emu / c_nat`, both key sizes and both proving times.

Thresholds, declared **before** measuring so the verdict cannot be
reverse-engineered (they are kept, and they bind any future re-opening of V1):

- `c_emu / c_nat ≤ 100` **and** outer proving `≤ 120 s` on the reference machine
  would have kept V1 alive. The time bound is deliberately loose against the
  paper's own unverified estimate, "in the range of tens of seconds on a modern
  CPU" (L520), which is exactly what M4 exists to replace with a measurement;
- below them **V1 would be dropped on the measurement** — and §5.5.5 has already
  brought that outcome forward on crate-level evidence, so M4b builds V2 or V3
  without waiting for this bench.

For V2/V3 the same metric is measured natively, and it yields the number the
paper lacks: the constraint count of computing a 500-entry commitment *and* the
norm inside one circuit. One concrete observation from the source that M4a
tests: the ready-made gadget `CurveVar::precomputed_base_multiscalar_mul_le`
loops `for (bits, bases) in scalars.zip(bases) { … precomputed_base_scalar_mul_le(…) }`
— one double-and-add **per entry**, i.e. `N·k` doublings — whereas a transposed
(two-dimensional) MSM shares `k` doublings across all `N` bases. M4a benches both
and reports which one is used.

#### 5.5.5 The gap that decides V1: the IPA proves a bilinear statement

This is the risk `threshold_quantization.py` already flagged from the other side
(L178–180: "Bulletproofs es nativo para enunciados lineales, asi que C_R(T) no
es expresable sobre el commitment sin revelar ||T||_F"), applied to the norm
itself rather than to `C_R`.

The IPA proves `∃ a, b : P = ⟨g,a⟩ + ⟨h,b⟩ ∧ ⟨a,b⟩ = v`, where `a` and `b` are
**independent** vectors and `v` is public. The norm needs `⟨T,T⟩` — the *same*
vector on both sides — while the Pedersen commitment to the tensor uses a single
base vector. Nothing in the protocol as written ties the two halves to the
committed `T`, so what is proved is a statement about a *split* of `T`
(`a + b = T` over one shared base), not about `‖T‖²`. A prover who controls the
split is not proving a norm: under the single-base reading `P = ⟨g, a+b⟩`, a
witness with `T = 0` and `a + b = 0` gives `⟨a,b⟩ = −⟨a,a⟩`, and `−1` *is* a
square in `Fr_BN254` (`r ≡ 1 mod 4`; computed `Legendre(−1) = 1`, with
`√−1 = 2^((r+3)/8)` because `(2^((r+3)/8))² = r − 1`), so `⟨a,a⟩ ≡ −c²` is
solvable and the degenerate witness clears the equality for an **arbitrary** `c`.
That is §4.5's failure mode returning one level down.

This is a **structural gap, not an implementation detail**, and it is why V1 is
not "V2 with extra steps":

- The fixings were evaluated against the crates themselves, not from memory, so
  the verdict is recorded here instead of being deferred to M4a.
  - **What the statement needs.** `Σ T_i² = v` is *quadratic* in `T`: it needs
    multiplication gates (`a_i · a_i = c_i`) plus a linear sum. The bare IPA
    cannot supply that, because it proves `⟨a,b⟩ = v` for **independent** `a,b`.
  - **The deployable surface of `bulletproofs 5.0.0` cannot express it.**
    `lib.rs` exposes `RangeProof`, `LinearProof` and `range_proof_mpc`; the
    inner-product module is private (`mod inner_product_proof;`). `LinearProof`
    documents itself as proving "`<a, b> = c` where `a` is secret and `b` is
    **public**" (GHL'21 §E.3) — a *cross* product, and with `b` chosen by the
    prover (`b = (v/⟨a,a⟩)·a`) it is satisfiable for any `a`, so it never says
    `a = b` and never certifies a norm.
  - **The one API that can express it does not build.** The quadratic relation
    *is* expressible in `bulletproofs::r1cs` (`ConstraintSystem`, `Prover`,
    `Verifier`, `R1CSProof`; `src/r1cs/`), whose documented relation is exactly
    `a_L ∘ a_R = a_O` plus linear constraints over committed high-level
    variables (`docs/notes-r1cs.md`): using the *same* variable on both sides of
    `multiply` is what forces both halves to be one `T`. But the module is gated
    (`#[cfg(feature = "yoloproofs")] #[cfg(feature = "std")] pub mod r1cs;`,
    `src/lib.rs` L47–49) and **enabling that feature does not compile** —
    verified, not quoted: with
    `bulletproofs = { version = "=5.0.0", features = ["yoloproofs"] }` the build
    stops with three `E0599`s in `src/r1cs/proof.rs` L180–182 (`no method named
    ok_or found for struct CtOption<Scalar>`), because the module still expects
    the `curve25519-dalek` 3.x signature `Option<Scalar>` while the dependency it
    declares (`4.1.1`, resolved to `4.1.3`) returns `CtOption<Scalar>`
    (`scalar.rs` L261). The published crate therefore ships that feature as dead
    code, which is why its README says the API "is disabled in the published
    version of the crate, so it can only be used by specifying a git dependency
    on the `develop` branch". A git dependency contradicts §5.5.6's
    reproducibility requirement, and the crate additionally declares the feature
    **UNSTABLE AND UNSUITABLE FOR DEPLOYMENT** and **PROVIDED FOR TESTING ONLY**,
    outside semver compatibility (`README.md` L43–50, L165–167). Reproduced by
    `src/zk/scripts/check-yoloproofs-gate.sh`.
  - **The paper's numbers are not the numbers for its own statement.**
    `main.tex` L518 lists `Option B` at `0` R1CS constraints and L538 estimates
    `0.72 KB` from `2N` scalar multiplications; both describe the *bare* IPA. A
    500-entry norm consumes 500 squaring gates plus a linear constraint, and the
    recursive SNARK must then verify *that* verifier instead of the plain one.
    The paper also never writes the relation: L442 says only that the prover
    "commits to `T` in some form and proves knowledge of a witness satisfying the
    inequality", and L510 rests soundness on "the special-soundness of the
    Bulletproofs protocol and the binding property of the Pedersen commitment",
    neither of which ties the two IPA halves to the committed `T`.
- **Verdict recorded here rather than deferred to a bench: V1 is dropped from the
  implementation path.** Not because the relation is unprovable in general — a
  proper arithmetic-circuit argument proves it — but because the only form
  implementable with the chosen crate rests on an API its authors declare
  unsuitable for deployment, and because its cost is not the cost the paper
  quotes. V2 and V3 show no such gap: their circuit computes `Σ T_i²` from the
  very witnesses it commits to.
- The normative result travels to the P6b batch through §9, anchored on the M4a
  note: **Option B as stated specifies no relation that implies the norm, and
  the general-purpose primitive it names cannot express one through a deployable
  API.**

Consequence for the ordering: §5.5.5 no longer needs an experiment. Because V1
goes, **risk 1 is dissolved rather than measured** — the curve mismatch exists
only in V1 — and §5.5.4 becomes the record of what the dropped variant *would*
have cost, i.e. evidence for the P6b amendment instead of a gate on the build.
M4a's live measurement is the native one: the constraint count of commitment,
norm and range inside a single circuit (§5.5.3), which is the number the paper
lacks.

#### 5.5.6 M4a and M4b as two gates

Both gates are Rust-only. **Neither changes Solidity**: M4b installs a derived key
into the existing verifier contract, and `AVIPRegistry`'s constructor already
takes the verifier address (§5.4 item 3). The registry and the manager are
untouched, so the measured `verify` cost must stay at the M3 figure (223,445
gas) — a drift there is a regression, not a new measurement.

**M4a — the inner layer, measured.** Deliverables:

- `src/zk/src/` modules and `benches/`: the aggregated-range-proof bench
  (§5.5.3), the native commitment + norm circuit — **V3** as implemented, and
  **V2′** (Pedersen over Baby Jubjub, §5.5.2), landed in §5.5.10, because V2 as
  written is blocked at the type level — and the `⟨T,T⟩` statement written down
  for V1 with the rejection §5.5.5 records. The emulated-field unit bench
  (§5.5.4) is **optional**: it runs only if V1 is ever re-opened, and no bench of
  the emulated IPA is scheduled;
- a deterministic fixture: one fixed 500-entry tensor from a fixed seed, byte
  identical across runs — the off-chain analogue of
  `scripts/generate_groth16_fixtures.py` (§5.4);
- a note with the measured table: constraints per variant (V2′ and V3), key size,
  proving time, proof size, the `c_emu / c_nat` figure §5.5.4 keeps on the record
  for the amendment, and the **D-M4-0 verdict** (V2′ vs V3) quoting the
  thresholds declared *before* the runs (§5.5.3, §5.5.4).

Acceptance: `cargo build` and `cargo test` clean, and every number in the note
reproducible by one documented command. The crate builds offline today because
it has no dependencies; each dependency added must keep that property or the
exception must be stated in the note. Non-goals: no ceremony, no production
circuit, no on-chain change, no testnet-latency claim.

**Both clauses are now answered, and one of them by a correction.** The offline
property survived the dependency tree: with `target/debug` deleted,
`cargo fetch --offline` and `cargo build --offline` both succeed (25.7 s) from
the committed lock, so `src/zk/` keeps the workspace's offline character. The one
command that cannot follow is `scripts/check-yoloproofs-gate.sh`, which builds a
throwaway crate against `bulletproofs` to re-verify §5.5.5; that exception is
stated in the note and in the script. The reproducibility clause did *not* hold
on the first try, which is worth recording because it was not a bug in a
computation: the report wrote wall-clock durations into its table, and re-running
it changed those lines while every counted quantity stayed identical. Durations
therefore left the table for stderr (§5.5.8), and the committed table is now
byte-stable under re-runs. The general rule this leaves behind: a pinned artefact
may hold only quantities the pinned command reproduces.

**M4b — the outer layer and the composition.** Deliverables:

- the chosen circuit's Groth16 key, derived for real, replacing the M3
  placeholder; `AVIPRegistry`, `IAVIPRegistry` and `AVIPValidatorManager` are not
  edited, and `verifyingKeyDigest()` (§5.4 item 3) is the hook that publishes
  `keccak256` of the installed key;
- the development setup, with its depth stated in plain words: universal phase 1
  reused plus **one** phase-2 contributor, transcript committed. A single
  contributor is a development setup and carries **no** security claim; a real
  multi-party ceremony stays out of scope (§11);
- one real proof for the deterministic fixture, accepted end to end by the
  existing `Groth16Verifier` and by `AVIPRegistry.verifyThreshold`. The M3
  synthetic fixture in `test/fixtures/Groth16Fixtures.sol` is retired, or kept
  **only** as the precompile-driving test §5.4 item 1 describes it as;
- the M4a acceptance re-run on the frozen revision.

#### 5.5.7 What M4 does not close

- The Pedersen ↔ Merkle bridge: unchanged, option (c), **M7** (§5.4 item 4).
- Treasury and custody, `P5`: **M8** with its own amendment — the label fix
  `e33ce98` exists to keep that boundary.
- Multi-party ceremony, external audit, mainnet: §11.
- Any change to `main.tex`: if M4a's verdict contradicts the paper's
  `[CONJECTURE]` about Option A′, it enters the P6b batch through §9's re-anchor
  procedure, anchored on the M4a script.
- A production-grade circuit: M4 proves the pipeline and its cost, not a
  deployment.

#### 5.5.8 M4a — the first measurement pass, as delivered

Recorded here because the plan is the milestone's record (§5.5). The crate
`src/zk/` now has exact pins (`=0.6.0` for the `ark-*` family, `=5.0.0` for
`bulletproofs`, `=4.1.3` / `=3.0.0`), a committed `Cargo.lock`, a deterministic
fixture, the aggregated range-proof bench and the native circuit, with
`cargo test` (13 tests) and `cargo clippy --all-targets` clean. Every number is
reproduced by `src/zk/scripts/m4a_report.sh`, which writes
`src/zk/scripts/m4a_output.txt`; the crate's `README.md` is the note §5.5.6 asks
for.

Measured on this machine, over the frozen fixture
(keccak `c2309377a00b109a…d77d9aa9`, `Σ T_i² = 1.6368e38 < r`, entries `< 2^60`):

| Quantity | Measured |
|---|---|
| Aggregated range proof | `512 × 64 = 32,768` bits → **1248 B** (1.696× the paper's `0.72 KB`), 39 elements |
| V3: Poseidon commitment + norm | **93,608 constraints**, 92,704 witnesses, satisfied |
| V3: norm alone (shared with V2′) | **32,860 constraints**, 31,957 witnesses, satisfied |
| Durations (stderr, load-dependent) | prove **3.2–5.4 s**, verify **0.27–0.44 s**, synthesized 16 ms / 73 ms |

The first three rows are the pinned ones: `scripts/m4a_report.sh` reproduced
`m4a_output.txt` byte for byte on two consecutive runs. The fourth row is why the
script has the shape it has. A first version wrote the durations into the table,
and re-running it **drifted** — `prove/verify` went from `3.300 s / 0.272 s` to
`5.427 s / 0.442 s` with every counted quantity identical, because the machine was
loaded. That breaks §5.5.6's acceptance ("every number in the note reproducible by
one documented command") in a way that would be easy to mistake for a real
change, so `render` now emits only counters and sizes and `render_timings` sends
the clocks to stderr. The durations still bound what M4b will cost, but they are
an observation about *this* machine, not a property of the revision.

Two readings of those numbers belong in the record. The norm alone costs
`32,860` constraints at `N = 500` with `k = 60` folded in, which is where the
paper's missing number lives; Poseidon over 500 entries adds `60,748`, i.e. the
commitment is the dominant term, not the norm. And `93,608` sits below the
paper's Option A′ (`240,261`, `main.tex` L516) by a factor of 2.6, so the plan
does **not** have to treat the paper's `[CONJECTURE]` ("still too large for
practical Groth16 proving on consumer hardware", L502) as settled: M4b's proving
time is the measurement that decides it, and §9 requires the backing script
before any amendment reaches `main.tex`.

Three deviations were found by building the thing rather than by reading it, and
each is recorded where it bites: §5.5.1 (the exact-square relation has no
witness; the floor is what the circuit certifies), §5.5.2 (V2's "no curve
mismatch" does not hold for `BN254 G1` inside an `Fr` circuit) and §5.5.3 (the
aggregated proof's width and value count). A fourth is an upstream limitation
that M4a works around rather than reports: `CmpGadget for [T]` in
`ark-r1cs-std 0.6.0` compares incorrectly, so the norm's inequalities are decided
by a bounded difference instead.

**Not yet delivered in M4a**, and therefore not yet decided: **V2′** (Pedersen
over `ark-ed-on-bn254`, the native repair of §5.5.2), key size, proving time, and
the `D-M4-0` verdict itself — M4a compares V3 against V2′, not against the V2 row
as §5.5.2 originally wrote it.

#### 5.5.9 M4b — the outer layer, as delivered

Recorded on the same terms as §5.5.8: the plan is the milestone's record. M4b
derived the real key and proved the fixture end to end. It added
`src/zk/src/groth16.rs` (the statement circuit, the seeded development setup, the
end-to-end prover, the binding checks), the two drivers `src/zk/src/m4b.rs` and
`src/zk/src/m4b_fixture.rs`, `src/zk/tests/groth16_statement_shape.rs`, and
`src/zk/scripts/{m4b_report.sh,m4b_fixture.sh}` with the pinned
`src/zk/scripts/m4b_output.txt`. On the contract side it added
`integrations/avalanche/test/fixtures/M4bGroth16Fixtures.sol` (emitted by
`src/zk`) and `integrations/avalanche/test/M4bRealKey.t.sol` (retired by M4d,
§5.5.11), and edited no
contract: nothing under `integrations/avalanche/contracts/` changed.

Measured over the §5.5.6 fixture, on this machine:

| Quantity | Measured |
|---|---|
| V3 in the statement wrapper, `[root, epoch, certifiedNorm]` | **94,438 constraints**, 93,189 witnesses, 4 instance variables, satisfied |
| The wrapper's own cost over V3 (`93,608`) | **+830 constraints (+0.9%)**, all of it `epoch < 2^64`; derived in the test from the gadget, not pinned |
| Key: `a` / `b_g1` / `b_g2` / `h` / `l` queries | 93,193 / 93,193 / 93,193 / 131,071 / 93,189 |
| `ic` | **4**, so `numPublicInputs() = 3` — what `Groth16Verifier` requires and what `AVIPRegistry` reads |
| Proof | 128 B compressed, **256 B on-chain** (`8 × 256`-bit) |
| Durations (stderr, load-dependent) | setup **6.6 s**, prove **3.9 s**, verify **1.3 ms** |

The wrapper's `+830` is not the `190` that a "one constraint per bit above the
bound" reading predicts, and the difference is a finding rather than a footnote:
`FpVar::to_bits_le` in `ark-r1cs-std 0.6.0` allocates the 254 bits of the
decomposition *and* checks the packed value is in the field
(`to_non_unique_bits_le` plus `enforce_in_field_le`), so the gadget costs 485
witnesses and 640 constraints before the 190 zero-checks are added.
`tests/groth16_statement_shape.rs` therefore derives the wrapper's delta by
running the gadget on a constraint system of its own, the way the wrapper
allocates it, instead of quoting a number — which is also what lets the figure
move when the crate does, without the table turning into a lie.

The last row closes the first half of **A11**, and it closes it by measurement
rather than by argument: the outer prover takes `3.9 s` against the **120 s**
threshold §5.5.4 declared before the run — a factor of 30 — so the paper's
`[CONJECTURE]` ("still too large for practical Groth16 proving on consumer
hardware", L502) does not hold at this circuit size on this machine. Three things
that number is *not*: a recursive SNARK (M4 proves one layer, §5.5.7), a claim
about a ceremony-grade key, or an on-chain cost (M3's 223,445 gas stands).

**What makes it a proof rather than a shape.** M3's fixture solves the Groth16
equation for `c` with no witness; M4b's has one. The fixture is the deterministic
500-entry tensor of §5.5.6, the circuit is V3 (`Σ T_i²` and its floor predicate,
plus the Poseidon commitment of the same entries), and the statement is the vector
`AVIPRegistry.verifyThreshold` builds from its own storage:
`[commitmentOf(epoch), epoch, certifiedNorm]`. `test/M4bRealKey.t.sol` (retired
by M4d, §5.5.11) installed the real key in the frozen `Groth16Verifier` and got
`true` back, then posted the certifying root as the sequencer and got `true`
from `verifyThreshold` itself.

**The epoch is bound, and the test that says so is the interesting one.** An
*unused* public input keeps the identity as its `gamma_abc_g1` entry, so the
pairing equation ignores it and a statement with a fresh epoch would verify
against an epoch-0 proof. `groth16.rs` therefore constrains `epoch < 2^64`
in-circuit, and the Solidity test *checks* the consequence instead of asserting
it: the same root is posted at epoch 1 and the epoch-0 proof is rejected there.
The off-chain counterpart (`binding.epoch/root/norm`) runs on every report.

**A development setup, stated in plain words.** One phase-2 contributor
(`SETUP_SEED`), with the proving randomness seeded too (`PROOF_SEED`); both are
committed and both are written into the fixture. The toxic waste is therefore
derivable by anyone and **forgeries are free**: the key is an instrument for
measuring the pipeline and for exercising the frozen verifier, not a key that
carries a claim. The ceremony that would carry one is §11, and the generated
fixture says this in its own header.

**Two encoders, one digest.** `verifyingKeyDigest()` is `keccak256(abi.encode(vk))`
over the contract's own layout; M4b recomputes it in Rust from the ABI layout and
the Solidity test compares the two. That check earned its place immediately: the
first Rust encoder wrote 24 words (768 B) and the contract produced 25 (800 B),
because a struct *with a dynamic member* is itself dynamic and `abi.encode` heads
it with an offset to its contents. A hand-written "same bytes" comment would have
shipped the wrong digest; the test did not.

**The M3 fixture is kept, and only as what §5.5.6 allows.** Its off-curve,
identity, arity and gas-bound tests are exactly what a real key cannot produce
(`Groth16Verifier.t.sol` still measures 223,445 gas through it), so it stays as
the precompile-driving test, and its header says so.

Validated: `cargo test` → *19 passed, 0 failed, 1 ignored* (the ignored one is
M4a's 32,768-bit range proof); `cargo clippy --all-targets -- -D warnings` and
`cargo fmt --check` clean; `forge test` → *107 passed, 0 failed*, 7 of them
M4b's, and `forge fmt --check` clean; `m4b_report.sh` twice → `m4b_output.txt`
byte-identical; the M4a acceptance re-run → `m4a_output.txt` unchanged.

Still open when M4b was delivered: **V2′** and therefore `D-M4-0` (§5.5.2,
§10 D-6) — both closed in §5.5.10 — and, unchanged by it, the Pedersen ↔ Merkle
bridge (M7, §5.5.7) and a multi-party ceremony and an audit (§11).

#### 5.5.10 M4c — V2′, and `D-M4-0` closed

Recorded on the same terms as §5.5.8 and §5.5.9. M4c built the branch §5.5.2 had
repaired *on paper* — **V2′**, Pedersen over Baby Jubjub — and measured it through
**M4b's own statement wrapper**, so the decision compares two rows of one table
rather than two pipelines whose wrappers could drift apart. It added a `v2` module
to `src/zk/src/native.rs` (one seeded parameter set, the fixed-base gadget, the
circuit), the variant switch to `src/zk/src/groth16.rs` (`Variant`,
`variant_circuit_for`, `variant_key_and_proof`, `variant_root`, `measure_variant`,
`render_duel`, `duel_verdict`), six tests to `native.rs` and four to
`src/zk/tests/groth16_statement_shape.rs`, and one new dependency to the crate
(`ark-ed-on-bn254 = "=0.6.0"` with `r1cs` + `std`, `Cargo.lock` committed —
`cargo build --offline` still succeeds, so the offline property §5.5.6 requires is
intact). The duel is
pinned in `src/zk/scripts/m4b_output.txt` **below** M4b's V3 section, and that
section is byte-identical to the file §5.5.9 committed: M4c added a measurement
rather than disturbing one. **No file under `integrations/avalanche/` was edited**,
which is what a V3 verdict means — the key M4b installed is the key that ships.

**Why Baby Jubjub, and what the bits are for.** V2 as written is blocked because
G1 coordinates are `Fq` while the wrapper's constraint field is `Fr` (§5.5.2).
Baby Jubjub's **base** field *is* `Fr_BN254`, so the coordinates fall inside the
circuit natively — that is the entire repair — but its **scalar** field is a
*different* prime, so a scalar cannot be a witness of this circuit either. The
gadget therefore takes the `T_i` **as 60 bits**, the decomposition §5.5.3's range
check already pays for (discarding it and re-decomposing would pay twice), and the
bases are constants: public parameters do not have to be variables. `root` is the
commitment's **x-coordinate**, because the frozen statement carries one `uint256`
for it; binding a full point would need a second word and is an M7 / §5.5.7
question, not a variant question — both variants expose the same three public
inputs, in the same order, with the same `ic = 4`.

**The duel, measured through one wrapper** (`m4b_output.txt`; `V2′`'s bare circuit
is the row `m4a_output.txt` prints):

| Quantity | V3 | V2′ |
|---|---|---|
| Constraints in `[root, epoch, certifiedNorm]` | **94,438** | **153,688** (+59,250, +62.7%) |
| Witness variables | 93,189 | 152,439 |
| `a` / `b_g1` / `b_g2` / `l` queries | 93,193 / 93,193 / 93,193 / 93,189 | 152,443 / 152,443 / 152,443 / 152,439 |
| `h` query | 131,071 | 262,143 |
| `ic` (what the contract reads) | 4 | 4 |
| Proof | 256 B on-chain | 256 B on-chain |
| Setup / prove / verify (stderr, one run) | 6.5 s / **3.9 s** / 1.3 ms | 10.0 s / **6.3 s** / 1.3 ms |
| Curves an implementation must carry | **1** (BN254: the commitment is field arithmetic) | **2** (BN254 + Baby Jubjub) |
| Commitment's share at 500 entries (§5.5.8) | Poseidon **60,748** | Pedersen **119,998** |

The gap is entirely in the commitment, and the two scripts prove it rather than
assert it: V2′'s wrapper costs +830 constraints over its own bare circuit — the
same `epoch < 2^64` bound M4b added to V3 — so 153,688 − 830 = 152,858, and
152,858 − 32,860 = 119,998 *is* the Pedersen share in `m4a_output.txt`. A test
asserts that subtraction for both arms, so the two files cannot diverge silently.
The `h` query crossing 2^18 is the same 62.7% seen from the prover's side — 59,250
constraints can push a query past a power-of-two boundary — and the measured
proving time moves with it (V3 `3.9–4.1 s` over two runs, V2′ `6.3 s`), well inside
§5.5.4's 120 s budget for *either* variant. The constraint count, not the clock, is
what decides.

**Why V3 wins, and how much of a margin it is.** Per entry: Poseidon ≈121
constraints (60,748 / 500), Pedersen 240 — `ENTRY_BITS = 60` consumed in 2-bit
windows, 30 windows of 8 constraints each, which `native.rs`'s tests *derive* from
the gadget (affine in the entry count, one constant per window) instead of pinning
the number. The verdict is therefore **comfortable on the measured gadget and near
a tie on a hypothetical one**: `ark-r1cs-std 0.6.0` exposes only the 2-bit
`precomputed_base_scalar_mul_le` for `AffineVar`, and at *4* bits the Pedersen
share would roughly halve to ≈60,000, within a few hundred constraints of
Poseidon's 60,748. That is an estimate read off the gadget, not a second
measurement, and it is recorded because it is what makes the *second* criterion
load-bearing rather than decorative: if the constraints ever draw level, the
tie-break is that V2′ costs a second curve — a second parameter set, a second
setup, a second set of audits — while V3 stays inside BN254.

**The verdict is computed, not transcribed.** `render_duel` prints the two rows;
the sentence beneath them comes from `duel_verdict`, which compares constraints
first and curve count second, and a test asserts the decision on the measurements
rather than on a substring of the table. §5.5.4 declares no numeric threshold for
*this* branch — the plan commits only to deciding "on the measured cost" — so a
hand-written verdict would be a claim with no derivation, exactly what §5.5.8's
methods exist to avoid. The table prints the criterion beside the numbers it
applies to.

Validated: `cargo test` → *29 passed, 0 failed, 1 ignored* (6 of the 29 are V2′'s,
in `native.rs`; 4 are the new ones in `tests/groth16_statement_shape.rs`; the
ignored one is M4a's 32,768-bit range proof); `cargo clippy --all-targets -- -D
warnings` and `cargo fmt --check` clean; `cargo build --offline` from the committed
lock; both report scripts re-run → their committed outputs byte-identical
(`m4b_output.txt`'s V3 section included, which is M4b's acceptance re-run);
`bash verification/audit-gate.sh` → *PASS=11, FAIL=0*. Nothing under
`integrations/avalanche/` was touched, so §5.5.9's contract validation stands
exactly as recorded (107 passing tests, 223,445 gas through the verifier).

Still open, and unchanged by M4c: the *paper-literal* recursive construction
(§5.5.5, §5.5.7); the Pedersen ↔ Merkle bridge (M7); a multi-party ceremony and an
audit (§11). `D-M4-0` is closed as **V3** (§10 D-6), which is the variant M4b had
already installed, so no artefact on either side of the boundary changes.

#### 5.5.11 M4d — admission binding and the two roots (audit P-01/P-16)

M4b proved a *global* norm over the 500-entry tensor and said nothing about the
validator. The verifier therefore accepted a **bearer token**: one valid proof
could be presented by any address. That is audit finding **P-01**, and M4d
replaces the statement rather than adding a check around it.

The admission circuit proves inclusion of one leaf:

```text
leaf_i  = Poseidon(validator_i, norm_i)
root    = Poseidon Merkle root over 2^9 leaves (500 real, zero-padded)
public  = [statementRoot, epoch, validator, norm]
witness = (Merkle path, leaf index)
```

`validator` and `norm` are constrained *inside* the leaf, so a proof for one
validator cannot admit another; the path and index are private, so one key
serves every index. The circuit also constrains `validator < 2^160`, a non-zero
address, `epoch < 2^64` and `norm < 1e18` (P-33). The norm bound is **strict**:
`norm == 1e18` (one entry at `1.0`, the rest zero) has no witness, so the
admitted domain is the paper's `[0, 1]` without its upper edge. That is a
completeness edge, not a soundness one — an over-`1.0` norm cannot be proved,
and `tests/admission_statement.rs` pins both sides of the edge (`WAD` and
`WAD + 1` must fail).

**P-16 — one slot, one meaning.** The Poseidon root no longer overwrites the
keccak commitment. `AVIPRegistry` stores them in separate per-epoch slots:
`commitmentOf(epoch)` remains M1's keccak fold used by `verifyEntry`, and
`statementRootOf(epoch)` is the Poseidon root the threshold proof consumes.
Both are written in one post:

```solidity
function postCommitment(uint256 epoch, bytes32 commitment, uint256 statementRoot,
                        uint32 changedEntries) external;
function verifyThreshold(uint256 epoch, uint256 validator, uint256 certifiedNorm,
                         bytes calldata proof) external view returns (bool);
```

`verifyThreshold` builds `[statementRootOf(epoch), epoch, validator,
certifiedNorm]` from its own storage, so the caller still supplies only the norm
and the proof.

**Where the leaf's norm comes from — and what the chain does not check (P-03).**
The number in the leaf is `Entry.norm_wad`, the data layer's per-validator
scalar, and it is the same field M1's keccak leaf hashes
(`abi.encodePacked(address, uint256)`, `commitment.rs`): the two trees of one
epoch commit to one `(validator, norm)` pair when both are built from the same
entries. M4d's fixture builds both from `fixture::tensor()`, and its
`TENSOR_DIGEST` is pinned to `c2309377…`, so the committed proof *is* over the
tensor the other fixtures digest. What `verifyThreshold` establishes is
membership, plus the validator and epoch bindings; it does **not** establish that
the statement root came from that tensor, because the registry never sees the
entries and cannot recompute either root. "Both roots came from one entry set" is
therefore the sequencer's assertion — made atomic by writing both in one
`postCommitment`, and auditable by anyone holding the epoch — not an on-chain
tie. `test/M4dRootSeparation.t.sol` writes that boundary down as a test instead
of leaving it implied. Closing it needs the commitment as a circuit input
(§5.5.7's recursive construction) *and* a decision on what `T` is per validator:
P-03 is the obstacle, not the cost. V3 already carried the 500-entry vector at
94,438 constraints and 3.9 s (§5.5.9) — expensive, but payable.

**What the proof buys, and what it does not.** Every statement word is public and
the witness is the leaf index plus nine siblings, both derivable by anyone holding
the epoch, so the only secret is the **position**: the proof hides which slot the
validator occupies, nothing else. It is not zero-knowledge about the norm — the
circuit says so itself (`admission.rs:215`) — and it is not cheaper than a plain
inclusion check: `AVIPRegistry.verifyEntry` already folds a keccak path for a few
thousand gas, against the 306,275 cold / 247,233 warm of `verifyThreshold` (a
Poseidon path on EVM would land in Groth16's order of magnitude, not below it).
M4d uses the proof anyway for uniformity — one verifier, one 256-byte blob, no
Merkle code in the registry — and because it keeps §5.5.7's recursive binding
reachable; not for cost and not for confidentiality. Until that binding exists the
whole claim is "the gate accepts a validator whose norm is in the published tree",
and the paper should not call it a certified Frobenius norm.

**The domain of `norm` is `[0, 1)`, and that is the floor (P-33).** The circuit
enforces it in one line — `admission.rs:213`,
`enforce_below_pow2(wad - norm - 1, ENTRY_BITS)` with `ENTRY_BITS = 60`. Read on
canonical representatives that is `norm ≤ WAD - 1`, the domain `[0, 1e18 - 1]`,
i.e. `r < 1`. (The difference from a `≤` form is a single value, `r = 1`; that is
not the point — the
domain excludes the whole half-line `r ≥ 1`.) `S_f(r) = (1 + 0.2r)/(1 + r)`
decreases, so the circuit's real floor is **0.6**, approached but not attained;
the paper's `S_min = 0.2` is only the `r → ∞` asymptote. With `Θ_r = 0.5` the
admitted band is `(0.6, 0.7333]`. The fixture's `0.665564…` gives
`S_f = 0.680317507197900649` (the number §5.11's M8 report prints); M4b's global
`12.793810…` gives `0.257997028195075875`, *below* that floor — the proof that the
two readings cannot share one `C_R`. P-33 fixes the floor and P-03 fixes what the
number means: a `‖T‖_F` of 12.79 cannot be certified as `< 1`, so it is the circuit
that decides `T` is one scalar per validator. The paper has to state the floor and
the meaning before v0.2.2 repeats `C_R` and `S_min`.

**The bound is one-sided; the closure is in the registry, not in the key.** The
check is a field subtraction whose result must be below `2^60`, so a `norm`
within `2^60` *below* the modulus — `[p - 152_921_504_606_846_977, p - 1]`, or
`[-2^60 + WAD, -1]` in signed terms — wraps the difference back into range and
satisfies it. `[0, WAD)` is the domain of *canonical* representatives only.
`AdmissionCircuit::norm_wad` is a `u64`, so this crate cannot build such a
witness; the circuit description and the key are public, so a prover writing its
own witness generator can, and no constraint or verifier rule stops it (a public
input *is* a field element). `AVIPRegistry.verifyThreshold` is where the value
would reach a state machine, and it now reverts `NormOutOfDomain` for
`certifiedNorm >= WAD` before decoding the blob — `certifiedNorm` is a `uint256`
that `Bn254.ecMul` reduces modulo the group order, so the guard has to be
explicit. Two other accident-shaped reasons make the band unreachable today — the
leaf has to be one the sequencer planted, and `admit` reverts because
`collateralFor` overflows `uint256` for a norm that large — and neither is a
check. The in-circuit lower bound, one more `enforce_below_pow2(norm,
ENTRY_BITS)`, is owed to the key regeneration that P-03 forces, because it
changes the `vk`, the fixture and every figure below.

**The same decision is written down twice in the code, and the two disagree.**
`commitment.rs:52` documents `Entry.norm_wad` as "`r = ‖T‖_F` in WAD — the same
quantity `collateralFor` takes", while `AVIPValidatorManager.sol:181` documents
`requiredStakeFor`'s argument as "the validator's committed norm `r = T(i)`". The
circuit's `< WAD` agrees with the second and rules the first out for M4b's real
fixture (`12.793810…`), so one of those comments is false today. Which one is
P-03; the answer has to land in both places and in `main.tex` at once.

**What M4d costs, measured.** The admission circuit is **4,827 constraints**
(§5.5.9's 94,438 is V3, the commitment circuit admission no longer runs), with
**≈0.45 s** setup and **≈0.33 s** prove in `--release` on this machine, dev key
(two runs: 452.9/331.4 ms and 457.8/336.9 ms — the shape is reproducible, the
clock is not). On chain, `Groth16Verifier.verify` with five `ic` points is
**234,284 gas**; `AVIPRegistry.verifyThreshold` is **306,275** on the cold path
(the convention the v0.2.1 note uses for V3's 286,144) and **247,233** warm
(`test/M4dRealKey.t.sol` logs and bounds all three). A v0.2.2 that describes M4d
has to use these figures: the paper's 94,438 constraints and 3.9 s, and the
note's 286,144 gas, describe V3. The note's **2.39×** and **1.82×** ratios also
move with them, and the full `manager.admit` path (376,588 gas for V3) is **not**
re-measured here, so neither ratio can be restated until that path is measured
again.

**Artefacts.** `src/zk/scripts/m4d_fixture.sh` emits
`integrations/avalanche/test/fixtures/M4dGroth16Fixtures.sol` with the admission
key, two inclusion proofs (for `STATEMENT_VALIDATOR` and
`STATEMENT_VALIDATOR_OTHER`), the four-word statement and the on-chain
`keccak256(abi.encode(vk))` digest. `test/M4dRealKey.t.sol` installs the key in
the frozen verifier, accepts the proof through `AVIPRegistry.verifyThreshold`,
and rejects a replay for another validator, the same roots at the next epoch,
any changed statement word, a tampered norm, and any word the framework cannot
encode as a norm (`2^64`, and `-1` in the scalar field — `NormOutOfDomain`). The
M4b proof is no longer
admitted by the manager; the M4b fixture stays only because §5.10's bridge tests
read its historical global statement.

| Quantity | M4d |
|---|---|
| Public inputs | **4** — `[statementRoot, epoch, validator, norm]` |
| `ic` | **5** points → 27 ABI words / 864 bytes on-chain |
| Tree | Poseidon, depth 9, 512 leaves (500 real), private path and index |
| Proof | **256 B on-chain** |
| Circuit | **4,827 constraints** (V3's 94,438 is the commitment circuit) |
| Proving (dev, `--release`) | **0.33 s** prove, **0.45 s** setup, one run |
| Gas | **234,284** `Groth16Verifier.verify`; **306,275** cold / **247,233** warm `verifyThreshold` |
| Key | *development* key; one contributor, seeds committed, no security claim (§11) |

Validated locally: `cargo test` → **47 passed, 0 failed, 1 ignored**;
`forge test --offline` → **275 passed, 0 failed, 0 skipped** over ten suites
(`AVIPRegistry.t.sol` is 52, `M4dRootSeparation.t.sol` is 6); `bash
src/zk/scripts/m4d_fixture.sh` → byte-identical across runs
(`md5 efe3ba62ee6daa1fc62f958704344579`); `forge fmt --check` → 0 diffs;
`scripts/m7d_report.sh` → **62 rows**, md5
`8a1dd78f824930144625441aed821797`; `scripts/m8_report.sh` → **42 rows**, md5
`55641a9f611c3ce64d35ffc7b8076a4f`. Both report guards pass: `m7d` still ties
M5's, M7b's and M7c's numbers to the wire — the relay leg keeps M7c's tensor-commitment
root and link, while the admission leg now runs on this fixture's root, and §5.11 spells
out why those are two different numbers — and `m8` reads this fixture's
`STATEMENT_NORM` out of the file (rather than copying it into M8's own fixture) and
requires the norm the report admitted to be that value, then still reproduces the
admission before the fee, slash and conservation sections.

Still open: the ceremony and an external audit (§11), and the paper-literal
recursive construction (§5.5.7). P-01's *off-chain* half — whether the certified
norm tracks events rather than the tensor — remains §7's problem, as the audit
triage records; and P-03's semantic choice is now **made in code** (one scalar per
validator) without the paper saying so, which the two paragraphs above record as
the decision a v0.2.2 must narrate or reverse.

### 5.6 M5 as delivered (off-chain RMT detector)

Status: **delivered.** `src/rmt/` is the crate `avip_rmt_detector` (edition 2024,
**no dependencies at all**), and its one documented command is
`src/rmt/scripts/m5_report.sh`. The acceptance is §5's row: *reproduces
`q99 = 9.0542` (right tail) and `−λ_min > 9.1371` (left tail) from
`verification/rmt/`, without editing it*.

The acceptance is met **exactly**, not statistically: the reproduced table agrees
with the sealed one in every quoted digit — the null moments and quantiles, the
five clique configurations, the six bipartite configurations (block densities
included) and the single-draw `W`/`A_sym`/`B` table. `verification/rmt/` is
untouched: no script, output or manifest line was edited.

**Why an exact reproduction is possible.** The sealed scripts are Monte Carlo, so
matching them means resuming the *same* stream, not drawing the same ensemble from
a different generator — the latter would only agree within its own sampling error
(`q99` has SE 0.0168, so `9.0542` and `9.0710` would both be "reproduced"). Every
sealed draw comes from `np.random.default_rng(42)`, i.e. PCG64 seeded through
`SeedSequence(42)`, so `src/rmt/src/pcg64.rs` implements that generator: the
XSL-RR output, the LCG step, numpy's `next_double`, and the LCG jump-ahead. The
fixture `fixtures/numpy_pcg64_seed42.txt` pins the reference stream (raw `u64`s,
double bit patterns, the first H0 draw's checksums), and the tests assert the Rust
stream against it **bit for bit**. `SeedSequence` itself is not reimplemented: its
128-bit PCG64 output for seed 42 is a constant carrying a regeneration command,
asserted against that pinned stream.

`graph.rs` then transcribes the three sealed generators call for call, including
the detail that decides whether the stream stays aligned: numpy draws a **full
`n × n`** block of uniforms per replicate and the scripts keep `i < j`, so a
generator that drew only the upper triangle would consume the wrong window. The
estimators follow the sealed conventions — numpy's default `quantile`
(`method="linear"`, `idx = q·(n−1)`), the population `std` (`ddof = 0`), the
Wilson interval of `bipartite_power.py`, and the SE derivation of
`q99_standard_error.py` recomputed from the **four-decimal** moments that script
reuses (hence `0.016802`; the same arithmetic on unrounded moments gives
`0.016803`, and the pinned table prints both, so the difference is the rounding
and nothing else).

| Quantity | Sealed value | Reproduced by |
|---|---|---|
| null `λ_max(B)` | mean `8.7679`, std `0.1115`, q99 `9.0542`, q95 `8.9663` | `null_distribution` |
| null `−λ_min(B)` | mean `8.8601`, std `0.1101`, q99 `9.1371`, q95 `9.0428` | `null_distribution` |
| right-tail power | means `9.7452`…`16.2281`, TPR@0.01 `0.9720`…`1.0000` | `clique_power` |
| left-tail power | means `9.6602`…`27.6546`, densities `0.0267`/`0.0534`… | `bipartite_power` |
| single draw | `W` `8.6896`/`10.6439`, `A_sym` `0.4254`/`0.4316`, `B` `8.6896`/`10.7011` | `clique_spectra_table` |
| degrees (H0) | `min=10`, `max=33`, `mean=19.88`, `std=4.22` | `Graph::degree_stats` |
| detection time | `0.060 s` per 500-node graph (release, min of 5; stderr) | `benches/m5.rs` |

**Parallel, and nevertheless bit-reproducible.** A phase runs in chunks
(`CHUNK = 50` replicates) and each chunk seeks its own window with
`Pcg64::advance`, which is the PCG jump-ahead; results are reassembled in
replicate order, so the phase's numbers do not depend on the worker count.
Parallelism changes the duration, never the pinned file — M4a's rule for
durations, applied to a Monte Carlo phase.

**The detector.** `detector.rs` exposes `B = W − ddᵀ/(2m)`, the two order
statistics, the sealed thresholds and a `Detection` struct with both decisions and
a `Verdict`. The spectrum comes from Householder tridiagonalization plus Sturm
bisection for the order statistic asked for (no eigenvectors, and no Lanczos: the
null's extremal eigenvalues sit inside a dense bulk, which is exactly where a
Krylov error bound is hard to trust). `jacobi_eigenvalues` is a second,
independent solver used only as a reference; the tests assert the two agree to
`1e-9` on random matrices *and* that the reduction preserves the trace and the
Frobenius norm — a transcription error in the Householder step cannot survive
both. Analytic spectra (cycle, complete graph) and the paper's structural identity
`λ_max(B) = λ₂(W)` on regular graphs are asserted too, as is the identity that
makes `s[-1]` the right statistic (`B·1 = 0`, F-018).

**The drift guard, in both directions.** `fixtures/sealed_reference.txt` holds the
sealed lines M5 reproduces, verbatim. `scripts/m5_report.sh` checks (a) that every
one of those lines is still present in `verification/rmt/results/` — so an edit
under the sealed tree fails the script instead of silently invalidating the
reproduction — and (b) that every four-decimal number in them appears in the
pinned output. `cargo test` repeats the same comparison against the thresholds and
the single-draw table, and `cargo test --release -- --ignored` runs the full
protocol against them.

**Two deviations, both stated.**
1. **The tensor → graph map does not exist in the paper.** `W` is the
   collaboration graph (`eq:collab`) while `T` is the reputation tensor
   (`eq:tensor`, one validator's 500 entries); §collusion never relates them. M5
   does not invent a map: `fixture.rs` binds the detector's synthetic input to the
   bytes M4 committed (`src/zk/fixtures/tensor_digest.txt`, read with
   `include_str!`, so a missing artefact is a build failure) and the pinned table
   prints that digest beside the detection it produced. The missing map is §10
   **D-7**, open.
2. **Scope.** M5 reproduces `calibration_modularity.py`, `bipartite_power.py` and
   `clique_spectra.py`. Deliberately not reproduced, with the reason: the
   `heavy_tail_*` scripts (Chung–Lu nulls, 15–24 min each; their conclusion —
   the threshold does not transfer, F-019/F-020/F-021 — is a property of the
   sealed output, not of a Rust reimplementation); `clique_spectra_seeds.py`
   (needs numpy's bounded-integer path for `default_rng(SEED).integers(...)`,
   which M5 does not reimplement, so the multi-seed gap distribution stays a
   sealed claim); `max_statistic.py` and `recalibrate_top.py` (same ensembles as
   the null phase, and the reproduced H0 already carries the `s[-1]` conclusion);
   `asym_weights.py` (ratios of expected weights, not a spectral claim). None of
   this touches the acceptance criterion, which names the two thresholds.

**Non-goals, as §5's row declares.** No on-chain slashing logic: `Detection` is a
struct a caller reads, and turning it into an AWM message or a `slash` call is
M7/M8. No calibration on real collaboration graphs (§10, open). No claim that a
dense `O(n³)` eigensolver is the deployment shape: it is what reproduces the
sealed calibration and what the benchmark times, and a sparse method is future
work rather than a hidden assumption.

Validated: `cargo test` → *36 passed, 0 failed, 1 ignored* (32 unit + 4 integration;
the ignored one is the full protocol, which `cargo test --release -- --ignored`
runs green);
`cargo clippy --all-targets -- -D warnings` and `cargo fmt --check` clean;
`cargo build --offline` with no registry (the crate has no dependencies);
`src/rmt/scripts/m5_report.sh` → the pinned file reproduced and the drift guard
green in both directions; `bash verification/audit-gate.sh` → *PASS=11, FAIL=0*.
The full protocol takes **≈145 s** on this machine (144.8 s and 140.0 s in two
runs; stderr, load-dependent) for 7,502 graphs, and one detection — what an epoch
monitor would run — takes **0.060 s** (`benches/m5.rs`, minimum of five).

### 5.7 M6 as delivered (reputation dynamics)

Status: **done** — §5.7.1 records the delivered artefacts, the four deviations and
the validation evidence. `src/reputation/` is the crate `avip_reputation` (edition
2024, **no dependencies**, `publish = false`), with 53 tests, zero clippy warnings
and a byte-stable report artefact; its one documented command is
`src/reputation/scripts/m6_report.sh`. §5's row is the acceptance: *the closed form
`C_R(r)` and the epoch commitment, plus positivity under multiplicative jumps*.
The rest of this section is the plan M6 was held to — kept, not rewritten, so the
outcome can be read against it.

**The pieces, and who owns each.** M6 sits inside a data flow three neighbours
already touch, so the boundaries are part of the deliverable and not an appendix to
it:

| piece | owner | trace |
|---|---|---|
| `C_R(r) = 0.8 r/(1+r)` at `r = ‖T‖_F`, and `S_f* = max{S_min, Θ − C_R(r)}` | **M6** (off-chain, `f64`) **and M2** (on-chain, WAD) | §2.5 and `\ref{sec:payment}`; M2 already ships the deployed reader, so M6's obligation is **parity with it**, not a second decision |
| the operator `C_R` satisfies: `L[C_R]`, `π = −L[C_R]` | **M6** | `\eqref{eq:fokker}`, `\eqref{eq:integro}`, `\eqref{eq:running-reward}`; the sealed evaluation is `verification/stochastics/cr_ide_solver.py` (C-24, closed `9d96b76`) |
| per-epoch reputation state → commitment payload and root | **M6** maps it; **M1** verifies it; **M7** transports it | `\ref{sec:datalayer}`; `AVIPRegistry.verifyInclusion` fixes the convention, so the map is not free |
| `T[c,d,h] = f_c(events)` (ingestion) and the fraud proof | **M7** — *not* M6; delivered by M7b (§5.9) as an interface plus the three-valued proof, with the function itself left to the protocol | `\eqref{eq:ingestion}`; guessing `f_c` here would be the same class of error as inventing `W` (D-7) |
| escrow of `financialStake`, slashing that retains or burns | **M8** — delivered (§5.12) | §5.2.3; the paper fixes neither the burn/retain decision nor a recipient, so M8 supplies the movement and records the destination as `D-M8-0` |
| the `T → W` map | **nobody**: §10 **D-7** stays open, option (b) | §5.6 also binds `W` as an input; a heuristic projection would be a claim-bearing invention, which is what (b) rejected |

**Acceptance criteria.** Each one is either a number the repository already sealed
or a property the paper states; no new constant enters.

1. **`C_R` and `S_f*`, three ways.** In WAD, with the *exact* Solidity expression
   (`(CR_INF · r) / (ONE + r)` on a 256-bit intermediate, floor division) and in the
   `f64` closed form. Reproduce (a) the constants the frozen contract's own tests
   pin — `collateralFor(THETA_R) = 266_666_666_666_666_666` and
   `requiredStakeFor(THETA_R) = 733_333_333_333_333_334`, with monotonicity,
   concavity and saturation `C_R(1e30) < CR_INF`; and (b)
   `verification/mechanism/results/financial_floor_sensitivity_output.txt`:
   `C_R^∞ = 0.800`, `C_R(1e9) = 0.800000`, `S_min = Θ − C_R^∞ = 0.200` and the sweep
   `C_R^∞ ∈ {0.5,…,1.0} → S_min ∈ {0.5,…,0.0}`.
2. **The integro-differential check, to the sealed six decimals.** The 14-point grid
   `r ∈ {1e-3, …, 50}` of
   `verification/stochastics/results/cr_ide_solver_output.txt`, in both regimes
   (`α, σ_0 = 0.5, 0.8` and `2.0, 0.5`), `λ = 0.8`, `ν = δ_{0.85}`: `C_R`, `C_R'`,
   `C_R''`, `L[C_R]` and `π`; plus the summary — `r_0 = 0.325039 / 0.611879`,
   `π(0.5) = +0.142752 / −0.170136`, `π(1.0) = +0.489946 / +0.450946`,
   `min π = −0.398195 / −1.594912`, monotone on `[r_0, ∞)`, `π(r)/r → 0.799992`.
   C-24 was closed by *that* script; M6's claim is narrower and is stated as such —
   the same operator, computed by an independent implementation, on the same grid.
3. **Positivity under jumps (F-001), in whichever mode the probe justifies.** Sealed
   parameters (`α = 0.5`, `R̄ = 1.0`, `σ_0 = 0.8`, `λ = 0.8`, mean jump `0.15`,
   `R_0 = 0.3`, `T = 5`, `dt = 0.001`, `100_000` paths, seed `42`): the additive
   scheme fails at **40.58%** and the multiplicative one at **0.000000%**
   (`min R = 0.000000`). `bin/m6-probe` first decides whether the crate can resume
   numpy's stream for the *whole* script — `normal`, `poisson` and `exponential`,
   not only `uniform` — and the pinned output states the mode it used:
   - **exact**: every sealed digit, by reproduction; or
   - **statistical**: the rate with its sampling error
     (`SE = √(p(1−p)/n) = 0.155` pp at 100k paths for 40.58%), and the multiplicative
     branch reported as **bounded by construction** — the sealed script clips
     `R + drift + diff` at zero *before* applying the jump, so `0.0000%` is a
     property of the specification, and the informative checks are `min R ≥ 0` plus
     Feller's condition `2αR̄ = 1.0 ≥ σ_0² = 0.64` (`\eqref{eq:wellcond}`).
   The mode is printed in `m6_output.txt` itself, so the file cannot be read as an
   exact reproduction when it is not one.
4. **The epoch commitment, in M1's convention.** `commitment.rs` maps a per-epoch
   reputation state (`(validator, r)` entries plus the epoch) to a payload and a
   Merkle root using **M1's exact hashing** — leaf
   `keccak256(abi.encodePacked(leaf))`, pair `keccak256(abi.encodePacked(min, max))`
   sorted — so the root M7 posts is verifiable by `AVIPRegistry.verifyInclusion`
   **unchanged**; it enforces the same freshness bound
   `γ·N = (500 · 1000)/10_000 = 50` entries per epoch (`\eqref{eq:freshness}`).
   Keccak-256 is checked against independent values in
   `fixtures/keccak256_vectors.txt`, generated with `cast keccak` — the same Keccak
   the contracts call.
5. **The gate.** `cargo test` green; `cargo clippy --all-targets -- -D warnings` and
   `cargo fmt --check` clean; `cargo build --offline` with no registry;
   `src/reputation/scripts/m6_report.sh` reproduces `scripts/m6_output.txt` behind
   the two-direction drift guard of §5.6; `bash verification/audit-gate.sh` →
   `PASS=11, FAIL=0`, with `verification/` untouched.

**Deliberately not reproduced**, with the reason (the §5.6 discipline):
`verification/stochastics/dt_convergence.py` (it measures the Euler bias of the
*MFPT*, `\eqref{eq:mfpt}`/`\eqref{eq:gamma}`, not the positivity claim),
`mfpt_jump_diffusion.py` and `mfpt_bound_explicit.py` (the same MFPT subject),
`stationary_stats.py` and `censoring_test.py` (`\eqref{eq:moments}`), and
`verification/mechanism/{fee_specification,fee_specification_net,frobenius_counterexample}.py`
(fee and tensor-norm subjects whose own findings are closed). None of them is part
of the acceptance, and each would re-derive a claim the sealed output already
carries.

**One label fix, not a change of decision.** §2.2's A6 row said "**on-chain**
reputation dynamics". The on-chain half exists — M2's `collateralFor` /
`requiredStakeFor`, in WAD, tested against the sealed floor — so what is missing is
the off-chain crate, and the row now says so.

#### 5.7.1 M6 as delivered

Delivered: `src/reputation/` (crate `avip_reputation`, edition 2024, **no
dependencies**, `publish = false`), with modules `pcg64` (the sealed stream —
`np.random.default_rng(42)`, i.e. PCG64 — resumed bit for bit, `advance` included),
`numpy` (`uniform` bit-identical, `poisson` exact at both sealed rates, `normal`
and `exponential` **SUBSTITUTED** — deviation 1), `wad` (M2's reader in WAD-18 with
a 256-bit intermediate: `collateralFor(Θ_R) = 266_666_666_666_666_666`,
`requiredStakeFor(Θ_R) = 733_333_333_333_333_334`, monotone and saturating, with
the domain `MAX_NORM` stated as a constant), `keccak` (digest parity with `cast
keccak`, including the rate boundary), `commitment` (M1's convention exactly: leaf
`keccak256(payload)` with `payload = abi.encodePacked(address, uint256)`, pairs
`keccak256(min‖max)` sorted, `merkle_root`, `Epoch::{root, digest, inclusion_proof,
changed_entries, freshness_ok}`, freshness `γ·N = 50` and the genesis case), `cir`
(the positivity run) and `cr` (the IDE solver).

Bin `m6-report` (`--smoke` shrinks the positivity run: a development mode, never
pinned) writes `scripts/m6_output.txt` — **12,078 B**, reproduced byte-identically
by `scripts/m6_report.sh` (md5 `18e0a845ef87775e903a90f85737dbce`). Bin `m6-probe`
is what decides the mode printed in that file's header, so the artefact cannot be
read as an exact reproduction when it is not one.

**The drift guard, in both directions** (§5.6's rule, applied here).
`fixtures/sealed_reference.txt` copies the sealed lines verbatim, one block per
file: `verification/stochastics/results/{cr_ide_solver_output,sim_positivity_output}.txt`
and `verification/mechanism/results/financial_floor_sensitivity_output.txt`.
`scripts/m6_report.sh` checks (a) that every one of those lines is still present,
byte for byte, in the file its `# ---` header names under `verification/` — so an
edit under the sealed tree fails the script instead of silently invalidating the
copy — and (b) that every four-decimal number in them appears in
`scripts/m6_output.txt`. The pinned file is replaced only after both directions
pass, so a drifting run leaves it untouched (fail-closed).

**The reproduced numbers.** Section 3 of `scripts/m6_output.txt` prints the additive
rate as **40.2510%** against the sealed **40.5800%** (`|Δ| = 0.3290 pp`, inside
`3·SE = 0.4658 pp` at `n = 100,000`) and the multiplicative one as **0.000000%**
with `min R = 0.000000`; section 2 holds the IDE solver's 14-point grid and its
summary for both regimes (`r_0 = 0.325039 / 0.611879`, `π(1.0) = +0.489946 /
+0.450946`, `min π = −0.398195 / −1.594912`, monotone on `[r_0, ∞)`,
`π(r)/r → 0.799992`).

**Four deviations, all deliberate.**
1. **`normal` and `exponential` are SUBSTITUTED, not reproduced.** NumPy 2.2.6
   draws both from a 257-entry ziggurat table, not from the next uniform by inverse
   CDF or Box–Muller, and that table is neither in this repository nor reachable
   offline. `numpy.rs` declares the substitution, `bin/m6-probe` is what *decides*
   it, and `scripts/m6_output.txt` prints the resulting mode (`statistical`) beside
   the numbers, so the file cannot be read as an exact reproduction; the test
   asserts the substitution rather than hiding it.
2. **F-001's multiplicative branch reproduces the `np.clip` that precedes the
   jump.** The `0.000000%` is by construction (`main.tex` L167), not an empirical
   finding: the port clips `R + drift + diff` at zero *before* applying the factor,
   exactly as the sealed script does, and the test asserts the resulting `min R ≥ 0`
   instead of re-measuring a tautology.
3. **D-7 stays open (option b).** No `mapping.rs` and no heuristic `T → W`
   derivation exists anywhere in the crate: the epoch's entries are M6's *input*,
   and the commitment is a map from a frozen tensor to a root, not a claim about
   how validators collaborated.
4. **The epoch commitment is a pure function, not a state machine.** The ingestion
   formula `f_c` and the epoch lifecycle belong to the data layer (M7, §10); M6
   provides `commitment::merkle_root` and `Epoch::{root, digest, freshness_ok}` as
   stateless computations over a frozen tensor, and enforces `γ·N = 50` through
   `changed_entries` / `freshness_ok` on epochs it does not own.

**Validated locally.** `cargo test --offline` → **53 passed, 0 failed**;
`cargo clippy --offline --all-targets -- -D warnings` → clean; `cargo fmt --check`
→ 0 diffs; `cargo build --offline` → OK (no registry, no dependencies);
`scripts/m6_report.sh` → PASS in **25.7 s** (paths = 100,000, steps = 5,000; stderr,
load-dependent) with the pinned file byte-identical across runs;
`bash verification/audit-gate.sh` → **PASS=11, FAIL=0, SKIP=0**;
`git status --porcelain verification/` → 0 lines, so the sealed tree is untouched.

### 5.8 M7a as delivered (offline deployment scripts)

Status: **done for the script half of A8; Fuji phase 1 is deployed.**
`integrations/avalanche/scripts/` holds `DeployCommon.sol`,
`DeployRegistry.s.sol` and `DeployValidatorManager.s.sol`, plus the dry-run
harness `deploy_dryrun.sh` with its pinned transcript
`deploy_dryrun_output.txt`, and `integrations/avalanche/test/DeployScripts.t.sol`
is the 16-test suite. The M7a dry run never touched an RPC endpoint, and the
addresses in its transcript are the ones a fresh EVM hands out — they are not
Fuji addresses. The later manual phase-1 run is `DeployFujiPhase1.s.sol` and its
artifacts are `fuji_20261018/phase1.json` and `fuji_phase1.txt` (chain 43113,
`2026-10-19T01:46:52Z` UTC, `verifier = address(0)`). §5's M7 row is the
acceptance; what follows is what M7a delivered against it.

**The split, and why it is the deliverable.** `DeployCommon` fixes the two rules
no individual script can forget: the chain guard (`MainnetRefused(chainId)` on
C-Chain mainnet `43114`; Fuji `43113` and local `31337` pass) and the role
plumbing (`DEPLOYER`, `SEQUENCER`, `VERIFIER`, `REGISTRY`, `SLASH_AUTHORITY` read
from the environment, never from the deployer). Each script is then
`run() = _refuseMainnet(); deploy(plan())`, where `deploy(Plan)` — the only
function that creates state — carries the guard, the plan validation, the
broadcast, the read-back assertions and the transcript. That is what makes the
scripts testable with no environment at all: `DeployScripts.t.sol` drives
`deploy(Plan)` directly, and the environment → `Plan` mapping is asserted out of
process by `deploy_dryrun.sh`, one fresh CLI process per case.

The reason is measured, not stylistic: **`vm.setEnv` is process-wide, its writes
outlive the test that made them, and the precedence of a later write over an
earlier one is not something a test can rely on** (observed twice while building
this milestone). A suite where one test pins `SEQUENCER` and another pins a
different value cannot be read as "each test saw its own environment", so this one
does not pretend to: the only `setEnv` calls left write names that exactly one
test owns.

**Acceptance criteria.** Each traces to a frozen artefact or to a property the
paper states; no new constant enters.

1. **The scripts deploy the frozen contracts, unmodified.**
   `DeployRegistry` constructs `AVIPRegistry(sequencer, verifier)` and
   `DeployValidatorManager` constructs
   `AVIPValidatorManager(registry, slashAuthority)`. No file under
   `integrations/avalanche/contracts/` was edited by M7a.
2. **Nothing can be deployed by accident.** `run()` refuses C-Chain mainnet
   *before it reads a single role*; a plan with a zero `sequencer`/`registry`
   reverts `MissingRole`; and no script broadcasts — the network step is a human
   decision that M7 owns, not a default.
3. **A malformed role is a hard error.** `_roleOr` parses with `vm.parseAddress`
   and not with `envOr`, so `SEQUENCER=0xnot-an-address` reverts instead of
   quietly wiring the default — the failure mode that would deploy a protocol
   whose sequencer is a public `anvil` account.
4. **The scripts assert their own wiring** by reading it back from the instances
   they just created: `sequencer`, `verifier`, `TENSOR_SIZE = 500`,
   `MAX_DELTA_ENTRIES = 50`, and the manager's `Theta = 1.0`, `C_R^inf = 0.8`,
   `S_min = 0.2`, `Theta_r = 0.5`, `F_0* = 0.05`, plus
   `collateralFor(Theta_r) = 266_666_666_666_666_666` and
   `requiredStakeFor(Theta_r) = 733_333_333_333_333_334` — the pair M2's own
   suite pins.
5. **The environment → plan mapping is asserted where it can be observed.** The
   dry run's six cases (defaults; `MissingRole("REGISTRY")`; environment wins; the
   chained registry; a malformed value; the mainnet refusal) each run in their own
   process, and the harness checks every line it must produce, including that a
   malformed `SEQUENCER` leaves no `role.sequencer` line behind. Two runs of
   `deploy_dryrun.sh` produce a byte-identical transcript.

**Deliberately not done**, each with its reason rather than as an omission:

- **No threshold verifier is deployed.** The only keys in the repository are M4b's
  and M4d's *development* keys over ceremony-less circuits, so installing one on
  a shared testnet would present a development key as a deployment. `VERIFIER`
  defaults to `address(0)`, which `AVIPRegistry` accepts and then refuses to
  certify with (`VerifierNotSet`).
- **No network in the M7a transcript.** The dry run uses a fresh EVM and therefore
  reports **no gas or latency number**; it excludes both on purpose so it stays
  stable across machines. The phase-1 Fuji run is separate: its gas is in
  `fuji_20261018/phase1.json` and its block time in the P10b measurement.
- **No Subnet L1 registration.** `RegisterSubnetL1.s.sol` (phase 4, ACP-77) is
  listed as *intended* in `scripts/README.md`; the P-Chain work is M7's.

**Validated locally.** `forge test --offline` → **123 passed, 0 failed, 0
skipped** (6 suites, of which `test/DeployScripts.t.sol` is 16); `forge fmt
--check` → 0 diffs; `forge build --offline` → OK; `forge lint` → 4 notes, no
warning (all four are the `setEnv` calls the suite must make to observe role
resolution); `bash scripts/deploy_dryrun.sh` → **6 cases ok**, exit 0, with
`deploy_dryrun_output.txt` byte-identical across runs;
`bash verification/audit-gate.sh` → **PASS=11, FAIL=0, SKIP=0**;
`git status --porcelain verification/` → 0 lines, so the sealed tree is untouched.

### 5.9 M7b as delivered (the audit equilibrium and the ingestion formula)

Status: **done for the data-layer half of A7**. `src/datalayer/` holds the crate:
`pcg64.rs` (M5's generator) and `commitment.rs` (M6's epoch → root) carried over
**unchanged, tests included**; `binomial.rs`, `fixture.rs`, `ingestion.rs`,
`report.rs`; the binaries `bin/m7b-report` and `bin/m7b-probe`; and
`scripts/m7b_report.sh` with the pinned `scripts/m7b_output.txt`. **As written,
A7 stayed open**: M7c was the Pedersen ↔ Merkle bridge — until it existed the norm
proof and the published root were not tied together in code — and nothing is
deployed (A8, §5.8). That half is **closed by M7c (§5.10)**, which reuses this
crate's fold instead of reimplementing it; the transport stays open (A9).

**The table is recomputed, not copied.** `verification/data-layer/simulate_data_layer_v3.py`
is sealed and was not edited; `scripts/m7b_output.txt` carries its 29 non-empty
lines byte for byte, and all 11 numeric rows of the grid are produced here, from
numpy's own `default_rng(42)` restarted per row, 500 epochs each: `n*(0.25) = 0`,
`n*(B*) = 1`, `n*(1.5) = 1`, `n*(25) = 20`. The floor is a floor, not a rounding
(`n*(1.5) = 1` is that sentence as a number), and the cap shows up twice:
`n*(20) = n*(25) = 20`, and the verifier's profit rising again at `B = 25` while
the cost stays pinned.

**The finding: two fraud means, one model.** Rows below `B*` print `Fraude/ép`
49.914, rows at or above it print 50.2, which reads like two models. It is one
PCG64 stream read at two offsets: with `coverage = 0.0` the detection draw
`binomial(n_frauds, 0.0)` returns 0 *before consuming a double*, so the fraud draw
is the first draw of every epoch; with `coverage = 1.0` the same call consumes one
double (`p = 1` lands in inversion), so it is every second. `binomial.rs` is the
transcription of `Generator.binomial` that makes that statement checkable — 3306
draws over 10 groups covering BTPE, inversion and both mirrored `p > 0.5` branches,
against `fixtures/numpy_binomial_seed42.txt` — and the consumption is *measured*
against `advance(k)` rather than assumed: 0 doubles for `binomial(n, 0.0)`, 1 for
`binomial(n, 1.0)`, 2 for `binomial(100, 0.5)`, 4 for two cached draws.
`bin/m7b-probe` exits non-zero on any divergence, because a mismatch here would
make the pinned table wrong rather than merely different.

**`eq:ingestion` is an interface; no formula is invented.** The paper fixes `f_c`'s
properties — public, not changeable by the validator, fixed before deployment,
identical for every validator on chain `c`, values in `[0, 1]` — and M7 does not
invent the function, the same line §5.7 draws for the `T → W` map. What the crate
carries is `Ingestion { chain, parameters_digest, score }` with `Score` a WAD
integer in `[0, 1e18]` *by construction* (never a float), `GenesisFormula` as the
one declared instance (chain 43113, weights `(att, gov, liq) = 3/5/2`, scale 1000),
and a genesis digest `0x2fcd03b859e0519cc0c443aa99b879e0f15bb0312047cec8d7541de55acbba0a`
that pins it: `score(no events) = 0`, `score((40, 7, 3)) = 138673557278208440 WAD =
0.138674`. The instance is declared, **not** the paper's `f_c`.

**The fraud proof decides three ways and slashes on one.** `Verdict::Consistent`
when the published value is `f_c(events)` at the epoch's own leaf;
`Verdict::Fraud { published_wad, formula_wad }` when it is not (the table prints
the re-hashed `+1` root `0x80328681…` and both values); `Verdict::Unproven` when
the claim cannot be checked — and an honest witness against a lying root is
`Unproven`, never a slash. What the paper describes as two contradictory inclusion
proofs against one root is *unsatisfiable* against the tensor's own Merkle root,
because a leaf has one value, and that unsatisfiability **is** the binding property:
a second opening of one position to a different value does not verify. The
misconduct that can exist is the value above, which is why `f_c` has to be public,
deterministic and frozen before deployment for the adjudicator to tell the two
apart.

**Acceptance criteria**, each traced to a sealed artefact or to a statement the
paper makes; no new constant enters.

1. **The sealed table is reproduced, and checked in both directions.** All 29
   non-empty lines of the sealed output occur byte for byte in
   `scripts/m7b_output.txt` — asserted inside the crate by `report::tests`, and out
   of process by `scripts/m7b_report.sh`, which checks every line against the file
   its `# ---` header names under `verification/` (so an edit there fails the script
   instead of silently invalidating the copy) *and* that every four-decimal number
   of the sealed file survives somewhere in the reproduction. The pinned file is
   replaced only after both directions pass, so a drifting run leaves the committed
   file untouched (fail-closed). Both halves were exercised negatively: with one
   sealed value perturbed, the crate's own check and the script both fail.
2. **The transcription is verified, not asserted.** The 3306 draws above, plus the
   degenerate cases, which consume exactly what numpy consumes rather than what one
   would guess; a divergence is a non-zero exit, not a tolerance.
3. **`n*(B)` is the paper's map.** `⌊B/B*⌋` with `B* = c_audit / p_fraud = 0.1/0.10
   = 1.0000`, floored at 0 and capped at `N_VERIFIERS = 20`; the grid, not a
   comment, is the evidence, and the three parameter values are asserted against the
   sealed script's own constants. The cancellation that yields `B* = c_audit / p_fraud`
   requires the **per-auditor** cost `N_ATT * c_audit` of
   `simulate_data_layer_v3.py:58`; the paper's printed `eq:revenue` omits that factor, which
   is one of the two `main.tex` amendments §5.12 queued for the P6 batch and applied in P6a ((094c41b)).
4. **`eq:ingestion` is an interface with one declared instance and a genesis
   digest**, and `adjudicate` returns the three verdicts of the paper's proof, with
   `Fraud` the only one that carries a slash.
5. **The report states its own mode and its own gaps.** Section 4 lists what is
   sealed, what is carried over from M5/M6 and what is deliberately not done, so the
   file cannot be read as evidence about a deployed registry.

**Deliberately not done**, each with its reason rather than as an omission: no `f_c`
formula is asserted (which `f_c` is in force is fixed at genesis); the `T → W`
collaboration map stays **D-7** open (§10), so nothing here derives a graph from the
tensor; no transport (no Teleporter message, no source-chain quorum); no
Pedersen ↔ Merkle bridge (**M7c**); no funds (escrow and burn are **M8**); no
security, liveness or economic claim about a deployed registry.

**Validated locally.** `cargo test --offline` → **39 passed, 0 failed**;
`cargo clippy --offline --all-targets -- -D warnings` → clean; `cargo fmt --check`
→ 0 diffs; `cargo build --offline` → OK (no registry, no dependencies);
`scripts/m7b_report.sh` → PASS, with `scripts/m7b_output.txt` byte-identical across
runs (`md5 20c8a209ccf4501c93955f58fd162462`); `bin/m7b-probe` → **10/10 groups**,
exit 0; `bash verification/audit-gate.sh` → **PASS=11, FAIL=0, SKIP=0**;
`git status --porcelain verification/` → 0 lines, so the sealed tree is untouched.

**The data-layer paper findings, all five applied in P6a** (commit `094c41b`,
re-anchor `2026-10-11T21:48:40Z`; the findings are kept below exactly as recorded,
because they are the evidence each amendment answers). §5.12 queues the
`main.tex` repairs that M8's contracts force. The three below are the sibling findings
from the same section, each raised against `main.tex` and each answered by an artefact
that already exists in this repository — recorded here, not repaired, for the reason
§5.12 states (`main.tex` is sealed; §3, §9, §10). None of them is a code change: M7b
and the sealed script are the side that is right.

**1. §7.3's fraud proof is described in a shape the tensor cannot have.**
`main.tex:976` says *"Any party can submit a fraud proof consisting of two state
inclusion proofs against the same source-chain root that yield contradictory values
for a single entry `T[c,d,h]`"*. Against the tensor's own Merkle root that pair is
**unsatisfiable by construction** — a leaf has one value, so a second opening of one
position to a different value simply does not verify — and M7b states that as the
binding property rather than pretending to catch a contradiction that cannot exist
(`src/datalayer/src/ingestion.rs:235-243`). What the delivered adjudicator does is the
check that *can* fail: re-execute the public, genesis-frozen `f_c` and compare it to
the published leaf, `Verdict::Consistent` / `Fraud { published_wad, formula_wad }` /
`Unproven`, with `Fraud` the only verdict that carries a slash
(`ingestion.rs:216-233`; §5.9's acceptance criterion 4). The same paragraph attaches
two things the delivered stack does not do: the **bounty** "the honest reporter
receives" is not implemented anywhere (`src/datalayer/src/lib.rs:18-19`, "nothing here
moves funds"), and the **slash** is the `S_slash = 10` that §5.12 just showed is not
executed on-chain. **Amendment:** rewrite the sentence to the adjudication that exists
(the reporter publishes the events and the adjudicator re-derives `f_c`, exactly as
`adjudicate` does), and restate the bounty and the slash as *model* parameters at the
status the rest of §7 already uses for a modelled, non-executable quantity — or defer
them explicitly to §10. This builds on C-48, which already corrected `fraud-proof` →
`fraud proof` in this same subsection (`content-audit-pending.md:1638`).

**2. The equilibrium is assumed and printed, the coverage is a step and not a
probability, and the free-rider case is missing from §10.2.** §7.3 derives
`n*(B) = ⌊B/B*⌋` as though it were the market outcome of individual entry decisions,
and §7.4 books it `Verified`. The sealed script computes it *first* and feeds it into
the epoch loop — `n_auditors = equilibrium_auditors(B)` at
`simulate_data_layer_v3.py:38`, before the 500 epochs that follow — so the Monte Carlo
never tests whether `n*` verifiers in fact enter; it re-evaluates a closed form. The
script's own header is explicit: *"Asume: cada auditor revisa TODAS las attestations y
compite por el bounty. Cobertura de detección = 100% si `n >= 1`"* (`:8-9`), and the
code is `coverage = 1.0 if n_auditors >= 1 else 0.0` (`:39`). Two conventions follow
that the paper never states:

- **The bounty is a common pool.** `total_revenue = n_detections * B` is divided by
  `n_auditors` (`:57-59`), so the reward per auditor *falls* with participation. The
  archived first version flagged this as *"múltiples verificadores compiten por el
  mismo bounty, y el beneficio individual se diluye. Este es el problema de la carrera
  (race), análogo al de los MEV bots"*
  (`verification/data-layer/results/archive/simulate_data_layer_output.txt:67-69`), and
  the note did not survive into the paper. Unstated, the grid's `+0.20` reads as a
  measured residual instead of what it is: the arithmetic of a split-the-pot
  convention, `(D_obs − D_theory) · B / n*` (`main.tex:1025`).
- **Detection is 0 or 1.** With `N_VERIFIERS = 20` there is no detection probability
  and no partial detection: one auditor sees every fraud. §7.4's prose hedges
  ("reaches 100\% *in this model*", `main.tex:1023`) but §7.7's table does not.

§10.2 already carries the neighbouring limitation — *"assumes auditors respond to
profit… Below that threshold, the mechanism provides no detection regardless of the
value of the reputation at stake"* (`main.tex:1321`), status `Design` in the
Limitations table (`:1313`) — but it covers only `B < B*`, not the free-rider and
dilution case, which is the one the archived note named. **Amendment:** state both
conventions in §7.3 (the pool divided by the auditors; coverage as a step), and extend
the §10.2 bounty limitation with one sentence on free-riding and dilution, at the same
`Design` status the row already carries.

**3. §7.7's `Verified` label covers what the script assumes.** The paper's own
vocabulary is explicit that the column records the *nature* of a claim, not a
pass/fail (`README.md:203-211`), and §7.7 spends it on three rows
(`main.tex:1053-1057`): `B* = c_audit / p_fraud` is `Analytical` — correctly, it is
derived; `n^*(B) = ⌊B/B*⌋` is `Verified` although the script *assumes* it (finding 2
above); and `Integrity = 1.0 when n^* ≥ 1` is `Verified` although it is forced by the
coverage convention — with `integrity = (N_ATTESTATIONS - frauds + detections) /
N_ATTESTATIONS` (`:70`) and `coverage ∈ {0,1}` (`:39`), `detections == frauds` is
deterministic, so the row is a tautology of the model. The fourth row is §5.12's; the
fifth, `Freshness bounds propagation linearly`, is correctly `Analytical` with no
script — but at the paper's own example the bound defeats itself: `γ = 0.10, k = 10`
in `main.tex:1040` gives `fraud fraction ≤ 1.0`, the whole tensor, so the printed
instance is vacuous rather than reassuring. **Amendment:** reclassify the two rows to
the paper's own `Analytical` / `Design`, keep `Verified` for quantities the script
*measures*, and print a `γ · k < 1` instance for the freshness bound. Precedent: C-41
repaired a summary-table label in §2.6 for exactly this kind of drift
(`content-audit-pending.md:1480`); `bloque-b-report.md:40-41` shows the row-level
rewrite. The reclassification must keep guard G8 green — no `Estimate`/`Verified` mix
on one line (`verification/audit-gate.sh`).

**Applied in P6a** (commit `094c41b`, re-anchor `2026-10-11T21:48:40Z`, root
`217d6d51…`): the five edits below, plus the `:941` correction from finding 2
(`We verify` → `We evaluate`, because the script feeds `n*(B)` into the epoch loop
rather than testing it). Twelve lines replaced 1:1 — 1410 before and after — so the
line-number references the three sealed `docs/audit/` files carry stay valid by
construction. None required a contract change and none introduced a new constant:
every number they cite was already in the sealed script or in a delivered crate. The
batch took **its own** re-anchor instead of §10's original single P6 batch, because §9's "one
batch" rationale names the C-phase and the receipts are additive: the superseded D1
receipt stays in history, and `git show aaaf460:verification/anchor_root.sha256.ots`
is where it lives. C1–C4 were delivered in P6b (§12), which took its own re-anchor
(`2026-10-12T00:54:19Z`, root `79ac6783…`, receipt R-3).

### 5.10 M7c as delivered (the Pedersen ↔ Merkle bridge, option (c))

Status: **A7's bridge half is closed.** A7 has three pieces — the ingestion
formula, the fraud proof and the transport; §5.9 delivered the first two and left
the statement's root and the registry's root tied together by nothing but prose.
The transport (3 AWM message types) is A9's and stays open.

**The gap, stated exactly.** The statement carries `root`; `AVIPRegistry` verifies
inclusion against `keccak256` leaves in M1's convention. Both are commitments to
the *same* 500-entry tensor, and before M7c a verifier that accepted the proof had
no way to check that the root it certified and the root the registry stores
describe that tensor: two independent numbers. §5.4 item 4 named four options and
§5.5.7 selected **(c)** — an off-chain commitment plus a *recomputable link* —
because (a) would re-prove the registry's tree inside the circuit and (b)/(d) would
change the deployed interface, which M3 froze.

**What M7c delivers.** `src/zk/src/bridge.rs` (`TENSOR_SIZE`, `position_key`,
`tensor_state`, `root_bytes`, `uint256_decimal`, `link_digest`, `statement_root`,
`Bridge`/`Claim`, `Mismatch`/`Verdict`, `Bridge::claim`, `open`, `verify`); the
driver `src/zk/src/m7c.rs` (`bin/m7c-report`); the integration test
`src/zk/tests/m7c_bridge.rs`; and `src/zk/scripts/m7c_report.sh` with the pinned
`src/zk/scripts/m7c_output.txt`, whose 11 internal checks all `hold`. The crate
gained exactly one path dependency, `avip_datalayer = { path = "../datalayer" }`
(no registry entry, so `--offline` is unaffected) and one `[[bin]]`. Nothing under
`integrations/avalanche/` or `verification/` was edited, and the only touch outside
`src/zk` is documentation: a scope note in `src/datalayer/src/lib.rs` recording that
the bridge belongs to M7c and not to M7b, and the data-layer row of the repo README
— no behaviour, no constant and no pinned table of M7b moves (its `m7b_report.sh`
re-runs to the same md5). The tie is off-chain, and the bridge had to live with the
prover because it needs the prover's own commitments.

**The link.** `keccak256(abi.encodePacked(bytes32 merkleRoot, uint256
statementRoot, uint256 epoch))`: three fixed-width words, so the encoding is
unambiguous — the property `abi.encodePacked` does not have in general and does
have for these types. Over the committed §5.5.6 fixture: `merkleRoot =
0x187d08e633fb4f3895633e6d3be1075f9603923adb6d70c09f27b458c3917537`,
`statementRoot =
14881564148789680950073164612164838307833922018127128489011700125541095929892`
(`0x20e6aab4b9b3e21de8ba1d7f765f20508bce20314533dc5cca56f93ae81f7824`),
`epoch = 0`, `link = 0xc4d35b0ac87daa8fe8647a6d2372e6dabe3e1c505e444455c20f9c8ff9073ba7`.

**Neither root is restated, and that is the design.** The tree is built by folding
`avip_datalayer::commitment`'s own `Epoch` through its `merkle_root`, so
`verifyEntry`'s convention cannot drift from the registry's; the statement root
comes from `native::poseidon_commitment`, the same function that fills
`groth16::circuit_for`'s public input, and `bridge::tests` recounts it against
V3's `variant_root`; the leaf key `i` is the position of `T[i]` in the 20-byte
`validator` slot. The unit tests then check the fold against a *second*
implementation written from the contract's rule (ordered pair, odd node promoted)
rather than against the crate it borrows, and `root_bytes`/`uint256_decimal` are
what make the statement root comparable to `STATEMENT_ROOT` as Solidity prints it.

**Scope note added after M4d (§5.5.11).** The `root` this link ties to the fold is
V3's **tensor commitment** — the M4b statement. M4d replaced the *admission*
statement with a per-epoch Poseidon Merkle root over `(validator, norm)` leaves, so
the link no longer names the root a live admission proof consumes: the registry
stores that root in `statementRootOf(epoch)` and the fold in `commitmentOf(epoch)`,
both written by one `postCommitment`. Nothing in this section changes — the tie is
still recomputable and it is still what M7c's table pins, and M7c's guard still
checks it in both directions against `M4bGroth16Fixtures` — but a reader should not
conflate it with the admission root. M7d's report keeps the two legs in separate
registry instances and §5.11 says why the numbers differ.

**What it does not do**, printed as §4 of the table so it cannot be missed: keccak
is **not** proved inside the circuit (the proof certifies the norm; the tie is
off-chain and recomputable by any peer — that is what option (c) means); a verifier
holding only the two roots learns nothing, because the link needs the tensor, and
side-by-side roots would be an `ic.length` change §5.5.7 does not decide; for V2′
the statement's `uint256` is the commitment's **x-coordinate**, so a full point
needs a second word — the §5.5.10 residual is a measured row, not a footnote; and
the `T → W` identity is not claimed (§10 **D-7** stays open).

**Acceptance criteria**, each traced to an artefact or to a computation; no new
constant enters.

1. **Both roots are recomputed from the two existing implementations, not from a
   third one.** The tree folds `avip_datalayer::commitment::Epoch` through that
   crate's `merkle_root`, and the statement root is `native::poseidon_commitment`
   — the function `groth16::circuit_for` itself calls. `the_fold_is_the_contracts_fold`
   then checks the result against a second implementation written from the
   contract's rule (ordered pair, odd node promoted, 500 → 250 → 125 → … so the
   promoted-node branch is on the path), and
   `the_leaf_is_abi_encode_packed_of_key_and_value` checks every leaf against
   `sha3::Keccak256` over the 52-byte `abi.encodePacked` payload directly.
2. **The tie is checked against the emitted artifact, in both directions.**
   `scripts/m7c_report.sh` requires the fresh table to carry `STATEMENT_ROOT`,
   `STATEMENT_EPOCH`, `STATEMENT_NORM` and `TENSOR_DIGEST` as read out of
   `integrations/avalanche/test/fixtures/M4bGroth16Fixtures.sol`, and requires the
   *pinned* link to be the link the current revision computes; the pinned file is
   replaced only after both pass, so a drifting run leaves it untouched
   (fail-closed), and the guard was exercised negatively during development — it
   caught the digest row printing without its `0x`. `cargo test` closes the same
   seam from the other side: `tests/m7c_bridge.rs` recomputes **every** number in
   the committed table, so library and artefact cannot drift apart silently.
3. **The four rejections are measured, not asserted.** Section 3 of the table
   recomputes each one from the tensor: a moved entry (`T[0] ^ 1`), a positional
   swap (which moves both roots, so the binding is positional and not a set), an
   epoch that is not the tree's (the same roots, `epoch 1`), and a link built over
   another tensor — the last three all `Unbound`, each with the check that failed.
4. **The report states its own mode and its own gaps.** Section 4 is what option
   (c) does *not* buy: no in-circuit keccak, nothing a verifier can do with the two
   roots alone, V2′'s x-coordinate residual as a measured row rather than a
   footnote, and `T → W` unclaimed, so the file cannot be read as evidence about a
   deployed registry.
5. **The link is a tie, not a proof, and that is what §5.5.7 asked for.** Three
   fixed-width words make the packing unambiguous; the epoch is inside the digest,
   so it cannot be moved beside it; both roots are recomputable by any peer from
   the tensor, which is the property a proof would not add here — the proof already
   certifies the norm.

**Deliberately not done**, each with its reason rather than as an omission: keccak
is not proved in-circuit (that is what (c) chose over (a)); no AWM transport exists
(A9); the `T → W` collaboration map stays **D-7** open (§10); V2′'s root remains a
single `uint256`, so the point is not fully bound (§5.5.10); the transport is not
deployed (Fuji phase 1 covers only the registry, vault and manager); and no security,
liveness or economic claim is made about a registry that publishes such a link.

**Validated locally.** `cargo test --offline --release` → **42 passed, 0 failed, 1
ignored** (9 of them `bridge.rs`'s, 4 in `tests/m7c_bridge.rs`, the ignored one
M4a's 32,768-bit proof); `cargo clippy --offline --all-targets -- -D warnings` →
clean; `cargo fmt --check` → 0 diffs; `cargo build --offline` → OK;
`scripts/m7c_report.sh` twice → `scripts/m7c_output.txt` byte identical
(`md5 633ee8703c4a192b89bc0641db60ea03`), with 11/11 internal checks holding and
the emitted fixture checked in both directions; `git status --porcelain
verification/` → 0 lines, so the sealed tree is untouched.

### 5.11 M7d as delivered (the Teleporter/AWM transport, gap A9)

Status: **A9 is closed in code, offline.** `integrations/avalanche/contracts/` gains
the wire format and the three message contracts of
`docs/architecture/avalanche-integration.md` §4;
`integrations/avalanche/test/M7dTransport.t.sol` is the 48-test suite over them; and
`scripts/M7dReport.s.sol`, `scripts/m7d_report.sh` and the pinned
`scripts/m7d_output.txt` (62 rows, 13 of them refusals) are the transcript,
reproduced by that one command. **A8's phase 1 is deployed; the transport is
not** — it needs the address of a real `TeleporterMessenger` and per-network
origin/destination configuration, neither of which an offline milestone or the
phase-1 C-Chain run supplies.

**The gap, stated exactly.** §4 names three messages — commitment propagation, a
collusion alert, a slashing notification — and says the transport is "Teleporter over
Avalanche Warp Messaging, signed by BLS signatures at the consensus level". Before
M7d that was all prose: no message had a shape, no receiver had an allowlist, nothing
deduplicated a delivery, and no line of this repository had ever been compiled against
Teleporter. §5.9 and §5.10 delivered A7's other two pieces and both said so in their
"deliberately not done" lists; this is that line, closed.

**The ABI is declared, not vendored.** `contracts/interfaces/ITeleporterReceiver.sol`
transcribes the receiver interface and `ITeleporterMessenger.sol` declares the subset
M7d calls (`sendCrossChainMessage` plus `TeleporterMessageInput`/`TeleporterFeeInfo`),
both read from `ava-labs/icm-contracts` on `main` while implementing the milestone.
This repository has never carried a git dependency and does not start now, so the price
is stated rather than hidden: **nothing here compiles against the real messenger**, and
the milestone is validated instead against
`test/mocks/MockTeleporterMessenger.sol` — a double that is a routing table
(`endpoint → chain`, so a sender cannot claim to be on another chain) with synchronous
delivery, whose header says exactly what it is not (no BLS, no quorum, no relayer, no
fee, no gas, no retry queue, therefore no latency and no claim about the protocol).
Two facts of that ABI decided the design and are quoted where they bite:
`receiveTeleporterMessage(sourceChain, originSender, payload)` hands the receiver **no
nonce and no message id**, and `sendCrossChainMessage` is not `payable` (fees travel as
an ERC-20 `feeTokenAddress`), so the transport carries no funds — consistent with M2's
"no custody" (§5.2.3).

**What M7d delivers, and why each piece is shaped the way it is.**

1. **`AVIPMessageCodec.sol` — the wire format.** Every message is
   `abi.encode(kind, nonce, payload)`: because AWM hands a receiver nothing it can
   deduplicate with, **the nonce has to be inside the message**, and the envelope is
   checked to be the *canonical* encoding of what it decodes to (one `keccak256`
   against a re-encode), so two encodings of one message cannot exist. Three payloads
   carry what a peer can act on *and recompute*: M1's root with the declared delta, the
   statement root and M7c's link; the alert's two tail decisions with the calibration
   they were decided against; and M7b's `published`/`formula` pair with the digest of
   the `f_c` instance in force. Values that are `f64` (`λ_max`, `−λ_min`) are not
   transported at all — the alert carries the *decision* plus the graph's `keccak256`,
   which is the rule M7c's table follows for the four-decimal numbers it pins. `encode`
   refuses to build a message that announces nothing (empty root, quiet alert, zero
   validator, a "fraud" whose two values agree, an unmapped kind) and every decoder
   re-checks the same predicates: the sender's copy is a courtesy, the receiver's is
   the boundary.
2. **`AVIPMessageEndpoint.sol` — one boundary for all three types.** The caller must be
   the messenger; the `(sourceChain → originSender)` allowlist is keyed *per kind* and
   fixed by the constructor (no setter, the spirit of M2's `slashAuthority`, §5.2.4);
   one contract answers for exactly one kind, enforced at construction *and* at
   delivery; and a `(source, sender, nonce)` that was delivered once is refused forever.
   An **empty allowlist is allowed and means "accepts nothing"** — which is how a
   send-only chain is wired, rather than a dead contract. Arrival *order* is
   deliberately not enforced: relayers promise no order, so requiring monotone nonces
   would refuse valid messages; a type that needs ordering enforces it over its own
   quantity instead.
3. **One contract per §4 message, deployed once per chain.** `AVIPCommitmentRelay`
   reads the root **out of the registry** (an uncommitted epoch cannot be announced) and
   records `(root, statementRoot, link, delta)` once per `(source, epoch)`, re-deriving
   the link from the payload's own words on arrival; `AVIPCollusionAlertChannel` records
   the flag once per `(source, epoch)`, so the flag set only grows and an alert cannot
   be retracted; `AVIPSlashingChannel` derives
   `reason = keccak256(sourceChain ‖ nonce)` and calls `AVIPValidatorManager.slash`, so
   the provenance id M8 will audit is a function of the envelope and not of anything the
   sender chose. The fields a side does not use (a receiver's registry, a sender's
   manager) are left zero at construction, so the bytecode that announces and the
   bytecode that records are the same bytecode — and the two deployments of a channel
   are one contract type, which is what makes the report's round trip a round trip.

**Acceptance criteria**, each traced to an artefact or to a computation; no new
constant enters.

1. **The wire is three messages, and their shape is checked against the crate that
   publishes it.** `AVIPMessageCodec.linkDigest` is
   `keccak256(abi.encode(merkleRoot, statementRoot, epoch))` — 96 bytes, the epoch as a
   word, which is what `src/zk/src/bridge.rs` writes by hand — and
   `test_linkDigestReproducesM7csCommittedLink` requires it to equal **M7c's committed
   link**; a 72-byte `abi.encodePacked` variant is measured and shown to be a different
   digest, so the encoding in force cannot drift by "optimisation". The fixture
   (`test/fixtures/M7cBridgeFixtures.sol`) is *declared* rather than generated, and
   `m7d_report.sh` checks it against `src/zk/scripts/m7c_output.txt` in both directions.
2. **The boundary is the messenger plus the allowlist, and each refusal is measured.**
   `NotTeleporter`, `UnknownOrigin`, `UnauthorizedOrigin`, `UnexpectedMessageKind` and
   `MessageAlreadyDelivered` each have their own test *and* their own row in the
   transcript (13 refusal rows in total), and the deployment itself fails closed: no
   messenger, no chain id, an allowlist entry of another kind, or a relay with a registry
   but no sequencer all revert at construction, while an empty allowlist is accepted and
   then refuses every delivery.
3. **Each type's effect is the one §4 names.** A commitment reaches the subscriber with
   M7c's link intact and is recorded once per epoch — and recorded *out of order* rather
   than discarded, so a fresher message cannot erase an older one and an older one cannot
   overwrite a fresher one; an alert arrives with both decisions and its calibration and
   cannot be rewritten; a slashing notification reaches the manager, **ejects** the
   validator (the whole record leaves, so `slash.stakeAfter = 0` — §5.13, M9b — while
   `slash.requiredStake` keeps the `S_f*(r) = 680317507197900649` the admission was
   priced from, for the certified norm `665564939881284858` M4d's proof binds; a
   re-entry adds the ejection surcharge, §12.1.2; `isAdmitted` goes false), and the
   `reason` the manager's own `ValidatorSlashed` event carries is the one
   the destination recorded — checked in the suite and again in the transcript.
4. **The numbers are the other milestones'.** M5's sealed `q99 = 9.0542`/`9.1371`
   (scaled to the 4 decimals the alert carries), M7b's `f_c` genesis digest and
   adjudicated `Verdict::Fraud` pair (`138673557278208441`/`138673557278208440`), and
   M7c's root, its tensor statement root and the link must each appear in the upstream
   transcript, in the declared fixture and in the fresh run; and the link the *contract*
   recomputes must be the link M7c published. The guard was exercised **negatively**:
   with M7c's link perturbed in `src/zk/scripts/m7c_output.txt` the script printed three
   `FAIL` lines, exited 1 and left the pinned transcript byte-identical.
5. **The report states its own mode and its own gaps.** It runs offline, prints 62 rows
   with no gas, no timing and no network address, is byte-identical across runs
   (`md5 8a1dd78f824930144625441aed821797` — the bytes M4d regenerated, §5.5.11), and
   its addresses are `anvil` account 0's CREATEs — so a reader cannot mistake the file
   for evidence about a chain.

**After M4d, "the statement's root" is two different numbers, and the report shows both.**
The root the relay announces is M7c's committed Poseidon commitment over the tensor
(`14881564148789680950073164612164838307833922018127128489011700125541095929892`), the
one §5.10's link ties to M1's fold. The root the admission proof consumes is M4d's
per-epoch Merkle root over `(validator, norm)` leaves
(`6105938163859590773966593243891138936289191320889329618475491144456189011390`,
§5.5.11), written by `postCommitment` into its own slot of the same registry. The report
therefore runs two registry instances, one per leg — the relay's root and link are M7c's,
`admit` is bound to M4d's — and neither number is a restatement of the other. Those two
deployments are a *reporting* convenience, not a contract constraint: `AVIPRegistry` keeps
both roots in two slots and one `postCommitment` writes both, and
`test/M4dRootSeparation.t.sol` exercises the two real roots in a single instance, with the
two negative directions (M7c's statement root cannot admit, and the admission root cannot
stand in for M1's fold). The legs stay apart in the transcript because each has to
reproduce its own pinned numbers, and M7c's link names the V3 statement root, not M4d's.
The wire format carries the first; the second never travels, because the registry the
proof is verified against reads it from its own storage.

**Deliberately not done**, each with its reason rather than as an omission: **no
deployment and no real Teleporter address** (A8's remaining half — a funded key and a
live endpoint, which no milestone here automates); no BLS signature, source-chain
quorum, relayer, fee or gas metering is exercised or claimed, since those are the
protocol's and the double is documented as not being them; **no latency**, so A11's
Teleporter benchmark stays deferred (§2.2); **no in-circuit keccak** (M7c's option (c)
chose recomputation over a circuit, §5.4 item 4); **no on-chain voting weight behind an
alert** — §4 says the alert "reduces the effective voting weight", but M2's manager
carries no weights (§5.2 defers them to M6), the message carries no node set, and which
validators a flagged graph names is decided off-chain, so what the transport delivers is
the flag and the impossibility of erasing it, not a discount; **no truth check** — a
compromised sequencer, alerter or notifier can announce a committed-but-lying root or ask
for a slash that no proof supports (`NotAFraudProof` catches only the self-refuting
case), because soundness lives in M7b's fraud proof and in the data layer; the `T → W`
collaboration map stays **D-7** open (§10); and no security, liveness or economic claim
is made about a chain that runs this.

**Validated locally.** `forge test --offline` → **171 passed, 0 failed, 0 skipped** over
7 suites (of which `test/M7dTransport.t.sol` is 48); `forge fmt --check` → 0 diffs;
`forge build --offline` → OK; `forge lint` → **4 notes, no warning** (the four are the
`setEnv` calls `test/DeployScripts.t.sol` must make; the two Teleporter interface files
are excluded from `mixed-case-variable` by path, with the reason in `foundry.toml`, so
that their parameter names stay diffable against upstream); `bash
scripts/m7d_report.sh` → **13 refusals and `status=ok`**, with
`scripts/m7d_output.txt` byte-identical across runs
(`md5 2bf8d16bfa20c1d47fa65690e240f0bd` at M7d's delivery; M9b and M4d regenerated it,
and §5.5.11 pins the current `8a1dd78f824930144625441aed821797`) and the upstream
guards passing in both directions, plus the negative run described above; `bash
verification/audit-gate.sh` → **PASS=11, FAIL=0, SKIP=0**; `git status
--porcelain verification/` → 0 lines, so the sealed tree is untouched.

## 5.12 M8 as delivered (treasury / custody, gap A2's second half)

Status: **A2's fund half is closed in code, offline.** `integrations/avalanche/contracts/`
gains `AVIPStakeVault.sol` (the custody behind `IAVIPCustody`) and `AVIPBurnSink.sol`
(the reference `IFundSink`); `AVIPValidatorManager.sol` is **amended** with a third
constructor argument (`custody`), an admission check against it and a `debit` on slash.
`integrations/avalanche/test/M8StakeVault.t.sol` is the 62-test suite over them;
`scripts/M8Report.s.sol`, `scripts/m8_report.sh` and the pinned `scripts/m8_output.txt`
are the transcript, reproduced by that one command, and `scripts/DeployStakeVault.s.sol`
is the deploy half of the wiring. **A8's phase 1 is deployed on Fuji** (chain
43113, `2026-10-19T01:46:52Z` UTC); the phase-4 L1 and the transport remain open.

**The gap, stated exactly.** §5.2.3 closes with M2's own limit — it "does not implement
token custody or transfer (ERC-20 or native); that is delegated to the M8 Treasury
Module" — and the paper leaves two things unnamed: whether slashed stake is destroyed or
retained (`S_slash = 10` is a *reputation* penalty, not a token transfer) and who, if
anyone, receives `F_0*`. Before M8 every one of those was declared and never moved: a
validator could be admitted with a `financialStake` that existed only as a number, and a
slash was an arithmetic change with no consequence.

**The model, and the one decision it makes (`D-M8-0`).** M8 supplies the movement and
refuses to invent the recipient. The vault transfers to a constructor-fixed `IFundSink`,
and *what the sink does* is a deployment fact:

| Component | What it fixes | What it deliberately does not decide |
|-----------|---------------|--------------------------------------|
| `AVIPStakeVault` | the token, the sink, the token scale (`WAD_PER_UNIT`) | where the funds go |
| `IFundSink` | that a slash and the fee are *notified* with an amount and a derived reason | whether the sink burns, keeps or forwards them |
| `AVIPBurnSink` (reference) | that the reference choice destroys them through the token's own `burn` | that burning is the protocol's choice |

Burning is the reference because it needs no actor the paper does not model: no treasury,
no beneficiary, no governance key. A deployment that keeps the funds implements the same
interface and changes nothing in the vault. The trade-off M8 records rather than resolves
is destroy-versus-retain: retention creates a spendable pot, which is a custody problem and
a governance question the paper never asks; destruction is irreversible but needs nobody.
The choice is one constructor argument, visible at the deployment boundary rather than
buried in a transfer target.

**Units, and the two rounding boundaries.** Escrow is accounted in the token's own base
units and *reported* in WAD (`escrowed`), so every comparison against `stakeOf` is
unit-clean; `WAD_PER_UNIT = 10 ** (18 - decimals)` is a deployment fact, because reading
`decimals()` would put a non-standard call on the custody path. Two boundaries follow, and
both are stated rather than hidden:

- `debit` **floors** (`floor(amount / unit)`): a slash smaller than one base unit moves
  nothing and still lowers `stakeOf`, which leaves the vault holding *more* than the
  record — the direction that keeps `escrowed >= stakeOf` true;
- the lock in `withdrawable` **ceils**: at most one base unit beyond the exact `stakeOf`
  stays locked, and it is released the moment the manager stops admitting the validator.
  A validator declaring `S_f*(Theta_r) = 733333333333333334` WAD against a 6-decimal token
  must escrow `733334` base units (`ceil`), because the paper's number is not
  representable in that token; the round-up is on the validator's side and always lands
  **above** the paper's requirement.

**The handshake, and why one side has to be mutable.** The vault authorises `debit` by its
manager; the manager reads and debits its vault. Neither address can be a constructor fact
of the other, so one contract has to have a hole. M8 puts the hole in the **vault**, and
`bindManager()` is filled exactly once by the **manager's own constructor**, which then
verifies `manager() == address(this)` and reverts otherwise. Consequences, all asserted:

| Situation | Behaviour |
|-----------|-----------|
| vault deployed, no manager yet | a plain escrow: everything withdrawable, `feeInUnits() == 0`, `payFee` reverts `ManagerNotBound`, `debit` reverts `NotManager` for everyone |
| manager deployed with `custody == address(0)` | original M2 exactly: the stake is declared, never checked against a balance, and `slash` moves nothing |
| manager deployed with the vault | the constructor binds it, verifies it, and both ends read back correctly |
| vault already bound by somebody else | the manager's deployment **reverts** (`ManagerAlreadyBound` bubbled) instead of existing with no custody |
| custody accepts the bind and reports nobody | the deployment **reverts** (`CustodyNotBound`) — the check that makes the handshake load-bearing |

The one race M8 accepts is a *deployment* race, not a funds race: a griefer can fill a
fresh vault's hole before the real manager's transaction lands, which makes the manager's
deployment fail loudly. It cannot move a token anywhere — the token and the sink are
constructor facts of the vault — and it cannot profit: the only destinations are the sink
and the depositors. The remedy is redeploying the vault, and the deployment order of
`avalanche-integration.md` §6 (vault, then manager, then any deposit) leaves the window
empty in practice.

**Admission, slashing and the fee, as delivered.**

| Path | M2 (before) | M8 (with custody) |
|------|-------------|-------------------|
| `admit` | checks `financialStake >= S_f*(T)` only | also requires `financialStake <= escrowed(validator)`, else `FinancialStakeNotBacked` |
| `slash` | reduces `stakeOf`, may eject | does the same and then calls `custody.debit(validator, amount, reason)` **in the same transaction**, after every write on its side |
| atomicity | not applicable | a failing token or a refusing sink reverts the whole slash: record and escrow move together or not at all |
| `payFee` | did not exist | the vault charges its **own caller** `F_0* / WAD_PER_UNIT`, pulls it straight from the payer's balance to the sink, and never lets it touch the vault's balance |
| `withdraw` | did not exist | returns only the caller's own escrow, capped by `withdrawable` |

There is no per-epoch fee ledger in the vault: charging once per epoch is the *caller's*
policy, and M8 claims nothing about it. Nothing here is a fee market — `F_0*` remains the
uniform posted price of §5.2.3, read from the manager so the policy has one source of truth.

**What M8 does not do.** No interest, rewards or staking yield; no second token; no
**native coin** — the whole path is ERC-20, `IFundSink.receiveFunds` is not `payable` and
the vault has no `receive`/`fallback`, so a native deployment needs a new interface rather
than a new constructor argument; no owner, pause, upgrade path or setter (the
constructor-fixed facts and the one-shot bind are the whole mutable surface); no exit queue
or cooldown (leaving the set stays the manager's
business); no governance of the sink; no sweep of tokens sent here by another route (they
are held and attributable to nobody); no fee-on-transfer or rebasing support (refused with
`InexactTransfer`, because the conservation identity is exact); no supply claim for the
burn (the *token* decides what `burn` means and `AVIPBurnSink` reports `BurnFailed` for a
token that cannot burn); and no economic claim about `S_slash = 10`, which stays the
paper's reputation penalty and is **not** executed on-chain.

**One hazard it declares rather than repairs: the unbound window.** The handshake
deploys the vault first and the manager second, and `bindManager` takes the first
caller that arrives. An unbound vault is a plain escrow — deliberate, and tested —
but the bind itself needs no code and no permission, so the first caller can be a
plain account. An EOA that binds *becomes* the manager: it can push any validator's
escrow to the constructor-fixed sink through `debit`, which checks only
`msg.sender != address(_manager)`, and because `withdrawable` staticcalls
`isAdmitted` on it, whose empty return data cannot be decoded, whatever is left can
no longer be withdrawn by its depositor. The remainder is not displaced but
*stranded*, and the vault's own header used to claim the opposite.

`test/M8StakeVault.t.sol` →
`test_aStrangerWhoTakesTheBindWithAnEoaDrainsAndTrapsAVictimsEscrow` executes it:
400 000 of a 1 000 000-unit escrow leave for the sink with the thief's own reason,
and the victim's `withdraw` of the remaining 600 000 reverts while `escrowedUnits`
still books them.

**Why the cheap guard does not exist.** A code-length check in `bindManager`
(`msg.sender.code.length > 0`) would refuse the one caller the handshake exists
for: `AVIPValidatorManager` binds from its own constructor
(`AVIPValidatorManager.sol:130`), where the caller's `EXTCODESIZE` is still `0`.
The `immutable` alternative needs the manager's address before the manager exists —
exactly the cyclic wiring the one-shot bind was chosen over (§5.12; the
CREATE-prediction precedent is M7d, §5.10) — so what closes the window is a
deployment rule, not a contract change: **the vault and the manager that binds it
must be broadcast in a single transaction**, one script performing both deployments
inside one `startBroadcast`/`stopBroadcast` pair. `DeployStakeVault.s.sol` and
`DeployValidatorManager.s.sol` are two separate scripts, and
`scripts/deploy_dryrun.sh` chains them inside one run as two executions: that proves
the wiring and *not* the atomicity, so it does not close the window.
`DeployFujiPhase1.s.sol` now performs the three deployments in one broadcast
session (the phase-1 run), which removes the operator gap between separate
scripts but **does not** make the vault and manager creation atomic: they remain
three transactions. Until a single-transaction deployer exists, a failure between
them can still leave a vault unbound, and nothing on-chain bounds it.

**The `S_slash = 10` reconciliation, and the `main.tex` amendments it queues.** M8 makes no
economic claim, but the paper does, and the two now disagree. The disagreement is recorded
here rather than repaired, because `main.tex` is in the sealed set (§3) and cannot be
touched outside the P6 batch (§9, §10). The paper's "Slashing and Integrity" subsection
(§7.5) concludes that the fraud is deterred — *"The attacker profit is negative for all
`B >= B*` because the slashing parameter `S_slash = 10.0` exceeds the fraud gain
`V_fraud = 1.0` by an order of magnitude"* (`main.tex:1027-1028`) — the grid books `-502.00`
(`main.tex:1014-1018`), and the section summary classes the row `Verified`: *"Attacker profit
`-502` with `S_slash = 10` | Verified"* (`main.tex:1055`).

**What that number is.** Under the sealed script's `coverage = 1.0` convention a detected
fraud earns nothing, so the per-epoch total is
`-S_slash * mean(n_frauds) = -10.0 * 50.2 = -502`, whose closed form is `-500`; the `-502`
is the seed-42 realisation, and C-07 closed the 52-unit gap as 50 (convention) + 2 (Monte
Carlo). It is reproducible *bookkeeping* under the script's arithmetic, and it is **not** an
executable loss.

**Why it is not executable, in the delivered contracts' units.** A slash moves tokens only
through `AVIPStakeVault.debit`, and what it can move is the escrow the validator actually
posted: the manager's `amount <= _stakes[validator]` (`AVIPValidatorManager.sol:241-242`) and
then the vault's `units <= _escrowedUnits[validator]` (`AVIPStakeVault.sol:376-377`). The
minimum a validator must post to be admitted is
`S_f*(r) = max{S_min, Theta - C_R(r)} <= Theta = 1.0`, and `C_R <= C_R^inf = 0.8` is an
opportunity cost that no function confiscates. Against a fraud gain of
`V_fraud * N_ATT * p_fraud = 1.0 * 500 * 0.10 = 50` per epoch, the paper's own parameters
bound the deterrent:

| Quantity | Value | Source |
|----------|-------|--------|
| Fraud gain per epoch | `50` | `V_fraud = 1.0`, `N_ATT = 500`, `p_fraud = 0.10` (`main.tex:1002`; `simulate_data_layer_v3.py:17-24`), with `n_frauds ~ Binomial(100, 0.5)`, mean `50.2` |
| Minimum stake a profit-maximising attacker posts, per validator | `<= Theta = 1.0` | `eq:allocation` (`main.tex:834`); `THETA = 1e18` (`AVIPValidatorManager.sol:57`) |
| Adversarial validators at `beta = 0.2` over 100 | `20` | `n_adv = int(100 * BETA_ADVERSARIAL)` (`simulate_data_layer_v3.py:46`) |
| Maximum confiscable per epoch (whole adversarial set, minimum stake, every token) | `<= 20` | `20 * 1.0`; `debit` cannot exceed escrow |
| Attacker's net for the epoch, with everything confiscated | `>= +30` | `50 - 20` |
| Loss the table books | `-502` | `main.tex:1014`, where the penalty is a parameter and not a transfer |

So with `S_slash` *not* executed, the deterrence sentence does not follow from the
parameters: even confiscating the whole adversarial set at the minimum admissible stake
leaves the fraud profitable for the epoch, and no arrangement of the delivered contracts
reaches `-502`, because the only moveable quantity is escrow and the table's multiplier is
`10x` it. What is left unquantified is the destroyed income stream of §2 — the framework's
own opportunity-cost argument — and M8 moves no number for it, because the paper prices none.
This is a **paper** finding, not an M8 defect: M8 is the side that already says
`S_slash = 10` is *"not executed on-chain"* (above), and both statements cannot stand
together.

**The two amendments, applied in P6a** (commit `094c41b`; amendment 1 verbatim,
amendment 2 as the *model* statement branch — the executable-loss bound in §7.5 and the
`Verified` → `Analytical` row in §7.7). Recorded here, exactly as §5.2.3
records its `F_0*` provenance note, and promotable to `docs/audit/claim-registry.csv` in the
next batched re-anchor (§9): the two `main.tex` edits below are the whole of the repair, and
nothing in `integrations/**` moves for them. §5.9 queues three more from the same section.

1. **`eq:revenue` is missing a factor** (`main.tex:981`, §7.3). As printed,
   `E[revenue] = p_fraud * N_ATT * B / n_auditors - c_audit`. The per-auditor cost is
   `N_ATT * c_audit`, as the prose two lines below already states — *"the per-auditor cost
   `N_ATT * c_audit = 50`"* (`main.tex:1025`) — and as the sealed script computes it
   (`total_cost = n_auditors * N_ATTESTATIONS * C_AUDIT`, `simulate_data_layer_v3.py:58`).
   With the printed form, `E = 0` gives `n* = N_ATT * B / B*`, not the
   `n*(B) = floor(B/B*)` the same page derives (`main.tex:988`); the missing factor is the
   one that makes `B* = c_audit / p_fraud` cancel. **Amendment: the trailing term becomes
   `- N_{ATT} * c_{audit}`.**
2. **§7.5 and the §7.7 row are restated** (`main.tex:1027-1030`, `:1055`). **Amendment:**
   bound the deterrence claim by the executable loss — escrow, `<= Theta = 1.0` per
   validator, `C_R` not confiscated — instead of by `S_slash`; or, if the claim is kept as a
   *model* statement, demote the row from `Verified` to the status the rest of that table
   already uses for a modelled, non-executable quantity. Either version must keep guard G8
   green — no `Estimate`/`Verified` mix on one line of `main.tex` (`verification/audit-gate.sh`).

**Both amendments were queued for P6b; P6b applies them both** (§12). P6a demoted §7.5 and the
§7.7 row (`main.tex:1027-1030`, `:1055`), but the same number is stated flat in §10.4's
"Stability of Conclusions": *"The attacker profit is `-502` with slashing
`S_slash = 10` and `+49.91` without detection"* (`main.tex:1266`). The residue is the
same defect in a second place: the figure is model bookkeeping under the sealed
script's `coverage = 1.0` convention, it is not an executable loss (above), and the
row it summarises in §7.7 no longer carries `Verified`. **Amendment:** restate
`:1181` with the status §7.7 now uses, or keep the sentence and bound it by §7.5's
executable loss. **Applied in P6b, second option:** the sentence stands and is
bounded — *"the loss collateralized on-chain is the escrowed stake of
Section~\ref{sec:payment}, bounded by $\Theta = 1.0$ per validator"* (`main.tex:1266`).
It travelled with P6b and not with M8 because `main.tex` is sealed
(§3) and P6b was already the batch that opens the paper — and because the C1–C4
restructure did **not** keep the line count 1:1 (1410 → 1566), the citations in the
three sealed `docs/audit/` files were re-derived in the same batch, before the root
was regenerated (`anchor-receipts.md` §R-3.1), instead of going stale.

**Second: an overloaded symbol in the payment section.** `main.tex:882` states
*"$\omega \sim U[0.01, 0.10]$ and $T$ uniform on $[0, 3]$ (so $C_R(T) \in [0, 0.6]$)"*,
but `T` is the tensor of §5.1, defined entry-wise as $T \in [0,1]^{C \times D \times H}$
(`main.tex:327`), and the quantity the Monte Carlo draws is its **norm**:
`verification/mechanism/fee_specification.py:86` samples
`norm_Ts = rng.uniform(0.0, 3.0, ...)`, and the $U_{\min}$/$U_{\text{mean}}$/$U_{\max}$
it prints are the ones at `main.tex:892-894` (`0.009747`, `0.069152`, `0.095891`), so
the support is on $\|T\|_F$ — which is admissible under `[0,1]` entries, whose norm can
reach $\sqrt{500} \approx 22.36$. The values are right and nothing is mis-stated
numerically; the *symbol* is doing two jobs in one paper. **Amendment:** write
$\|T\|_F$ where the norm is meant (`:831`, and wherever `C_R(T)` appears), leaving the
`[0,1]^{C \times D \times H}` definition untouched. **Applied in P6b:** `main.tex:842`
now declares `C_R(T) \equiv C_R(\|T\|_F)` and `main.tex:882` draws `\|T\|_F`; the
tensor definition at `main.tex:327` is unchanged, as required. Same batch, same
reason: it was a paper edit, and `main.tex` is sealed.

**Validated locally.** `forge test --offline` → **238 passed, 0 failed, 0 skipped**
over 9 suites (of which `test/M8StakeVault.t.sol` is 62, and the amended M2 suite's
34 and M7d's 48 run **unchanged**, which is the compatibility evidence for
`custody == address(0)`); `forge fmt --check` → 0 diffs; `forge build --offline` → OK;
`forge lint` → **4 notes, no warning** (the same four `setEnv` calls as before);
`bash scripts/m8_report.sh` → **6 refusals and `status=ok`** (42 rows), with
`scripts/m8_output.txt` byte-identical across runs
(`md5 55641a9f611c3ce64d35ffc7b8076a4f`), the fee derived from M7a's `F_0*` and the
deployed scale, the stake trajectory and the slashing reason checked against M7d's
transcript, and the certified norm against M4d's;
`bash scripts/deploy_dryrun.sh` → **9 cases**, the three new ones being M8's (the vault
script with no inputs, the vault script with them, and the manager script handed a custody
that cannot bind); `bash verification/audit-gate.sh` → unchanged (**PASS=11, FAIL=0,
SKIP=0**); `git status --porcelain verification/` → 0 lines.

## 5.13 M9 as delivered (the contract batch, P8)

All three milestones have landed — DEC-2's authority pair (M9a), DEC-4's slash
amount (M9b) and DEC-5's ejection surcharge (M9c). They are implemented and
tested offline; Fuji phase 1 deployed the amended contracts, but M9's paths have
not been exercised on-chain.

### M9a as delivered (registry authority, DEC-2)

Status: **DEC-2 is closed in code and tested offline, and M9b and M9c with it;
the amended contracts are deployed in Fuji phase 1 but their paths have not been
exercised on-chain.** `integrations/avalanche/contracts/AVIPRegistry.sol`
gains an immutable `guardian` and the propose/execute pair that replaces both
setters, `IAVIPRegistry.sol` publishes it, `scripts/DeployCommon.sol` and
`scripts/DeployRegistry.s.sol` take the new role and refuse a plan in which it is not
one, and the two suites over those surfaces grow — `test/AVIPRegistry.t.sol`
32 → **48** and `test/DeployScripts.t.sol` 21 → **24** — while the five suites that
only construct a registry (34, 62, 48, 18 and 7) keep their count *and* their
behaviour, which is the compatibility evidence that posting and certification are
untouched.

**The defect, stated exactly.** §12.1.2 fixed it as three facts about the old
contract, and they are one fact seen three ways: `sequencer` was the only caller of
both setters, so the role that *posts* commitments was the role that *decides who
posts* them; neither setter emitted an event, so a rotation was invisible after the
fact; and `setVerifier` had no `address(0)` check, so the sitting key could silently
disable certification (`verifyThreshold` then reverts `VerifierNotSet`). Nothing was
self-healing in either direction: a rogue sequencer could not be replaced except by
the rogue sequencer, and a lost one could not be replaced at all.

**What the code does** — the guardian proposes, the delay gates, anyone executes:

- the constructor rejects `address(0)` as guardian (`ZeroGuardian`) beside M1's
  `ZeroSequencer`; that the two roles are *different kinds of authority* is enforced
  one level up, in the deployment path, because a contract cannot check a key policy
  (below);
- `proposeSequencer`/`proposeVerifier` are `onlyGuardian`, reject `address(0)`
  (`ZeroVerifier` on the verifier lane), arm `pending*` plus
  `*Eta = block.timestamp + CHANGE_DELAY` and emit `<Role>Proposed(next, eta)`;
  re-proposing restarts the delay rather than shortening it;
- `executeSequencerChange`/`executeVerifierChange` are **permissionless**: they
  require the pending value to be non-zero (`NoPendingSequencerChange`,
  `NoPendingVerifierChange`) and `block.timestamp >= eta` (`ChangeNotReady(eta, now)`),
  then commit, emit `<Role>Changed(old, new)` and clear;
- `cancelSequencerChange`/`cancelVerifierChange` are `onlyGuardian`, and the two lanes
  are independent, so a lost-verifier rotation is not stuck behind a contested
  sequencer one.

**What it deliberately does not decide.** That the guardian is a multisig is a
deployment fact, and the contract says so by not pretending to check it: it needs a
*second authority*, not a particular key policy — which is why the collapse of the two
roles is refused where the keys are actually resolved (`DeployRegistry`'s
`RolesCollapsed`, and `MissingRole("GUARDIAN")` for the zero case) and not inside the
constructor. The verifier **stays mutable** (DEC-2): this registry is also the
commitment history (`_roots`, `_changedEntries`) that `admit` reads back, so freezing
the verifier would turn a circuit bug into a redeploy that loses that history.
`CHANGE_DELAY = 2 days` is a **deployment constant, not a model parameter** (§6): it
appears in no paper equation and backs no number in this repository, so §6 lists it as
an absence of provenance rather than inventing one.

**Validated locally.** `forge test --offline` → **257 passed, 0 failed, 0 skipped**
over 9 suites (238 before M9a); `forge fmt --check` → 0 diffs; `forge build --offline`
→ OK; `forge lint` → **4 notes, no warning** (the same four `setEnv` calls as in
§5.12); `bash scripts/deploy_dryrun.sh` → **11 cases**, the two new ones being M9a's
own refusals at the deployment boundary (a guardian pinned to the sequencer, and one
pinned to zero — neither creating a contract), with the regenerated
`scripts/deploy_dryrun_output.txt` byte-identical across two runs
(`md5 1208fa7a787da04319fb530027bcb8c6`); `bash scripts/m7d_report.sh` and
`bash scripts/m8_report.sh` → `status=ok`, both pinned transcripts byte-identical
across runs (`md5 2bf8d16bfa20c1d47fa65690e240f0bd` and
`147064b25244913b7398330f8730baf4`), so the third constructor argument left the wire
transcripts' bytes alone; `bash verification/audit-gate.sh` → unchanged
(**PASS=11, FAIL=0, SKIP=0**); `bash verification/fase0_anchor.sh --check` → exit 0;
`git status --porcelain verification/ docs/paper/` → 0 lines.

### M9b as delivered (the slash amount, DEC-4)

`slash(address validator, bytes32 reason)` now takes **the record**, and the record
is what it takes: `AVIPValidatorManager.slash` reads `_stakes[validator]` and
empties it, so M2's `SlashExceedsStake` — a check that existed only to reconcile two
numbers — is replaced by `NothingToSlash`, which refuses an empty record. The
consequence is arithmetic rather than policy: since `requiredStakeFor` is never
below `S_min > 0` (§5.2.3), a whole-record slash always ejects, and the ejection
reports the empty record it leaves behind (`ValidatorEjected(v, 0, S_f*)`).

**What left the wire, and why that is the point.** `amountWad` is gone from
`AVIPMessageCodec.SlashingNotification`, its `ZeroSlashAmount` predicate with it
(three predicates remain, plus M7b's `NotAFraudProof`), and `AVIPSlashingChannel`'s
`notify`/`_deliver`/events no longer carry or echo it: the type-3 message carries
the fraud proof's outcome — validator, epoch, ingestion digest, and the two values
that disagree — and the destination applies its own book to it. So the number that
decides what a validator loses is the number the rest of the protocol reads
(`stakeOf`, and the escrow `admit` demanded against it), rather than a sender's
claim about it. What a subnet is told is the *fact* of the fraud; what it seizes is
its own record, which is what "all subnets where the slashed validator is
registered" (integration §4) means once the amount is a local fact. `SlashingExecuted`
keeps the envelope-derived `reason` and drops the amount: the amount is recoverable
by joining on that `reason` against the custody's `StakeDebited` event, which is
where a fund movement belongs.

**The rounding, which is where M8 and M9b meet.** `debit` floors WAD to base units,
and the new amount makes that boundary *funded by construction*: `admit` requires
`financialStake <= escrowed`, so `floor(record / WAD_PER_UNIT) <= escrowUnits` and a
whole-record slash can never revert `InsufficientEscrow`. What the token cannot
express stays the validator's — `escrowed` ends above the cleared record by the
round-up, and `withdrawable` equals it once the ejection releases the lock. Where
the escrow is exactly the record (a declaration that is a whole number of units)
nothing is left on either side, and that equality is a test of its own
(`test_slash_debitsExactlyTheEscrowTheRecordNames`, the case the plan asked for).

**Tests.** `AVIPValidatorManager.t.sol` 34 → **33**: seven slashing tests that
existed to explore a transported amount (a partial slash that leaves the validator
admitted, one wei short of the minimum, more than the stake) are replaced by six
that pin the new rule — the authority, the whole record with a buffer, the ejection
at the exact minimum, an address that never staked, a second slash of the same
record (the "zero stake still reverts" case), and that a neighbour's record is
untouched. `M8StakeVault.t.sol` 62 → **63**: the exact-escrow case above is new; the
flooring test moves to the `debit` boundary the manager calls, since nothing
reaches it through `slash` any more; and the fuzz that varied the slashed amount
now varies the declaration and the escrow around it (the amount is no longer a free
variable, which is the milestone in one sentence). `M7dTransport.t.sol` keeps its
48: the amount disappears from its fixtures, its end-to-end assertion becomes
`STAKE_WAD` (what the record held) and the two notifications it uses to show that a
`reason` is not the notifier's to choose now name two different validators, because
the first one's record is empty.

**Validated locally.** `forge test --offline` → **257 passed, 0 failed, 0 skipped**
over 9 suites (the same total: one test fewer in M2, one more in M8, the transport
suite unchanged); `forge fmt --check` → 0 diffs; `forge build --offline` → OK;
`forge lint` → the same **4 notes, no warning**; `bash scripts/m7d_report.sh` → 62
rows, byte-identical across runs (`md5 40130315ec07f2f3fc469cf43d36e7f1`, one row
fewer: `notify.amountWad`) and `bash scripts/m8_report.sh` → 42 rows
(`md5 2955c738f2c2a56cb0f6936c4b8e5ff8`, one row more: `slash.recordBefore`), both
`status=ok`; `bash scripts/deploy_dryrun.sh` → **11 cases**, transcript unchanged
byte for byte (`md5 1208fa7a787da04319fb530027bcb8c6`), which is the evidence that
M9b moves no deployment; `bash verification/audit-gate.sh` → **PASS=11 FAIL=0
SKIP=0**; `bash verification/fase0_anchor.sh --check` → exit 0;
`git status --porcelain verification/ docs/paper/` → 0 lines. The M8 drift guard was
adjusted where its old shape would have gone vacuous: with `slash.stakeAfter` at
`0`, a substring test for `"0"` could not fail, so the fixture tie is the whole
declaration (`M7D_SLASH_STAKE_AFTER = 0;`) and the run side is still compared
numerically in both directions.

### M9c as delivered (the ejection surcharge, DEC-5)

`admit` now requires `S_f*(certifiedNorm) + ejectionsOf(validator) * EJECTION_SURCHARGE`,
and the second term is the whole of the milestone: the re-entry cost is **its own
term**, not an inflation of `S_f*`. The reason is arithmetic — `Theta - S_f*(r)` is
the collateral the norm earns, so folding a history-dependent quantity into `S_f*`
would make that credit shrink with every ejection and go negative for a validator
ejected often enough, which is a state no contract should be able to represent.
`collateralOf` therefore reports the same `C_R` at every re-admission, and §5.2.4's
"derived, never stored" survives: the surcharge inside `_requiredStakes` is
recovered from the counter (`- _ejections[v] * κ`), which is exact because the count
cannot move while a validator is admitted — an ejection revokes the admission in the
same call.

**The record and its observability.** `slash`'s ejection path increments
`_ejections[validator]`, which is never reset: what prices the next admission is the
validator's history rather than the session that ended. `ejectionsOf` reports it,
`EJECTION_SURCHARGE` reports the price, and `AdmissionEvaluated` gains the
**surcharge** — so a larger requirement is visible in the event that explains it
rather than inferred from a count the reader has to multiply. (The count is
`surcharge / κ`, and the event carries the surcharge because that is the number the
requirement is made of; carrying both would have been two encodings of one fact, and
the `admit` frame was already at the edge of the stack.)

**κ is a deployment constant with no paper value** (§6, §9). The paper names the
term symbolically and claims no magnitude for it, so no `verification/` script and
no `F-` entry are opened; instead `DeployValidatorManager.s.sol` asserts what it
deploys (`EJECTION_SURCHARGE = 1e17`, `0.1` WAD), `test/DeployScripts.t.sol` pins it
where the script's plan is driven, and the dry-run transcript quotes it
(`check.EJECTION_SURCHARGE=100000000000000000`, one row more). `0.1` is a choice of this deployment and not a measurement: a
visible fraction of `Theta = 1.0`, a whole base unit even for a one-decimal token,
and small enough that the third chance, not the second, is what becomes expensive.

**Tests.** `AVIPValidatorManager.t.sol` 33 → **37**: four new cases pin the rule —
the second admission costs `+κ` (and the image alone is refused), the third costs
`+2κ` with `requiredStakeFor` blind to history, the event carries the surcharge and
the larger requirement, and the counter is per validator and survives a
re-admission. `M8StakeVault.t.sol` 63 → **64**: the case §12.1.2 asks for by name,
where a validator is ejected, withdraws its whole escrow, and is then one surcharge
short of admitting again — so the count is a fact about the validator and not about
the funds, and the escrow that used to suffice is priced against the new
requirement. `M7dTransport.t.sol` is untouched: no wire format moved, which its
byte-identical transcript is the evidence for.

**Validated locally.** `forge test --offline` → **262 passed, 0 failed, 0 skipped**
over 9 suites (257 before M9c; the two M9b expectations stand unchanged);
`forge fmt --check` → 0 diffs; `forge build --offline` → OK; `forge lint` → the same
**4 notes, no warning**; `bash scripts/deploy_dryrun.sh` → **11 cases**, transcript
one row longer and byte-identical across two runs
(`md5 d68537cdb33ba64c33f45129c0538646`); `m7d_output.txt` and `m8_output.txt`
unchanged byte for byte (`40130315ec07f2f3fc469cf43d36e7f1` and
`2955c738f2c2a56cb0f6936c4b8e5ff8`) *at M9c's delivery* — M4d later regenerated
both when the admission statement changed, and §5.5.11 pins the current bytes;
`bash verification/audit-gate.sh` → **PASS=11
FAIL=0 SKIP=0**; `bash verification/fase0_anchor.sh --check` → exit 0;
`git status --porcelain verification/ docs/paper/` → 0 lines.

**What P8.x owes, now that all three landed.** The paper's `main.tex` understates and
misstates in three places this batch closes: §7.4's «caller-supplied amount bounded
by the validator's own escrowed stake» (false since M9b), §7.5's «the reputation of
a slashed validator is reduced» (nothing writes a reputation reduction; what the
code writes is the ejection count and the surcharge), and §10.2's description of
what is deployed at seal time (the guardian pair of M9a). None of them is in this
batch's files: §12.1's order puts M9 before P8.x, and P8.x must land in the same
release.

## 6. Interfaces and parameter provenance

The contract boundary is fixed by **interfaces** (types only, no logic —
M1 and M2 now implement two of them, and M8 adds the custody pair):

| File | Key surface |
|------|-------------|
| `contracts/interfaces/IAVIPRegistry.sol` | `postCommitment(epoch, commitment, statementRoot, changedEntries)`, `commitmentOf(epoch)`, `statementRootOf(epoch)`, `changedEntriesOf(epoch)`, `tensorSize()`, `maxDeltaEntries()`, `latestEpoch()`, `verifyEntry(root, leaf, proof)`, `verifyThreshold(epoch, validator, certifiedNorm, proof)` (view) |
| `contracts/interfaces/IAVIPValidatorManager.sol` | `stakeOf`, `collateralOf`, `requiredStake`, `isAdmitted`, `custody()`, `F0_STAR()`, `admit(validator, financialStake, certifiedNorm, proof)`, `slash(validator, amount, reason)`; events `ValidatorAdmitted(validator, stake, collateral)`, `AdmissionEvaluated(validator, epoch, certifiedNorm, collateral, requiredStake)`, `ValidatorEjected(validator, stake, requiredStake)`, `ValidatorSlashed(validator, amount, reason)`; errors `FinancialStakeNotBacked(financialStake, escrowed)` and `CustodyNotBound(custody)` (§5.12) |
| `contracts/interfaces/IAVIPCustody.sol` | `escrowed(validator)` (WAD), `manager()`, `bindManager()` (one-shot, called by the manager's constructor), `debit(validator, amount, reason)` (manager-only) — the whole boundary between the manager's record and the funds (§5.12) |
| `contracts/interfaces/IFundSink.sol` | `receiveFunds(amount, reason)`: the vault transfers first and then *tells* the sink, so the sink needs no allowance and cannot half-accept (§5.12, `D-M8-0`) |
| `contracts/interfaces/IERC20Minimal.sol`, `IERC20BurnableMinimal.sol` | the three ERC-20 functions the custody uses (`balanceOf`, `transfer`, `transferFrom`) and the one the reference sink adds (`burn`); deliberately not OpenZeppelin's, since the repository vendors nothing but `forge-std` (§5.12) |
| `contracts/interfaces/IZKThresholdVerifier.sol` | `verify(a, b, c, publicInputs)` (Groth16 shape over BN254) |
| `contracts/interfaces/ITeleporterMessenger.sol` | `sendCrossChainMessage(TeleporterMessageInput)` (the subset M7d calls, verbatim from `icm-contracts`), with `TeleporterMessageInput { destinationBlockchainID, destinationAddress, feeInfo, requiredGasLimit, allowedRelayerAddresses, message }` and `TeleporterFeeInfo { feeTokenAddress, amount }` |
| `contracts/interfaces/ITeleporterReceiver.sol` | `receiveTeleporterMessage(sourceBlockchainID, originSenderAddress, message)` — no nonce, no message id, which is why the AVIP envelope carries one (§5.11) |

`src/datalayer/src/ingestion.rs` adds a fourth, the only one off-chain and the only
one with no Solidity counterpart: `Ingestion { chain, parameters_digest, score }`,
with `Score` a WAD integer in `[0, 1e18]` (§5.9). It is provisional in the same
sense as the three above, and for one more reason: `f_c` itself is the protocol's
to choose, so the trait fixes the shape of the interface and not the function —
`GenesisFormula` is one declared instance, not the deployed one.

They are provisional: a signature change is not a breaking change while nothing
is deployed. M1 changed exactly one signature — `postCommitment` now carries the
declared epoch delta, because the freshness rule of the Data Layer needs it —
and added the readers that rule implies. M2 changes `verifyThreshold` (§5.2):
it becomes `view`, drops the `validator` argument, builds the statement
`[root, epoch, certifiedNorm]` internally, and moves threshold enforcement to
the manager. **M4d changes both signatures again** (§5.5.11): `postCommitment`
takes the keccak `commitment` and the Poseidon `statementRoot` separately (P-16),
and `verifyThreshold(epoch, validator, certifiedNorm, proof)` restores the
validator as a *bound* public input, so the statement is
`[statementRoot, epoch, validator, certifiedNorm]` (P-01). M7d adds the two
Teleporter files and they are provisional in a
stronger sense than the rest: they are transcribed from an external project that
this repository does not vendor, so **nothing here compiles against the real
messenger** and the transport is validated offline against a double whose limits
are written at the top of `integrations/avalanche/test/mocks/MockTeleporterMessenger.sol`
(§5.11). Every parameter they mention has a provenance:

| Parameter | Value | Provenance |
|-----------|-------|------------|
| `Θ` (admission threshold) | `1.0` | Payment Rule; frozen at genesis |
| `C_R(r)` | `0.8r/(1+r)` | Reputation Dynamics / Payment Rule (closed form) |
| `C_R^∞`, `S_min` | `0.8`, `0.2` | `verification/mechanism/financial_floor_sensitivity.py` |
| `Θ_r` (Frobenius threshold) | `0.5` **[CONJECTURE]** | ZK section [CONJECTURE]; enforced in `AVIPValidatorManager`, not in the registry (§5.2.2) |
| `C·D·H` (tensor size) | `500` | Tensor Compression |
| `γ` (freshness) | `0.10` | Data Layer; `simulate_data_layer_v3.py` |
| `S_slash` | `10` | Data Layer; `simulate_data_layer_v3.py` |
| `q99` (right tail) | `9.0542` | Collusion; `calibration_modularity.py` |
| left-tail boundary | `−λ_min > 9.1371` | Collusion; `bipartite_power.py` |
| `F0_STAR` (uniform posted price) | `5e16` (0.05) | Payment Rule (main.tex §6.4); enforced in `AVIPValidatorManager`; IR-safe lower bound on the admissible domain, whose true optimum is 0.07666... (§5.2.3) |
| Groth16 public inputs `k` | `4` (`[statementRoot, epoch, validator, norm]`) | §5.5.11 (M4d; supersedes §5.2.1's `k = 3`); fixed by `AVIPRegistry.verifyThreshold` and `Groth16Verifier` (§5.4) |
| pairings per verification | `4` | Groth16: `e(−A,B)·e(α,β)·e(vk_x,γ)·e(C,δ)` (§5.4) |
| `CHANGE_DELAY` (M9a role changes) | `2 days` | **No paper provenance, deliberately**: it appears in no equation of `main.tex` and in no `verification/` script, so it is a deployment constant and not a model parameter (§5.13). `DeployRegistry.s.sol` re-declares it and the dry-run transcript pins it, so §10.2 quotes a value a deployment actually installs |
| `EJECTION_SURCHARGE` (M9c re-entry, κ) | `1e17` (`0.1` WAD) | **No paper value, deliberately**: the paper names the term symbolically and claims no magnitude for it, so the deployment is where the number lives — `DeployValidatorManager.s.sol` asserts and reports it (`deploy_dryrun_output.txt`, `check.EJECTION_SURCHARGE`) and §9's code→paper rule opens no `verification/` script and no `F-` entry for it. What the paper's rule buys does not depend on the value: `C_R` is untouched by ejections because the term is separate (§5.13) |

## 7. Conventions for new code

- **Solidity**: `pragma solidity ^0.8.24`; compiled with solc `0.8.33`,
  `evm_version = "cancun"`, `optimizer = false` (same setting as the gas
  benchmarks cited in the paper, so numbers stay comparable). NatSpec on every
  external function.
- **Naming**: contracts keep the architecture's names (`AVIPRegistry`,
  `AVIPValidatorManager`). AVIP is the protocol's contract prefix; it is used in
  `avalanche-integration.md` and is not expanded there — expand it or replace it
  when M1 lands (D-2).
- **No secrets, no mainnet**: no private keys in the tree (`.gitignore` already
  excludes `*.key`/`*.pem`); no deployment script targets mainnet.
- **Docs**: every new directory ships a `README.md` stating what exists, what
  does not, and the milestone it belongs to.
- **Git**: one milestone per branch (`feature/m1-registry`,
  `feature/m2-validator-manager`), per `CONTRIBUTING.md` §Workflow.
- **Numbers**: any numeric constant in code carries a provenance comment
  (paper section or `verification/` script). Unsupported constants are rejected
  in review.
- **Lint**: `forge build` and `forge lint` stay silent. A lint that cannot be
  fixed without hurting readability is excluded **by id** in `foundry.toml`
  with its reason written next to it (today: `asm-keccak256`).

## 8. Testing policy

`CONTRIBUTING.md` makes tests a merge condition for `integrations/avalanche/`.
Concretely, for every milestone:

1. `test/<Contract>.t.sol` exists and `forge test -vv` is green.
2. The file header states **what is tested** and **what is NOT tested**
   (e.g. "the recursive SNARK is mocked; `IZKThresholdVerifier` is a stub").
3. Tests run offline (`forge test --offline`); `forge-std` is reused from
   `benchmarks/lib/forge-std` via remapping, never re-vendored.
4. Numeric assertions trace to a paper claim or a `verification/` script.
5. Rust code (M4–M6): `cargo test` plus a declared deterministic seed.

## 9. Traceability and the re-anchor procedure

The repository's rule is *a script for every number*. For the system the rule
becomes *an artefact for every claim*, in one of two directions:

- **Paper → code.** A contract or module cites the paper section it implements
  (NatSpec `@dev`, README, or test header).
- **Code → paper.** If building the system produces a **new quantitative
  claim** (proving time, gas of the real verifier, testnet latency), it cannot
  go into `main.tex` without a backing script — and adding it reopens the
  content audit.

Re-anchoring procedure (only for the sealed list in §3), to be run **once per
batch**:

1. Make every intended edit to the sealed files in one working session.
2. Re-run the suite: `bash verification/run_all.sh` (regenerates
   `verification/output_manifest.txt` and its `.sha256`).
3. Re-derive the anchor: `bash verification/fase0_anchor.sh`.
4. Verify: `bash verification/audit-gate.sh` → expect `FAIL=0`; and
   `bash verification/fase0_anchor.sh --check` → exit 0.
5. Append the new receipt to `docs/audit/anchor-receipts.md` (outside the root,
   no cycle) and re-seal externally (OpenTimestamps).
6. On any discrepancy: `git reset --hard HEAD` and report.

Because steps 2–6 are expensive and destroy the previous receipt, the C-phase
(paper apparatus, §2.4) is done as **one** batch, after the system code is
stable — the same reason the protection phase is last.

## 10. Open decisions

| # | Decision | Options | Recommendation |
|---|----------|---------|----------------|
| D-1 | Language of `src/` | Rust (as the architecture's prover) vs Python | **Rust** — the architecture names a Rust prover and `cargo` is available; Python is already the language of `verification/`, which stays as-is |
| D-2 | `AVIP` prefix | Expand it (`Andromeda Validator Incentive Protocol…`) vs keep the acronym | Still open. M1 landed with the architecture's names, so the decision no longer blocks M1; it now only affects how the prefix is documented |
| D-3 | Foundry project layout | New project at `integrations/avalanche/` (current) vs moving the benchmarks inside it | **Keep current**: the benchmarks are cited by the paper and by C-20; moving them would invalidate their recorded paths |
| D-4 | Code license vs paper license | MIT for code (already) and separate license for the paper | **Closed in P7a**: the repository is MIT (`LICENSE`, the MIT text untouched, with a scope note above it naming the one exception) and the paper is **CC BY 4.0** (`docs/paper/LICENSE`, the verbatim legal code). `CITATION.cff` names MIT at the root — the software's licence — and carries `preferred-citation` (`unpublished`, `in-preparation`) with `CC-BY-4.0` for the paper, because CFF 1.2.0 documents its licence *array* as **OR**, not AND: a list would have offered the manuscript under MIT |
| D-5 | solc drift | Paper says 0.8.33, badge said 0.8.24, machine has 0.8.33 | **Closed in P2**: badge aligned to 0.8.33, both Foundry projects pin 0.8.33; the one 0.8.24 artefact is documented, not edited |
| D-6 | M4 primitive (`D-M4-0`) | V1 paper-literal (Ristretto + Bulletproofs + recursion) vs V2 native Pedersen in-circuit vs V3 Poseidon in-circuit | **Closed in M4c (§5.5.10) as V3**: V1 leaves the implementation path (§5.5.5 — the `yoloproofs` gate), V2 as *written* is blocked at the type level, and its native repair **V2′** (Pedersen over Baby Jubjub) was built and measured against V3 through the same statement wrapper — 153,688 vs 94,438 constraints (+59,250, +62.7%, the commitment's 240-per-entry against Poseidon's ≈121), two curves against one, prove 6.3 s against 3.9–4.1 s (stderr, load-dependent; the pinned files carry only counts, sizes and digests). V3 is the variant M4b already installed, so no artefact changes |
| D-7 | The tensor → collaboration-graph map (`T → W`) | (a) invent a projection from the reputation tensor's entries onto validator pairs; (b) leave `W` as an input of the detector, with no derivation from `T` in the repository; (c) calibrate on a real collaboration graph once one exists | **Open, and left open by M5 (§5.6)**: `eq:collab` defines `W` as interactions between validators and `eq:tensor` defines `T` as one validator's scores, and §collusion never relates them, so any projection would be an invented constant-free but claim-bearing choice. M5's `fixture.rs` therefore only *binds* the detector's synthetic input to M4's committed digest (a wiring, printed as such in the pinned table), and the detector's contract is `detect(&Graph, &Calibration)`. Closing this needs real interaction data, which §11 lists as unavailable |

## 11. Out of scope here

- **Protection of the document**: done in P7a for the licence (D-4), the PDF
  metadata — `pdftitle`/`pdfauthor`/`pdfsubject`/`pdfkeywords`, which the PDF did
  not have (`pdfinfo main.pdf | grep -i title` printed nothing) — and the re-seal
  (receipt **R-4**), whose promotion arrived 16 h later (`ots upgrade`, four
  Bitcoin attestations in blocks `971035`–`971090`, §R-4.2). What remains is the
  **Zenodo deposit**, which needs an account — `.zenodo.json` already carries the
  metadata.
- **arXiv submission.** Deliberately last. The bundle is **one file**: no
  `\includegraphics` and an inline `thebibliography`, so `main.tex` is the whole
  submission and the packages it loads are all in TeX Live's
  base/recommended/extra collections.
- **External security audit.** Not started; required before any mainnet claim.
- **Teleporter latency benchmark** (A11, half): needs a live subnet.
- **Real reputation data calibration** (README "Not a goal"): no data source.

## 12. Phase order and immediate next step

| Phase | Content | Anchor risk |
|-------|---------|-------------|
| **P1 (done)** | This plan + Foundry skeleton + provisional interfaces | none |
| **P2 (done)** | B-gaps: README, `CITATION.cff`, benchmark README, badges aligned with reality (B1–B5) | none |
| **P3 (done — M1, M2, M3)** | M1 ✅ → M2 ✅ → M3 ✅ (on-chain core, §5.4) | none |
| **P4 (done — M4, M5, M6)** | M4 ✅ (M4a/M4b/M4c) → M5 ✅ → M6 ✅ (off-chain, §5.5–§5.7) | none |
| **P5 (done — M7, M8)** | M7 (data layer, deploy scripts, AWM) ✅ + M8 (treasury/custody) ✅ (§5.8–§5.12) | none |
| **P6a (done — `094c41b`)** | The five data-layer amendments of §5.9/§5.12: §7.3's fraud-proof mechanism with the bounty/slash status, §7.3's unstated pool/coverage conventions plus the §10.2 free-rider sentence, the freshness instance with §7.7's `Verified` labels, `eq:revenue`'s missing `N_ATT` factor, and the §7.5/§7.7 non-executable deterrence — twelve lines 1:1, plus §7.4's `We verify` → `We evaluate` (`main.tex:1002`) | **re-anchored** `2026-10-11T21:48:40Z`, root `217d6d51…` (G10/G11 green) |
| **P6b (done)** | C-gaps: paper apparatus (C1–C4) — `center` → `table[H]` with `\caption`, **1410 → 1566 lines** — plus the two amendments queued above, both applied (§5.12): §10.4's `-502` bounded by §7.5 (`main.tex:1266`) and `\|T\|_F` where the norm is meant (`main.tex:842`, `:882`). It carried the citation drift P6a did not introduce — `F-019`'s `:1215` (the sentence it cites lives at `:1183` on `aaaf460`, `:1268` now) and `C-14`'s `§8.7` pointer; the numbers this row used to quote (`:1297`, `C-48`) were mis-derived. Rather than correcting them, all cited tokens were **re-derived** before the root was regenerated: 316 tokens, 313 remapped, 23 files, 396 citations checked, **0 section changes** (`anchor-receipts.md` §R-3.1) | **re-anchored** `2026-10-12T00:54:19Z`, root `79ac6783…`, receipt **R-3** (G1..G11 PASS=11 FAIL=0 SKIP=0) |
| **P7a (done)** | Protection (D-4 licences: MIT for the repository, **CC BY 4.0** for the paper), the PDF metadata the PDF did not have, `.zenodo.json`, a frozen 37-page snapshot | **re-anchored** `2026-10-12T03:28:48Z`, root `5d6002ba…`, receipt **R-4** (promoted to Bitcoin in `971035`–`971090`); of the ten pairs **one** moved — the paper's |
| **P8 (done — M9)** | **M9, the trust-amendment batch** — `M9a` registry authority (DEC-2), `M9b` full-stake slash (DEC-4), `M9c` ejection surcharge (DEC-5), delivered in §5.13. Contracts, scripts and tests only | **none** — nothing under `integrations/` is in the sealed list |
| **P10 / P10b (done — F-022)** | Gas of the five Fuji phase-1 creations and Fuji C-Chain block time in the paper, with `F-022`; receipts **R-8** and **R-9**. Detail in `docs/audit/anchor-receipts.md` | **re-anchored** by R-8/R-9; no new anchor risk |
| **A6-doc (done)** | Documentation consistency sweep after Fuji phase 1 (this commit): no document claims the tree is undeployed; phase 1 is recorded with `verifier = address(0)` and the transport/phase-4 L1 as pending. **A6 in §2.2 remains reputation dynamics (M6).** | **none** — README/architecture only |
| **P9 (next)** | **Fase 4 + Fase 5 as one sealed batch** — the paper text under DEC-1/DEC-2/DEC-4/DEC-5 plus DEC-3 declared (§7.3, §7.4, §7.5, §9.4, §10.2, abstract, §1.2), `N-7` and the three remaining FASE 0 objectives, `M-05` with the **count manifest**, then **one** re-anchor. Detail in §12.1 | **re-anchored once**; `main.tex` is line 1 of the root |
| P7b | *now blocked by P9* — the Zenodo deposit and the arXiv submission (both need an account, not code). Release `D-3` forbids submitting before the batch above lands | none |

**Next step: P9** — P8 (`M9`: DEC-2 + DEC-4 + DEC-5; contracts, scripts and
tests only) and P10/P10b (`F-022`) are done. P9 is the paper batch (Fase 4 +
Fase 5) that closes DEC-1…DEC-5 in §7.3/§7.4/§7.5/§9.4/§10.2, the abstract and
§1.2, repairs `N-7`, adds `M-05` with the count manifest, and re-anchors
**once**. It is specified in §12.1 below.

**P7b is blocked by P9**: the Zenodo deposit (`.zenodo.json` is written, so the
upload is metadata and not a retyping) and the arXiv submission (`main.tex`
alone) wait for that re-anchor, because release `D-3` forbids submitting before
the batch lands. Fuji phase 1 is already deployed (chain 43113,
`2026-10-19T01:46:52Z` UTC); what remains outside P9 is the phase-4 Subnet L1
and the transport deployment.

## 12.1 The one batch: M9 (system) → Fase 4 (text) → Fase 5 (sealed + re-anchor)

Decided 2026-10-15. **No sealed file has moved**: `main.tex` and the nine other
sealed files are untouched, the gate is `PASS=11 FAIL=0 SKIP=0` and the anchor is
the committed one. Of the batch, `M9a`, `M9b` and `M9c` have landed, and only in
`integrations/` plus this plan (§5.13).

### Namespaces (no mixing)

| Space | Means | Status |
|-------|-------|--------|
| `DEC-1 … DEC-6` | **content** decisions — the audit triage's Part A | closed 2026-10-15 (§12.1.1) |
| `D-1 … D-4` | the **release process** decisions — triage Part D | untouched; they are why §12.1.4 re-anchors once |
| `P8.x` / `P9.x` | the execution units of this batch | below |
| `M9a` / `M9b` / `M9c` | the contract milestones; specified in §12.1.2, and **§5.13** on delivery (the §5.x convention) | P8 (done) |
| `F-022`, `M-05`, `N-7` | the new numerical entry, its measurement, the dangling-refs finding | §12.1.3 / §12.1.4 |

The four-item list maps as: alcance → **DEC-1**, secuenciador → **DEC-2**,
importe → **DEC-4**, reputación → **DEC-5**; plus **DEC-3** (time axis, declared as
a constraint) and **DEC-6** (`γ`, open and non-blocking).

**The order is forced, not chosen.** §10.2 must describe what is deployed at seal
time, so M9 (contracts, P8) precedes P8.x (text); and §9 allows exactly **one**
re-anchor per batch, so P9 is a single step.

### 12.1.1 The decisions as closed

| ID | Decision | Lands in |
|----|----------|----------|
| **DEC-1** | **Scope/custody — (B).** §7.3's «does not move funds» is true of *the delivered data layer*; the defect is a missing actor. The manager and the custody vault are named as delivered and the sentence is qualified, not deleted | `main.tex` §7.3 (`:974-980`), §7.4 (`:1028`) |
| **DEC-2** | **Sequencer — (B) + declare the state.** `M9a`: a `guardian` multisig is the only proposer, execution is permissionless after `CHANGE_DELAY`, both setters emit events, a zero address is rejected, and the **verifier stays mutable** — freezing it turns a circuit bug into a registry redeploy that loses the commitment history `_roots`/`_changedEntries` (`AVIPRegistry.sol:63-65`, written `:114-116`, read by the manager at `AVIPValidatorManager.sol:216-219`) | `M9a`, `main.tex` §10.2 |
| **DEC-3** | **Time axis — declared constraint, not enforcement.** The detection window is a *constraint*; `M-05` parametrises the attack model over detection latency **in epochs** instead of one scalar; an on-chain challenge window is **follow-up**, explicitly out of v1 | `main.tex` §10.2 (limitations), `F-022`/`M-05` |
| **DEC-4** | **Slash amount — (A).** `M9b`: `L` is the **whole posted stake** (`_stakes[validator]`) and the amount leaves the Teleporter payload. `L ≥ S_f*(T) ∈ [0.2, 1.0]` with **no upper bound**, because `admit` caps nothing (`AVIPValidatorManager.sol:200`, `:229`); the model's `Θ = 1.0` is a coverage convention, and the paper must say so | `M9b`, `main.tex` §7.4 (`:1028`), §9.4 (`:1274`) |
| **DEC-5** | **Reputation — (B) + (C) honest.** `M9c`: the re-entry cost is a **separate ejection surcharge** (`required = requiredStakeFor(norm) + n_ejections·κ`), never an inflation of `requiredStakeFor`, so `collateral` keeps deriving from the norm and `Θ − C_R` cannot go negative. §7.5 stops asserting a reputation reduction that nothing writes | `M9c`, `main.tex` §7.5/§7.4 (`:1030`), abstract, §1.2 (`:76`) |
| **DEC-6** | **`γ`'s value — open, non-blocking.** `N-6` calls `γ = 0.10` vacuous at horizon 10 and the paper already says so (`:1048`). Either a value is chosen (a numeric claim ⇒ a `verification/` script plus an `F-` entry) or the text states the bound is vacuous for the delivered parameters | **not in this batch** |

Two consequences beyond the four items: the `G = 50` scalar of `A-18`
(`:470-476`, a worksheet derivation and never a protocol quantity) stops being
used as a paper quantity, and the attacker `A-21` says is never named gets named.
Text that does both closes `A-18`, `A-20` and `A-21`, and collapses `A-22` into
`N-1`.

### 12.1.2 M9 — the contract batch (P8; nothing sealed)

**M9a — DEC-2, registry authority. Delivered** (§5.13: 48 registry tests, 24 script
tests, 257 in total, the gate and the anchor untouched). `contracts/AVIPRegistry.sol`.
The specification it was closed against, kept as written: `sequencer` was an `address`
fixed at construction (`:71-73`, `ZeroSequencer`)
and is the only caller of both setters (`:86-91`, `:93-96`); neither emits an event
and `setVerifier` has no `address(0)` check, so the role can silently disable
certification (`verifyThreshold` then reverts `VerifierNotSet`, `:174-175`).

1. The constructor gains an immutable `guardian` (`ZeroGuardian` revert). The
   guardian is an authority **distinct** from the sitting keys; that it is a
   multisig is a deployment fact.
2. `setSequencer`/`setVerifier` are **removed**. Each becomes a propose/execute
   pair: `proposeSequencer(address)`/`proposeVerifier(address)` are `onlyGuardian`,
   reject `address(0)`, set `pending*` and `*Eta = block.timestamp + CHANGE_DELAY`
   and emit `<Role>Proposed(next, eta)`; `executeSequencerChange()` /
   `executeVerifierChange()` are **permissionless**, require `block.timestamp >= eta`
   and a non-zero pending value, commit, emit `<Role>Changed(old, new)` and clear.
   `cancel*Change()` stays `onlyGuardian`.
3. `CHANGE_DELAY` is a contract constant, documented in `contracts/README.md` as a
   **deployment constant, not a model parameter** (§6).
4. Permissionless execution is the point: a compromised sitting key can neither
   rotate itself nor veto the guardian's rotation once the delay elapses. A delay
   on the same role would only make a rotation visible; the second authority is
   what closes the capture.
5. Ripple: `scripts/DeployRegistry.s.sol` and `scripts/DeployCommon.sol` take the
   new argument; `test/DeployScripts.t.sol` and the committed dry-run transcript
   `scripts/deploy_dryrun_output.txt` are regenerated — the transcript grows from
   nine to **eleven** cases, the two new ones being this milestone's own refusals
   (`GUARDIAN == SEQUENCER` → `RolesCollapsed`, `GUARDIAN = 0x0` →
   `MissingRole("GUARDIAN")`); `contracts/README.md`'s status table and NatSpec
   `@dev` citations follow §9's paper→code rule.

**M9b — DEC-4, the slash amount. Delivered** (§5.13: 33 manager tests, 63 vault
tests and 48 transport tests, 257 in total, the gate and the anchor untouched).
`contracts/AVIPValidatorManager.sol`, `contracts/AVIPSlashingChannel.sol`,
`contracts/AVIPMessageCodec.sol` and the manager interface.
The specification it was closed against, kept as written: the amount was a
**remote parameter**: `_deliver` executed
`MANAGER.slash(notification.validator, notification.amountWad, reason)`
(`AVIPSlashingChannel.sol:185`), `amountWad` is decoded from the Teleporter payload
(`AVIPMessageCodec.sol:138`) and validated only as non-zero (`:343`) and ≤ the stake
(`AVIPValidatorManager.sol:242`).

1. `slash(address validator, bytes32 reason)`; the amount is derived inside, from
   `_stakes[validator]` — the whole posted stake. The "≤ stake" check disappears
   because the amount *is* the stake.
2. The `amountWad` field and `ZeroSlashAmount` leave `AVIPMessageCodec`; the
   encode/decode pair and the `SlashingNotification` struct shrink.
3. `docs/architecture/avalanche-integration.md` §4 (Teleporter/AWM, the wire
   format) is updated — that file is **not** sealed.
4. Tests updated: `AVIPValidatorManager.t.sol` (34), `M7dTransport.t.sol` (48),
   `M8StakeVault.t.sol` (62); one new case asserts the debit equals the escrow on
   record, another that a zero-stake validator still reverts. **Delivered as 33, 48
   and 63** (§5.13): the M2 suite loses the arithmetic the argument made possible
   and gains the rule, the transport suite is unchanged in number, and the vault
   suite gains the exact-escrow case.
5. Consequence for the paper: `main.tex:1028`'s «caller-supplied amount» becomes
   **false** the moment M9b ships, which is why P8.x must land in the same release.

**M9c — DEC-5, the ejection surcharge. Delivered** (§5.13: 37 manager tests, 64
vault tests, 262 in total, the dry-run transcript one row longer, the gate and the
anchor untouched). `contracts/AVIPValidatorManager.sol`.

1. `mapping(address => uint256) _ejections;` plus a constant `EJECTION_SURCHARGE`
   (**κ**). `admit` becomes
   `stake = requiredStakeFor(norm) + _ejections[validator] * EJECTION_SURCHARGE`,
   while `collateral` stays `collateralFor(norm)`.
2. The ejection path (`:249-256`) increments `_ejections[validator]`. Because the
   surcharge is a separate term, `_requiredStakes` keeps its meaning as the
   norm-image **plus** surcharge and `Θ − C_R` cannot go negative — inflating
   `requiredStakeFor` instead would make a many-times-ejected validator's implied
   collateral negative.
3. The surcharge appears in `AdmissionEvaluated`, so the reason for the larger
   requirement is observable.
4. `κ` is a **deployment constant**: the paper names the term symbolically and
   claims no value for it, so no `verification/` script and no `F-` entry are
   opened (§9's code→paper rule). §6's parameter table lists it as such.
5. Tests: re-admission after one ejection costs `+κ` and after two `+2κ`; the
   collateral is unchanged; the counter is per validator and survives withdrawal.
   **Delivered as 37, 64 and 262 in total, with the counter's survival asserted
   against real escrow** (§5.13: the validator withdraws everything after its
   ejection and is then one surcharge short of admitting again).

Acceptance for M9 as a whole: `forge test` green **offline**, with the 238 tests
that passed before the batch still passing plus the new ones (257 of them once
`M9a` landed, §5.13); `cargo` untouched; nothing under `verification/` — and
therefore nothing sealed — modified. `git status` shows changes confined to
`integrations/`, `docs/architecture/avalanche-integration.md` and this plan.

### 12.1.3 Fase 4 (P8.x) — the paper text

P8.1 **§7.3 (`:974-980`) — DEC-1.** Keep «the delivered data layer … does not move
funds»; add the two subjects it omits: the manager that adjudicates and debits, and
the custody vault that holds the escrow. The paper names «the delivered manager»
exactly once (`:1028`), never names the vault, and uses `custody` once, in «chain
of custody» (`:1505`).

P8.2 **§7.4 (`:1026-1042`) — DEC-4 and DEC-5.** `L` is the whole posted stake,
`L ≥ S_f*(T) ∈ [0.2, 1.0]`, unbounded above; the «caller-supplied amount» clause
goes; the reputation-reduction sentence at `:1030` is withdrawn or qualified,
because `slash` writes no reputation state; the ejection surcharge with its `κ`
takes its place as the executable re-entry cost.

P8.3 **§7.4/§5.7 — DEC-3 and `M-05`.** The attacker `A-21` says is unnamed is
named, the scalar gain of `A-18` is replaced by the declared model (gain = the
stake the norm buys, loss = the escrow actually debited), and the detection window
enters as an explicit **constraint**. Whatever it costs is stated as a function of
latency in epochs, so the numbers must come from P9.3's script: the paper cannot
state a new quantity before that script exists, and that is the second reason P8.x
and P9 are one batch.

P8.4 **§9.4 (`:1274`) — DEC-4.** «bounded by `Θ = 1.0` per validator» is the
**model's** coverage convention. It must be labelled as such, or a reader can file
it as an executable cap, which the contract does not enforce.

P8.5 **§10.2 — DEC-2 and DEC-3.** Declare the state as it is after M9a: the
guardian as sole proposer, `CHANGE_DELAY`, permissionless execution, the events,
the rejected zero address, and the verifier's mutability with its reason (the
registry keeps the commitment history `admit` depends on). Then declare DEC-3: the
detection window is a constraint of this model and on-chain enforcement is
follow-up. `sequencer` does not appear in `main.tex` at all today, so this is an
addition, not a correction.

P8.6 **Abstract and §1.2 (`:76`) — DEC-5.** «reputational collateral» and «partial
substitutes» overstate what is executed; the term becomes reputation-weighted
*access cost*. The **title survives**: «Reputation-Weighted Validator Selection»
describes exactly the discount `collateralFor` applies.

P8.7 **Gate discipline inside P8.x.** No line may contain `Estimate` **and**
`Verified` (G8); `pdflatex` must end clean with `errors=0, Undefined=0` (G9), so
any new table, equation or label needs its references to exist; the abstract's
prose «twenty-one claims» is payload for G5 and must not be edited in isolation.

### 12.1.4 Fase 5 (P9) — the sealed batch, one re-anchor

P9.1 **`N-7`** in `docs/audit/content-audit-pending.md`: `:45` points at
`main.tex:837` and `:69` at `main.tex:805`, both blank today (the reference
`Θ = 1.0` with its parameters lives at `main.tex:870` now), and `:69` describes
`VaR_tech`, a symbol that no longer exists — the replacement is `S_{\min}`
(`main.tex:834,840,941`).

P9.2 **The three remaining FASE 0 objectives**, same file: the «No open finding
remains» overclaim (`:1707-1708`), `C-01`'s status (`:46`, `:155-160`), and the
internal refs of P9.1.

P9.3 **`M-05` and `F-022`, with the count manifest.** `M-05` is a measurement the
triage declares necessary and that does not exist yet (`:478-483`): a deterministic
`verification/mechanism/m05_attack_model.py` emitting the attacker's loss — and the
resulting deterrence — **as a function of detection latency in epochs**, declaring
its sample size and seed per the log's rules; registered in `verification/README.md`
(the source `run_all.sh` parses for its command list),
`verification/baseline_verified/manifest.txt` and
`verification/fase1_determinism_evidence.txt`; its output joins
`output_manifest.sha256` (**35 → 36 pairs**); and `F-022` records it in
`numerical-verification.md`.

The **count manifest is not only G5.** A literal count today lives inside two
sealed files: `audit-gate.sh:99` (`F-` = 21, exact) and `:106` (`C-` = 50, exact)
gate their values, `audit-gate.sh:44-48` floors the `.py` count at 35, and
`fase0_anchor.sh:189,196` *prints* «35 pares». Adding `F-022`, or `M-05`'s script,
therefore moves a number hardcoded in four places. P9.3 introduces one derived
source for the three counts (21 F entries, 50 C worksheets, 35 output pairs — the
last asserted as a floor, never as equality) and makes every message derive from
it, so the next entry does not need a four-file edit. Leaving the constants where
they are is possible, but it is exactly the state that made the reviewer ask for a
manifest.

P9.4 **The citation re-derivation.** Fase 4 moves `main.tex` lines, and
`claim-registry.csv` (sealed, 27 rows) stores a `line` column pointing into
`main.tex`; `content-audit-pending.md` and other documents cite `main.tex:NNN` too.
The batch therefore repeats P6b's job (`anchor-receipts.md` §R-3.1): a `difflib`
HEAD→worktree line map over every citation form the repository uses, then verify
**0 LaTeX section changes** and a strictly monotone map.

**Estado (2026-10-16): hecho.** El mapa se derivó de los hunks del diff —diez hunks,
+21/−9 = +12 líneas netas; tramos en `anchor-receipts.md` §R-5—, se inventariaron 411
tokens de texto más 27 filas del registro y se reescribieron **120 punteros en 9
documentos**, con **0 cambios de sección** y una segunda pasada byte-idéntica (la
base es siempre el blob de `HEAD`). `bash verification/audit-gate.sh` conserva
**8 PASS / 3 FAIL**: G4/G5/G6 pasan con los ficheros reescritos y G9 compila limpio;
los tres FAIL (G2, G10, G11) son pre-existentes del lote de `M-05` y se reproducen
idénticos con los documentos revertidos a HEAD. El inventario de **98 citas ya
muertas** y las exclusiones (triage, recibos, dos `.py` cuyo comentario se imprime y
las diez líneas de crónica) están en §R-5. Lo que sella es P9.5.

P9.5 **One re-anchor, in the order §9 fixes**: `run_all.sh` → `fase0_anchor.sh` →
`audit-gate.sh` (`FAIL=0`) → `fase0_anchor.sh --check` (exit 0) → a new receipt in
`anchor-receipts.md` → OTS re-seal. `audit_manifest.sha256` (not sealed) is
regenerated with its UTC header, the anchoring HEAD and its two pairs;
`output_manifest.sha256` moves only if `M-05`'s output does.

P9.6 **Loose end, adjacent but outside P9**: `.zenodo.json` carried a one-line
worktree difference left by an earlier session (one blank line at EOF); it has since
been restored to the committed bytes, so the file P7b deposits is byte-identical to
the one `bfe329d` committed. It is unsealed and belongs to release `D-1`/P7b —
nothing about it enters this batch.

**Estado (2026-10-17): P9.6a hecho; P9.6b espera a OTS.** El manifiesto de conteos
existe (`verification/count_manifest.txt`, tres pares) y es el **11.º par** de
`anchor_root.sha256`; G2, G5 y G6 lo leen en lugar de literales —un conteo que
cambie sin actualizarlo es FAIL explícito— y `F-022`, el registro de `M-05`, sube
la serie `F-` a 22. `fase0_anchor.sh --check` deriva el número de pares del fichero
regenerado (`36 pares`, `11 pares`), no de un literal. `bash
verification/audit-gate.sh` → `PASS=11 FAIL=0 SKIP=0`; `--check` exit 0; root
`559af48c…` anclado sobre `690a151`, con el detalle en `anchor-receipts.md` §R-6.
Queda **P9.6b**: `ots upgrade` hasta obtener la atestación de bloque Bitcoin y
anotar tx y altura en §R-6 — el `.ots` no es un par del root, de modo que ese paso
no re-ancla.

### Acceptance and rollback

The batch is done when, in one session: `forge test` offline green with the
pre-batch 238 tests still in it (257 after `M9a`, §5.13); `pdflatex` clean;
`bash verification/audit-gate.sh` →
`PASS=11 FAIL=0 SKIP=0` with G5 and G6 reading the manifest instead of a literal;
`bash verification/fase0_anchor.sh --check` → exit 0; a receipt recorded. On any
discrepancy §9's rule stands: `git reset --hard HEAD` and report. No sealed file is
edited before P9, and P8 never re-anchors.

*(The file's chronicle of delivered milestones resumes below; it is kept at the end
of §12 as the plan's historical appendix.)*

**M7 is delivered**:
M7b (§5.9) is the ingestion formula `f_c` as an interface, the fraud proof and its
audit equilibrium `n*(B) = ⌊B/B*⌋` with `S_slash = 10`; M7c (§5.10) resolves the
Pedersen ↔ Merkle bridge (option (c), §5.4 item 4) by tying the statement's `root`
to the registry's Merkle root with a link any peer recomputes; and M7d (§5.11)
delivers the transport — the three Teleporter/AWM message types of
`avalanche-integration.md` §4, as a wire format plus one contract per type, with
per-kind origin allowlists, at-most-once delivery and a slashing `reason` derived
from the envelope. M7 closed the loop between the off-chain crates (M4–M6) and the
on-chain contracts (M1–M3); M8 (treasury/custody) follows it in P5 and **is
delivered** (§5.12): the stake M2 declares is now escrowed, the slash this
transport triggers moves real tokens into a sink, and `F_0*` is collected — while
the *destination* of those funds stays a deployment fact, because the paper names
none (`D-M8-0`). §5.12 amends M2's `AVIPValidatorManager` with a `custody`
constructor argument; with `custody == address(0)` its behaviour is M2's,
unchanged, which the M2 suite running untouched is the evidence for.

**M7a is delivered** (§5.8): the phase-1 pair
`DeployRegistry.s.sol`/`DeployValidatorManager.s.sol` exists over the shared
`DeployCommon` floor, refuses C-Chain mainnet by construction, is driven in tests
through `deploy(Plan)` (no environment) and is verified out of process by
`scripts/deploy_dryrun.sh`, whose **eleven-case** transcript is committed (six from
M7a, plus M8's three, §5.12, plus M9a's two, §5.13). What remains of
A8 is the Fuji deployment itself — a funded key and a live endpoint, which no
milestone here automates — plus the phase-4 P-Chain registration.

**M7b, M7c and M7d are delivered too** (§5.9, §5.10, §5.11): the data layer's audit
equilibrium, the ingestion formula as an interface plus the three-valued fraud
proof, the Pedersen/Poseidon ↔ keccak bridge that ties the statement's `root` to the
registry's Merkle root over M1's own fold, and the Teleporter/AWM transport of §4's
three message types — each with a byte-stable report reproduced by one command and,
for the two that carry numbers from another milestone, a fail-closed drift guard
that reads the upstream transcript in both directions. What stays open in M7 is the
Fuji deployment: M7d adds no deployment script for the transport on purpose, because
a channel's origins and destinations are a per-network fact and the address of a
real `TeleporterMessenger` is exactly what no offline milestone has.

**P4 is delivered**: M4 (off-chain ZK prover, **V3**, 94,438 constraints, 3.9 s
proving, §5.5), M5 (RMT detector, exact PCG64 reproduction, `q99 = 9.0542` right and
`9.1371` left, §5.6) and M6 (reputation dynamics, 53 tests, F-001 reproduced, the IDE
solver, §5.7) — all three crates build offline, pass `cargo clippy --all-targets
-- -D warnings` and `cargo fmt --check`, and publish a byte-stable report artefact
reproduced by one command each; the sealed tree is untouched (`PASS=11, FAIL=0`).

M4a, M4b, M4c and M4d are delivered
(§5.5.8, §5.5.9, §5.5.10, §5.5.11): the crate under
`src/zk/` measures the inner layer, derives the real key, and decides `D-M4-0` on
both variants through one statement wrapper, and every number
either note quotes is in `src/zk/scripts/{m4a,m4b}_output.txt`, reproduced by one
command each. M4b replaced the M3 placeholder with a real key over V3, proved the
deterministic fixture end to end, and got it accepted by the unmodified
`Groth16Verifier` and `AVIPRegistry.verifyThreshold` — the fixture is a real proof
now, not a solved equation. M4c then built **V2′** and measured it against V3
through that same wrapper, which is what closed `D-M4-0` as **V3** (§5.5.10) — the
variant M4b had already installed, so the decision cost no artefact. M4d then
closed audit **P-01** and **P-16** (§5.5.11): the admission proof is a Poseidon
leaf inclusion over `(validator, norm)`, so it is no longer a bearer token, and
the registry keeps the Poseidon `statementRootOf(epoch)` in a slot separate from
the keccak `commitmentOf(epoch)` that `verifyEntry` folds. **M5 is
delivered too** (§5.6): `src/rmt/` reproduces the sealed RMT calibration
*exactly* — `q99 = 9.0542` right and `9.1371` left, plus both power tables and the
single-draw `W`/`A_sym`/`B` table — by resuming numpy's own PCG64 stream, and it
does so without touching `verification/rmt/`; the crate has **no dependencies**,
its one command is `src/rmt/scripts/m5_report.sh`, and the thresholds it decides
with are checked against the sealed lines by that script and by `cargo test`. What
remains of M4 is the *paper-literal* recursive
construction, which §5.5.7 keeps open; the pipeline is variant-agnostic,
so re-opening the decision is a change to `variant_circuit_for` and a re-run
rather than a new pipeline. M3 closed
the **on-chain** half of A3:
`AVIPRegistry.verifyThreshold` no longer calls a mock, the pairing runs through
precompiles `0x06`/`0x07`/`0x08`, and `Θ_r = 0.5` `[CONJECTURE]` is enforced on a
proof that a validator cannot forge for another statement.

What M3 does **not** close, and must not be read into it (§5.4):

- the circuit and the trusted setup do not exist, so the deployed key would
  currently be the generator's placeholder and `verifyingKeyDigest()` has no
  ceremony to match;
- the fixture is synthetic and carries no soundness claim: it proves the wrapper
  drives the precompiles and rejects correctly, not that a norm is true;
- the Pedersen ↔ Merkle bridge is *decided* (option (c), §5.4) but not
  *implemented*: linking the norm's commitment to the posted Keccak root is the
  data layer's job in M7.

Delivered by P1: `docs/architecture/implementation-plan.md`,
`integrations/avalanche/foundry.toml`, `integrations/avalanche/.gitignore`,
`contracts/README.md`,
`contracts/interfaces/{IAVIPRegistry,IAVIPValidatorManager,IZKThresholdVerifier}.sol`,
`test/README.md`, `scripts/README.md`, `src/README.md`.

Delivered by P2: the B-gap fixes listed in §2.3 — `README.md` (badges B2/B5, `src/`
description B1, layout block), `CITATION.cff` (B4) and
`integrations/avalanche/benchmarks/README.md` (B3, plus the B5 provenance note).

Delivered by M1: `contracts/AVIPRegistry.sol`,
`contracts/interfaces/IAVIPRegistry.sol` (signature + errors + readers),
`test/AVIPRegistry.t.sol`, `contracts/.gitkeep` removed, and the `[lint]` block
in `foundry.toml`. Validated locally: `forge build --offline --force` → *clean
compile with Solc 0.8.33, no warnings*; `forge test --offline` → *30 passed, 0
failed* for the registry suite, with the 10 pre-existing benchmark tests still
passing. No file in the sealed list (§3) was touched.

Delivered by M2: `contracts/AVIPValidatorManager.sol`,
`contracts/interfaces/IAVIPValidatorManager.sol` (signature, events, errors),
`test/AVIPValidatorManager.t.sol`, the shared
`test/mocks/MockThresholdVerifier.sol`, and the §5.2 amendment applied to
`AVIPRegistry.sol` / `IAVIPRegistry.sol` / `AVIPRegistry.t.sol` (§5.3 itemises the
deviations). Validated locally: `forge build --offline --force` → clean with Solc
0.8.33, no warnings; `forge test --offline` → *66 passed, 0 failed* (32 registry +
34 manager); `bash verification/audit-gate.sh` → *PASS=11, FAIL=0*, because
nothing under `integrations/` is sealed.

Delivered by M3: `contracts/verifiers/Bn254.sol`,
`contracts/verifiers/Groth16Verifier.sol`, `test/Bn254.t.sol`,
`test/Groth16Verifier.t.sol`, the generated `test/fixtures/Groth16Fixtures.sol`
plus `scripts/generate_groth16_fixtures.py` and its transcript, and the
`abi.decode` → `Bn254.decodeProof` change in `AVIPRegistry.verifyThreshold` with
its two tests updated (§5.4). Validated locally: `forge build --offline` clean,
`forge fmt --check` clean, no `forge lint` notes; `forge test --offline` →
*100 passed, 0 failed* (32 registry + 34 manager + 16 `Bn254` + 18
`Groth16Verifier`), the last suite including a real pairing and the
registry/manager integration; the measured `verify` cost is 223,445 gas against
the benchmark's inlined-key ≈206k.

Delivered by M4a (§5.5.8): `src/zk/Cargo.toml` + committed `Cargo.lock` with exact
pins, `src/zk/src/{lib,fixture,native,range_proof,report,main}.rs`,
`src/zk/benches/m4a.rs`, `src/zk/scripts/{m4a_report.sh,check-yoloproofs-gate.sh}`
with the measured `src/zk/scripts/m4a_output.txt`, `src/zk/fixtures/tensor_digest.txt`,
`src/zk/tests/field_nativity_probe.rs` and `src/zk/README.md`. Validated locally:
`cargo test` → *13 passed, 0 failed, 1 ignored* (the ignored one is the
32,768-bit aggregated proof, run under `--release`); `cargo clippy --all-targets`
and `cargo fmt --check` clean; `cargo fetch --offline` + `cargo build --offline`
from an empty `target/` (25.7 s), so the crate keeps the offline property M4a's
acceptance requires; `scripts/m4a_report.sh` twice → `m4a_output.txt` byte
identical; `bash verification/audit-gate.sh` → *PASS=11, FAIL=0*, with no
sealed file touched. The one dependency-fetch exception is the §5.5.5 gate
script, which builds a throwaway crate and says so. What M4a did **not** deliver
is V2′ and the `D-M4-0` verdict (§5.5.8).

Delivered by M4b (§5.5.9): `src/zk/src/{groth16,m4b,m4b_fixture}.rs`,
`src/zk/tests/groth16_statement_shape.rs`, `src/zk/scripts/{m4b_report.sh,m4b_fixture.sh}`
with the pinned `src/zk/scripts/m4b_output.txt`, and on the contract side
`integrations/avalanche/test/fixtures/M4bGroth16Fixtures.sol` (emitted by
`src/zk`) plus `integrations/avalanche/test/M4bRealKey.t.sol` (retired by M4d,
§5.5.11). No file under
`integrations/avalanche/contracts/` was edited: the real key and the real proof
are accepted by the contracts exactly as M3 froze them. Validated locally:
`cargo test` → *19 passed, 0 failed, 1 ignored*; `cargo clippy --all-targets -- -D
warnings` and `cargo fmt --check` clean; `forge test` → *107 passed, 0 failed*
(7 of them M4b's) and `forge fmt --check` clean; `scripts/m4b_report.sh` twice →
`m4b_output.txt` byte identical; `scripts/m4a_report.sh` → `m4a_output.txt`
unchanged, which is the M4a acceptance re-run §5.5.6 asks for. The setup is a
**development** setup — one contributor, committed seeds, no security claim
(§5.5.4) — and the measured outer proving time, `3.9 s` against a declared `120 s`
threshold, is what closes the proving-time half of A11 (the Teleporter half still
needs a live subnet, §11). What M4b did **not** deliver is V2′, and therefore the
`D-M4-0` verdict remains open (§5.5.2).

Delivered by M4c (§5.5.10): `src/zk/src/native.rs`'s `v2` module (the seeded
Baby Jubjub parameters, the fixed-base gadget that takes the entries' bits, the
circuit) and the variant switch of `src/zk/src/groth16.rs` (`Variant`,
`variant_circuit_for`, `variant_key_and_proof`, `variant_root`, `measure_variant`,
`render_duel`, `duel_verdict`), with `src/zk/src/{m4b,report}.rs` measuring and
printing both arms. The pinned `src/zk/scripts/m4b_output.txt` gained the
`D-M4-0` duel (35 lines) and `src/zk/scripts/m4a_output.txt` gained V2′'s circuit
and share (5 lines) — both **additions only**, and the V3 section of
`m4b_output.txt` is byte-identical to the file M4b committed, which is the
acceptance re-run §5.5.6 asks for in the form that matters here. Nothing under
`integrations/avalanche/` was edited, because the verdict is V3. Validated locally:
`cargo test` → *29 passed, 0 failed, 1 ignored*; `cargo clippy --all-targets -- -D
warnings` and `cargo fmt --check` clean; `cargo build --offline` from the committed
lock (§5.5.6's offline property, kept through the one new pinned dependency); both
report scripts re-run → their committed outputs byte identical;
`bash verification/audit-gate.sh` → *PASS=11, FAIL=0*. What M4c delivered,
measured rather than argued, is the verdict M4a and M4b could not: **V3**. What it
did **not** deliver is the paper-literal recursive construction (§5.5.7).

Delivered by M4d (§5.5.11): `src/zk/src/admission.rs` (the Poseidon leaf, the
2^9-leaf tree, the in-circuit path and index, the four-word statement),
`src/zk/src/m4d_fixture.rs` and `src/zk/scripts/m4d_fixture.sh`, the pinned
`src/zk/scripts/m4d_output.txt`, and on the contract side
`integrations/avalanche/test/fixtures/M4dGroth16Fixtures.sol`,
`integrations/avalanche/test/M4dRealKey.t.sol` and
`integrations/avalanche/test/M4dRootSeparation.t.sol`. The contracts gained the second
per-epoch root (`statementRootOf`) and the 4-argument `postCommitment` /
`verifyThreshold`; `M4bRealKey.t.sol` was retired while the M4b fixture stayed
for §5.10's bridge tests. Validated locally: `cargo test` → *47 passed, 0 failed,
1 ignored*; `forge test --offline` → *274 passed, 0 failed, 0 skipped* over ten
suites;
`forge fmt --check` clean; `m7d_report.sh` → *62 rows*, `m8_report.sh` → *42
rows*, both byte-stable and guard-clean. The keys remain **development** keys
(§11); what M4d closes is the statement's semantics, not its ceremony.
