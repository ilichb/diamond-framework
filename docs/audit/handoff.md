# Diamond Framework — Session Handoff

Entry point for the next session on the content audit and paper
revisions. Replaces the session-1 handoff, which described the state
at 0eeea29 and no longer matches the repo.

This file is durable: it holds rules, inventory, closure record, and
residual gaps. It does not hold HEAD, md5, or tree state — those are
re-derived by the commands in section 0, or read from the first
message of the current session.

## 0. Anchors and derivable commands

Every value below is derivable. When a number can be obtained with a
command, the handoff gives the command, not the result.

    git rev-parse HEAD                                   # current commit
    git status --short                                   # tree state
    md5sum docs/paper/main.tex docs/audit/content-audit-pending.md
    grep -c '^### C-' docs/audit/content-audit-pending.md # findings count
    grep -c '^### F-' docs/audit/numerical-verification.md # log entries
    grep -c '^    python3 ' verification/README.md       # catalogued scripts
    find verification -name '*.py' -not -path '*/archive/*' | wc -l
    git log --format='%h %s' -- docs/paper/main.tex      # paper edits

## 1. Context

Repository: `ilichb/diamond-framework`. Paper source:
`docs/paper/main.tex` (LaTeX, source of truth). Overleaf project is
downstream-only: local pushes, Overleaf pulls. The repo is the source
of truth.

The content audit worksheet is `docs/audit/content-audit-pending.md`.
The falsification log is `docs/audit/numerical-verification.md`.

## 2. Backlog: C-01 through C-50, all closed

50 findings, all closed. Closure record in each block of the
worksheet. The compact table below is derived from `git log`; if it
disagrees with the log, the log wins. C-43 and C-44 were raised and
closed by the eje (vi) style pass; C-45 through C-48 by its closure
round, and C-49/C-50 by a post-closure terminology sweep (report:
`docs/audit/eje-vi-style-report.md`). Of the eje (vi) Sub-eje 1
terminology inventories, three were resolved — `heavy-tail` →
`heavy-tailed` (C-47), `true/false-positive` → unhyphenated (C-46),
`fraud-proof` → `fraud proof` (C-48) — and `net_gain` was left
unchanged: normalizing the identifier reaches 8 occurrences (prose,
paths, labels) and is an unopened STOP, not a finding.

| Finding | Title (short) | Script(s) | Commit(s) | main.tex |
|---|---|---|---|---|
| C-01 | ZK bit vs continuous value | threshold_quantization.py | 5248239, 7c31174, 42ae082, b751974, dc205df | no |
| C-02 | Pedersen binding | — (design decision) | a4eb339, 44decda, fc61a71 | yes |
| C-03 | MFPT ignores the jumps | mfpt_jump_diffusion.py | a6964d6 | yes |
| C-04 | Section 2 unused downstream | — (declared map) | 31186a7 | yes |
| C-05 | Asym explanation wrong | clique_spectra_seeds.py, asym_weights.py | 0eeea29 | yes |
| C-06 | Censoring test disagreement | censoring_test.py | 2d6a46b | yes |
| C-07 | −502 not the model value | attacker_profit_analytical.py | 3779272 | yes |
| C-08 | Revenue column gross | fee_specification_net.py | 3779272 | yes |
| C-09 | Bootstrap R_std mismatch | — (refuted) | f682d7d | no |
| C-10 | Heavy-tail not measured | calibration_heavy_tail.py | 7d7ec86, fc61a71 | yes |
| C-11 | Theta_r / VaR_tech undefined | — (definitions) | a2200a8 | yes |
| C-12 | §6.2 presupposes repair | — (textual) | 4f597a7 | yes |
| C-13 | Three forms of C_R | — (declared map) | 31186a7 | yes |
| C-14 | R_std never defined | r_std_specification.py | 82324e6 | yes |
| C-15 | Order of attack stale | — (worksheet-internal) | dc205df | no |
| C-16 | Script counter stale | — (counter) | f4de779 | yes |
| C-17 | Falsification counter | — (counter) | 92ea4a4 | yes |
| C-18 | §9.2 runtime table | — (counter) | 92ea4a4 | yes |
| C-19 | VaR_tech renamed to S_min | — (rename) | 563df9d | yes |
| C-20 | Succinctness of ingesting T | succinctness_comparison.py | aa7f642 | yes |
| C-21 | S_min derived from C_R | financial_floor_sensitivity.py | 469a532 | yes |
| C-22 | The n >= 5000 heavy-tail experiment | heavy_tail_n5000.py | 0c54363 | no |
| C-23 | Heavy-tail failure is structural, not clique scale | heavy_tail_scaled_clique.py | 3510769 | yes |
| C-24 | Closed-form C_R vs the IDE (eq:integro) | cr_ide_solver.py | 9d96b76 | yes |
| C-25 | Reproducibility counters (§1.4/§9/§11) | — (counter) | 047dc5c | yes |
| C-26 | F-log counter in §1.3 (words) | — (counter) | 1f46bd0 | yes |
| C-27 | F-log counter in Abstract (words) | — (counter) | 1f46bd0 | yes |
| C-28 | §5.2 per-pair ratio citation | asym_weights.py | 38d97ab | yes |
| C-29 | F-018 cites the correct script (refuted) | recalibrate_top.py | 9fa0a53 | no |
| C-30 | §10.5 unsourced 20--25% range | simulate_bootstrap_net_gain.py | bf91735 | yes |
| C-31 | §4.5 Poseidon-2 gas citation | — (benchmark) | ec38f91 | yes |
| C-32 | §8.3 transition rate alpha(t) glyph | — (rename) | 0c90d10 | yes |
| C-33 | §8.2 bootstrap decay rate mu glyph | — (rename) | e82243c | yes |
| C-34 | lambda for eigenvalues (refuted) | — (refuted) | bf602c0 | no |
| C-35 | sigma glyphs, distinct domains (refuted) | — (refuted) | d3e1942 | no |
| C-36 | Eigenvalue rounding in §5.4 | recalibrate_top.py | 5f76824 | yes |
| C-37 | §9.2 runtime table omits the heavy-tail rows | — (counter) | 3f998e7 | yes |
| C-38 | Abstract/§11.3 4th contribution mismatch | — (textual) | ac696c2 | yes |
| C-39 | §5.6 detection-power cross-ref → §5.4 | — (cross-ref) | f06fe16 | yes |
| C-40 | §11.1 "five" vs seven-row §11.6 table | — (counter) | cda36f6 | yes |
| C-41 | §2.6 undefined regime labels D4/S2.2 | — (textual) | cd6f8f4 | yes |
| C-42 | §11.4 attributes §9.5 items to §10 | — (cross-ref) | a5b0e30 | yes |
| C-43 | §5.4 [CONJECTURE] prefix→suffix | — (style) | edc29b9 | yes |
| C-44 | Unused conjecture theorem environment | — (style) | 55d4d90 | yes |
| C-45 | Worksheet missing C-43/C-44 blocks | — (worksheet) | dc62f1c | no |
| C-46 | true/false positive unhyphenated | — (style) | 065fc9a | yes |
| C-47 | heavy-tail → heavy-tailed | — (style) | 8c04346 | yes |
| C-48 | fraud-proof → fraud proof | — (style) | d04d5a4 | yes |
| C-49 | collusion test → collusion detection | — (style) | e08c862 | yes |
| C-50 | log of falsifications → falsification log | — (style) | 6cc8130 | yes |

