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

    function test_ingestFrobeniusNorm() public {
        uint256[500] memory T;
        for (uint256 i = 0; i < 500; i++) {
            T[i] = 1;
        }
        uint256 g0 = gasleft();
        uint256 n2 = bench.benchmarkIngestFrobeniusNorm(T);
        uint256 used = g0 - gasleft();
        console.log("ingest Frobenius norm (T[i]=1), exec gas:", used);
        console.log("sum T^2:", n2);
    }

    function test_ingestFrobeniusNormWide() public {
        uint256[500] memory T;
        for (uint256 i = 0; i < 500; i++) {
            T[i] = 0xffffffffffffffff; // 8 bytes non-zero; square = 2^128
        }
        uint256 g0 = gasleft();
        uint256 n2 = bench.benchmarkIngestFrobeniusNorm(T);
        uint256 used = g0 - gasleft();
        console.log("ingest Frobenius norm (T[i]=2^64-1), exec gas:", used);
        console.log("sum T^2:", n2);
    }

    // Isolation: the pure sum-of-squares loop, no external call, so the
    // measured gas is the loop alone (no memory/arg overhead of a CALL).
    function test_ingestInlineLoop() public {
        uint256[500] memory T;
        for (uint256 i = 0; i < 500; i++) {
            T[i] = 1;
        }
        uint256 sum;
        uint256 g0 = gasleft();
        for (uint256 i = 0; i < 500; i++) {
            sum += T[i] * T[i];
        }
        uint256 used = g0 - gasleft();
        console.log("inline loop only gas:", used);
        console.log("sum T^2:", sum);
    }

    // Harness calibration: gasleft() probe and a trivial 500-step loop.
    function test_gasleftProbe() public {
        uint256 g0 = gasleft();
        uint256 used = g0 - gasleft();
        console.log("gasleft probe:", used);
        uint256 sum;
        g0 = gasleft();
        for (uint256 i = 0; i < 500; i++) {
            sum += i;
        }
        used = g0 - gasleft();
        console.log("minimal 500-loop gas:", used);
    }
}

