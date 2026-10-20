# External Review Triage — Round 3 (v0.2.0)

## What this file is

A third review of the v0.2.0 paper arrived as a list of claimed defects.
This file records the disposition of every item against the **live**
repository at `d99c73a` / tag `v0.2.0`, using the same method as
`content-audit-pending.md` and `triage-external-review-2026-10.md`:

1. **Model** the discrepancy explicitly.
2. **Verify** it against the committed text, the committed output, and
   (where possible) a run of the script that backs the number.
3. **Record** the outcome: confirmed, partially confirmed, refuted, or
   already scoped.
4. **Propose** the correction only after the outcome is recorded.

It is a worksheet, not a paper artifact, and it is **not** sealed by
`verification/anchor_root.sha256`. No file under `docs/paper/` or
`verification/` is modified by this triage.

## State at triage time (verified, not assumed)

- `HEAD` = `d99c73a9783fc9ae3856c1a15b58d810d442637c`
  (`release: v0.2.0 — metadatos pre-tag + fix S-012`).
- `git describe --tags --always` = `v0.2.0`; the annotated tag
  `bebb9e78…` points at `d99c73a`.
- `sha256sum docs/paper/main.tex` =
  `107217541102518f573f7f842f46f8fb30047328f5f9e3aefe8a44b76efd3a4e`,
  byte-identical to line 1 of `verification/anchor_root.sha256`.
- `sha256sum verification/anchor_root.sha256` =
  `d8b63d299568db92c408e1b21c9302de3fb6c02dc6334129cedd7679550d7649`.
- GitHub Release and Zenodo v0.2.0: **not created**. The tag exists;
  no DOI has been minted for v0.2.0. The v0.1.0 DOI is `23268374`.

**Consequence.** Any edit to `main.tex` is a new change requiring the
full re-anchoring pipeline. The tag `v0.2.0` is already public and
should not be moved; a corrected paper must be a new commit and a new
tag (`v0.2.1`).

## Verdict summary

Legend: **C** confirmed; **P** partially confirmed; **R** refuted;
**S** already scoped by the paper or README.

| ID | Review item | Verdict | Severity |
|---|---|---|---|
| R3-01 | Cost of Attack claim is undefined; the 0.2 floor degrades it | **C** | P0 |
| R3-02 | Paper's ZK design contradicts the delivered `src/zk` implementation | **C** | P0 |
| R3-03 | Pedersen (Option B) vs Merkle (§7): nothing binds the roots on-chain | **C** | P0 |
| R3-04 | `p_fraud` is exogenous; the audit table is not an equilibrium | **C** | P0 |
| R3-05 | §7.2 says the data layer publishes; §7.5 says the validator publishes. Who is slashed? | **C** | P0 |
| R3-06 | Attack model evaluates `r_fraud = 1`, not the worst case `r_fraud → ∞` | **C** | P1 |
| R3-07 | Freshness bounds entry count, not the norm; one epoch can reach `C_R ≈ 0.70` | **C** | P1 |
| R3-08 | `f_c` is never specified; §2, §8 and §7 use three different models | **C** | P0/P1 |
| R3-09 | §3.1 domain violation (`‖T‖ = 73.07 > √500`) and overgeneralized blocky claim | **C** | P1 |
| R3-10 | `0.7764` / `0.3936` are means mislabelled as medians; map `r = R/(1+r)` is misapplied | **C** | P1 |
| R3-11 | The 573-constraint count is actually 3,621 for the Tucker reconstruction | **C** | P1 |
| R3-12 | `150 / 6,000 / 34,000` are EIP-1108, not EIP-196/197 | **C** | P1 |
| R3-13 | §4 proves a bit, §6 needs a value: paper text is stale; the circuit certifies the floor norm | **P** | P1 |
| R3-14 | `29.2×` is spurious precision and Table 11.1 overstates the collusion status | **P** | P1 |
| R3-15 | Title says September 2026; Table 4.4 is dated 2026-10-18 | **C** | P2 |
| R3-16 | 160 wei/gas looks too low; confirm the effective gas price | **P** | P2 |
| R3-17 | §9.3 never says how many AVAX one stake unit is worth | **C** | P2 |
| R3-18 | Block time measured on a low-traffic testnet; epochs not timestamp-based | **P** | P2 |
| R3-19 | Fuji has `verifier = address(0)` and no unbonding; "complete system" claim | **R/S** | — |
| R3-20 | Cannot reproduce −502 from 50 attacks × slash 10 | **R** | — |
| R3-21 | Fuji results do not state what they test and do not test | **P** | P2 |

## P0 — release blockers

### R3-01 — The Cost of Attack claim is undefined and the 0.2 floor contradicts it

**Location:** §1.2 (`main.tex:59`), §1.3 (`main.tex:78`), §6.3
(`main.tex:838-866`), `README.md:28,43`.
**Disposition: Confirmed.**
**Severity: P0 — headline claim.**

The paper says reputation lowers the financial barrier *"without degrading
the Cost of Attack that secures the network"* (`:59`). It then defines

    CoA(i) = S_f(i) + C_R(T(i)) >= Theta(t)          (main.tex:78, :838)

which is a **per-validator admission condition**, not a network-level cost
of attack. No section defines the pure-PoS comparator, the cost of
acquiring the reputation that earns the discount, or the cost of
controlling a third of the admitted set. The claim is therefore an
assertion, not a result.

