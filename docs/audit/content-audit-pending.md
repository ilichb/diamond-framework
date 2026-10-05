# Content Audit — Pending Findings

Working notes for the content audit of `docs/paper/main.tex`. This file
lists the technical findings raised during the initial review (C-01…C-10),
plus the findings raised by the auditor during verification (C-11), their
verification status, and the proposed order of attack.

It is not a paper artifact. It is an audit worksheet: a place to record
what is suspected, what has been confirmed, and what still requires a
model or a script before any correction is proposed.

## Methodology

Every finding below is processed as:

1. **Model** the discrepancy explicitly (equation, script, or null hypothesis).
2. **Verify** locally with a reproducible script under `verification/`.
3. **Record** the outcome: confirmed, refuted, or refined.
4. **Propose** the correction only after the outcome is recorded.

No finding is corrected in `main.tex` before it is verified. Findings
that cannot be verified are marked with the local worksheet status
`Unverified` (the paper's own marker for unverifiable claims is
`[CONJECTURE]`, per `CONTRIBUTING.md`).

## Status legend

- **Confirmed** — reproduced locally with a script, discrepancy is real.
- **Partially confirmed** — some components reproduced, others not; or
  one component confirmed and another refuted; or the qualitative claim
  holds but the precise figure has not been reproduced.
- **Refuted** — reproduced locally, discrepancy is not real.
- **Conceptual** — the structural issue is clear from reading the
  paper, but no numerical verification has been attempted yet.
- **Unverified** — raised as a suspicion, no reproduction attempted.

## Findings

### C-01 — ZK proof returns a bit; payment rule needs a value

**Location:** §4.1 (threshold proof) and §6.3 (allocation rule);
`Theta = 1.0` at `main.tex:786` (§6.4).
**Status:** Confirmed.
**Severity:** Structural.

The proof of §4.1 demonstrates `||T||_F >= Theta_r`, a boolean. The
allocation rule of §6.3, `S_f*(T) = max{VaR_tech, Theta - C_R(T)}`,
requires `C_R(T)` as a continuous function of the tensor norm. No
mechanism bridges the boolean and the continuous value.

**Evidence:** `verification/zk/threshold_quantization.py` quantizes the
gap using the paper's own numbers (`Theta_r = 0.5` from the §4.2 exploit
table, `T ~ U[0,3]`, `C_R(x) = 0.8x/(1+x)` from `fee_specification.py`).
The bit accepts `||T|| in [0.5, 3]`, over which `C_R` spans
`[0.266667, 0.600000]` and `S_f*` spans `[0.400000, 0.733333]`. The
protocol must therefore either over-collateralize the top of the band by
83.3%, or charge the minimum-margin policy (`S_f* = 0.4`, the top of the
`||T||` band) and violate `CoA` for the bottom of the band by 0.333333
(33.3% of `Theta`). With `k` stepped thresholds the error falls as
`0.333333/k` (optimal placement uniform in `C_R`), at one extra range
proof per threshold; on-chain gas stays constant (~250k) under recursion,
so the marginal cost is off-chain.

**Adjacent discoveries (block the numerical resolution):** `Theta_r` has
no numeric value anywhere in the repo; `VaR_tech` appears once, in
`main.tex:754`, and is never defined or valued (recorded as C-11);
`C_R` carries three incompatible definitions (the §2.5 integro-PDE value
function in a scalar `r`, the tensor-valued `C_R(T)` of §6.3, and
`0.8x/(1+x)` in `fee_specification.py`), which overlaps C-04.

**Resolution (two layers):** §4.3 defines and §4.4 adopts Option B
(Pedersen + Bulletproofs, zero R1CS constraints), which restores binding
and thereby rescues the misreporting argument of §6.2 (`main.tex:746`)
that §4.2 had refuted for the original design (`main.tex:450`). This
closes the soundness layer. It does not close the allocability layer:
Option B never opens the tensor (`main.tex:423` forbids it), and
`C_R = 0.8x/(1+x)` is nonlinear while Bulletproofs is native to
linear/inner-product and range statements. How `C_R(T)` reaches the chain
is unspecified.

