# P-12 — binding the freshness bound to something the chain can check

**Status:** analysis, closes `L1`. No contract change and no re-seal; the one code
change it carries is the defect fix of §7 (`R5-1`, `R5-2`), because a memo that says
"the fraud proof (b) describes would reject every honest proof" and leaves it there
is a memo that hands `T1-M2` a broken precondition.
**Decides:** which option `T1-M2` implements and `G3` waits for.
**Question (audit `P-12`):** "la freshness `γN` sólo se comprueba sobre el delta
declarado" — can the bound be closed *without* changing the circuit's statement?

**Answer:** yes, under all three candidate options. Only a fourth option — proving
the delta inside a circuit — changes the statement, and it is not needed. What the
three options differ in is who is trusted, not what is proved.

## 1. What the code does today

| Piece | Where | What it does |
|---|---|---|
| `TENSOR_SIZE = 500`, `MAX_DELTA_ENTRIES = 50` | `AVIPRegistry.sol:70-79` | the bound, `γ = 0.10` in basis points |
| `postCommitment` | `AVIPRegistry.sol:320-370` | rejects `changedEntries > 50` (`:351-353`), requires `500` at genesis (`:349-350`), stores `root`, `statementRoot`, `changedEntries` (`:355-357`) |
| `commitmentOf` / `changedEntriesOf` | `AVIPRegistry.sol:373-385` | read back the two per-epoch words |
| `Epoch::changed_entries` | `src/datalayer/src/commitment.rs:229-243` | compares two `BTreeMap<validator, norm>`, counts added, removed and changed |
| `Epoch::freshness_ok` | `src/datalayer/src/commitment.rs:249-256` | applies `<= 50`, or `== 500` at genesis |
| `adjudicate` | `src/datalayer/src/ingestion.rs:251-268` | compares one published leaf with `f_c(events)`; it does not count a delta |

The producer and the checker are the same party. The registry stores no tensor, so
it cannot recompute the delta, and the contract says so in its own docstring
(`AVIPRegistry.sol:25-30`): it enforces the bound **on the delta the sequencer
declares**. The audit's PoC (`docs/audit/audit-2026-10-20-in-progress.md:878-883`)
posts a completely different root with `changedEntries = 0`, twice, and both calls
pass.

Three holes follow from that and are already written down
(`audit-2026-10-20-in-progress.md:897-918`): `Epoch::new` accepts any `Vec<Entry>`,
so a genesis epoch of 501 leaves with a repeated address can pass as `500`, and an
epoch of 1,000 leaves (each address twice, same norm) can pass as `changed == 0`.
`AVIPMessageCodec.decodeCommitment` (`AVIPMessageCodec.sol:281-293`) bounds nothing
either, so the declared number travels to the relay unverified.

## 2. The three options, as the audit already framed them

`P-12`'s remediation list (`:920-933`) has two entries that are the same two the
owner's brief names as (a) and (c); (b) is its first entry read as a challenge
game rather than as a per-epoch payload:

| | Option | Who must be honest |
|---|---|---|
| (a) | Validate in the data layer: `len == 500`, unique `validator`, `delta <= 50`, before the root is computed | the sequencer, as today — but a *bug* can no longer produce an out-of-bound epoch |
| (b) | Optimistic violation proof: exhibit 51 changed entries with inclusion in both roots, on-chain | nobody: a liar is refuted, given a window and a bond |
| (c) | Sequencer attestation with the bounded field: the declared delta is the attestation, and the field is bounded everywhere it travels | the sequencer, on purpose and on the record |

## 3. Option (a) — validation in the data layer

**What it buys.** Three concrete holes close with no gas and no circuit: an epoch
that is not 500 leaves, an epoch with a duplicated validator, and an epoch whose
declared delta disagrees with its own two maps. Each is a cheap check at
`Epoch::new` or at the head of `freshness_ok`, plus the two tests the audit asks
for (501 leaves with a duplicate; 1,000 leaves with every address twice).

**What it does not buy.** Anything against a sequencer that lies. The check runs
on the producer's own machine, over the producer's own vector. The PoC is
unaffected by it: a wrong root with `changedEntries = 0` is still accepted,
because "the data layer computed 0" and "the sequencer declared 0" are the same
sentence when the sequencer runs the data layer.