The floor makes the objection concrete. With
`C_R(r) = 0.8r/(1+r)`, `C_R^∞ = 0.8` and
`S_min = Theta - C_R^∞ = 0.2` (`:866`). A coalition that can inflate its
own reputation to the saturation point pays **0.2 Theta of financial stake
per node**. Unless the protocol also prices the reputation-acquisition
cost and makes it non-refundable, the financial cost of admission has
fallen by 80%, which is the opposite of "without degrading".

The paper already records the two mechanisms that would have to carry the
missing argument, and both are declared incomplete:

- `C_R` is never at risk: the slash writes no reputation state
  (`:1056`; triage `A-20`).
- The collusion statistic is global and is not wired to admission or
  slashing (`triage-external-review-2026-10.md`, `A-15`).

**Action.** Either (i) define `CoA_PoS` and `CoA_hybrid` formally, include
the cost of acquiring `T`, and prove the inequality; or (ii) remove
"without degrading the Cost of Attack" from §1.2 and `README.md` and
state the weaker claim the model supports: *reputation lowers the
financial stake; the protocol does not yet bound the resulting cost of
attack*. Option (ii) is honest and cheap; option (i) is a research
programme, not a v0.2.1 edit.


### R3-02 — The paper's ZK design contradicts the delivered `src/zk` implementation

**Location:** §4.3–§4.4 (`main.tex:512-558`), `tab:design-gas`
(`:521-524`), `README.md` ("ZK threshold proofs (Bulletproofs)"),
against `src/zk/scripts/m4a_output.txt`, `src/zk/scripts/m4b_output.txt`,
`src/zk/README.md:27-43`, and
`docs/architecture/implementation-plan.md:190`.
**Disposition: Confirmed.**
**Severity: P0 — the paper and the artifact describe different systems.**

The paper's table says:

| Design | Constraints | Proof | Direct gas |
|---|---:|---:|---:|
| As specified (Tucker, no commitment) | 573 | 0.20 KB | ~206k |
| Option A: Merkle + full opening | 1,080,501 | 0.20 KB | ~470M |
| Option A′: Poseidon over full tensor | 240,261 | 0.20 KB | ~30M |
| Option B: Pedersen + Bulletproofs | 0 | 0.72 KB | ~6.5M |

It then says A′ is *"still too large for practical Groth16 proving on
consumer hardware"* (`:542`), that recursion is *"not optional"*
(`:546`), and adopts Option B with a recursive SNARK (`:558`).

The delivered implementation measures the opposite:

- `src/zk/scripts/m4b_output.txt`: **94,438 constraints**, proof
  **128 bytes compressed / 256 bytes on-chain**, setup 6.6 s,
  **prove 3.9 s**, verify 1.3 ms, `ic = 4`, verifies.
- `src/zk/README.md:33-43`: V3 (Poseidon + norm) **93,608
  constraints**; V2′ (Pedersen over Baby Jubjub + norm) **152,858**
  constraints; M4b V3 **94,438**; `D-M4-0` selects **V3**.
- `src/zk/README.md:190`: the paper-literal recursive construction is
  still **remaining**.
- `src/zk/scripts/m4a_output.txt`: the aggregated Bulletproofs range
  proof is **1,248 bytes**, not the paper's 0.72 KB estimate.

Consequences, in order of importance:

1. **A′ is practical.** The paper's 240,261 is an estimate; the measured
   V3 circuit is 94,438 and proves in 3.9 s. A 240k circuit is in the
   same range as V2′ (153,688, 6.3 s), not "impractical".
2. **Recursion is not required for on-chain cost.** A Groth16 proof
   verifies for ~206k gas regardless of whether the circuit has 94k or
   240k constraints. The table's "~30M direct" for A′ is the cost of
   doing Poseidon hashing *on-chain*, not the cost of verifying a
   Groth16 proof of the A′ circuit. The table compares the wrong
   alternatives.
3. **Option B is not the delivered design.** The code's sound statement
   is V3 Groth16, not Pedersen + Bulletproofs; the 0.72 KB estimate is
   also low by 1.7× for the range proof.
4. **"Groth16 recursion over BN254" is underspecified.** A Groth16
   verifier inside a BN254 circuit needs non-native arithmetic or a
   curve cycle; the paper cites the right families but does not fix the
   construction. The measured implementation avoids the problem by not
   recursing.

**Action.** Rewrite §4 around the measured V3/A′ pipeline: constraints,
proof size, proving time, direct Groth16 verification, and the data-layer
root. Treat recursion as an optional deferred benchmark, not as the
adopted design. Correct the 0.72 KB figure to the measured 1.248 KB if
Option B is retained anywhere. This is the single largest paper↔code
divergence in the release.


### R3-03 — Pedersen (Option B) and the Merkle root (§7) are not bound on-chain

**Location:** §4.3 (`main.tex:524,544`), §7.2–§7.3
(`main.tex:995-1002`), `src/zk/src/bridge.rs`, `src/zk/README.md:145-170`.
**Disposition: Confirmed.**
**Severity: P0 — soundness claim.**

Option B commits to the flattened tensor with a Pedersen commitment.
§7.2/§7.3 publish a **Merkle root** and verify per-entry inclusion
proofs. Nothing in the on-chain statement ties the Pedersen commitment
to the Merkle root. A verifier that accepts the norm proof learns
nothing about the tree the registry stores, and vice versa.

