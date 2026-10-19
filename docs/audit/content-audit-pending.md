# Content Audit — Pending Findings

Working notes for the content audit of `docs/paper/main.tex`. This file
lists the technical findings raised during the initial review (C-01…C-10),
plus the findings raised during verification and the session-3 external
review (C-11…C-37), the eje (v) integrated read (C-38…C-42), and the eje
(vi) style pass and its closure round (C-43…C-50), all closed by the
scripts and edits recorded
below, their verification status, and the proposed order of attack.

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
`Theta = 1.0` at `main.tex:896-900` (§6.4, `eq:f0-value`).
**Status:** Cerrado (resolved by the C-02 decision; residual gaps tracked under C-04 and C-11).
**Severity:** Structural.

The proof of §4.1 demonstrates `||T||_F >= Theta_r`, a boolean. The
allocation rule of §6.3, `S_f*(T) = max{S_min, Theta - C_R(T)}`,
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
no numeric value anywhere in the repo; `S_{\min}` (formerly `VaR_tech`)
is defined in §6.3 at `main.tex:857-866` and valued at `0.2` there
(recorded as C-11);
`C_R` carries three incompatible definitions (the §2.5 integro-PDE value
function in a scalar `r`, the tensor-valued `C_R(T)` of §6.3, and
`0.8x/(1+x)` in `fee_specification.py`), which overlaps C-04.

**Resolution (two layers):** §4.3 defines and §4.4 adopts Option B
(Pedersen + Bulletproofs, zero R1CS constraints), which restores binding
and thereby rescues the misreporting argument of §6.2 (`main.tex:797`)
that §4.2 had refuted for the original design (`main.tex:469`). This
closes the soundness layer. It does not close the allocability layer:
Option B never opens the tensor (`main.tex:442` forbids it), and
`C_R = 0.8x/(1+x)` is nonlinear while Bulletproofs is native to
linear/inner-product and range statements. How `C_R(T)` reaches the chain
is unspecified.

**Open question:** single threshold (accept the 83.3% over-collateralization),
stepped proof with `k` thresholds (cost grows off-chain), or a new
commitment scheme, or a linear `C_R` expressible over the commitment
(design proposal, not a consequence of the text)? Each choice has
different cost implications.

**Next step:** state the `C_R` functional form, `Theta_r` and `S_min`
in §6 (the soundness design is already decided in §4.4), or label the gap
`[CONJECTURE]` and present §6.3 as a design proposal.

### C-02 — Pedersen commitment not bound to the consensus-derived tensor

**Location:** §4.1 (`main.tex:442`), §4.2 (`main.tex:469`), §6.2
(`main.tex:795`), §7.1 (`main.tex:919-926`), §7.2 (`main.tex:934`).
**Status:** Resolved (design decision).
**Severity:** Structural.

**Original problem.** Neither §3.5 nor §7.2 specified who creates the
Pedersen commitment. If the validator creates it, the same class of
unsoundness corrected in §4 (F-012) reappears at the data layer: the
validator chooses `T` freely and proves the norm of a fabricated
tensor. If the data layer creates it, the binding between the
commitment and the events of §7.1 is unspecified.

**Root contradiction.** §4.1 states the protocol "requires validators
to prove, without revealing the full reputation tensor `T`, that its
Frobenius norm exceeds a threshold" (`main.tex:442`), and §1.2 lists
"Verifiability. Reputation claims must be cryptographically verifiable
without revealing the underlying tensor" (`main.tex:66`). §7.1 states
the opposite: `T` is "derived from consensus events on the source
chains" via "a public function `f_c`" (`main.tex:919-926`). Any party
with access to the source chains recomputes `T`. The privacy claim of
§4.1 is vacuous in the protocol §7.1 specifies.

**Decision.** `T` is public. The privacy layer of §4 is dropped. The
ZK proof of §4 is reassigned from privacy to succinctness: the on-chain
verifier does not recompute the Frobenius norm.

**Owner of the commitment.** Option 2 + Option 3 combined.

- **Option 2 (primary).** The data layer reads the source chains,
  applies `f_c`, produces `T`, and publishes the commitment
  optimistically. Soundness rests on the fraud-proof mechanism of §7.3 and the
  slashing parameter $S_{\mathrm{slash}}$ of §7.5, not on the
  validator's honesty. The validator references the published
  commitment; it does not create one.
- **Option 3 (transport).** For Avalanche L1 source chains, the root
  is propagated via Warp Messaging (`main.tex:1230`). The trust
  anchor is the source chain's quorum. For non-Avalanche chains, the
  transport requires a light client or a ZK bridge; a centralized
  oracle is excluded by `main.tex:66`.

Options 1 (validator creates) and a pure Option 3 without Option 2
are rejected.

**Reasons.**

1. §7.1 already declares `T` public. Any alternative requires
   rewriting §7.1, not just §4.
2. The events that feed `T` are consensus output. Privacy of `T`
   would require privacy of the source chains, which the protocol
   does not assume.
3. Option 1 requires `C*D*H = 500` state inclusion proofs
   inside the recursive circuit. The proving time is the benchmark
   the paper explicitly defers (`main.tex:1228`).
4. Option 2 removes the ZK soundness surface that §4.2 already
   exploited once (`main.tex:469`) and does not depend on the
   unmeasured proving time.

**Consequences for other findings.**

- **C-01.** The gap between the bit returned by the ZK proof and the
  continuous value required by the allocation rule is closed if
  `C_R(T) = ||T||_F` is published optimistically by the data layer.
  The contract reads a value, not a bit. C-01 loses its soundness
  layer entirely; only the allocability layer (the functional form
  of `C_R`) remains.
- **C-04.** Reconciliation of §2, §6 and §8 is simplified because
  `C_R(T)` is a public quantity, not a value extracted from a
  circuit.
- **§6.2** (`main.tex:795`). The misreporting argument becomes
  vacuous in a stronger sense: `T` is not a private type because it
  is public, not because a proof binds the validator.

**Costs accepted.**

- A dispute window before a new validator activates.
- Dependence on honest auditors (`main.tex:1274`).
- `T` is visible. Any adversary that reads the source chains sees it.

**Next step:** rewrite `main.tex` §4.1 (`:442`), §1.2 (`:66`) and §6.2
(`:744`) to declare `T` public and reassign the ZK proof from privacy
to succinctness. Rewrite §7.2 (`:873`) to specify that the data layer
owns the commitment and the source chain transport, with Option 3 for
Avalanche L1 source chains. The paper edits belong to a separate
iteration and are not applied here.

### C-03 — MFPT of the jump-diffusion is larger than the CIR value

**Location:** §2.3 (equations 2.4 and 2.5, `main.tex:176-188`).
**Status:** Cerrado.
**Severity:** Moderate.

**Original problem.** The mean first-passage time was computed for the
CIR diffusion without jumps. §2.1 defines the reputation process as CIR
with multiplicative downward jumps (`R -> R*y`, `y in (0,1]`). The
values reported in §2.3 (`11.2203` and `443.7374`) are the `lambda = 0`
limit, not the MFPT of the process as defined.

**Resolution.** A new script,
`verification/stochastics/mfpt_jump_diffusion.py`
(md5 `e57613ea0b9347769c4f95a0fa9d8fa3`), measures the MFPT by Euler
simulation of the full jump-diffusion for `lambda in {0.0, 0.05, 0.1,
0.3, 0.8}`, in both parameter regimes. The jump distribution is
`y ~ U(0.5, 1.0)`, applied as `R -> R*y` per event, matching
`sim_positivity.py`. Deterministic, seed 42, `N_paths = 2000`,
`dt = 0.005`.

Measured MFPT (conditional on absorption within `T_MAX`):

    Regime  lambda   MFPT     reached   analytical
    R1      0.00     11.34    1.0000    11.2203
    R1      0.05     12.10    1.0000    --
    R1      0.10     12.20    1.0000    --
    R1      0.30     14.03    1.0000    --
    R1      0.80     19.38    1.0000    --
    R2      0.00     495.10   0.9725    443.7374
    R2      0.05     512.95   0.9710    --
    R2      0.10     535.22   0.9650    --
    R2      0.30     594.50   0.9280    --
    R2      0.80     710.49   0.8210    --

The `lambda = 0` control at `N_paths = 2000` gives `+1.03%` over the
analytical value, within the Euler-scheme bias (`dt_convergence.py`
reports `+4.9%` at `dt = 0.005` with `N = 5000`; the two are
statistically indistinguishable at `z < 2`). The MFPT grows
monotonically with `lambda`, and in the second regime the fraction of
paths that reach `R_0` within `T_MAX = 2000` falls from `0.9725` at
`lambda = 0` to `0.8210` at `lambda = 0.8`.

`main.tex:188` (after the table of the two regimes) now declares that
the reported values are the `lambda = 0` limit and that the full
process has a larger MFPT. The whitewashing bound of §2.3 is therefore
a lower bound for the process as defined.

**Evidence:**
- `verification/stochastics/mfpt_jump_diffusion.py`
  (md5 `e57613ea0b9347769c4f95a0fa9d8fa3`), output
  `verification/stochastics/results/mfpt_jump_diffusion_output.txt`.
- `verification/stochastics/mfpt_bound_explicit.py`
  (md5 `bbc34d39c7109e9ecb895fe7362394ec`) — the drift+diffusion
  formula, unchanged.
