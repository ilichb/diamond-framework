# Paper Releases

Frozen PDF snapshots of `docs/paper/main.tex`, kept as the citable
artifact of the paper. Each snapshot carries a dated filename so that
its bytes, once published, never change.

## Files

- `diamond-framework-2026-10-03.pdf` — 31 pages, 624450 bytes.
  `sha256 bacd6242e28b1948e599a021b2d543b7886593b3ee1024545ff0a72a55426cde`

## Convention

- Name: `diamond-framework-YYYY-MM-DD.pdf`. The date is the day the
  snapshot was frozen into this repository, **not** the PDF's internal
  `CreationDate`.
- Never overwrite or re-export an existing snapshot — add a new dated
  file instead. A published hash must stay valid forever.
- These are the only PDFs git tracks: `.gitignore` carries `*.pdf` with
  the single negation `!docs/paper/releases/*.pdf`.

## Provenance of the current snapshot

`diamond-framework-2026-10-03.pdf` entered the repository in `ea8564d`,
the commit that adopted `main.tex` as the source of truth, and no later
commit has modified it. The sha256 above is that blob, unchanged. Its
embedded metadata records:

    CreationDate: Wed Sep 23 13:58:28 2026 -04   (ModDate matches)
    Producer:     pdfTeX-1.40.29

The filename date (`2026-10-03`) is the day the file entered this
repository; the PDF itself was produced on 2026-09-23, consistent with
the `\date{September 2026}` declared in `main.tex`.

## A rebuild is content-equivalent, not byte-identical

Three `pdflatex` passes on `main.tex` reproduce the paper — 31 pages
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
  same source relies on Latin Modern instead and embeds 26 subsets: 25
  `LMRoman*`/`LMMono*`/`LMMath*` plus the shared `MSBM10`.

Latin Modern is what provides scalable T1 Type 1 fonts in this
environment (package `fonts-lmodern`, e.g. `kpsewhich lmr10.pfb`),
which is why `main.tex` carries `\usepackage{lmodern}`. Without it the
build aborts with a fatal `pdfTeX error (font expansion)` and writes no
PDF — see `docs/audit/compile-logs/` for the transcript.

Consequence: verify a rebuild by page count and text, never by byte
hash. The text comparison has the caveats below.

## Divergence from the snapshot

`main.tex` is not a word-for-word rendering of the snapshot: exactly one
source line differs, and deliberately so. The Reproducibility remark
listed the paper source as `docs/paper/sections/`, a directory that no
longer exists; it now reads `docs/paper/main.tex`.

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

Per the Convention above the snapshot is not re-exported, so the
corrected source line reaches the public artifact only through the next
dated snapshot.

## Note on `cm-super`

"Type 1 fonts extending CM, EC, and Cyrillic families" — it supplies
the scalable T1/TS1 Type 1 Computer Modern (EC/TC) faces that
`\usepackage[T1]{fontenc}` expects (CTAN `/fonts/ps-type1/cm-super`;
shipped in TeX Live as `cm-super`).

## Verifying

    cd docs/paper
    pdflatex -interaction=nonstopmode -halt-on-error main.tex   # run 3x
    pdfinfo main.pdf | grep Pages      # Pages: 31
    sha256sum releases/diamond-framework-2026-10-03.pdf       # hash in Files
    git hash-object releases/diamond-framework-2026-10-03.pdf # blob in HEAD
