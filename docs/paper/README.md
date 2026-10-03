# The Paper

`main.tex` is the source of truth for the paper: a single LaTeX
document (`article`, A4, 11pt) containing the title block, the
abstract, a table of contents, eleven sections, and the sixteen-item
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

`main.tex` compiles with the preamble as committed and produces a
31-page PDF. Release snapshots are archived under `releases/`; the
current revision is `releases/diamond-framework-2026-10-03.pdf`. Only
PDFs under `releases/` are tracked by git.

## Troubleshooting

If compilation stops with

    ! pdfTeX error (font expansion): auto expansion is only possible with scalable fonts.

then `microtype` is performing font expansion without scalable fonts.
Restore `\usepackage{lmodern}` after `\usepackage[T1]{fontenc}`, or
install `cm-super` (`sudo apt install cm-super`), or disable expansion:

    \usepackage[protrusion=true,expansion=false]{microtype}

