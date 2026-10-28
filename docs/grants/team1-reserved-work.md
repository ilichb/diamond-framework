GRANT_STATUS: not-started
RESEARCH_PROPOSAL_STATUS: closed

# Team 1 — reserved work (the blocked lane)

Two different asks were written for two different programmes, and this file keeps
them apart. Line 1 governs the **mini grant** that was sent to Team1
([`team1-mini-grant-application.md`](team1-mini-grant-application.md): four
milestones, audit and ceremony out of scope). Line 2 governs the **$50k research
proposal** ([`avalanche-research-proposal.md`](avalanche-research-proposal.md)),
which was never sent because its call was closed. Merging the two is how a plan
starts promising an audit it never asked anyone to pay for.

The file exists because two parties work on the same repository, and a lane that
is not written down is a lane that gets done twice or not at all. It lives in
`docs/grants/`, which per [`README.md`](README.md) is outside the research record
and outside `verification/anchor_root.sha256`: creating or editing it never
re-seals the deposit.

## 0. The two switches

| Line | Governs | Accepted values | On `not-started` / `closed` |
|---|---|---|---|
| 1 `GRANT_STATUS` | `T1-M1`…`T1-M4` | `not-started` · `active` · `released-self-funded` | nothing reserved is authorised; the lane is inert |
| 2 `RESEARCH_PROPOSAL_STATUS` | `G1`…`G5` | `closed` · `submitted` · `funded` | the five §5 rows are dormant; nothing may claim them |

Only the repository owner edits these lines. An automated lane must read them
from HEAD, not from the working tree, so that a stale local edit cannot unlock
the lane:

```
git show HEAD:docs/grants/team1-reserved-work.md | head -2
```

If this file is missing, renamed, or a line holds any other value, that lane is
`not-started`/`closed`. Absence is not permission.

## 1. The two lanes

| Lane | May touch | Gate expectation |
|---|---|---|
| Reserved (`T1-M1`…`T1-M4`, `G1`…`G5`) | contracts, circuit, gate, `main.tex`, sealed files | blocked until the switch that governs the row says otherwise |
| Free (`L0`–`L6`) | new unsealed docs and notes; the paper only on a branch | 11/11 on `main` |

The free lane is not free of consequences, and pretending otherwise is how two
lanes collide:

- adding any script under `verification/` moves G2, because the expected count is
  the sealed key `scripts 38` in `verification/count_manifest.txt`, cross-checked
  against the `## Running` block of `verification/README.md`;
- editing `docs/audit/claim-registry.csv` edits a sealed pair (anchor pair 8);
- publishing a paper revision means `main.tex` and the re-seal, i.e. the reserved
  lane.

**Accepting a red branch, decided 2026-10-27.** A branch that edits an anchored
file fails G11 by construction, because G11 re-derives the anchor from the
committed manifest. The workflow is itself a sealed file, so it is not filtered
and not touched: a red badge on such a branch is the correct answer, not a defect.
What matters is that `main` stays green, and it does — the gate is 11/11 at
`57e59b6`. Branches that knowingly edit an anchored file take the `wip/` prefix so
that a red run is read as expected rather than as a regression:

```
git switch -c wip/<short-name>      # edits an anchored file
git switch -c research/<short-name> # unsealed docs only; must stay 11/11
```

**`L3` (detection-frontier numbers) and `L6` (regenerate claim-registry line
numbers) are therefore re-seal-gated, not free.** They are listed as free only in
the sense that they need no grant money.


## 2. What the Team1 mini grant funds (`T1-M1`–`T1-M4`)

The milestones are the four lines of
[`team1-mini-grant-application.md`](team1-mini-grant-application.md), in its own
order. This table adds only what the application leaves implicit: what each row
touches and what makes it close.

