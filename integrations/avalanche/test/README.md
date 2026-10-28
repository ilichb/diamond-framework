# `integrations/avalanche/test/` — Foundry tests

Status: **317 tests over thirteen suites (plus two libraries), all green with
`forge test --offline`**:

| File | Tests | Scope |
|------|-------|-------|
| `AVIPRegistry.t.sol` | 53 | M1 registry: Merkle convention — including R5-2, where an odd level must promote its last node rather than duplicate it, checked against the data layer's own 500 leaves — sequential epochs, freshness bound and the two per-epoch roots — keccak `commitmentOf` for `verifyEntry`, Poseidon `statementRootOf` for `verifyThreshold` (P-16) — with the statement binding the validator and the certified norm (P-01). Plus M9a's authority pair (§12.1.2): the guardian proposes and cancels, anybody executes after `CHANGE_DELAY`, executing early reverts, the two pending changes are independent, the sitting sequencer can neither rotate itself nor veto the rotation that replaces it, and the constructor refuses a zero guardian |
| `AVIPValidatorManager.t.sol` | 37 | M2 manager: `C_R`/`S_f*` parameters, admission, anti-replay, slashing and ejection, plus 2 fuzz tests — amended in M8 by one constructor argument (`custody = address(0)`), so it also *is* the evidence that the M2 mode is unchanged, in M9b by the derived slash amount (the whole record, with `NothingToSlash` for an empty one), and in M9c by the ejection surcharge (re-entry costs `+κ`, `+2κ`, the credit is unchanged, the count is per validator and survives re-admission) |
| `Bn254.t.sol` | 16 | M3 library: field/group parameters, proof decoding (length, canonicality, trailing bytes) and the `0x06`/`0x07`/`0x08` wrappers |
| `Groth16Verifier.t.sol` | 18 | M3 verifier: key installation and digest, accept/reject verdicts, off-curve revert, gas, and the `AVIPRegistry`/`AVIPValidatorManager` integration |
| `M4dRealKey.t.sol` | 10 | M4d (audit P-01/P-16) and the P-33 hardening: the real admission key and the real inclusion proof, accepted by `Groth16Verifier.verify` and by `AVIPRegistry.verifyThreshold`; every component of `[statementRoot, epoch, validator, certifiedNorm]` is bound, a proof for one validator cannot admit another, the same roots at the next epoch are rejected, a norm outside the circuit's domain (`WAD`, and `-1` in the scalar field) is refused before the blob is decoded, the Rust `keccak256(abi.encode(vk))` digest matches the contract's, and the five-`ic` statement is priced (234,284 for `verify`, 306,275 cold / 247,233 warm through `verifyThreshold`) |
| `M4dRootSeparation.t.sol` | 6 | M4d P-16: **one** registry holds both roots of one epoch in one `postCommitment` — M1's keccak fold and the admission tree — and serves both legs from it; the admission proof does not verify against the tensor's statement root, swapping the slots breaks both legs, `linkDigest` rejects the admission root in either word, the two fixtures are one tensor carrying two different quantities (`‖T‖₂` vs one entry), and the absence of an on-chain tie between the two roots is a test rather than an implication |
| `M7dTransport.t.sol` | 48 | M7d: the wire format's fail-closed edges, `linkDigest` against M7c's committed link, the endpoint boundary (messenger, allowlist, nonce, kind), and the three §4 message types end to end — the commitment recorded once, the alert flag that cannot be erased, and the slashing notification reaching `AVIPValidatorManager.slash` with a reason derived from the envelope and no amount in the payload (amended in M9b), one record per notification (plus 3 fuzz tests) |
| `M8StakeVault.t.sol` | 64 | M8 (§5.12): the handshake (bind, one-shot, a vault taken by somebody else — and by an EOA, which then drains a victim's escrow through `debit` and freezes the remainder), the unbound vault as a plain escrow, escrow accounting and the two rounding boundaries, admission bound to escrow, the whole-record slash (M9b: the debit equals the escrow the record names, a slash that moves funds, the round-up dust that stays the validator's, and a rollback that is whole when the token or the sink refuses), the ejected validator's re-entry (M9c: the count survives the withdrawal and prices the next admission), `debit`/`payFee` authorisation, USDT-style/`false`/reverting tokens, four reentrancy attempts, the conservation identity (plus 2 fuzz tests), and `AVIPBurnSink` in its own contract (plus a stray transfer it must leave untouched) |
| `DeployScripts.t.sol` | 24 | M7a + M8 + M9a: `_roleOr` resolution (absent/empty/malformed), the three deploy scripts driven through `deploy(Plan)` — wiring, the frozen registry/policy constants, the mainnet refusal, the deployed pair interoperating, the M8 handshake chained across the vault and manager scripts, and M9a's guardian argument (a zero guardian and a guardian equal to the sequencer are refused before anything is created, and the registry a `Plan` deploys does rotate its own sequencer through propose/execute) |
| `DatalayerInclusion.t.sol` | 5 | R5-1 across the language boundary: the payloads, leaves, roots and proofs are emitted from `avip_datalayer::commitment` by `../../../../src/zk/scripts/merkle_fixture.sh`, and the deployed `verifyEntry` accepts all four entries of the 4-entry epoch and the tensor's proofs. No Solidity code here builds a tree. Also the negative side: the pre-R5-1 root (the leaves folded directly) is rejected on-chain, so the two conventions are not interchangeable |
| `fixtures/DatalayerInclusion.sol` | — | **generated** by `../../../../src/zk/scripts/merkle_fixture.sh` (the Rust crate that owns the data layer's fold); do not edit by hand. R5-1's and R5-2's cross-language vector |
| `fixtures/Groth16Fixtures.sol` | — | **generated** by `../scripts/generate_groth16_fixtures.py`; do not edit by hand |
| `fixtures/M4dGroth16Fixtures.sol` | — | **generated** by `../../../../src/zk/scripts/m4d_fixture.sh` (the Rust crate that owns the admission circuit); do not edit by hand |
| `fixtures/M4bGroth16Fixtures.sol` | — | **generated** by `../../../../src/zk/scripts/m4b_fixture.sh`; do not edit by hand. *Retired as an admission artifact* by M4d (audit P-01/P-16): no contract accepts its global statement `[root, epoch, certifiedNorm]` any more. It stays committed because M7c's bridge fixture and `../../src/zk/tests/m7c_bridge.rs` read its `TENSOR_DIGEST` and `STATEMENT_ROOT` (and `scripts/m7c_output.txt` is pinned against them) |
| `fixtures/M7cBridgeFixtures.sol` | — | **declared**, not generated: the five words of M7c's committed table, checked against it by `../../src/zk/scripts/m7c_report.sh` and by `../scripts/m7d_report.sh` |
| `fixtures/M7dProvenanceFixtures.sol` | — | **declared**, not generated: M5's sealed `q99` pair and M7b's adjudicated `Verdict::Fraud`, checked against both transcripts by `../scripts/m7d_report.sh` |
| `fixtures/M8CustodyFixtures.sol` | — | **declared**, not generated: M7d's stake trajectory and slashing reason (the numbers M8 replays against real escrow) plus the six-decimal scale, checked against `m7d_output.txt` by `../scripts/m8_report.sh` |
| `mocks/MockThresholdVerifier.sol` | — | the `IZKThresholdVerifier` double used by the M1/M2 suites |
| `mocks/MockTeleporterMessenger.sol` | — | the Teleporter/AWM double used by the M7d suite and by `../scripts/M7dReport.s.sol`: a routing table (`endpoint → chain`) with synchronous delivery |
| `mocks/MockERC20.sol` | — | the M8 token double whose *behaviour* is a knob: no return data (USDT-style), a `false` return after moving, a revert with a reason, a silent revert, a fee-on-transfer, and a re-entry hook that records whether the attempt succeeded |
| `mocks/MockBurnableERC20.sol` | — | `MockERC20` plus `burn`, and a `burn` that answers `false` without destroying |
| `mocks/MockFundSink.sol` | — | the M8 sink double: keeps what it receives, records the reason and the amount, can refuse, and can re-enter the vault |
| `mocks/MockDeafCustody.sol` | — | a custody that accepts the handshake and reports nobody — the single case `CustodyNotBound` exists for |

`mocks/MockThresholdVerifier.sol` does not simply answer `true`: it asserts the
`(a, b, c)` it receives and the `keccak256` of the public statement it is called
with, and reverts otherwise. That is what makes "the registry forwards the proof
unchanged" and "the registry builds
`[statementRoot, epoch, uint160(validator), certifiedNorm]` itself" properties
of the double rather than assumptions of the test. The M3 and M4d suites are the
ones that run the real pairing check (`Groth16Verifier`), and they still keep the
double for the M1/M2 semantics.

`mocks/MockTeleporterMessenger.sol` follows the same rule: it reads the *source*
chain id from its own routing table instead of from the caller (so a sender cannot
claim to be somewhere else), refuses an unregistered endpoint and a destination
chain that does not match the destination address, and delivers synchronously so
the receiver's decision is observable in the caller's frame. What it is **not** —
no BLS, no quorum, no relayer, no fee, no gas, no retry queue, and therefore no
latency and no claim about the real protocol — is written at the top of the file,
because the M7d suite relies on the double and must say so.


## Rule (from `CONTRIBUTING.md`)

> Code in `integrations/avalanche/` is merged only with unit tests **and** an
> explicit statement of what is tested and what is not.

Every test file must therefore ship with, at the top of the file as a NatSpec
block or comment:

- **What is tested**: the properties asserted, with the paper section they
  trace to.
- **What is NOT tested**: the gaps (e.g. "the recursive SNARK is not verified;
  `IZKThresholdVerifier` is mocked").

## Conventions

- One test file per contract: `test/AVIPRegistry.t.sol`,
  `test/AVIPValidatorManager.t.sol`, `test/Groth16Verifier.t.sol`; libraries are
  tested through `test/Bn254.t.sol` plus the harness in the same file (a
  library's `internal` functions are inlined, so they need a wrapper contract
  to be observed from outside). M7d's `AVIPMessageCodec` needs the same wrapper
  for the same reason (`AVIPMessageCodecHarness` in
  `test/M7dTransport.t.sol`), and M7d's three contracts share one file because
  they share one boundary; M8's vault and its reference sink share
  `test/M8StakeVault.t.sol` for the same reason (two contracts in the file, the
  second parametrised over the sink alone). The M7a deploy scripts are Solidity
  too, so they get their own file, `test/DeployScripts.t.sol`, with the same
  `DeployCommonHarness` trick for `_roleOr`. Shared doubles in `test/mocks/`,
  generated fixtures in `test/fixtures/`.
- **Mutually referential wiring is predicted, then checked.** M7d's endpoints name
  each other (a source's routing table names its destination, the destination's
  allowlist names the source) and both sides are constructor-fixed, so the three
  destination addresses are computed from the CREATE nonce before they exist and
  compared with `assertEq` the moment they do. The same cycle fixes the manager's
  slasher, and the failure mode of a wrong guess is a loud `setUp` failure rather
  than a transport wired to a contract nobody can use. `setUp` documents its
  deployment order because the offsets depend on it. **M8 hits the same cycle in
  the funds layer** — the vault authorises its manager, the manager debits its
  vault — and answers it with a one-shot handshake instead of a prediction: the
  vault is deployed first and its `bindManager()` is filled by the manager's own
  constructor, which then verifies `manager() == address(this)`. The suite asserts
  both ends, the one-shot property, and the two ways a bad pairing fails the
  deployment (`ManagerAlreadyBound`, `CustodyNotBound`).
- **Read a value before you `prank`.** `vm.prank` applies to the *next external
  call*, so `vm.prank(v); vault.withdraw(vault.withdrawable(v))` reads as `v` and
  then withdraws as the test contract — the M2 suite documents the pitfall and M8
  hits it twice during development. Compute the argument first, then prank.
- Deploy scripts are driven through `deploy(Plan)`, never through the
  environment: `vm.setEnv` is process-wide and outlives the test that made it, so
  a suite cannot prove which environment a script saw. The environment → plan
  mapping is asserted out of process by `../scripts/deploy_dryrun.sh`, one fresh
  CLI process per case, and the tests that must call `setEnv` each own a unique
  variable name.
- `forge-std` is reused from the benchmarks project via the remapping in
  `../foundry.toml`; do not vendor a second copy.
- Numeric assertions must trace to a paper claim or to a `verification/`
  script. Invented constants are not accepted.
- Tests must pass offline: `forge test` must not require network access.

## Run

```shell
cd integrations/avalanche
forge test --offline            # 274 tests
forge test --offline -vv --match-path 'test/DeployScripts*'
forge test --offline --match-path 'test/M7dTransport*'
forge test --offline --match-path 'test/M8StakeVault*'
```

Note the glob: on forge 1.5.1 `--match-path test/DeployScripts.t.sol` matches
nothing and reports no error — use `--match-contract DeployScriptsTest` or the
`test/DeployScripts*` form above. The dry-run transcript of the same scripts is
`../scripts/deploy_dryrun_output.txt`, reproduced by `bash
../scripts/deploy_dryrun.sh`; M8's custody audit is
`../scripts/m8_output.txt`, reproduced by `bash ../scripts/m8_report.sh`.
