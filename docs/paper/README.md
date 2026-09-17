# Compiling the Paper

The paper is written in Markdown, one file per section, in `sections/`.
To compile the full paper to PDF:

## Prerequisites

    pandoc >= 3.0
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