The repository contains `src/zk/src/bridge.rs`, but its own header is
explicit: the link is

    link = keccak256(abi.encodePacked(bytes32 merkleRoot,
                                      uint256 statementRoot,
                                      uint256 epoch))

and it is **a commitment, not a proof**. It lets a party that already has
the tensor recompute the tie; it does **not** give a verifier that only
has the two roots anything. `src/zk/README.md:165-169` says the same:
*"a verifier holding only the two roots learns nothing, because the link
needs the tensor."* The triage `A-11` conclusion that the repo "already
resolves it" is too strong: it resolves the off-chain recomputation, not
the trustless on-chain binding.

**Action.** Choose one:

- (a) Adopt a single Poseidon Merkle root over the tensor for both the
  norm proof and the per-entry fraud proofs (the reviewer's A′). This
  removes the bridge and the dual-commitment problem.
- (b) Keep two commitments and make the link part of the on-chain
  statement, with the trust assumption stated explicitly.
- (c) Keep the off-chain bridge and state that the data layer is trusted
  to publish the link; remove "the soundness gap is closed" from §4.

The paper currently does none of the three. The reviewer's "nothing binds
both commitments" is correct against the paper and against the on-chain
verifier; it is only partially answered by the off-chain `bridge.rs`.

### R3-04 — `p_fraud` is exogenous; the audit table is not an equilibrium

**Location:** §7.3 (`main.tex:1004-1025`), §7.4
(`main.tex:1028-1051`), `verification/data-layer/simulate_data_layer_v3.py`.
**Disposition: Confirmed.**
**Severity: P0 — the "equilibrium" label is wrong.**

The model writes

    n*(B) = floor(B / B*),   B* = c_audit / p_fraud

with `p_fraud = 0.10` a fixed parameter. At `B >= B*`, coverage is 1 and
the table's attacker profit is negative (`-502`). If `p_fraud` is the
attacker's choice, a rational attacker sets `p_fraud = 0`; then
`B* = c_audit / 0 -> infinity`, `n* = 0`, detection is 0, and fraud
becomes profitable again. The paper never closes this loop. The table is
a **conditional simulation at `p_fraud = 0.10`**, not an equilibrium.

This is the classic verifier's-dilemma/audit-game problem. The paper's
§10.2 already admits free-riding and the `B < B*` failure, but not the
endogeneity of `p_fraud`. The implementation plan's own finding 2 says
the script computes `n*` first and feeds it into the epoch loop, so the
Monte Carlo never tests whether `n*` auditors enter.

**Action.** Either (i) solve the mixed-strategy equilibrium (or cite a
standard audit-game solution and map it to these parameters), or
(ii) relabel the table as *comparative statics under an exogenous fraud
rate*, remove "equilibrium" from §7.3/§7.4, and state the circularity in
§10.2. Option (ii) is the minimum honest fix; it does not invalidate the
arithmetic, only the interpretation.

### R3-05 — "Who publishes the fraudulent leaf?" is undefined, so the slash has no subject

**Location:** §7.2 (`main.tex:995`), §7.3 (`:1002`), §7.5 (`:1063`),
`integrations/avalanche/contracts/AVIPRegistry.sol:321-347`,
`integrations/avalanche/contracts/AVIPValidatorManager.sol:194-262`.
**Disposition: Confirmed.**
**Severity: P0 — the enforcement path is underspecified.**

The paper says the commitment *"is produced by the data layer, not by the
validator"* (`:995`). §7.5 then says *"the attacker is a validator that
publishes a fraudulent leaf"* (`:1063`). Those are different subjects.
In the delivered contracts, `AVIPRegistry.postCommitment` is callable only
by the `sequencer` role, while `AVIPValidatorManager.slash` debits a
**validator's** escrow. If the sequencer publishes the fraudulent leaf,
the validator did not publish it; if the validator submits the leaf to
the data layer, the data layer is a relay. The paper never says which
address is slashed, on what evidence, or how the adjudicator maps a
fraudulent leaf back to a validator.

**Action.** Define the publisher, the relayer and the slashed subject in
one paragraph, and align them with the contracts. If the sequencer is the
publisher, the slash must target the sequencer's bond (which does not
exist in v1), not a validator's escrow. If the validator is the
publisher, the data layer is not the producer of the commitment. The
current text cannot be both.


## P1 — confirmed, should be fixed before v0.2.1

### R3-06 — The attack model does not evaluate the worst-case inflation

**Location:** §7.5 (`main.tex:1058-1063`),
`verification/mechanism/m05_attack_model.py` (Table 2).
**Disposition: Confirmed.**
**Severity: P1 — the quoted deterrence margin is not the worst case.**

The paper evaluates the deterrence condition at `r_fraud = 1` and
`omega = 0.10`, giving `q > 0.0625` at `k = 1` and `q > 0.375` at
`k = 9`. It calls this the "worst-case type"; `omega = 0.10` is the
worst case over `omega`, but **`r_fraud = 1` is not the worst case over
the certified norm**. As `r_fraud -> infinity`:

    C_R -> 0.8,  DeltaS -> 0.8,  L -> S_min = 0.2,
    G(k) = k * 0.10 * 0.8 = 0.08 k,
    q > G/(G+L):
        k = 1:  q > 0.08/0.28  = 0.2857
        k = 9:  q > 0.72/0.92  = 0.7826

The reviewer's `~0.29` and `~0.78` are correct. The paper's `0.0625` and
`0.375` are the `r = 1` row, not the worst case. `m05_attack_model.py`
prints the limit in Table 1 but never evaluates `q_min` at the limit.