**Open question:** single threshold (accept the 83.3% over-collateralization),
stepped proof with `k` thresholds (cost grows off-chain), or a new
commitment scheme, or a linear `C_R` expressible over the commitment
(design proposal, not a consequence of the text)? Each choice has
different cost implications.

**Next step:** state the `C_R` functional form, `Theta_r` and `VaR_tech`
in §6 (the soundness design is already decided in §4.4), or label the gap
`[CONJECTURE]` and present §6.3 as a design proposal.

### C-02 — Pedersen commitment not bound to the consensus-derived tensor

**Location:** §3.5 ("proof operates on the committed tensor") and
§7.2 ("committed via state inclusion proofs").
**Status:** Conceptual.
**Severity:** Structural.

Neither section specifies who creates the Pedersen commitment. If the
validator creates it, the same class of unsoundness corrected in §4
(F-012) reappears at the data layer: the validator chooses `T` freely
and proves the norm of a fabricated tensor. If the data layer creates
it, the binding mechanism between the commitment and the events of
§7.1 is unspecified.

**Next step:** model both scenarios, quantify the exploit cost, and
identify which protocol component must own the commitment.

### C-03 — MFPT formula ignores the jumps

**Location:** §2.3 (equations 2.4 and 2.5).
**Status:** Confirmed by the agent.
**Severity:** Moderate.

The mean first-passage time is computed for the CIR diffusion without
jumps. §2.1 defines the reputation process as CIR **with multiplicative
downward jumps**. The whitewashing bound therefore does not apply to
the process as defined.

**Evidence:** `verification/stochastics/mfpt_bound_explicit.py`
implements the drift+diffusion formula and reproduces the reported
values (11.2203, 443.7374). The paper does not compute an MFPT for the
jump-diffusion; no such script exists under `verification/`.

**Next step:** compute the MFPT for the jump-diffusion, or re-scope the
claim to the no-jump sub-process.

### C-04 — Section 2 is never used downstream

**Location:** §2 (CIR), §6.5 (`T` scalar in `[0,3]`), §8 (`net_gain` in `[0,1)`).
**Status:** Confirmed.
**Severity:** Structural.

Three distinct objects:
- §2: CIR diffusion with jumps, unbounded, mean 1.
- §6: `T` treated as a scalar uniform on `[0,3]`.
- §8: `net_gain` deterministic ODE on `[0,1)`.

No section reconciles them. §2 appears decorative.

**Next step:** determine which process is intended to be canonical, and
align §6 and §8 to it or explicitly justify the divergence.

### C-05 — Asym explanation in §5.2 is conceptually wrong

**Location:** §5.2, paragraph beginning "The normalization is
inappropriate for detecting cliques", and the spectral table above it.
**Status:** Confirmed by committed scripts:
`verification/rmt/asym_weights.py` for the per-pair weight mechanism,
and `verification/rmt/clique_spectra_seeds.py` for the single-seed
nature of the table.
**Severity:** Moderate.

The paper compares only the per-edge weight (`1/27.2` vs `1/20`) and
concludes the clique signal is cancelled by degree increase. It ignores
that clique edges are DENSITY_FACTOR times more probable: the expected
per-pair weight of an intra-clique pair is 10x the expected per-pair
weight of a background pair under W, and either 10x or at least 7.4x
under A_sym depending on the background denominator. Under either
reading, the clique signal is not cancelled by the degree increase; it
is reduced by a normalization factor that the paper does not compute.
Whether the residual is detected depends on the finite-size position
of the bulk edge, which the paper does not state.

Separately, the spectral table reports single-seed values for the
leading gap of W (`+1.6996`), A_sym (`-0.0156`) and B (`+1.7569`),
without stating that they come from one seed or that they are
atypical for W and B.