- `verification/stochastics/dt_convergence.py`
  (md5 `9382aaa5e4f888d88971f0204f272fcf`) — the Euler scheme,
  unchanged; same integration rule.
- Two independent runs produce the same output md5.

**Next step:** none. Closed by the paper edit in the same commit.

### C-04 — Section 2 is used downstream via the map r = ||T||_F

**Location:** §2.5 (`main.tex:286`), §6.3 (`main.tex:817`),
§8.1 (`main.tex:1079`).
**Status:** Cerrado.
**Severity:** Structural.

Three objects were listed as unreconciled:
- §2: CIR diffusion with multiplicative jumps, state `r` on `(0, ∞)`,
  mean `\bar{R} = 1`.
- §6: the tensor norm `||T||_F`, sampled uniformly on `[0, 3]` for the
  allocation rule.
- §8: `net_gain` ODE on `R ∈ [0, 1)`, stationary value
  `R^* = ga/(ga + μ)`.

**Resolution.** The paper now declares the map:

- §2.5: the state `r` is the reputation level on the positive
  half-line. Section 6 evaluates `C_R` at `r = ||T||_F`, and the
  reference configuration uses the closed form
  `C_R(r) = 0.8 r / (1 + r)`.
- §6.3: `C_R(T) ≡ C_R(||T||_F)`, with `C_R` the value function of
  §2.5.
- §8.1: the bootstrap operates on a bounded reputation score
  `R ∈ [0, 1)`, distinct from the unbounded `r`, with `R = r/(1+r)`.
  During the bootstrap phase (from `R(0) = 0`) the value function is
  replaced by the bootstrap-specific form
  `\tilde{C}_R(R) = 0.8 R / (1 + R)`. This is the §2.5 form expressed
  in the normalized variable: with `r = R/(1-R)`,
  `C_R(r) = 0.8 r/(1+r) = 0.8 R = \tilde{C}_R(R)`.

The §6 sampling range `[0, 3]` on `||T||_F` is preserved by the
mapping; the §8 stationary value `R^* ≈ 0.4` is the stationary value
of the normalized variable `R`, not of `r`.

**Evidence:**
- `main.tex:286` (state `r` and closed form).
- `main.tex:817` (`C_R(T) ≡ C_R(||T||_F)`).
- `main.tex:1079` (bootstrap `R = r/(1+r)` and `\tilde{C}_R(R)`).
- Compilation clean; references `sec:reputation`, `sec:payment`,
  `eq:allocation`, `eq:netgain` all resolve.

**Next step:** none. Closed by the paper edit in the same commit.

### C-05 — Asym explanation in §5.2 is conceptually wrong

**Location:** §5.2, paragraph "Each edge is scaled by..." and the spectral table.
**Status:** Cerrado. §5.2 mechanism paragraph rewritten with the
per-pair weight argument; table prose now reports the multi-seed
distribution and cites Weyl interlacing for the paired claim.
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

### C-06 — Censoring test is a tail diagnostic, not an MFPT estimate

**Location:** §2.3 (censoring test paragraph, `main.tex:231-233`).
**Status:** Cerrado.
**Severity:** Minor.

**Original problem.** The paper reported the censoring test result
`635.7` and the exact MFPT `443.7` as the output of "two independent
methods" that "agree on the qualitative structure", without discussing
the `43%` numerical gap.

**Resolution.** The two figures are not independent measurements of
the same quantity. The censoring test estimates the MFPT by
extrapolating a geometric tail: `T_0/(1-p)` with
`p = P(tau > T_0) = 0.9214`, giving `635.7279`. The exact MFPT from
numerical integration of the CIR formula is `443.7374`
(`mfpt_bound_explicit.py`). The two differ by `43%`.

The gap is the signature of the tail being sub-geometric. The
empirical ratios `P_emp/P_geo` across five windows are
`0.9973, 0.9942, 0.9943, 0.9921, 0.9858`, with mean `0.9927` and
std `0.0038`. The survival decays faster than geometric, so the
geometric extrapolation overestimates the MFPT. The script's own
tolerance (`|mean-1| < 0.1 and std < 0.1`) is too loose to
distinguish "approximately geometric" from "exactly geometric".

The paper §2.3 now reports both values, explains the gap, and
characterizes the censoring test as a tail-shape diagnostic rather
than an MFPT estimator. The script `censoring_test.py` now labels
its extrapolation as biased upward when the tail is sub-geometric,
and its verdict as "approximately geometric".

**Evidence:**
- `verification/stochastics/censoring_test.py`
  (md5 `6c1e646f1adb54341e71661543b9fb78` before the edit),
  output `verification/stochastics/results/censoring_test_output.txt`.
- `verification/stochastics/mfpt_bound_explicit.py`
  (md5 `bbc34d39c7109e9ecb895fe7362394ec`) — exact MFPT, unchanged.
- `main.tex:231-233` — reworded paragraph and conclusion.
- Deterministic: seed 42 for R1, seed 43 for R2 (as declared in the
  script), two runs produce the same output md5.

**Next step:** none. Closed by the paper and script edits in the
same commit.

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
for all types (`main.tex:823` before the edit; §6.6 after), not as
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
**Status:** Refutado.
**Severity:** Moderate.

**Original claim:** `R_std = 0.0282` and `0.0424` do not reproduce.
An independent agent measured ~0.114 and placed the argmax at
`mu/g ~ 1.0`.

**Resolution:** All three parts are refuted.

- `0.0282` reproduces from `compare_reputation_models.py`
  (md5 `9032169d67ff4e47fdfb9019cfbcd3e3`) at `mu/g = 5.0`, seed 42.
- `0.0424` reproduces from `sweep_net_gain.py`
  (md5 `a60fd329a28217d5ce7ae095e4098866`) at `mu/g = 1.5`, averaged
  over seeds 42-46.
- The argmax of `R_std` over the sweep is at `mu/g = 1.5`:
  `0.0424` at 1.5 > `0.0420` at 2.0 > `0.0405` at 1.0.

Both scripts use the same statistic: `R[active].std()`, the numpy
default `ddof = 0`, cross-sectional over active validators (n = 100)
at the final epoch (t = 500). Neither uses a temporal std nor a
std across seeds. `compare` runs one seed; `sweep` averages the
result over five seeds. The large difference between `0.0282` and
`0.0424` is the operating point (`mu/g = 5.0` vs `1.5`), not the
definition.

The ~0.114 of the independent reproduction comes from evaluating
the analytical stationary form `R* = g*a/(g*a + mu)` with the entry
sigma of the log-normal process (0.7). The simulated activity is a
stationary AR(1) in log space with effective sigma
`sigma_eff = 0.1/sqrt(1 - 0.95^2) = 0.3203`. Using `sigma_eff`
gives `0.0453` at `mu/g = 5.0`, consistent with the simulation. The
~0.114 is a modelling error in the independent reproduction, not a
discrepancy in the paper.

**Evidence:**
- `verification/bootstrap/compare_reputation_models.py`
  (md5 `9032169d67ff4e47fdfb9019cfbcd3e3`), output md5
  `c2757936d4cc84d1c10856ecb7f267c6`.
- `verification/bootstrap/sweep_net_gain.py`
  (md5 `a60fd329a28217d5ce7ae095e4098866`), output md5
  `2cb5ee01190841316c018d613bf755d4`.

**Next step:** none for C-09 itself. The paper uses `R_{\mathrm{std}}`
in three places (lines 995, 1055, 1133 of `main.tex`) and reports two
of its values (lines 1066, 1205) without ever defining it. The two
reported values correspond to two different operating points
(`mu/g = 5.0` and `1.5`) and two different seed counts (1 and 5),
neither declared. This is a textual presentation issue, registered
separately, not part of C-09.

### C-10 — Heavy-tail robustness claimed but not measured

**Location:** §1.2 (`main.tex:67`; the subsection opens at
`main.tex:59`), §5.4 (`main.tex:665`, the calibration itself), §5.7
(`main.tex:745`) and §10.7 (`main.tex:1312-1314`).
**Status:** Confirmed.
**Severity:** Moderate.

The Introduction motivates the collusion test by the need for
robustness against heavy-tailed interaction graphs (`main.tex:67`). The
calibration of §5.4 reports `q99 = 9.0542` on Erdős–Rényi graphs only
(`calibration_modularity.py`, `N_H0 = 2000`). `main.tex:745` and
`main.tex:1314` acknowledge that the calibration is on ER and
Chung–Lu and that "their validity on real graphs is an open question".

**Resolution:** `verification/rmt/calibration_heavy_tail.py`
(md5 `db66ba8f22e820f1503215669c41551a`, output
`verification/rmt/results/calibration_heavy_tail_output.txt`,
md5 `faa8778684e649e8e8aca8e131f54555`) calibrates `q99` under
Chung–Lu power-law degree distributions at the same `n = 500` and
`d_mean = 20` as the canonical calibration. It measures both the
false-positive rate under the paper's ER threshold (`9.0542`) and the
power against a single planted clique. Results
(`N_H0 = 500`, `N_H1 = 200`, seed 42):

    model   beta  q99_own  FPR_at_9.0542  TPR_own   TPR_paper
    ER       --    9.0314  0.0060         0.970     0.960
    CL       2.10  14.4197 1.0000         0.000     1.000
    CL       2.30  12.9942 1.0000         0.000     1.000
    CL       2.50  12.0039 1.0000         0.020     1.000
    CL       3.00  11.3169 1.0000         0.155     1.000