There is a second modelling issue: `G = k * omega * DeltaS` is the
**opportunity cost of capital avoided**, which is the right gain for a
validator that already has the capital. For a capital-less attacker, the
gain from inflating reputation is the validation income it can earn with
less capital, not the interest saved on capital it does not have. The
paper's `G` can understate the attacker's gain unless the outside option
is "do not validate" and the model says so.

**Action.** Evaluate `q_min` over the full `r` grid including the limit,
or state explicitly that `r_fraud = 1` is the reference case and publish
the limit row. Define the attacker's outside option and whether `G` is
capital cost avoided or validation profit. The conclusion (the step
convention `q = 1` still satisfies the condition) survives, but the
margin is much thinner than the paper states.

### R3-07 — Freshness bounds the number of changed entries, not the norm

**Location:** §7.6 (`main.tex:1065-1074`), `AVIPRegistry.MAX_DELTA_ENTRIES`
(`AVIPRegistry.sol:45-52`), `main.tex:999`.
**Disposition: Confirmed.**
**Severity: P1 — the "second line of defense" does not protect the
security-relevant quantity.**

The bound is `gamma * N = 0.10 * 500 = 50` entries per epoch. It says
nothing about the magnitude of each change. If 50 entries move from 0 to
1, the Frobenius norm moves from 0 to `sqrt(50) = 7.071`, and

    C_R(7.071) = 0.8 * 7.071 / (1 + 7.071) = 0.701.

In one epoch the protocol can go from full stake (`S_f = 1.0`) to
`S_f = 0.299`, i.e. 70% of the reputation credit available in a single
epoch. The paper's claim that freshness "prevents a single undetected
fraud from contaminating the entire tensor" is true for the **count** of
entries, not for the **norm** that prices admission.

**Action.** Replace or supplement the entry-count bound with a bound on
the norm (or on the per-entry magnitude), e.g.
`||T_t - T_{t-1}||_F <= delta`, and state the `C_R` change it implies.
If the protocol keeps the count bound, say explicitly that it does not
bound the norm and remove the "second line of defense" framing.


### R3-08 — `f_c` is never specified, and the paper runs three different models

**Location:** §7.1 (`main.tex:983-990`), §2.1 (`:124-141`), §8.2
(`:1125-1134`), `src/datalayer/src/ingestion.rs`,
`docs/architecture/implementation-plan.md:1602-1614`.
**Disposition: Confirmed.**
**Severity: P0/P1 — the tensor's meaning is not reproducible from the
paper.**

The paper says `T[c,d,h] = f_c(events in window h)` and that `f_c` is a
public function "frozen at genesis" (`:983-990`). It never gives `f_c`.
The implementation deliberately does not invent it either: `src/datalayer`
carries `GenesisFormula` as a **declared instance** (weights
`(att, gov, liq) = 3/5/2`, scale 1000, genesis digest
`0x2fcd03b8…`), and the implementation plan says *"guessing `f_c` here
would be the same class of error as inventing `W`"* (`:1602-1614`).

The result is three models that are never reconciled:

- §2: CIR diffusion with multiplicative jumps on an unbounded state `r`.
- §8: `net_gain` ODE on a bounded score `R`, with a different value
  function.
- §7: a deterministic `f_c` over finalized events.

None of the three is what the data layer computes, and none is what the
paper's `C_R` uses. The tensor table of §3 is synthetic; the economic
table of §6 samples `||T|| ~ U[0,3]`; the data layer's `f_c` is an
interface. The paper's claims are therefore conditional on an object the
paper does not define.

**Action.** Either (i) specify a reference `f_c` (the `GenesisFormula`
instance is available and has a digest) and use it to generate the
tensor, or (ii) declare `f_c` as a protocol parameter/interface, make the
conditional nature explicit in §7.1, and remove any claim that the tensor
is reproducible from the paper alone. In both cases, state which of the
three models feeds `C_R` and which feeds the admission rule.


### R3-09 — The tensor table violates the declared domain, and the blocky claim is overgeneralized

**Location:** §3.1 (`main.tex:331`), §3.3 (`:377-380`), `:391`,
`verification/tensor/tucker_analysis.py:65-87`.
**Disposition: Confirmed.**
**Severity: P1 — a visible arithmetic contradiction and a wrong
explanation.**

§3.1 declares `T in [0,1]^{C x D x H}` with 500 entries. The maximum
Frobenius norm is `sqrt(500) = 22.3607`. The table reports:

    clean low-rank        ||T||_F = 73.068
    low-rank + noise      ||T||_F = 45.261

Both exceed the maximum of the declared domain. The script explains why:
`random_uniform` and `blocky` are generated with zero mean on
`[-0.5, 0.5]`, and `low_rank_clean` multiplies positive random factors
without clipping, so its entries can exceed 1. Those are synthetic test
tensors, not elements of `T in [0,1]^500`. The paper never says so.

The blocky explanation is also wrong. A tensor that is constant within
`K = 3` communities in mode `C` has **mode-0 rank at most 3**, not full
rank. The noiseless experiment confirms it:

    mode 0 singular values: 4.0285, 3.3674, 2.7326, 0, ...
    mode 1: rank 5; mode 2: rank 5
    HOSVD (4,3,3): relative error 0.5846
    HOSVD (4,5,5): relative error ~1e-15

