# Contributing

## Core Rules

1. **Every quantitative claim requires a script.**
   If you add a number to a document, the script that produced it must be in `verification/`.

2. **Every script requires a stated sample size.**
   Monte Carlo results must declare `N_REPLICATES`. Empirical quantiles must declare the method (empirical, Wilson, etc.).

3. **Every script requires reproducible output.**
   Scripts must be deterministic given a seed. The seed must be declared.

4. **Conjectures must be labeled as such.**
   Use `[CONJECTURE]` prefix in documents for claims without numerical backing.

## Workflow

1. Fork the repository.
2. Create a feature branch: `git checkout -b feature/your-contribution`.
3. Add your change with a corresponding script if it is quantitative.
4. Run the script and commit both the script and its output summary.
5. Open a pull request with:
   - What you changed and why.
   - Which claim it affects.
   - The script output that supports the change.

## What we will not merge

- Quantitative claims without scripts.
- Changes to the paper's theorems without numerical verification.
- Code in `integrations/avalanche/` without unit tests and a statement of what is tested vs untested.
- Marketing language. This is a research repository.

## Honesty policy

This project documents its own errors. If you find a claim that is not
reproducible, open an issue with the label `falsification`. We will correct
the claim or remove it.
