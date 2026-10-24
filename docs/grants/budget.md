# Budget

$50,000 over 16 weeks. Five lines, one purpose: have the finished work attacked
by someone who is paid to succeed at it.

## 1. Allocation

| # | Line | Amount | Unit basis |
|---|---|---|---|
| 1 | External audit of the nine core contracts | **$32,000** | ~4.5 auditor-weeks at $7,000/week; nine contracts, 2,673 core lines |
| 2 | Re-audit of the remediation diff | **$7,000** | ~1 auditor-week plus report review |
| 3 | Trusted-setup ceremony | **$4,500** | 3 participants, coordination, transcript, on-chain replacement |
| 4 | Fuzzing / invariant campaign in CI | **$4,000** | ~2 weeks of engineering plus CI time |
| 5 | Closure report, anchor re-seal, dissemination | **$2,500** | ~1.5 weeks of writing and sealing |
| | **Total** | **$50,000** | |

Rates are mid-tier firm estimates as of 2026-10; they are the weakest numbers in
this package and are listed as such.

## 2. If the quotes come in higher

The scope narrows in a fixed order, decided now so it is not negotiated under
pressure:

1. Audit **`AVIPRegistry`, `AVIPStakeVault`, `AVIPValidatorManager`** first — the
   three that hold policy, funds and the stake floor. Their statement coverage is
   100%, 100% and 100%, so the auditor starts from a tested floor.
2. Then `AVIPMessageEndpoint` and `AVIPMessageCodec` (cross-chain surface).
3. Then the channels and the sink (`AVIPSlashingChannel`,
   `AVIPCollusionAlertChannel`, `AVIPCommitmentRelay`, `AVIPBurnSink`).
4. `verifiers/Groth16Verifier` is generated and deliberately **not** in scope: an
   auditor reviewing generated code is paid to read constants. What is in scope is
   `verifiers/Bn254.sol` and the registry's use of the verifier interface.

If line 1 must exceed $32,000, line 5 drops first, then line 4. Lines 1 and 2 are
never traded away: an audit without a re-audit is a report, not a fix.

## 3. Co-funding: what is claimed, and what is not

No page reachable from `build.avax.network/grants` on **2026-10-24** states an
audit subsidy, a percentage, or a list of approved firms. The commonly mentioned
figure of the Foundation covering a large share of an audit from its own list
(two thirds, three quarters) is **not confirmed here** and is therefore not used
in the arithmetic above.

If it is real and available, the request changes as follows — and only then:

| With co-funding of the audit line | Request becomes |
|---|---|
| Foundation covers a share *x* of line 1 directly | Line 1 becomes `32,000 × (1 − x)`; the difference is reallocated to line 3 (ceremony) and a second re-audit, **or** removed from the request |
| Foundation supplies the firm in kind | Line 1 drops out; request falls to ~$18,000 (lines 2–5) |
| Co-funding requires an invoice from a company | Not applicable: the applicant is an individual, and this is stated in the submission rather than discovered later |

The proposal stands on $50,000 alone, because a budget that only works if an
unconfirmed programme exists is not a budget.

## 4. What is not funded, by design

- **Mainnet deployment.** Fuji is the target of this tranche; a mainnet launch
  would be a separate decision after an audit, not a line item before one.
- **A token, liquidity, or market making.** There is no token.
- **Salaries for the author.** The work to date was unfunded; the grant pays for
  external validation, not for the author's time.
- **Marketing or ecosystem incentives.**

## 5. Payment against deliverables

| Tranche | Trigger | Amount |
|---|---|---|
| 1 | Audit brief accepted and audited commit frozen | 10% |
| 2 | Audit report delivered | 50% |
| 3 | Remediation merged, gate green, re-audit report delivered | 25% |
| 4 | Ceremony transcript + closure report + re-sealed anchor | 15% |

Every trigger is an artefact a reviewer can open, and the last one is a timestamp
the project cannot backdate. If the grant is paid in a single instalment, the same
four artefacts define completion.
