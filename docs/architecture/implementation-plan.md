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
2. the **numerical verification suite** (`verification/`, 35 scripts, a
   harness, an audit gate G1–G11 and a tamper-evident anchor),
3. the **EVM gas benchmarks** (`integrations/avalanche/benchmarks/`, Foundry).

The repository did **not** contain the protocol when this plan was written.
`src/reputation/`, `src/rmt/`, `src/zk/`, `integrations/avalanche/contracts/`
and `integrations/avalanche/scripts/` were placeholder directories holding only
a `.gitkeep`, and `avalanche-integration.md` §*Status of the code* said exactly
that: `AVIPRegistry.sol`, `AVIPValidatorManager.sol` and the off-chain prover
were *"specified in this document but not yet implemented"*. Three
implementations now exist — `AVIPRegistry.sol` (milestone M1, §5.1),
`AVIPValidatorManager.sol` (M2, §5.3) and the verifier pair
`contracts/verifiers/{Bn254,Groth16Verifier}.sol` (M3, §5.4) — and the other
gaps keep the status they had.

This plan closes that gap. It does not reopen what is already verified: the
paper's claims, their scripts and their anchor are inputs, not work items.

**Out of scope here** (handled in later phases, see §12): protection of the
document (license, PDF metadata, OpenTimestamps, Zenodo) and any arXiv
submission.

## 2. Current state: what exists and what does not

### 2.1 Exists and is verified

| Artefact | Path | Anchor-sealed |
|----------|------|---------------|
| Paper (11 sections, 34 pp) | `docs/paper/main.tex` | **yes** (pair #1) |
| Numerical suite (35 scripts) | `verification/{stochastics,mechanism,zk,rmt,tensor,data-layer,bootstrap}/` | outputs yes (35 pairs) |
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
| A6 | On-chain reputation dynamics (`C_R`, epoch commitment) | `src/reputation/.gitkeep` |
| A7 | Data layer: event ingestion, transport, fraud proof | architecture §5, §6.3 |
| A8 | Deployment scripts | `scripts/.gitkeep`; architecture §6 |
| A9 | Teleporter / AWM (3 message types) | architecture §4; README roadmap "Pending" |
| A10 | Unit tests for everything above | required by `CONTRIBUTING.md` |
| A11 | Deferred benchmarks (recursive SNARK proving time, Teleporter latency) | paper §9.4; architecture §7 |

Status: **A1, A2 and A3 are closed** by M1, M2 and M3 (§5.1, §5.3, §5.4).
A4–A11 are open. The `Evidence` column records what the gap looked like when this
plan was written, not its current status.

### 2.3 Documental inconsistencies (closed in P2; zero anchor risk)

| # | Inconsistency | Evidence | Resolution |
|---|---------------|----------|------------|
| B1 | README said `src/` holds "reference implementations"; it held only `.gitkeep` | `README.md:49` | README now says the off-chain layers are design notes, links this plan, and the layout block no longer claims "reference code" |
| B2 | README badge required "Python 3.11+"; this machine runs 3.10.12 and the suite passes | `README.md:9` | badge lowered to 3.10+ |
| B3 | `benchmarks/README.md` was `forge init` boilerplate; it did not document the benchmark | 64 generic lines | rewritten: what is measured, how to reproduce it offline, artefact provenance, what is **not** tested |
| B4 | `CITATION.cff` published a GitHub `url` and a release date for a private, unreleased repo | `CITATION.cff` | `url` and `date-released` removed; an `abstract` states there is no release, tag or DOI |
| B5 | The paper cites **solc 0.8.33**; the README badge and one benchmark artefact cite **0.8.24** | `main.tex:1172` vs `benchmarks/results/gas_ingest_output.txt:4` | badge aligned to 0.8.33, which is what both Foundry projects pin; the 0.8.24 artefact is left untouched as evidence and its provenance is documented in `benchmarks/README.md` |

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
| M4 | Off-chain prover | A4, A11 | `src/zk/` (Rust) | Pedersen commit of the 500-entry tensor; Bulletproofs proof (0 R1CS, ~0.72 KB); recursive SNARK; reports local proving time |
| M5 | RMT detector | A5 | `src/rmt/` | Reproduces `q99 = 9.0542` (right tail) and `−λ_min > 9.1371` (left tail) from `verification/rmt/`, without editing it |
| M6 | Reputation dynamics | A6 | `src/reputation/` | `C_R(r)` closed form + epoch commitment; positivity under multiplicative jumps (paper §2) |
| M7 | Data layer, deploy, AWM | A7, A8, A9 | `src/` + `scripts/` + contracts | Fraud-proof equilibrium `n*(B)=⌊B/B*⌋`, `S_slash=10` (Data Layer); `Deploy*.s.sol` to Fuji; 3 AWM message types |
| M8 | Treasury / custody | A2 (deferred half) | contracts + scripts | Token custody and fund movement: escrow of `financialStake`, slashing that retains or burns, collection of `F_0*`; in M2 every one of those is declared, never moved (§5.2.3) |

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
| Tensor, `N` entries | `T ∈ [0,1]^(C×D×H)`, `C·D·H = 500` | `main.tex` `eq:tensor` (L318, L322–324) |
| Object compared to `Θ_r` | the norm `‖T‖_F` | `main.tex` L324 |
| `Θ_r` | `0.5` | `main.tex` L444–445; enforced on chain since M2 |
| WAD convention | `1.0 = 1e18` | M3 fixture statement `[root, epoch, 5e17]` (§5.4) |
| Simulated norm range | `‖T‖_F ∈ [0, 3]` | `main.tex` L831; `threshold_quantization.py` L20, L40 |
| Bulletproofs at `N=500` | `≈6.5e6` gas off-chain, `0.72 KB` | `main.tex` L498, cited by `threshold_quantization.py` L25, L48 |
| Paper's design table | A: 1,080,501 constr. / ~470M gas; A′: 240,261 / ~30M; B: 0 / ~6.5M; proof sizes 0.20 / 0.20 / 0.72 KB | `main.tex` L487–490 |
| Recursive proof cost / proving time | `≈250k` gas; proving time **not measured**, estimated "tens of seconds" | `main.tex` L518, L520 |
| `bulletproofs 5.0.0` deployable surface | `RangeProof`, `LinearProof` (⟨a,b⟩ with **b public**), `range_proof_mpc`; the R1CS API is behind `yoloproofs`, "UNSUITABLE FOR DEPLOYMENT" | crate `README.md` L43–50, L165–167; `src/lib.rs` L47–49 |

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
| **V2** — native adaptation | Pedersen over BN254 G1, recomputed **inside** the circuit | the same circuit: `Σ T_i²`, range folded into the bit decomposition | one Groth16/BN254, no recursion | no: everything native |
| **V3** — Option A′ revisited | Poseidon over the 500 entries, in-circuit | the same circuit: `Σ T_i²` + range | one Groth16/BN254, no recursion | no: everything native |

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
`main.tex`.

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
`k × 0.72 KB`, "una prueba de rango por umbral"). M4a measures the real size of
the aggregated proof of 30,000 bits and marks the paper's figure as the estimate
it is.