| Row | Items | Closes when |
|---|---|---|
| `T1-M1` | `P-08`, `P-32`, `P-05`/`B-1`, `P-26`, `P-09` with `B-5` and `B-7`, guardian rotation, pause | each item has a fix and a test that fails before it and passes after; the guardian rotation and the pause are exercised by tests, not only by the delay logic that already exists |
| `T1-M2` | `P-18`, `P-12` (the option chosen), `P-17`, `B-4` | the `P-12` option is chosen in writing, `P-18`/`P-17` are closed or explicitly deferred against it, and `B-4` is resolved. Until this closes, the circuit is not frozen |
| `T1-M3` | Redeploy; verifier announcement with its 2-day delay; an epoch, a proof, an admission; deploy script and pinned artefact; `MAX_NORM` getter (`B-10`) | the operator and the verifier are redeployed, `postCommitment` → `verifyThreshold` → `admit` runs end to end on the new deployment, the script and its artefact are pinned in the repo, and `B-10`'s getter is live |
| `T1-M4` | Gate over contracts and charge (`B-8`), `SafeFork` as an explicit omission (`B-9`), `P-20`, `P-36`, re-seal and release, mutation campaign with tooling | the gate runs over the contracts and the charge path, the `SafeFork` skip is documented as an omission rather than silenced, the two paper items are closed, the anchor is re-derived green after the re-seal, and the mutation campaign runs from a committed harness |

Declared out of scope by the application, and therefore in no row: **the full
audit and the ceremony.** `T1-M3` needs the ceremony to have happened, and the
ceremony is `G3` — a dependency of this lane, not a row of it. Nothing here is
labelled self-funded, because nothing here is outside the application: these four
rows are what the application buys, and they sit inert only while line 1 says
`not-started`.

## 3. The dependency chain

```
P-08 (T1-M1) -> P-12 decision (L1) -> circuit frozen -> ceremony (G3) -> T1-M3
```

- `P-08` comes first because a contract defect invalidates any deployment built
  on it.
- The `P-12` decision comes next because it decides the statement the circuit
  proves. Freezing before it is deciding in the dark.
- The ceremony comes **after** the freeze and **before** `T1-M3`. A ceremony that
  installs a verifier over an undecided statement installs the same hole with
  better ceremony, and a redeploy that precedes it has to be done twice.
- `G3` before `T1-M1`'s `P-08` is a mistake that looks like progress. If the
  audit is slow, the ceremony waits.

`T1-M2`'s `P-17` changes what a re-admission test may assert, so a free-lane test
written before it is a characterisation test with an expiry date, not a spec.

## 4. The $50k research proposal (`G1`–`G5`), governed by line 2

This section is about a different ask. `avalanche-research-proposal.md` §5 funds,
in its own order: (1) external audit of the nine contracts; (2) remediation and
re-audit of the diff; (3) a ceremony with ≥3 independent participants and a
published transcript; (4) a fuzzing and invariant campaign (Echidna/Medusa) wired
into CI, with the invariants published as properties; (5) the closure report,
appended to the falsification log as F-023 onward. §5 also says what it does not
fund: mainnet deployment, a token, liquidity, marketing, salaries, or any promise
of adoption. §7 adds the sentence that makes the budget honest, and it is quoted
here because here is the only place it applies: **"No line pays for work already
done."** It says nothing about the mini grant, whose rows are work that is not done
yet.

| Row | Work | Closes when |
|---|---|---|
| `G1` | Audit brief, threat model, and freezing the audited commit. Scope per `reviewer-checklist.md` | the brief is in the repo, the audited commit hash is recorded, and the checklist is scoped to it |
| `G2` | Remediation of the audit's findings, **one regression test per finding**, then re-audit of the diff. Also the catch-all for findings with no `P-`/`B-` ID, by definition | every finding has a fix, a test that fails before and passes after, a green gate, and a linked re-audit of exactly that diff |
| `G3` | Ceremony replacing the development key: ≥3 independent participants, **published transcript**, new verifier deployed, announced, executed | transcript published and the on-chain announce/execute pair recorded. **Precondition: `P-08` closed and the `P-12` option decided** — a ceremony that installs a verifier accepting a degenerate key installs the same hole with better ceremony |
| `G4` | Echidna/Medusa fuzzing and invariant campaign on the three stateful contracts, wired into CI, invariants published as properties | the CI job runs on every push and the property file is committed. This is **not** the mutation campaign of `B-8`/`T1-M4`; keeping them apart is the point |
| `G5` | Closure report as F-023 onward, plus re-seal and public write-up | the report is appended, the anchor is re-derived green, and the write-up is published |