**Evidence:** two committed scripts.
(a) `verification/rmt/asym_weights.py` (committed in `6d0b91c`)
    computes the expected per-pair weights in closed form. Under W:
    intra-clique 0.400802 vs background 0.040080, ratio 10.0000.
    Under A_sym with the H1 model-consistent background degree
    (27.214): 0.014925 vs 0.001473, ratio 10.1343. Under A_sym with
    the null-model degree cited by §5.2 (20.000): 0.014925 vs
    0.002004, ratio 7.4478. Under either denominator, the clique's
    per-pair weight exceeds the background's by more than 7.
(b) `verification/rmt/clique_spectra_seeds.py` (committed in
    `cc6c06c`) reruns the same generator as `clique_spectra.py` over
    200 seeds:
    - W: gap mean +0.73, std 0.39, P(gap > 0) = 0.980;
      the single-seed value cited by the table (+1.6996) is at P99.
    - A_sym: gap mean -0.02, std 0.01, P(gap > 0) = 0.005;
      the cited value (-0.0156) is at P90.
    - B: gap mean +0.77, std 0.41, P(gap > 0) = 0.980;
      the cited value (+1.7569) is at P99.
    - P(lambda > q99 = 9.0542): 0.940 for both W and B (all seeds),
      0.937 excluding the first 10 seeds.
    - The paired claim gap_B > gap_W is structural (Weyl interlacing:
      B = W - dd^T/(2m) with the subtracted matrix positive
      semidefinite of rank one, so lambda_1(W) >= lambda_max(B) >=
      lambda_2(W) for every graph). The empirical content is the mean
      difference +0.0353, small against the per-seed std.

The first-order BBP prediction (force of the spike, detection
threshold, normalization factor, predicted gaps) is not implemented.
Stop rule applied: two of the required formulas lack a verifiable
reference or a self-contained derivation, and the naive margin
theta/sqrt(D_BAR) does not reproduce the observed gap within a factor
of 2. This part remains [CONJECTURE].

**Next step:** two edits to §5.2. (a) Rewrite the mechanism
paragraph to state the per-pair weight argument (10x under W, >7x
under A_sym regardless of the background denominator) instead of the
per-edge weight comparison. (b) In the table caption, state that the
values are one draw from `clique_spectra_seeds.py`; report the mean
and std over seeds, or cite the single-seed values as representative.
The first-order BBP mechanism is left as [CONJECTURE] pending a
citable reference.

### C-06 — Censoring test disagreement

**Location:** §2.3, paragraph reporting the censoring test.
**Status:** Partially confirmed.
**Severity:** Minor.

The censoring test yields 635.7; the exact MFPT is 443.7. The paper
reports both figures and characterizes the relationship as agreement
"on the qualitative structure" (finite, grows with R_0, dominated by
alpha/sigma_0^2). It does not discuss the 43% numerical gap. Not
recalculated by the agent.

**Next step:** reproduce the censoring test locally; verify the 635.7
figure. Once verified, determine whether the paper's "qualitative
structure" characterization is sufficient or whether the 43% gap
warrants explicit discussion.

### C-07 — −502 is the seed-42 Monte Carlo realization; the model value is −500

**Location:** §7.4, attacker profit column.
**Status:** Cerrado.
**Severity:** Minor.

**Evidence (original):** `-502` appears verbatim in
`verification/data-layer/results/simulate_data_layer_v3_output.txt`.
The paper's declared parameters were read as giving `-450`. The
52-unit gap was unexplained by the text.

**Resolution:** The gap decomposes exactly as `52 = 50 + 2`.

- `50` is the profit convention. The script credits `V_fraud`
  only on undetected frauds
  (`(n_frauds - n_detections) * V_FRAUD - n_detections * S_SLASH`,
  line 52 of v3). At coverage 1.0 this collapses to
  `-S_slash * n_frauds`, giving analytic value `-500`. Crediting
  `V_fraud` on all frauds gives `-450`; that convention is not
  used, because detected frauds are reverted rather than rewarded.

- `2` is the Monte Carlo deviation. With `RNG_SEED = 42` and
  `N_EPOCHS = 500`, `mean_mc = -502.000000`,
  `z_vs_analitico = -0.894427`, `p_bilateral = 0.371093`,
  `IC95 = [-506.382693, -497.617307]`, which contains `-500`.

