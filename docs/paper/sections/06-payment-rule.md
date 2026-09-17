# 6. Payment Rule

## 6.1 The Revelation Problem

A validator is admitted to the validator set if its hybrid collateral
exceeds the threshold:

    CoA(i) = S_f(i) + C_R(T(i)) ≥ Θ(t)                             (1)

where S_f is the financial stake, C_R is the reputational collateral,
and T is the reputation tensor.

The allocation of collateral between its financial and reputational
components depends only on T. It does not depend on any private
information that the validator might hold. This simplifies the
mechanism design problem relative to a classic auction, but it also
means that the standard tools of auction theory do not apply directly.

We address the two candidate sources of private information below.

## 6.2 Verified Reputation

The reputation tensor T is verifiable on-chain via the zero-knowledge
threshold proof of Section 4. A validator whose reputation exceeds the
threshold can prove it without revealing the tensor itself. A validator
whose reputation falls below the threshold cannot produce a valid
proof.

Consequently, T is not a private type in the sense of mechanism design.
The validator cannot misreport it: the proof binds the validator to a
specific tensor, and the verifier checks the binding. The revelation
principle does not apply because there is nothing to reveal.

## 6.3 Private Cost of Capital

The validator's cost of capital ω ∈ [ω_min, ω̄] is private. It
represents the opportunity cost of locking financial stake. A validator
with low ω can lock stake cheaply; a validator with high ω faces a
higher opportunity cost.

The allocation rule is

    S_f*(T) = max{ VaR_tech, Θ(t) − C_R(T) }                       (2)

which does not depend on ω. The type affects the validator's utility
but not its allocation.

The utility of a validator of type ω with reputation T is

    U(ω, T) = π_val − ω · S_f*(T) − F0                              (3)

where π_val is the expected validation revenue per epoch and F0 is the
fee charged for participation.

## 6.4 The Uniform Posted Price

Since the allocation does not depend on ω, the only mechanism design
decision is the participation fee F0. We choose a uniform posted price:
all validators pay the same F0, regardless of type.

The optimal F0 is the largest value that preserves Individual
Rationality for all types. The worst-case type is (ω̄, T = 0), which
combines the highest cost of capital with the lowest reputation:

    U(ω̄, 0) = π_val − ω̄ · Θ − F0 ≥ 0                              (4)

Solving for F0 at equality:

    F0* = π_val − ω̄ · Θ                                            (5)

With the reference parameters (π_val = 0.15, ω̄ = 0.10, Θ = 1.0):

    F0* = 0.15 − 0.10 · 1.0 = 0.0500                               (6)

The fee is charged per epoch and is the same for all participating
validators.

## 6.5 Individual Rationality

The posted price F0* saturates IR at the worst-case type by
construction. We verify numerically that IR holds for all types in
the support and that the saturation is exact
[verification/mechanism/fee_specification.py].

The Monte Carlo draws N_VALIDATORS = 1000 validators with
ω ~ U[0.01, 0.10] and T uniform on [0, 3] (so C_R(T) ∈ [0, 0.6]).
The measured utilities are:

| Statistic | Value |
|-----------|-------|
| U_min | 0.009747 |
| U_mean | 0.069152 |
| U_max | 0.095891 |
| Fraction with U ≥ 0 | 1.0000 |

The analytical saturation U(ω̄, 0) = 0 is exact, with residual below
1e-9. The Monte Carlo U_min is strictly positive (0.009747) because
the specific pair (ω = 0.10, T = 0) is not sampled exactly in a
finite draw. The bound holds analytically for the worst-case type and
empirically for the sampled population.

## 6.6 Sensitivity

If the fee exceeds F0*, IR is violated for the worst-case types. We
verify this numerically:

| F0 | Fraction with U < 0 | Revenue per epoch |
|----|---------------------|-------------------|
| 0.025 | 0.0000 | 25.00 |
| 0.040 | 0.0000 | 40.00 |
| 0.050 | 0.0000 | 50.00 |
| 0.060 | 0.0020 | 60.00 |

At F0 = 0.06 (20% above F0*), 0.2% of the sampled validators violate
IR. The revenue trade-off is linear: increasing the fee above F0*
gains revenue at the cost of excluding the worst-case types.

## 6.7 Incentive Compatibility

Incentive Compatibility is tautological in this mechanism. There is
no private type to misreport: T is verified on-chain, and S_f*(T)
does not depend on ω. A validator cannot improve its allocation by
misreporting, because the allocation is determined by a public,
verifiable signal.

The falsification log records this as F-006. The original formulation
of the protocol applied Myerson's optimal auction rule, which requires
a private one-dimensional type. The current mechanism does not have
one. The payment rule is a saturated uniform posted price, not a
Myerson auction.

## 6.8 Summary of the Section

| Claim | Status | Script |
|-------|--------|--------|
| T is verified, not private | Design | Section 4 |
| S_f*(T) independent of ω | Design | — |
| F0* = π_val − ω̄ · Θ | Analytical | `fee_specification.py` |
| IR holds for all types | Verified | `fee_specification.py` |
| IR saturation exact at worst-case type | Verified | `fee_specification.py` |
| F0 = 1.2·F0* violates IR for 0.2% | Verified | `fee_specification.py` |
| IC is tautological | Logical | — |

The payment rule is a uniform posted price, not a Myerson auction.
The absence of a private type with respect to the allocation rule
makes the mechanism simpler than standard auction theory would
suggest.