#### 5.5.4 Risk 1 — the Ristretto ↔ BN254 mismatch, and how it would be measured

Status after §5.5.5: **off the critical path.** The mismatch exists only in V1,
which §5.5.5 drops, so this measurement no longer gates the build. It is kept
because it is the quantified evidence a P6 amendment needs, and because it is
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
  - **The one API that can express it is declared unfit for deployment.** The
    quadratic relation *is* expressible through `bulletproofs::r1cs`
    (`ConstraintSystem`, `Prover`, `Verifier`, `R1CSProof`; `src/r1cs/`), whose
    documented relation is exactly `a_L ∘ a_R = a_O` plus linear constraints
    over committed high-level variables (`docs/notes-r1cs.md`): allocating the
    variables is what forces both sides to be the *same* `T`. But the crate's
    own README gates it — the API "is provided **FOR EXPERIMENTS ONLY**", "is
    not covered by semver compatibility and is **SUBJECT TO CHANGE WITHOUT
    NOTICE**", and "The `yoloproofs` feature ... is **UNSTABLE AND UNSUITABLE
    FOR DEPLOYMENT**, and **PROVIDED FOR TESTING ONLY**". The gate is in the
    source: `#[cfg(feature = "yoloproofs")] pub mod r1cs;` (`src/lib.rs`
    L47–49). The README adds that the feature "is disabled in the published
    version of the crate, so it can only be used by specifying a git dependency
    on the `develop` branch", which contradicts §5.5.6's reproducibility
    requirement.
  - **The paper's numbers are not the numbers for its own statement.**
    `main.tex` L490 lists `Option B` at `0` R1CS constraints and L510 estimates
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
- The normative result travels to the P6 batch through §9, anchored on the M4a
  note: **Option B as stated specifies no relation that implies the norm, and
  the general-purpose primitive it names cannot express one through a deployable
  API.**

Consequence for the ordering: §5.5.5 no longer needs an experiment. Because V1
goes, **risk 1 is dissolved rather than measured** — the curve mismatch exists
only in V1 — and §5.5.4 becomes the record of what the dropped variant *would*
have cost, i.e. evidence for the P6 amendment instead of a gate on the build.
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
  (§5.5.3), the native commitment + norm circuit (V2/V3), and the `⟨T,T⟩`
  statement written down for V1 with the rejection §5.5.5 records. The
  emulated-field unit bench (§5.5.4) is **optional**: it runs only if V1 is ever
  re-opened, and no bench of the emulated IPA is scheduled;
- a deterministic fixture: one fixed 500-entry tensor from a fixed seed, byte
  identical across runs — the off-chain analogue of
  `scripts/generate_groth16_fixtures.py` (§5.4);
- a note with the measured table: constraints per variant (V2 and V3), key size,
  proving time, proof size, the `c_emu / c_nat` figure §5.5.4 keeps on the record
  for the amendment, and the **D-M4-0 verdict** (V2 vs V3) quoting the
  thresholds declared *before* the runs (§5.5.3, §5.5.4).