The paper's ER threshold is **anti-conservative** on heavy-tailed
graphs: it flags every H0 replicate in the four Chung–Lu models tested,
so its empirical false-positive rate is `1.0` rather than
`alpha = 0.01`. Re-calibrating per-null removes the false-positive
problem but destroys the power: `TPR_own` against a single planted
clique (`m = 20`, `10x` local density) collapses to `0.000` for
`beta <= 2.3` and reaches only `0.155` at `beta = 3.0`.
`TPR_paper = 1.0` is degenerate, not evidence of robustness.

**Caveats:**

- The `min(1, w_i w_j / sum(w))` form of Chung–Lu saturates the
  highest-weight pairs when the weight sequence is normalised to a
  fixed mean. At `n = 500`, `d_mean = 20`, the requested maximum degree
  is `1120` for `beta = 2.1` and `694` for `beta = 2.3`, both above
  `n - 1 = 499`. A simple-graph realisation of the pure configuration
  model is therefore infeasible without rejecting the excess stubs
  (`7.32%` at `beta = 2.1` and `1.97%` at `beta = 2.3`; the realised
  maximum degree saturates at `n - 1 = 499`), so those two rows are a
  degree-capped null rather than the pure power-law sequence. The
  separation of "genuine tail" from "saturated hub core" requires
  `n >= 5000` (or a much smaller `d_mean`) and a recalibrated ER
  baseline; the code was prepared and is stored outside the repository
  as a postponed experiment.
- The bulk edge `2*sqrt(d_bar) = 8.9443` used in the canonical ER
  calibration (`main.tex:637`) is not the correct edge for Chung–Lu.
  The entire CL null lies above it (the `FPR_at_9.0542 = 1.0000` column
  shows every replicate exceeding `9.0542 > 8.9443`), and the correct
  bulk edge depends on the weight sequence.

**Evidence:**

- `verification/rmt/calibration_heavy_tail.py`
  (md5 `db66ba8f22e820f1503215669c41551a`), output md5
  `faa8778684e649e8e8aca8e131f54555`.
- Deterministic byte-for-byte: two independent runs on the same machine
  produce the identical md5; seed 42, no clock, no entropy, no disk I/O.
- ER baseline cross-checked against the committed ER calibration
  (`main.tex:674`, `calibration_modularity.py` at `N_H0 = 2000`: mean
  `8.7679`, std `0.1115`, `q99 = 9.0542`). The ER control
  (`N_H0 = 500`) reproduces the mean and the standard deviation
  (`8.7693` / `0.1107`); its `q99 = 9.0314` differs from the canonical
  value by `0.0228`, about `1.3` times the paper's own standard error
  of the `q99` estimate (`0.017`, `main.tex:1219`). The ER control also
  reproduces the paper's H1 power: `0.960` against a single clique of
  size 20, with the paper's `0.972` (`main.tex:1219`) inside its Wilson
  interval `[0.923, 0.980]`.
- Wilson intervals computed with the same estimator as
  `verification/rmt/wilson_intervals.py` (`wilson_ci`): ER row
  `wilson_ci(194, 200) = [0.936, 0.986]`, and `[0.000, 0.019]`,
  `[0.008, 0.050]`, `[0.111, 0.212]` for the CL rows at
  `beta = 2.1 / 2.5 / 3.0`.

**Next step:** declare in §5.4 that the ER-calibrated `q99` does not
transfer to heavy-tailed graphs, and that the collusion test requires
either per-null recalibration or a weight-dependent bulk edge. Register
the "saturated hub core vs genuine tail" separation as a postponed
experiment, to be run at `n >= 5000`.

### C-11 — The allocation rule uses symbols the paper never defines

**Location:** §4.1 (`Theta_r` defined at `main.tex:465`) and §6.3
(`S_{\min}` defined at `main.tex:866`).
**Status:** Cerrado (textual; definitions added to the paper).
**Severity:** Minor.

**Confirmed.** `\Theta_r` appears five times in the paper
(`main.tex:325`, `:445`, `:449`, `:453`, `:456`). Before the present
edit it appeared four times with no numeric value (`:316`, `:426`,
`:432`, `:435`). `\mathrm{VaR}_{\mathrm{tech}}` appears three times
(`main.tex:809` in the allocation rule, `:815` in the definition
below, `:1019` in the bootstrap policy). Neither symbol had a notation
entry or a `\newcommand` before the present edit.

The scripts use working values, but neither is derived from the paper:

- `verification/zk/threshold_quantization.py:41` sets `THETA_R = 0.5`
  citing `main.tex:463-464` (the §4.2 exploit table). That value is an
  illustration of the exploit, not a declared protocol constant.
- `verification/mechanism/fee_specification.py:38` sets `VAR_TECH = 0.2`
  with no paper citation. The same value is used in the bootstrap
  scripts (`compare_reputation_models.py:29`,
  `sweep_net_gain.py:32`, `simulate_bootstrap_net_gain.py:20`) and in
  `threshold_quantization.py:43`.

**Resolution.** The paper defines both symbols in place and labels the
reference values `[CONJECTURE]`:

- §4.1, after `eq:threshold`: `\Theta_r` defined as the minimum
  Frobenius norm required for admission; reference value
  `\Theta_r = 0.5` `[CONJECTURE]`.
- §6.3, after the sentence that follows the allocation rule:
  `\mathrm{VaR}_{\mathrm{tech}}` defined as the technical minimum
  financial stake; reference value `\mathrm{VaR}_{\mathrm{tech}} = 0.2`
  `[CONJECTURE]`.

**Evidence:**
- `grep -nF 'Theta_r' docs/paper/main.tex` returns `:325`, `:445`,
  `:430`, `:434`, `:437` after this edit; `:316`, `:426`, `:432`,
  `:435` before.
- `grep -nF 'VaR' docs/paper/main.tex` returns `:809`, `:815`, `:1098`
  after this edit; `:756`, `:1015` before.
- `grep -rnE 'THETA_R|VAR_TECH' verification/ --include='*.py'`
  returns the script lines cited above.

**Next step:** none. Closed by the paper edit in the same commit.

### C-12 — §6.2 presupposes the §4.3-4.4 repair without citing it

**Location:** §6.2 ("Verified Reputation") vs §4.2-4.4.
**Status:** Cerrado. Forward reference added at `main.tex:803` (§6.2 → §4.4).
**Severity:** Structural.

