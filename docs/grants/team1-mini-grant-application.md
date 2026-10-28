SUBMISSION_STATUS: submitted-unverified

> **Reconstructed working draft: not verified as the text submitted.** The owner could not locate the submitted copy. This is the last working draft prepared before submission; the four milestones and the out-of-scope list are the ones the lane in `team1-reserved-work.md` is keyed to. If the original is found, replace this file verbatim and re-check the mapping.

# Team 1 mini grant — reconstructed working draft

## What this file is now

Until 2026-10-28 this file carried `SUBMISSION_STATUS: submitted` and a block of
milestone IDs that the repository owner had pasted on 2026-10-27 as *what was
sent*, with the surrounding prose declared missing. That framing does not survive
the owner's second look: **the submitted copy cannot be located**, so nothing here
can be presented as the text Team1 received.

What replaces it is the last working draft prepared before submission, reproduced
below verbatim from the owner's paste of 2026-10-28, plus — kept separately, one
section down — the milestone-ID block that the lane in
[`team1-reserved-work.md`](team1-reserved-work.md) is keyed to. The split matters:
the draft says what the work *is*, the ID block says which registry item each
piece maps to, and only the second can be checked against `open-items.md`.

The `[verify]` markers are the owner's and are **unresolved**. They are left
unresolved on purpose: filling them from the repository would turn a draft into a
record, which is the one thing this file must not fake.

## The draft, verbatim

Amount: [verify] (el tope del mini grant era $10,000; no hay cifra confirmada de lo enviado)

Briefly describe your project and what the grant will fund

The Diamond Framework’s Avalanche contracts are deployed on Fuji, and the registry installed its verifier on 2026-10-26, but no admission has been certified on-chain yet. This grant funds direct development to close the known defects on the admission path, add the missing lifecycle controls, and produce the first certified on-chain admission on Avalanche, with every artifact pinned and reproducible. All work is in the public repository. No external audit or third-party service is funded; a full audit and the trusted-setup ceremony remain separate, declared dependencies.

Why you’d be a great fit for a mini grant

The repository is public and its claims are reproducible: a Foundry suite ([verify] passing, 1 skipped fork test that needs an RPC), a 38-script verification suite with byte-identical reruns, and an audit gate that re-derives a sealed anchor over the paper and its evidence. The project separates what is deployed from what is designed or deferred: the contracts run on Fuji testnet, the registry installed its verifier on 2026-10-26, and nothing is deployed to mainnet. The verifier on Fuji uses a development key and the code has not been externally audited; both are stated in the README.

The development effort is dedicated to the Diamond Framework and visible in the history: 262 commits between 2026-09-15 and 2026-10-26 [verify], a published paper (Zenodo), a falsification log of 22 entries, and a content audit of 50 findings, each closed with the script or edit that closed it.

Development to date, of this repository and of Andromeda’s other protocol and chain integrations, has been entirely self-funded by Andromeda Computer; no external funding has been received. Separately, Andromeda Core is running a four-week pilot with Rootstock Collective (14 Oct–11 Nov 2026), announced publicly and governed in the Collective’s proposal thread. That grant is payable only if the pilot completes successfully and has not been paid. It is a different project for a different ecosystem, built on reputation technology; it is unrelated to the Diamond Framework and its Avalanche contracts, and it funds none of the milestones here. The pilot has not concluded and no conversion claim is made.

The gap is specific and bounded: from an installed verifier to the first certified admission on Avalanche, and from a reproducibility gate that covers the paper to one that also covers the contracts. The milestones are sequential and all live in the same public repository; each one leaves on-chain or reproducible evidence. No token or equity is involved, and the grant does not fund any external service.

Milestones

1. Registry and deployment hardening (weeks 1–2). Reject degenerate verifying keys (P-08). Fix the latestEpoch griefing path (P-32). Close the manager-binding race at deployment (P-05). Make deployment guards fail closed (P-26, P-09). Add guardian rotation and a pause function to the registry. Deliverable: contracts, regression tests that fail on the current code, updated deployment scripts.

2. Enforcement chain and admission lifecycle (weeks 3–5). Implement the bounty payment path (P-18). Bind freshness to the committed root instead of the declared delta (P-12). Add recertification and voluntary exit with a queue (P-17), and a withdrawal delay (B-4). Deliverable: contracts, tests and NatSpec, with the mechanism changes documented.

3. First certified admission on Fuji, on the final deployment (weeks 6–7). Redeploy the hardened contracts, announce the verifier through the two-day delay, post an epoch and a proof the installed key accepts, and execute admit on-chain. Deliverable: the on-chain transaction hash, a pinned deployment artifact, and a script that regenerates the result from the tagged commit.