Acceptance: `cargo build` and `cargo test` clean, and every number in the note
reproducible by one documented command. The crate builds offline today because
it has no dependencies; each dependency added must keep that property or the
exception must be stated in the note. Non-goals: no ceremony, no production
circuit, no on-chain change, no testnet-latency claim.

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
  `[CONJECTURE]` about Option A′, it enters the P6 batch through §9's re-anchor
  procedure, anchored on the M4a script.
- A production-grade circuit: M4 proves the pipeline and its cost, not a
  deployment.

## 6. Interfaces and parameter provenance

The contract boundary is fixed by three **interfaces** (types only, no logic —
M1 and M2 now implement two of them):

| File | Key surface |
|------|-------------|
| `contracts/interfaces/IAVIPRegistry.sol` | `postCommitment(epoch, root, changedEntries)`, `commitmentOf(epoch)`, `changedEntriesOf(epoch)`, `tensorSize()`, `maxDeltaEntries()`, `latestEpoch()`, `verifyEntry(root, leaf, proof)`, `verifyThreshold(epoch, certifiedNorm, proof)` (view) |
| `contracts/interfaces/IAVIPValidatorManager.sol` | `stakeOf`, `collateralOf`, `requiredStake`, `isAdmitted`, `admit(validator, financialStake, certifiedNorm, proof)`, `slash(validator, amount, reason)`; events `ValidatorAdmitted(validator, stake, collateral)`, `AdmissionEvaluated(validator, epoch, certifiedNorm, collateral, requiredStake)`, `ValidatorEjected(validator, stake, requiredStake)` |
| `contracts/interfaces/IZKThresholdVerifier.sol` | `verify(a, b, c, publicInputs)` (Groth16 shape over BN254) |

They are provisional: a signature change is not a breaking change while nothing
is deployed. M1 changed exactly one signature — `postCommitment` now carries the
declared epoch delta, because the freshness rule of the Data Layer needs it —
and added the readers that rule implies. M2 changes `verifyThreshold` (§5.2):
it becomes `view`, drops the `validator` argument, builds the statement
`[root, epoch, certifiedNorm]` internally, and moves threshold enforcement to
the manager. Every parameter they mention has a provenance:

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
| Groth16 public inputs `k` | `3` (`[root, epoch, certifiedNorm]`) | §5.2.1; fixed by `AVIPRegistry.verifyThreshold` and `Groth16Verifier` (§5.4) |
| pairings per verification | `4` | Groth16: `e(−A,B)·e(α,β)·e(vk_x,γ)·e(C,δ)` (§5.4) |

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
| D-4 | Code license vs paper license | MIT for code (already) and separate license for the paper | Decide in the protection phase |
| D-5 | solc drift | Paper says 0.8.33, badge said 0.8.24, machine has 0.8.33 | **Closed in P2**: badge aligned to 0.8.33, both Foundry projects pin 0.8.33; the one 0.8.24 artefact is documented, not edited |
| D-6 | M4 primitive (`D-M4-0`) | V1 paper-literal (Ristretto + Bulletproofs + recursion) vs V2 native Pedersen in-circuit vs V3 Poseidon in-circuit | **Narrowed in the plan**: V1 leaves the implementation path (§5.5.5 — the `yoloproofs` gate), so `D-M4-0` is now V2 vs V3, measured in M4a by the native constraint count (§5.5.3) |

## 11. Out of scope here

- **Protection of the document**: license, PDF metadata, OpenTimestamps
  renewal, Zenodo deposit. Deliberately last.
- **arXiv submission.** Deliberately last.
- **External security audit.** Not started; required before any mainnet claim.
- **Teleporter latency benchmark** (A11, half): needs a live subnet.
- **Real reputation data calibration** (README "Not a goal"): no data source.

## 12. Phase order and immediate next step

| Phase | Content | Anchor risk |
|-------|---------|-------------|
| **P1 (done)** | This plan + Foundry skeleton + provisional interfaces | none |
| **P2 (done)** | B-gaps: README, `CITATION.cff`, benchmark README, badges aligned with reality (B1–B5) | none |
| **P3 (done — M1, M2, M3)** | M1 ✅ → M2 ✅ → M3 ✅ (on-chain core, §5.4) | none |
| P4 | M4 → M5 → M6 (off-chain) | none |
| P5 | M7 (data layer, deploy scripts, AWM) + M8 (treasury/custody) | none |
| P6 | C-gaps: paper apparatus (C1–C4), one batch | **re-anchor** |
| P7 | Protection + arXiv | **re-anchor** if `main.tex` changes |

**Next step: M4 — the off-chain prover**, planned in §5.5 and not started:
`src/zk/` holds the crate (`99db3fe`) with no dependencies, and the milestone is
gated on the §5.5 review. The structural gap that decides the paper's Option B
is already settled (§5.5.5: V1 dropped), so M4a *measures* what remains — the
native constraint count with the mandatory range proof (§5.5.3), alongside the
Ristretto ↔ BN254 figure §5.5.4 keeps for the amendment; M4b derives the
real key that replaces the M3 placeholder, with **no Solidity change**. What M4
turns into a real proof is the M3 fixture. M3 closed the **on-chain** half of A3:
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