The `R1 = 4` truncation captures the block structure exactly (`4 > 3`).
The 52.5% error of the noisy blocky tensor comes from truncating modes
`D` and `H` to 3, not from "HOSVD does not capture block structure." With
`K <= R1` the block structure is captured; the failure depends on `K`,
not on blockiness as such.

**Action.** State in the table caption that the four tensors are
synthetic test inputs outside the declared domain, and do not compare
their norms to `Theta_r`. Rewrite the blocky paragraph as: the mode-`C`
block structure has rank `K`; at `K = 3 < R1 = 4` it is captured, and the
error comes from modes `D` and `H`. If the paper wants a domain-respecting
experiment, generate `T in [0,1]^500` and recompute the table.


### R3-10 — The bootstrap reports means as medians, and the `r <-> R` map is misapplied

**Location:** §8.1 (`main.tex:1134`), §8.4 (`:1179-1192`), §9.3
(`:1289`), §10.9 (`:1426`),
`verification/bootstrap/simulate_bootstrap_net_gain.py:68,102-104`.
**Disposition: Confirmed.**
**Severity: P1 — headline number and label.**

`simulate_bootstrap_net_gain.py` stores `s_f.mean()` and `R.mean()` but
prints them under the headers `S_f med` and `R med`. The actual values at
the final epoch, reproduced from the same seed and RNG order, are:

| Quantity | Mean | Median |
|---|---:|---:|
| `R` | 0.393574 | 0.400000 |
| `S_f` | 0.776446 | 0.771429 |
| stake reduction | 22.36% | 22.86% |

The paper says "median `S_f = 0.7764`" and "median `R = 0.3936`"; both
are the means. The actual median pair is `(0.4000, 0.7714)`, and the
median reduction is **22.86%**, not 22.4%. The reviewer's `0.7741` is the
bootstrap form evaluated at the **mean** `R = 0.3936`; it is not the
actual median either. So the reviewer's specific arithmetic is right for
the pair the paper printed, but the underlying error is the mean/median
mislabel, not a 0.0023 discrepancy.


There is a second, larger inconsistency. The paper says `R = r/(1+r)`
and `C_R(r) = 0.8r/(1+r)`. Substituting `r = R/(1-R)` gives

    C_R(r) = 0.8 * (R/(1-R)) / (1 + R/(1-R)) = 0.8 R,

not `\tilde C_R(R) = 0.8R/(1+R)`. The bootstrap uses the latter. The
paper calls it a "bootstrap-specific form" (`:1134`), which is honest,
but `content-audit-pending.md` C-04 claims the two are the same function
("with `r = R/(1-R)`, `C_R(r) = \tilde C_R(R)`"), which is false. If the
consistent form `0.8R` is used, the median stake is
`1 - 0.8*0.4 = 0.68`, a **32% reduction**, not 22.4%.

**Action.** Choose one convention and use it everywhere:

- (a) Keep the bootstrap-specific `0.8R/(1+R)` and relabel all numbers
  as **mean**, not median; keep 22.36% and state that the bootstrap
  value function is a different model from §2.
- (b) Use the consistent map `C_R = 0.8R` and update the numbers to the
  ~32% reduction.
- (c) Use actual medians with the bootstrap form: `0.4000`, `0.7714`,
  22.86%.

Whichever is chosen, the script's `med` labels must be fixed, and C-04's
equivalence sentence must be removed or corrected.


### R3-11 — The 573-constraint count is actually 3,621 for the Tucker reconstruction

**Location:** §4.3 (`main.tex:531-538`), `tab:design-gas` (`:521`),
`verification/zk/soundness_zk_check.py:64-89`.
**Disposition: Confirmed.**
**Severity: P1 — arithmetic in a table.**

The paper derives

    R1 R2 R3 + R1 R2 R3 + C D H + 1 = 36 + 36 + 500 + 1 = 573

and labels it "the reconstruction." The two `36` terms are core-tensor
sizes, not the mode products. The actual multiplication count for
`G x0 A0 x1 A1 x2 A2` with `(C,D,H) = (20,5,5)` and
`(R1,R2,R3) = (4,3,3)` is:

    G x0 A0:  20 * 3 * 3 * 4  =   720
    x1 A1:    20 * 5 * 3 * 3  =   900
    x2 A2:    20 * 5 * 5 * 3  = 1,500
    squares:  500 entries -> 500 multiplications
    comparison: 1
    total:    3,621

The reviewer's "~3,100 multiplications plus 500 squares, order 3.6k" is
correct. The qualitative conclusion survives (3.6k is still small against
240k or 1.08M), but the table's number is wrong by a factor of 6.3.

**Action.** Replace 573 with 3,621 (or 3,620 if the final comparison is
counted as a linear constraint), update the derivation and the script,
and state that this is the unsound Tucker design, not the delivered V3
circuit.

### R3-12 — The gas constants are EIP-1108, not EIP-196/197

**Location:** §4.3 (`main.tex:510`), §9.3 (`:1265-1285`),
`integrations/avalanche/benchmarks/src/GasBenchmarks.sol:5-34`,
`verification/eip_cost_check.py`.
**Disposition: Confirmed.**
**Severity: P1 — factual citation.**

The measured base costs are:

    ecAdd      150
    ecMul    6,000
    ecPairing 45,000 + 34,000 k

