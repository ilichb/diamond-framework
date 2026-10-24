# Evidence appendix

Supporting material for `avalanche-research-proposal.md`. Not counted in the ten
pages. Every figure here is re-derivable with `./figures.sh` or with a command from
`reviewer-checklist.md` §2; nothing is quoted from memory.

## 1. The record

| Item | Value |
|---|---|
| Repository | `github.com/ilichb/diamond-framework` (MIT) |
| Commits | 250 |
| Latest tag | `v0.2.1`; `v0.2.2` sealed and pending deposit |
| Preprint | *Diamond Framework: Reputation-Weighted Validator Selection via Verifiable Non-Transferable Reputation* |
| Concept DOI | `10.5281/zenodo.23268373` (v0.1.0: `10.5281/zenodo.23268374`) |
| Paper PDF | `docs/paper/releases/diamond-framework-2026-10-24.pdf`, 43 pp, 591,880 bytes |
| PDF SHA-256 | `5651a2f31707d26c9ff9ca1009e385d046e7004e7dd5397226577670e4f3dd16` |
| Claim labels | Verified / Measured / Estimated / Design / Deferred, per section |
| Falsification log | `docs/audit/numerical-verification.md`, 22 entries (F-001 … F-022) |

## 2. The seal

The research record is hashed into a single root and timestamped, so a reviewer does
not have to trust a commit date.

| Item | Value |
|---|---|
| Root | `ca83694715739ac2ce8eb24874f3c33c1df69bbb4852b802e85dac899b23b020` |
| Pairs sealed | 11 |
| Re-derivation | `fase0_anchor.sh --check` → exit 0, byte-identical |
| Timestamp | OpenTimestamps, 4 calendars, `PendingAttestation` |
| Bitcoin attestation | **none yet** — the receipt is young and is not cited as proof |
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
| `forge test` (offline) | **299 passed, 0 failed, 1 skipped** (300 total) |
| `forge test` with `FUJI_RPC_URL` | **300 passed, 0 failed, 0 skipped** — the extra one is `SafeForkTest`, a fork test of the live 2-of-3 Safe (468,956 gas) |
| Suites | 11 |
| Test code | 6,878 lines across 10 `.t.sol` files |
| Contract source | 3,956 lines, 20 files: **2,673 core** + 1,283 interfaces/verifiers |
| Toolchain | solc 0.8.33, EVM `cancun`, optimizer off (paper's gas basis) |

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
