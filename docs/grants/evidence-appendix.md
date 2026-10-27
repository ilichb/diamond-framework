# Evidence appendix

Supporting material for `avalanche-research-proposal.md`. Not counted in the ten
pages. Every figure here is re-derivable with `./figures.sh` or with a command from
`reviewer-checklist.md` §2; nothing is quoted from memory.

## 1. The record

| Item | Value |
|---|---|
| Repository | `github.com/ilichb/diamond-framework` (MIT) |
| Commits | 250 |
| Latest tag | `v0.2.2`, deposited 2026-10-25 |
| Preprint | *Diamond Framework: Reputation-Weighted Validator Selection via Verifiable Non-Transferable Reputation* |
| Concept DOI | `10.5281/zenodo.23268373` — v0.2.2: `10.5281/zenodo.23651484`; v0.1.0: `10.5281/zenodo.23268374` |
| Paper PDF | `docs/paper/releases/diamond-framework-2026-10-25.pdf`, 43 pp, 591,875 bytes |
| PDF SHA-256 | `89e718373158285821ac04d1a9280c7ff85baa8c03dbc4b8df9a6da481dd39b9` |
| Claim labels | Verified / Measured / Estimated / Design / Deferred, per section |
| Falsification log | `docs/audit/numerical-verification.md`, 22 entries (F-001 … F-022) |

## 2. The seal

The research record is hashed into a single root and timestamped, so a reviewer does
not have to trust a commit date.

| Item | Value |
|---|---|
| Root | `abe9c5535eb1dd7e462b49f19b52b828a9cfe235ccbcd32819f5daa37fe56bf7` |
| Pairs sealed | 11 |
| Re-derivation | `fase0_anchor.sh --check` → exit 0, byte-identical |
| Timestamp | OpenTimestamps, 4 calendars, `PendingAttestation` |
| Bitcoin attestation | **none yet for this root** — the receipt is hours old and is not cited as proof. The receipt over the preceding root did complete (Bitcoin blocks 972956, 972959, 973014) and is archived under `verification/ots-history/`; it seals other bytes, so it is not cited either. |
| Receipt | `docs/audit/anchor-receipts.md` R-15 (R-01 … R-15) |
| Superseded seals | `verification/ots-history/` (kept, never cited) |

The distinction matters: the seal says *these bytes existed by this time*, not *this
time is attested in Bitcoin*. The proposal does not blur it.

## 3. The chain

Fuji, chain 43113. Phase 2 (`2026-10-23`) and the verifier announcement
(`2026-10-24`).

| Contract | Address | Note |
|---|---|---|
| `AVIPRegistry` | `0x8DE8C8436D0cc9ED85ea630D5324B8A580EAd69a` | `CHANGE_DELAY` 172,800 s |
| `AVIPStakeVault` | `0xD560F40BfEd79D8a3b39279fc5Cd8149f71b7e60` | token + sink as inputs |
| `AVIPValidatorManager` | `0x88e60aA2f031B35C823CE4b8994804c025B80317` | stake floor |
| `Groth16Verifier` | `0x125f2054EaCFbd9e34F991cF7A437b3dC95E3eCa` | 5,517 bytes; dev key |
| Safe (2-of-3, `slashAuthority`) | `0x673F7725CF17A481299c7073486F8Fb222a66813` | policy read from the receipt, then re-executed against the fork: one signature is not enough, two are |
| Guardian / sender | `0x12458CD567C9f01cbA220Fe3f2Af97034f9635bb` | EOA |

| Transaction | Hash | Block | Gas |
|---|---|---|---|
| Deploy verifier | `0xa4c0760be19dd10368ebafe97fd520106738417b180adb6aeb443d5aa859a3fb` | 59,962,296 | 2,273,291 |
| `proposeVerifier` | `0x184a8e6eff8c80515981a0f66264694658c2c95a0035d85d8b92f31cc696eff7` | 59,962,546 | 46,299 |

Reads at proposal time: `code.verifier` 5,517 bytes · `keyDigest`
`0x018ce1b832c244ea2697e03f964c5f7e393bd88e2624ad6cd72de5a9dd3a319d` ·
`numPublicInputs` 4 · `icLength` 5 · `registry.verifier()` `0x0` ·
`pendingVerifier()` `0x125f…3eCa` · `verifierChangeEta` `1793035395`
(2026-10-26T17:22:54Z).

Measured refusals, which is what makes the delay more than a constant:

```text
executeVerifierChange()  →  revert ChangeNotReady(1793035395, 1792865535)   # 169,860 s early
verifyThreshold(...)     →  revert UnknownEpoch(0)  (0x80cfe517)           # AVIPRegistry.sol:427-431
registry.verifier()      →  0x0000…0000                                    # until the eta
```

## 4. The tests

