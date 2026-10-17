# External Review Triage — 2026-10

## What this file is

A second round of external review arrived with a list of claimed defects
in `docs/paper/main.tex` (part A), in `integrations/avalanche/` (part B),
as three measurement proposals (part C), and as three release-process
items (part D).

This file records the disposition of every item **against the live
repository**, using the same method as `content-audit-pending.md`:

1. **Model** the discrepancy explicitly.
2. **Verify** against the committed text, the committed output, and (where
   possible) a run of the script that backs the number.
3. **Record** the outcome: confirmed, partially confirmed, refuted, or
   needs-measurement.
4. **Propose** the correction only after the outcome is recorded.

It is not a paper artifact and it is **not part of the anchor**. It is a
worksheet. The three files under `docs/audit/` that *are* sealed by
`verification/anchor_root.sha256` (`claim-registry.csv`,
`numerical-verification.md`, `content-audit-pending.md`) are **not**
modified by this review.

### Status legend

- **Confirmed** — reproduced the discrepancy; the text is wrong as written
  and needs an edit.
- **Partially confirmed** — one component holds, another does not; or the
  defect is in presentation while the underlying conclusion survives.
- **Refuted** — reproduced against the committed text and the discrepancy
  is not real. Usually because the point was already closed by a C-xx
  finding and the reviewer read an earlier state.
- **Needs measurement** — a legitimate methodological challenge with no
  demonstrated error. Per §9 of `implementation-plan.md`, a new number
  requires a script *before* it may reach `main.tex`.

### Anchor state at the time of this triage (verified, not assumed)

`sha256sum docs/paper/main.tex` returns
`fb5cae97ba5bc96114e155e0c81e70ada2c3ca5cdea06011a6f0199ab378bde8`,
byte-identical to line 1 of `verification/anchor_root.sha256`.
`bash verification/fase0_anchor.sh --check` reports all five links of the
chain identical (35 output pairs, `audit_manifest.sha256`, HEAD ancestry,
`anchor_root.sha256`, 10 pairs).

**Consequence for everything below.** The sealed tree is consistent. There
is no pre-existing divergence between the paper and its seal, so any edit
in part A is a *new* change requiring the full re-anchoring pipeline
(§9 of `implementation-plan.md`), and must be applied as a single batch.

`git status --porcelain` reports one pre-existing modification:
` M .zenodo.json`. Not touched by this review.

### Section map of `main.tex` (verified with `grep -n '^\\section{\\|^\\subsection{'`)

The external review, and the plan derived from it, cite section numbers that do
not always match the paper's own numbering. The authoritative map, line
numbers included, so a citation can be checked before it is written:

| § | Title (line) | § | Title (line) |
|---|---|---|---|
| 1 | Introduction (49) | 7 | Data Layer (953) |
| 2 | Reputation Dynamics (117) | 7.3 | The Fraud Proof Mechanism (975) |
| 3 | Tensor Compression (320) | 7.4 | Numerical Verification (1001) |
| 3.1 | Tensor Representation (323) | 7.5 | Slashing and Integrity (1027) |
| 3.3 | Reconstruction Error (354) | 8 | Bootstrap Dynamics (1064) |
| 4 | Zero-Knowledge Threshold Proof (446) | 8.1 | The Genesis Problem (1067) |
| 4.2 | Soundness Failure (465) | 8.2 | Reputation Models (1072) |
| 4.3 | Repair Options (486) | 8.3 | Bootstrap Simulation (1108) |
| 4.4 | Recursive Verification (542) | 8.5 | Comparison of Policies (1150) |
| 4.6 | Estimates and Their Provenance (562) | 8.6 | Recommendation (1157) |
| 5 | Collusion Detection (597) | 9 | Evaluation (1187) |
| 5.4 | Null Distribution and Calibration (689) | 9.4 | Stability of Conclusions (1259) |
| 5.5 | Detection Power (730) | 10 | Limitations (1306) |
| 5.6 | The Detection Boundary (762) | 10.2 | Adversary Model (1314) |
| 5.7 | Limitations (771) | 10.3 | Collusion Detection Boundary (1325) |
| 6 | Payment Rule (806) | 10.8 | What the Protocol Does Not Claim (1372) |
| 6.4 | The Uniform Posted Price (853) | 11 | Conclusion (1411) |
| 6.5 | Individual Rationality (879) | 12 | Reproduction Protocol (1490) |

Two conventions worth fixing in any plan: `F_0^*` and the `‖T‖_F ~ U[0,3]`
sweep live in **§6.5**, not §5.5; and the bootstrap (genesis, policies,
`R = 0`) lives in **§8**, not §7. The implementation plan's `§5.x` labels are
a *different* namespace (module ids M1…M8), not paper sections.


### Version diagnosis of the reviewed copy (executed 2026-10-13)

The second review asked, correctly, for three commands to settle which of the
two documents is stale. They were run against the anchored tree. **The
anchored paper is the one triaged; the reviewer's copy is the stale one, and
the divergence is now pinned to a commit.**

```
$ sha256sum docs/paper/main.tex
fb5cae97ba5bc96114e155e0c81e70ada2c3ca5cdea06011a6f0199ab378bde8  docs/paper/main.tex
$ head -1 verification/anchor_root.sha256
fb5cae97ba5bc96114e155e0c81e70ada2c3ca5cdea06011a6f0199ab378bde8  docs/paper/main.tex
$ git log -1 --format='%h %ad %s' -- docs/paper/main.tex
6440ac5 Sun Oct 11 23:36:59 2026 -0400 P7a: the PDF gets the metadata it never had, and the re-anchor that costs
```

`grep -n 'c_{\mathrm{audit}}'` returns five hits; the contested one is the
revenue equation at `:981`, which in the anchored text reads

```
\mathbb{E}[\text{revenue}] = \frac{p_{\mathrm{fraud}} \cdot N_{\mathrm{ATT}} \cdot B}{n_{\mathrm{auditors}}} - N_{\mathrm{ATT}} \cdot c_{\mathrm{audit}}
```

`N_ATT` is present in **both** terms. `git show 094c41b -- docs/paper/main.tex`
prints the hunk that put it there, in P6a:

```
-\mathbb{E}[\text{revenue}] = \frac{p_{\mathrm{fraud}} \cdot N_{\mathrm{ATT}} \cdot B}{n_{\mathrm{auditors}}} - c_{\mathrm{audit}}
+\mathbb{E}[\text{revenue}] = \frac{p_{\mathrm{fraud}} \cdot N_{\mathrm{ATT}} \cdot B}{n_{\mathrm{auditors}}} - N_{\mathrm{ATT}} \cdot c_{\mathrm{audit}}
```

So the reviewer's `A-4` was **true of the text they read** and is false of the
anchored text. Likewise P6a relabelled the `−502` rows of §7.4/§7.7 from
`Verified` to `Analytical`, and P6b (`3955d91`) added the "model bookkeeping,
not executable losses … bounded by `Θ = 1.0`" disclosure at `:1266`. The
reviewed copy therefore predates P6a — the hypothesis this triage recorded in
its own summary, now verified. The two disputed items are **already closed**,
which is not the same thing as refuted.

| Commit | Batch | What it did to the two contested items |
|---|---|---|
| `ac696c2` | C-38 | first use of `sec:limitations` in the paper |
| `094c41b` | P6a | added `− N_ATT · c_audit` to the revenue equation; `−502` rows `Verified → Analytical`; the q = 1 step-coverage sentence (`:999`); the §10 referral (`:1030`) |
| `3955d91` | P6b | "not executable losses" + `Θ`-bound disclosure (`:1266`); "escrowed loss" wording (`:1028`) |
| `6440ac5` | P7a | PDF metadata; last commit touching `main.tex` |

## Part A — paper content (22 items)

### Refuted, or already closed — the distinction matters

Two dispositions share this table, and the second review was right to insist
they not be conflated:

- **Refuted** — the claim is wrong as arithmetic or as a reading of the
  committed text (A-2, A-12, A-14, A-16a).
- **Already closed** — the claim was **correct against the revision the
  reviewer read**, and the anchored text no longer exhibits the defect because
  a later sealed batch fixed it (A-3, A-4). A closure is not a refutation: the
  finding was real, it is simply no longer live.

Each row was checked against the committed `main.tex` at the hash above.

| # | Claim | Disposition | Evidence |
|---|---|---|---|
| A-2 | `C_R` is written backwards; `0.8r/(1+r)` and `0.8R/(1+R)` must be reconciled | **Refuted.** The reviewer's substitution is correct (`R = r/(1+r)` ⇒ `0.8r/(1+2r)`), but the paper *already* declares them as two different objects: §8.2 states that `C̃_R(R)` **replaces** `C_R(r)` once the bootstrap switches the state variable to `R`. The algebraic identity and the closed form are reconciled numerically by `verification/stochastics/cr_ide_solver.py` (C-24, Cerrado). C-13 is Cerrado. | `main.tex` §8 bootstrap; C-13, C-24 in `content-audit-pending.md` |
| A-3 | `−502` is unreachable under the cap `≤ Θ = 1.0`; `50 − 10·50 = −450 ≠ −502` | **Valid against the revision reviewed; already closed in the anchored text.** The reviewer's copy predates P6a: the summary-table row read `Verified` until P6a (`094c41b`) relabelled it `Analytical`, and the disclosure that the figures are "model bookkeeping, not executable losses", bounded by the escrowed stake `0.2 → 1.0` of §6, entered in P6b (`3955d91`). On the arithmetic: C-07 decomposes it as `52 = 50 + 2`; the `−450` is the convention that was *deliberately rejected* (`simulate_data_layer_v3.py` counts detected frauds as reverted, not as rewarded). **Residual, editorial only:** `−502.00` still sits in the §7.4 table (`:1014`–`:1018`) and is restated in §9.4 (`:1266`); *removing* it rather than labelling it is a presentation choice, not a defect fix, and costs a re-anchor. | `anchored main.tex` §7.4 table (`:1014`), §7.7 (`:1055`), §9.4 (`:1266`), §7.5 (`:1028`); P6a `094c41b`, P6b `3955d91`; C-07; `verification/data-layer/simulate_data_layer_v3.py` |
| A-4 | `N_ATT` is missing from the revenue equation | **Valid against the revision reviewed; closed by P6a.** The pre-P6a equation did omit `N_ATT` from the cost term; `git show 094c41b` prints the exact hunk that added it (`− c_{\mathrm{audit}}` → `− N_{\mathrm{ATT}} \cdot c_{\mathrm{audit}}`). The anchored equation carries `N_ATT` in **both** terms and `simulate_data_layer_v3.py` agrees term by term. Settled by the version diagnosis above, not by reading alone. | anchored `main.tex` `:981` (revenue equation, §7.3); P6a `094c41b`; `verification/data-layer/simulate_data_layer_v3.py` |
| A-12 | §5.7 calls the detection boundary a `[CONJECTURE]` while §10.3 says "was not located"; unify them | **Refuted: they already agree.** §5.6 states the boundary lies *below* the tested range and marks it `[CONJECTURE]`; §5.5 reports that all five configurations have TPR above 0.97, which is exactly what the table says; §10.3 says the boundary "was not located" and calls its location "an open question". Three consistent statements of the same thing. | `main.tex`:764, :767, :1328, :1330, :1399, :1447 |
| A-14 | The `29.2×` ratio is a straw man measured against chance | **Refuted.** The comparison is `A_sym` vs the modularity matrix `B` **on the same configuration** (`k=1`, `m=20`, `n=500`, `d̄=20`): `A_sym` gives TPR 0.033 over `N_H1 = 30` replicates, `B` gives 0.972 over `N_H1 = 500`. Both Wilson 95% intervals are reported (`[0.006, 0.167]` and `[0.954, 0.983]`). That `0.033 ≈ 1/30` is the reason the *point estimate* is fragile, which is why the paper prints the intervals; it is not a refutation. | `main.tex`:758, :760, :797; F-002 |
| A-16a | The identical Gini / Top-10 columns prove the metric carries no information about concentration | **Refuted.** The paper explains the identity: both policies track the same reputation trajectory `R(t)`, and Gini/Top-10 are computed on the distribution of `R`, not of `S_f`. The comparison that does carry content is `hybrid_decay` (0.1563) vs `hybrid_no_decay` (0.1283), and it is flagged in the falsification log. The paper does not use the identical pair as evidence for the stake policy. | `main.tex` §8 bootstrap; F-015 |

### Confirmed — real defects requiring an edit to `main.tex`

These are the items that must be fixed before arXiv v1. All are text-level;
none invalidates a numerical result.

#### A-1 — The four tensor types in the Tucker table violate the declared domain of `T`

**Location:** §3.1 (`T ∈ [0,1]^{C×D×H}`, line 323) vs the §3.3 table.
**Disposition: Confirmed.**
**Severity:** Presentation, but a reviewer will catch it immediately.

