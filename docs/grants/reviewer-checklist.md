# Reviewer checklist

The call states five criteria. Each row below maps one to evidence a reviewer can
check without trusting the applicant.

## 1. Published criteria → evidence

| Criterion (as published) | How it is met | Where to check |
|---|---|---|
| **Relevance** — validator economics, network security, non-inflationary rewards | Area 2 asks how validator incentives are structured, measured and optimised. The mechanism prices admission on non-transferable reputation; nothing pays a validator for existing. | Paper §5 (stake floor), §7 (slashing), §10 (open items) |
| **Methodological rigour** | Every claim carries a label (Verified / Measured / Estimated / Design / Deferred); 22 documented self-falsifications; a gate with 11 guards that re-derive their own values. | `docs/audit/numerical-verification.md`, `verification/audit-gate.sh` |
| **Novelty** | Admission is certified per validator on its **own** tensor entry — a proof of a global norm was removed because it is a bearer token. The coalition-cost result is derived, not simulated. | Paper §8 (zero-knowledge), §5.2 |
| **Feasibility** | Not promised: deployed on Fuji, verified on Snowtrace, 300 tests with none failing, 100% line coverage on registry/vault/manager (branch coverage 96.43/95.45/100), CI green on every push. | Addresses in `evidence-appendix.md`; `forge test` |
| **Researcher qualifications** | Sole author of paper and of all 250 commits; a public history where corrections are as visible as claims. No prior audit history — stated, not hidden. | `git log`, `docs/audit/sessions/` |
| **Proposal format** — ≤10 pages, question, methodology, contributions, timeline, budget, CVs | Sections 1–10 of `avalanche-research-proposal.md`, in that order. | this directory |

## 2. Commands a reviewer can run

```shell
# 1. The suite the proposal cites.
cd integrations/avalanche && forge test
#    expected: 0 failed, 300 total, 11 suites.
#    299 run offline; SafeForkTest skips without FUJI_RPC_URL and passes with it,
#    executing against the live 2-of-3 Safe on Fuji.

# 2. Coverage per contract (the numbers in §4 of the proposal).
forge coverage --report summary | grep -E 'contracts/AVIP|verifiers/'

# 3. The consistency gate, including a byte-for-byte anchor re-derivation.
cd ../.. && bash verification/audit-gate.sh
#    expected: PASS=11 FAIL=0 SKIP=0

# 4. The research record is what it says it is.
bash verification/fase0_anchor.sh --check
#    expected: exit 0, "IDENTICO byte a byte" over 11 pairs

# 5. The chain agrees with the document.
cast code 0x125f2054EaCFbd9e34F991cF7A437b3dC95E3eCa --rpc-url $FUJI_RPC_URL | wc -c
cast call 0x8DE8C8436D0cc9ED85ea630D5324B8A580EAd69a 'pendingVerifier()(address)' --rpc-url $FUJI_RPC_URL
```

No command requires a key, an account, or a network other than a public Fuji RPC.

## 3. Audit scope

**In scope: 2,856 lines** — the nine core contracts (2,673) plus the BN254 wrapper (183).

| Contract | Lines | Line cov. | Statement cov. | Branch cov. | Why it is in scope |
|---|---|---|---|---|---|
| `AVIPRegistry.sol` | 466 | 100% (114/114) | 99.21% (126/127) | 96.43% (27/28) | Epoch commitment, admission policy, role-rotation delay |
| `AVIPStakeVault.sol` | 476 | 100% (95/95) | 99.16% (118/119) | 95.45% (21/22) | Escrow; slash over the whole recorded stake |
| `AVIPValidatorManager.sol` | 332 | 100% (61/61) | 100% (75/75) | 100% (17/17) | Stake floor, ejection accounting, re-entry surcharge |
| `AVIPMessageCodec.sol` | 351 | 100% (46/46) | 95.45% (63/66) | 82.35% (14/17) | Encoding of commitments across chains |
| `AVIPMessageEndpoint.sol` | 335 | 93.55% (58/62) | 92.42% (61/66) | 61.54% (8/13) | Transport entry point |
| `AVIPCommitmentRelay.sol` | 246 | 100% (29/29) | 100% (29/29) | 100% (6/6) | Commitment relay |
| `AVIPSlashingChannel.sol` | 190 | 100% (23/23) | 100% (22/22) | 100% (3/3) | Slash path |
| `AVIPCollusionAlertChannel.sol` | 194 | 100% (18/18) | 100% (16/16) | 100% (3/3) | Collusion signal path |
| `AVIPBurnSink.sol` | 83 | 100% (11/11) | 100% (15/15) | 100% (4/4) | Sink for slashed value |
| `verifiers/Bn254.sol` | 183 | 95.24% (40/42) | 92.86% (52/56) | 80.00% (8/10) | Pairing and scalar checks around the verifier |

Reproduce with `forge coverage --report summary`. **Read the column, not the
headline:** line coverage is 100% on eight of the ten, but branch coverage is
where the audit should look — `AVIPMessageEndpoint` is 61.54% (8/13) and
`AVIPMessageCodec` 82.35% (14/17). Those uncovered branches are the transport's
failure paths, and the scope below asks the auditor to start there rather than
to re-walk what the suite already exercises. Claiming "100% coverage" without
the column would be true of lines and misleading about behaviour.

**Out of scope, with reasons:** `verifiers/Groth16Verifier.sol` (generated: constants
and pairing calls, reviewed as generated code rather than hand-written logic),
`interfaces/` (ABI transcriptions), and `test/mocks/`.

## 4. Attack surfaces the audit must cover

These are the questions the report is asked to answer. They are written as
questions, not as assurances:

1. **Whole-stake slash.** Can a validator reach a state where the vault debits less
   than the stake the manager has on record? Can rounding in `withdraw` be steered
   to lock or release a wei?
2. **Delay bypass.** Can `executeVerifierChange` be reached before
   `verifierChangeEta`, by any sender, through any path — including a re-entrant
   registry call or a guardian role change that lands mid-delay?
3. **Proof binding.** Are the four public inputs bound to epoch, validator and
   threshold, so a proof for one epoch cannot be replayed into another, nor for
   validator *A* used by *B*? Is `Bn254` malleability (e.g. negation of a proof
   element) rejected?
4. **Epoch freshness.** What happens between an epoch boundary and the next
   commitment? Does `UnknownEpoch` fire before `VerifierNotSet` in every
   configuration, and does that ordering leak anything?
5. **Cross-chain replay.** Is `sourceChainId()` enforced on every path that accepts
   a commitment, or only on the documented one?
6. **Escrow isolation.** Can a slash on one validator touch another's escrow, or a
   manager's recorded stake diverge from the vault's balance?
7. **Guardian compromise.** With a single EOA as guardian today, what is the worst
   case *inside* the 48-hour window, and what does the 2-of-3 Safe cover that the
   guardian does not?
8. **Re-entry surcharge.** Can `n·κ` be reset by ejecting and re-admitting through a
   different path, or through a zero-stake interlude?
9. **Sink and burn.** Is the burn path idempotent, and unreachable by a non-slash
   caller?
10. **Liveness.** Can a valid validator be made permanently unable to be admitted —
    griefing on the commitment or on the proof check?

## 5. What this package does not claim

- That the contracts are safe. They are unaudited; that is the premise of the
  request.
- That Fuji is production. Testnet, development key, no posted epoch, admission path
  not exercised on chain.
- That the economic model is calibrated on real data. It is not; that is open in the
  paper's §10 and is **not** part of this budget.