§6.2 asserts that the threshold proof binds the validator to a specific
tensor: "the proof binds the validator to a specific tensor, and the
verifier checks the binding" (`main.tex:797`). This claim holds only
under the Option B repair of §4.3-4.4, because §4.2 had explicitly
refuted the binding property of the original design ("There is no
commitment binding the prover to any specific tensor", `main.tex:469`).

§6.2 does not cite §4.3-4.4. A reader arriving at §6.2 from §6.1
encounters an assertion whose truth depends on a repair specified two
sections earlier and never referenced.

**Evidence:** `main.tex:797` vs `main.tex:469`. The dependency is
reproducible by inspection.

**Next step:** add a forward reference from §6.2 to §4.3-4.4 (or vice
versa), making the dependency explicit.

### C-13 — C_R has three incompatible forms; the map T → r is now declared

**Location:** §2.5 (`main.tex:279-286`), §6.3 (`main.tex:817`),
§8.1 (`main.tex:1079`), `verification/` (`c_r(norm_T)`, `c_r(R)`).
**Status:** Cerrado.
**Severity:** Structural.

**Original problem.** `C_R` appeared in three forms: the scalar EDO of
§2.5, the tensor-valued `C_R(T)` of §6.1/§6.3/§6.5, and the executable
`c_r(norm_T)` or `c_r(R)` of `verification/`. No map `T → r` was
declared; the paper never stated that `C_R` depends on `T` only through
`||T||_F`.

**Resolution.** The paper now declares the map in three sentences:

- §2.5: the state `r` is the reputation level on `(0, ∞)`. §6 evaluates
  `C_R` at `r = ||T||_F`, with closed form
  `C_R(r) = 0.8 r / (1 + r)`.
- §6.3: `C_R(T) ≡ C_R(||T||_F)`.
- §8.1: the bootstrap uses a bounded score `R ∈ [0, 1)`, distinct
  from `r`, with `R = r/(1+r)`. The bootstrap form
  `\tilde{C}_R(R) = 0.8 R/(1+R)` is the §2.5 form in the normalized
  variable: with `r = R/(1-R)`, `C_R(r) = \tilde{C}_R(R)`.

The executable forms become consistent with the declared map:
`c_r(norm_T)` in `mechanism/fee_specification.py:41` and
`zk/threshold_quantization.py:56` computes `C_R(||T||_F)`; `c_r(R)` in
the four bootstrap scripts computes `\tilde{C}_R(R)`. The scripts are
not modified; the paper now explains why the two forms are not the same
function.

The §2.5 EDO itself has zero implementation in the repository. This
remains a design gap: the closed form `0.8 r/(1+r)` is the reference
configuration, not the solution of `eq:integro`. The gap is recorded,
not closed.

**Evidence:**
- `main.tex:286` (state `r` and closed form).
- `main.tex:817` (`C_R(T) ≡ C_R(||T||_F)`).
- `main.tex:1079` (bootstrap `R = r/(1+r)` and `\tilde{C}_R(R)`).
- `grep -nF 'C_R' docs/paper/main.tex` shows consistent use.
- `verification/` unchanged; the two executable forms are now
  reconciled by the declared map.

**Next step:** the §2.5 EDO remains unimplemented. Whether to publish
the closed form `0.8 r/(1+r)` as the protocol's collateral function
(replacing the EDO), or to implement the EDO numerically, is a
separate finding. This block closes the map inconsistency only.

### C-14 — `R_{\mathrm{std}}` is never defined; the two reported values are unlabelled

**Location:** §8.1 (`main.tex:1071`), §8.2 summary table (`main.tex:1134`),
§8.2 prose (`main.tex:1149`), §8.7 (`main.tex:1223`), §9 (`main.tex:1302`).
**Status:** Cerrado. `R_{\mathrm{std}}` defined at the end of §8.2;
operating point and seed count declared at `main.tex:1163` and
`main.tex:1323`.
**Severity:** Minor.

The symbol `R_{\mathrm{std}}` occurs three times (`main.tex:1071`, `:1134`,
`:1141`) and appears twice more as the gloss "standard deviation of
reputation" (`:1074`, `:1213`). It is never defined. The text does not say
whether the standard deviation is across validators or across time, over
the full epoch history or the final epoch, over active or all slots, or
with which `ddof`. There is no notation table, no `\newcommand`, no
`\DeclareMathOperator`.

`main.tex:1149` juxtaposes two numbers taken at different operating
points and with different sample sizes as if comparable. `0.0282` comes
from `compare_reputation_models.py` at `mu/g = 5.0` (one seed, 42).
`0.0424` comes from `sweep_net_gain.py` at `mu/g = 1.5` (mean over seeds
42-46). Neither the operating point nor the seed count is declared at
`:1074` or at `:1213`, where `0.0424` is reported alone.

The statistic used in both scripts is the same: `R[active].std()`, numpy
default `ddof = 0`, cross-sectional over active validators (n = 100) at
the final epoch (t = 500). Neither script uses a temporal std nor a std
across seeds. The code is correct; the paper's presentation is not.

**Evidence:** `grep -nF 'R_{\mathrm{std}}' docs/paper/main.tex` returns
`:995`, `:1063`, `:1141`. The only executable definition in the
repository is the dict key `"R_std": active_R.std()` at
`verification/bootstrap/compare_reputation_models.py:151` and
`verification/bootstrap/sweep_net_gain.py:90`; there is no function
`r_std()` and no constant `R_STD` anywhere.

`verification/bootstrap/r_std_specification.py`
(md5 `e4cf5cfda9e94e5df12a9c9c0953546d`, output md5
`f81ada2fa1b0be5faa196b129454bed4`) formalizes the statistic once,
reproduces both canonical values (`0.028156` and `0.042400`), and
extends the seed sample to N = 100:

    mu/g = 1.00:  mean 0.042050,  std 0.003002,  SE 0.000300,  CI95 [0.041461, 0.042638]
    mu/g = 1.50:  mean 0.043970,  std 0.003156,  SE 0.000316,  CI95 [0.043351, 0.044588]
    mu/g = 2.00:  mean 0.043470,  std 0.003144,  SE 0.000314,  CI95 [0.042853, 0.044086]
    mu/g = 3.00:  mean 0.040321,  std 0.002983,  SE 0.000298,  CI95 [0.039737, 0.040906]
    mu/g = 5.00:  mean 0.033499,  std 0.002615,  SE 0.000262,  CI95 [0.032987, 0.034012]

Two numerical consequences:

- The paper's `0.0424` at `mu/g = 1.5` is below the N = 100 CI lower
  bound (`0.043351`). It is a specific 5-seed realization that happens
  to be low. The population mean at that operating point is `0.043970`.
  The paper reports a point estimate without an interval and without
  declaring that it comes from 5 seeds.
- The N = 100 CI at `mu/g = 1.5` `[0.043351, 0.044588]` overlaps the CI
  at `mu/g = 2.0` `[0.042853, 0.044086]`. The argmax at `1.5` is not
  statistically distinguishable from `2.0` at N = 100. This is
  consistent with F-005 ("the optimum is a band, not a point") and with
  `main.tex:1223` ("nearby values give similar results").

**Next step:** define `R_{\mathrm{std}}` in §8.1 as the cross-sectional
sample standard deviation (`ddof = 0`) of `R` over active validators at
the final epoch; declare the operating point and seed count at `:1074`
and `:1213`; and either report the N = 100 mean with its 95% CI in place
of the single 5-seed realization, or label `0.0424` as a point estimate
without an interval.

### C-15 — The Proposed order of attack is stale

**Location:** `docs/audit/content-audit-pending.md`, §Proposed order of
attack.
**Status:** Confirmed (textual, worksheet-internal).
**Severity:** Minor.

The block listed fourteen findings. Ten of them are closed: C-02
`Resolved (design decision)`; C-05, C-07, C-08, C-10, C-12, C-13, C-14
`Confirmed` with committed evidence; C-09 `Refutado`; C-01 closed by
the C-02 decision. Item 10 carried an obsolete `(pending commit)` for
the calibration script and output, both committed in `7d7ec86`. The
sequence was not monotone in severity, against the block's own stated
rule ("Order is by severity and dependency"). A stray blank line sat
between items 13 and 14.

**Resolution:** The block is rewritten to list only the open findings,
ordered by severity modulated by dependency. The closed findings remain
in the file above this block as record. The `(pending commit)` marker
and the stray blank line are removed.

**Next step:** none. Closed in the same commit that rewrites the block.

### C-16 — Script counter in §9 is stale

**Location:** `main.tex:1176` (`The README lists the N scripts`).
**Status:** Cerrado.
**Severity:** Minor.

The paper reported `27` scripts in §9.1. The README's `## Running`
block listed `28` executable scripts. The disk had `30` non-archived
`.py` files. Three counters, three values.

Origin: the commit `a7f7bf2` aligned the counter at 27 (README 27,
paper 27). The commit `a6964d6` (C-03) added
`stochastics/mfpt_jump_diffusion.py` to the README (28) but did not
update the paper. Separately, `rmt/asym_weights.py` (commit `6d0b91c`)
and `rmt/clique_spectra_seeds.py` (commit `cc6c06c`) had versioned
outputs in `results/` but were never added to the README.

**Resolution.** All three counters are aligned at 30:

- `verification/README.md` `## Running` now lists
  `clique_spectra_seeds.py` and `asym_weights.py`; both have rows in
  `## Runtime`. The total runtime is unchanged (~12 min) because the
  two additions total ~22 s.
- `main.tex:1176` now reads `30 scripts`.
- The reference is now consistent across the paper, the README, and
  the disk.

**Evidence:**
- `grep -c '^    python3 ' verification/README.md` returns 30 after
  this edit (28 before).
- `find verification -name '*.py' -not -path '*/archive/*'` returns 30.
- `grep -nF 'The README lists the' docs/paper/main.tex` returns the
  line with `30`.
- Both scripts were re-run for timing and produce the same output md5
  as the committed version (`clique_spectra_seeds.py` →
  `92862f2e11aa8188658ffbbb30869e9c`, `asym_weights.py` →
  `9671f10df471b4f3d19b27683a78b677`).

**Next step:** none. Closed by the edits in the same commit.

### C-17 — Falsification counter says 18 in two places, 19 in four

**Location:** `main.tex:1259` (§9.6 table), `main.tex:1397` (§11.2).
**Status:** Cerrado.
**Severity:** Minor.

The log has 19 entries (F-001 through F-019). The paper says 19 in the
abstract (`:49`), §1.3 (`:88`), §9.2 (`:1099`), and §11.6 (`:1354`
before the edit). It said 18 in §9.6 (`:1174` before the edit) and
§11.2 (`:1304` before the edit). The 18 was residue from when the log
had 18 entries.

`falsifications` is a misleading count: 16 of the 19 entries are
`Refuted` or `Partially refuted`; the rest are `Not applicable`,
`Misapplied`, `Mis-tested`. The paper now says `19 entries`
everywhere. The `either confirmed or corrected` clause in §11.2 is
removed because it contradicted the actual verdicts.

**Resolution.** §9.6 and §11.2 aligned at 19 entries; terminology
changed from `falsifications` to `entries` in both.

**Evidence:**
- `grep -c '^### F-' docs/audit/numerical-verification.md` returns 19.
- `grep -nF '18 falsifications' docs/paper/main.tex` returns 0 after
  the edit.

**Next step:** none.

### C-18 — §9.2 runtime table contradicts the README

**Location:** `main.tex:1182-1199` (§9.2 Reproducibility).
**Status:** Cerrado.
**Severity:** Minor.

§9.2 reported `approximately 10 minutes` and `All others < 5 s each`,
listing six scripts. The README reports `~12 min` and lists thirteen
scripts at `≥5 s`, including the actually dominant `recalibrate_top.py`
(`~10 min`), which §9.2 omitted.

**Resolution.** The §9.2 table now matches the README rows at `≥5 s`.
The total is `~12 min` and the dominant cost is cited as
`recalibrate_top.py`. `All others < 5 s each` remains true for the
rest.

**Evidence:**
- `awk '/^## Runtime/,/^## Reproducibility/' verification/README.md`
  lists the same rows.
- The paper table no longer omits `recalibrate_top.py`.

**Next step:** none.

### C-19 — VaR_tech renamed to S_min

**Location:** §6.3 (allocation rule and floor definition) and §8.3
(bootstrap policy `hybrid_no_decay`) in `docs/paper/main.tex`.
**Status:** Cerrado.
**Severity:** Minor.

The floor of the allocation rule was named `VaR_tech`. Section 6.3
itself admitted the name was historical and that the quantity is a
design parameter, not a financial Value at Risk. In a formal paper the
notation must reflect the function, not the history: `S_min`
(Minimum Financial Stake) removes the semantic friction with
economics reviewers while keeping the same value (`0.2`).

**Resolution.** Global rename of `\mathrm{VaR}_{\mathrm{tech}}` to
`S_{\min}` in `main.tex`. The trailing clause "the notation is
historical" was dropped because it asserted the historical origin that
the rename removes; the sentence now states only that the floor is a
design parameter, not a market-calibrated quantity. The value `0.2`
and the surrounding argument are unchanged.

**Evidence:** `grep -c 'VaR' docs/paper/main.tex` returns 0;
`pdflatex` runs twice with no `^!` and no `Undefined`.

**Next step:** none.

### C-20 — The succinctness claim lacked a cost model

**Location:** §4.1 (circuit specification) and §4.5 (new subsection
"Succinctness and the Cost of Ingesting the Tensor",
`\label{subsec:succinctness}`).
**Status:** Cerrado.
**Severity:** Structural.

§4.1 asserted that the threshold proof "exists for succinctness, not
for privacy" without ever quantifying the alternative. Since `T` is
public, a reviewer can ask why a validator does not simply transmit
`T` to the destination chain and compute `||T||_F` there. Without a
cost model the claim is an assertion, not an argument.

**Resolution.** A Foundry benchmark (`benchmarkIngestFrobeniusNorm` in
`GasBenchmarks.sol`) measures the native sum-of-squares loop over the
500-entry tensor. §4.5 composes the cost of the native alternative
from two terms: the calldata cost of transmitting `T` (EIP-2028,
`256,000` gas at the upper bound for 500 254-bit field elements) and
the measured on-chain loop (`428,064` gas at the reference compile,
optimizer disabled as for the precompile benchmarks). The composed
ingest is `684,064` gas, which exceeds the constant verification
costs: `206k` (Groth16 direct), `250k` (recursive SNARK), and the
`181,142` pairing step. The reviewer's premise does not hold on the
reference tensor, and the stop-gate set at `181,142` gas is not
tripped. §4.1 now states the cross-chain framing and the §4 summary
table lists the measured ingest.

**Evidence:** `verification/zk/succinctness_comparison.py` (output in
`verification/zk/results/succinctness_comparison_output.txt`) reads
the raw Foundry output at
`integrations/avalanche/benchmarks/results/gas_ingest_output.txt`.
The measured call gas is insensitive to the byte pattern of `T`
(`T[i]=1` and `T[i]=2^64-1` both give `428,064`): the Foundry
call-frame figure measures the loop and the test frame, not the
calldata payload, so the calldata term is composed analytically.
`grep -c 'succinctness' docs/paper/main.tex` returns 8; `pdflatex`
runs twice with no `^!` and no `Undefined`.

**Next step:** none.

### C-21 — The financial floor S_min was an unjustified conjecture

**Location:** §6.3 (allocation rule and floor definition).
**Status:** Cerrado.
**Severity:** Minor.

§6.3 set the financial floor `S_min = 0.2` and tagged it `[CONJECTURE]`,
with no derivation. A design parameter that gates admission should trace
to the model, not to a round number.

**Resolution.** The floor is the complement of the collateral saturation:
`S_min = Theta - C_R^inf`, with `C_R^inf = lim_{r->inf} C_R(r)`. For the
reference value function `C_R(r) = 0.8 r/(1+r)` the collateral saturates at
`C_R^inf = 0.8`, giving `S_min = 1.0 - 0.8 = 0.2`. The floor is the largest
minimum stake that stays inactive over the admissible range (the unfloored
allocation `Theta - C_R(T)` has infimum `0.2`). §6.3 now states the
derivation and drops the `[CONJECTURE]` marker; the §6 summary table lists
the closed form.

**Evidence:** `verification/mechanism/financial_floor_sensitivity.py`
(output in
`verification/mechanism/results/financial_floor_sensitivity_output.txt`)
sweeps `C_R^inf in [0.5, 1.0]`, tracing `S_min = Theta - C_R^inf` over
`[0.0, 0.5]`. `grep -c 'financial_floor_sensitivity' docs/paper/main.tex`
returns 2; `pdflatex` runs twice with no `^!` and no `Undefined`.

**Next step:** none.

### C-22 — The `n >= 5000` heavy-tail experiment (stop-gate tripped)

**Location:** §5.4 (the Chung–Lu FPR paragraph, the "requires `n >= 5000`"
remedy) in `docs/paper/main.tex`.
**Status:** Cerrado (stop-gate tripped; the §5.4 edit is deferred to C-23).
**Severity:** Structural.

§5.4 defers the separation of the genuine heavy tail from the saturated
hub core to a "postponed experiment" at `n >= 5000`, with the code stored
outside the repository. That experiment is now run
(`verification/rmt/heavy_tail_n5000.py`).

**Resolution.** At `n = 5000` the stop-gate tripped: `TPR_pernull < 0.5`
for every `beta`, and the ER threshold rejects every Chung–Lu replicate
(empirical FPR `1.0000`). The failure persists, so §5.4 is *not* edited to
claim a recovery; F-020 records the raw result. The `n >= 5000` remedy is
refuted on two counts. First, even at `n = 5000`, `beta = 2.1` remains
degree-capped (expected `d_max = 7445.8 > n - 1 = 4999`). Second, the
experiment conflates the heavy-tail miscalibration with clique-size
scaling: a fixed `m = 20` clique is `0.4%` of `n = 5000` versus `4%` at
`n = 500`, so the Erdős–Rényi baseline itself loses power (`TPR = 0.005`)
for reasons unrelated to the tail. The structural conclusion requires
isolating the confound; it is carried as C-23.

**Evidence:** `verification/rmt/heavy_tail_n5000.py` (output in
`verification/rmt/results/heavy_tail_n5000_output.txt`), seed 42,
deterministic. `main.tex` is unchanged by this finding.

**Next step:** C-23 (scaled-clique experiment) isolates the confound
before §5.4 is edited.

### C-23 — The `n >= 5000` failure conflates heavy-tail miscalibration with clique scaling

**Location:** §5.4 (Calibration) and §5.7 (Limitations) in
`docs/paper/main.tex`.
**Status:** Cerrado.
**Severity:** Structural.

C-22 (F-020) left a confound: at `n = 5000` a fixed `m = 20` clique is
`0.4%` of `n` versus `4%` at `n = 500`, so the collapse of the per-null
power could be a clique-size effect rather than a heavy-tail effect. A
structural conclusion about §5.4 cannot be drawn without isolating it.

**Resolution.** `heavy_tail_scaled_clique.py` sweeps the clique size at
`n = 5000` over three regimes (fixed `m = 20`; `m = 63`, preserving
`m/sqrt(n)`; `m = 200`, preserving `m/n`). The confound resolves cleanly:
at `m = 200` (the `n = 500` fraction) the ER baseline recovers full power
(`TPR = 1.000`) while every Chung–Lu null stays at `0.085` or below
(F-021). The failure is therefore structural in the heavy-tailed null.
§5.4 now removes the "requires `n >= 5000`" remedy and states the measured
result; §5.7 declares that detection is not the binding defence in
heavy-tailed regimes and that the guarantee rests on the financial floor
`S_min` (C-21).

**Evidence:** `verification/rmt/heavy_tail_scaled_clique.py` (output in
`verification/rmt/results/heavy_tail_scaled_clique_output.txt`), seed 42,
deterministic; the H0 calibration reproduces C-22 exactly (q99 `9.1957`,
`47.3792`, `37.0298`, `30.2631`, `22.8598`). `pdflatex` runs twice with no
`^!` and no `Undefined`.

**Next step:** none.

### C-24 — Closed-form `C_R` unverified against the IDE (`eq:integro`)

**Location:** §2.5 (`eq:integro`) and the closed form `C_R(r) = 0.8 r/(1+r)`
in `docs/paper/main.tex`.
**Status:** Cerrado.
**Severity:** Moderate.

§2.5 defines the integro-differential equation that `C_R(r)` satisfies and
declares the closed form `C_R(r) = 0.8 r/(1+r)` as the reference
configuration, but never checks it against the operator. The gap was carried
as residual gap #1 in the handoff (§3) with zero implementation in the
repository.

**Resolution.** `verification/stochastics/cr_ide_solver.py` evaluates the
stationary operator `L[C_R](r)` analytically (no Monte Carlo, no finite
differences) on the fixed grid `r in {1e-3, ..., 50}` for both regimes
(`alpha = 0.5, sigma_0 = 0.8`; `alpha = 2.0, sigma_0 = 0.5`), with the
reference jump `lambda = 0.8`, `nu = delta_{y=0.85}` (mean magnitude `0.15`),
and backs out the running reward `pi(r) = -L[C_R](r)`. The strict guards pass
in both regimes: `pi` is real and finite, `pi(r) = O(r)` as `r -> inf`
(`pi(r)/r -> 0.8`), and `pi` increases on `[r_0, inf)`. The zero crossing
sits at `r_0 = 0.325039` (Regime 1) and `r_0 = 0.611879` (Regime 2), below
the operational range; `pi(r) > 0` for every `r >= 1.0` in both regimes, so
the closed form is admissible wherever the protocol operates. §2.5 now
states the payoff `pi(r)` explicitly (equation `eq:running-reward`) and
cites the script.

**Evidence:** `verification/stochastics/cr_ide_solver.py` (output in
`verification/stochastics/results/cr_ide_solver_output.txt`); deterministic,
no seed, analytical. `grep -c 'cr_ide_solver' docs/paper/main.tex` returns 1;
`pdflatex` runs twice with no `^!` and no `Undefined`.

**Next step:** none.

### C-25 — Reproducibility counters stale in §1.4, §9 and §11

**Location:** `docs/paper/main.tex` §1.4 (runtime), §9 (script count,
F-log count, runtime), §11.
**Status:** Cerrado.
**Severity:** Moderate.

Four counters in the paper had drifted from the repository. §1.4 said
"approximately ten minutes"; §9 said "the 30 scripts", "19 entries
(F-001 through F-019)" and "approximately 12 minutes". The two runtime
claims were already inconsistent with each other before this batch, and
all four counters were stale. The F-log count also appears in the §9
summary table and twice in Section 11.

**Resolution.** Re-derived from the repository: 35 non-archived scripts
(`find verification -name '*.py' -not -path '*/archive/*' | wc -l`),
F-001 through F-021 (21 entries), and a total runtime dominated by
`recalibrate_top.py` (~10 min), `heavy_tail_n5000.py` (~15 min) and
`heavy_tail_scaled_clique.py` (~24 min). §1.4 and §9 now report the same
total; the F-log count reads 21 in §9 and §11. No number was adjusted
downward to preserve the original runtime claim.

**Evidence:** `docs/paper/main.tex`; derived with the commands above.
`pdflatex` runs twice with no `^!` and no `Undefined`.

**Next step:** none.

### C-26 — F-log counter in §1.3 written in words is stale

**Location:** `docs/paper/main.tex` §1.3 (`main.tex:81`).
**Status:** Cerrado.
**Severity:** Structural.

§1.3 read "During development, nineteen quantitative claims were
made, tested, and either confirmed or corrected." The falsification log
holds 21 entries (F-001 through F-021). The counter was stale in the
same way as C-25, but expressed in words, which is why the C-25 digit
sweep did not catch it.

**Resolution.** "nineteen" → "twenty-one" in §1.3. The digit counters
in §9 and §11 already read 21; both forms are now consistent with the
log.

**Evidence:** `grep -cE 'nineteen' docs/paper/main.tex` = 0;
`grep -cE 'twenty[- ]one|21 entries|21 quantitative' docs/paper/main.tex`
= 6; `pdflatex` twice with no `^!` and no `Undefined`.

**Next step:** none.

### C-27 — F-log counter in the Abstract written in words is stale

**Location:** `docs/paper/main.tex` Abstract (`main.tex:42`).
**Status:** Cerrado.
**Severity:** Structural.

The Abstract read "a falsification log documenting nineteen claims
that were made, tested, and corrected during development." Same stale
counter as C-26, same root cause (word form), same log (21 entries).

**Resolution.** "nineteen" → "twenty-one" in the Abstract.

**Evidence:** as C-26.

**Next step:** none.

### C-28 — The §5.2 per-pair ratio lacked a citation to asym_weights.py

**Location:** `docs/paper/main.tex` §5.2, paragraph on the per-pair ratios.
**Status:** Cerrado.
**Severity:** Moderate.

The values 7.4478 / 10.1343 / d_bg = 27.214 are produced by
`verification/rmt/asym_weights.py` (`results/asym_weights_output.txt`,
lines 10-17). The nearest `\fref` pointed to `clique_spectra.py`, which
does not produce those values.

**Resolution.** `\fref` to `asym_weights.py` added in §5.2. One-line edit.

**Evidence:** `grep -c 'asym_weights.py' docs/paper/main.tex` >= 1;
`pdflatex` twice with no `^!` and no `Undefined`.

**Next step:** none.

### C-30 — Unsourced 20--25% range replaced with the derived 22.4%

**Location:** `docs/paper/main.tex` §10.5 (Reputation Model Selection).
**Status:** Cerrado.
**Severity:** Minor.

The "20--25\%" range is produced by no script. The derived reference
value is 22.4\% (`simulate_bootstrap_net_gain.py`), cited in §8.4 and §11.

**Resolution.** The range is replaced by the derived value with a
`\fref`. The robustness claim is preserved for the ranking of policies.

**Evidence:** `grep -c 'reference stake reduction is 22.4' docs/paper/main.tex` = 1;
`grep -c 'stake reduction of 20--25' docs/paper/main.tex` = 0;
`pdflatex` twice with no `^!` and no `Undefined`.

**Next step:** none.

### C-31 — The Poseidon-2 gas measurement lacked a benchmark citation

**Location:** `docs/paper/main.tex` §4.5.
**Status:** Cerrado.
**Severity:** Minor.

The 104{,}963 gas figure for Poseidon-2 comes from `benchPoseidon2()` in
`integrations/avalanche/benchmarks/src/GasBenchmarks.sol`
(`benchmark_output_v2.txt`, line 64), but the sentence carried no
`\fref`.

**Resolution.** `\fref` to `GasBenchmarks.sol` added in §4.5. One-line edit.

**Evidence:** `grep -cF '104{,}963 gas \fref{integrations/avalanche/benchmarks/src/GasBenchmarks.sol}' docs/paper/main.tex` = 1;
`pdflatex` twice with no `^!` and no `Undefined`.

**Next step:** none.

### C-32 — §8 reused the §2 mean-reversion glyph alpha for the transition rate

**Location:** `docs/paper/main.tex` §8.3 (`\alpha(t)`, `\alpha{=}1`) vs §2.1 (`\alpha`, mean-reversion speed).
**Status:** Cerrado.
**Severity:** Minor.

§2.1 uses `\alpha` for the CIR mean-reversion speed; §8.3 used the same
glyph for the hybrid transition rate `\alpha(t) = \min(1, t/200)`. Two
distinct quantities in the same paper.

**Resolution.** `\alpha(t)` (three occurrences) and `\alpha{=}1` (one
table entry) renamed to `\tau` in §8.3. The mean-reversion `\alpha` of §2
and the significance level `\alpha` of §5 are untouched.

**Evidence:** `grep -c '\\alpha(t)' docs/paper/main.tex` = 0;
`grep -c '\\tau(t)' docs/paper/main.tex` = 3; `pdflatex` twice with no
`^!` and no `Undefined`.

**Next step:** none.

### C-33 — §8 reused the §2.5 drift glyph mu for the bootstrap decay rate

**Location:** `docs/paper/main.tex` §2.5 (`\mu(r)` drift) vs §8.2 (bootstrap decay rate).
**Status:** Cerrado.
**Severity:** Minor.

§2.5 uses `\mu(r)` for the CIR drift; §8.2 used the same glyph for the
reputational decay rate of the bootstrap. Same model, two quantities.

**Resolution.** `\mu` renamed to `\delta` in §8.2, §8.4, §8.7, §9 and
§10 (including `\mu/g` → `\delta/g`). The `\mu(r)` of §2.5 is untouched.
Scripts unchanged; only paper notation.

**Evidence:** `grep -c '\\mu' docs/paper/main.tex` equals
`grep -c '\\mu(r)' docs/paper/main.tex`; `grep -c '\\delta'` = 10;
`pdflatex` twice with no `^!` and no `Undefined`.

**Next step:** none.

### C-29 — F-018 cites the correct script (refuted)

**Location:** `docs/paper/main.tex` §5.4 (two-block balance);
`docs/audit/numerical-verification.md` F-018.
**Status:** Refutado.
**Severity:** —

The paper attributes s[-1] = 17.5 and s[-2] = 8.5 to F-018. The Test
field of F-018 cites `verification/rmt/recalibrate_top.py`, which
produces exactly 17.5172 / 8.5617 (assortative configuration 250/250,
rho = 10; `recalibrate_top_output.txt`, line 27). The attribution is
correct.

**Resolution.** No edit. Refuted in eje (ii). The initial eje (i)
finding was a false positive. The attribution is correct, but the
value was not checked against the output; the eje (iv) cross-check
later found `8.5` should read `8.6` (C-36).

**Next step:** none.

### C-34 — Lambda for eigenvalues is standard notation (refuted)

**Location:** `docs/paper/main.tex` §2.2 (jump intensity) vs §5.4-§5.5 (eigenvalues).
**Status:** Refutado.
**Severity:** —

§2.2 uses `\lambda = 0.8` (Poisson intensity); §5 uses
`\lambda_{\max}(B)`, `-\lambda_{\min}(B)` (eigenvalues). The convention
`\lambda` for eigenvalues is universal (Wigner 1958; Bai-Silverstein
2010; Chung-Lu 2002). The sections are disjoint; no value contradiction.

**Resolution.** No edit. Refuted in eje (ii).

**Next step:** none.

### C-35 — Sigma glyphs live in distinct domains (refuted)

**Location:** `docs/paper/main.tex` §2.1, §2.5 and §3.3.
**Status:** Refutado.
**Severity:** —

§2.1 uses `\sigma_0` (diffusion constant); §2.5 uses
`\sigma^2(r) = \sigma_0^2 r` (local variance derived from `\sigma_0`);
§3.3 uses `\sigma = 0.05` (tensor noise std, a distinct domain). No
contradiction.

**Resolution.** No edit. Refuted in eje (ii).

**Next step:** none.

### C-36 — Eigenvalue rounding in §5.4 (`8.5` → `8.6`)

**Location:** `docs/paper/main.tex` §5.4 (`main.tex:727`).
**Status:** Cerrado.
**Severity:** Minor.

§5.4 reported `s[-2] = 8.5` for the balanced two-block structure.
The source cited (F-018 → `verification/rmt/recalibrate_top.py`,
assortative configuration 250/250, rho = 10) reports `mean_s2 =
8.5617` (`recalibrate_top_output.txt`, line 27). The paper's own
convention is round-half-up, not truncation: `85.7366` → `85.74` and
`52.5270` → `52.53` (`tucker_analysis_output.txt`, lines 25 and 28).
Applied to `8.5617` at one decimal the convention gives `8.6`, not
`8.5`. No output contains a value in `[8.45, 8.55)`; nothing is
truncated. By contrast `s[-1] = 17.5172` → `17.5` rounds cleanly.

Eje (i) and eje (ii) closed this neighbourhood as C-29 by attribution
only: the `\fref` to `recalibrate_top.py` is correct, but the value was
never checked against the output. C-36 is the value check eje (iv)
performs.

**Resolution.** `8.5` → `8.6` in §5.4. One-line edit. The qualitative
claim survives: the bulk edge is `2 \sqrt{\bar d} = 8.9443` for
`\bar d = 20`, so both 8.5 and 8.6 sit inside the bulk.

**Evidence:** `grep -c '\$s\[-2\] = 8\.5\$' docs/paper/main.tex` = 0;
`grep -c '\$s\[-2\] = 8\.6\$' docs/paper/main.tex` = 1; `pdflatex`
twice with no `^!` and no `Undefined`.

**Next step:** none.

### C-37 — §9.2 runtime table omits the heavy-tail rows

**Location:** `docs/paper/main.tex` §9.2 (Reproducibility), the runtime
table (`main.tex:1217`--`1142`).
**Status:** Cerrado.
**Severity:** Minor.

The §9.2 runtime table listed thirteen scripts and closed with
`All others < 5 s each`. The same subsection (`Total runtime ...
approximately 67 minutes ... dominated by the heavy-tail
recalibrations`) and §1.4 (`main.tex:116`) state that two scripts
outside the table run `15 min` and `24 min`. Those two scripts therefore
fall under "All others", whose `< 5 s each` bound is then false. C-18
had already fixed this table to "match the README rows at ≥5 s"; the two
heavy-tail rows were never added, so C-18's stated resolution was not
satisfied once the suite grew (§1.4 and §9.2 were re-derived to 67 min
by C-25, but the table itself was left behind).

**Resolution.** The two missing rows are added, derived from
`verification/README.md` `## Runtime` (not from memory):
`heavy_tail_scaled_clique.py` `~24 min` and `heavy_tail_n5000.py`
`~15 min`, both above the ten-minute `recalibrate_top.py`. The table now
lists the same fifteen `≥5 s` rows as the README, and
`All others < 5 s each` is true.

**Evidence:** `grep -nE 'heavy_tail_(n5000|scaled_clique)' docs/paper/main.tex`
returns the two rows in §9.2 and the §1.4/§9.2 prose;
`sed -n '/^## Runtime/,/^## Reproducibility/p' verification/README.md`
lists the same rows; `pdflatex` twice with no `^!` and no `Undefined`.

**Next step:** none.

### C-38 — §11.3 fourth contribution disagrees with the Abstract and §1.3

**Location:** `docs/paper/main.tex` Abstract (`main.tex:42`), §1.3
(`main.tex:75`--`90`), §11.3 (`main.tex:1442`--`1343`).
**Status:** Cerrado.
**Severity:** Minor.

The Abstract and §1.3 promise four contributions and name the fourth as
"a set of design decisions with explicit boundaries, stating where the
protocol cannot deliver a guarantee". §11.3 (Contributions) listed a
different fourth, "Local benchmarks of the EVM precompile costs", and
dropped the design-decisions item. The count matched ("four" in all
three places); the content of the fourth did not. Found by the eje (v)
integrated read of the compiled PDF.

**Resolution.** §11.3 item 4 → "A set of design decisions with explicit
boundaries … (Section~\ref{sec:limitations})"; the local benchmarks are
folded into item 2 (the numerical verification suite). The count stays
four in the Abstract, §1.3 and §11.3.

**Evidence:** `grep -n 'design decisions with explicit boundaries'
docs/paper/main.tex` returns the Abstract, §1.3 and §11.3; `pdflatex`
twice with no `^!` and no `Undefined`.

**Next step:** none.

### C-39 — §5.6 detection-power cross-ref points to §5.4

**Location:** `docs/paper/main.tex` §5.5 (`main.tex:731`), §5.6
(`main.tex:763`).
**Status:** Cerrado.
**Severity:** Minor.

§5.6 (The Detection Boundary) read "The detection power measured in
Section~\ref{subsec:null-distribution}", but `subsec:null-distribution`
is §5.4 (Null Distribution and Calibration); the detection power is
measured in §5.5 (Detection Power), which had no label. The reference
resolved to the neighbouring subsection.

**Resolution.** Add `\label{subsec:detection-power}` to §5.5 and redirect
the §5.6 reference to it. §5.7's citation of the null quantiles (which do
live in §5.4) is unchanged.