`-502.00` therefore IS reproducible byte-for-byte from the
declared parameters (seed 42). It is not the model value: it is
the seed-42 realization. The model value under the script's
profit convention is `-500.00`.

**Scripts:**
- `verification/data-layer/simulate_data_layer_v3.py`
  (md5 `2920cb7b054b787a1bcad3a422cdede2`) — canonical,
  produces `-502.00`.
- `verification/data-layer/attacker_profit_analytical.py`
  (md5 `155b9f18cf54d24bfdfe6f238389eee0`,
  output md5 `a07636b54aec9ef6f2ef0a17b1bd89ac`) —
  closed-form vs MC, deterministic byte-for-byte.

**Next step:** decide whether §7.4 declares the profit convention
explicitly. If not, this is a separate finding (paper-level
ambiguity), not a continuation of C-07. C-07 itself is closed.

### C-08 — Revenue column in §6.6 does not discount excluded validators

**Location:** §6.6, table of `F_0` vs revenue.
**Status:** Cerrado.
**Severity:** Minor.

Two distinct claims were bundled originally.

**(a) Refuted.** §6.6 does not contradict the paper's "optimal"
`F_0*`: the text defines "optimal" as the largest value preserving IR
for all types (`main.tex:772` before the edit; §6.6 after), not as
revenue-maximizing.

**(b) Confirmed and repaired.** The revenue column reported gross
revenue. At `F_0 = 0.06`, 0.2% of validators violate IR; the table
showed `60.00`, while the net revenue after excluding those validators
is `59.88`. The script computed `f0 * N_VALIDATORS` without subtracting
the excluded validators.

**Resolution:** Two parts.

1. New script `verification/mechanism/fee_specification_net.py`
   (md5 `5df811eb975d42bea4febc1e45a73ec8`, output md5
   `6a088920edeacd9263d56c8ec64d97c9`) reproduces the canonical
   fee specification and adds a net-revenue column. Deterministic
   byte-for-byte, seed 42, same RNG consumption order as the canonical
   script. Verifies:

   - `U_min(F0*) = 0.009747`, identical to canonical.
   - `U_min(1.2 F0*) = -0.000253`.
   - `n_excluded(1.2 F0*) = 2`, `gross = 60.00`, `net = 59.88`.
   - Asserts of exact equality, no intermediate rounding.

2. `docs/paper/main.tex` §6.6 (Sensitivity) now reports a four-column
   table (`Fraction with U < 0`, `Gross revenue`, `Net revenue`) and
   states explicitly that the linear trade-off holds for gross, and
   that net at `F0 = 0.06` is `59.88`. The edit is confined to the
   table and the paragraph immediately following; no labels, captions,
   numbering, environment, or `\resizebox` were touched.

**Evidence:**
- `verification/mechanism/fee_specification.py` (md5
  `2cd0272a11b7eaedaf6acec0d901466b`) — canonical, unchanged.
- `verification/mechanism/results/fee_specification_output.txt`
  (md5 `f8a19bc06917816f0ec10dae1bd87a45`) — canonical, unchanged.
- `verification/mechanism/fee_specification_net.py` (md5
  `5df811eb975d42bea4febc1e45a73ec8`, output md5
  `6a088920edeacd9263d56c8ec64d97c9`) — new.
- `docs/paper/main.tex` md5 `9206ebb4538425cf9313afdc2f3b6349`
  before the edit, `8ed4e6c7ddbf438a00c4f8205bb1486b` after.

**Next step:** none. C-08 is closed by construction of the net column
and the explicit statement of the gross linearity. The two scripts
remain unversioned in `results/`; whether to add their captured output
files (with README lines) is a separate housekeeping decision, not part
of this finding.

### C-09 — Bootstrap standard deviation does not match

**Location:** §8.2 and §8.7.
**Status:** Partially confirmed.
**Severity:** Moderate.

The paper reports `R_std = 0.0282` (in `compare_reputation_models.py`)
and `0.0424` (at the sweep optimum). The agent measures ≈0.114 with an
independent reproduction. The maximum of the sweep falls at
`mu/g ≈ 1.0`, not `1.5`.

