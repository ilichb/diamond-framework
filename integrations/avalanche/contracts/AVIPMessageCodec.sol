// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title AVIPMessageCodec
/// @notice The wire format of the three AVIP message types of
///         `docs/architecture/avalanche-integration.md` §4, in one place.
///
/// @dev Milestone M7d of `docs/architecture/implementation-plan.md` §5.11 (gap
///      A9). The three types are the ones the architecture names:
///
///        1. **commitment propagation** — a new reputation commitment on a source
///           chain is announced to every subscribed subnet;
///        2. **collusion alert** — the RMT test flagged a clique or a bipartite
///           structure, so the flagged validators' effective voting weight is to
///           be reduced;
///        3. **slashing notification** — a fraud proof succeeded, so the slashed
///           validator's subnet is told.
///
///      **The envelope exists because AWM gives the receiver no nonce.** A
///      Teleporter message is handed to a receiver as
///      `receiveTeleporterMessage(sourceChain, originSender, payload)` — see
///      `./interfaces/ITeleporterReceiver.sol` — with the protocol's
///      `messageNonce` stripped from the payload. A receiver therefore cannot
///      deduplicate anything by protocol means, and a solver may re-deliver a
///      message whose execution failed. Every AVIP message is consequently
///      `abi.encode(kind, nonce, payload)`, with a sender-chosen, per-destination
///      monotone `nonce`, and the receiver refuses a nonce it has already
///      delivered (§5.11).
///
///      **What is carried and what is not.** The payloads carry the values a peer
///      can act on and can *recompute*; a number the destination cannot check is
///      carried only as a digest:
///
///        - the commitment's `merkleRoot`, `changedEntries`, `statementRoot` and
///          `link` are exact, and the link is recomputed at both ends (M7c
///          §5.10 decided that the statement's `root` and the registry's Merkle
///          root are tied *off-chain and recomputably* — so an AVIP peer holding
///          the tensor recomputes the same tie, and one holding only the two
///          roots learns nothing new from the message);
///        - the alert's two statistics travel as the flags that were decided
///          (`rightAlert`, `leftAlert`) plus the calibration they were decided
///          against, scaled to 4 decimals — the same four decimals
///          `src/rmt/scripts/m5_output.txt` prints — and the *graph* travels as
///          `graphDigest`, because a graph is not a wire type and M5's
///          `Detection` holds `f64`s;
///        - the slashing notification carries the fraud proof's own numbers
///          (`publishedWad`, `formulaWad`, M7b's §5.9 `Verdict::Fraud`) and the
///          digest of the ingestion instance they were judged under, so the
///          destination can record *which* `f_c` was in force. The `reason` the
///          manager receives is **not** carried: it is derived from the
///          envelope's `(sourceChain, nonce)`, so a sender cannot choose it
///          (§5.11).
///
///      **Fail-closed at both ends.** `encode` refuses to build a message whose
///      payload is empty where the protocol has no meaning for it (a zero root, a
///      zero validator, an alert that flags nothing, a "fraud"
///      whose two values agree); every decoder re-checks the same predicates. The
///      sender's copy is a courtesy — it fails fast, next to the mistake — and the
///      receiver's copy is the boundary, because a message can be hand-built or
///      come from another version of this codec.
library AVIPMessageCodec {
    // ------------------------------------------------------------- the kinds

    /// @notice A new reputation commitment: type 1 of §4.
    uint8 internal constant KIND_COMMITMENT_PROPAGATION = 1;

    /// @notice A collusion alert: type 2 of §4.
    uint8 internal constant KIND_COLLUSION_ALERT = 2;

    /// @notice A slashing notification: type 3 of §4.
    uint8 internal constant KIND_SLASHING_NOTIFICATION = 3;

    /// @notice The highest kind `decodeEnvelope` accepts, used by the membership
    ///         check.
    uint8 internal constant KIND_MAX = 3;

    /// @notice Scale of the alert's calibration thresholds: 4 decimals, the
    ///         precision `src/rmt/scripts/m5_output.txt` prints (`q99 = 9.0542`
    ///         becomes `90542`).
    uint32 internal constant THRESHOLD_SCALE = 1e4;

    // ----------------------------------------------------------- the payloads

    /// @notice Type 1: a commitment, in both of its readings, plus M7c's link.
    /// @param epoch The epoch index the commitment belongs to (0-based, M1).
    /// @param merkleRoot `AVIPRegistry.commitmentOf(epoch)`, M1's fold.
    /// @param changedEntries The delta the sequencer declared when it posted,
    ///        which is what M1's freshness rule is checked against.
    /// @param statementRoot The `root` the Groth16 statement carries for the same
    ///        tensor (V3: the Poseidon commitment), as `uint256`.
    /// @param link M7c's tie: `linkDigest(merkleRoot, statementRoot, epoch)`.
    struct CommitmentPropagation {
        uint256 epoch;
        bytes32 merkleRoot;
        uint32 changedEntries;
        uint256 statementRoot;
        bytes32 link;
    }

    /// @notice Type 2: the RMT detector's verdict, enough to re-run the check.
    /// @param epoch The epoch whose graph was tested.
    /// @param nodeCount `Detection.n`: the graph's node count.
    /// @param rightThresholdQ The right tail's `q99`, 4-decimal scaled (`90542`).
    /// @param leftThresholdQ The left tail's `q99`, 4-decimal scaled (`91371`).
    /// @param graphDigest The digest of the graph the test ran on. M5 draws the
    ///        graph from the tensor's digest, so this is the M4 fixture's tensor
    ///        digest (`0xc2309377…`) and the message says *which* graph was
    ///        flagged without claiming the graph is recoverable from it.
    /// @param rightAlert `λ_max(B) > q99` fired (a dense subgraph).
    /// @param leftAlert `−λ_min(B) > q99` fired (bipartite polarization).
    struct CollusionAlert {
        uint256 epoch;
        uint32 nodeCount;
        uint32 rightThresholdQ;
        uint32 leftThresholdQ;
        bytes32 graphDigest;
        bool rightAlert;
        bool leftAlert;
    }

    /// @notice Type 3: a fraud proof's outcome, as an instruction to slash.
    /// @param validator The validator the data layer found at fault.
    /// @param epoch The epoch the fraud proof adjudicated.
    /// @param ingestionDigest The digest of the `f_c` instance in force when the
    ///        proof was decided (M7b §5.9's `Ingestion::parameters_digest`), so the
    ///        slashed subnet records *which* formula was applied.
    /// @param publishedWad The value the sequencer published (M7b's
    ///        `Verdict::Fraud::published_wad`).
    /// @param formulaWad What `f_c(events)` says (M7b's `formula_wad`). A fraud
    ///        proof is exactly `publishedWad != formulaWad`; both ends reject a
    ///        notification where they agree.
    ///
    /// @dev **No amount travels** (§12.1.2, M9b). M7b's equilibrium names
    ///      `S_slash = 10` as a *model* parameter and M2 originally carried that
    ///      decision as a `uint256 amountWad`; the manager now takes the whole stake
    ///      on record, so the number leaves the wire instead of crossing it. What
    ///      crosses is the proof's outcome — the transported amount was a second
    ///      source of truth for something the destination already knew, and M2's
    ///      `SlashExceedsStake` existed only to reconcile the two.
    struct SlashingNotification {
        address validator;
        uint256 epoch;
        bytes32 ingestionDigest;
        uint256 publishedWad;
        uint256 formulaWad;
    }

    // ---------------------------------------------------------------- errors

    /// @notice `kind` is not one of the three §4 types.
    error UnknownMessageKind(uint8 kind);

    /// @notice The message is empty, so it carries no envelope at all.
    error EmptyMessage();

    /// @notice The message is not the canonical encoding of what it decodes to:
    ///         `abi.decode` would accept it (or a prefix of it), the envelope
    ///         check does not, because two encodings of one message are one
    ///         message too many for a replay guard keyed on the envelope.
    error NonCanonicalMessage();

    /// @notice A payload that must not be empty is.
    error EmptyPayload();

    /// @notice A commitment with no Merkle root announces nothing.
    error EmptyMerkleRoot();

    /// @notice A commitment whose `link` is not the link its own words compute.
    error LinkMismatch(bytes32 expected, bytes32 got);

    /// @notice An alert with no graph to point at.
    error EmptyGraphDigest();

    /// @notice An alert whose two tails are both quiet: §4's alert exists because
    ///         a test *flagged* something, so a quiet verdict is not an alert.
    error QuietAlert();

    /// @notice A slashing notification for the zero address.
    error EmptyValidator();

    /// @notice A slashing notification naming no ingestion instance.
    error EmptyIngestionDigest();

    /// @notice A "fraud proof" whose published value *is* the formula's: M7b's
    ///         `adjudicate` returns `Consistent` for that, never `Fraud`.
    error NotAFraudProof(uint256 publishedWad, uint256 formulaWad);

    // ------------------------------------------------------------------ the tie

    /// @notice `keccak256(abi.encode(merkleRoot, statementRoot, epoch))`: the
    ///         digest M7c computes as `bridge::link_digest`.
    /// @dev Three 32-byte words, so the encoding is unambiguous — the property
    ///      `abi.encodePacked` does not have in general and *does* have for three
    ///      fixed-width words. `src/zk/src/bridge.rs` writes the same 96 bytes by
    ///      hand (the epoch right-aligned in a word), and
    ///      `../test/M7dTransport.t.sol` checks this function against M7c's
    ///      committed link rather than against a second description of it.
    /// @param merkleRoot M1's root over the tensor.
    /// @param statementRoot The statement's `root`.
    /// @param epoch The epoch the two roots describe.
    function linkDigest(bytes32 merkleRoot, uint256 statementRoot, uint256 epoch)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(merkleRoot, statementRoot, epoch));
    }

    /// @notice The machine-readable reason a slashed subnet records, derived from
    ///         the envelope instead of carried in it.
    /// @dev `keccak256(abi.encodePacked(sourceBlockchainId, nonce))`: two 32-byte
    ///      words, so packing is unambiguous here as well. This is the `bytes32
    ///      reason` of `IAVIPValidatorManager.slash`, and it is §5.11's whole point
    ///      for type 3: the value M8 will audit is a *provenance id* the transport
    ///      cannot forge, because no sender chooses it — it is a function of which
    ///      chain sent the message and which nonce it was.
    /// @param sourceBlockchainId The chain the notification came from.
    /// @param nonce The envelope's nonce.
    function provenanceId(bytes32 sourceBlockchainId, uint256 nonce)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(sourceBlockchainId, nonce));
    }

    // ------------------------------------------------------------------ envelope

    /// @notice Wraps a payload with its discriminant and nonce.
    /// @param kind One of the three `KIND_*` constants.
    /// @param nonce The sender's per-destination nonce.
    /// @param payload One of the three payload encodings above.
    function encode(uint8 kind, uint256 nonce, bytes memory payload)
        internal
        pure
        returns (bytes memory)
    {
        if (kind == 0 || kind > KIND_MAX) revert UnknownMessageKind(kind);
        if (payload.length == 0) revert EmptyPayload();
        return abi.encode(kind, nonce, payload);
    }

    /// @notice Unwraps a message, refusing anything that is not a canonical
    ///         envelope of a known kind.
    /// @dev `abi.decode` reverts on a short blob and silently tolerates some
    ///      longer ones; the re-encode comparison removes that slack. It costs one
    ///      `keccak256` and buys the invariant the nonce guard needs: the bytes
    ///      are exactly the encoding of `(kind, nonce, payload)`.
    function decodeEnvelope(bytes memory message)
        internal
        pure
        returns (uint8 kind, uint256 nonce, bytes memory payload)
    {
        if (message.length == 0) revert EmptyMessage();
        (kind, nonce, payload) = abi.decode(message, (uint8, uint256, bytes));
        if (kind == 0 || kind > KIND_MAX) revert UnknownMessageKind(kind);
        if (payload.length == 0) revert EmptyPayload();
        if (keccak256(message) != keccak256(abi.encode(kind, nonce, payload))) {
            revert NonCanonicalMessage();
        }
    }

    // ------------------------------------------------------- type 1: encode/decode

    /// @notice Encodes a type-1 payload, refusing one that announces nothing.
    /// @dev The link is checked here as well as on the receive side: a sender that
    ///      built the tie from the wrong words would otherwise spend a cross-chain
    ///      message to be told so.
    function encodeCommitment(CommitmentPropagation memory commitment)
        internal
        pure
        returns (bytes memory)
    {
        if (commitment.merkleRoot == bytes32(0)) revert EmptyMerkleRoot();
        bytes32 expected =
            linkDigest(commitment.merkleRoot, commitment.statementRoot, commitment.epoch);
        if (commitment.link != expected) revert LinkMismatch(expected, commitment.link);
        return abi.encode(commitment);
    }

    /// @notice Decodes a type-1 payload, re-checking what `encodeCommitment`
    ///         refuses.
    function decodeCommitment(bytes memory payload)
        internal
        pure
        returns (CommitmentPropagation memory commitment)
    {
        commitment = abi.decode(payload, (CommitmentPropagation));
        if (commitment.merkleRoot == bytes32(0)) revert EmptyMerkleRoot();
        bytes32 expected =
            linkDigest(commitment.merkleRoot, commitment.statementRoot, commitment.epoch);
        if (commitment.link != expected) revert LinkMismatch(expected, commitment.link);
    }

    // ------------------------------------------------------- type 2: encode/decode

    /// @notice Encodes a type-2 payload, refusing an alert that flags nothing.
    function encodeAlert(CollusionAlert memory alert) internal pure returns (bytes memory) {
        if (alert.graphDigest == bytes32(0)) revert EmptyGraphDigest();
        if (!alert.rightAlert && !alert.leftAlert) revert QuietAlert();
        return abi.encode(alert);
    }

    /// @notice Decodes a type-2 payload, re-checking what `encodeAlert` refuses.
    function decodeAlert(bytes memory payload) internal pure returns (CollusionAlert memory alert) {
        alert = abi.decode(payload, (CollusionAlert));
        if (alert.graphDigest == bytes32(0)) revert EmptyGraphDigest();
        if (!alert.rightAlert && !alert.leftAlert) revert QuietAlert();
    }

    // ------------------------------------------------------- type 3: encode/decode

    /// @notice Encodes a type-3 payload, refusing an instruction that slashes
    ///         nothing or names no fault.
    function encodeSlashing(SlashingNotification memory notification)
        internal
        pure
        returns (bytes memory)
    {
        _checkSlashing(notification);
        return abi.encode(notification);
    }

    /// @notice Decodes a type-3 payload, re-checking what `encodeSlashing`
    ///         refuses.
    function decodeSlashing(bytes memory payload)
        internal
        pure
        returns (SlashingNotification memory notification)
    {
        notification = abi.decode(payload, (SlashingNotification));
        _checkSlashing(notification);
    }

    /// @dev The three predicates of a well-formed slashing notification, shared by
    ///      both ends so that they cannot drift apart. The last one is M7b's
    ///      semantics rather than a formatting rule: `adjudicate` returns
    ///      `Verdict::Fraud` exactly when the published value is not `f_c(events)`
    ///      (`src/datalayer/src/ingestion.rs`, §5.9), so a message where the two
    ///      agree is a slashing instruction with no proof behind it. M2's fourth
    ///      predicate — a non-zero amount — went with the field (§12.1.2, M9b): the
    ///      manager derives the amount from the record it is about to take and
    ///      refuses an empty one itself (`NothingToSlash`).
    function _checkSlashing(SlashingNotification memory notification) private pure {
        if (notification.validator == address(0)) revert EmptyValidator();
        if (notification.ingestionDigest == bytes32(0)) revert EmptyIngestionDigest();
        if (notification.publishedWad == notification.formulaWad) {
            revert NotAFraudProof(notification.publishedWad, notification.formulaWad);
        }
    }
}
