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

## 2. Backlog: C-01 through C-25, all closed

25 findings, all closed. Closure record in each block of the
worksheet. The compact table below is derived from `git log`; if it
disagrees with the log, the log wins.

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