**Caveat:** the discrepancy may be a definitional difference in
`R_std` (across validators at a fixed epoch vs across time). The agent
could not conclude error without seeing the script's definition.

**Next step:** read `compare_reputation_models.py` and
`sweep_net_gain.py`, establish the exact definition of `R_std`, and
reproduce the reported values or document the definitional gap.

### C-10 — Heavy-tail robustness claimed but not measured

**Location:** §1.1 (Introduction requires robustness to heavy-tailed
graphs) and §5.6/§5.7 (calibration on Erdős–Rényi and Chung–Lu only).
**Status:** Unverified.
**Severity:** Minor.

The Introduction motivates the collusion test by the need for
robustness against heavy-tailed interaction graphs. Section 5 does not
report any heavy-tail calibration. The `2·sqrt(d_bar)` bulk edge for
`B` holds for nearly-regular graphs; its validity on heavy-tailed
degree distributions is not established.

**Next step:** add a calibration on a heavy-tailed graph model (e.g.,
Chung–Lu with power-law weights) and report the null quantile shift.

### C-11 — The allocation rule uses symbols the paper never defines

**Location:** §4.1 (`Theta_r`) and §6.3 (`VaR_tech`).
**Status:** Confirmed (textual, by exhaustive grep).
**Severity:** Minor.

`Theta_r` is the threshold of `eq:threshold` (`main.tex:426`). It appears
four times in the paper, always symbolically (`main.tex:316`, `:426`,
`:432`, `:435`), and has no numeric value anywhere in the repository.
The only threshold actually used in a table is `0.5`, in the §4.2
exploit (`main.tex:444-445`).

`VaR_tech` is worse: it occurs once in the entire paper, inside the
allocation rule (`main.tex:754`), and is never defined, valued, or cited.
The floor it is meant to impose cannot be evaluated from the text.

**Evidence:** `grep -rnF 'Theta_r'` over the repo returns only the four
`main.tex` lines above and this worksheet; `grep -nF 'VaR'` over
`docs/paper/main.tex` returns only `:754` and `:1011`, where the
bootstrap policy uses it again unvalued. Reproducible by inspection.

**Next step:** define and calibrate both symbols, or label any chosen
value `[CONJECTURE]`.

### C-12 — §6.2 presupposes the §4.3-4.4 repair without citing it

**Location:** §6.2 ("Verified Reputation") vs §4.2-4.4.
**Status:** Confirmed (textual, by inspection).
**Severity:** Structural.

