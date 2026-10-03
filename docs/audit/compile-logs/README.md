# Compilation Logs

Raw `pdflatex` transcripts for `docs/paper/main.tex`, preserved as
evidence that the LaTeX source compiles under the declared preamble,
and as a record of the font blocker and its fix.

## Files

- `2026-10-03-pass1.txt` — First compilation attempt after adopting
  `main.tex` as the source of truth. It ends in a fatal error and
  produces no PDF; it documents the state before the fix.

## The blocker

The preamble declares `\usepackage[T1]{fontenc}` together with
`\usepackage{microtype}` (line 13) but no scalable T1 font family.

`microtype` enables font *expansion* by default, and expansion requires
scalable Type 1 fonts. This TeX Live installation ships neither
`cm-super` nor the Type 1 Computer Modern set, so the first page ship-out
aborts:

    ! pdfTeX error (font expansion): auto expansion is only possible with scalable fonts.
    <argument> ...shipout:D \box_use:N \l_shipout_box ...
    l.54 \newpage
    !  ==> Fatal error occurred, no output PDF file produced!

This is a fatal error, not a warning. No `main.pdf` is written. The
transcript contains zero `Warning` lines and zero `Font shape` lines:
it is not a missing-font-substitution problem.

## The fix

Add `\usepackage{lmodern}` immediately after `\usepackage[T1]{fontenc}`.
Latin Modern ships T1-native scalable Type 1 fonts, so `microtype` can
perform font expansion. With the fix, `pdflatex main.tex` completes
three passes with exit code 0 and produces a 31-page PDF — the same
page count as the reference PDF in `docs/paper/`.

## Verifying

    cd docs/paper
    pdflatex -interaction=nonstopmode -halt-on-error main.tex

The signal is the exit code and the presence of `main.pdf`. A grep for
`Font shape` is not a valid check: that warning is absent both before
and after the fix.