§3.1 declares the reputation tensor as `T ∈ [0,1]^{C × D × H}` with
`C·D·H = 500` entries and states that *this* is the object whose norm is
compared against `Θ_r`. A tensor in that domain satisfies
`‖T‖_F ≤ √500 = 22.3607`. The §3.3 table then reports
`‖T‖_F = 73.068` (clean low-rank) and `45.261` (low-rank + noise) for two
of its four tensor types, and never says that those four types are
*unbounded synthetic test tensors* rather than instances of `T`. The
script says so; the paper does not. The reviewer's arithmetic
(`√500 ≈ 22.4`) is correct, and their reading is the natural one.

**Action.** State the construction and scale of the four synthetic tensors
in the caption or surrounding text, and say explicitly that they are test
inputs, not elements of the declared domain of `T`. Optionally add that
the §6.5 choice `‖T‖_F ~ U[0,3]` is a modelling choice *inside* a domain
that extends to 22.36, so the utility analysis lives in the low-norm
corner; `Θ_r = 0.5` and `C_R ∈ [0, 0.6]` should be read in that light.

Note: `verification/mechanism/frobenius_counterexample.py` investigates a
*different* property of the norm (that `‖T1‖_F = ‖T2‖_F` for a diversified
and a concentrated tensor — the motivation for Rule 3 and for the
log-aggregator `C_R`). It is not evidence for or against this item, but it
belongs in the same discussion.

#### A-6 — The abstract overclaims the ZK component as "verified numerically"