**Cost.** One Rust change, two tests, no on-chain change, no re-seal of
`main.tex`. **No new circuit.**

**Verdict.** Necessary and not sufficient. It is the precondition of (b), not an
alternative to it: (b) counts changed entries *by validator address*, so the
address has to be the identity of an entry — which is exactly what the uniqueness
rule in (a) establishes.

## 4. Option (b) — an optimistic violation proof

**The shape.** A violation is "more than 50 entries changed". To prove it you
exhibit 51 entries, each with two inclusions:

```
for i in 51 entries:  (v_i, old_i) in root[e-1]  and  (v_i, new_i) in root[e],  old_i != new_i
```

That is 102 inclusion proofs of depth 9 (`500 -> 250 -> 125 -> ... -> 1`). It is
the minimum: exhibiting 51 is what makes the count exceed `γN`, and both roots are
needed to show a *change* rather than a value. Non-inclusion proofs are not
required, which matters because the tree is unsorted and has no index — the
address inside the leaf is the dedup key, and `old != new` is the change.

**Measured, not estimated — and decomposed this time.** A temporary Foundry probe
(deleted after the run; `integrations/avalanche/test/` is not in the anchor, so
nothing was re-sealed) called `verifyEntry` on the contract, over the 500-leaf tensor
(depth 9, `500 -> 250 -> 125 -> ... -> 1`), from inside one transaction:

