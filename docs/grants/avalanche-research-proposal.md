# Pricing validator admission on non-transferable reputation — and paying to have it attacked

**Programme:** Avalanche Research Proposals, Area 2 — *Validator Economics and Network Security*
**Request:** $50,000 · **Duration:** 16 weeks · **Status:** ready to submit; the call is closed (2026-10-24)
**Applicant:** Ilich Blanco, Andromeda Computer — `ilichblanco@andromedacomputer.net`
**Repository:** `github.com/ilichb/diamond-framework` · **Preprint:** `10.5281/zenodo.23268373`

---

## 1. Research question

> **Can validator admission be priced on reputation that cannot be bought or
> transferred, so that the cost of a colluding coalition rises with the size it
> needs — and can that price be enforced on-chain without a trusted operator?**

The question is economic in its object and cryptographic in its enforcement. Area 2
asks how validator incentive systems are "structured, measured, and optimised",
and specifically about "non-inflation-based reward mechanisms that support
sustainable long-term outcomes". This proposal answers with a mechanism that
prices admission instead of subsidising it, and — unusually for a proposal — the
mechanism is already written, tested, sealed and deployed, so the money is not
asked for the idea. It is asked for the refutation.

That inversion is the whole design of this application:

> The mechanism has survived its author's attempts to break it, and has been
> corrected 22 times in public when it did not. What it has never survived is a
> stranger's attempt. This grant buys the stranger.

## 2. Why this belongs in Area 2

| What Area 2 asks for | What this work contains |
|---|---|
| How validator incentive systems are **structured** | A stake floor `S_f*` derived from the reputational gap `Θ − C_R(r)`, with `C_R(r) = C_R^∞ · r/(1+r)`, `C_R^∞ = 0.8`, `Θ = 1.0`; a slash that takes the validator's **whole recorded stake** rather than a figure sent with the decision; a re-entry surcharge of `S_f* + n·κ` that makes ejection count. |
| How they are **measured** | A 500-entry tensor `T` (chain × domain × horizon) committed one scalar per validator, `‖T‖_F` as the audit quantity, a certified proof of a validator's **own** entry against `Θ_r`, and a fraud proof with a three-valued verdict. |
| How they are **optimised** | Closed forms for the admission price and the deterrence condition `q(k, ω)`, evaluated by Monte Carlo (`verification/mechanism/m05_attack_model.py`), with the detection-latency `k` bounded by a freshness rule rather than assumed. |
| **Non-inflation-based** reward mechanisms | Admission is *priced*, not *yielded*: nothing in the mechanism pays a validator for existing. The token's role is a bond, and the sink burns what slashing takes. |
| Sustainable long-term outcomes | The design target is a cost of collusion that grows with coalition size, so the equilibrium is "many small validators" rather than "few large ones", without paying either. |

## 3. Methodology

The method is the contribution, and it is already operating. It has three layers,
and the grant strengthens the third.

### 3.1 The mechanism under test

`AVIPRegistry` holds the epoch commitment and the admission policy; `AVIPStakeVault`
holds escrow and applies the whole-recorded-stake slash; `AVIPValidatorManager`
carries the stake floor and the ejection accounting; `AVIPMessageEndpoint` and
`AVIPMessageCodec` move commitments across chains; `AVIPCommitmentRelay`,
`AVIPSlashingChannel`, `AVIPCollusionAlertChannel` and `AVIPBurnSink` close the
loop; `verifiers/Groth16Verifier` is the on-chain proof check. Core: **2,673 lines
across 9 contracts**, plus 1,283 in interfaces and verifiers, 20 files in total.

Two design decisions are load-bearing and were forced by failures, not chosen in
advance:

- **A global-norm proof was removed.** An earlier circuit certified
  `⌊‖T‖_F⌋` over the epoch's 500 entries. A proof of a global norm names no
  validator, so it is a bearer token: whoever holds it is admitted. It is no longer
  admitted by the manager; the global norm survives as the off-chain audit
  quantity and not as an admission input.
- **Authority rotates through a delay.** Roles change by guardian proposal and a
  `CHANGE_DELAY` of 48 h, not by the sitting key. A guardian cannot swap a verifier
  in one block, and the refusal is measured, not asserted: an early
  `executeVerifierChange()` reverts `ChangeNotReady(eta, now)`.

### 3.2 The falsification loop

Every claim in the paper carries a label — Verified, Measured, Estimated, Design,
Deferred — and every falsification is written down, dated, and kept:
`docs/audit/numerical-verification.md` holds **22 entries (F-001 … F-022)**, each a
claim that was made, tested, and corrected. The paper cites them. This is the
project's own record of being wrong, and it is the strongest evidence that the
remaining claims have been examined rather than asserted.

The loop is enforced mechanically, not by discipline:

