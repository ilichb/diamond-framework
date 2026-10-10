// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// GENERATED FILE - do not edit by hand.
//
// Produced by `src/zk/scripts/m4b_fixture.sh`, which runs
// `cargo run --release --bin m4b-fixture` and then `forge fmt`. Regenerate with
//     src/zk/scripts/m4b_fixture.sh
//
// WHAT THIS IS
// ------------
// The real thing M3 waited for: a Groth16/BN254 verification key over the V3
// circuit of `docs/architecture/implementation-plan.md` 5.5.2 (Poseidon
// commitment + floor norm), and a real proof for the deterministic 500-entry
// fixture of 5.5.6. `test/M4bRealKey.t.sol` installs the key in the frozen
// `Groth16Verifier` and feeds the proof to `AVIPRegistry.verifyThreshold`, which
// builds the statement `[root, epoch, certifiedNorm]` from its own state -- no
// Solidity change anywhere.
//
// WHAT IT IS NOT
// --------------
// A *development* setup: one phase-2 contributor, with the transcript seeded, so
// anyone can derive the toxic waste and forge freely. It carries no security
// claim; the ceremony that would carries one stays out of M4's scope (5.5.4,
// 11). What it demonstrates is that the pipeline works end to end, and it makes
// the cost of that pipeline measurable.
//
// The statement's `root` is the Poseidon commitment of the fixture tensor, not a
// Merkle root: tying it to the registry's `keccak256` root is the Pedersen/
// Merkle bridge, gap A7, milestone M7 (5.5.7).

import {Groth16Verifier} from "../../contracts/verifiers/Groth16Verifier.sol";