§6.2 asserts that the threshold proof binds the validator to a specific
tensor: "the proof binds the validator to a specific tensor, and the
verifier checks the binding" (`main.tex:746`). This claim holds only
under the Option B repair of §4.3-4.4, because §4.2 had explicitly
refuted the binding property of the original design ("There is no
commitment binding the prover to any specific tensor", `main.tex:450`).

§6.2 does not cite §4.3-4.4. A reader arriving at §6.2 from §6.1
encounters an assertion whose truth depends on a repair specified two
sections earlier and never referenced.

**Evidence:** `main.tex:746` vs `main.tex:450`. The dependency is
reproducible by inspection.

**Next step:** add a forward reference from §6.2 to §4.3-4.4 (or vice
versa), making the dependency explicit.

### C-13 — `C_R` has three incompatible forms, none of them the EDO of §2.5

**Location:** §2.5 (`C_R(r)`, scalar EDO); §6.1, §6.3, §6.5 (`C_R(T)`, tensor, `main.tex:733`, `:754`, `:798`); §8.1, §8.3 (`C_R(0)`, `C_R(R(t))`, scalar, `main.tex:964`, `:1011`); `verification/` (`c_r(norm_T)`, `c_r(R)`).

**Status:** Confirmed (textual + executable evidence).
**Severity:** Structural.

§2.5 defines `C_R(r)` as the viscosity solution of an integro-differential equation in a scalar `r`, with `C_R(0) = 0` (`main.tex:274-281`). §6.1 and §6.3 write `C_R(T)`, a function of the reputation tensor. §8.1 and §8.3 write `C_R(0)` and `C_R(R(t))`, scalar arguments, even though the preceding sentence names the tensor `T`. The executable scripts use a third object: `c_r(norm_T)` in `mechanism/fee_specification.py:41` and `zk/threshold_quantization.py:56`, or `c_r(R)` in four bootstrap scripts. All implement `0.8·x/(1+x)`, but `x` is `‖T‖_F`, `R`, or the tensor norm sampled in `[0,3]` depending on the script.

Three forms, no declared map `T → r`. The paper never states that `C_R` depends on `T` only through `‖T‖_F`.

**Evidence:** three separate verifications.
(i) `grep -nF 'C_R' docs/paper/main.tex` shows the scalar EDO at `:274-281`, the tensor form at `:733`, `:754`, `:798`, and the scalar `C_R(0)` / `C_R(R(t))` at `:964`, `:1011`.
(ii) `grep -rnE '\bc_r\b' verification/ --include='*.py'` shows the executable forms at `mechanism/fee_specification.py:41`, `zk/threshold_quantization.py:56`, and four bootstrap scripts (all `0.8·x/(1+x)` with `x = norm_T` or `x = R`).
(iii) The §2.5 EDO has **zero implementation** in the repository: the search over `.py`, `.pyx`, `.jl`, `.m`, `.nb`, `.sol`, `.rs`, `.ts`, `.go`, `.c`, `.cpp`, `.h` returns only one textual match, in a comment inside `zk/threshold_quantization.py:183`. The literal `eq:integro` appears only at its own definition (`main.tex:278`); the deprecated `_deprecated-md/02-reputation-dynamics.md` reproduces the EDO text (`:174`, `:180`) without citing the label.

**Adjacent:** `verification/mechanism/frobenius_counterexample.py` (tracked in `6587cda`) constructs two tensors with identical Frobenius norm but different risk and tests the log-aggregator `C_R(T) = Σ w_cdh · log(1+T_cdh)`, which the paper never adopts.

**Next step:** state which `C_R` the protocol uses — the scalar EDO of §2.5, a declared function of `‖T‖_F`, or a tensor-wise aggregator — and declare the map from `T` to the argument of `C_R`.

## Proposed order of attack

1. **C-01** — structural, blocks the payment rule. **Confirmed**; the
   evidence is committed (`zk/threshold_quantization.py`) and the
   correction (state `C_R`/`Theta_r`/`VaR_tech` in §6, or label the gap
   `[CONJECTURE]`) is recorded but not yet applied.
2. **C-02** — structural, blocks the data layer's soundness.
3. **C-04** — structural, ties §2 to the rest of the paper.
4. **C-03** — moderate, requires a jump-diffusion computation.
5. **C-09** — moderate, definitional first.
6. **C-05** — moderate, rewrite §5.2 mechanism paragraph and
   table caption; first-order BBP prediction remains [CONJECTURE].
7. **C-06** — minor, reproduce and rephrase.
8. **C-07** — minor, read the script and account for the discrepancy.
9. **C-08** — minor, clarify in §6.6 that the revenue column is gross
   (before exclusion), or recompute the net column.
10. **C-10** — minor, add a calibration.
11. **C-11** — minor, define `Theta_r` and `VaR_tech`.
12. **C-12** — structural (registered late; depends on nothing),
    declares §6.2's binding assumption without citing the §4.3-4.4
    repair it depends on.
13. **C-13** — structural, three incompatible forms of `C_R` (the
    scalar EDO of §2.5, the tensor `C_R(T)` of §6, the executable
    `c_r()` of `verification/`) with no declared map `T → r`.

Order is by severity and dependency, not by ease. C-01 and C-02 come
first because they determine whether §6 and §7 are implementable as
written.

## Handoff

This file is the entry point for the content audit. The next session
should begin by reading it, then opening one finding at a time under
the rules of `CONTRIBUTING.md`. No finding is closed until its script
runs locally and its output is committed to `verification/` or
`docs/audit/`, or its arithmetic is recorded above and the evidence is
committed.