Those are the **EIP-1108** (Istanbul) constants. EIP-196/197 originally
set `500`, `40,000`, and `100,000 + 80,000k`. The paper says the
measurements "match EIP-196 and EIP-197 exactly" (`:510`, `:1265`) and
labels the table "EIP-196/EIP-197 formula" (`:1269`). The numbers are
right; the cited EIP is the amendment, not the original.

**Action.** Cite EIP-1108 (which amends EIP-196/197) in the text and
table caption, and update `eip_cost_check.py`'s labels. No numeric change.

### R3-13 — §4 proves a bit while §6 needs a value: paper text is stale, the circuit already certifies the floor norm

**Location:** §4.1 (`main.tex:456-465`), §6.3 (`:860-868`),
`src/zk/src/native.rs:141-162`, `AVIPRegistry.sol:321-347`,
`AVIPValidatorManager.sol:194-223`, `verification/zk/threshold_quantization.py`.
**Disposition: Partially confirmed.**
**Severity: P1 — paper↔code mismatch, not a design flaw in the code.**

The paper's §4.1 states only `||T||_F >= Theta_r`, a bit. §6.3 then uses
`C_R(T) = C_R(||T||_F)` as a continuous value. Against the paper alone,
the reviewer's objection is correct: a bit does not determine the stake.
`threshold_quantization.py` quantifies the gap: the bit accepts
`||T|| in [0.5, 3]`, over which `C_R` spans `[0.2667, 0.6]` and the stake
spans 0.333 of `Theta`.

The delivered circuit closes this. `native::enforce_floor_norm` enforces

    c^2 <= Σ T_i^2 < (c+1)^2

with `c = certifiedNorm`, i.e. it certifies the **floor** of the norm,
not just a threshold. `AVIPRegistry.verifyThreshold` builds
`[root, epoch, certifiedNorm]` from its own state, so the caller cannot
substitute a different norm; `AVIPValidatorManager.admit` then enforces
`certifiedNorm >= Theta_r`. The statement is therefore a value
(`floor(||T||)`), not a bit.

**Action.** Update §4.1 to say the circuit certifies the floor norm and
that `Theta_r` is enforced by the manager, not by the circuit. Cite the
`src/zk` implementation and remove the stale "bit vs value" framing from
the paper. The reviewer is right about the text and wrong about the
delivered code; the paper is the side that needs the edit.


## P2 — confirmed presentation, measurement and scope items

### R3-14 — `29.2×` is a fragile point estimate, and Table 11.1 overstates the collusion status

**Location:** §5.5 (`main.tex:783-785`), §5.5 summary (`:822`),
Table 11.1 (`:1529`), `verification/rmt/wilson_intervals.py`.
**Disposition: Partially confirmed.**
**Severity: P1/P2 — status label, not the arithmetic.**

The paper reports both Wilson intervals: `A_sym [0.006, 0.167]` and
`B [0.954, 0.983]` (`:785`). The ratio `0.972/(1/30) = 29.16` is a point
estimate, and the paper says "approximately 29.2×"; the reviewer's claim
that the interval is missing is incorrect. What is fair is that the
`A_sym` estimate is `1/30`, so the ratio is fragile even though the
intervals do not overlap, and the summary row `A_sym vs B ratio =
29.2× — Verified` (`:822`) overstates the precision.

The larger issue is Table 11.1, which lists
`Collusion detection — Verified — rmt/` (`:1529`). The paper's own §5.7
and §10 report the heavy-tailed negative result (FPR 1.0, TPR 0.000 for
`beta <= 2.3`). The status should be qualified.

**Action.** Change Table 11.1 to
`Verified (synthetic ER only); negative on heavy-tailed`, and change the
ratio row from `Verified` to `Measured (point estimate; CI reported)`.
Keep the ratio; it is arithmetically correct.

### R3-15 — The title date is stale

**Location:** `main.tex:33`, `tab:fuji-gas` (`:570`).
**Disposition: Confirmed.**
**Severity: P2 — visible metadata.**

`\date{September 2026}` while Table 4.4 is dated `2026-10-18` and the
released PDF is `diamond-framework-2026-10-19.pdf`. The title page
contradicts the paper's own newest table.

**Action.** Set `\date{October 2026}` (or the release date) in the next
paper edit. This is a one-line change but still requires re-anchoring.

### R3-16 — 160 wei/gas is real for the Fuji transactions, but it is not a protocol constant

**Location:** §9.3 (`main.tex:1296`),
`integrations/avalanche/broadcast/Deploy*.s.sol/43113/run-latest.json`,
`verification/baseline_verified/fuji_gas_output.txt`.
**Disposition: Partially confirmed.**
**Severity: P2 — provenance, not an error in the conclusion.**

The Fuji receipts carry `effectiveGasPrice = 0xa0 = 160 wei`. Foundry's
own estimate in `fuji_phase1.txt` is `0.00000017 gwei` = 170 wei. So 160
wei is the actual effective price of those transactions, not a typo. It
is a low-traffic testnet observation, not a protocol constant.

The break-even conclusion is robust to the obvious correction. At 25 gwei
(a realistic C-Chain order of magnitude), 206,000 gas costs
`0.00515 AVAX`, still **43× below** the `1,085 gwei` break-even. At 160
wei it costs `3.30e-11 AVAX`.

**Action.** Cite the receipt/`fuji_gas_output.txt` as the source of the
160 wei, call it a testnet observation, and add the 25 gwei sensitivity
sentence. Do not change the conclusion.

### R3-17 — §9.3 never says how many AVAX one stake unit is worth