**Evidence:** `pdftotext -layout docs/paper/main.pdf | grep 'detection
power measured'` → "Section 5.5"; `pdflatex` twice with no `^!` and no
`Undefined`.

**Next step:** none.

### C-40 — §11.1 "five components" vs the seven-row §11.6 table

**Location:** `docs/paper/main.tex` §11.1 (`main.tex:1426`) and §11.6
(`main.tex:1477`--`1376`).
**Status:** Cerrado.
**Severity:** Minor.

§11.1 said the protocol is "built from five components" and grouped
payment, data layer and bootstrap into a single fifth item. §11.6
tabulates seven component rows (Reputation dynamics, Tensor compression,
ZK threshold proof, Collusion detection, Payment rule, Data layer,
Bootstrap). The same object was counted as five and as seven. §1.3 also
lists a third set of five protocol parts, which omits tensor and ZK.

**Resolution.** Un-group §11.1's fifth item into three (Payment rule §6,
Data layer §7, Bootstrap §8) and change "five" to "seven", so §11.1 and
§11.6 enumerate the same seven. §1.3's prose list is left as is.

**Evidence:** `pdftotext -layout docs/paper/main.pdf | grep -n 'built
from seven components'`; the §11.1 list and the §11.6 table both show
seven rows; `pdflatex` twice with no `^!` and no `Undefined`.