Line 2 is `closed`, so all five rows are dormant: no row may be started "because
the ceremony has to happen anyway", and no row may be described as funded. If the
call reopens, the send is the one in [`README.md`](README.md) §"How it is sent",
including the honest boundary in the cover note — testnet, unaudited, development
key, and the call was closed when the proposal was written.

**The one place the old §3.3-versus-§5 problem still exists** is this budget.
§3.3 leans on the un-exercised admission path as what the audit is for, and §5
does not fund posting an epoch or exercising `admit`. In the mini grant that
problem is gone: certified admission is `T1-M3`, and it is paid for. Here it stays
open until either §3.3 is tightened or the exercise is declared an unfunded
commitment.

## 5. Never reserved (free lane)

| Row | Work | Note |
|---|---|---|
| `L0` | `docs/audit/open-items.md`: one registry, frozen numbering, collision register | done; see §7 |
| `L1` | `P-12` options memo, with `P-21` (the paper twin) | written: `docs/architecture/p12-freshness-binding.md`. Closes with a recommendation, not a diff; `T1-M2` executes the chosen option and `G3` waits for it |
| `L2` | `main.tex`: ACP-77 (`R4-D10`) and the `[CONJECTURE]` | **blocked by `P-36`** for the BBP citation, which is `T1-M4`. The conjecture is the detection frontier (`P-35`), not `Θ_r` |
| `L3` | Detection-frontier research: sweep `density_factor ∈ {3,5,10}`, TPR at fixed `m`/`θ` with CI and `q99`; `R3-A-13-bis` | re-seal-gated: new scripts move G2 |
| `L4` | Staging contracts for the `P-11`/`P-14`/`P-15` family | staging only; nothing reaches a deployed address from here |
| `L5` | Design notes: `P-34`, recursion (`R3-A-10`), `B-9` | `B-9` is the `SafeForkTest` skip, documented rather than "fixed"; `T1-M4` is what makes the omission explicit in the delivery |
| `L6` | Regenerate `claim-registry.csv` line numbers | re-seal-gated; no generator exists today, and `G4` does not check line numbers, so the script needs its own verification |

## 6. Decisions only the owner can take

1. **CI policy for branches that edit an anchored file — decided 2026-10-27:
   accept the red, do not touch the workflow, prefix those branches `wip/`.** See
   §1. `main` stays green; nothing else is required.
2. **§3.3 versus §5 — decided 2026-10-27: it does not apply to Team1.** Certified
   admission is `T1-M3` and is funded. It survives only for the $50k proposal, §4
   above.
3. **Ceremony ordering — decided 2026-10-27: never before `P-08`, never before
   the circuit is frozen.** Matches the chain in §3.
4. **`P-12` option — open.** `L1` closes with the analysis; the owner chooses, and
   `T1-M2` executes. Until then the circuit is not frozen and `G3` has nothing
   safe to install.

## 7. How to check this file

```
git show HEAD:docs/grants/team1-reserved-work.md | head -2   # both switches
bash verification/audit-gate.sh                              # expect 11/11
bash verification/fase0_anchor.sh --check                    # expect exit 0
grep -cE '`R[1-4]`' docs/grants/team1-reserved-work.md    # expect 0: the R1–R4 labels are retired
grep -n 'No line pays' docs/grants/team1-reserved-work.md    # expect only §4
```

The registry that resolves the IDs used above is `docs/audit/open-items.md`,
which is also outside the anchor and therefore safe to edit without a re-seal.