**Location:** §9.3 (`main.tex:1292-1296`), `DeployFujiPhase1.s.sol`
(`wad_per_unit = 1`), `MockBurnableERC20`.
**Disposition: Confirmed.**
**Severity: P2 — dimensional clarity.**

The break-even formula says "if one unit of stake is worth `p` native
units, the threshold scales by `p`", but never gives `p`. The Fuji
deployment uses a mock 18-decimal token with `wadPerUnit = 1`; it is not
AVAX. A reader cannot convert the `1,085 gwei` figure to an AVAX-denominated
gas price without `p`.

**Action.** Define `p` explicitly (e.g. `p = 1 AVAX` for the reference
mock token) or state that the result is per unit of stake and that `p`
scales it linearly. If the token is not AVAX, say so.


### R3-18 — Block time is a low-traffic testnet observation; the range is already pinned

**Location:** §9.3 (`main.tex:1308`), §9.4 (`:1322`),
`verification/fuji/measure_block_time.py:52-64`,
`verification/baseline_verified/fuji_block_time_output.txt`.
**Disposition: Partially confirmed.**
**Severity: P2 — scope, not a reproducibility bug.**

The script already fixes the block range (`59670000-59670099`), pins the
fixture, and computes the median, p95 and max deterministically. The
reviewer's request to "fix the block range in the script" is already
satisfied. What is not stated is that a 100-block sample on a low-traffic
Fuji C-Chain measures **load**, not a protocol constant, and that an
epoch should be defined in timestamps rather than a fixed block count.

The paper's conservative choice (p95 = 11 s, max = 28 s, not the 1 s
median) mitigates the first issue. The second remains: `N_b` is a
deployment parameter, and the paper does not say whether epochs are
block-counted or timestamped.

**Action.** Add one sentence: the measurement is a testnet observation,
the p95/max are the conservative scale, and a deployment should define
epochs by timestamp (or fix `N_b` explicitly) so the wall-clock window is
reproducible. The fixture and range are already correct.

### R3-19 — `verifier = address(0)` and no unbonding: already scoped, no "complete system" claim

**Location:** `main.tex:1371`, `:1377`, `README.md:49,51,202`.
**Disposition: Refuted as an overclaim; already scoped.**
**Severity: —.**

The paper says the Fuji deployment was made with
`verifier = address(0)` and that `verifyThreshold` reverts
`VerifierNotSet` until a real verifier is installed; a complete on-chain
exercise is Phase 2 work (`:1377`). It also says v1 has no exit queue, no
unbonding delay and no on-chain challenge window (`:1371`). The README
says the project is not a finished protocol, not a production
implementation, and that Fuji phase 1 is a testnet deployment only
(`README.md:49,51,202`).

I found no "complete system" or "sistema completo" claim in the paper or
README. The reviewer's conditional ("if v2.6 says complete system") is
not met. No change is required for correctness; a short
"what Fuji phase 1 demonstrates / does not demonstrate" table would make
the scope easier to see (R3-21).

### R3-20 — −502 is reproducible; the reviewer's arithmetic uses the wrong profit convention

**Location:** §7.4 (`main.tex:1039-1044`),
`verification/data-layer/simulate_data_layer_v3.py:52`,
`content-audit-pending.md` C-07.
**Disposition: Refuted as an arithmetic error; confirmed as a clarity
issue.**
**Severity: P2.**

The script computes

    attacker_profit = (n_frauds - n_detections) * 1 - n_detections * 10.

At coverage 1, `n_detections = n_frauds`, so the profit is
`-10 * n_frauds`. With seed 42 the mean is `n_frauds = 50.2`, hence
`-502.0`. The model value at exactly 50 frauds is `-500`; the `-2` is the
Monte Carlo realisation. The reviewer's "50 × 10 = 500, ±50 gain" assumes
detected frauds still earn the +1 gain; the script intentionally reverts
detected frauds, so the gain cancels. C-07 already records this.

**Action.** Add a parenthetical in §7.4: "`-502 = -10 × 50.2`, the seed-42
mean; the model value at 50 frauds is -500." Do not change the number.

### R3-21 — Fuji results need an explicit "what this tests / does not test" table

**Location:** §9.3 (`main.tex:1263-1298`), §10 (`:1371-1377`),
`README.md:202`.
**Disposition: Partially confirmed.**
**Severity: P2 — scope.**

The paper reports deployment gas (Table 4.4), block time, and the offline
contract suite, but does not state in one place that Fuji phase 1 does
**not** test incentives, real economic value, challenge latency, the
transport, or the verifier. The reviewer's request is a useful clarity
improvement, not a correction of a false number.

**Action.** Add a small table in §9.3 or §10:

| Fuji phase 1 tests | Fuji phase 1 does not test |
|---|---|
| Deployment gas and wiring | Incentive compatibility |
| Contract creation and roles | Real economic value at risk |
| C-Chain block time (100 blocks) | Challenge latency / adjudication |
| `verifier = address(0)` guard | Recursive SNARK / real verifier |
| Offline contract suite | Teleporter transport / AWM |

This also answers R3-19 without changing the paper's claims.


## Release recommendation

**Do not create the GitHub Release or the Zenodo v0.2.0 deposit yet.**

The tag `v0.2.0` is already public and must not be moved. A Zenodo DOI is
permanent and citable; minting one for a paper whose ZK section describes
a different design from the delivered `src/zk`, and whose Cost of Attack
claim is unsupported, freezes known errors into the public record. The
existing v0.1.0 DOI (`23268374`) remains the citable version.

