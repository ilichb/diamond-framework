// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// GENERATED FILE - do not edit by hand.
//
// Produced by `src/zk/scripts/m4d_fixture.sh`, which runs
// `cargo run --release --bin m4d-fixture` and then `forge fmt`. Regenerate with
//     src/zk/scripts/m4d_fixture.sh
//
// WHAT THIS IS
// ------------
// A Groth16/BN254 verification key over the **admission** circuit (audit
// 2026-10-20, P-01 and P-16), and a real inclusion proof for one validator of
// the deterministic 500-entry fixture. The statement is
//
//     [statementRoot, epoch, validator, certifiedNorm]
//
// and the witness is the validator's Merkle path and leaf index. The circuit
// constrains `validator` and `norm` inside the leaf, so this proof admits that
// one validator and no other: the replay that P-01 describes now changes a
// public input and fails.
//
// WHAT IT IS NOT
// --------------
// A *development* setup: one phase-2 contributor, with the transcript seeded, so
// anyone can derive the toxic waste and forge freely. It carries no security
// claim; the ceremony that would carries one stays out of scope.
//
// `statementRoot` is the Poseidon Merkle root of the admission tree. It is stored
// in its own per-epoch slot, separate from the keccak root `verifyEntry` uses
// (P-16), and `AVIPRegistry` binds it to the epoch in the same post.

import {Groth16Verifier} from "../../contracts/verifiers/Groth16Verifier.sol";