library M4bGroth16Fixtures {
    /// @notice The committed fixture (5.5.6): 500 entries, `keccak256` of their
    ///         8-byte little-endian words -- the anchor `m4a_output.txt` pins.
    bytes32 internal constant TENSOR_DIGEST =
        0xc2309377a00b109a6c44d83a5cc759108977ffe207fba6f83215a9cdf77d9aa9;
    /// @notice The Phase-2 transcript: 32 ASCII bytes, both committed, so this
    ///         file is reproducible and the toxic waste is public.
    string internal constant SETUP_SEED = "AVIP-M4b-dev-setup-1-contributor";
    /// @notice The proving randomness, committed so the proof is a pinned
    ///         artifact rather than a load-dependent observation.
    string internal constant PROOF_SEED = "AVIP-M4b-dev-proof-1-contributor";

    /// @notice The statement, in `AVIPRegistry.verifyThreshold`'s order.
    uint256 internal constant STATEMENT_ROOT =
        14881564148789680950073164612164838307833922018127128489011700125541095929892;
    /// @notice The epoch the statement belongs to.
    uint256 internal constant STATEMENT_EPOCH = 0;
    /// @notice `certifiedNorm = floor(sqrt(sum T_i^2))` in WAD (5.5.1).
    uint256 internal constant STATEMENT_NORM = 12793810215743475835;

    /// @notice `keccak256(abi.encode(vk))`, which `verifyingKeyDigest()`
    ///         publishes. Computed off-chain from the ABI layout, so
    ///         `test/M4bRealKey.t.sol` compares two implementations of it.
    bytes32 internal constant KEY_DIGEST =
        0x979e49afea11966c7fee9f8a2735686e52a37b0f771e11670b5703789ca98098;

    /// @notice The real key over V3: 3 public inputs, `ic.length == 4`.
    /// @dev G2 coordinates are in the natural `Fp2` order `(c0, c1)`; the
    ///      contract reorders them for EIP-197.
    function verifyingKey() internal pure returns (Groth16Verifier.VerifyingKey memory vk) {
        vk.alpha1 = [
            uint256(3560892886901676219246517730618754812323206632862387657189723283349606935402),
            uint256(1874407417580866640600310737395255713355774746889983418872247804924444711982)
        ];
        vk.beta2 = [
            [
                uint256(
                    180521856055556556565946217783798665934986777114341761958467537675720198362
                ),
                uint256(
                    21441565092071256442589279347241366865298172515885630172613413232843542295572
                )
            ],
            [
                uint256(
                    10572665849245704681425390781141154543418147077292130571685187762799467190379
                ),
                uint256(
                    20650743161933022589077203620549454894262637189885716239304283008516306745955
                )
            ]
        ];
        vk.gamma2 = [
            [
                uint256(
                    7623293401537199845543440468833808931535161257486736584561985800767711940211
                ),
                uint256(
                    16379568658183954708075909824989282797385174958055122556470031032373216605436
                )
            ],
            [
                uint256(
                    11919852460329673343006587844145792852203662524710106796696493931076560819640
                ),
                uint256(
                    1730473060007056592539080821251105197369227926939256105042873715854733593598
                )
            ]
        ];
        vk.delta2 = [
            [
                uint256(
                    20001940254414788305826928086924043198478371259326718903933642885947290036499
                ),
                uint256(
                    3343567813963363388614464972943954724262179333914921205845520457168360640501
                )
            ],
            [
                uint256(
                    6473870983062368148155296435085456000539783485539737561884121258563466311871
                ),
                uint256(
                    2490099085528341920272109625194388685788948614293499027061309939068998821335
                )
            ]
        ];
        vk.ic = new uint256[2][](4);
        vk.ic[0] = [
            uint256(3672898896614367989413987005825685255127218290317844019185642748509742998971),
            uint256(20830184524088180934577948268000209412556335834518437110781827821959788110800)
        ];
        vk.ic[1] = [
            uint256(21432387449927166955105641388992220903375137818349533660070376648900689375286),
            uint256(2667442947632628565473215155222199419785150212615372968254508573896496824511)
        ];
        vk.ic[2] = [
            uint256(14482475652516971741105821803851629120176388819607677243953569291334141967780),
            uint256(17119135190560479323512632138115996420101914152813293716642973367044597542864)
        ];
        vk.ic[3] = [
            uint256(14656767459633687013584288988284377835009811905252328218371801420784224342599),
            uint256(15722547362963551279118752153390861186814987206406302988553914024870877541748)
        ];
    }

    /// @notice `[root, epoch, certifiedNorm]`, the statement the registry builds.
    function statement() internal pure returns (uint256[] memory inputs) {
        inputs = new uint256[](3);
        inputs[0] = STATEMENT_ROOT;
        inputs[1] = STATEMENT_EPOCH;
        inputs[2] = STATEMENT_NORM;
    }

    /// @notice The proof's `A`.
    function proofA() internal pure returns (uint256[2] memory) {
        return [
            uint256(5025328732119438391763506758236482333977937608898291599127215641286948478130),
            uint256(4380009849921545872882593900779086186071012930681340180069504807405606508295)
        ];
    }

    /// @notice The proof's `B`.
    function proofB() internal pure returns (uint256[2][2] memory) {
        return [
            [
                uint256(
                    18484146522102287137940455006319443922494093955320164933110763446867938241564
                ),
                uint256(
                    8781312522120342935326399162698218947649017752147979868688440802682961725788
                )
            ],
            [
                uint256(
                    3199885022137693416559656289405317376618428122580517261339531413358169754323
                ),
                uint256(
                    13469988453770363162074857989571775898618965270641866669375294511322678384122
                )
            ]
        ];
    }

    /// @notice The proof's `C`.
    function proofC() internal pure returns (uint256[2] memory) {
        return [
            uint256(5850718816959016419238006353502819038604293130395546474367229668811139798076),
            uint256(667375712611654844074557918796080709261358344089671991228924293829122753500)
        ];
    }

    /// @notice `abi.encode(a, b, c)`: the 256-byte blob `Bn254.decodeProof`
    ///         reads and `AVIPRegistry.verifyThreshold` takes.
    function proof() internal pure returns (bytes memory) {
        return abi.encode(proofA(), proofB(), proofC());
    }
}
