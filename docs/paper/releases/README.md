# Paper Releases

Frozen PDF snapshots of `docs/paper/main.tex`, kept as the citable
artifact of the paper. Each snapshot carries a dated filename so that
its bytes, once published, never change.

## Files

- `diamond-framework-2026-10-29.pdf` — 43 pages, 592894 bytes (v0.2.3, **current
  in `wip/v0.2.3`, unsealed as a release: not tagged, not deposited**).
  `sha256 1468b5d744ab02d6236742cf4868377b6d6aa50464d485db24c8d6270ae478fd`
- `diamond-framework-2026-10-25.pdf` — 43 pages, 591875 bytes (v0.2.2, current
  published artifact; the DOI names this file).
  `sha256 89e718373158285821ac04d1a9280c7ff85baa8c03dbc4b8df9a6da481dd39b9`
- `diamond-framework-2026-10-24.pdf` — 43 pages, 591880 bytes (v0.2.2, superseded
  before publication: §9 said the Bulletproofs alternative costs `31×` the Groth16
  verification while the paragraph had just declared the 206k inline-key base not
  to be the deployed cost; the ratio over the deployed path is `23×`).
  `sha256 5651a2f31707d26c9ff9ca1009e385d046e7004e7dd5397226577670e4f3dd16`
- `diamond-framework-2026-10-20.pdf` — 41 pages, 579260 bytes.
  `sha256 1aa1cb6c52593203116a600eec11f980ab92a64945f480efd8e6cb856b864da5`
- `diamond-framework-2026-10-19.pdf` — 40 pages, 569259 bytes (v0.2.0, historical).
  `sha256 1b5ac7ac844ca3dedf846356ffe2a0f1fb1e04df3c70411e3124069cfbf9e10d`
- `diamond-framework-2026-10-11.pdf` — 37 pages, 545018 bytes.
  `sha256 13e85c757e2b6efbb717325e2a4e75062f5ad484e426b1c160e24ae7bfa5b56a`
- `diamond-framework-2026-10-08.pdf` — 34 pages, 530095 bytes.
  `sha256 4a442fe42d2183d5f486bbd359804f24228f71e0b267e38cc98548d994b32be7`
- `diamond-framework-2026-10-03.pdf` — 31 pages, 624450 bytes.
  `sha256 bacd6242e28b1948e599a021b2d543b7886593b3ee1024545ff0a72a55426cde`