| Measurement | Gas |
|---|---|
| 102 verifications in one transaction (51 entries × 2 roots) | **1,631,531** |
| the same loop with the verifications removed (the harness's own cost) | 94,202 |
| 102 verifications, harness removed | 1,537,329 |
| per inclusion, marginal and warm (all-in) | **15,072** |
| one inclusion, the contract's own execution, depth 9 (`forge test --gas-report`) | 6,990 (max) |
| for comparison: `verifyThreshold` with the **real** M4d key (`--gas-report`, median) | 293,293 |

`1,631,531 / 293,293 = 5.56`: one freshness challenge costs about five and a half
full Groth16 verifications, and one inclusion costs 5.1% of one. The ~8.1k between
the contract's own 6,990 and the 15,072 the batch pays per inclusion is the caller's
side of an external call — encoding a 9-word `bytes32[]` into memory, the `CALL`
itself, the return copy — which a batch pays per inclusion as well. Nothing in that
8.1k is the tree: the tree is built off-chain and only the path crosses the boundary.

**Two numbers retracted, and one divisor that was never a divisor.** An earlier
revision of this section quoted "one inclusion = 10,630", "102 inclusions =
1,227,747" and "4.29× `verifyThreshold`'s 286,144". They do not reconcile —
`102 × 10,630 = 1,084,260`, leaving 143,487 unaccounted — and the probe that
produced them was deleted before the decomposition was written down. They are
withdrawn rather than re-explained.

The `286,144` needs its own sentence, because it is **not** a wrong number: it is
V3's cold-path verification cost, the figure §5.5.9's circuit and the paper's
release notes quote. What was wrong is that this section borrowed it as the
denominator of a *freshness* ratio. The key that admits validators today is M4d's,
not V3's. Measured 2026-10-28: `verifyThreshold` costs
**306,253 cold / 247,211 warm** with that key (`test_theAdmissionVerificationCostsFiveIcPoints`;
§5.5.11 records 306,275 / 247,233 — the same test, 22 gas more, so a toolchain drift
and not a different quantity), and `--gas-report` aggregates 18 calls at **293,293**
median / **305,706** max. The ratio below divides by the median because the batch it
divides is warm. The retraction is of the comparison, not of the number: `4.29×` was
one key's cost divided by another key's cost.

Two caveats on that reading, both owned elsewhere and both open. The paper
does call 286,144 "the deployed figure" (`main.tex:537`, `:559`, `:1294`), which is
a defect of the *label* rather than of the number — a three-input key cannot be
installed at all, since the registry passes four public inputs and the verifier
reverts `PublicInputsMismatch(3, 4)`. That is registered as `E-01` in
[`../paper/releases/v0.2.3-errata.md`](../paper/releases/v0.2.3-errata.md) with its
measurement in [`../audit/evidence/2026-10-28-v3-vs-m4d-gas/`](../audit/evidence/2026-10-28-v3-vs-m4d-gas/README.md).
Since 2026-10-28 it ships in v0.2.3 as free-lane, self-funded work rather than in the
reserved lane, and the shape is decided: the installed key's figure is the deployed
one. That figure is **306,253** on today's toolchain (306,275 on the earlier one),
measured cold with the four-input key — not a like-for-like re-measurement of V3's.
Of the 20,109-gas gap, 8,873 is the extra `ic` point and the rest is `AVIPRegistry`'s
growth since 2026-10-20, which this memo does not decompose further. The full
admission path is now measured too: `manager.admit` is 395,255 cold with that key,
against the V3-era 376,588.

The table above is reproducible: build the tensor's 102 (leaf, root, proof) triples
with the promote fold, measure `gasleft()` around a loop of 102 `verifyEntry` calls,
and around the same loop with the calls removed; the two figures differ by the
verifications alone.

All of it is the project's own build (solc 0.8.33, legacy pipeline, no `viaIR`). The
earlier revision also quoted `viaIR` figures (5,341 and 686,597); those came from the
same withdrawn run and are not quoted here.

**What (b) needs to exist.** A challenge entrypoint with a window, `commitmentOf`
for both epochs (already public), a dedup rule by address, and a bounty — which is
`P-18` ("el bounty `B` no tiene ruta de pago"), still open, with `P-34` (slash
without proof) in the same family. Until those two are answered, (b) can be built
only as an *adjudication surface that reports*, like today's off-chain
`adjudicate`, and not as a mechanism that moves money. That is a scope statement,
not a blocker on the design.

**What (b) still cannot see.** A duplicated leaf is not a changed entry: the
1,000-leaf epoch has `changed == 0` by address, its extra leaves are invisible to
a count, and the fraud proof — which counts by address — agrees with it. So (b)
does not replace (a). It assumes it.

**No new circuit.**

## 5. Option (c) — the sequencer's attestation with the bounded field

The brief's wording covers two different things, and separating them is the whole
value of the option:

| | What is attested | Cost | Soundness |
|---|---|---|---|
| (c1) | the *count*, `changedEntries` | 0 gas: the field already exists (`_changedEntries`, `AVIPRegistry.sol:357`) | trust, stated in the paper instead of implied |
| (c2) | the changed *set*: at most 50 `(validator, old, new)` triples per epoch | ~4.2 KB of calldata per epoch (`50 × (20 + 32 + 32)`), i.e. ~67k gas at 16 gas per non-zero byte — arithmetic from EVM constants, **not measured** | checkable by anyone, with no challenge game and no bond |

(c1) is what the chain does today plus two things it lacks: a bound on the field
where it travels (`AVIPMessageCodec.decodeCommitment`, `:281-293`), and a sentence
in the paper saying the field is an attestation. It converts an unstated trust
assumption into a stated one. It closes nothing about a lying sequencer.

(c2) is the honest middle: the sequencer publishes the delta instead of its
cardinality, so every reader can verify it against the two roots with the same 102
inclusions, and no window is needed because nothing is being refuted — the epoch
is simply self-certifying or wrong on arrival. It costs every epoch instead of
only when challenged, which is the mirror image of (b)'s economics.

**No new circuit**, under either reading.

## 6. Only one option needs a new circuit, and it is none of these three

Proving the bound *inside* a proof means proving it over two epochs at once: a
circuit that reads 500 Poseidon leaves for epoch `e-1` and 500 for epoch `e`,
compares them and outputs the delta. That is the paper's **Option A′**, 240,261
constraints (`main.tex:530`, `:551`), whose verification the paper measures at
~30M gas in the recursive row. It changes the statement and therefore the
verifying key, which re-opens the ceremony.

The three options above leave the admission statement untouched:

| Option | New circuit? | Statement change? |
|---|---|---|
| (a) data-layer validation | no | none |
| (b) optimistic violation proof | no | none: it is a second entrypoint reading `commitmentOf` |
| (c1)/(c2) attestation with bounded field | no | none |

## 7. Precondition zero: the two trees did not share a bottom rule — closed

(b) is the option that needs on-chain inclusion to work, and until 2026-10-28 it
would not have. `AVIPRegistry.verifyEntry` starts the fold at
`keccak256(abi.encodePacked(leaf))` (`:410`), while the data layer's `merkle_root`
folded `Entry::leaf()` directly, and `verify_entry` called itself "the contract's
`verifyEntry`" while doing it. They differed by one hash at the bottom.

Measured against the repo's own pinned fixture — `keccak256_vectors.txt`, four
entries, `cast keccak`-generated — with the contract:

```
verifyEntry accepts the data layer's root/proof: false
verifyEntry accepts the contract's own tree:      true
contract root for the same four entries: 0x6d7dbeead031ce88ee6f534d9c2fef6063ab9471b1fe3cde38bd0b26555eed36
(while root(4) in the fixture was        0xa708d90e3df263b03d823e688d8780c6d6f378b9a0696647b4ab2129adbeffd8)
```

Both sides were self-consistent; neither suite could see it, because the Rust tests
compared Rust with Rust (`independent_root` repeated the missing step) and the
Solidity tests compared Solidity with Solidity (`_buildTree`). It failed closed, and
nothing on-chain consumed `verifyEntry`, so no deployment was broken — but any fraud
proof in the shape (b) describes would have rejected every honest proof.

**Resolved, contract's rule wins (`R5-1`).** The data layer gained the bottom hash
(`commitment::bottom_node`), because the contract is deployed and changing it would
be bytecode and a redeploy, while the ceremony freezes nothing in the keccak tree
(§8). `root(4)` is now the contract's `0x6d7dbeea…` above, and it is asserted three
ways: `cast`-generated in the fixture, by the Rust suite, and — the cross-language
part — by `integrations/avalanche/test/DatalayerInclusion.t.sol`, which runs the
contract's `verifyEntry` over payloads, leaves and proofs that
`src/zk/scripts/merkle_fixture.sh` emitted from the data layer. `verifyEntry` also
rejects the retired root on-chain, so the two conventions cannot be confused again.
`commitment.rs`'s comment now says what the code does.

**Second divergence, also closed (`R5-2`).** At an odd level the test fixture
duplicated the last node and hashed it with itself, while the specified rule — and
the data layer — promote it unchanged (`implementation-plan.md:2033`, `:2065`). For
`N = 500` the two rules give different roots (measured: `0x33575097…` promoted vs
`0xcb53a6ce…` duplicated on the same leaves), so the 500-leaf Solidity test could not
serve as a cross-language vector. It was a bug in `AVIPRegistry.t.sol`'s `_buildTree`
and nothing else: the contract never duplicated anything, the fixture did. Fixed in
the test helper, with the tensor's own leaves now folding to the data layer's
`TENSOR_ROOT` — which is the assertion that fails if duplication comes back.

**What moved when the convention changed**, so nothing is discovered later: every
root the data layer publishes. Concretely — `root(4)` and the M6 transcript's
`root`/`digest` (`src/reputation/scripts/m6_output.txt`, regenerated), M7c's
`MERKLE_ROOT` and `LINK` and its pinned table (`src/zk/scripts/m7c_output.txt`,
regenerated; `M7cBridgeFixtures.sol` updated), M7d's `commit.merkleRoot` /
`record.merkleRoot` (`m7d_output.txt`, regenerated through `m7d_report.sh`, which
checks M7c in both directions), and one abbreviated root in `m7b_output.txt`. **No
sealed output moved**: the anchor's 38 files are all `verification/baseline_verified/`
Python simulations, `fase0_anchor.sh --check` still exits 0, and nothing was
re-sealed. The two documents that quote M7c's root (`implementation-plan.md`,
`audit-2026-10-20-in-progress.md`) were updated with a dated note.

