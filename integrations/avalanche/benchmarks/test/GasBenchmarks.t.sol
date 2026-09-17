// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "forge-std/Test.sol";
import "../src/GasBenchmarks.sol";

contract GasBenchmarksTest is Test {
    GasBenchmarks bench;

    function setUp() public {
        bench = new GasBenchmarks();
    }

    function test_ecAdd() public {
        uint256 gas = bench.benchEcAdd();
        console.log("ecAdd gas:", gas);
    }

    function test_ecMul() public {
        uint256 gas = bench.benchEcMul();
        console.log("ecMul gas:", gas);
    }

    function test_ecPairing_k1() public {
        uint256 gas = bench.benchEcPairing(1);
        console.log("ecPairing k=1 gas:", gas);
    }

    function test_ecPairing_k2() public {
        uint256 gas = bench.benchEcPairing(2);
        console.log("ecPairing k=2 gas:", gas);
    }

    function test_ecPairing_k4() public {
        uint256 gas = bench.benchEcPairing(4);
        console.log("ecPairing k=4 gas:", gas);
    }

    function test_poseidon2() public {
        uint256 gas = bench.benchPoseidon2();
        console.log("poseidon2 gas:", gas);
    }
}