**Location:** abstract ("The protocol is verified numerically for … the
zero-knowledge threshold proof …") and the Conclusion ("seven components,
**each verified numerically** in this paper").
**Disposition: Confirmed.**
**Severity:** Presentation, credibility-relevant.

§4 is where the paper reports that the *original* circuit specification is
unsound — a verified finding — and then adopts a new design whose
recursive composition is labelled `Estimate` / `Design` in the paper's own
summary tables, with two benchmarks explicitly deferred. So "the
zero-knowledge threshold proof [is verified numerically]" is unsupported by
§4's own status labels, and "each verified numerically" is contradicted by
them.

The Abstract and Conclusion item 3 are otherwise **accurate** (the
unsoundness is verified; the EIP-196/197 precompile costs are measured),
and Table 15 / §10's limitation table are accurate as written.

**Action.** Reword the two abstract-level sentences to claim the
*soundness failure* and the *measured precompile costs* as verified, and
the recursive repair as designed and costed, not verified.

#### A-7 — "Pairs every quantitative claim with a reproducible script" is contradicted by the paper's own tables

**Location:** abstract contributions list.
**Disposition: Confirmed.**
**Severity:** Presentation.

The paper's own summary tables contain rows whose status is `Estimate`
(e.g. the recursive SNARK at ~250k gas) and `Design` with `---` in the
Script column (e.g. "recursion required for on-chain viability", "detection
boundary below tested range"). A contribution claim that *every*
quantitative claim is paired with a script is therefore false on the
paper's own pages.

**Action.** "… a numerical verification suite that pairs every
quantitative claim with a reproducible script, **and labels the estimates
and the design choices as such**."

#### A-9 — The 1,080,501 constraint count is a naive over-count presented as "the circuit requires"

**Location:** §4.3, Option A paragraph; derivation in
`verification/zk/soundness_zk_check.py`.
**Disposition: Partially confirmed — presentation confirmed, conclusion
refuted.**
**Severity:** Presentation. Highest-value correction in part A.

The script computes the Option A count as `N · log₂N · 240 = 500 × 9 × 240
= 1,080,000`, i.e. it charges a full Poseidon hash per (leaf, level) pair.
That double-counts: an honest Poseidon Merkle tree over `N` leaves has
`2N − 1` hashes, so the count is `(2N − 1) · 240 = 239,760`. That is what
the paper's own Option A′ row reports as **240,261**, and the paper already
says that at 240,261 constraints the circuit is "still too large for
practical Groth16 proving on consumer hardware".

The reviewer is right about the derivation and wrong about the conclusion.
Option A is rejected either way, and the rejection that survives does so on
the **gas** axis, not the constraint-count axis: Option A′ costs ~30M gas
to verify directly against ~206k for the small Groth16 circuit and ~250k
for the recursive proof. That comparison is in `tab:design-gas` and is not
addressed by the reviewer.

**Action.** Give the derivation of *both* counts explicitly in §4.3 (the
naive `N log N` opening and the `2N − 1` tree), stop presenting the naive
count as what "the circuit requires", and cross-reference the Option A′
row. Do **not** change the rejection.

#### A-11 — Pedersen (Option B) cannot back per-entry fraud proofs, and the paper never says what the data layer publishes

**Location:** §4.3 (repair options) vs §7.3 (per-entry fraud proofs).
**Disposition: Confirmed — and the repository already contains the answer.**
**Severity:** Structural in presentation.

§4.3 discusses Merkle/Poseidon (Options A, A′) and Pedersen (Option B) as
commitments for the *ZK statement*, and adopts Option B.
§7.3 requires *per-entry* fraud proofs, which a Pedersen commitment over a
flattened tensor cannot provide. The paper never states which commitment
the data layer publishes, leaving a real structural incompatibility.

The integration layer already resolves it: the keccak/Merkle root over the
data layer's fold is canonical, and the ZK statement's root is tied to it
by `bridge::link_digest`. The paper simply does not say so.

**Action.** Add a short paragraph in §7.3 (or §4.6) stating which
commitment the data layer publishes for per-entry fraud proofs, and how it
relates to the commitment used by the ZK statement. This closes a
structural objection using work that is already done, at bookkeeping cost.

#### A-15 — The collusion statistic is global, and the paper never says it

**Location:** §5.6/§5.7 and §10.3.
**Disposition: Confirmed.**
**Severity:** Conceptual gap in a declared boundary.

`λ_max(B)` is a statistic of the whole graph. It flags that *an epoch's*
collaboration graph shows community structure; it does not identify which
validators form the community, and the paper never connects the flag to the
tensor data, to admission, or to slashing. The paper is careful about the
*power* of the test (the boundary is unlocated; the sub-boundary regime
relies on economic deterrence) but silent on the *identification*
limitation.

**Action.** One paragraph declaring that the test is global — it flags the
epoch/graph, not the members — and stating whether identification is in
scope. The delivered integration layer already emits an alert for the epoch
and a slashing notification carrying a derived reason, which can be cited
as the operational counterpart.

#### A-18 — The deterrence condition is never stated, and the executable loss can be zero

**Location:** §7.5 (`:1028`–`:1030`), §9.4 (`:1266`), §10.2 (`:1314`–`:1321`).
**Disposition: Confirmed — a real gap. New in this round; it supersedes the
reviewer's own earlier A-3 argument.**
**Severity:** Conceptual. The one item where the reviewer's *second*
formulation is stronger than their first.

The paper states its detection convention explicitly and correctly at
`:999`–`:1000` (added by P6a):

> Detection in this model is a step and not a probability: an auditor reviews
> every attestation of the epoch, so coverage is `1` whenever
> `n_auditors ≥ 1` and `0` otherwise.

So the model assumes `q = 1` by construction, and *a fortiori* never writes
the condition under which a probabilistic detector would deter:

    q > G / (G + L)

with `G` the gain if undetected and `L` the loss if detected. This is the
correct condition for a risk-neutral attacker: `E = (1−q)·G − q·L < 0`.
With the paper's own reference parameters,
`G = V_fraud · N_ATT · p_fraud = 1.0 × 500 × 0.10 = 50` and
`L ≤ Θ = 1.0`, deterrence requires `q > 50/51 ≈ 0.980`. The step model
satisfies it trivially at `q = 1` — but the margin is under two percent, and
the paper never says so, nor that the margin is what the step convention is
buying.

The second half is sharper and is **nowhere in §10**. §10.2 does contain
adjacent material — `:1317` already says that slashing deters "only if the
adversary prefers profit to loss" (a statement about *risk preference*, not
about `q`), and `:1321` already flags the free-riding dilution of the bounty
pool, which the step convention makes *worse* (coverage needs one auditor, so
the rest can wait for it). What is absent from both is the quantity itself:
the loss is realized only if the escrowed stake is *still posted when the
fraud is adjudicated*. Any exit path that settles before the challenge window
closes drives `L → 0`, and then **no** `q` deters — the detection probability
becomes irrelevant because there is nothing left to take. `main.tex` contains
no exit queue, unbonding delay or withdrawal cooldown anywhere: `grep -n -i
'escrow|exit queue|withdraw|unbond|cooldown'` returns only `:1028`, `:1030`
and `:1266`, all three inside the data layer's own discussion. The assumption
is therefore implicit and load-bearing. This is the same concrete gap that
**B-4** records from the other side, seen from the economics rather than from
the cross-reference.

**Action — two sentences, and no new number if phrased as a derivation.**
(i) In §7.5, state the deterrence condition and note that step coverage
satisfies it at the price of a narrow margin. (ii) In §10.2, state that the
loss is conditional on the escrow still being posted at adjudication, which
in turn requires an exit queue — this discharges the dangling referral of
B-4 at the same time.
**Gate consequence (D-4).** If (i) is written as a *derivation* from the
existing `G` and `Θ`, no new `F-`/`C-` entry is needed and G5/G6 are
untouched. If it is recorded as a new claim in a sealed table, it costs the
three-sealed-file batch of D-4 and must ride in the same re-anchor.

#### A-19 — The boundary is named "Kesten–Stigum" in three places, but KS is not the governing threshold for the object tested

**Location:** `:82` (contributions), `:1328` (§10.3), `:1377` (conclusions) —
against `:767` (§5.6).
**Disposition: Confirmed — a mis-attribution. New in this round.**
**Severity:** Precision of a citation; the paper names the wrong theorem for
its own boundary.

The paper does not consistently hedge this. §5.6 (`:767`) is careful:

> The detection boundary for the modularity-spectrum test with `s[-1]` on the
> degree-corrected stochastic block model lies below the configurations tested
> here `[CONJECTURE]`. … A derivation of the boundary from the **Kesten–Stigum
> threshold or from the random matrix literature** would be a separate
> contribution.

But §10.3 (`:1328`) then asserts it flatly — "the theoretical Kesten–Stigum
threshold for the degree-corrected SBM with the reference parameters
(`n = 500`, `d̄ = 20`) is below the tested range" — and `:82` and `:1377`
speak of "the Kesten–Stigum boundary" with no qualifier at all.

The object actually tested is a **single planted clique of `m = 20`** in a
sparse Erdős–Rényi background (`n = 500`, `d̄ = 20`), i.e. a *sublinear*
community (4% of `n`). Kesten–Stigum characterizes detectability for
communities of *linear* size; for a small planted clique in a sparse
background the governing result is the spiked-Wigner / BBP threshold, as the
reviewer notes. Naming the boundary "Kesten–Stigum" in three places, while the
tested object is a sublinear clique, is a discrepancy in its own right — and
it is the same discrepancy that makes the plan's proposed step-0.2 target
(`BBP m_crit`) conflict with §10.3's own label (see Appendix, item 5).

**Action.** Either (i) qualify the three occurrences to match §5.6's hedge
("the boundary, whose derivation would follow from the Kesten–Stigum
threshold of the SBM or from the random-matrix literature for a planted
clique"), or (ii) adopt whichever of the two the A-12-bis measurement
actually computes, and cite that. Option (ii) is preferred if the measurement
is run, since it retires the `[CONJECTURE]` at the same time. No number is
added or changed by option (i).
**Note.** This is *not* the same item as A-12, which is about §5.5/§5.6/§10.3
being *consistent with each other* about the location of the boundary (they
are). A-19 is about which theorem the paper names.

#### A-20 — `C_R` is never at risk: the slash does not touch it, and re-admission is immediate

**Location:** §1 (`:76`), §6.3 (`:834`, `:842`), §7.5 (`:1028`–`:1031`), §8.1
(`:1067`); `integrations/avalanche/contracts/AVIPValidatorManager.sol`.
**Disposition: Confirmed — a real gap.** New in round three (external reviewer,
item `N1`). **Severity:** Conceptual. It is the paper's headline mechanism.

The paper's first contribution is that "financial stake and reputational
collateral are partial substitutes" (`:76`), and §7.5 states that "the
reputation of a slashed validator is reduced according to the process of
Section~\ref{sec:reputation}" (`:1029`). The delivered mechanism does not
implement the second half:

- `slash` writes two things only: `_stakes[validator] = remaining`
  (`AVIPValidatorManager.sol:245`) and — only if the remainder falls below the
  record — `_admitted[validator] = false` (`:249-256`). Custody is debited last
  (`:258-262`).
- `_requiredStakes`, which **is** the on-chain image of `C_R` (`:102`, read by
  `requiredStake` `:161-163` and by `collateralOf = Theta − _requiredStakes`
  `:171-176`), is **never written by `slash`**. Its only write is in `admit`
  (`:229`), from the freshly certified norm (`:200`).
- There is no reputational state at all: `grep -n 'eputation'` over the manager
  returns doc-comments only (`:14-22`, `:41`, `:59-63`, `:140-142`).
- Re-admission is therefore immediate and penalty-free. The gates in `admit`
  are `! _admitted` (`:194`), `certifiedNorm >= Theta_r` (`:198`), stake and
  escrow (`:200-212`) and the ZK proof (`:220-223`): no cooldown, no history, no
  accumulated penalty. A slashed validator that re-declares the same norm gets
  the identical `_requiredStakes`.
- Ejection is by *state*, not by time (`:249-256`), which is deliberate and
  correct for the invariant `isAdmitted ⇒ stakeOf ≥ requiredStake`. It is not a
  sanction.

**Consequence for §7.** In A-18's deterrence condition `q > G/(G+L)`, `L` is the
escrow only. The reputational half of the penalty is a *paper* quantity (the
§2.5 integro-PDE `C_R(r)`) with no on-chain counterpart to lose, so the thesis
of `:76` holds in the model, not in the mechanism.

**Action.** Blocked on **D-4** (is on-chain reputation executable or
declarative?). If declarative, §1/§7.5/§8 must say that `C_R` is a *dynamic
entrance discount computed from the declared norm*, not collateral at risk. If
executable, the slash has to persist something `admit` reads (a re-admission
surcharge, or an accumulated `ΔS`). Cross-refs: A-18, B-4, and this file's
`N-4`/`N-6`.

#### A-21 — The §7 attacker is never named, and `V_fraud`/`S_slash` have no counterpart in the protocol

**Location:** §7.2 (`:957`, `:964`, `:969`), §7.3 (`:975-1000`), §7.5 (`:1028`),
`tab:sec7-summary` (`:1055`);
`verification/data-layer/simulate_data_layer_v3.py:17-18,52`.
**Disposition: Confirmed — a real gap.** New in round three (external reviewer,
item `N2`). **Severity:** Conceptual. It defeats any "the attacker model is
closed" reading of §7.5.

Three verified facts:

1. §7.2 defines `T` only by exclusion: it "is not declared by the validator"
   (`:957`), `f_c` is "not changeable by the validator" (`:964`), and the
   commitment "is produced by the data layer, not by the validator" (`:969`).
   **Correction to the review report:** the claim that "`validator` appears 0
   times in §7.3" is false — `grep` over `main.tex:953-1000` returns **3** hits.
   All three are negations, which is the stronger form of the same point: §7's
   actor is defined only by *not* being the validator.
2. §7.3 names no actor at all. The attack is one scalar, introduced in §7.5:
   "the slashing parameter `S_slash = 10.0` exceeds the fraud gain
   `V_fraud = 1.0`" (`:1028`); `tab:sec7-summary` records "Attacker profit −502
   with `S_slash = 10`" as *Analytical*, backed by `simulate_data_layer_v3.py`
   (`:1055`).
3. Both numbers are **script constants**, not protocol quantities:
   `V_FRAUD = 1.0` (`:17`), `S_SLASH = 10.0` (`:18`),
   `attacker_profit = (n_frauds − n_detections)·V_FRAUD − n_detections·S_SLASH`
   (`:52`). No contract carries either, and `slash(validator, amount, reason)`
   takes an **arbitrary** `amount` (`AVIPValidatorManager.sol:238`) bounded only
   by the stake. The `G = 50` used by A-18 is this worksheet's derivation
   (`1.0 × 500 × 0.10`), not a paper quantity.

**Action.** Replace the scalar gain with a declared attack model — the real
incentive is the stake the declared norm buys
(`AVIPValidatorManager.sol:142-149`), i.e. `ω·ΔS` per epoch — with an explicit
detection window and a loss equal to the escrow actually debited. Needs
measurement **M-05**; depends on **D-3** and **D-4**. Same root as A-18 and as
this file's `N-2`/`N-3`.

#### A-22 — The publisher of `T` is an EOA with no stake and no timelock, and it also controls the verifier

**Location:** `integrations/avalanche/contracts/AVIPRegistry.sol:56`, `:71-73`,
`:77-84`, `:86-91`, `:93-96`; `AVIPValidatorManager.sol:106-113`;
`docs/paper/main.tex` (no occurrence of "sequencer").
**Disposition: Confirmed — a real gap, and the same finding as this file's
`N-1`.** New label in round three (external reviewer, item `N3`). `N-1` carries
the longer evidence list and should be preferred on adoption: the two IDs must
collapse into one, not two.
**Severity:** Structural trust assumption.

`sequencer` is an `address` fixed at construction (`:71-73`, `ZeroSequencer`)
and is the only caller of `postCommitment` (`:99-102`) and of both setters
(`:86-91`, `:93-96`). Neither setter emits an event, and `setVerifier` has **no
`address(0)` check**, so the role can silently disable certification, after
which `verifyThreshold` reverts `VerifierNotSet` (`:174-175`). The role can
rotate itself; no contract requires it to be a validator or to hold stake
(`grep -c 'sequencer'` → 0 in `AVIPValidatorManager.sol` and in its interface);
and the paper never uses the word at all (`grep 'sequencer'
docs/paper/main.tex` → 0), attributing publication to "the data layer"
(`:969`).

**Action.** Blocked on **D-2** (model of the publisher of `T`). Recorded here
for the register. The cheap hardening of the registry (event + zero-check +
access-control test) is `B-1` and this file's `N-1`, and does **not** resolve
the trust assumption.

### Partially confirmed — wording precision, no numerical change

#### A-5 — `F_0^*` is the IR-saturating fee, not the revenue maximizer

**Location:** §6.5 and the `F_0` table; §7.4.
**Disposition: Partially confirmed — wording only; the numerical form of
the objection is refuted.**
**Severity:** Presentation.

The paper already states both facts: that "the optimal `F_0` is the largest
value that preserves IR for all types", and that "increasing the fee above
`F_0^*` gains revenue at the cost of excluding the worst-case types". The
`*` notation and the caption "relative to the optimal `F_0^*`" nevertheless
invite the reading that `F_0^*` is an unconstrained revenue optimum.

The reviewer's comparison ("59.88 > 50") is invalid across sections: 59.88
is §6.5 gross/net *fee revenue* at `F_0 = 0.06`, while 50 is §7.4's
*audit cost*, a different quantity in a different model.

Their request for an explicit note that high-`ω` types stay at `U = 0` is
already satisfied: §6.5 states that the saturation `U(ω̄, 0) = 0` is exact
and holds analytically for the worst-case type.

**Action.** One line stating that `F_0^*` is IR-constrained (the
IR-saturating fee), not a revenue optimum.

#### A-10 — Bulletproofs recursion over BN254 needs non-native arithmetic

**Location:** §4.4 recursive composition; §4.6 provenance.
**Disposition: Partially confirmed — the missing-number half is already
done; the non-native half is confirmed.**
**Severity:** Presentation.

The paper already labels the recursive cost as an estimate and states that
the proving time "is not measured". What it does not state is that a
recursive composition over BN254 requires non-native field arithmetic
(Grumpkin, Nova, or Halo2-style cycles), which is the reason the proving
time is not a small constant multiple of a native proof.

**Action.** Add the non-native-arithmetic caveat where the recursion is
introduced. No number changes.

#### A-13 — Heavy-tail detection: add the Bethe Hessian as an option

**Location:** §5.4 heavy-tail calibration; F-019.
**Disposition: Partially confirmed — an addition, not a defect.**
**Severity:** Presentation.

The negative result is already fully measured and reported (FPR 1.0 with
TPR 0.000 for `β ≤ 2.3`, TPR 0.155 at `β = 3.0`), and the paper already
says the bulk edge `2√d̄` is not the correct edge for the weight
distribution it uses and that recalibration destroys power. The reviewer's
proposal — record Bethe Hessian / non-backtracking (Krzakala et al., 2013)
as a third remedy alongside per-null recalibration and a weight-dependent
bulk edge — is legitimate and cheap.

**Action.** Add the option. If a script is written to demonstrate it, that
is a part-C measurement and follows the same rule: script before text.

#### A-16b — The entry-barrier effect contradicts the stated motivation

**Location:** §1 (motivation), §6.4, §8 bootstrap (§8.1 genesis, §8.5–§8.6 policies); §10 limitations.
**Disposition: Confirmed — a real framing gap.**
**Severity:** Conceptual; the strongest substantive criticism in the list.

The Introduction motivates the framework by the fact that high collateral
"deters honest but capital-constrained validators", and the Abstract says
the framework "replaces a fraction of the financial stake with verifiable,
non-transferable reputation". But stake reduction is a function of
reputation: at genesis, a validator with `R = 0` posts the full `Θ`, and
below-median validators lock *more* than the median. So a capital-constrained
*newcomer* receives no relief at all; the reduction accrues to incumbents.
The paper records the mechanics (genesis behaves as pure PoS; below-median
validators lock more) but never confronts the tension with the stated
motivation.

**Action.** One paragraph in §8 (genesis) or §10 stating the effect plainly, with a
metric if one exists. Do not overclaim it as a numerical error — the
numbers are consistent; the *framing* is incomplete.

### Needs measurement — legitimate challenges with no demonstrated error

Per §9 of `implementation-plan.md`, these require a script that reproduces
the number *before* any text changes. Two of them can move a conclusion.

- **A-8 — Succinctness baseline.** The reviewer proposes re-measuring the
  ingesting-tensor baseline with assembly and a 2-byte-packed fixed-point
  encoding, on the theory that the honest baseline may fall below 206k gas
  and invert §4.5's conclusion.
  *State:* the row is backed by `verification/zk/succinctness_comparison.py`
  (684,064 gas = 256,000 calldata + 428,064 on-chain), and §4.5 already has
  its own "Estimates and Their Provenance" subsection separating measured
  from estimated. The challenge is methodological and untested.
  **Risk:** if the honest baseline lands below ~206k, the §4.5 conclusion
  ("transmitting the tensor and computing its norm on-chain does not
  dominate the constant-size proof") must change — a `main.tex`-level claim.
  Measure first.

- **A-12-bis — Locate the detection boundary.** Targeting a BBP-style
  `m_crit` (the reviewer suggests `≈ 16` for the reference parameters) would
  convert the `[CONJECTURE]` of §5.6 into a measurement and tighten §10.3.
  Optional, but it is the only part-A item that would add a *number*. Three
  things must be fixed before the script is written, or the exercise produces
  a number nobody can compare:
  1. **Target the quantity the paper names.** §10.3 attributes the boundary to
     the **Kesten–Stigum** threshold of the degree-corrected SBM; BBP is the
     spiked-Wigner analogue. Compute whichever the paper will cite, and make
     the two agree — see **A-19**.
  2. **Pin the null.** `q99 = 9.0542` is the *reference-configuration*
     quantile (`n = 500`, `d̄ = 20`), so "crossing q99" is not executable
     until the null is fixed. Recalibrate `q99` per configuration; the
     reviewer's own F-019/F-020/F-021 work shows that per-null recalibration
     is what destroys the power on heavy-tailed nulls, so *which* null is
     meant has to be stated.
  3. **Define `m_crit` operationally.** "The boundary" is not a procedure. Use
     the reviewer's definition: **the smallest `m` at which TPR = 0.5 for
     `α = 0.01`, with `q99` recalibrated for that configuration**, and write
     that sentence into the script's docstring and into the report.

  C-05's residual already records that BBP "is not implemented" and that the
  boundary "remains `[CONJECTURE]`".

- **A-13-bis — Demonstrate the Bethe Hessian remedy.** Only if A-13 is
  adopted as more than a bibliographic note. Same rule.

### A-17 — Bibliography: stale keys and genuinely missing citations

**Disposition: Confirmed (cosmetic) plus confirmed (additions).**

- `chung2003` points at *PNAS* **99(25), 2002** — the entry is correct, the
  key year is stale.
- `coja2009` points at *Combinatorics, Probability and Computing* **19(2),
  2010** — same: correct entry, stale key year.
- The modularity-matrix claim cites `chung2003, coja2009` for "the
  modularity matrix is the standard tool for community detection in the
  stochastic block model". **Newman (2006)** is the missing citation here.
- **Füredi–Komlós (1981)** for the clique spectral bound: legitimate
  addition.
- **BBP** (Féral–Péché 2007; Benaych-Georges–Nadakuditi 2011) and
  **Krzakala et al. (2013)** for the Bethe Hessian: legitimate additions,
  contingent on A-12-bis / A-13.

**Action.** Rename the two keys (or leave them and accept the mismatch, but
the mismatch is visible). Add Newman unconditionally. Add the rest with the
corresponding content.

## Part B — `integrations/avalanche/` (7 items)

**Key structural finding, verified:** `grep -i 'integrations\|contracts\|forge\|cargo'`
against `verification/audit-gate.sh` and `verification/run_all.sh` returns
**no matches**. The audit gate and the harness do not inspect the
integration layer at all. Therefore:

- Every item in part B is **outside the anchor**. Changing
  `AVIPStakeVault.sol`, adding `DeployFujiPhase1.s.sol` or
  `DeployBurnSink.s.sol` requires **no re-anchoring, no receipt, no
  `.ots`**.
- The reverse of that: the gate does **not** protect the Solidity suite. A
  contract change must be re-validated by hand (`forge test --offline`,
  `forge fmt --check`, `bash scripts/deploy_dryrun.sh`) and the affected
  documents (`implementation-plan.md` §5.12, `scripts/README.md`, the
  integration `README.md`) updated by hand.

| # | Item | Disposition |
|---|---|---|
| B-1 | `bindManager` → pass the manager address in the constructor | **Confirmed and feasible.** §5.12 already names the obstacle (cyclic wiring: an `immutable` needs the manager's address before it exists) and the precedent already exists in the integration layer (**nonce-based `CREATE` prediction**: `test/M7dTransport.t.sol:158` predicts from the `CREATE` nonce via `_predictDeployment(offset)`, and the same test notes it "reaches the same end with CREATE2 or with nonces it knows"). Prefer extending that nonce-based precedent; `CREATE2` additionally requires the manager to be deployed by a factory with a `salt` + init-code hash, which is a larger change than the item needs. No anchor impact; requires re-running the M8 suite and updating §5.12 / the READMEs. |
| B-2 | Write `DeployFujiPhase1.s.sol` | **Confirmed.** This is the Fuji-runbook item §5.12 already calls for. Note the residual to record: it is two transactions in sequence, not "a single transaction". |
| B-3 | Write `DeployBurnSink.s.sol` | **Confirmed absent.** `AVIPBurnSink` exists with a constructor taking the token address; there is no deploy script for it, and there is no deployable ERC20 in the repo (only mocks/fixtures). A Fuji run therefore needs either a mock token or a real testnet ERC20. |
| B-4 | Add an exit queue / withdrawal delay | **Confirmed gap, deliberate and already documented.** `AVIPStakeVault.sol` states "No cooldown and no exit queue: leaving the set is the manager's business, and M8 adds no exit". So on-chain deterrence (§7.5) has no time lock. Either add the delay (contract change, no anchor impact) or keep it declared-open — §7.5 already hands the question to §10. **Confirmed dangling reference.** §7.5 (line 1030) writes: *"whether the executable loss on its own deters an attacker of that size is the question Section~\ref{sec:limitations} leaves open."* §10 does **not** contain it: §10.2 (Adversary Model) covers rationality, Sybil cost and the `B*` bounty, and §10.8 (`What the Protocol Does Not Claim`) lists five items without it. So this is a real dangling cross-reference, not a false alarm. Either add the sentence to §10 (preferred — it is a genuine limitation) or rewrite the §7.5 clause. |
| B-5 | Compare `token.decimals()` in the deploy script | **Confirmed as cheap hardening.** It does not violate the contract's rule (the contract never calls `decimals()`); it catches a wrong `WAD_PER_UNIT` at deploy time, when it is still free to fix. |
| B-6 | Slash liveness under a pausable/blacklisted token | **Confirmed as a "decide and document" item.** The behavior is already deliberate and tested (a slash reverts atomically rather than half-applying). What is missing is the explicit statement of the atomicity-vs-liveness trade-off. |
| B-7 | `DeployCommon` docstring calls the anvil addresses "public, valueless" | **Confirmed by live measurement.** The `anvil[0]` address is not valueless on Fuji (it held a non-zero balance and a high nonce). Add a `require(sender != anvil_defaults)` guard for `chainid != 31337`. No anchor impact. |

## Part C — measurement tasks (consolidated)

Three measurement proposals arrived. They are collected here because they
share one process rule, not because they share a subject.

| Task | Moves a conclusion? | Where |
|---|---|---|
| Honest succinctness baseline (assembly + packed fixed point) | **Yes** — §4.5's conclusion flips if the baseline drops below ~206k | A-8 |
| Locate the detection boundary (BBP `m_crit`) | No — converts a `[CONJECTURE]` into a measurement | A-12-bis |
| Demonstrate the Bethe Hessian remedy | No — adds a remedy option with evidence | A-13-bis |

**Process rule.** Per §9 of `implementation-plan.md`, a number reaches
`main.tex` only after a script under `verification/` produces it and the
output is committed to `verification/baseline_verified/`. Any script added
here changes `verification/output_manifest.txt` and therefore changes the
anchor root: these tasks must be completed **before** the part-A edit
session, so that a single re-anchor covers both.

Two constraints on the artifact, verified in the gate:

- A prose `.md` report under `docs/audit/` is *not* sufficient on its own —
  it is allowed (that directory is not sealed) but the *number* must come
  from an executable script plus its committed output. So each task should
  ship **script + `verification/baseline_verified/` output + a note in the
  report**, not the report alone.
- G1 of `audit-gate.sh` counts `find verification -maxdepth 2 -name '*.py'`,
  so a new script must sit exactly one level below `verification/`
  (`verification/<area>/name.py`) to be counted, and the count must stay
  `>= 35`.

**One correction to the task statement itself.** The detection boundary in
§10.3 is attributed by the paper to the **Kesten–Stigum** threshold of the
degree-corrected SBM, not to BBP: BBP is the spiked-Wigner / sample-covariance
analogue. Both are legitimate tools, but the task should target the quantity
the paper already names, and the acceptance criterion must fix the null
distribution — `q99 = 9.0542` is the right-tail quantile of the reference
configuration (`n = 500`, `d̄ = 20`), and `m_crit` depends on `n`, `d̄` and
that null, so "crossing q99" is not executable until the procedure is pinned.

Order of work: measure → decide the text → one edit session → one re-anchor.

## Part D — release process (4 items)

- **D-1 — Zenodo v2.** A new version with its own DOI is the right home for
  the corrected text. `.zenodo.json` already has an uncommitted
  modification in the working tree (` M .zenodo.json`); reconcile it as
  part of the release rather than leaving it dangling.

- **D-2 — Re-anchoring.** Any part-A edit invalidates
  `verification/anchor_root.sha256`, because `main.tex` is line 1 of the
  root. The sequence is: `run_all.sh` → `fase0_anchor.sh` → new receipt
  (next in the R-series) → external `.ots` timestamp → out-of-band copy of
  the root. The receipt and the `.ots` live outside the root by
  construction, so they do not create a cycle. `audit-gate.sh` must read
  **PASS=11, FAIL=0** (guards G1…G11) before the release is tagged.

- **D-3 — Do not submit before part A is applied or explicitly deferred.**
  This is the one scheduling fact that matters: arXiv versions are
  permanent and citable. Submitting the current text makes the confirmed
  items (A-1, A-6, A-7, A-9, A-11, A-15) part of the public record,
  correctable only through a visible v2. The repository is in a clean,
  consistent, fully-anchored state right now — which means the *cheap*
  moment to fix part A is before the first arXiv submission, not after.

  Part B (integration layer) is outside the anchor and can proceed in
  parallel with no interaction. The Fuji deployment numbers are a separate
  batch: new quantitative claims re-open the content audit, so they belong
  to a later release with its own re-anchoring.

- **D-4 — The gate has three hard-coded constants over *sealed* files.**
  Verified in `verification/audit-gate.sh`, and this is the sharpest trap in
  the whole release, because none of these guards complains about *content* —
  it fails on a *count*:

  | Guard | Rule | File (sealed?) | Consequence |
  |---|---|---|---|
  | G5 | `grep -c '^### F-'` must be **exactly 21** | `docs/audit/numerical-verification.md` — **sealed** | Adding any `F-0xx` entry (e.g. the Bethe-Hessian finding) is a FAIL until the constant `21` is raised in the same batch |
  | G6 | `grep -c '^### C-'` must be **exactly 50** | `docs/audit/content-audit-pending.md` — **sealed** | Recording the external-review findings as new `C-51 …` worksheets is a FAIL. This is why the triage lives in a **new, unsealed** file instead |
  | G8 | `grep -c 'Estimate.*Verified\|Verified.*Estimate'` must be **0** on `main.tex` | `main.tex` — **sealed** | Rewriting the status tables (A-9, A-11) so that one line carries both words is a FAIL |
  | G9 | `pdflatex ×2` with `^!` count 0 and `Undefined` count 0 | `main.tex` | Any LaTeX error introduced by the part-A batch is a FAIL |

  So: if the part-A session adds a numerical finding, the `21`/`50`
  constants and `audit-gate.sh` itself must be edited **in the same
  re-anchoring batch** — three sealed files at once, not two. If it does not
  add a finding (the preferred path), only `main.tex` and the manifest move.

## Appendix — verification of the proposed execution plan (2026-10-13)

The plan circulated after this triage was checked line by line against the
repository. It is **sound in its four-phase shape** (measure → edit → re-anchor
→ release) and its re-anchoring sequence is correct. Five problems were found,
one of them blocking.

**1. Blocking — label collision in step 1.** The plan's step 1 calls two
"confirmed defects" `A-6` and `A-7` and describes them as §7.5 / `−502` and
§7.3 / `N_ATT`. In this triage those are **A-3** and **A-4**, both **already
closed** — and the plan's own "NO TOCAR" list names `A-3, A-4`. Its step 1
therefore contradicts its own checklist, and both edits are redundant:
`main.tex:1266` already states the real bound (`Θ = 1.0`, "not executable
losses", P6b) and `main.tex:981` already carries `N_ATT` in both terms (P6a).
The genuine `A-6` and `A-7` — the abstract's "verified numerically" overclaim
and the "pairs every quantitative claim with a script" overclaim — are
**absent from the plan entirely**, although they are two of the six confirmed
defects and sit in the abstract, the most visible page of the paper.

**On provenance.** The plan under review arrived as pasted text in the working
session, labelled `PASO 1` with `A-6`/`A-7`; the reviewer states they did not
author it and did not use `A-n` labels. That is immaterial to the finding:
this triage does not use `A-n` that way either, so the plan's numbering is a
*different namespace* and the collision stands regardless of who wrote it. The
labels in this file are the authoritative ones. What did settle the underlying
question was the reviewer's own round-two diagnostic (`sha256sum`, `grep`,
`git show`), reproduced verbatim under "Version diagnosis" above: it shows the
contested copy predates P6a, so `A-3`/`A-4` are closed rather than refuted,
and the plan's step 1 was redundant rather than wrong.

Authoritative mapping for step 1:

| Plan label | Real triage label | Verdict | Where it belongs |
|---|---|---|---|
| A-1 | A-1 | confirmed | step 1 |
| A-6 (−502 / §7.5) | **A-3** | **already closed (P6a relabel, P6b disclosure) → do not touch** | drop |
| A-7 (`N_ATT` / §7.3) | **A-4** | **already closed (P6a fixed the cost term) → do not touch** | drop |
| — | **A-6** (abstract, ZK "verified") | confirmed | **missing — add** |
| — | **A-7** (abstract, "pairs every claim") | confirmed | **missing — add** |
| A-9 | A-9 | confirmed | step 1 |
| A-11 (non-native, "tens of seconds") | **A-10** | confirmed | step 1 |
| A-10 (wording) | A-10 | confirmed (same item) | step 1, once |
| A-13 | A-13 / A-13-bis | partial + measurement | step 0.3 |
| A-15 | A-15 | confirmed | step 1 |
| A-16b | A-16b | confirmed framing | step 1 |
| — | **A-18** (deterrence `q > G/(G+L)`) | confirmed, round two — **add** | step 1 |
| — | **A-19** (KS vs BBP attribution) | confirmed, round two — **add** | step 1, or resolved by step 0.2 |
| — | **A-20** (`C_R` never at risk / immediate re-admission) | confirmed, round three — **record only** | blocked on D-4 |
| — | **A-21** (§7 attacker never named) | confirmed, round three — **record only** | blocked on D-3, D-4, M-05 |
| — | **A-22** (publisher of `T` is an EOA) | confirmed, round three — **record only** | blocked on D-2; same substance as **N-1** |
| A-5, A-17 | A-5, A-17 | confirmed | step 1 |

**2. Section numbers.** The plan's `§8.3` for A-16b is close but not exact:
the `R = 0` genesis effect is stated in **§8.1** (`:1067`) and the policy
results in **§8.5–§8.6**. Its `§5.7` for A-15 should be **§5.6** (the
`[CONJECTURE]` sits at `:767`, inside §5.6) with §5.7 as the limitations
summary. Its `§4.4` for the "tens of seconds" clause is **correct**
(`:548`). Its `§4.3` for A-9 is **correct**. See the section map above.

**3. The one edit the plan correctly *adds* and this triage missed.**
"Quitar *tens of seconds*" is right and should be adopted: `main.tex:548`
says, verbatim, "we estimate the recursive proving time in the range of tens
of seconds on a modern CPU, **but the estimate is not verified**". Deleting
the interval (or marking it plainly as unverified) is the cleanest fix.

**4. `CREATE2` in step 2 is unnecessary.** The repository's own precedent is
**nonce-based `CREATE` prediction** (`test/M7dTransport.t.sol:158`,
`_predictDeployment(offset)`, and the test itself notes it "reaches the same
end with CREATE2 **or** with nonces it knows"). `CREATE2` would additionally
require the manager to be deployed by a factory with a salt and an init-code
hash. Use the nonce precedent; it is smaller and already tested.

**5. Step 0 acceptance criteria are under-specified.**

- `0.1` proposes a `.md` report as the artifact. That is allowed
  (`docs/audit/` is unsealed) but insufficient: the number must come from a
  script plus committed output. Ship **script + `verification/baseline_verified/`
  output + report**, and put the script exactly one level under `verification/`
  or G1 will not count it.
- `0.2` targets "BBP `m_crit`". The paper attributes the boundary to the
  **Kesten–Stigum** threshold of the degree-corrected SBM (§10.3); BBP is the
  spiked-Wigner analogue. Target the quantity the paper already names, and pin
  the null: `q99 = 9.0542` is the reference-configuration quantile
  (`n = 500`, `d̄ = 20`), so "crossing q99" is not executable until the
  procedure is fixed.
- `0.3` is fine, with the caveat already noted for A-13: only worth running if
  the answer changes text.

**6. G5/G6/G8 are mis-designed as guards, and the reviewer's diagnosis is
correct.** (Raised in round two; accepted.)

- **G5/G6** hard-code the expected entry counts (`21` `F-` rows, `50` `C-`
  rows) as literals inside the *sealed* `verification/audit-gate.sh`. Adding a
  numerical finding therefore **fails the gate** instead of recording it, which
  inverts the incentive of a project whose stated virtue is the falsification
  log. The fix is to read the expected count from a manifest rather than from a
  literal. This is workable: `fase0_anchor.sh` derives the root from an array
  (`ROOT_PATHS=("${ANCHOR_PATHS[@]}" "${VERIFIER_PATHS[@]}" "${INPUT_PATHS[@]}")`,
  counted with `${#ROOT_PATHS[@]}`), so an extra sealed file needs no rewrite of
  the print logic. **The caveat that makes or breaks the proposal: the counts
  manifest must itself be *inside* the seal.** If it is not, an entry can be
  added and the gate still passes with no re-anchor — the guard would stop
  guarding. Sealed, the change becomes exactly what the reviewer wants: an
  explicit, reviewed edit plus a deliberate re-anchor, *not* a silent gate
  failure. Note the cost: it touches `fase0_anchor.sh`, `audit-gate.sh` and the
  manifest, so it is a three-sealed-file batch (see D-4) and cannot be slipped in
  alongside an unrelated edit.
- **G8** is a line-oriented `grep` (`count() { grep -c "$1" "$2" 2>/dev/null || true; }`),
  so `Estimate` and `Verified` split across two lines escape it. It is a lint,
  not evidence, and must not be presented in the paper as a guarantee that
  estimates are never mixed with verified claims. Keep it — it catches the
  common case cheaply — but describe it as a lint. This does not change any
  finding above; `main.tex` does not currently cite G8 as a guarantee.

**Correct in the plan, no change needed:** step 0 before the text; the
re-anchor sequence of step 3; `PASS=11, FAIL=0`; `NO TOCAR: A-2, A-3, A-4,
A-12, A-14, A-16a`; the separate Fuji batch; the manual Solidity re-validation
because the gate does not cover `integrations/` (verified: `forge test
--offline`, `forge fmt --check`, `bash scripts/deploy_dryrun.sh` — the script
exists at `integrations/avalanche/scripts/deploy_dryrun.sh`); marking B-4 as
pending (now **confirmed** as a dangling reference: §7.5 `:1030` sends the
reader to `sec:limitations` and §10 does not contain the clause).

One residual the plan inherits from this triage: `A-2` is refuted as algebra,
but it carries one confirmed cosmetic fix — `:278` calls `r = 0` an
"absorbing boundary" while §2.2 proves positivity pathwise. If "NO TOCAR A-2"
is read literally, that one word stays. Decide it explicitly.


## Recommended order

1. **Part C** — run the three measurements. No text is touched. If the
   succinctness baseline moves, §4.5 changes its conclusion.

2. **Part A, single session** — apply A-1, A-6, A-7, A-9, A-11, A-15 and
   **A-18** (defects and gaps), then A-5, A-10, A-13, A-16b, A-17 (precision
   and additions). A-18 also discharges B-4, by giving §10 the clause that
   §7.5 `:1030` already points at. Every edit to a sealed file in one pass.
   **A-20, A-21 and A-22 are deliberately excluded from this batch.** They are
   recorded (below) but blocked on decisions D-1…D-4, and applying them before
   those decisions are settled would have to be redone. See the round-three
   ledger at the end of this file.
3. **Re-anchor** — `run_all.sh` → `fase0_anchor.sh` → receipt → `.ots` →
   out-of-band copy → `audit-gate.sh` PASS.
4. **Release** — arXiv v1 with the corrected text, Zenodo v2 with its DOI.
5. **Part B** — in parallel: B-7 and B-5 are trivial and useful immediately;
   B-2 and B-3 unblock the Fuji run; B-1 is the only item with real cost
   (re-validation of the M8 suite).
6. **Fuji numbers** — separate batch, later, own audit and re-anchoring.

## Summary

| Disposition | Count | Items |
|---|---|---|
| Refuted (reviewer wrong) | 4 | A-2, A-12, A-14, A-16a |
| Already closed (valid against the reviewed copy) | 2 | A-3, A-4 |
| Confirmed defect (edit needed) | 7 | A-1, A-6, A-7, A-9 (presentation), A-11, A-15, A-19 |
| Confirmed gap (edit needed) | 2 | A-16b, A-18 |
| Confirmed gap, round three — model vs delivered mechanism | 3 | A-20, A-21, A-22 |
| Partially confirmed (wording) | 3 | A-5, A-10, A-13 |
| Needs measurement first | 3 | A-8, A-12-bis, A-13-bis |
| Confirmed cosmetic / additions | 1 | A-17 |
| Integration items (outside the anchor) | 7 | B-1 … B-7 |
| Release-process items | 4 | D-1 … D-4 |

The reviewer's two strongest contributions in round one are A-9 (the
derivation behind the 1.08M count is naive and presented as authoritative)
and A-16b (the stake reduction does not reach the capital-constrained
newcomer the motivation is written for). Roughly a third of the list
re-litigates findings that were already closed and recorded as C-xx. That is
now *verified* rather than assumed: the reviewer read a copy that predates P6a
and P6b (see "Version diagnosis"), which is why A-3 and A-4 read as live
defects to them and as closed here. Both descriptions are correct about their
own revision — which is exactly why those two are recorded as **already
closed** and not as **refuted**. The reviewer also supplied the strongest
single item of round two by replacing their own A-3 argument: the deterrence
condition `q > G/(G+L)`, absent from the paper, adopted here as **A-18**.

## Hallazgos de la pasada de lectura

**Fichero no sellado, y esta sección tampoco lo está.** Como el resto de este
worksheet (arriba, "What this file is"), no forma parte del ancla: no toca
`claim-registry.csv`, `numerical-verification.md` ni `content-audit-pending.md`,
y no mueve `main.tex`. La pasada fue de **solo lectura**: no se modificó ningún
contrato, test, documento sellado ni script; `main.tex` conserva su hash.

**IDs provisionales.** Este fichero numera `A-n` (paper), `B-n`
(`integrations/avalanche/`), `C-n` (medición) y `D-n` (release). Los siete puntos
de abajo se etiquetan **`N-1 … N-7`**: `N` no pertenece a ninguna de esas series
y **es un namespace provisional del lector, no una asignación**. Adoptarlos
requiere renumerar a `B-n`/`D-n` en un solo lote, con la disciplina de
`audit-gate.sh` en mente (G5/G6 cuentan entradas `F-`/`C-`; esta sección no añade
ninguna).

**Nota de reconciliación de IDs (`N-4`).** La petición de registrar el
*staleness* no temporal del artefacto como `N-4` **no crea un ID nuevo**: ese
hallazgo ya está registrado como **`N-3`** (fila anterior) y `N-4` está tomado
por el claim de §6.2 sobre el *binding* ZK. Se ha **reforzado `N-3`** con la
evidencia dura del artefacto (grep de `block.timestamp`, ausencia de
`Expired`/`deadline`, época sin duración, `Window` sin campo temporal) en lugar
de abrir un duplicado. `N-7` sí es nuevo y pertenece a un **fichero sellado**
(por eso su estado es «diferido», no «aplicable»).

**Tres streams, no uno.** Los hallazgos registrados en este fichero pertenecen a
tres registros distintos y **no se mezclan**:

- **Stream A — auditoría contrato↔paper** (`A-1 … A-22`, `N-1 … N-7`): es el
  registro de este triaje. Bloquea las decisiones `D-1 … D-4` (y `M-05`).
- **Stream P — proceso, guardas, CI** (`P1 … P7b`, la tabla de fases de
  `implementation-plan.md` §12): no depende del contenido del paper ni del
  artefacto; se juzga por sus propios gates.
- **Stream B — mérito académico** (`N-8 … N-15`, reviewer externo): **no bloquea
  v1**; condiciona v2 (ver el bloque `(e)` de Fase 5).

Un hallazgo de B **no reabre** uno de A, y uno de A **no invalida** B: son
preguntas distintas (¿el artefacto hace lo que el paper dice? frente a ¿el paper
se sostiene ante un reviewer?). Los tres se registran aquí; ninguno se aplica
sin decisión del autor. La etiqueta `stream B` viaja en la tabla de abajo para
que cada ID sea trazable a su registro.

| # | Hallazgo | Evidencia (fichero:línea) | Estado |
|---|---|---|---|
| **N-1** | El publicador de `T` («sequencer») no tiene ningún requisito on-chain de ser validador ni de stake, se auto-rota sin timelock y controla también el verificador; ninguno de los dos setters emite evento | `contracts/AVIPRegistry.sol:56` (`address public sequencer`), `:71-73` (constructor, `ZeroSequencer`), `:77-84` (`onlySequencer`/`NotSequencer`), `:86-91` (`setSequencer`, sin evento), `:93-96` (`setVerifier`, sin evento **y sin zero-check**), `:99-102` (`postCommitment`); `AVIPValidatorManager.sol:84-93,109-112` y `grep -c 'sequencer'` → 0 en el manager y en su interfaz; `test/AVIPValidatorManager.t.sol:89,94` (`makeAddr("sequencer")`, no validador); `test/AVIPRegistry.t.sol:174-186` (rota el sequencer: 3 asserts), `:362-367` (el verificador sólo se sustituye por el helper `_setVerifier`; no hay test de acceso ni de `setVerifier(address(0))`) | abierto, pendiente de decisión |
| **N-2** | El paper atribuye la publicación al «data layer» y **nunca usa la palabra «sequencer»**; el código y los docs llaman «sequencer» al rol | `docs/paper/main.tex:969` («produced by the data layer, not by the validator»); `grep -n 'sequencer' docs/paper/main.tex` → 0 coincidencias; `contracts/AVIPRegistry.sol:54-56`; `scripts/DeployRegistry.s.sol:16-19` | abierto, pendiente de decisión |
| **N-3** | **Staleness sin eje temporal en el artefacto** (no «frescura»): no existe ventana de desafío —ni en tiempo ni en épocas— on-chain ni en el data layer entregado; la época es un contador **sin duración** y un root obsoleto **nunca caduca** (no hay `maxAge`, expiración ni plazo) | `grep -rn 'challenge\|Challenge' contracts/ test/` → 0; `grep -rn 'block.timestamp' integrations/avalanche/contracts/` → **1** y es un `emit` (`contracts/AVIPRegistry.sol:119`): se emite y **nunca se lee**; `grep -rn 'Expired\|expired\|deadline\|challengeWindow\|CHALLENGE' contracts/` → **0**; `AVIPRegistry.sol:105-106` (secuencia estricta) y `:143-145` (`latestEpoch()` devuelve `type(uint256).max` si vacío ⇒ nada obliga a avanzar de época); `verifyThreshold` es `view` (`:166-169`); `main.tex:973,976` (desafío sin plazo; `B` y `S_slash` son «model parameters… does not move funds»); `src/datalayer/src/ingestion.rs:75-82` (`Window` = tres contadores `u32`, sin campo temporal; `h` es la clave del llamante, `:72-73`) y `:251-256` (`adjudicate` no recibe **ningún** argumento de tiempo); este fichero, A-18/B-4 | abierto, pendiente de decisión |
| **N-4** | §6.2 declara imposible el misreporting por el *binding* ZK, pero `eq:allocation` crea el incentivo a inflar `T`, y §6.2 no cruza a §7 | `main.tex:824-826` («The validator cannot misreport it… nothing to reveal»); `main.tex:834` (`eq:allocation`, `S_f^*` decreciente en `C_R(T)`); `main.tex:838`; `main.tex:957,969,976` (la verdad de `T` es del data layer) | abierto, pendiente de decisión |
| **N-5** | El *binding* ZK es validador↔declaración (norma exacta), no verdad↔eventos; esa mitad queda en §7 y no se reconoce en §6.2 | `contracts/AVIPRegistry.sol:12-18,166-193` (`statement = [root, epoch, certifiedNorm]` en `:187-190`); `contracts/interfaces/IAVIPRegistry.sol:17-21`; `docs/architecture/implementation-plan.md:2007-2010` («no truth check»); `src/datalayer/src/ingestion.rs:224-229` (`Verdict::Fraud`) | abierto, pendiente de decisión |
| **N-6** | `γ` no tiene valor de referencia en el paper; el contrato lo hard-codea a `0.10` (el valor que el paper muestra vacuo a `k = 10`) y la cota se comprueba sobre el delta **declarado** | `main.tex:973` (γ simbólico), `:1040` (`γ = 0.10`, `k = 10` ⇒ «permits everything and constrains nothing»), `:1057` (fila «Analytical & ---»), `:1002`; `contracts/AVIPRegistry.sol:45-52,110-111`; `contracts/interfaces/IAVIPRegistry.sol:66-73`; `verification/data-layer/simulate_data_layer_v3.py` → 0 coincidencias de `gamma`; `verification/data-layer/archive/simulate_data_layer.py:49` (`GAMMA = 0.1`, archivado); `scripts/DeployRegistry.s.sol:60-61,111-114` | abierto, pendiente de decisión |
| **N-7** | **Referencias colgantes dentro de un fichero sellado**: `content-audit-pending.md` cita líneas de `main.tex` que hoy están **vacías**, y una de ellas describe un símbolo que **ya no existe** en el paper | `docs/audit/content-audit-pending.md:45` («`Theta = 1.0` at `main.tex:837`») → `main.tex:837` es hoy línea en blanco; el valor con parámetros de referencia (`$\pi_{\mathrm{val}} = 0.15$, $\bar\omega = 0.10$, $\Theta = 1.0$`) está en `main.tex:870`. `:68-69` («`VaR_tech` appears once, in `main.tex:805`») → `main.tex:805` es hoy línea en blanco y `grep -n 'VaR' docs/paper/main.tex` → **0** (el símbolo quedó sustituido por `S_{\min}`, `main.tex:834,840,941`; lo que sí existe es `\mathrm{Var}[R_\infty]`, varianza, `:245,258`). Fichero **sellado** ⇒ sólo registro | diferido a Fase 5 (no aplicable ahora) |

### Notas por hallazgo

**N-1.** Dos hechos adicionales, medidos en esta pasada, agravan el punto y no
aparecen en los docs de arquitectura: (i) `grep -n 'setSequencer\|setVerifier\|rotat'`
sobre `docs/architecture/avalanche-integration.md` y `implementation-plan.md` →
**0 coincidencias**: la rotación de roles no está documentada (los docs sí
describen el verificador como artefacto: `avalanche-integration.md:14-16,34,49,61`;
`implementation-plan.md:186,226-227,376-379,1515,1543-1547`); (ii) `setVerifier` no
valida `address(0)` (el `ZeroSequencer` de `:89` no tiene análogo), así que el
sequencer puede **desactivar la certificación** sin evento y sin test que lo fije.
`admit` **falla por revert** en ese caso, no por un camino `false`:
`AVIPValidatorManager.sol:222-223` llama a `registry.verifyThreshold`, que revierte
`VerifierNotSet` (`AVIPRegistry.sol:174-175`) y `admit` no captura excepciones; con
el umbral comprobado antes (`:198`) y sin commitment, el camino es `UnknownEpoch`
(`:220-221`). Fail-closed, pero el único test cercano
(`test/AVIPValidatorManager.t.sol:304-315`) declara explícitamente que *no* instala
verificador **para que el registro nunca se alcance** — es decir, el caso
`admit → VerifierNotSet` sigue sin estar fijado.

**N-3.** El único rastro de la noción en el repo es su ausencia: A-18/B-4 en este
mismo fichero («Any exit path that settles before the challenge window closes»),
atado a que no hay exit queue ni cooldown en `AVIPStakeVault.sol`.

Los comandos exactos de la evidencia del artefacto, para que sea reproducible
sin releer el contrato entero:

```
grep -rn 'block.timestamp' integrations/avalanche/contracts/     # 1 hit, y en un emit (:119)
grep -rn 'Expired\|expired\|deadline\|challengeWindow' integrations/avalanche/contracts/   # 0
grep -rn 'challenge' integrations/avalanche/ src/ --include=*.sol --include=*.rs           # 0
```

Dos precisiones que evitan sobreafirmar: (i) el `timestamp` **sí existe** como
dato —viaja en `CommitmentPosted` (`:119`)— pero **nadie lo consume**: no hay
comparación, `require` ni política de expiración; (ii) «frescura» en el paper es
una magnitud **en épocas** (`γ·k`, `main.tex:1033-1040`), no en tiempo, de modo
que la acepción temporal que el nombre sugiere **no está implementada en ningún
artefacto**. La consecuencia operativa es que un compromiso congelado o
arbitrariamente antiguo es **indistinguible**, para el protocolo, de uno fresco.

**N-7.** Es el único de los siete puntos que vive en un fichero **sellado**
(`content-audit-pending.md` ⊂ `anchor_root.sha256`), así que su registro aquí es
**deliberadamente inerte**: ni se edita ni se propone editar fuera del lote de
Fase 5. Dos detalles de precisión sobre lo verificado: (i) el informe externo
cita las refs obsoletas como `:45, :67`, pero la segunda está en **`:69`**
(`:67` es la cabecera «Adjacent discoveries»); (ii) la afirmación correcta sobre
el símbolo es «`VaR_tech` no aparece», **no** «no hay `VaR`»: el paper sí usa
`\mathrm{Var}[R_\infty]` para la varianza (`main.tex:245,258`), que es otra cosa.
Al corregir en Fase 5, el reemplazo es `VaR_tech` → **`S_{\min}`**
(`main.tex:834`, definido en `:840`, con valor `0.2` en la tabla de `:941`).

**N-6.** Consecuencia de diseño↔contrato: `GAMMA_BPS` es `public constant` sin
setter, luego cambiar `γ` exige **redeploy** del registro, mientras el paper no lo
fija como constante de protocolo. `grep -rn 'gamma\|γ\|GAMMA' docs/audit/` sólo
devuelve las líneas de esta misma sección: no hay constancia previa de la
elección de `γ` en la documentación de auditoría.

### Stream B — mérito académico (N-8 … N-15)

**Registro, no corrección.** Los ocho puntos vienen del *stream* B (reviewer
externo) y se han re-verificado línea a línea en esta pasada. Se registran **sin
aplicarlos**: no tocan `main.tex` ni los 10 ficheros sellados, y no abren ninguna
decisión de la Parte A. `Gravedad` es la valoración del reviewer, no una medida;
`Evidencia` es lo que este fichero ha podido comprobar por sí mismo.

| # | Problema | Dónde | Gravedad | Evidencia | Estado/acción |
|---|---|---|---|---|---|
| **N-8** | Falta posicionamiento frente a la literatura de PoS con reputación (DPoS con reputación, delegación de stake). El paper cita EigenTrust y PeerTrust pero no se sitúa contra esa línea; un reviewer agresivo lo leerá como ensamblaje | `§1` (`:58-71`), `§5.1` (`:601`) | Media-alta | `\bibitem{kamvar2003}` (`:1555`, EigenTrust) y `\bibitem{xiong2004}` (`:1563`, PeerTrust) existen, pero **se citan una sola vez y en la misma línea**: `main.tex:601` (modelado del grafo de colaboración: «shared governance votes, co-authored pull requests, and simultaneous liquidity events»), no como trabajo relacionado; `grep -niE 'DPoS\|delegated proof\|reputation-weighted'` → 1 hit, que es el propio título (`:31`); ninguna de las 16 `\bibitem` trata delegación de stake ni reputación como peso de consenso (bai2010, bauer2012, chung2003, coja2009, cong2021, gmr1985, groth2016, kamvar2003, myerson1981, oksendal2007, roughgarden2021, saleh2021, tracy1994, tucker1966, wigner1958, xiong2004) | abierto, stream B (no bloquea v1) |
| **N-9** | Mercado secundario de identidades. «Non-transferable» califica al token de reputación, no a la identidad: un validador con `T` alto puede vender cuenta/clave y con ella el flujo de ingresos. No hay modelo de mercado secundario ni razón por la que no se forme | `§1.2` (`:59`), `§10.2` (`:1314-1323`) | Alta | El paper afirma «verifiable, non-transferable reputation» (`:39`, `:59`, `:1415`) y su argumento es de coste de oportunidad («destruction of its reputation eliminates future income streams», `:59`); `grep -niE 'secondary market\|sell (the\|its) (account\|key)\|resale\|resell'` → **0**; lo más cercano en limitaciones es el coste de mercado del Sybil (`:1319`), que es **acumular** reputación, no **comprar** la cuenta; `§10.2` (`:1314-1323`) no menciona venta de identidad ni de clave | abierto, stream B (no bloquea v1) |
| **N-10** | Break-even del aparato criptográfico: la reducción de stake (22.4% en la mediana) no se confronta con el coste de verificación (~206k–250k gas por validación). El paper no analiza la relación | `§6.5` (`:879-901`), `§9.3` (`:1231-1258`) | Media | 22.4% de reducción de stake en la mediana (`:1176`, claim «Verified»; `:1160`: el validador mediano bloquea el 77.6% del stake que exigiría PoS puro); coste de verificación `~206k` gas directo (`:515`, `:560`) y `~250k` recursivo, este último **estimado** (`:546`, `:565`); `§9.3` (`tab:gas-eip`, `:1238`) mide gas **por operación**, sin convertirlo a unidades monetarias; `grep -niE 'break-?even\|amortiz\|per validation\|cost per validator'` → **0**: ningún pasaje confronta ambas magnitudes | abierto, stream B (no bloquea v1) |
| **N-11** | `net_gain` se selecciona por correlación (0.76 vs 0.08–0.11) pero el criterio declarado en el script de comparación es el umbral `R_std ≥ 0.05`, que el propio modelo viola (0.0424). El barrido de `R_std` queda como ornamento del criterio. Declarar la correlación como criterio y abandonar el umbral, o eliminarlo | `§8.2` (`:1102-1106`), `§8.7` (`:1185`) | Media | `§8.7` (`:1185`) **ya lo declara**: «both fall below the 0.05 threshold used in the comparison script. The threshold is a heuristic, not a requirement» (0.0424 en `sweep_net_gain.py`; 0.0282 en `compare_reputation_models.py`); la correlación se fija como razón de la elección en `§8.2` (`:1102-1104`) y el barrido de `δ` vía `R_std` (`:1104`, `:1174`) no es el criterio de selección. La tensión es de **redacción** (el reviewer lee el umbral como criterio declarado, el paper lo declara heurística) y su cita (`§8.1`/`§8.6`) no es donde están los números, que viven en `§8.2`/`§8.7` | abierto, stream B (no bloquea v1) |
| **N-12** | Espacio de tipos no vacío en `§6`. «IC es tautológica» es defendible, pero la puerta de entrada al conjunto (timing, rotación, agresión de canales) puede portar información privada que el modelo ignora | `§6.2` (`:823-826`), `§6.7` (`:923-926`) | Media | `§6.7` (`:924`): «Incentive Compatibility is tautological in this mechanism. There is no private type to misreport: `T` is verified on-chain, and `S_f^*(T)` does not depend on `ω`» (registrado como F-006, `:926`); `§6.2` (`:825`): «`T` is not a private type in the sense of mechanism design»; el otro lado del argumento está en `§1.2` (`:67`): «…or---if reputation is publicly verified---must make the reporting question **vacuous**». Ninguno de los dos trata información privada **distinta de `T`** (cuándo entrar, cuándo rotar, agresión de canales), que es justo lo que señala el reviewer | abierto, stream B (no bloquea v1) |
| **N-13** | HOSVD no define qué estimador de rango usa para el caso ruidoso: el rango se fija a mano y se barre empíricamente, sin regla de selección | `§3.3` (`:354-389`), `tab:tensor-rank` (`:394-400`) | Baja | Rango fijo `(R_1,R_2,R_3) = (4,3,3)` (`:345`); `:355` «exact for tensors of rank at most … and approximate otherwise»; `:392` «the reconstruction error decreases monotonically with rank» (barrido, no estimador); `grep -niE 'rank estimat\|estimator\|elbow\|energy criterion\|scree\|parallel analysis'` → **0**: no hay regla de selección de rango para el caso ruidoso; el propio paper deja el régimen sin resolver (`:389`) | abierto, stream B (no bloquea v1) |
| **N-14** | `groth2016` no es fuente primaria de recursión SNARK. La recursión debería citar Halo/ICICLE o *cycle curves*, y fijar el framework que hoy queda explícitamente sin fijar | `§4.4` (`:542-552`), bibliografía (`:1550-1570`) | Baja | `\cite{groth2016}` aparece **una vez** (`:484`) y para la *base* del esquema, no para la recursión («Groth16 is sound with respect to the circuit»); la recursión se describe como «a Groth16 recursion over BN254» (`:546`); el paper reconoce que «The choice of recursion framework (Groth16 recursion, Plonk recursion, Halo2 recursion) is not fixed in this paper» (`:550`) y que **no mide** el tiempo de prueba (`:548`); la bibliografía (16 entradas) no incluye ninguna fuente de recursión/composición (0 hits para `halo\|plonk\|nova\|marlin\|cycle\|pasta`) | abierto, stream B (no bloquea v1) |
| **N-15** | Incoherencia interna: la tabla del equilibrio asume que el *pool* del bounty se reparte entre los auditores activos (sin dilución por *free-riding*), mientras el *free-riding* sólo se admite en limitaciones | `§7.3` (`:978-999`) y `tab:equilibrium` (`:1006`) **vs** `§10.2` (`:1321`) | Media | `§7.3` (`:978`): «The bounty is a single common pool and not a reward per auditor: it is divided among the auditors who are active, so the income of an individual auditor falls as participation grows»; `tab:equilibrium` (`:1006`) reporta «Verifier profit `+0.20`» para todo `n^*(B) ≥ 1`; `§10.2` (`:1321`) admite lo contrario: «a verifier that expects the others to audit has an incentive to free-ride on their work instead --- a dilution of the individual reward **that the model does not represent**». Numeración: la tabla es el **22.º** `\caption` del orden de fuente, no el 8.º ⇒ la cita «Tabla 8» del reviewer necesita re-cotejo contra el PDF antes de usarse | abierto, stream B (no bloquea v1) |

**Nada de esto se aplica.** Las ocho entradas son **registro**: no hay corrección
de texto, ni de cifras, ni de artefacto; no se promueven al stream A y no abren
`F-022` (que sigue atado al manifiesto de conteos). Su destino editorial es la
decisión `(e)` del bloque de Fase 5.

**Puerta de release.** Ninguno de estos siete puntos toca el ancla mientras no se
edite `main.tex` **ni** un fichero sellado. Si N-2/N-4/N-5/N-6 se cierran con
texto en el paper, el lote debe re-anclarse entero (§9 de
`implementation-plan.md`) y respetar G5/G6/G8; N-1 y N-3 son de la capa de
integración y están **fuera del ancla** (Part B, cabecera de este fichero);
**N-7 es el único que apunta a un fichero sellado** y queda diferido a Fase 5.
El registro de esta pasada no ha movido ningún hash: `main.tex` conserva
`fb5cae97…` y los 10 pares de `verification/anchor_root.sha256` se re-derivan
byte a byte (`fase0_anchor.sh --check` → exit 0; `audit-gate.sh` → PASS=11).

### Registro de la pasada consolidada (2026-10-14) — estado de FASE 0

El informe consolidado del revisor (siete reportes + auditoría G1–G12) pedía
cinco tareas de registro. Dos se aplicaron **en este fichero**; tres quedaron
**bloqueadas por el sello**. Nada sellado fue tocado.

**Aplicado aquí (no sellado, sin re-anclaje).** `A-20`, `A-21` y `A-22` en la
Parte A, con evidencia verificada línea a línea; cabecera `(19 items)` →
`(22 items)`; una fila nueva en `Summary`; tres filas en la tabla de mapeo del
apéndice; y una nota en `Recommended order` para que no entren en el lote de la
Parte A. Los gates no se ven afectados: G5 cuenta `^### F-` en
`numerical-verification.md` y G6 cuenta `^### C-` en `content-audit-pending.md`;
ninguno lee este fichero.

**Aplicado además en la pasada del 2026-10-15.** Tres registros nuevos, todos
en este fichero y todos con `grep` reproducible: (i) **`N-3` reforzado** con la
evidencia del artefacto —sigue siendo **el mismo** hallazgo que la petición
llamaba «`N-4`»; ver «Nota de reconciliación de IDs»—; (ii) **`N-7`** añadido
(refs colgantes dentro de `content-audit-pending.md`), con estado «diferido a
Fase 5» porque su objetivo está sellado; (iii) la **errata del auditor externo**
sobre «`validator` = 0 veces en §7.3» anotada con el comando y su salida exacta
(3 hits, los tres negaciones). Ninguno de los tres mueve un hash.

**Colisión de namespaces, resuelta por declaración.** El informe numera sus tres
hallazgos `N1`/`N2`/`N3`; este fichero ya usa `N-1 … N-7` para **otra cosa**.
Mapeo: informe `N1` → `A-20`; informe `N2` → `A-21`; informe `N3` → `A-22`, que
es **el mismo hallazgo** que `N-1` (publisher de `T`), cuyo listado de evidencia
es más largo. Al adoptar los siete `N-n` en una sola tanda, `A-22`/`N-1` deben
colapsar en un único ID, y `N-7` —que es el único que apunta a un fichero
sellado— debe entrar con el lote de Fase 5, no con la Parte A.

**Dos correcciones al informe, verificadas.**

(i) **El auditor externo erró en «`validator` aparece 0 veces en §7.3»: es
falso.** Comando reproducible y su salida exacta:

```
$ awk 'NR>=953 && NR<=1000 && /validator/ {print NR": "substr($0,1,60)}' docs/paper/main.tex
957: The reputation tensor $T$ introduced in Section~\ref{sec:tensor} is not
964: where $f_c$ is a public function that maps the observed consensus event
969: The commitment to the reputation tensor $T$ is produced by the data lay
$ awk 'NR>=953 && NR<=1000 && /validator/' docs/paper/main.tex | wc -l
3
```

Son **3 hits** (`:957`, `:964`, `:969`) y **los tres son negaciones** («is not
declared by the validator», «not changeable by the validator», «not by the
validator»). El error del informe no debilita el hallazgo: lo **refuerza**,
porque la definición del actor es puramente negativa. Queda notado aquí, en
`A-21` (`:461-464`) y en `N-2` (fila de tabla), es decir **tres veces**, para
que ninguna relectura futura vuelva a citar el «0 hits» como si fuera un hecho.

(ii) `G = 50` no sale del paper: es la derivación de `A-18` en este mismo
fichero (`1.0 × 500 × 0.10`). El paper escribe `S_slash = 10.0` y
`V_fraud = 1.0` (`:1028`) y el `-502` de `:1055`, ambos constantes de
`simulate_data_layer_v3.py:17-18,52`.

### Diferido a Fase 5 (registrado, no aplicado)

Lo que sigue **no** puede aplicarse ahora: toca ficheros sellados. Se registra
aquí, con evidencia, para que el lote único de re-anclaje lo recoja de una vez.
Cuatro bloques.

**(a) Los tres objetivos restantes de FASE 0**, en
`docs/audit/content-audit-pending.md` (uno de los 10 ficheros de
`verification/anchor_root.sha256`,
`32cf126e303ab229135430a40badc947f7452961b5a8a7c20f0f62e687e766ec`):

1. el overclaim «No open finding remains» (`:1707-1708`);
2. el estado de `C-01`, «cerrado» cuando la asignabilidad sigue abierta (`:46`;
   y `:155-160`);
3. las refs internas obsoletas dentro de `C-01` (hoy en `:45` y **`:69`**, no en
   `:67`), que es el hallazgo **`N-7`** de la tabla de arriba: `:45` apunta a
   `main.tex:837` y `:69` a `main.tex:805`, **ambas líneas hoy vacías**
   (`Θ = 1.0` con los parámetros de referencia vive ahora en `main.tex:870`), y
   `:69` describe `VaR_tech`, símbolo que **ya no existe**
   (`grep -n 'VaR' docs/paper/main.tex` → 0). Sustitución correcta:
   `VaR_tech` → `S_{\min}` (`main.tex:834,840,941`).

**(b) La entrada `F-022` y el manifiesto de conteos van juntos, o no van.** Hoy
la serie `F-` termina en **F-021** (`numerical-verification.md:378`) y G5 lleva
el 21 **literal** en el script (`audit-gate.sh:94`: `<n> -> 21`; `:100-101`:
`esperado 21`). Por tanto **añadir `F-022` sin desacoplar G5 del literal hace
fallar el gate por diseño**: los dos cambios son un solo cambio. Ese desacoplo
*es* el manifiesto de conteos que pide el informe, y es la razón técnica de que
ambos se difieran al mismo lote.

**(c) La tabla de fases del plan no tiene fila para este lote.**
`implementation-plan.md` §12 enumera P1 … **P7b**, y su «next step» es P7b
(Zenodo/arXiv): ni `F-022` ni el manifiesto de conteos figuran ahí. Dato útil:
`docs/architecture/implementation-plan.md` **no está sellado**
(`grep -c implementation-plan verification/anchor_root.sha256` → 0), de modo que
añadir esa fila y el detalle del lote es una edición **sin coste de ancla** y
puede hacerse **antes** del lote sellado.

**(d) Prohibiciones explícitas**, mientras el autor no fije D-2/D-3/D-4 y M-05:

- **no** editar `content-audit-pending.md` (rompe el sello y con él G1/G10);
- **no** añadir `F-022` ni retocar `numerical-verification.md` sin el manifiesto
  de conteos en el **mismo** cambio (G5 quedaría en FAIL);
- **no** re-anclar por partes: §9 exige **un** lote (cabecera de este fichero);
- **no** promover `N-1 … N-7` a `B-n`/`D-n` antes de que `A-22`/`N-1` colapsen.

**(e) Destino de `N-8 … N-15`: decidir el encaje editorial antes de aplicarlos.**
Las ocho entradas del *stream* B están **registradas y abiertas** y no se
aplican antes de que el autor decida una de dos:

- **entran en arXiv v1** como **correcciones de texto** (título/`§1.2`, `§3.3`,
  `§4.4`, `§8`, `§10.2` y la bibliografía), sin tocar cifras, sin tocar el
  artefacto y con su propio re-anclaje completo si `main.tex` se mueve; o
- **esperan a v2**, junto con una eventual respuesta al reviewer.

Mientras la decisión no exista, este fichero no los toca: no abren ninguna
decisión de la Parte A, no abren `F-022` y no entran en el lote de re-anclaje.

Sin decisión del autor, la Parte A no se toca y nada sellado se edita. Los
cinco bloques son **registro**, no trabajo pendiente que este fichero pueda
ejecutar por sí solo.

### Respuestas directas a las cuatro preguntas del autor (2026-10-15)

Evidencia re-verificada línea a línea en esta pasada; los IDs remiten a los
hallazgos de arriba (`N-n`) y a la Parte A (`A-nn`).

**1. ¿Quién es el `sequencer`?** Es `AVIPRegistry.sequencer`, un `address`
público fijado en el constructor con la única validación `ZeroSequencer`
(`AVIPRegistry.sol:56,71-75`). Es el **único** autorizado a publicar
compromisos (`postCommitment`, `:99-102`) y el único que puede rotar su propia
posición (`setSequencer`, `:86-91`) y cambiar el verificador (`setVerifier`,
`:93-96`). **No hay ningún vínculo con el conjunto de validadores**: `grep -c
'sequencer'` da 0 en `AVIPValidatorManager.sol` y en su interfaz ⇒ no se exige
que sea validador, ni stake, ni que sea slashable, y por tanto **no está cubierto
por `C_R`**. No hay timelock ni gobernanza; el propio contrato lo documenta como
"Testnet-stage governance: the sequencer rotates itself" (`:86-88`). Ninguno de
los dos setters emite evento, así que las rotaciones son invisibles para
indexadores, y `setVerifier` no valida `address(0)` (`:95`): un
`setVerifier(address(0))` desactiva la certificación en silencio porque
`verifyThreshold` revierte `VerifierNotSet` (`:174-175`) — DoS, no robo. El
paper **no menciona el rol en absoluto** (`grep 'sequencer' docs/paper/main.tex`
→ 0). Veredicto: suposición de confianza estructural no declarada → `N-1` /
`A-22`, bloqueado en **D-2**.

**2. ¿El paper atribuye `T` a «la capa de datos»?** Sí, y sólo así: "The
commitment to the reputation tensor $T$ is produced by the data layer, not by
the validator" (`main.tex:969`), precedido de "is not declared by the validator"
(`:957`) y "The formula is not changeable by the validator" (`:964`). Son las
**3** únicas menciones de `validator` en §7.2-§7.3 (el informe decía 0; es falso)
y **las tres son negaciones**: el actor se define sólo por lo que *no* es. La
frase es verdadera y a la vez elude el punto, porque el artefacto entregado sí
tiene un actor positivo —la EOA `sequencer`— sin stake. → `N-2`, mismo hecho que
`A-22`.

**3. ¿Es `0.10`/`γ`/`k=10` vacuo?** Sí, y hay que separar cuatro capas:
(i) **numérica, admitida por el paper**: `main.tex:1040` escribe que con
`γ = 0.10` y `k = 10` epochs, `γ·k = 1.0`, "the maximum fraudulent fraction is
1.0 --- the whole tensor --- so there the bound **permits everything and
constrains nothing**", y da las alternativas que sí muerden (`γ = 0.05` → 0.5;
`γ = 0.02` → 0.2). El valor de referencia del paper es exactamente el que anula
la garantía con horizonte 10.
(ii) **de parámetro**: el contrato lo hard-codea como `GAMMA_BPS = 1000`
(`= 0.10`, `public constant`, `AVIPRegistry.sol:45-46`) con
`MAX_DELTA_ENTRIES = (500·1000)/10000 = 50` (`:51-52`): **sin setter ni evento**
⇒ cambiar `γ` exige redesplegar.
(iii) **de cumplimiento**: el bound se comprueba contra el delta **declarado**
por el propio publicador (`_changedEntries[epoch] = changedEntries`, `:115`;
"as declared when it was posted", `IAVIPRegistry.sol:91-93`), no contra un delta
recomputable; `verifyThreshold` certifica la **norma** (`[root, epoch,
certifiedNorm]`, `:187-190`), no el delta ⇒ subdeclarar el delta hace pasar el
check.
(iv) **de trazabilidad**: `simulate_data_layer_v3.py` no tiene `gamma` (`grep` →
0) y la fila de frescura de `tab:sec7-summary` (`main.tex:1057`) está clasificada
*Analytical* con script **`---`**. → `N-6`.

**4. ¿Frescura frente a obsolescencia (*staleness*)?** En el paper «frescura» es
propagación **entre epochs** (`γ·k`), una cantidad en número de epochs, no en
tiempo (`:973`, `:1033-1040`). En cadena **no hay eje temporal**: `grep
'block.timestamp'` sobre todo `integrations/avalanche/contracts/` da **1**
coincidencia y es un `emit` (`AVIPRegistry.sol:119`) — el timestamp se registra y
**nunca se lee**; `grep 'Expired|deadline|challengeWindow|CHALLENGE'` → **0**.
El epoch es un **contador sin duración**: `expected = _empty ? 0 : _latestEpoch +
1` (`:105-106`) y `latestEpoch()` devuelve `type(uint256).max` si está vacío
(`:143-145`); se exige secuencialidad, **no puntualidad**, así que el publicador
puede quedarse en el epoch `t` indefinidamente y un root obsoleto nunca caduca.
La adjudicación es instantánea y sin estado: `verifyThreshold` es `view`
(`:166-169`) y en la capa entregada `adjudicate(root, published, formula,
window)` (`src/datalayer/src/ingestion.rs:251-256`) no recibe **ningún**
argumento de tiempo. Finalmente, el `Window` de la ingesta no es un intervalo:
son tres contadores `u32` (`:75-82`) y `h` es la clave que pone el llamante
(`:72-73`), luego la vaguedad "events in window `h`" (`eq:ingestion`,
`main.tex:960`) no está acotada en tiempo en ningún artefacto. → `N-3`.

**Consecuencia común.** Los cuatro puntos son el mismo hueco de modelo visto
desde cuatro ángulos: el paper escribe garantías **negativas** (lo que el
validador no puede hacer) y el artefacto las satisface literalmente, pero el
actor que **sí** controla `T` —el `sequencer`— no aparece en el paper, no tiene
`γ` propio, no tiene ventana temporal y no está cubierto por `C_R`. Cerrarlos
exige **D-2/D-3/D-4** (modelo del publicador, del tiempo y de la frescura) y
**M-05** (modelo de ataque con pérdida ejecutable); hasta entonces, `A-20 … A-22`
y `N-1 … N-6` permanecen abiertos y registrados, sin tocar el ancla. **`N-7`**
(refs colgantes dentro de `content-audit-pending.md`) es el único de los siete
puntos cuyo objetivo está sellado: no espera a D-2/D-3/D-4, sino al lote único
de Fase 5, junto a `F-022` y al manifiesto de conteos (ver «Diferido a
Fase 5»).

### Cierre técnico de D1–D4 (verificado 2026-10-15; **cerrado por el autor el 2026-10-15**)

Los tres ajustes de la verificación se aceptaron y las decisiones quedaron cerradas:
alcance **(B)**, secuenciador **(B)** + estado declarado, importe **(A)**,
reputación **(B)+(C)**. El eje temporal se resolvió aparte como **`DEC-3`**
(constraint declarada, enforcement on-chain diferido) y `γ` queda en **`DEC-6`**
(abierto, no bloquea). El espacio de nombres pasa a ser **`DEC-1 … DEC-6`** para
contenido y **`D-1 … D-4`** para el proceso de release, con el remapeo de `:440`,
`:482`, `:507`, `:819` y `:1288` incluido en el bloque de ejecución.

**El bloque de ejecución vive en `docs/architecture/implementation-plan.md` §12.1**
(fuera del ancla: `grep -c implementation-plan verification/anchor_root.sha256` →
0), con las unidades `M9a/M9b/M9c` para el contrato y `P8.x`/`P9.x` para el paper.

Verificación independiente de las cuatro fichas contra los contratos y `main.tex`.
Las cuatro recomendaciones **se confirman**; dos necesitan ajuste de razón, una de
coste, y hay **dos bloqueos** que resolver antes de escribir las instrucciones de
Fase 4. Nada de esta subsección está aplicado.

**Bloqueo 1 — `D-n` está triplicado en este fichero.** (a) La Parte D (`:728-757`)
usa `D-1 … D-4` para el **proceso de release** (DOI, re-anclaje, no enviar antes de
aplicar A, constantes del gate). (b) La Parte A los usa para **decisiones de
contenido**: `D-2` = publicador de `T` (`:507`), `D-4` = «¿reputación ejecutable o
declarativa?» (`:440`), `D-3`+`D-4` = ventana de detección y pérdida ejecutable
(`:482`), y `:1288` los resume como «publicador, tiempo y frescura». (c) La lista de
cierre: `D1` alcance, `D2` secuenciador, `D3` importe, `D4` reputación. Colisionan
**`D1`** (alcance vs DOI de Zenodo) y **`D3`** (importe vs tiempo). Propuesta:
reservar `D-1 … D-4` para el release (ya tabulados con consecuencia) y renombrar el
contenido a **`DEC-1 … DEC-6`**: `DEC-1` alcance/custodia, `DEC-2` publicador de
`T`, `DEC-3` eje temporal y ventana, `DEC-4` importe del slash, `DEC-5` reputación
ejecutable, `DEC-6` valor de `γ` (`N-6`, opcional). Remapear `:440`, `:482`,
`:507`, `:819`, `:1288`.

**Bloqueo 2 — falta la decisión temporal (`N-3`) y `M-05` la exige.** `A-21` pide
«an explicit detection window» (`:482`) para poder escribir el modelo de ataque, y
el artefacto no tiene eje temporal: `block.timestamp` aparece **una** vez en todo
`integrations/avalanche/contracts/` y es un `emit` (`AVIPRegistry.sol:119`), nunca
se lee. Cerrar D1–D4 como están deja `M-05` sin parámetro y `N-3` sin decisión.
Opciones: (i) abrir `DEC-3` como bloqueante de `M-05`; (ii) declarar que el
timelock de `D2` fija la escala temporal — hoy no lo hace, porque **no hay
timelock**.

**D1 — alcance: (B), con corrección de razón.** El sujeto de `:976` («does not move
funds») es **la capa de datos**, no el sistema: la frase es literalmente cierta del
servicio off-chain, y quien mueve fondos es el manager (`AVIPValidatorManager.slash`
→ `custody.debit`, `:262-264`). El defecto no es una frase falsa, es un **actor
ausente**: el paper nombra «the delivered manager» **una** vez (`:1028`), nunca
nombra el vault (`grep 'StakeVault\|Vault'` → 0) y usa `custody` **una** vez, en
«chain of custody» (`:1493`). Con (B) hay que **añadir los dos sujetos y calificar**
`:976`, no borrarla.

**D2 — secuenciador: (B) + declarar el estado, con tres matices.** (i) El lote ya
tiene un fallo registrado que entra gratis: `setVerifier` **no comprueba
`address(0)`** (`AVIPRegistry.sol:93-96`) y con el verificador a cero
`verifyThreshold` revierte `VerifierNotSet` (`:174-175`) — certificación desactivada
en silencio, la dureza barata de `B-1`/`N-1`. (ii) El **multisig** es lo que cierra
la captura (autoridad **distinta** de la clave actual); el **timelock** sólo hace la
rotación visible y reversible y los eventos sólo trazable: un timelock sobre el
mismo rol no cierra nada por sí solo. (iii) «Verificador mutable» no es preferencia
sino consecuencia del código: el verificador es *storage* con setter y el historial
de compromisos vive en el **registry** (`_roots`, `_changedEntries`,
`AVIPRegistry.sol:63-65`), que `admit` consulta (`AVIPValidatorManager.sol:216-219`)
⇒ congelarlo convierte un bug de circuito en un **redespliegue
del registry** que se lleva por delante el historial del que depende la admisión.
Coste real: **≈40–60 líneas** (dos flujos de dos pasos + dos retardos + 4 eventos)
más tests, no ~20, y estrena las **primeras lecturas de `block.timestamp`** del
árbol de contratos.

**D3 — importe del slash: (A), con un argumento más fuerte y una corrección.** Hoy
el importe lo decide **el mensaje remoto**: `AVIPSlashingChannel.sol:185` ejecuta
`MANAGER.slash(validator, notification.amountWad, reason)`, y `amountWad` viene del
payload (`AVIPMessageCodec.sol:138`), validado sólo como no-cero (`:343`) y ≤ stake
(`AVIPValidatorManager.sol:242`). (A) **elimina un parámetro remoto**: el importe
pasa a ser función del estado del contrato. Corrección: **`L` no es `S_f*`**, es el
stake **posteado entero**, y `admit` no pone techo (`financialStake >= stake`,
`:200`; `_stakes = financialStake`, `:229`) ⇒ `L ≥ S_f*(T) ∈ [0.2, 1.0]` **sin cota
superior**. Consecuencias de texto: `:1028` («at least `S_f*`») sale reforzada, pero
su «**caller-supplied amount**» pasa a ser **falso** y debe reescribirse en el mismo
lote; y el «bounded by `Θ = 1.0` per validator» de `:1266` es la convención de
cobertura del **modelo**, no una cota ejecutable. Coste real: la firma de `slash`
propaga a `IAVIPValidatorManager`, `AVIPSlashingChannel:185`, `AVIPMessageCodec`
(`amountWad`, `ZeroSlashAmount`), `M7dTransport.t.sol` y `M8StakeVault.t.sol` ⇒ es
cambio de **contrato**, no sólo de texto (fuera del ancla, pero no gratis).

**D4 — reputación: (B) + (C) honesto, con restricción de implementación.**
`collateralFor` y `requiredStakeFor` son **puras del norm** (`:142-151`) y `admit`
deriva de ellas `collateral` y `stake` (`:200-201`, `:229`). Si (B) se implementa
**inflando** `requiredStakeFor`, `_requiredStakes` deja de ser la imagen on-chain de
`C_R` y `Θ − C_R` puede volverse **negativo** con muchas eyecciones ⇒ (B) debe ser
un **recargo aparte**: `required = requiredStakeFor(norm) + surcharge(ejections)`,
con `collateral` todavía derivado del norm. La variante «retardo mínimo ≥ ventana»
exige leer `block.timestamp`, que hoy nunca se lee (Bloqueo 2): se recomienda la de
**recargo**, que no necesita eje temporal y encaja con la eyección por estado
(`:249-256`). Se confirma retirar o calificar `:1030` (afirma una reducción de
reputación que `slash` no escribe). El reencuadre alcanza a «reputational
**collateral**» (abstract) y a «partial substitutes» (`:76`); el **título sobrevive**
(«Reputation-Weighted Validator Selection» describe exactamente el descuento).

**Consecuencias de gate en Fase 4.** `main.tex` es la línea 1 de
`anchor_root.sha256` ⇒ **G10/G11 en FAIL** desde la primera edición hasta el
re-anclaje único de Fase 5 (esperado; no hay re-anclaje parcial). Dos trampas
**dentro** de Fase 4: **G8** (ninguna línea con `Estimate` y `Verified` a la vez al
reescribir las tablas de estado) y **G5** (el abstract lleva en prosa «twenty-one
claims», que es carga útil del `21`; `M-05` **no** debe emitir un `### F-` nuevo
salvo que el mismo lote suba la constante — el lote de tres sellados de `D-4`).
`integrations/` está **fuera** del ancla: los cambios de contrato de D2/D4 no
re-anclan, pero invalidan el «Status» de `integrations/avalanche/contracts/README.md`
y el §5.12 del plan. **Decisión de secuencia pendiente:** si (B) de D2 se entrega en
esta release, §10.2 declara **(B)** como estado entregado; si no, declara **(A)** —
el texto debe coincidir con lo desplegado en el momento del sellado.

**Nada aplicado todavía.** Esta subsección es **registro**: `main.tex` intacto, los
10 ficheros sellados intactos, `N-8 … N-15` siguen «abierto, stream B». Las
instrucciones de ejecución están emitidas en `implementation-plan.md` §12.1 y el
orden es forzado: **M9** (contrato, cero riesgo de ancla) → **P8** (texto del paper)
→ **P9** (lote sellado y **un** re-anclaje).