The `main.tex` column is derived with
`git log --format='%h %s' -- docs/paper/main.tex`. C-05, C-12 and C-14
were audited in session 2 with `Status: Confirmed` but their Next step
(a paper edit) was applied in the commit that closes them, after the
audit-close commit.

Re-derive with:

    git log --format='%h %s' -- docs/paper/main.tex
    git log --format='%h %s' -- docs/audit/content-audit-pending.md
    git log --format='%h %s' -- verification/

## 3. Residual gaps (not findings)

Items declared in the worksheet's Proposed order of attack as
non-findings. They are not tasks and not bugs; they are design
decisions or contributions that require their own iteration. Item 1
was later formalized and closed as C-24.

1. (Resolved) `eq:integro` (§2.5). The integro-differential equation
   that defines `C_R(r)` is checked against the closed form
   `C_R(r) = 0.8 r/(1+r)` by
   `verification/stochastics/cr_ide_solver.py`: the implied running
   reward `pi(r)` is admissible in the operational range (`pi(r) > 0`
   for `r >= 1.0` in both regimes; `pi(r) = O(r)`; monotone above the
   admission threshold). Recorded as C-24.

2. (Resolved) The `n >= 5000` experiment for separating the genuine
   heavy tail from the saturated hub core was run as C-22
   (`verification/rmt/heavy_tail_n5000.py`, F-020) and extended as C-23
   (`verification/rmt/heavy_tail_scaled_clique.py`, F-021). The
   separation is structural, not a clique-size artifact: §5.4 drops the
   `n >= 5000` remedy and §5.7 delegates the heavy-tailed defence to
   `S_min`.

## 4. Rules

From `CONTRIBUTING.md`:

- A script for every number.
- Declared sample size.
- Reproducible output with a declared seed.
- `[CONJECTURE]` for conjectures.

Consolidated during session 2:

- One finding per iteration. One script, one commit, one verification.
- Stop and ask when a guard returns 0 and the expectation was >= 1.
- Enumerate `\section{}` before citing a section number.
- Do not conflate quantities in different units.
- Do not commit without verified raw output.
- Stop rule when a citable reference is missing: stop, report, do not
  invent.
- Counters and pointers are findings. Every edit that moves lines or
  adds/removes scripts leaves counters stale. After each commit, grep
  the relevant counters.