The fold convention is deployed, so a *further* change after the ceremony-and-redeploy
pair means redeploying again; that is why this had to land before `T1-M3` rather than
after it.

## 8. What is frozen for the ceremony, and what is not

Frozen the moment `P-12` closes — untouched by (a), (b) and (c):

1. the V3 circuit: 94,438 constraints, 128 B compressed (`main.tex:532`, `:555`);
2. its verifying key, i.e. the verifier the ceremony installs;
3. the four public inputs `[statementRoot, epoch, uint160(validator), certifiedNorm]`
   (`AVIPRegistry.verifyThreshold:458-463`);
4. the leaf `Poseidon(validator, norm)` and its slot, `_statementRoots`
   (`:356`, audit `P-16`: never the keccak root);
5. `MAX_NORM = 1 << 64` and the `certifiedNorm < MAX_NORM` domain check (`:443`).

Not frozen, and not part of any ceremony: the keccak fold convention (§7), the
signature of `postCommitment` if a challenge entrypoint or a changed-set field
arrives, and the codec/relay bound on `changedEntries`. The registry already keeps
the two roots in separate slots precisely so that closing freshness cannot move
the statement root — that separation (`P-16`) is what makes this section short.

## 9. Recommendation, and what would change it

1. **(a) is a defect fix and goes now, not as part of the `P-12` decision.** (§7 has
   already landed: it was the other prerequisite, and it was a defect, not an
   option.) (a) makes the address the identity of an entry; §7 makes an inclusion
   proof mean the same thing on both sides of the wire. Neither has an alternative.