**Next step:** none.

### C-41 — §2.6 table uses undefined regime labels D4 / S2.2

**Location:** `docs/paper/main.tex` §2.6 summary table (`main.tex:313`).
**Status:** Cerrado.
**Severity:** Minor.

The §2.6 table read "D4 tail is geometric; S2.2 has no censoring".
Neither "D4" nor "S2.2" occurs anywhere else in the paper; the body
(§2.3) refers to the regimes as "first regime" and "second regime". The
labels are the script configuration names (`censoring_test.py`: "Section
2.2 parameters" = alpha 0.5, sigma0 0.8; "D4 analysis parameters" =
alpha 2.0, sigma0 0.5).

**Resolution.** Replace the opaque labels with the body's terminology.
The meaning was already correct (§2.3: the second regime has the
geometric tail, the first has no censoring), so only the labels change:
"Second-regime tail is geometric; first regime has no censoring".

**Evidence:** `grep -c 'D4\|S2\.2' docs/paper/main.tex` = 0; `pdflatex`
twice with no `^!` and no `Undefined`.

**Next step:** none.

### C-42 — §11.4 attributes §9.5 items to §10

**Location:** `docs/paper/main.tex` §9.5 (`main.tex:1278`), §11.4
(`main.tex:1452`).
**Status:** Cerrado.
**Severity:** Minor.

