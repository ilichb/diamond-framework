# Compiling the Paper

The paper is written in Markdown, one file per section, in `sections/`.
To compile the full paper to PDF:

## Prerequisites

    pandoc >= 2.9
    pdflatex (from TeX Live or MacTeX)

On Debian/Ubuntu:

    sudo apt install pandoc texlive-latex-base texlive-latex-recommended

## Build

    cd docs/paper
    pandoc sections/01-introduction.md \
           sections/02-reputation-dynamics.md \
           sections/03-tensor-compression.md \
           sections/04-zk-soundness.md \
           sections/05-collusion-detection.md \
           sections/06-payment-rule.md \
           sections/07-data-layer.md \
           sections/08-bootstrap.md \
           sections/09-evaluation.md \
           sections/10-limitations.md \
           sections/11-conclusion.md \
           -o diamond-framework.pdf \
           --pdf-engine=pdflatex \
           --toc \
           --number-sections

The output is `diamond-framework.pdf` in this directory.

## Alternative: single concatenated Markdown

    cat sections/*.md > diamond-framework.md

The concatenated file preserves section numbering because each file
starts with its own `# N. Title` heading.

## Status

The PDF is not yet compiled in the repository. The sections are
complete and can be compiled locally with the command above.

## Troubleshooting Unicode

The paper uses Unicode symbols (subscripts, superscripts, combining
marks, mathematical operators) that pdflatex with inputenc may not
support. If compilation fails with "Unicode character not set up for
use with LaTeX", two solutions are available:

### Option A: Use xelatex

    sudo apt install texlive-xetex
    pandoc sections/*.md -o diamond-framework.pdf \
      --pdf-engine=xelatex --toc --number-sections

### Option B: Add a header file mapping the problematic characters

Create header.tex with newunicodechar mappings, and pass:

    pandoc sections/*.md -o diamond-framework.pdf \
      --pdf-engine=pdflatex --toc --number-sections \
      -H header.tex

Both options are documented but not verified in this repository.
