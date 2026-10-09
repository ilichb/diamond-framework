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
were *"specified in this document but not yet implemented"*. The first
implementation now exists — `AVIPRegistry.sol` (milestone M1, §5) — and every
other gap keeps the status it had.

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
| A4 | Off-chain prover (Pedersen + Bulletproofs + recursive SNARK) | `src/zk/.gitkeep`; architecture §6.2 |
| A5 | Production RMT detector | `src/rmt/.gitkeep`; today only `verification/rmt/` simulations |
| A6 | On-chain reputation dynamics (`C_R`, epoch commitment) | `src/reputation/.gitkeep` |
| A7 | Data layer: event ingestion, transport, fraud proof | architecture §5, §6.3 |
| A8 | Deployment scripts | `scripts/.gitkeep`; architecture §6 |
| A9 | Teleporter / AWM (3 message types) | architecture §4; README roadmap "Pending" |
| A10 | Unit tests for everything above | required by `CONTRIBUTING.md` |
| A11 | Deferred benchmarks (recursive SNARK proving time, Teleporter latency) | paper §9.4; architecture §7 |

Status: **A1 is closed** by M1 (§5). A2–A11 are open.

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
| M3 | ZK verifier | A3 | `contracts/verifiers/Groth16Verifier.sol` | Groth16 k=4 over BN254 via 0x06/0x07/0x08; gas ≈ 206k (cross-check `GasBenchmarks.sol`) |
| M4 | Off-chain prover | A4, A11 | `src/zk/` (Rust) | Pedersen commit of the 500-entry tensor; Bulletproofs proof (0 R1CS, ~0.72 KB); recursive SNARK; reports local proving time |
| M5 | RMT detector | A5 | `src/rmt/` | Reproduces `q99 = 9.0542` (right tail) and `−λ_min > 9.1371` (left tail) from `verification/rmt/`, without editing it |
| M6 | Reputation dynamics | A6 | `src/reputation/` | `C_R(r)` closed form + epoch commitment; positivity under multiplicative jumps (paper §2) |
| M7 | Data layer, deploy, AWM | A7, A8, A9 | `src/` + `scripts/` + contracts | Fraud-proof equilibrium `n*(B)=⌊B/B*⌋`, `S_slash=10` (Data Layer); `Deploy*.s.sol` to Fuji; 3 AWM message types |

Ordering rationale: M1 → M2 → M3 are on-chain and unblock each other; M4 and M5
are the heavy off-chain work; M6 and M7 close the loop. A10 (tests) is not a
separate milestone: it is a gate on every milestone. A11 is split:
the recursive SNARK proving time is delivered by M4; the Teleporter latency
stays deferred until a live testnet exists.

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
  `IZKThresholdVerifier`, but that verifier does not exist yet: the tests use a
  mock, so no claim is made about the pairing check or the recursive SNARK (M3).
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
and the pairing fails. In M2 the verifier is a mock, so no soundness claim is
made until M3.

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
- **Custody.** M2 exposes the `F0*`/`S_f*` policy. It does not implement token
  custody or transfer (ERC-20 or native); that is delegated to a future treasury
  module.

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
  validator set, weight) to M4/M7.
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
5. **The proof blob is `(a, b, c)`** and trailing bytes are ignored by ABI
   decoding (§5.2.4, last bullet): asserted as a property, not assumed.

Validated locally: `forge build --offline --force` → clean with Solc 0.8.33, no
warnings, no `forge lint` notes; `forge test --offline` → **66 passed** (32
registry + 34 manager, two of them fuzz — the admission invariant and the policy);
`bash verification/audit-gate.sh` → `PASS=11 FAIL=0`, i.e. the anchor is
untouched, as expected since nothing under `integrations/` is sealed (§3).

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
| **P3 (in progress — M1, M2 done)** | M1 ✅ → M2 ✅ → M3 (on-chain core) | none |
| P4 | M4 → M5 → M6 (off-chain) | none |
| P5 | M7 (data layer, deploy scripts, AWM) | none |
| P6 | C-gaps: paper apparatus (C1–C4), one batch | **re-anchor** |
| P7 | Protection + arXiv | **re-anchor** if `main.tex` changes |

**Next step: M3 — `contracts/verifiers/Groth16Verifier.sol`** (Groth16 k=4 over
BN254 through precompiles `0x06`/`0x07`/`0x08`, gas ≈ 206k cross-checked against
`benchmarks/GasBenchmarks.sol`), so that `AVIPRegistry.verifyThreshold` stops
calling a mock and `Θ_r = 0.5` `[CONJECTURE]` acquires a real circuit and trusted
setup.

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
