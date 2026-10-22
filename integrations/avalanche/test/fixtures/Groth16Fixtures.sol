// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// GENERATED FILE - do not edit by hand.
//
// Produced by `scripts/generate_groth16_fixtures.py`; regenerate with
//     python3 scripts/generate_groth16_fixtures.py && forge fmt
// See that script for what these numbers are, and are not: there is no circuit
// and no trusted setup behind this key, so it certifies nothing. It is a real
// BN254 instance (on-curve points, canonical coordinates, accepted by the
// pairing precompile) built so that the Groth16 equation of `Groth16Verifier`
// holds for the proof and statement shipped with it.

import {Groth16Verifier} from "../../contracts/verifiers/Groth16Verifier.sol";

library Groth16Fixtures {
    /// @notice `keccak256("tensor")`, the registry's epoch-0 root.
    uint256 internal constant STATEMENT_ROOT =
        86442290903294350648273222779976636221758675587005340531248271500348333491074;
    /// @notice Epoch the statement belongs to.
    uint256 internal constant STATEMENT_EPOCH = 0;
    /// @notice `address(0xA11CE)`: the validator the statement admits.
    uint256 internal constant STATEMENT_VALIDATOR = 659918;
    /// @notice `Theta_r = 0.5e18` (0.5 in WAD).
    uint256 internal constant STATEMENT_NORM = 500000000000000000;

    /// @notice The installed key: 4 public inputs, so `ic.length == 5`.
    function verifyingKey() internal pure returns (Groth16Verifier.VerifyingKey memory vk) {
        vk.alpha1 = [
            uint256(16417170671487590121473862373570533031806101446564967195958767047075526777038),
            uint256(21171900648705018833427018038442250867895147283726175791763172305494283380727)
        ];
        vk.beta2 = [
            [
                uint256(
                    12324186159126983368358431820116314694404415679551005720932421821365890960030
                ),
                uint256(
                    16816743731016557881635543433252396313395996314283136442148403547173598871295
                )
            ],
            [
                uint256(
                    9523204953839579794797345618842478585907765193217539414189933309338249527841
                ),
                uint256(
                    3896743186412004664050604033376477601055756307033045846966173036224065037820
                )
            ]
        ];
        vk.gamma2 = [
            [
                uint256(
                    4268320131101711157368757495350926838857943423500082432364866673110082887720
                ),
                uint256(
                    13504969738087700070752527591603314409296514065165588512114663046413111479945
                )
            ],
            [
                uint256(
                    7266882671303735445524208891579592269051262177839410264211483329622671689848
                ),
                uint256(
                    16157272935168151464374230892544828772604113166449960070756111344490559677672
                )
            ]
        ];
        vk.delta2 = [
            [
                uint256(
                    21329656335137687015811901382940365267906982197909450226129710009706537404413
                ),
                uint256(
                    19993752682342220273180382454007839514526152585402246113525838253689953606489
                )
            ],
            [
                uint256(
                    15134581942543494034799651414834572324851049061160623157418895632562220970682
                ),
                uint256(
                    7002475360456220334083761433779356664417052385524186736285646494389448518585
                )
            ]
        ];
        vk.ic = new uint256[2][](5);
        vk.ic[0] = [
            uint256(15426086151966752780237975064210402928461939467965378936949161256041495377669),
            uint256(18357050465378466634175768375539539401699171822196778334465741296833759129712)
        ];
        vk.ic[1] = [
            uint256(15744452102360418788513408538710702188436669952777966559766525270262285528363),
            uint256(14346468726037142199994132695674699389803935192551372383838421251777432687737)
        ];
        vk.ic[2] = [
            uint256(16303309253033995901903137997030905897146541593529048007608812868085374794485),
            uint256(9159074055704588877296536648000380337471857128321724440294590823869889785941)
        ];
        vk.ic[3] = [
            uint256(4641462070004302322158165986505057327425143586572859358800893070129199209927),
            uint256(3163391584447695760125354721815207319138667465155597519213236343250795569753)
        ];
        vk.ic[4] = [
            uint256(2967827802596222133991065483876860449047124254460545278999073451350321794645),
            uint256(13398916888164575406630686308816925504047064071598484426743755350360465022590)
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

    function proofA() internal pure returns (uint256[2] memory) {
        return [
            uint256(3266706187554666811785078068508515081464057787252631834862657983014896376841),
            uint256(9517221948595178629827800559136395434178456525154561564716931643695242411185)
        ];
    }

    function proofB() internal pure returns (uint256[2][2] memory) {
        return [
            [
                uint256(
                    14446667458145796488813072441582755809819586038124580361987634512487099224029
                ),
                uint256(
                    19560966142159308279335817244335621665729767701242355107703606402086499804678
                )
            ],
            [
                uint256(
                    4853896543306159277821068388603696644007468782559563288828050438160354105757
                ),
                uint256(191037005245582989830569236782110677862861761805400646863059824337551931341)
            ]
        ];
    }

    function proofC() internal pure returns (uint256[2] memory) {
        return [
            uint256(1829885660214784271416683865887658415570954660638383354498016642059787512213),
            uint256(21322277302108489807265090214934791668301162316124435927676854004505346615440)
        ];
    }
}