2. **Then pick the mechanism, at the start of `T1-M2`.** If the commitment's trust
   anchor is a quorum whose signature the destination already checks, (a) + (c1) is
   enough and (b) is belt-and-braces. If the sequencer is a single key — which is
   what `sequencer` is today (`AVIPRegistry.sol:109`) — then (b) is the only option
   that removes the trust rather than recording it, at 1.63M gas per 102-inclusion
   challenge and one open dependency (`P-18`, the bounty route, which is also
   `T1-M2`). Only (b) *binds* freshness to the committed root; (c1) and (c2) are the
   sequencer's attestations, so a promise of the form "freshness is bound to the
   root" is (b) or it is not that promise.
3. **(c2) is a legitimate fallback** if a challenge window is unacceptable, and it
   is the one option that needs no bounty, no window and no bond: it pays ~67k gas
   every epoch instead.
4. **`P-21` is independent of all of this and belongs in `L2` anyway:** even with
   the delta enforced, `γ` bounds changed entries, not how long an unchanging
   fraudulent leaf survives. Replacing the `[CONJECTURE]` in `main.tex` is gated
   on `P-36` (`T1-M4`), not on this memo.

What would change the recommendation: a measured cost showing that 5.6 Groth16
verifications per challenge is unaffordable on the target chain; or a decision to
make the sequencer's commitment quorum-signed, which moves the trust anchor and
makes (b) redundant.

The ceremony is not blocked by any of this. It is blocked by the *decision* — which
is what `T1-M2` exists for — and by §7, which has landed.

## 10. How to check this memo

The gas figures came from a temporary probe in `integrations/avalanche/test/`,
deleted after the run exactly as the audit's own PoCs were
(`audit-2026-10-20-in-progress.md:880`, `:952`): a test file in that directory is not
in the anchor, so nothing had to be re-sealed, and leaving it behind would have added
a spec the delivery has not decided. To reproduce, the probe is three tests sharing
one `setUp` that builds the 102 (leaf, root, proof) triples over the 500-leaf tensor
with the promote fold:

```
cd integrations/avalanche && forge test --match-path test/<probe>.t.sol -vv
# 102 verifyEntry calls inside one test, timed with gasleft();
# the same loop with the calls removed;
# one call, and three, to check the marginal is linear.
```

For the numbers the contract itself reports, no probe is needed:

```
cd integrations/avalanche
forge test --match-path test/AVIPRegistry.t.sol --gas-report | grep verifyEntry      # max 6,990
forge test --match-path 'test/M4dRealKey.t.sol' --gas-report | grep verifyThreshold  # median 293,293
```

§7 used to need three greps; now it needs the checks that keep it closed:

```
grep -n 'bottom_node' src/datalayer/src/commitment.rs            # the two-hash bottom
grep -n 'root(4)' src/datalayer/fixtures/keccak256_vectors.txt    # the contract's own root
cd integrations/avalanche && forge test --match-path test/DatalayerInclusion.t.sol
cd src/zk && cargo test --offline --test datalayer_inclusion      # the drift guard
bash src/zk/scripts/merkle_fixture.sh                             # regenerate the vector
```

What this memo does not decide: whether (b) or (c2) becomes the mechanism (owner,
at the start of `T1-M2` — see §9), and whether `P-18`'s bounty gets a payment route.
It also does not touch the paper: the freshness paragraph in `main.tex:1006` says the
bound holds, and until an option lands it is a claim about the design, not about the
deployed contract — the contract's own docstring already says so
(`AVIPRegistry.sol:25-30`), and the paper's `[CONJECTURE]` sentence is `P-21`/`L2`.

