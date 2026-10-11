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
    bash verification/audit-gate.sh                      # state of the whole chain (G1..G11)
    bash verification/fase0_anchor.sh --check            # re-derives the anchor and diffs it
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

- 36 non-archived `.py` files under `verification/` (43 total, 7 under
  `*/archive/`). 35 of them are the documented suite; the 36th is
  `verification/eip_cost_check.py`, the helper behind guard G7 (it writes
  nothing; it prints the EIP-196/197 cost table to stdout, which the gate
  discards with `>/dev/null 2>&1` — G7 reads only its exit code).
- Every suite script has a corresponding `*_output.txt` under the sibling
  `results/` directory (35 of 35).
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

### 5.1 The audit gate (Bloques A and B)

`verification/audit-gate.sh` re-derives the state of the repository and
prints one line per guard. It is the single command that closes the loop
between the README, the paper, the logs and the anchored outputs, and it
is what a new session should run first:

    bash verification/audit-gate.sh      # PASS=11 FAIL=0 SKIP=0 (exit 0)

| Guard | Definition (as implemented in `audit-gate.sh`) |
|---|---|
| G1 | `.py` file count under `verification/` at depth 2 (`find ... -maxdepth 2`) >= 35 |
| G2 | `EXIT 0` lines in the harness evidence log = scripts with a numeric row in the manifest |
| G3 | `DRIFT` lines in the harness evidence log = 0 |
| G4 | rows of `docs/audit/claim-registry.csv` with `class == 'Orphan'` or empty = 0 |
| G5 | `### F-` entries in `docs/audit/numerical-verification.md` = 21 |
| G6 | `### C-` worksheets in `docs/audit/content-audit-pending.md` = 50 |
| G7 | `python3 verification/eip_cost_check.py` exits 0 |
| G8 | no `Estimate`/`Verified` mix on one line of `docs/paper/main.tex` |
| G9 | `pdflatex` on `main.tex` x2: 0 `!` errors and 0 `Undefined`; SKIP without `pdflatex` |
| G10 | the anchor verifies: the master manifest pairs, **and** the 35 output hashes, **and** the anchored HEAD is an ancestor of HEAD |
| G11 | the anchor **re-derives**: `bash verification/fase0_anchor.sh --check` exits 0 (the 35 pairs, the seal and the anchored HEAD, recomputed in a temp dir) |

The same gate runs in CI (`.github/workflows/audit-gate.yml`, active since
`48b6a3c`, fixed in `56bf653`): `fetch-depth: 0` is **required** because G10
checks the anchored HEAD is an ancestor of the current one and G11 re-derives
that same ancestor criterion; a shallow checkout makes both FAIL (D10,
`bloque-b-report.md` §6.2). G9 degrades to SKIP on the runner (no `pdflatex`):
CI green at `PASS=10 FAIL=0 SKIP=1`. The full finding (why a fixed
`fetch-depth: N` does not suffice, and why G10 fails closed instead of
skipping) is recorded as D10 in `docs/audit/bloque-b-report.md` §6.2. The G9 SKIP
is itself a registered finding — D14, same §6.2: the runner has no LaTeX, so a
`main.tex` break that only `pdflatex` catches passes CI and fails only on a
TeX-equipped machine; the workflow does not install TeX Live because that install
cannot be pinned by full commit SHA the way its two actions are. The CI baseline
above (`PASS=10`) is therefore the *maximum* achievable on the runner, not a
degraded local run.

The anchor chain (Bloque B, `794ba7c`) is

    outputs  <-  verification/output_manifest.sha256       (35 pairs)
             <-  verification/audit_manifest.sha256        (HEAD + 2 pairs)
             <-  docs/paper/main.tex

Fase 0 (D1, `d4336ca`) adds a third, byte-deterministic artefact on top of the
two above — no header, no timestamp, no HEAD, so it re-derives anywhere:

    verification/anchor_root.sha256   (10 pairs) commits

      the anchor    docs/paper/main.tex
                    verification/output_manifest.txt
                    verification/output_manifest.sha256
      the verifier  verification/audit-gate.sh
                    verification/fase0_anchor.sh
                    verification/run_all.sh
                    .github/workflows/audit-gate.yml
      the inputs    docs/audit/claim-registry.csv
                    docs/audit/numerical-verification.md
                    docs/audit/content-audit-pending.md

G11 *re-derives* that root with `fase0_anchor.sh --check` and diffs it against
the committed file. The external timestamp (OpenTimestamps) is taken over the
root's digest, and its receipts live in `docs/audit/anchor-receipts.md`, outside
the root: including them would be circular.

Three properties, measured rather than argued, with the negative tests recorded
in `docs/audit/post-closure-audit.md`: G3 was a count of zero and passed
vacuously when the evidence log disappeared (B-2) — since `120634d` it fails
closed (`-s "${EVID}"`), so the test is now the guard; G4 counts orphans
*inside* the registry and does not see a new token that has no row, which is
still an open hardening opportunity (P-3, deferred); and G10 skips
(`PASS=9 FAIL=0 SKIP=1`, exit 0) when both sha256 manifests are removed, so a
repository with no anchor could come out green — the state that motivated G11,
recorded as D11 in `docs/audit/bloque-b-report.md` §6.2 and closed since it,
without touching G10's ratified definition.

