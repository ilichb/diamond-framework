GRANT_STATUS: not-started

# Team 1 — reserved work (the blocked lane)

This file declares what waits for the grant and what does not. It exists because
two parties work on the same repository against the same grant, and a lane that
is not written down is a lane that gets done twice or not at all.

It lives in `docs/grants/`, which per [`README.md`](README.md) is deliberately
outside the research record and outside `verification/anchor_root.sha256`:
creating or editing it never re-seals the deposit.

## 0. The switch

Line 1 is the switch. Accepted values:

| Value | Meaning |
|---|---|
| `not-started` | nothing reserved is authorised; the lane is inert |
| `active` | the grant is funded; `G1`–`G5` and `R1`–`R4` may proceed |
| `released-self-funded` | the grant did not land; the same rows become ordinary self-funded work |

Only the repository owner edits line 1. An automated lane must read it from HEAD,
not from the working tree, so that a stale local edit cannot unlock the lane:

```
git show HEAD:docs/grants/team1-reserved-work.md | head -1
```

If this file is missing, renamed, or line 1 holds any other value, the lane is
`not-started`. Absence is not permission.

## 1. The two lanes

| Lane | May touch | Gate expectation |
|---|---|---|
| Reserved (`G1`–`G5`, `R1`–`R4`) | contracts, circuit, gate, `main.tex`, sealed files | blocked until line 1 says otherwise |
| Free (`L0`–`L6`) | new unsealed docs and notes; the paper only on a branch | 11/11 on `main`; a branch that edits an anchored file shows G11 red by construction |

The free lane is not free of consequences, and pretending otherwise is how two
lanes collide:

- adding any script under `verification/` moves G2, because the expected count is
  the sealed key `scripts 38` in `verification/count_manifest.txt`, cross-checked
  against the `## Running` block of `verification/README.md`;
- editing `docs/audit/claim-registry.csv` edits a sealed pair (anchor pair 8);
- publishing a paper revision means `main.tex` and the re-seal, i.e. the reserved
  lane.

**`L3` (detection-frontier numbers) and `L6` (regenerate claim-registry line
numbers) are therefore re-seal-gated, not free.** They are listed as free only in
the sense that they need no grant money.

## 2. What the proposal actually funds

§5 of the proposal, in its own order: (1) external audit of the nine contracts;
(2) remediation and re-audit of the diff; (3) a ceremony with ≥3 independent
participants and a published transcript; (4) a fuzzing and invariant campaign
(Echidna/Medusa) wired into CI, with the invariants published as properties;
(5) the closure report, appended to the falsification log as F-023 onward. §5
also says what it does not fund: mainnet deployment, a token, liquidity,
marketing, salaries, or any promise of adoption.

The first draft of the reserved list did not match that. Row by row:

| Funded item | In the first draft? | Row |
|---|---|---|
| (1) audit, plus brief, threat model, frozen audited commit | no | `G1` |
| (2) remediation of the audit's findings, one regression test each | no | `G2` |
| (2) re-audit of the diff | no | `G2` |
| (3) ceremony ≥3 participants **and published transcript** | partly: redeploy and announce were there, the transcript was not | `G3` |
| (4) Echidna/Medusa campaign in CI, invariants as properties | no — the draft reserved *mutation with tooling*, a different method | `G4` |
| (5) closure report as F-023 onward, plus re-seal | no | `G5` |
| §10 dissemination | no | `G5` |

And in the other direction, three groups were reserved that §5 does not pay for:
`P-12`/`P-17`/`P-18`/`B-4` (new mechanism, not remediation), `P-20`/`P-36` (paper)
and `B-8`/`B-10` (gate and contract hygiene). They are kept below as
self-funded, not as funded.

## 3. Funded rows (`G1`–`G5`) — what closes each

