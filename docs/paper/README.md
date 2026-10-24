# The Paper

`main.tex` is the source of truth for the paper: a single LaTeX
document (`article`, A4, 11pt) containing the title block, the
abstract, a table of contents, eleven sections, and the twenty-one-item
reference list.

The earlier Markdown sections are kept in `_deprecated-md/` for
reference only. They are no longer maintained, and they never contained
the abstract or the reference list, so they cannot reproduce the PDF.

## Prerequisites

    pdflatex (from TeX Live or MacTeX) with:
    texlive-latex-base texlive-latex-recommended texlive-latex-extra

On Debian/Ubuntu:

    sudo apt install texlive-latex-base texlive-latex-recommended texlive-latex-extra

`pdflatex` must find scalable Type 1 fonts: `microtype` enables font
expansion by default, and expansion aborts when only bitmap fonts are
available. `main.tex` loads `lmodern` (Latin Modern) to provide them.
Do not remove that line. See `docs/audit/compile-logs/` for the exact
failure that occurs without it.

## Build

    cd docs/paper
    pdflatex -interaction=nonstopmode -halt-on-error main.tex
    pdflatex -interaction=nonstopmode -halt-on-error main.tex

Two passes are required so that the table of contents and the internal
cross-references resolve. The output is `main.pdf` in this directory.
The auxiliary files (`main.aux`, `main.log`, `main.out`, `main.toc`)
are ignored by git.

## Status

`main.tex` compiles with the preamble as committed, and produces `main.pdf`.
The page count follows the content, so it is read from the build:

    cd docs/paper && pdflatex -interaction=nonstopmode -halt-on-error main.tex && pdfinfo main.pdf | grep Pages

The current source is 43 pages (`Pages: 43`, three `pdflatex` passes, 0 errors, 0 undefined, 0 overfull or underfull boxes).
Release snapshots are archived under
`releases/`; the latest is `releases/diamond-framework-2026-10-24.pdf`
(43 pages, 591880 bytes, SHA-256 `5651a2f3…`), frozen from the v0.2.2 source —
the very source whose `main.tex` (`7058d6e6…`) the anchor root seals. That
snapshot is the v0.2.2 release candidate; it has no DOI yet, and the
DOI-backed version is still v0.1.0 (see the repository `README`). The earlier snapshots stay
as published and are no longer
the artifact of record. Snapshots are frozen documents: they are not
re-exported when the source advances, so a rebuild of the current source
is not byte-comparable to them — see `releases/README.md`. Only PDFs
under `releases/` are tracked by git.

Since P7a the PDF **carries its own metadata** — `pdftitle`, `pdfauthor`,
`pdfsubject`, `pdfkeywords` — so a reference manager that imports the file gets a
title and an author instead of empty fields:

    cd docs/paper && pdfinfo main.pdf | grep -E '^(Title|Author|Subject|Keywords):'

The submission bundle for arXiv is **one file**: the source has no
`\includegraphics` and carries an inline `thebibliography`, so there is no figure
directory and no `.bbl` to send alongside `main.tex`.

## License

The paper is **CC BY 4.0**: the manuscript `main.tex` and the frozen PDF
snapshots under `releases/`. The legal code is [`LICENSE`](LICENSE) in this
directory. The code in the repository is MIT
([`LICENSE`](../../LICENSE)) — a separate licence, because the two artefacts are
reused differently.

The file next to this one is the **verbatim** legal code, fetched rather than
paraphrased: a licence is not a document to summarise in one's own words.

    curl -s https://creativecommons.org/licenses/by/4.0/legalcode.txt -o LICENSE
    sha256sum LICENSE    # 9ba9550ad48438d0836ddab3da480b3b69ffa0aac7b7878b5a0039e7ab429411
    wc -c LICENSE        # 18657
    wc -l LICENSE        # 396

## Troubleshooting

If compilation stops with

    ! pdfTeX error (font expansion): auto expansion is only possible with scalable fonts.

then `microtype` is performing font expansion without scalable fonts.
Restore `\usepackage{lmodern}` after `\usepackage[T1]{fontenc}`, or
install `cm-super` (`sudo apt install cm-super`), or disable expansion:

    \usepackage[protrusion=true,expansion=false]{microtype}

