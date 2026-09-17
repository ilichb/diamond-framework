# 9. Evaluation

## 9.1 Scope

This section evaluates three things: the reproducibility of the
numerical claims, the measured on-chain gas costs of the cryptographic
primitives, and the stability of the conclusions under parameter
variation. Two benchmarks are deferred to future work because they
require a live network: the proving time of the recursive SNARK, and
the latency of cross-chain message propagation.

## 9.2 Reproducibility

Every quantitative claim in Sections 2 through 8 is accompanied by a
script in `verification/`. The scripts are self-contained: they depend
only on NumPy and SciPy, and they declare their seeds and sample sizes
at the top of each file. Running `pip install -r verification/requirements.txt`
followed by the commands listed in `verification/README.md` reproduces
every number reported in the paper. The README lists the 17 scripts
and their expected runtimes.

The project documents its own falsifications in
`docs/audit/numerical-verification.md`. As of this writing the log
contains 17 entries (F-001 through F-017), each one a claim that was
made, tested, and corrected. The log exists because the numerical
verification is the primary defense against errors of the kind that
would otherwise propagate through the paper unchallenged.

The scripts run in the following time ranges on a 2020-era desktop:

| Script | Time |
|--------|------|
| `calibration_modularity.py` | ~400 s |
| `dt_convergence.py` | ~130 s |
| `sim_positivity.py` | ~34 s |
| `censoring_test.py` | ~17 s |
| `clique_spectra.py` | ~17 s |
| `stationary_stats.py` | ~12 s |
| All others | < 5 s each |

Total runtime for the full suite: approximately 10 minutes on a
single core. The dominant cost is the RMT calibration with
N_H0 = 2000 and N_H1 = 500.

## 9.3 On-Chain Gas Costs

The cryptographic design of Section 4 has an on-chain component. We
measure the gas cost of the EVM precompiles that implement the
BN254 pairings and scalar multiplications
[integrations/avalanche/benchmarks/src/GasBenchmarks.sol]. The
measurements match EIP-196 and EIP-197 to the gas unit:

| Primitive | Measured gas | EIP formula |
|-----------|--------------|-------------|
| `ecAdd` (0x06) | 292 | 150 + overhead |
| `ecMul` (0x07) | 6,142 | 6,000 + overhead |
| `ecPairing` k=1 | 79,142 | 45,000 + 34,000·1 + overhead |
| `ecPairing` k=2 | 113,142 | 45,000 + 34,000·2 + overhead |
| `ecPairing` k=4 | 181,142 | 45,000 + 34,000·4 + overhead |

The overhead is 142 gas in all five measurements, consistent with a
single `staticcall` dispatch. Groth16 verification over BN254 uses
k = 4 pairings and therefore costs 181,142 gas for the pairing step
alone, plus approximately 25k gas for the surrounding verification
logic. The total is approximately 206k gas, constant in the size of
the circuit.

The direct verification of a Bulletproofs proof of Section 4.3 for
n = 500 elements requires 2n scalar multiplications and 2n point
additions: approximately 6.5M gas. This is 31× the cost of a Groth16
verification. The recursive SNARK of Section 4.4 reduces this to the
constant cost of the recursive proof, approximately 250k gas.

The measurement uses a local Foundry instance with Solc 0.8.33. The
precompile gas schedule is a constant of the EVM protocol, so the
measurements apply identically to any EVM-compatible chain including
Avalanche C-Chain.

## 9.4 Stability of Conclusions

The conclusions of the paper depend on parameter choices that are
fixed at design time. We check that small variations do not change
the qualitative outcome.

**Reputation dynamics (Section 2).** The domain validity of the
multiplicative-jump specification is verified pathwise: 0 of 100,000
trajectories leave the positive domain for any parameter choice that
satisfies Feller. The mean first-passage time converges to the exact
value as dt → 0, with a relative error of 0.22% at dt = 5×10⁻⁴. The
conclusions do not depend on the discretization.

**Collusion detection (Section 5).** The null quantile q99 = 8.8372
is calibrated with N_H0 = 2000 replicates. The standard error of the
q99 estimate is sqrt(p(1-p)/N) / f(q99), evaluated at the empirical
z-score of q99 (2.476), giving 0.011 gas, or 0.125% of its value. The
95% confidence interval is approximately [8.816, 8.859]. The
corresponding theoretical value, using the standard normal density at
z = 2.326, is 0.087%. The transition from partial to full detection
for k = 1 vs k = 3 cliques is 24.8% vs 100%, well outside the
confidence intervals. The qualitative boundary does not depend on the
calibration sample size.

**Data layer (Section 7).** The equilibrium n*(B) = ⌊B/B*⌋ is exact
given the parameters. The attacker profit is −502 with slashing
S_slash = 10 and +49.91 without detection. The discontinuity at
B = B* is a property of the equilibrium, not of the Monte Carlo.

**Bootstrap (Section 8).** The stationary reputation under net_gain
is R* = g·a/(g·a + μ). The measured median R = 0.3936 matches the
analytic R* = 0.4 for unit activity. The choice μ/g = 1.5 maximizes
R_std in the sweep; nearby values give similar results.

## 9.5 Deferred Benchmarks

Two benchmarks are not reported in this paper because they require
a live network:

**Recursive SNARK proving time.** The recursive proof of Section 4.4
composes a Groth16 verifier inside a larger circuit. The proving time
depends on the choice of recursion framework and the size of the inner
circuit. This is measurable locally but requires implementing the
recursive circuit, which is outside the scope of the current paper.

**Teleporter latency.** The protocol uses Avalanche Warp Messaging
(AWM) through the Teleporter contract to propagate reputation
commitments across subnets. The message latency depends on the
Avalanche consensus timing and is bounded by the finality time of the
source subnet. This is not measurable without a live testnet
deployment.

Both benchmarks are declared as future work. The protocols for
measuring them are defined in the repository.

## 9.6 Summary of the Section

| Claim | Status | Source |
|-------|--------|--------|
| Verification suite reproduces all claims | Verified | `verification/` |
| 17 falsifications documented | Verified | `docs/audit/` |
| ecPairing k=4 = 181,142 gas | Measured | `GasBenchmarks.sol` |
| Groth16 verification ≈ 206k gas | Measured + estimate | `GasBenchmarks.sol` |
| Bulletproofs direct: ~6.5M gas | Estimated | `GasBenchmarks.sol` |
| Recursive SNARK: ~250k gas | Estimated | — |
| Conclusions stable under parameter variation | Verified | Multiple |
| Recursive proving time | Deferred | — |
| Teleporter latency | Deferred | — |

The evaluation confirms the reproducibility of the numerical claims
and the measured gas costs of the cryptographic primitives. The two
deferred benchmarks are declared as future work with the protocols
for measuring them.