§11.4 opened by attributing its six-item open-problems list to "the
limitations section (Section~\ref{sec:limitations})" alone. Two of the
six ("Recursive proving time", "Teleporter latency") live in §9.5
(Deferred Benchmarks) and do not appear in §10. Reciprocally §10.5
(Reputation Model Selection) and §10.8 (Bootstrap Assumptions) are not in
§11.4, so the list is not a clean subset of §10. Note §9.5, not §9.4, is
Deferred Benchmarks; §9.4 is Stability of Conclusions.

**Resolution.** Add `\label{subsec:deferred}` to §9.5 and widen the §11.4
attribution to cite both sections: "The limitations section (Section 10)
and the deferred benchmarks (Section 9.5) identify …".

**Evidence:** `pdftotext -layout docs/paper/main.pdf | grep 'and the
deferred benchmarks'` → "(Section 10) … (Section 9.5)"; `pdflatex` twice
with no `^!` and no `Undefined`.

**Next step:** none.

### C-43 — §5.4 marked [CONJECTURE] as a prefix, not a suffix

**Location:** `docs/paper/main.tex` §5.4 (`main.tex:767`),
`CONTRIBUTING.md` (`CONTRIBUTING.md:14-15`).
**Status:** Cerrado.
**Severity:** Minor.