| Row | Work | Closes when |
|---|---|---|
| `G1` | Audit brief, threat model, and freezing the audited commit. Scope per `reviewer-checklist.md` | the brief is in the repo, the audited commit hash is recorded, and the checklist is scoped to it |
| `G2` | Remediation of the audit's findings, **one regression test per finding**, then re-audit of the diff. Also the catch-all for findings with no `P-`/`B-` ID, by definition | every finding has a fix, a test that fails before and passes after, a green gate, and a linked re-audit of exactly that diff |
| `G3` | Ceremony replacing the development key: ≥3 independent participants, **published transcript**, new verifier deployed, announced, executed | transcript published and the on-chain announce/execute pair recorded. **Precondition: `P-08` closed and the `P-12` option decided** — a ceremony that installs a verifier accepting a degenerate key installs the same hole with better ceremony |
| `G4` | Echidna/Medusa fuzzing and invariant campaign on the three stateful contracts, wired into CI, invariants published as properties | the CI job runs on every push and the property file is committed. This is **not** the mutation campaign of `B-8`; keeping them apart is the point |
| `G5` | Closure report as F-023 onward, plus re-seal and public write-up | the report is appended, the anchor is re-derived green, and the write-up is published |

## 4. Self-funded rows (`R1`–`R4`) — blocked until line 1 allows them

| Row | Items | Why it is not funded |
|---|---|---|
| `R1` | `P-08`, `P-32`, `P-05`/`B-1`, `P-26`, `P-09`/`B-5`/`B-7`, guardian rotation, pause | self-found findings, already documented in v0.2.2; §7 of the proposal says no line pays for work already done |
| `R2` | `P-12` (implementation of the chosen option), `P-17`, `P-18`, `B-4` | new mechanism, not remediation of an audit finding |
| `R3` | On-chain: publish an epoch, post a floor-proof over the live root, exercise `admit`, read `MAX_NORM` | §5 funds the ceremony, not exercising the admission path. §3.3 leans on this; §5 does not pay for it (see §6) |
| `R4` | `P-20`, `P-36`, `B-8` (gate extension), `B-10` (`MAX_NORM` getter), and any re-seal of `main.tex` or the registry | paper and repository hygiene |

Dependency chain, which is not a preference:

```
R1 (P-08) -> P-12 decision (free lane memo L1) -> circuit frozen -> G3 -> R3
```

`R2`'s `P-17` changes what a re-admission test may assert, so a free-lane test
written before it is a characterisation test with an expiry date, not a spec.

## 5. Never reserved (free lane)

| Row | Work | Note |
|---|---|---|
| `L0` | `docs/audit/open-items.md`: one registry, frozen numbering, collision register | done; see §7 |
| `L1` | `P-12` options memo, with `P-21` (the paper twin) | closes with a recommendation, not a diff; decides `R2` and gates `G3` |
| `L2` | `main.tex`: ACP-77 (`R4-D10`) and the `[CONJECTURE]` | **blocked by `R4`** for the BBP citation (`P-36`). The conjecture is the detection frontier (`P-35`), not `Θ_r` |
| `L3` | Detection-frontier research: sweep `density_factor ∈ {3,5,10}`, TPR at fixed `m`/`θ` with CI and `q99`; `R3-A-13-bis` | re-seal-gated: new scripts move G2 |
| `L4` | Staging contracts for the `P-11`/`P-14`/`P-15` family | staging only; nothing reaches a deployed address from here |
| `L5` | Design notes: `P-34`, recursion (`R3-A-10`), `B-9` | `B-9` is the `SafeForkTest` skip, documented rather than "fixed" |
| `L6` | Regenerate `claim-registry.csv` line numbers | re-seal-gated; no generator exists today, and G4 does not check line numbers, so the script needs its own verification |

## 6. Decisions only the owner can take

1. **CI policy for branches that edit an anchored file.** The workflow runs on
   every push and G11 re-derives the anchor, so such a branch is red by
   construction. Choose one: `[skip ci]`, a fork, accept the red badge, or filter
   branches in the workflow (a sealed file, so a re-seal).
2. **§3.3 versus §5.** §3.3 says the un-exercised admission path is what the
   audit and the tranche are for; §5 does not fund posting an epoch or exercising
   `admit`. Either §3.3 is tightened or `R3` is declared an unfunded commitment.
3. **Ceremony ordering.** `G3` before `R1(P-08)` is a mistake that looks like
   progress. If the audit is slow, the ceremony waits.
4. **`P-12` option.** Until `L1` closes, the circuit is not frozen and `G3` has
   nothing safe to install.

## 7. How to check this file

```
git show HEAD:docs/grants/team1-reserved-work.md | head -1   # the switch
bash verification/audit-gate.sh                              # expect 11/11
bash verification/fase0_anchor.sh --check                    # expect exit 0
```

The registry that resolves the IDs used above is `docs/audit/open-items.md`,
which is also outside the anchor and therefore safe to edit without a re-seal.

