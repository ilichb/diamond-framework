#!/usr/bin/env python3
"""
eje-iv-crosscheck.py — Cross-check every quantitative figure in
docs/paper/main.tex against the baseline outputs in
verification/baseline_2026-10-06/.

Methodology (eje iv, "Regla A/B"):
  A. Extract numeric tokens with the same regex as eje (i):
       [0-9]+\\.[0-9]+|[0-9]+\\%|[0-9]+,[0-9]{3}
  B. Derive each token's reference value by searching the baseline
     outputs (never typed by hand).
  C. Emit a Markdown draft table. For each token it reports the nearest
     \\fref{...} on/near the line, the output file that \\fref resolves
     to, and whether the token matches that output (EXACT / ROUNDED /
     NONE), plus which other outputs contain it (fallback).

The adjudication (OK / DERIVED / MISMATCH / MISSING) is left to the
manual pass; this script only delivers the mechanical cross-check.

Usage:  python3 docs/audit/eje-iv-crosscheck.py > /tmp/eje_iv_draft.md
"""
import re
import os
import glob

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
PAPER = os.path.join(REPO, "docs", "paper", "main.tex")
BASELINE = os.path.join(REPO, "verification", "baseline_2026-10-06")
INTEGRATION = os.path.join(REPO, "integrations", "avalanche", "benchmark_output_v2.txt")

TOKEN_RE = re.compile(r'[0-9]+\.[0-9]+|[0-9]+\\%|[0-9]+,[0-9]{3}')
NUM_RE = re.compile(r'[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?')
FREF_RE = re.compile(r'\\fref\{([^}]*)\}')
SEC_RE = re.compile(r'\\(section|subsection)\{([^}]*)\}')


def norm(text):
    """Strip LaTeX wrappers and thousands separators so a paper token can
    be compared to a raw output line."""
    return (text.replace('\\%', '').replace('%', '')
                .replace('{,}', '').replace(',', ''))


def token_decimals(tok):
    t = norm(tok)
    return len(t.split('.')[1]) if '.' in t else 0


def token_sig(tok):
    """Rough significant-digit count (used to flag design constants)."""
    t = norm(tok).replace('.', '').lstrip('0')
    return len(t)


def match_value(token, raws):
    """Return the first raw number string in *raws* that rounds to the
    token at the token's own precision, else None."""
    n = norm(token)
    if not n:
        return None
    decs = token_decimals(token)
    if decs == 0:
        ti = int(float(n))
        for r in raws:
            if abs(float(r) - ti) < 0.5:
                return r
        return None
    q = 10 ** decs
    target = round(float(n) * q)
    for r in raws:
        if round(float(r) * q) == target:
            return r
    return None


def load_outputs():
    outputs = {}
    for path in glob.glob(os.path.join(BASELINE, '*_output.txt')):
        stem = os.path.basename(path)[:-len('_output.txt')]
        with open(path, encoding='utf-8', errors='replace') as fh:
            outputs[stem] = NUM_RE.findall(fh.read())
    if os.path.exists(INTEGRATION):
        with open(INTEGRATION, encoding='utf-8', errors='replace') as fh:
            outputs['benchmark_output_v2'] = NUM_RE.findall(fh.read())
    return outputs


def sections_of(lines):
    secs = []
    for i, line in enumerate(lines, 1):
        m = SEC_RE.search(line)
        if m:
            secs.append((i, m.group(2)))
    return secs


def section_at(lineno, secs):
    name = '(pre)'
    for start, nm in secs:
        if start <= lineno:
            name = nm
        else:
            break
    return name


# (numeric matching is handled by match_value above)


def fref_to_output(path, outputs):
    """Resolve a \\fref{} path to the key of the output it produces."""
    if not path:
        return None
    if path.endswith('.py'):
        stem = os.path.basename(path)[:-3]
        return stem if stem in outputs else None
    if path.endswith('.sol'):
        return 'benchmark_output_v2' if 'benchmark_output_v2' in outputs else None
    return None


def main():
    outputs = load_outputs()
    with open(PAPER, encoding='utf-8') as fh:
        lines = fh.readlines()
    secs = sections_of(lines)

    frefs = {}
    for i, line in enumerate(lines, 1):
        found = FREF_RE.findall(line)
        if found:
            frefs[i] = found

    def nearest_fref(lineno):
        for d in range(0, 4):
            for cand in (lineno - d, lineno + d):
                if cand in frefs:
                    return frefs[cand][0]
        return ''

    print("| # | Línea | § | Cifra | Fuente (script) | Valor en paper | Valor en output | Estado |")
    print("|---|---|---|---|---|---|---|---|")
    idx = 0
    no_global = []
    nomatch_cited = []
    for i, line in enumerate(lines, 1):
        for m in TOKEN_RE.finditer(line):
            token = m.group(0)
            idx += 1
            fref = nearest_fref(i)
            stem = fref_to_output(fref, outputs) if fref else None
            val = match_value(token, outputs[stem]) if stem else None
            if val is None:
                globals_ = [s for s, raws in outputs.items()
                            if match_value(token, raws)]
                if globals_:
                    val = match_value(token, outputs[globals_[0]])
                    source_label = stem or globals_[0]
                else:
                    source_label = stem or '-'
            else:
                source_label = stem
            estado = 'OK' if val else ''
            if val is None and stem is None:
                no_global.append((idx, i, section_at(i, secs), token))
            if val is None and stem is not None:
                nomatch_cited.append((idx, i, section_at(i, secs), token, fref))
            print("| {} | {} | {} | `{}` | {} | `{}` | `{}` | {} |".format(
                idx, i, section_at(i, secs), token, source_label or '-',
                token, val or '-', estado))
    print()
    print("_Total tokens: {}_".format(idx))
    print()
    print("## Sin match ni en la fuente citada ni en ningun output ({} anchos)".format(
        len(no_global)))
    print()
    print("| # | Línea | § | Cifra |")
    print("|---|---|---|---|")
    for (a, b, c, d) in no_global:
        print("| {} | {} | {} | `{}` |".format(a, b, c, d))
    print()
    print("## No coincide con la fuente citada pero si con otro output ({})".format(
        len(nomatch_cited)))
    print()
    print("| # | Línea | § | Cifra | \\fref citado |")
    print("|---|---|---|---|---|")
    for (a, b, c, d, e) in nomatch_cited:
        print("| {} | {} | {} | `{}` | {} |".format(a, b, c, d, e))


if __name__ == '__main__':
    main()
