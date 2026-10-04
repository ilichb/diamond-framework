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

**Location:** §4.1 (threshold proof) and §6.3 (allocation rule).
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
83.3%, or charge the mid value and violate `CoA` for the bottom of the
band by 0.333333 (33.3% of `Theta`). With `k` stepped thresholds the
error falls as `0.333333/k` (optimal placement uniform in `C_R`), at one
extra range proof per threshold; on-chain gas stays constant (~250k)
under recursion, so the marginal cost is off-chain.

**Adjacent discoveries (block the numerical resolution):** `Theta_r` has
no numeric value anywhere in the repo; `VaR_tech` appears once, in
`main.tex:754`, and is never defined or valued (recorded as C-11);
`C_R` carries three incompatible definitions (the §2.5 integro-PDE value
function in a scalar `r`, the tensor-valued `C_R(T)` of §6.3, and
`0.8x/(1+x)` in `fee_specification.py`), which overlaps C-04.

**Resolution identified, not yet applied:** the paper already adopts
Option B, a commitment to the raw tensor (`main.tex:512`). Under Option B
`C_R(T)` is computed from the opened tensor, so the §4.1 threshold is a
relic of the unsound design and should be reframed as a coarse prefilter
rather than the source of the value consumed by §6.3.

**Open question:** single threshold (accept the 83.3% over-collateralization),
stepped proof with `k` thresholds (cost grows off-chain), or
commitment-opening variant (already adopted in §4.4 for soundness)?
Each choice has different cost implications.

**Next step:** choose one design in §4 and state the `C_R` functional
form, `Theta_r`, and `VaR_tech` in §6 so that `k` becomes derivable.

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
inappropriate for detecting cliques".
**Status:** Confirmed by the agent.
**Severity:** Moderate.

The paper compares only the per-edge weight (`1/27.2` vs `1/20`) and
concludes the clique signal is cancelled by degree increase. It ignores
that clique edges are 10× more probable. Expected weight per pair is
≈0.0147 vs 0.002, i.e., the clique remains ≈7× stronger after
normalization. Asym fails by a bulk-edge scale effect, not by
cancellation.

**Evidence (artifact pending):** the agent's independent reproduction
reported in this session; no committed script under `verification/rmt/`
backs the ≈7× counter-accounting. A script `verification/rmt/asym_weights.py`
must be added before §5.2 is rewritten. The paper's own spectral table
(committed) confirms Asym's failure but not the mechanism.

**Next step:** rewrite §5.2 to describe the correct mechanism, keeping
the conclusion (Asym is unsuitable) unchanged.

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

### C-07 — −502 not reproducible from declared parameters

**Location:** §7.4, attacker profit column.
**Status:** Confirmed by the agent.
**Severity:** Minor.

**Evidence:** `-502` appears verbatim in
`verification/data-layer/results/simulate_data_layer_v3_output.txt`.
The paper's declared parameters give `-450`. The 52-unit gap requires
reading the script; artifact exists, derivation does not.

With the declared parameters, `50 · (1 − 10) = −450`, not −502. The
discrepancy (52) is unexplained by the text. Possibly a term not
declared in §7.3.

**Next step:** read `verification/data-layer/simulate_data_layer_v3.py`
and account for the 52.

### C-08 — Revenue column in §6.6 does not discount excluded validators

**Location:** §6.6, table of `F_0` vs revenue.
**Status:** Partially confirmed.
**Severity:** Minor.

Two distinct claims were bundled originally:

**(a) Refuted.** §6.6 does not contradict the paper's "optimal" `F_0*`:
the text defines "optimal" as the largest value preserving IR for all
types (`main.tex:772`), not as revenue-maximizing.

**(b) Confirmed.** The revenue column reports gross revenue. At
`F_0 = 0.06`, 0.2% of validators violate IR; the table shows 60.00 but
the net revenue after excluding those validators would be 59.88. The
script computes `f0 * N_VALIDATORS` without subtracting the excluded
validators.

**Evidence:** inspection of §6.6 and the script; verifiable by
arithmetic.

**Next step:** clarify in §6.6 that the revenue column is gross (before
exclusion), or recompute the net column.

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

## Proposed order of attack

1. **C-01** — structural, blocks the payment rule. **Confirmed**; the
   evidence is committed (`zk/threshold_quantization.py`) and the
   correction (reframe §4.1, state `C_R`/`Theta_r`/`VaR_tech` in §6) is
   recorded but not yet applied.
2. **C-02** — structural, blocks the data layer's soundness.
3. **C-04** — structural, ties §2 to the rest of the paper.
4. **C-03** — moderate, requires a jump-diffusion computation.
5. **C-09** — moderate, definitional first.
6. **C-05** — moderate, rewrite §5.2 with the correct mechanism.
7. **C-06** — minor, reproduce and rephrase.
8. **C-07** — minor, read the script and account for the discrepancy.
9. **C-08** — minor, clarify in §6.6 that the revenue column is gross
   (before exclusion), or recompute the net column.
10. **C-10** — minor, add a calibration.
11. **C-11** — minor, define `Theta_r` and `VaR_tech`.

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