- `verification/audit-gate.sh` runs **11 guards**, each re-deriving its value with
  the command that checks it (no tecleado figures). Current: **PASS=11 FAIL=0
  SKIP=0**, also in CI on every push.
- `verification/fase0_anchor.sh` derives a SHA-256 root over the research record
  (paper, falsification log, claim registry, gate itself, CI config, count
  manifests) and `--check` re-derives it byte for byte. Root:
  `abe9c553…` (11 pairs). The root is timestamped with OpenTimestamps, so the
  record is witnessed by something the project does not control.

### 3.3 What is already on chain (the feasibility argument)

Feasibility is the criterion most proposals have to promise. Here it is measured.
Fuji, chain 43113, 2026-10-23/24, all three contracts verified on Snowtrace from
this tree:

| Component | Address | Evidence |
|---|---|---|
| `AVIPRegistry` | `0x8DE8C8436D0cc9ED85ea630D5324B8A580EAd69a` | phase-2 deployment, 2-of-3 Safe as `slashAuthority` |
| `AVIPStakeVault` | `0xD560F40BfEd79D8a3b39279fc5Cd8149f71b7e60` | verified, wiring read back by `verify_fuji.sh` |
| `AVIPValidatorManager` | `0x88e60aA2f031B35C823CE4b8994804c025B80317` | verified, stake floor exercised in tests |
| `Groth16Verifier` | `0x125f2054EaCFbd9e34F991cF7A437b3dC95E3eCa` | deployed block 59,962,296, 2,273,291 gas; announced through the delay, `eta` 2026-10-26T17:22:54Z |
| Safe (2-of-3) | `0x673F7725CF17A481299c7073486F8Fb222a66813` | policy reconstructed from the receipt and re-executed by a fork test (468,956 gas) |

The honest boundary, stated in the same breath: the verifier carries a
**development key** — no ceremony has been run — the epoch has not been posted, and
`verifyThreshold` reverts `UnknownEpoch(0)` before it ever reaches the verifier. The
admission path has **not** been exercised on chain. That is precisely what an audit
and the tranche requested below are for, and the paper says so in §10 rather than
in a footnote.

## 4. Expected contributions

**To the literature.** A worked answer to Area 2's question about non-inflationary
security: the cost of a coalition is made to rise with its size by *pricing
admission* on reputation that cannot be transferred, and the price is enforced by a
proof of the validator's own entry rather than by an operator's judgement. The
paper also reports what did **not** work — the bearer-token circuit, the audit
equilibrium's endogeneity, the freshness bound where `γ·k ≥ 1` constrains nothing —
and those negative results are, for a reader, worth more than the positive one.

**To engineering.** A specification precise enough to be audited: 2,673 lines of
core Solidity and **311 tests in 12 suites** with none failing — 310 run offline
(300 unit and fork tests plus 10 stateful-invariant tests, of which 9 invariants
over the escrow each run against 1,536 randomized calls) and `SafeForkTest`
reads the live 2-of-3 Safe on Fuji, skipping when no RPC is configured — and
**line**
coverage of 100% on the registry (114/114), the vault (95/95) and the manager
(61/61), with branch coverage of 96.43% (27/28), 95.45% (21/22) and 100% (17/17)
respectively; 93.55% lines and 61.54% branches on the endpoint, 95.24% lines and
80.00% branches on the BN254 wrapper. The branch column is quoted because it is
the honest one: the transport's failure paths are the least exercised code in
the repository and the first thing an auditor should open. Coverage is not
security, and this proposal does not pretend otherwise — it is the floor that
makes a two-week audit meaningful rather than exploratory.

**To Avalanche.** A validator-admission design that a Subnet can adopt without
paying emissions for security, with the enforcement already portable to an L1, and
a public audit trail of what was claimed, measured and refuted.

## 5. What the grant funds — and what it does not

It funds **validation of finished work**, in this order:

1. **External security audit** of the nine core contracts, by a firm from the
   Foundation's list, read-only on the deployed addresses plus the source at the
   audited commit. Scope in `reviewer-checklist.md`.
2. **Remediation and re-audit of the diff.** Findings fixed in public, then
   re-reviewed. A first audit without a re-audit buys a report, not a fix.
3. **A trusted-setup ceremony** to replace the development key, run with ≥3
   independent participants and a published transcript, so the verifier stops
   being a demonstration.
4. **A fuzzing and invariant campaign** (Echidna/Medusa) on the three stateful
   contracts, wired into CI, with the invariants published as properties.
5. **The closure report**: what the audit found, what was fixed, what remains
   open, appended to the falsification log as F-023 onward.

It does **not** fund: mainnet deployment, a token, liquidity, marketing, salaries,
or any promise of adoption. There is no token, and the mechanism is designed so
that it does not need one.

## 6. Timeline (16 weeks)