`CONTRIBUTING.md` rule 4 requires the marker as a **suffix** ("Use
`[CONJECTURE]` suffix in documents"). §5.4 opened its sentence with a
bold prefix, unlike §4.1 (`main.tex:460`) and §7.2 (`main.tex:535`),
which place the marker as a plain, unbolded suffix at the end of the
clause. `CONTRIBUTING.md` also spelled its own rule as "prefix",
contradicting its example.

**Resolution.** Moved the marker in §5.4 to the end of the sentence, in
the style of §4.1/§7.2 (no bold); changed `CONTRIBUTING.md:14-15` from
"prefix" to "suffix" (commit `edc29b9`, `fix(paper): C-43 ...`).

**Evidence:** `grep -in 'conjecture' docs/paper/main.tex` shows the §5.4
marker as a suffix (`main.tex:767`); `sed -n '14,15p' CONTRIBUTING.md`
prints "suffix"; `pdflatex` twice with no `^!` and no `Undefined`.

**Next step:** none.

### C-44 — Unused `conjecture` theorem environment in the preamble

**Location:** `docs/paper/main.tex` preamble (`main.tex:35`).
**Status:** Cerrado.
**Severity:** Trivial.

The preamble declared `\newtheorem{conjecture}[theorem]{Conjecture}`, but
the environment is never used (`grep -rn 'begin{conjecture}' docs/paper/`
is empty). It also invited a second, inconsistent way of marking
conjectures, at odds with the `[CONJECTURE]` suffix rule of
`CONTRIBUTING.md`.

**Resolution.** Deleted the `\newtheorem{conjecture}` line (commit
`55d4d90`, `fix(paper): C-44 ...`).

**Evidence:** `grep -rn 'begin{conjecture}' docs/paper/` is empty;
`grep -rn 'newtheorem{conjecture}' docs/paper/` is empty; `pdflatex`
twice with no `^!` and no `Undefined`.

**Next step:** none.

### C-45 — Worksheet missing the C-43/C-44 closure blocks

**Location:** `docs/audit/content-audit-pending.md`.
**Status:** Cerrado.
**Severity:** Trivial.

The handoff declared "C-01 through C-44, all closed" and "44 findings",
but this worksheet carried only 42 blocks (C-01 to C-42): the eje (vi)
findings C-43 and C-44 were recorded in the handoff table and in
`docs/audit/eje-vi-style-report.md` but never as worksheet blocks. The
handoff's own derivable counter (section 0, `grep -c '^### C-'`)
therefore returned 42, contradicting its prose.

**Resolution.** Added the C-43 and C-44 blocks above and updated this
worksheet's counter. The derivable count now matches the handoff prose.

**Evidence:** `grep -c '^### C-' docs/audit/content-audit-pending.md`
matches the handoff count; the worksheet is not a paper artifact, so no
`pdflatex` guard applies.

**Next step:** none.

### C-46 — `true`/`false positive` hyphenation in §5.4

**Location:** `docs/paper/main.tex` §5.4 (`main.tex:728`).
**Status:** Cerrado.
**Severity:** Minor.

The attributive term appeared in both forms, and both in the **same
line**: `main.tex:728` carried 2 `true-positive rate` and 3
`false-positive rate`, while seven other lines used the unhyphenated
`true positive rate`. The majority form is unhyphenated, and the
unhyphenated sense is the one used elsewhere.

**Resolution.** Removed the hyphen from the five strings on
`main.tex:728` (2 `true-positive`, 3 `false-positive`), unifying to
`true positive` / `false positive`.

**Evidence:** `grep -cE '[-](true|false)positive' docs/paper/main.tex`
= 0; `grep -cE '(true|false) positive' docs/paper/main.tex` = 8;
`pdflatex` twice with no `^!` and no `Undefined`.

**Next step:** none.

### C-47 — `heavy-tail` → `heavy-tailed` (§1.5, §9.2)

**Location:** `docs/paper/main.tex` §1.5 (`main.tex:115`), §9.2
(`main.tex:1237`).
**Status:** Cerrado.
**Severity:** Minor.

Both runtime sentences wrote the attributive "heavy-tail recalibrations",
while the rest of the paper uses `heavy-tailed` (6 occurrences). The
script names (`heavy_tail_n5000.py`, `heavy_tail_scaled_clique.py`) use
underscores and are not prose.

**Resolution.** `heavy-tail` → `heavy-tailed` in the two prose lines;
script names untouched.

**Evidence:** `grep -cE 'heavy-tail([^e]|$)' docs/paper/main.tex` = 0;
the count of `heavy_tail_n5000.py` is unchanged; `pdflatex` twice with no
`^!` and no `Undefined`.

**Next step:** none.

### C-48 — `fraud-proof` → `fraud proof`

**Location:** `docs/paper/main.tex` §7.2 (`main.tex:969`), §7.7
(`main.tex:1070`).
**Status:** Cerrado.
**Severity:** Minor.

The attributive term appeared as `fraud-proof` in two places while the
section title (`\subsection{The Fraud Proof Mechanism}`, `main.tex:975`,
§7.3) and two other lines used `fraud proof`. The majority form and the
section title are unhyphenated.

**Resolution.** Option (a): removed the hyphen at `main.tex:969` and at
the first occurrence in `main.tex:1070`; the title was already
unhyphenated. Option (b) (unify to the hyphenated form) was discarded: it
would touch 4 strings against 2.

**Evidence:** `grep -c 'fraud-proof' docs/paper/main.tex` = 0;
`grep -c 'fraud proof' docs/paper/main.tex` = 4; `pdflatex` twice with no
`^!` and no `Undefined`.

**Next step:** none.

### C-49 — `collusion test` → `collusion detection`

**Location:** `docs/paper/main.tex` §1.3 (`main.tex:76`), §11
(`main.tex:1442`).
**Status:** Cerrado.
**Severity:** Minor.

The protocol-component list in §1.3 named the component "the collusion
test", while the section title (`\section{Collusion Detection}`,
`main.tex:597`, §5) and the parallel enumeration in `main.tex:43` both use
"the collusion detection". A second occurrence in §11 (`main.tex:1442`,
the F-018 entry) also read "the collusion test".

**Resolution.** `collusion test` → `collusion detection` at both
occurrences. This finding was recovered after the C-45…C-48 closure: the
closure plan assumed a single occurrence, and the re-derivation found two.

**Evidence:** `grep -c 'collusion test' docs/paper/main.tex` = 0;
`grep -c 'collusion detection' docs/paper/main.tex` = 4; `pdflatex` twice
with no `^!` and no `Undefined`.

**Next step:** none.

### C-50 — `log of falsifications` → `falsification log`

**Location:** `docs/paper/main.tex` §11 (`main.tex:1440`).
**Status:** Cerrado.
**Severity:** Minor.

The canonical term is `falsification log` (16 occurrences, e.g.
`main.tex:111` "The falsification log"). A single variant, "a public log
of falsifications", appeared in the §11 traceability sentence.

**Resolution.** `log of falsifications` → `falsification log`. Recovered
by the same post-closure sweep: the closure plan had assumed the variant
was already normalised (`= 0`); the raw diagnostic disproved it (`= 1`).

**Evidence:** `grep -c 'log of falsifications' docs/paper/main.tex` = 0;
`grep -c 'falsification log' docs/paper/main.tex` = 17; `pdflatex` twice
with no `^!` and no `Undefined`.

**Next step:** none.


## Proposed order of attack

All findings C-01 through C-50 are closed. The list of closures is
above, in each block. No open finding remains.

The next iteration of the content audit should begin from the paper
as it stands after the closures of C-04, C-06, C-10, C-11, C-13. The
residual gaps that were not findings in this worksheet:

- (Closed as C-24) The §2.5 integro-differential equation
  (`eq:integro`) had zero implementation in the repository. The closed
  form `C_R(r) = 0.8 r/(1+r)` is the reference configuration; C-24 now
  checks it against the operator and records the running reward
  `pi(r)`.
- The `n >= 5000` experiment for separating the genuine heavy tail
  from the saturated hub core was run as C-22 (F-020) and extended as
  C-23 (F-021). It refutes the remedy and shows the failure is
  structural, not a clique-size artifact: at the `n = 500` clique
  fraction the ER baseline recovers full power while every Chung–Lu
  null does not. §5.4 therefore drops the remedy and §5.7 delegates the
  heavy-tailed defence to `S_min` (§6.3).

## Handoff

The entry point for the next session is `docs/audit/handoff.md`. This
worksheet is the record of individual findings; the handoff is the
durable pointer to rules, inventory, and the current closure state.