| Metric | Value |
|---|---|
| `forge test` (offline) | **310 passed, 0 failed, 1 skipped** (311 total) |
| `forge test` with `FUJI_RPC_URL` | **311 passed, 0 failed, 0 skipped** — the extra one is `SafeForkTest`, a fork test of the live 2-of-3 Safe (468,956 gas) |
| Suites | 12 |
| Stateful invariants | **9**, over escrow conservation and admission consistency, 48 runs x 32 calls each (1,536 randomized calls per invariant) |
| Test code | 7,328 lines across 11 `.t.sol` files |
| Contract source | 3,956 lines, 20 files: **2,673 core** + 1,283 interfaces/verifiers |
| Toolchain | solc 0.8.33, EVM `cancun`, optimizer off (paper's gas basis) |

### 4.1 The stateful invariants

`test/invariant/AVIPInvariants.t.sol` fuzzes **sequences**, not paths: five actors
deposit, withdraw, get admitted, pay the fee and are slashed in random order, and
nine invariants are checked after every call. The unit suite asserts one chosen
ordering per property; this asserts the property over 1,536 of them.

| Invariant | What it would catch |
|---|---|
| `conservationOfUnits` | `totalDeposited == totalEscrowedUnits + totalReleased + totalDebited` |
| `vaultHoldsExactlyItsEscrow` | a unit counted twice, or escrow not backed by the token |
| `aggregateIsTheSumOfValidators` | a per-validator update that forgets `totalEscrowedUnits` |
| `everyValidatorIsBacked` | escrow not covering `stakeOf` — the M8 claim, over random orderings |
| `admissionImpliesRequirement` | a slash that lowers the record without ejecting |
| `unadmittedHasNoStake` | a record left behind after an ejection |
| `ejectionsNeverDecrease` | a wiped ejection penalty |
| `withdrawableIsWithinEscrow` | a withdrawal view that offers more than exists |
| `sinkReceivedWhatLeftEscrow` | a debit or fee that does not reach the sink |

**The invariants bite, and that is tested.** Two mutations of the shipped code
were applied and reverted: removing the aggregate update in `withdraw` fails
`conservationOfUnits` with `733334 != 1466667`, and removing the ejection in
`slash` fails `admissionImpliesRequirement` with `0 < 733333333333328031`. A
tenth test, `test_handlerReachesEveryPath`, asserts each handler path actually
lands — it was added after the first run showed nine green invariants over a
handler whose `admit` was silently reverting on a malformed proof.

**What this does not prove.** `AcceptAllVerifier` accepts every proof, so nothing
here says anything about §5.2 or the pairing check; `MockERC20` transfers exactly
what it is asked, so the fee-on-transfer and reverting-token cases of M8 are not
covered; and five actors with no routing between them is not a network. The
invariants are evidence that the escrow accounting holds under fuzzing, not
evidence that it is correct, and they are not the audit.

Coverage per contract, from `forge coverage --report summary`. All four columns are
reproduced because publishing only the first one would be true and misleading:

| Contract | Lines | Statements | Branches | Functions |
|---|---|---|---|---|
| `AVIPRegistry` | **100%** (114/114) | 99.21% (126/127) | 96.43% (27/28) | 100% (20/20) |
| `AVIPStakeVault` | **100%** (95/95) | 99.16% (118/119) | 95.45% (21/22) | 100% (18/18) |
| `AVIPValidatorManager` | **100%** (61/61) | 100% (75/75) | 100% (17/17) | 100% (10/10) |
| `AVIPMessageCodec` | **100%** (46/46) | 95.45% (63/66) | 82.35% (14/17) | 100% (11/11) |
| `AVIPMessageEndpoint` | 93.55% (58/62) | 92.42% (61/66) | **61.54%** (8/13) | 100% (11/11) |
| `AVIPCommitmentRelay` | **100%** (29/29) | 100% (29/29) | 100% (6/6) | 100% (7/7) |
| `AVIPSlashingChannel` | **100%** (23/23) | 100% (22/22) | 100% (3/3) | 100% (6/6) |
| `AVIPCollusionAlertChannel` | **100%** (18/18) | 100% (16/16) | 100% (3/3) | 100% (5/5) |
| `AVIPBurnSink` | **100%** (11/11) | 100% (15/15) | 100% (4/4) | 100% (2/2) |
| `verifiers/Bn254` | 95.24% (40/42) | 92.86% (52/56) | 80.00% (8/10) | 100% (7/7) |
| `verifiers/Groth16Verifier` | **100%** (62/62) | 97.06% (66/68) | 77.78% (7/9) | 100% (13/13) |
| `verifiers/Bn254` | 95.24% (40/42) | 92.86% (52/56) | 100% (7/7) |

The repository-wide figure (7.97%) is not quoted here on purpose: it is dominated
by `test/mocks` and the generated verifier. Coverage is not security and is offered
only as the floor an auditor starts from.

## 5. The gate

```text
G1  scripts present             PASS
G2  harness exits               PASS  (38/38)
G3  drift lines                 PASS  (0)
G4  orphan claims               PASS  (0 of 29)
G5  falsification entries       PASS  (22)
G6  worksheets                  PASS  (50)
G7  cost check                  PASS  (exit 0)
G8  no Estimate/Verified mix    PASS
G9  pdflatex clean              PASS  (0 errors, 0 undefined)
G10 output manifest             PASS  (38 outputs)
G11 anchor re-derived           PASS  (exit 0)
PASS=11 FAIL=0 SKIP=0
```

`G11` is the guard that matters for this application: it re-derives the anchor from
the tree, so the paper a reviewer reads is the paper the gate passed.