| Weeks | Work | Output |
|---|---|---|
| 1–2 | Freeze the audited commit, write the audit brief, hand over addresses and threat model | audit brief, commit hash |
| 3–7 | External audit, weekly triage calls | interim findings |
| 8–10 | Remediation, tests for every finding, gate re-run | patched commit, new tests |
| 11–12 | Re-audit of the diff | final report |
| 13–14 | Trusted-setup ceremony, 3 participants | transcript, new verifier address |
| 15 | Fuzzing campaign, invariants in CI | property suite |
| 16 | Closure report, anchor re-seal, public write-up | report, new anchor root, tag |

Every stage ends in something a reviewer can open, and the anchor is re-sealed at
the end so the tranche leaves a timestamped trail like the one before it.


## 7. Budget justification

$50,000, sixteen weeks, five lines. Full detail in `budget.md`; the logic here.

| Line | Amount | Why this and not less |
|---|---|---|
| External audit, nine core contracts | $32,000 | 2,673 lines of core Solidity with a ZK check, a vault, cross-chain codec and a slashing path. A two-week review at a reputable firm's rate does not cover it; four to five auditor-weeks does. |
| Re-audit of the remediation diff | $7,000 | The finding that matters is the one fixed after the report. Without this line the audit produces a PDF that ages. |
| Trusted-setup ceremony | $4,500 | Three independent participants, coordination, transcript publication and on-chain verifier replacement. The development key is the single largest gap between this and a real system. |
| Fuzzing and invariants (Echidna/Medusa), CI | $4,000 | Property-based coverage of the vault and registry, permanently in CI. |
| Closure report, anchor re-seal, dissemination | $2,500 | The write-up, the falsification entries F-023+, and the re-sealed root. |

Rates are estimates for a mid-tier firm and are the part of this proposal most
open to being wrong; `budget.md` §2 shows the arithmetic and the fallback if the
quotes come in higher.

**No line pays for work already done.** The paper, the 311 tests, the Fuji
deployment, the gate and the anchor were produced without funding.

## 8. Researcher qualifications

Ilich Blanco (Andromeda Computer), sole author of the preprint and of every commit
in the repository — 250 commits, a public history in which the corrections are as
visible as the claims. Relevant, verifiable facts rather than a narrative:

- The paper is deposit-ready and citable (`10.5281/zenodo.23268373`), 43 pages,
  every section closing with a labelled summary table.
- The implementation is deployed on Fuji and verified on Snowtrace from this tree.
- The project has documented 22 of its own falsifications, and the gate that
  enforces consistency is itself under the anchor, so the author cannot quietly
  relax it.
- Full CV supplied with the submission form.

What the qualifications do **not** include is an audit history or a co-author with
one. That is the gap this grant closes, and pretending otherwise would be the
first thing a reviewer catches.

## 9. Risks, and what would make this fail

| Risk | Consequence | Mitigation |
|---|---|---|
| Quotes exceed $32k | Audit scope shrinks to registry + vault + manager, the three that hold funds and policy | `budget.md` §2 fallback, decided before signing |
| Audit finds a soundness bug in the ZK admission path | The central claim weakens; the paper must be corrected | That is a **success** of the grant, and the falsification log is built to absorb it |
| Ceremony participants unavailable | Verifier stays on the development key | Ceremony can slip without blocking the audit; it is the last deliverable |
| Scope creep into mainnet | Budget consumed by deployment work | Mainnet is explicitly out of scope; the proposal funds refutation, not launch |
| Reviewer reads "deployed on Fuji" as "production" | Overstated maturity | Every document in this repository says *testnet, unaudited, development key* in the same paragraph as the addresses |

## 10. Deliverables

1. Audit report, published in full, including the findings that were not fixed.
2. Patched commit, with a regression test per finding and the gate green.
3. Trusted-setup transcript and a verifier address without the development key.
4. Invariant suite in CI.
5. Closure report appended to `docs/audit/`, and a re-sealed anchor root with a
   timestamped receipt — the same mechanism used for every claim so far.
6. A short public write-up of what broke, addressed to the validator-economics
   audience the call names.

## 11. Why fund this one

Most proposals ask for money to find out whether an idea works. This one asks for
money to find out whether a working thing is **sound**, from someone other than
its author, and commits in advance to publishing the answer either way. The
mechanism is on a testnet, the record is timestamped, the failures are already
written down, and the only party who has not yet tried to break it is the one the
grant pays for.

If the audit finds nothing, Avalanche gets a validator-admission design it can
point to with a report behind it. If the audit finds something, the record shows a
project that published its own refutation — which is the behaviour the ecosystem
says it wants and rarely gets to fund.

---

*Supporting material: `evidence-appendix.md` (addresses, hashes, coverage),
`reviewer-checklist.md` (criterion → command), `budget.md` (arithmetic). Not part
of the ten pages.*