The current artifact of record is the most recent dated file; the earlier
ones are historical and are never re-exported. Which one is current is
derivable, not memorized:

    ls docs/paper/releases/*.pdf | tail -1

## Publication status (v0.2.2)

- **No errata sheet.** The three statements v0.2.1 could only correct in prose are
  rewritten in the paper: the validator binding (§6, now the M4d statement with
  the validator address as a public input), the gas figure (`286,144` cold path;
  `g* = 781` gwei; 31× at 25 gwei; `~206k` kept only as the inline-key
  composition), and the financial floor (a minimum admission cost, not a
  guarantee). The collusion detector now declares `W` as an external input and
  the on-chain alert as a non-sanction. See [`v0.2.2-notes.md`](v0.2.2-notes.md).
- **v0.2.3 has one.** [`v0.2.3-errata.md`](v0.2.3-errata.md) registers `E-01`
  (2026-10-28): the `286,144` cold path that this section calls the deployed one is
  V3's three-input key, and the key the registry installs is M4d's (`306,253` cold,
  measured 2026-10-28; `306,275` on the earlier toolchain). **Applied on
  `wip/v0.2.3` on 2026-10-29**: v0.2.3 prints the installed key's figure as the
  deployed one and keeps `286,144` as V3's, in the eight lines the errata names, and
  the anchor is re-sealed once (`R-17`). The branch is not merged and the release is
  not deposited: the bytes and the metadata are in
  [`v0.2.3-zenodo-deposit.md`](v0.2.3-zenodo-deposit.md), and the decision is the
  owner's. The re-seal is free-lane and self-funded: **v0.2.3 does not wait for the
  grant** (`../../grants/team1-reserved-work.md` §6, decision 6).
- Release asset `diamond-framework-2026-10-25.pdf`: 43 pages, 591875 bytes,
  sha256 `89e718373158285821ac04d1a9280c7ff85baa8c03dbc4b8df9a6da481dd39b9`.
- **The verifier left `address(0)` the same day, and the text followed.** A
  development-key `Groth16Verifier` was deployed on Fuji and announced through the
  registry's two-day rotation after the first export of this snapshot; the four
  passages that said it was not deployed were corrected and the PDF re-exported
  before any tag or DOI existed. No ceremony key and no certified admission — see
  `v0.2.2-notes.md` §"The verifier leaves `address(0)`" and
  `integrations/avalanche/scripts/fuji_20261024/`.
- Zenodo version DOI: **`10.5281/zenodo.23651484`** — deposited 2026-10-25 as
  <https://zenodo.org/records/23651484>, version 2 of the concept
  `10.5281/zenodo.23268373`. The deposit holds exactly two files, `main.tex` and
  the PDF above, and both are byte-identical to the copies in this repository
  (md5 `3e8bfe26ad048e19a418a6dc8366dbc0` for the PDF,
  `68b04622d42a50f3e5e3e7bcc81bf929` for the source; re-hashed after download).
  v0.1.0 keeps its own frozen DOI `10.5281/zenodo.23268374`. The checklist that
  was executed is [`v0.2.2-zenodo-deposit.md`](v0.2.2-zenodo-deposit.md), now
  marked as deposited, including the one place where the published record
  departs from the plan.
- GitHub Release: the tag `v0.2.2` is pushed and carries this DOI; the Release
  entry itself is the one step that needs a host with an authenticated `gh`
  (`gh release create v0.2.2 --notes-file docs/paper/releases/v0.2.2-notes.md`).
- arXiv: the bundle is `main.tex` alone and it no longer carries the retired
  statements; the submission is pending an account and an endorsement.

## Publication status (v0.2.1, historical)

- **Errata (2026-10-20):** the published PDF's §6.2 validator-binding sentence
  and its `~206k` gas figure are corrected in
  [`v0.2.1-notes.md`](v0.2.1-notes.md#errata-2026-10-20-after-publication).
  The PDF bytes are unchanged; the audit findings are P-01 and P-25.
- **Documentation errata (2026-10-21):** the OTS pending count in the same notes
  is **3**, not 4; the receipt and anchor are unchanged. See
  [`v0.2.1-notes.md`](v0.2.1-notes.md#errata-in-these-notes-2026-10-21).
- GitHub Release:
  <https://github.com/ilichb/diamond-framework/releases/tag/v0.2.1>
- Release asset `diamond-framework-2026-10-20.pdf`: 579260 bytes,
  sha256 `1aa1cb6c52593203116a600eec11f980ab92a64945f480efd8e6cb856b864da5`
  (downloaded and re-hashed).
- Zenodo version DOI: **no v0.2.1 deposit was made.** The reason recorded here at
  the time — §6.2's validator binding was not implemented (P-01) — was resolved
  by M4d and the text was corrected in v0.2.2, which is the version now deposited
  as `10.5281/zenodo.23651484`.
- v0.2.0 has no GitHub Release and no Zenodo deposit; it is superseded
  by v0.2.1 and must not be cited.

## Convention

- Name: `diamond-framework-YYYY-MM-DD.pdf`. The date is the day the
  snapshot was frozen into this repository, **not** the PDF's internal
  `CreationDate`.
- Never overwrite or re-export an existing snapshot — add a new dated
  file instead. A published hash must stay valid forever.
- These are the only PDFs git tracks: `.gitignore` carries `*.pdf` with
  the single negation `!docs/paper/releases/*.pdf`.

## Provenance of the 2026-10-25 snapshot (the current one)

`diamond-framework-2026-10-25.pdf` is frozen from the v0.2.2 source, the release
that rewrites in the paper what v0.2.1 had only been able to correct in an
errata sheet (P-25 gas and minor errata, P-27, P-28, P-29 and the §6 validator
binding). Three `pdflatex` passes over that source produce it: 43 pages,
591875 bytes, 0 errors, 0 undefined references, and 0 overfull or underfull
boxes. The two extra pages are the new paragraphs of §5 and §10.

It differs from the 2026-10-24 export by five bytes of text. §9 said the
Bulletproofs alternative for `n = 500` costs `31×` the Groth16 verification,
which is `6.5M / 206k`; the same paragraph had just declared that the 206k
inline-key composition is *not* the deployed cost, and the deployed cold path
is 286,144 gas, so the ratio over the deployed base is `6.5M / 286,144 = 22.7`,
rounded to `23×`. §4.3 keeps `31×` because there the declared base *is* the
206k composition. The 2026-10-24 file was never tagged, deposited or cited for
an artifact, so it stays in the tree as history and this file is the artifact.

    git rev-parse --short HEAD                             # the commit that added this file
    sha256sum docs/paper/main.tex                          # 2a6384d2…368c, entry #1 of the root abe9c553…
    head -1 verification/anchor_root.sha256                # the same hash
    sha256sum releases/diamond-framework-2026-10-25.pdf    # 89e71837…39b9

## Provenance of the 2026-10-20 snapshot (historical)

`diamond-framework-2026-10-20.pdf` is frozen from the v0.2.1 source: the
revision that corrects the ZK paper↔code mismatch, the Cost of Attack
claim, the audit-table interpretation, the tensor domain and the
mean/median labels. Three `pdflatex` passes over that source produce it:
41 pages, 579260 bytes, 0 errors, 0 undefined references, and 0 overfull
or underfull boxes.

    git rev-parse --short HEAD                             # the commit that added this file
    sha256sum docs/paper/main.tex                          # 37ebdc73…5a41, entry #1 of the root
    head -1 verification/anchor_root.sha256                # the same hash
    sha256sum releases/diamond-framework-2026-10-20.pdf    # 1aa1cb6c…4da5

## Provenance of the 2026-10-19 snapshot (historical)

`diamond-framework-2026-10-19.pdf` is frozen from the R-11 source: the
revision that closes the pre-v0.2.0 consistency pass (F=22, 38 pinned
outputs, softened ZK and recursive claims) and whose `main.tex` the R-11
anchor root seals (`../audit/anchor-receipts.md`). Two `pdflatex` passes over
that source produce it: 40 pages, 569259 bytes, 0 errors, 0 undefined
references, and 0 overfull or underfull boxes.

    git rev-parse --short HEAD                             # the commit that added this file
    sha256sum docs/paper/main.tex                          # 10721754…d3a4e, entry #1 of the root
    head -1 verification/anchor_root.sha256                # the same hash
    sha256sum releases/diamond-framework-2026-10-19.pdf    # 1b5ac7ac…e10d
    git hash-object releases/diamond-framework-2026-10-19.pdf

Its embedded metadata, read from the file rather than remembered:

    Title:        Diamond Framework: Reputation-Weighted Validator Selection via Verifiable Non-Transferable Reputation
    Author:       Ilich Blanco
    Subject:      Reputation-weighted validator selection, cryptoeconomics, zero-knowledge proofs
    Keywords:     proof-of-stake, validator selection, reputation, zero-knowledge proofs, cryptoeconomics, Avalanche, OpenTimestamps
    Producer:     pdfTeX-1.40.22
    CreationDate: Mon Oct 19 14:06:52 2026 -04   (ModDate matches)

The filename date is the local day (UTC-04) the file was frozen into this
repository; the UTC anchor seal written in the same session is recorded in
R-11 (`../audit/anchor-receipts.md`). This snapshot supersedes
`diamond-framework-2026-10-11.pdf`, and it is the file a deposit uploads.

## Provenance of the 2026-10-11 snapshot (historical)

`diamond-framework-2026-10-11.pdf` is frozen from the `main.tex` of the P7a
batch: the revision the anchor root `5d6002ba…` seals, whose receipt is R-4
(`../audit/anchor-receipts.md`). Three `pdflatex` passes over that source produce
it: 37 pages, 545018 bytes, 0 errors, 0 overfull or underfull boxes.

    git rev-parse --short HEAD                             # the commit that added this file
    sha256sum docs/paper/main.tex                          # fb5cae97…8bde8, entry #1 of the root
    head -1 verification/anchor_root.sha256                # the same hash
    sha256sum releases/diamond-framework-2026-10-11.pdf    # 13e85c75…a56a
    git hash-object releases/diamond-framework-2026-10-11.pdf

Its embedded metadata, read from the file rather than remembered:

    Title:        Diamond Framework: Reputation-Weighted Validator Selection via Verifiable Non-Transferable Reputation
    Author:       Ilich Blanco
    Subject:      Reputation-weighted validator selection, cryptoeconomics, zero-knowledge proofs
    Keywords:     proof-of-stake, validator selection, reputation, zero-knowledge proofs, cryptoeconomics, Avalanche, OpenTimestamps
    Producer:     pdfTeX-1.40.22
    CreationDate: Sun Oct 11 23:28:33 2026 -04   (ModDate matches)

The filename date is the local day (UTC-04) the file was frozen into this
repository; the UTC anchor seal written in the same session reads
`2026-10-12T03:28:48Z`. This snapshot superseded
`diamond-framework-2026-10-08.pdf`, and it was the file a deposit uploads until
`2026-10-19`.

## Provenance of the 2026-10-08 snapshot

`diamond-framework-2026-10-08.pdf` is frozen from the `main.tex` of
`ab485c1`, the commit that recorded the out-of-band e-mail copy (R-1.3)
and the observed Bitcoin aggregation (R-1.5). That revision was the one
the paper was audited at when this file was frozen, and its sha256 was
then the first entry of the anchor root:

    git rev-parse --short HEAD                     # ab485c1 when this file was frozen
    sha256sum docs/paper/main.tex                  # 32c2dff4…a0753
    head -1 verification/anchor_root.sha256        # the same hash, entry #1
    git log --diff-filter=A --format='%h' \
      -- docs/paper/releases/diamond-framework-2026-10-08.pdf   # the commit that added it

The file entered the repository in the commit the last command names,
and no later commit may modify it. Its embedded metadata records:

    CreationDate: Thu Oct  8 20:26:25 2026 -04   (ModDate matches)
    Producer:     pdfTeX-1.40.22

The filename date (`2026-10-08`) is the local day (UTC-04) the file was
frozen into this repository; the anchor timestamp written in the same
session reads `2026-10-09T00:26:00Z`, because that field is UTC.

Three `pdflatex` passes over the frozen source produce this file: 34
pages, 530095 bytes, 0 errors, 0 warnings, 0 overfull or underfull
boxes. The fresh build is textually identical to the `main.pdf` that was
already on disk (`pdftotext` diff empty, 17448 words in both) and not
byte-identical to it, for the reasons in the next section.

The source advanced between the two snapshots: 43 commits have touched
`main.tex` since `ea8564d`, 116 commits in total, and the page count went
from 31 to 34.

    git rev-list --count ea8564d..ab485c1 -- docs/paper/main.tex   # 43
    git rev-list --count ea8564d..ab485c1                           # 116

## Provenance of the 2026-10-03 snapshot

`diamond-framework-2026-10-03.pdf` entered the repository in `ea8564d`,
the commit that adopted `main.tex` as the source of truth, and no later
commit has modified it. The sha256 above is that blob, unchanged. Its
embedded metadata records:

    CreationDate: Wed Sep 23 13:58:28 2026 -04   (ModDate matches)
    Producer:     pdfTeX-1.40.29

The filename date (`2026-10-03`) is the day the file entered this
repository; the PDF itself was produced on 2026-09-23, consistent with
the `\date{September 2026}` declared in `main.tex`.

## The 2026-10-03 source: a rebuild is content-equivalent, not byte-identical

The comparison in this section was made when `main.tex` was still the
2026-10-03 snapshot-era source (`ea8564d`). It describes that source, not
the one frozen in 2026-10-08: `main.tex` has advanced since, and only the
reason a rebuild can never be byte-identical is independent of the content.

    git rev-list --count ea8564d..HEAD -- docs/paper/main.tex   # commits touching main.tex since the snapshot
    cd docs/paper && pdfinfo main.pdf | grep Pages              # pages of the current source

Three `pdflatex` passes on the snapshot-era `main.tex` reproduce the paper —
31 pages
and the same text, apart from the two differences noted under *Divergence
from the snapshot* — but never the same bytes, for two independent
reasons:

- **Build metadata.** pdfTeX stamps `/CreationDate` and `/ID` at every
  run, so two back-to-back local builds already differ from each other:
  both 508383 bytes, different `md5`.
- **Fonts.** The snapshot was built where `\usepackage[T1]{fontenc}`
  finds the scalable Type 1 EC fonts from `cm-super`, so it embeds 31
  font subsets: 18 from cm-super (`SFRM*`, `SFBX*`, `SFTT*`, `SFTI*`),
  12 from the classic Type 1 Computer Modern set (`CMR6`–`CMR10`,
  `CMBX10`, `CMMI7`–`CMMI10`, `CMSY7`–`CMSY10`, `CMEX10`), and
  `MSBM10` from the AMS fonts. This machine has no `cm-super`, so the
  rebuild loads Latin Modern instead and embeds 26 subsets: 25
  `LMRoman*`/`LMMono*`/`LMMath*` plus the shared `MSBM10`.

Latin Modern is what provides scalable T1 Type 1 fonts in this
environment (package `fonts-lmodern`, e.g. `kpsewhich lmr10.pfb`),
which is why `main.tex` carries `\usepackage{lmodern}`. Without it the
build aborts with a fatal `pdfTeX error (font expansion)` and writes no
PDF — see `docs/audit/compile-logs/` for the transcript.

Consequence: verify a rebuild by page count and text, never by byte
hash. The text comparison has the caveats below.

## Divergence from the 2026-10-03 snapshot

As of `ea8564d`, `main.tex` was not a word-for-word rendering of the
snapshot: exactly one
line of text differed, and deliberately so. The Reproducibility remark
listed the paper source as `docs/paper/sections/`, a directory that no
longer exists; it now reads `docs/paper/main.tex`. Beyond that the source
differed at that commit by the `\usepackage{lmodern}` line noted above, which changes no
words — only the line breaks that move §5.4 to the next page.

Comparing the two PDFs with `pdftotext` overstates this. `diff` on the
plain-text extractions reports 466 differing lines, and a word-level
comparison reports 73 differing blocks (15 496 against 15 492 words,
ratio 0.994) — but 71 of those blocks are artifacts of the extraction,
not text. They go away only once the comparison normalizes whitespace,
and they come in four kinds:

- **Line breaks and hyphenation.** The snapshot breaks `non-transferable`
  after the hyphen and the rebuild fits it on one line; likewise
  `on-chain` against `on- chain`, `sepa- rated` against `separated`,
  `mismeasurement` against `mismeasure- ment`. Both PDFs carry the same
  words.
- **Math glyphs.** The snapshot extracts `√︁`, `∫︂`, `↦→`, `∑︁` where the
  rebuild extracts `q`, `Z`, `7→`, `P`: the two math fonts name their
  glyphs differently. The formulas are the same.
- **Extraction order.** Right-aligned equation numbers — (2.1), (2.3),
  (6.6) — and page numbers are read across the text columns in a
  different order.
- **Metrics.** The contents dot leaders of §2.4, §5.3 and §7.3 run one
  dot shorter, and binary operators extract with different spacing (`+λ`
  against `+ λ`, `B=W−` against `B=W −`).

The second real difference sits in the table of contents: §5.4 *Null
Distribution and Calibration* is listed on page 14 in the snapshot and on
page 15 in the rebuild. That is pagination, not text — the different line
breaks move a subsection across the page boundary. Both PDFs are 31
pages.

Per the Convention above the 2026-10-03 snapshot is not re-exported, so the
corrected source line reached the public artifact only through the next
dated snapshot, `diamond-framework-2026-10-08.pdf`, frozen from the
`main.tex` of `ab485c1`. The 43 commits that touched `main.tex` between
`ea8564d` and that freeze are in the same position: they are absent from
the 2026-10-03 file, which stays as published and now documents the paper
only as it stood on 2026-10-03. Every later revision of the source reaches
the public artifact through a new dated snapshot, never by re-export.

## Note on `cm-super`

"Type 1 fonts extending CM, EC, and Cyrillic families" — it supplies
the scalable T1/TS1 Type 1 Computer Modern (EC/TC) faces that
`\usepackage[T1]{fontenc}` expects (CTAN `/fonts/ps-type1/cm-super`;
shipped in TeX Live as `cm-super`).

## Deposit

Zenodo is done for v0.2.2 — **`10.5281/zenodo.23651484`** (2026-10-25), version 2 of
the concept `10.5281/zenodo.23268373`. arXiv is still open: it needs an account and
an endorsement.

The PDF no longer carries the statement that blocked v0.2.1 (the validator binding
is implemented by M4d and described in §6), and the gas figure is the measured
deployed path. Neither delivery needed a code change (plan §11, P7b). The licence
both carry is the one the paper already has: **CC BY 4.0** (`../LICENSE`, the same
legal code the paper's `main.tex` sits next to).

**Zenodo.** Deposited by hand as a *new version* of the v0.1.0 record, so the
concept DOI stayed stable and v0.1.0 kept its own frozen DOI. The record holds two
files — `diamond-framework-2026-10-25.pdf` and `main.tex` — and the metadata came
from `.zenodo.json` (title, creators with ORCID, `Preprint`, `cc-by-4.0`,
keywords, 21 references, `isSupplementTo` the repository). The DOI was minted at
publish and is now asserted in `CITATION.cff` (`identifiers` and
`preferred-citation`) and in `.zenodo.json` (`related_identifiers`,
`isIdenticalTo`).

**arXiv.** The bundle is `main.tex` alone: it loads no `\includegraphics` and its
bibliography is an inline `thebibliography`, so there is no `.bbl` and no figure
directory to send, and every package it loads comes from TeX Live's
base/recommended/extra collections.

Caveat of provenance: `docs/paper/LICENSE` and `.zenodo.json` are as old as P7a
and are not in the sealed eleven, so a later edit to either one moves no anchor —
but it does move what a deposit claims.

## Verifying

    cd docs/paper
    pdflatex -interaction=nonstopmode -halt-on-error main.tex   # run 3x
    pdfinfo main.pdf | grep Pages      # 31 for the 2026-10-03-era source; 34 for the 2026-10-08 one
    sha256sum releases/diamond-framework-2026-10-08.pdf        # hash in Files
    sha256sum releases/diamond-framework-2026-10-03.pdf        # the historical hash, unchanged
    git hash-object releases/diamond-framework-2026-10-08.pdf  # blob in HEAD
