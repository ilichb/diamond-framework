SUBMISSION_STATUS: submitted

# Team 1 mini grant — the application as sent

## What this file is

The record of what was actually sent to Team1, so that every other document in
`docs/grants/` can be checked against it instead of against the $50k research
proposal. That is the whole point of the file: [`README.md`](README.md) used to
describe the ask as the remediation tranche of
[`avalanche-research-proposal.md`](avalanche-research-proposal.md), and that is
not what was sent.

**Provenance, stated because the record has to be able to disappear and be
reconciled:** the block below is the text the repository owner pasted on
2026-10-27. It is the *milestone block and the declared out-of-scope*, verbatim.
It is **not** the whole application: the surrounding prose (title, one-paragraph
description, ask, delivery terms) was not pasted and is therefore not reproduced
here. Nothing below is paraphrased, and nothing was added to fill the gap — a
record that invents the parts it does not have is worse than one that says which
parts it lacks.

## The milestones, verbatim

```text
T1-M1: P-08, P-32, P-05/B-1, P-26, P-09 con B-5 y B-7, rotación del guardián, pausa.
T1-M2: P-18, P-12 (la opción elegida), P-17, B-4.
T1-M3: redespliegue, anuncio del verifier (2 días), epoch, prueba, admit; script y artefacto fijado; getter de MAX_NORM (B-10).
T1-M4: gate sobre contratos y cargo (B-8), SafeFork como omisión explícita (B-9), P-20, P-36, re-sellado y release, campaña de mutación con herramienta.
Fuera de alcance declarado en la solicitud: auditoría completa y ceremonia.
```

## How the IDs are read

The prefixes are the frozen ones in [`../audit/open-items.md`](../audit/open-items.md)
§1: `P-` is `docs/audit/audit-2026-10-20-in-progress.md`, `B-` is
`docs/audit/triage-external-review-2026-10.md`. `B-8`, `B-9` and `B-10` do not
exist in that triage file — they are the new IDs that registry assigns to items
the earlier plans named `V-8` (a series that does not exist anywhere in the
repository) and to two items that had no ID at all. The registry is the
authority on the mapping; this file only records what was sent.

## What the four milestones are, in one line each

| Milestone | Shape | What it is not |
|---|---|---|
| `T1-M1` | Fix the contract and gate defects an audit would open anyway: reentrancy and the norm bound (`P-08`), `P-32`, `P-05`/`B-1`, `P-26`, `P-09` with `B-5` and `B-7`, plus guardian rotation and pause | it is not an audit, and it does not cover the audit's findings |
| `T1-M2` | Settle the two decisions that change what gets deployed: the freshness binding (`P-18`, `P-12` with the option chosen, `P-17`) and `B-4` | it is not a circuit change; it is the decision that says whether one is needed |
| `T1-M3` | Redeploy and re-prove end to end: verifier announcement with its 2-day delay, an epoch, a proof, an admission; the deploy script and its pinned artefact; the `MAX_NORM` getter (`B-10`) | it is not a ceremony: the ceremony is a declared dependency (see below) |
| `T1-M4` | Close the delivery surface: the gate over contracts and charge (`B-8`), `SafeFork` as an explicit omission (`B-9`), the paper claims `P-20` and `P-36`, the re-seal and the release, and the mutation campaign run with a tool | it is not re-audit; it pays no third party |

## The dependency chain, and where the ceremony sits

```
P-08  →  P-12 decision (L1)  →  circuit frozen  →  ceremony  →  T1-M3 redeploy
```

`P-08` is first because a contract defect invalidates any deployment built on
top of it. The `P-12` decision is next because it decides the statement the
circuit proves; freezing before it is deciding in the dark. The ceremony comes
after the freeze and **before** the redeploy that `T1-M3` delivers — otherwise
the deployed verifier has no ceremony behind it and the redeploy has to happen
twice.

In this application the ceremony is **a declared dependency, not a milestone**:
it is out of scope (the last line of the block above), it is not paid for by
this grant, and `T1-M3` is blocked until it happens. That distinction is the
difference between a plan that assumes someone else's work and one that
pretends to have bought it.

## What this changes in the rest of the directory

- [`team1-reserved-work.md`](team1-reserved-work.md) is now keyed to this file:
  its `T1-M1`…`T1-M4` rows are these four lines, not `R1`…`R4`.
- The five rows that `avalanche-research-proposal.md` §5 funds (audit,
  remediation and re-audit, ceremony and transcript, fuzzing in CI, closure
  report from `F-023`) are **not** funded by this application. They stay in
  `team1-reserved-work.md` under their own status line, tied to
  `RESEARCH_PROPOSAL_STATUS`, because §7's "No line pays for work already done"
  is a statement about *that* budget and does not transfer to this one.