4. Reproducibility gate and paper corrections (week 8). Extend audit-gate.sh and run_all.sh to the Solidity contracts, forge and cargo. Make the Safe fork test an explicit offline skip. Correct the stationary-moments table label and the bibliography entries (P-20, P-36), then re-seal the anchor. Deliverable: a gate covering contracts, an updated manifest, the corrected paper and a new release.

Out of scope: external audit of the circuit and contracts, and the trusted-setup ceremony. The Fuji verifier uses a development key and this grant does not certify it. Mainnet deployment is not claimed.

## The milestone IDs the lane is keyed to

This block is not the draft and is not claimed to have been sent in this form. It
is what the owner pasted on 2026-10-27 as the milestone mapping, and it is retained
because `team1-reserved-work.md` §2 and the `T1-`-prefixed rows throughout
`docs/audit/` point here.

```text
T1-M1: P-08, P-32, P-05/B-1, P-26, P-09 con B-5 y B-7, rotación del guardián, pausa.
T1-M2: P-18, P-12 (la opción elegida), P-17, B-4.
T1-M3: redespliegue, anuncio del verifier (2 días), epoch, prueba, admit; script y artefacto fijado; getter de MAX_NORM (B-10).
T1-M4: gate sobre contratos y cargo (B-8), SafeFork como omisión explícita (B-9), P-20, P-36, re-sellado y release, campaña de mutación con herramienta.
Fuera de alcance declarado en la solicitud: auditoría completa y ceremonia.
```

## Where the draft and the ID block disagree

Checked 2026-10-28, item by item. The four milestones line up in
subject and order — hardening, lifecycle, certified admission, gate-and-paper — and
the out-of-scope sentence matches. Two differences, both in `T1-M3`/`T1-M4`, and
neither is a contradiction:

| Row | In the draft | In the ID block | Reading |
|---|---|---|---|
| `T1-M3` | "post an epoch and a proof the installed key accepts, and execute admit on-chain" | adds "getter de `MAX_NORM` (`B-10`)" | the draft does not name `B-10`. Either it entered after this draft, or it is implied by "the installed key accepts". The lane keeps `B-10` because `team1-reserved-work.md` §2 lists it |
| `T1-M4` | "extend audit-gate.sh and run_all.sh ... re-seal the anchor" | adds "campaña de mutación con herramienta" | the draft does not name a mutation campaign; the lane does, and `team1-reserved-work.md` §2 requires it to "run from a committed harness" |

If the submitted copy turns up, the right move is to replace this file verbatim and
re-derive the table above against it; until then the disagreement is recorded rather
than smoothed away.

## How the IDs are read

The prefixes are the frozen ones in [`../audit/open-items.md`](../audit/open-items.md)
§1: `P-` is `docs/audit/audit-2026-10-20-in-progress.md`, `B-` is
`docs/audit/triage-external-review-2026-10.md`. `B-8`, `B-9` and `B-10` do not
exist in that triage file — they are the new IDs that registry assigns to items the
earlier plans named `V-8` (a series that does not exist anywhere in the repository)
and to two items that had no ID at all. The registry is the authority on the
mapping; this file only records what the draft and the ID block say.


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

`P-08` is first because a contract defect invalidates any deployment built on top
of it. The `P-12` decision is next because it decides the statement the circuit
proves; freezing before it is deciding in the dark. The ceremony comes after the
freeze and **before** the redeploy that `T1-M3` delivers — otherwise the deployed
verifier has no ceremony behind it and the redeploy has to happen twice.

In this application the ceremony is **a declared dependency, not a milestone**: it
is out of scope (the last line of the draft), it is not paid for by this grant, and
`T1-M3` is blocked until it happens. That distinction is the difference between a
plan that assumes someone else's work and one that pretends to have bought it.

Note that `T1-M3`'s redeploy also has to publish the *corrected* gas figure if
`E-01` has landed by then: the paper currently prices the deployed path with V3's
key ([`../paper/releases/v0.2.3-errata.md`](../paper/releases/v0.2.3-errata.md)).

## What this changes in the rest of the directory

- [`team1-reserved-work.md`](team1-reserved-work.md) is keyed to the ID block in
  this file: its `T1-M1`…`T1-M4` rows are those four lines, not `R1`…`R4`. Its
  status line still governs whether any of them may start.
- The five rows that `avalanche-research-proposal.md` §5 funds (audit, remediation
  and re-audit, ceremony and transcript, fuzzing in CI, closure report from
  `F-023`) are **not** funded by this application. They stay in
  `team1-reserved-work.md` under their own status line, tied to
  `RESEARCH_PROPOSAL_STATUS`, because §7's "No line pays for work already done" is
  a statement about *that* budget and does not transfer to this one.
- This file is evidence of a draft, not of a submission. Any document that cites it
  as "what was sent" is now wrong, and `SUBMISSION_STATUS: submitted-unverified` on
  line 1 is the machine-readable form of that caveat.
