# P-12 — binding the freshness bound to something the chain can check

**Status:** analysis only, closes `L1`. No code, no contract change, no re-seal.
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
| `Epoch::changed_entries` | `src/datalayer/src/commitment.rs:205-220` | compares two `BTreeMap<validator, norm>`, counts added, removed and changed |
| `Epoch::freshness_ok` | `src/datalayer/src/commitment.rs:225-232` | applies `<= 50`, or `== 500` at genesis |
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

**Measured, not estimated.** A temporary Foundry probe (deleted after the run;
`integrations/avalanche/test/` is not in the anchor, so nothing was re-sealed)
built a 500-leaf tensor with the registry's own convention and called the deployed
`verifyEntry`:

| Measurement | Gas |
|---|---|
| one inclusion, depth 9 | **10,630** |
| 102 inclusions (51 entries × 2 roots) | **1,227,747** |
| average per inclusion | 12,036 |
| for comparison: `verifyThreshold`, cold path (`main.tex:1294`) | 286,144 |

`1,227,747 / 286,144 = 4.29`: one freshness challenge costs a bit over four full
Groth16 verifications. The measurement includes calldata for every proof (the
calls were external, `bytes32[]` encoded each time) and the base cost of the
contract call, under the project's own build (solc 0.8.33, legacy pipeline, no
`viaIR`); with `viaIR` the same probe reported 5,341 and 686,597, which is why the
number quoted is the one from the project's own settings.

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

## 7. Precondition zero: the two trees do not share a bottom rule

(b) is the option that needs on-chain inclusion to work, and today it would not.
`AVIPRegistry.verifyEntry` starts the fold at `keccak256(abi.encodePacked(leaf))`
(`:410`), while the data layer's `merkle_root` folds `Entry::leaf()` directly
(`commitment.rs:98-112`), and `verify_entry` says in its own comment that it is
"the contract's `verifyEntry`" (`:114-117`). They differ by one hash at the
bottom.

Measured against the repo's own pinned fixture — `keccak256_vectors.txt`, four
entries, `cast keccak`-generated — with the deployed contract:

```
verifyEntry accepts the data layer's root/proof: false
verifyEntry accepts the contract's own tree:      true
contract root for the same four entries: 0x6d7dbeead031ce88ee6f534d9c2fef6063ab9471b1fe3cde38bd0b26555eed36
(while root(4) in the fixture is         0xa708d90e3df263b03d823e688d8780c6d6f378b9a0696647b4ab2129adbeffd8)
```

Both sides are self-consistent; neither test suite can see it, because the Rust
tests compare Rust with Rust (`independent_root`, `src/zk/src/bridge.rs:324-343`,
repeats the missing step) and the Solidity tests compare Solidity with Solidity
(`_buildTree`, `AVIPRegistry.t.sol:1046-1075`). It fails closed, and nothing
on-chain consumes `verifyEntry` today, so no deployment is broken — but any fraud
proof wired in the shape (b) describes would reject every honest proof, and
`commitment.rs`'s claim to be "the parity check that the root M6 posts is
verifiable by the deployed registry" (`:114-116`) is false as written.

There is a second, smaller divergence in the same area: at an odd level the
fixture duplicates the last node and hashes it with itself
(`AVIPRegistry.t.sol:1071-1072`), while the specified rule — and the data layer —
promote it unchanged (`implementation-plan.md:2033`, `:2065`: "ordered pair, odd
node promoted, 500 → 250 → 125 → … so the promoted-node branch is on the path").
For `N = 500` the two rules give different roots (measured: two distinct digests
for the same 500 leaves), so the 500-leaf Solidity test cannot serve as a
cross-language vector.

**Whose rule wins, and why it is not this memo's decision:** the deployed
contract's bottom hash is what decides the shape of a valid proof, so either the
data layer gains `keccak(abi.encodePacked(leaf))` at the bottom, or `verifyEntry`
drops it. Both are reserved-lane changes to the fold convention; neither touches
the admission statement (§8). **The decision must land before `T1-M3`**, because
the fold convention is deployed, and a change after the ceremony-and-redeploy pair
means redeploying again.

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

1. **Do (a) and §7 first, as defect fixes, not as the closure of `P-12`.** They are
   both cheaper than any of the three options and both are prerequisites: (a)
   makes the address the identity of an entry, §7 makes an inclusion proof mean
   the same thing on both sides of the wire. Neither has an alternative.
2. **Then pick the mechanism.** If the commitment's trust anchor is a quorum whose
   signature the destination already checks, (a) + (c1) is enough and (b) is
   belt-and-braces. If the sequencer is a single key — which is what `sequencer` is
   today (`AVIPRegistry.sol:109`) — then (b) is the only option that removes the
   trust rather than recording it, at 1.23M gas per challenge and one open
   dependency (`P-18`).
3. **(c2) is a legitimate fallback** if a challenge window is unacceptable, and it
   is the one option that needs no bounty, no window and no bond: it pays ~67k gas
   every epoch instead.
4. **`P-21` is independent of all of this and belongs in `L2` anyway:** even with
   the delta enforced, `γ` bounds changed entries, not how long an unchanging
   fraudulent leaf survives. Replacing the `[CONJECTURE]` in `main.tex` is gated
   on `P-36` (`T1-M4`), not on this memo.

What would change the recommendation: a measured cost showing that 4.29 Groth16
verifications per challenge is unaffordable on the target chain; or a decision to
make the sequencer's commitment quorum-signed, which moves the trust anchor and
makes (b) redundant.

The ceremony is not blocked by any of this. It is blocked by the *decision* — which
is what `T1-M2` exists for — and by §7 landing before `T1-M3`.

## 10. How to check this memo

The gas figures came from a temporary probe in
`integrations/avalanche/test/`, deleted after the run exactly as the audit's own
PoCs were (`audit-2026-10-20-in-progress.md:880`, `:952`): a test file in that
directory is not in the anchor, so nothing had to be re-sealed, and leaving it
behind would have added a spec the delivery has not decided. To reproduce:

```
cd integrations/avalanche && forge test --match-contract <probe> -vv
# probe: 500 leaves, bottom = keccak(leaf), pairs sorted, odd node promoted;
# one inclusion of depth 9, then 102 of them (51 entries x 2 roots).
```

The divergence in §7 needs no probe; it is two greps and one fixture line:

```
grep -n 'keccak256(abi.encodePacked(leaf))' integrations/avalanche/contracts/AVIPRegistry.sol
sed -n '96,127p' src/datalayer/src/commitment.rs
grep -n 'root(4)' src/datalayer/fixtures/keccak256_vectors.txt
```

What this memo does not decide: which bottom rule wins (§7), whether (b) or (c2)
becomes the mechanism, and whether `P-18`'s bounty gets a payment route. It also
does not touch the paper: the freshness paragraph in `main.tex:1006` says the
bound holds, and until an option lands it is a claim about the design, not about
the deployed contract — the contract's own docstring already says so
(`AVIPRegistry.sol:25-30`), and the paper's `[CONJECTURE]` sentence is `P-21`/`L2`.