Recommended sequence:

1. **Keep** `v0.2.0` as a development tag. Do not delete or move it.
2. **Decide the architecture** for v0.2.1: adopt the single Poseidon
   Merkle root + direct Groth16 (A′/V3) and drop the recursive Option B,
   or keep Option B and document the off-chain bridge/trust assumption.
   The measured `src/zk` already points to the first option.
3. **Fix the P0/P1 claims** in one batch on top of `d99c73a`.
4. **Re-run** the affected scripts, regenerate the PDF, run
   `verification/run_all.sh`, `verification/audit-gate.sh` (11/11) and
   `verification/fase0_anchor.sh --check`; write the next R-receipt.
5. **Tag `v0.2.1`**, create the GitHub Release and then the Zenodo "New
   version" deposit. Commit B (DOI in `CITATION.cff`, `.zenodo.json`,
   `README.md`) follows the new DOI.

If a release is unavoidable before the fixes, create the GitHub Release
as a **pre-release** with a "known defects" section that names R3-01,
R3-02, R3-03, R3-04 and R3-05, and **do not** mint a Zenodo version DOI
until v0.2.1. A pre-release with an explicit warning is defensible; a
Zenodo DOI for the same text is not.

## Minimum v0.2.1 batch

The cheapest honest batch, in dependency order:

1. **R3-02 / R3-03 — ZK architecture.** Rewrite §4 around the measured
   V3/A′ pipeline (94,438 constraints, 3.9 s, 256 B on-chain, ~206k gas,
   direct Groth16). If A′ uses a Poseidon Merkle root, state that it is
   the same root §7 uses. Remove the "recursion is not optional" claim.
   If Option B is retained, state the off-chain bridge and its trust
   assumption. This is the largest edit and the one that decides whether
   the paper describes the artifact.
2. **R3-01 / R3-04 / R3-05 — economics.** Either formalize `CoA` or
   remove "without degrading"; relabel the audit table as conditional
   statics; define the publisher and the slashed subject.
3. **R3-06 / R3-07 — attack model.** Add the `r -> infinity` row
   (`q > 0.286` at `k=1`, `q > 0.783` at `k=9`); replace the
   entry-count freshness bound with a norm bound or state its limits.
4. **R3-08 — `f_c`.** Cite the `GenesisFormula` instance or declare `f_c`
   an interface; state which model feeds `C_R`.
5. **R3-09 / R3-10 / R3-11 / R3-12 — numbers.** Domain caption, blocky
   rank, means vs medians, 3,621 constraints, EIP-1108.
6. **R3-13 / R3-14 — status labels.** Floor-norm certification in §4.1;
   Table 11.1 "ER synthetic only; negative on heavy-tailed."
7. **R3-15…R3-21 — metadata/scope.** Date, 160 wei source, `p`, block-time
   caveat, Fuji scope table, `-502` parenthetical.

## What is already closed (do not reopen)

- **A-1** (tensor domain) is already confirmed in the previous triage;
  R3-09 is the same defect plus the blocky explanation.
- **A-6/A-7** (abstract overclaims) were fixed in R-11; the current
  abstract says the ZK repair is "specified with estimated costs, not
  implemented" (`main.tex:43`).
- **A-14** (29.2× "straw man") is refuted: the paper compares `A_sym` and
  `B` on the same configuration and reports both Wilson intervals
  (`:783-785`). R3-14 is only about the status label.
- **C-07** (−502) is closed: it is the seed-42 realisation of
  `-10 * 50.2`; the model value is −500.
- **R3-19** is already scoped by `main.tex:1371,1377` and
  `README.md:49,51,202`; there is no "complete system" claim.

## Reproduction commands used in this triage

```bash
# Tensor domain and blocky rank
python3 verification/tensor/tucker_analysis.py

# Attack model at r_fraud = 1 (Table 2) and the limit r -> infinity
python3 verification/mechanism/m05_attack_model.py
python3 - <<'PY'
from fractions import Fraction as F
def cr(r): return F(4,5)*r/(1+r)
for k in (1,9):
    G=k*F(1,10)*cr(F(10**9)); L=max(F(1,5),1-cr(F(10**9)))
    print(k, float(G/(G+L)))   # 0.285714..., 0.782608...
PY

# Bit-vs-value quantisation
python3 verification/zk/threshold_quantization.py

# Old circuit count
python3 verification/zk/soundness_zk_check.py

# Delivered ZK circuit: 94,438 constraints, 3.9 s proof
sed -n '1,70p' src/zk/scripts/m4b_output.txt
sed -n '27,43p' src/zk/README.md

# Medians (the script stores means under "med" labels)
python3 - <<'PY'
# Re-run simulate_bootstrap_net_gain.simulate('hybrid_no_decay') and print
# mean/median of active_R and s_f; the committed output gives the means
# 0.393574 / 0.776446, the medians are 0.400000 / 0.771429.
PY

# Fuji effective gas price
python3 - <<'PY'
import json, glob
for f in glob.glob('integrations/avalanche/broadcast/Deploy*.s.sol/43113/run-latest.json'):
    d=json.load(open(f))
    for r in d.get('receipts',[]): print(f, r['effectiveGasPrice'])
PY

# Anchor/gate, after any paper edit
bash verification/audit-gate.sh
bash verification/fase0_anchor.sh --check
```


