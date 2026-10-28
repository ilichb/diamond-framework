# Grants

This directory is the funding ask. It is deliberately **outside the research
record**: nothing here is part of `verification/anchor_root.sha256`, and
`docs/paper/main.tex` says only what it can support — that an external audit is
pending. The paper does not ask for money, and it does not mention this
directory.

The ask exists because the mechanism is finished and unaudited, and those two
facts are the ones a reviewer should weigh: the work is not a proposal to build
something, it is a proposal to try to break something that is already running.

## Files

| File | What it is |
|---|---|
| `avalanche-research-proposal.md` | The submission itself, in the shape the call asks for: research question, methodology, contributions, timeline, budget, qualifications. Under 10 pages. **Not sent**: the call is closed. |
| `team1-mini-grant-application.md` | The Team1 mini grant: **submitted, and the submitted copy was not located** (2026-10-28). What the file holds is the last working draft, verbatim, plus the milestone-ID block the lane is keyed to. Four milestones, no audit, no ceremony. |
| `team1-reserved-work.md` | The lane switch and the two reserved lists: `T1-M1`…`T1-M4` (mini grant) and `G1`…`G5` (the $50k proposal), each behind its own status line. |
| `budget.md` | The $50,000 line by line, with what the money does *not* buy. |
| `reviewer-checklist.md` | Each published review criterion mapped to a command a reviewer can run. |
| `evidence-appendix.md` | The artefact table: addresses, transactions, hashes, coverage. Supporting material, not counted in the 10 pages. |
| `figures.sh` | Re-derives every number quoted above from the tree. Run it before sending. |

## How it is sent

The submission is the file itself, exported to PDF, plus three attachments — only
one of which (the CV) is not already in the repository. Nothing else has to be
written on the day the call reopens.

1. **Watch the call.** `build.avax.network/grants/avalanche-research-proposals`
   reverts from "Applications are currently closed" to a form. Nothing else on
   that page needs re-reading.
2. **Export** `avalanche-research-proposal.md` to PDF (the ten-page limit is about
   the body; this file is ~2,300 words, about five pages). Do not include the
   appendix in the uploaded PDF; link it.
3. **Attach:** CV · `diamond-framework-2026-10-25.pdf` (43 pp, sha256
   `89e71837…`) · the frozen commit hash · the Fuji addresses table.
4. **State the honest boundary in the first paragraph of the cover note:** testnet,
   unaudited, development key, call was closed when this was written.
5. **Run `./figures.sh` immediately before sending.** If it prints DRIFT, the
   repository moved and a number in the PDF is now wrong.
6. **Keep the answer** — findings are appended to the falsification log whatever
   the outcome, including a rejection of this application.

For Team1, the ask is different by design and was sent before 2026-10-27: a mini
grant for four milestones of contract, decision, redeploy and delivery work
([`team1-mini-grant-application.md`](team1-mini-grant-application.md)). The audit
and the ceremony are declared out of scope there — it funds builders, and asking
a builder programme for an audit would be asking the wrong programme for the
wrong thing. The steps above describe the $50k research proposal and do **not**
apply to the mini grant; sending that one is done, and what it unlocks is
[`team1-reserved-work.md`](team1-reserved-work.md).

## Programme status

Checked on **2026-10-24** against `build.avax.network/grants`:

| Programme | Fits? | Status |
|---|---|---|
| [Avalanche Research Proposals](https://build.avax.network/grants/avalanche-research-proposals) — up to **$50,000**, academic research on the economics of cryptoassets and decentralised networks | **Yes.** Area 2, *Validator Economics and Network Security*: "how validator incentive systems are structured, measured, and optimised", "non-inflation-based reward mechanisms". This work is that, with a deployed implementation. | **Closed.** "We are not accepting new research proposal submissions at this time." |
| [Team1 Mini Grants](https://build.avax.network/grants/team1-mini-grants) — fast, focused funding for builders | **Yes.** It funds building, and what is left to build is the `T1-M1`–`T1-M4` list: contract fixes, the `P-12` decision, the redeploy, and the delivery surface. The audit and the ceremony are declared out of scope there. | Open, rolling. **Submitted** (recorded 2026-10-27). The submitted copy could not be located on 2026-10-28, so `team1-mini-grant-application.md` is a reconstructed draft, not the text Team1 received. |
| [Avalanche Bug Bounty](https://immunefi.com/bug-bounty/avalanche/) — up to $100,000 | **No.** It covers Avalanche network components, not third-party contracts deployed on Fuji. | Open, not applicable. |
| Blizzard Fund | No: it invests in companies, and there is no company. | — |

The consequence is concrete: the 50k call is the right instrument and the door
is shut today. The proposal is therefore written to be sent the day it reopens,
and `README`/`v0.2.2-notes.md` keep the audit gap visible in the meantime so the
delay is recorded rather than hidden.

## Two claims this directory does not make

1. **No relationship with the Avalanche Foundation exists.** Nothing here is
   endorsed, and no award has been made. One application **has** been sent: the
   Team1 mini grant recorded in
   [`team1-mini-grant-application.md`](team1-mini-grant-application.md). The
   earlier wording of this claim — "no grant has been requested" — was true when
   it was written and stopped being true on submission; it is corrected here
   rather than deleted, because a record that quietly rewrites itself is worth
   nothing.
2. **No co-funding percentage is asserted.** The pages consulted on 2026-10-24
   describe no audit subsidy and no percentage. If the Foundation co-funds
   audits from its own list of firms, that changes the request — `budget.md` §3
   says how, and what would have to be confirmed first.

Both are stated here because a proposal that inflates its own backing is the
first thing a reviewer checks.
