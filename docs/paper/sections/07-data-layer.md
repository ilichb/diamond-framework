# 7. Data Layer

## 7.1 Ingestion of Consensus Events

The reputation tensor T introduced in Section 3 is not declared by
the validator. It is derived from consensus events on the source
chains. For each chain c, domain d, and horizon h, the entry T[c,d,h]
is computed from a formula frozen at genesis:

    T[c,d,h] = f_c(events in window h)                             (1)

where f_c is a public function that maps the observed consensus events
to a normalized score in [0,1]. The formula is not changeable by the
validator; it is fixed before deployment and applies identically to
all validators on chain c.

The events themselves are consensus outputs: signed attestations,
governance votes, and liquidity events that have been finalized on
the source chain. They are not subjective judgments or off-chain
declarations.

## 7.2 Transport and Freshness

Entries of T are committed to the destination chain via state inclusion
proofs against signed headers of the source chains. This requires a
light client or a zero-knowledge bridge for each source chain. The
protocol does not define the transport mechanism; it requires that
the destination contract can verify inclusion proofs against signed
source-chain state.

The tensor T is frozen per epoch. Two consecutive epochs cannot differ
in more than γ·N entries, where N = CDH and γ is a freshness parameter.
The freshness constraint bounds the propagation of undetected fraud
across epochs.

## 7.3 The Fraud Proof Mechanism

Any party can submit a fraud proof consisting of two state inclusion
proofs against the same source-chain root that yield contradictory
values for a single entry T[c,d,h]. If the proof is valid, the entry
is marked fraudulent and the honest reporter receives a bounty B. The
validator whose entry was fraudulent is slashed.

We model the audit equilibrium as follows. Let N_ATT be the number of
attestations per epoch, p_fraud the fraction that are fraudulent, and
c_audit the cost of auditing one attestation. Each verifier decides
whether to audit based on the expected revenue:

    E[revenue] = p_fraud · N_ATT · B / n_auditors − c_audit         (2)

where n_auditors is the number of active auditors. A verifier enters
if E[revenue] > 0 and exits otherwise. The equilibrium is

    n*(B) = ⌊ B / B* ⌋                                             (3)

with the threshold fee

    B* = c_audit / p_fraud                                         (4)

For B < B* no auditor enters; for B ≥ B* at least one auditor is
active. The threshold B* is the fee at which a single auditor is
indifferent between auditing and not.

## 7.4 Numerical Verification

We verify (3) and (4) by Monte Carlo
[verification/data-layer/simulate_data_layer_v3.py]. The reference
parameters are N_ATT = 500, c_audit = 0.10, p_fraud = 0.10, V_fraud = 1.0,
S_slash = 10.0, N_VERIFIERS = 20. The threshold is B* = 0.10/0.10 = 1.0.

| B | n\*(B) | Detection | Attacker profit | Verifier profit | Integrity |
|---|--------|-----------|-----------------|-----------------|-----------|
| 0.75 | 0 | 0.000 | +49.91 | 0.00 | 0.9002 |
| 1.00 | 1 | 1.000 | −502.00 | +0.20 | 1.0000 |
| 2.00 | 2 | 1.000 | −502.00 | +0.20 | 1.0000 |
| 5.00 | 5 | 1.000 | −502.00 | +0.20 | 1.0000 |
| 10.00 | 10 | 1.000 | −502.00 | +0.20 | 1.0000 |
| 20.00 | 20 | 1.000 | −502.00 | +0.20 | 1.0000 |

The table reports the interior equilibrium points, where B is either
below the threshold or an exact integer multiple of B*. The transition
at B = B* is exact. For B below the threshold no verifier audits; the
attacker earns V_fraud · N_ATT · p_fraud per epoch without friction.
For B at or above the threshold the auditor coverage reaches 100% in
this model, and the attacker's expected profit is negative because
the slashing dominates the fraud gain.

At the interior equilibrium points the analytical verifier profit is
zero: the per-auditor revenue D · B/n* equals the per-auditor cost
N_ATT · c_audit = 50 exactly when n* = B/B*. The observed +0.20 is the
Monte Carlo deviation from zero, equal to (D_obs − D_theory) · B/n*.
With D_obs ≈ 50.2 and D_theory = 50.0, the deviation is 0.2 · B* =
0.20. Between interior points the verifier profit is strictly positive;
the value depends on B and is tabulated in the script output.

## 7.5 Slashing and Integrity

The attacker profit is negative for all B ≥ B* because the slashing
parameter S_slash = 10.0 exceeds the fraud gain V_fraud = 1.0 by an
order of magnitude. The design of the slashing parameter is outside
the scope of this section; the relevant observation is that once the
audit threshold is crossed, the fraud is deterred.

The reputation of a slashed validator is reduced according to the
process of Section 2. The combination of financial slashing and
reputation destruction makes fraud strictly unprofitable for any B
above the threshold.

## 7.6 Freshness as Second Line of Defense

The freshness parameter γ bounds the propagation of undetected fraud
across epochs. If a fraudulent entry is present in epoch t, it can
propagate to epoch t+1 only within the γ fraction allowed. Over k
epochs, the maximum fraction of fraudulent entries in the tensor is
bounded by

    fraud fraction ≤ γ · k                                         (5)

in the worst case, where the adversary can insert fresh fraud each
epoch. The growth is linear, not exponential. For γ = 0.10 and k = 10
epochs, the maximum fraudulent fraction is 1.0; for γ = 0.05 the
maximum is 0.5 after 10 epochs. The freshness constraint prevents a
single undetected fraud from contaminating the entire tensor.

## 7.7 Summary of the Section

| Claim | Status | Script |
|-------|--------|--------|
| B* = c_audit / p_fraud | Analytical | `simulate_data_layer_v3.py` |
| n\*(B) = ⌊B/B*⌋ equilibrium | Verified | `simulate_data_layer_v3.py` |
| Attacker profit −502 with S_slash = 10 | Verified | `simulate_data_layer_v3.py` |
| Integrity = 1.0 when n\* ≥ 1 | Verified | `simulate_data_layer_v3.py` |
| Freshness bounds propagation linearly | Analytical | — |

The Section describes the ingestion, transport, and fraud-proof
mechanism of the data layer, and verifies the audit equilibrium by
Monte Carlo. The freshness parameter provides a second line of
defense in case the fraud proof mechanism fails to detect a
particular attack.