Fase 0 ships a versioned generator, `verification/fase0_anchor.sh`, which
closes the third gap: it uses no `find` (it reads the closed list
`verification/output_manifest.txt`), it pins the manifest order so the result
does not depend on the machine locale, and its `--check` mode re-derives the
anchor into a temporary directory and diffs it against the committed one
without writing to the repository. Since G11 the gate *runs* that `--check` on
every pass, so the generator's use is verified instead of trusted: the latent
impact D9 recorded (a re-anchor under another ordering rule would be committed
silently) is covered by a guard, not by discipline.

**Re-anchoring recipe.** Any change to `docs/paper/main.tex` or to
`verification/baseline_verified/` invalidates the two older artefacts, and any
change to one of the ten files listed above — the anchor, the verifier, or the
three audit inputs — invalidates `anchor_root.sha256` as well (G11 and the
external seal follow it). Re-anchor atomically:

1. Make the change.
2. If outputs changed: `bash verification/run_all.sh` (deterministic; it rewrites
   `verification/baseline_verified/` and the closed list
   `verification/output_manifest.txt`).
3. `bash verification/fase0_anchor.sh` (it rewrites the **three** artefacts:
   `output_manifest.sha256`, `audit_manifest.sha256` and
   `anchor_root.sha256`). Generate *before* committing: the seal records the
   HEAD at generation time — which then remains an ancestor of the new commit
   (D7-b) — while the hashes it seals are those of the *new* content.
4. Commit the change **and all three artefacts** in the **same** commit. The
   anchor carries the `sha256` of `main.tex` and of `output_manifest.sha256`,
   and the root carries the ten hashes it commits, so committing the change
   alone leaves G10 and G11 failing at that commit.
5. Verify, then push: `bash verification/audit-gate.sh` gives `PASS=11 FAIL=0
   SKIP=0` locally (in CI `PASS=10 FAIL=0 SKIP=1`: G9 SKIP without `pdflatex`),
   and `git push` makes CI re-run the same gate on the pushed commit.

No guard executes this recipe. What G11 verifies is that the anchor *re-derives*
from the current tree, which is exactly what fails if the order above breaks.


## 6. The delivery arc, and one convention change

Two records the earlier sections do not carry. Both were added after
the audit/paper workstream closed.

**The M1–M8 delivery workstream.** The AVIP implementation milestones
M1 through M8 are registered in
`docs/architecture/implementation-plan.md` §5 ("Module map and
milestones"), one subsection per milestone, each titled "as delivered"
and each carrying the evidence that closed it; the architecture record
is `docs/architecture/avalanche-integration.md`. This handoff covers
the audit and paper chain only — nothing in sections 2 to 5 is about
them — so a session that reads only this file will not see them at all.
One chain is shared: the OpenTimestamps receipts over
`anchor_root.sha256` live in `docs/audit/anchor-receipts.md` (R-1.1 …
R-1.6 over the D1 root, R-2 over the root re-derived for P6a), outside
the root on purpose — a receipt that sealed the root would be circular
— and the proof itself is `verification/anchor_root.sha256.ots`.

**The convention change this file did not register.** The statements
that `docs/audit/session-report.md` is untracked *by convention*
(`eje-i-claims-report.md`, `eje-ii-consistency-report.md`,
`eje-iv-reproduction-report.md`, `eje-vi-session-context.md`,
`bloque-b-report.md`, `post-closure-audit.md`, and the report's own
closing list) were true when written: the latest of them,
`post-closure-audit.md`, audits `794ba7c` (2026-10-08). The file was
promoted to tracked by `b924b36` (M3) and is tracked since. Those
sentences are not corrected. Several of them are `git status` output
quoted verbatim (`?? docs/audit/session-report.md`), and the rule that
governs the dated acta applies — its own closing note in
`post-closure-audit.md` §6: they are actas fechadas with the HEAD of
their day, *con cifras caducas por diseño*. A dated actum is not
corrected, it is dated. The promotion is recorded here instead, which
is the third option `post-closure-audit.md` §6 weighed and did not
take: it neither rewrites a pushed commit (`git rm --cached` plus a
`.gitignore` entry) nor leaves a live claim false.

    git log --oneline --diff-filter=A -- docs/audit/session-report.md
    git log -1 --oneline -- docs/audit/session-report.md

**A clean tree is not a published tree.** `git status --short` empty
says the working tree matches `HEAD`; it says nothing about
`origin/main`. On 2026-10-11 the two disagreed by 23 commits: the whole
M1–M8 arc plus the P6a re-anchor existed on one disk under a clean
tree, while the remote stood at `810ea37`. Volatile state stays out of
this file; the check belongs to the closing routine, beside the tree
check.

    git rev-list --count origin/main..HEAD
    git ls-remote --heads origin        # the server, not the local ref

## 7. First message for the new session

Volatile values. Re-derive before trusting any of them.

    cd /home/ilich/Escritorio/diamond-framework
    git rev-parse HEAD
    git status --short
    md5sum docs/paper/main.tex docs/audit/content-audit-pending.md