- Read the PDF end-to-end after a batch of edits. Fragment-level
  verification does not see prose incoherences that emerge when
  section 2.5, 4.1, 6.3, 7.2 and 8.1 are read as continuous text.
  C-17 and C-18 were found this way.
- Do not assert a derivable value; derive it. If a number can be
  obtained with git, grep or find, the handoff gives the command, not
  the result typed from memory.

Consolidated during session 3:

- When a plan produces N parallel edits, the commit-message templates
  must enumerate all 2^N subsets (or explicitly declare the intended
  subset). Assuming "all or nothing" leaves valid intermediate states
  unhandled and forces a stop that the plan did not anticipate. Case
  A.2: the guard tripped on a line-wrap false positive, and the
  {A.1 only, A.2 blocked} template was the missing case.

- When a plan requires a commit to reference its own hash, use a
  placeholder and fill it in a follow-up housekeeping commit.
  Self-reference is not a plan bug; the missing follow-up template
  was. (C-24.)
- The paper's own counters (§1.4, §9) must be re-derived after any
  batch that changes the script count or the F-log count. Deriving
  only the handoff and worksheet counters is insufficient; the paper's
  claims are the most visible to reviewers. (C-25.)

- Counter re-derivation must cover both digit and word forms. C-25
  caught four digit counters; C-26 and C-27 caught the same class in
  the Abstract and §1.3 written as "nineteen". A grep for digits alone
  is insufficient.

Consolidated during session 4:

- The content-audit and eje (ii) passes closed C-28 through C-35. C-29
  (a false positive of eje (i)) and C-34, C-35 (standard notation, no
  value contradiction) were refuted; C-28, C-30 and C-31 were citation
  gaps closed with a `\fref`; C-32 and C-33 were glyph reuses
  disambiguated by renaming the §8 symbols (`\alpha(t)` → `\tau(t)` and
  `\mu` → `\delta`), leaving the §2 mean-reversion `\alpha` and the
  §2.5 `\mu(r)` drift untouched.
- `run_all.sh --resume` must verify the existence of each script's
  `*_output.txt`, not only its numeric row in the manifest. `rm -f` of
  an output therefore requires removing its row from the manifest
  before relaunching; otherwise `--resume` skips a script whose output
  is gone. Hardened in `run_all.sh` (561e2cf): `DONE` now requires the
  output to exist and be non-empty, the stale row is dropped before
  re-executing, and the regression test deletes
  `sim_positivity_output.txt`, resumes, and asserts exactly one re-run
  and one manifest row.

Consolidated during session 5:

- Attribution is not value verification. Eje (i) checked that every
  number had a source; eje (ii) checked symbol consistency; neither
  compared the paper's value against the output's value. The §5.4
  `s[-2]` case was closed as C-29 by attribution only (the `\fref`
  was correct) while the value was wrong (`8.5` vs `8.6`). When a
  finding is closed by attribution, record explicitly that the value
  was not checked against the output; a numeric cross-check (eje iv)
  is a separate pass. (C-36.)

- A counter can contradict itself within a single subsection. The §9.2
  runtime table's `All others < 5 s each` was contradicted by the two
  heavy-tail figures cited three lines below in the same subsection, and
  the two `≥5 s` rows C-18 said the table matched were absent. When a
  table and its surrounding prose describe the same set, both must be
  cross-checked against the derivation. (C-37.)

Consolidated during session 6:

- C-49 (`collusion test` → `collusion detection`) and C-50 (`log of falsifications` → `falsification log`) are **new findings** discovered during the post-closure terminology sweep. They are not renumbered continuations of session-5 findings. The session-5 slots C-45 (worksheet gap) and C-46 (true/false-positive hyphenation) were applied in commits `dc62f1c` and `065fc9a` respectively, and their numbering was not reassigned.

- A prose value with no originating command is not a value, it is a hypothesis. Guards must be re-derived with the exact command that will verify them, not with a similar command from a previous block or a value summarized in prose.

## 5. Verification inventory

- 35 non-archived `.py` files under `verification/` (42 total, 7 under
  `*/archive/`).
- Every script has a corresponding `*_output.txt` under the sibling
  `results/` directory.
- All scripts are deterministic: seed declared, no clock, no entropy,
  no disk I/O.
- Every figure cited in `main.tex` traces to a script, a benchmark, or
  a falsification log entry.
- Falsification log F-001 through F-021 (21 entries). Seventeen are
  refuted or partially refuted, three are not applicable, misapplied,
  or mis-tested, and one (F-021) confirms a structural failure that
  amends the paper.

Re-derive with:

    find verification -name '*.py' -not -path '*/archive/*'
    ls verification/*/results/*_output.txt
    grep -c '^### F-' docs/audit/numerical-verification.md

## 6. First message for the new session

Volatile values. Re-derive before trusting any of them.

    cd /home/ilich/Escritorio/diamond-framework
    git rev-parse HEAD
    git status --short
    md5sum docs/paper/main.tex docs/audit/content-audit-pending.md