library M4dGroth16Fixtures {
    /// @notice The committed fixture (5.5.6): 500 entries, `keccak256` of their
    ///         8-byte little-endian words -- the anchor `m4a_output.txt` pins.
    bytes32 internal constant TENSOR_DIGEST =
        0xc2309377a00b109a6c44d83a5cc759108977ffe207fba6f83215a9cdf77d9aa9;
    /// @notice The Phase-2 transcript: 32 ASCII bytes, both committed, so this
    ///         file is reproducible and the toxic waste is public.
    string internal constant SETUP_SEED = "AVIP-M4d-dev-setup-1-admission!!";
    /// @notice The proving randomness, committed so the proof is a pinned
    ///         artifact rather than a load-dependent observation.
    string internal constant PROOF_SEED = "AVIP-M4d-dev-proof-1-admission!!";

    /// @notice The statement, in `AVIPRegistry.verifyThreshold`'s order.
    uint256 internal constant STATEMENT_ROOT =
        6105938163859590773966593243891138936289191320889329618475491144456189011390;
    /// @notice The epoch the statement belongs to.
    uint256 internal constant STATEMENT_EPOCH = 0;
    /// @notice The address the committed proof admits (`fixture::ADMISSION_INDEX`).
    uint256 internal constant STATEMENT_VALIDATOR =
        435886155672405361841334550125050854938346586543;
    /// @notice That validator's committed norm in WAD.
    uint256 internal constant STATEMENT_NORM = 665564939881284858;

    /// @notice A second admitted validator, for tests that need two records.
    uint256 internal constant STATEMENT_VALIDATOR_OTHER =
        667491683938233972620704977950824617602315973375;
    /// @notice The second validator's committed norm in WAD.
    uint256 internal constant STATEMENT_NORM_OTHER = 910706342274755635;

    /// @notice `keccak256(abi.encode(vk))`, which `verifyingKeyDigest()`
    ///         publishes. Computed off-chain from the ABI layout, so
    ///         `test/M4dRealKey.t.sol` compares two implementations of it.
    bytes32 internal constant KEY_DIGEST =
        0x018ce1b832c244ea2697e03f964c5f7e393bd88e2624ad6cd72de5a9dd3a319d;

    /// @notice The real admission key: 4 public inputs, `ic.length == 5`.
    /// @dev G2 coordinates are in the natural `Fp2` order `(c0, c1)`; the
    ///      contract reorders them for EIP-197.
    function verifyingKey() internal pure returns (Groth16Verifier.VerifyingKey memory vk) {
        vk.alpha1 = [
            uint256(8811204903348573500590535980995231585235783795000320847546740806405859585044),
            uint256(6987061142452488210372456693358729712671668513580899688207348247176766395899)
        ];
        vk.beta2 = [
            [
                uint256(
                    16970398905263726155192916746437489427614653224595930354532042884013462318092
                ),
                uint256(
                    21590261884874803826723462953790877301521945855823270386729207953846365483939
                )
            ],
            [
                uint256(
                    6444415701660394728988427343749843556505328110662071028698585602851720159176
                ),
                uint256(
                    1813193367936942942017419777433546424472479862560210290524385196648961103201
                )
            ]
        ];
        vk.gamma2 = [
            [
                uint256(
                    16951551961342826126902091955982779637116279598942100827740530839834194145880
                ),
                uint256(
                    17622100592096284328682407586597339640819420820008709050940722243033145369225
                )
            ],
            [
                uint256(
                    20613711781531928999122937891835308179516954963654871616816275223546882204381
                ),
                uint256(
                    9488580365702824372730314750038152969384140138185682764399083645181274462366
                )
            ]
        ];
        vk.delta2 = [
            [
                uint256(
                    10841826990842110904089575675770084674268123116186587146466766839773615224978
                ),
                uint256(
                    13548515562028738665415720533326331985556424765889872063419426945664330512271
                )
            ],
            [
                uint256(
                    2606802494701884548460416092268754965953181830332466218417055203567251548897
                ),
                uint256(
                    18246211359295443153735155691876182292744658464406786912879252330879978596557
                )
            ]
        ];
        vk.ic = new uint256[2][](5);
        vk.ic[0] = [
            uint256(9956992513936237998107703048582234142003953693287534119743278491327083182181),
            uint256(6722974240679333425764023505966524047436624744342848637058135435930529733153)
        ];
        vk.ic[1] = [
            uint256(505791256006902892118038915972197438745488633281335348886044189660831903831),
            uint256(3476692125010437929040529099814469085637417969205680917509282548463612417088)
        ];
        vk.ic[2] = [
            uint256(5741143405693520617978959732265622392851494270341750743770062032801216386794),
            uint256(203448582770970162415477917990152653757857579271220299397218271330572748735)
        ];
        vk.ic[3] = [
            uint256(4544621595589714365108476317980986512290140328437302682929535335871707706972),
            uint256(13522814831644098846316733802102338963075975239499641859842419387489760121342)
        ];
        vk.ic[4] = [
            uint256(4681125800181623594484804766212491199847296198651689969304092600687585490713),
            uint256(20910305306744833144234500775683769384337748738266157052906904286084782309762)
        ];
    }

    /// @notice `[root, epoch, validator, certifiedNorm]`, the statement the
    ///         registry builds.
    function statement() internal pure returns (uint256[] memory inputs) {
        inputs = new uint256[](4);
        inputs[0] = STATEMENT_ROOT;
        inputs[1] = STATEMENT_EPOCH;
        inputs[2] = STATEMENT_VALIDATOR;
        inputs[3] = STATEMENT_NORM;
    }

    /// @notice The proof's `A`.
    function proofA() internal pure returns (uint256[2] memory) {
        return [
            uint256(15591895325026739434754578479949681215301871203108803941473262314156467622460),
            uint256(3510871735692401034176627632888498084462233345941184774218704574271546539156)
        ];
    }

    /// @notice The proof's `B`.
    function proofB() internal pure returns (uint256[2][2] memory) {
        return [
            [
                uint256(
                    18745910410188891585339755465438362760513143588984073687321555291351093810316
                ),
                uint256(
                    8972471370755232256955694672358511759116840905975782995374326726038322004624
                )
            ],
            [
                uint256(
                    2862963245152312492321211943837864980036435287563548944465331354471507648092
                ),
                uint256(
                    10459034387797355773005834190522956114627282112888112675952315275157662028721
                )
            ]
        ];
    }

    /// @notice The proof's `C`.
    function proofC() internal pure returns (uint256[2] memory) {
        return [
            uint256(10469973577864870023895160114736707202155614763643749856714326463576492184677),
            uint256(16542763204745574710875388833480154506244364246274798733148808790043828960788)
        ];
    }

    /// @notice `abi.encode(a, b, c)`: the 256-byte blob `Bn254.decodeProof`
    ///         reads and `AVIPRegistry.verifyThreshold` takes.
    function proof() internal pure returns (bytes memory) {
        return abi.encode(proofA(), proofB(), proofC());
    }

    /// @notice The same, for `STATEMENT_VALIDATOR_OTHER`.
    function proofOther() internal pure returns (bytes memory) {
        return abi.encode(proofOtherA(), proofOtherB(), proofOtherC());
    }

    function proofOtherA() internal pure returns (uint256[2] memory) {
        return [
            uint256(15541685136950838828063889039686368516594625664239789054728354675428780159112),
            uint256(15451753073831818427150386955553386120105508442124762422453602047886573612449)
        ];
    }

    function proofOtherB() internal pure returns (uint256[2][2] memory) {
        return [
            [
                uint256(
                    5034748913004034052071473172556906945877338059528707142007663046935735259365
                ),
                uint256(
                    7547134734403483406844219332793097689681054556698878808970108904560457686789
                )
            ],
            [
                uint256(
                    3297440200609931660553185558206820769382396223546591110668960547001807183341
                ),
                uint256(
                    20714729120637040345786478867219489433195787765522553186959649266548541850264
                )
            ]
        ];
    }

    function proofOtherC() internal pure returns (uint256[2] memory) {
        return [
            uint256(14496985435498624273542560611027502068739560022656834142632328628709896137300),
            uint256(2858248306861858005182820917139340024400590417847336502659830274468314502492)
        ];
    }
}
