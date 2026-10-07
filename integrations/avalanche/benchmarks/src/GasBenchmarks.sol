// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract GasBenchmarks {
    // EIP-196: ecAdd precompilado en 0x06
    function benchEcAdd() external view returns (uint256 gasUsed) {
        uint256[4] memory input = [
            uint256(1), uint256(2),  // P
            uint256(1), uint256(2)   // Q
        ];
        uint256 gasBefore = gasleft();
        assembly {
            let success := staticcall(gas(), 0x06, input, 0x80, 0, 0x40)
            if iszero(success) { revert(0, 0) }
        }
        gasUsed = gasBefore - gasleft();
    }

    // EIP-196: ecMul precompilado en 0x07
    function benchEcMul() external view returns (uint256 gasUsed) {
        uint256[3] memory input = [
            uint256(1), uint256(2),  // P
            uint256(3)               // scalar
        ];
        uint256 gasBefore = gasleft();
        assembly {
            let success := staticcall(gas(), 0x07, input, 0x60, 0, 0x40)
            if iszero(success) { revert(0, 0) }
        }
        gasUsed = gasBefore - gasleft();
    }

    // EIP-197: ecPairing precompilado en 0x08, k pares (1..4).
    // EIP-197 define k = input.length / 192, y el coste es 45000 + 34000*k.
    function benchEcPairing(uint256 k) external view returns (uint256 gasUsed) {
        require(k >= 1 && k <= 4, "k out of range");
        uint256 size = k * 192;
        uint256[24] memory input; // hasta 4 pares de (G1, G2) = 768 bytes = 0x300
        uint256 gasBefore = gasleft();
        assembly {
            let success := staticcall(gas(), 0x08, input, size, 0, 0x20)
            if iszero(success) { revert(0, 0) }
        }
        gasUsed = gasBefore - gasleft();
    }

    // ------------------------------------------------------------------
    // Poseidon-2 sobre BN254 (t=2, RF=8 rondas completas, RP=56 parciales,
    // S-box x^5, MDS Cauchy 2x2). La estructura y el numero de operaciones
    // son los del Poseidon estandar; las constantes de ronda son marcadores
    // deterministicos (no los literales del estandar). El coste de gas es
    // identico porque MULMOD/ADD tienen coste constante, independiente del
    // valor de los operandos.
    // ------------------------------------------------------------------
    uint256 internal constant P =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;
    // MDS Cauchy con x=(0,1), y=(2,3): M[i][j] = 1/(x_i + y_j)
    uint256 internal constant INV2 =
        10944121435919637611123202872628637544274182200208017171849102093287904247809;
    uint256 internal constant INV3 =
        14592161914559516814830937163504850059032242933610689562465469457717205663745;
    uint256 internal constant INV4 =
        16416182153879456416684804308942956316411273300312025757773653139931856371713;
    uint256 internal constant RF = 8;
    uint256 internal constant RP = 56;

    function _addF(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            uint256 s = a + b;
            if (s >= P) s -= P;
            return s;
        }
    }

    function _sbox(uint256 x) internal pure returns (uint256) {
        uint256 x2 = mulmod(x, x, P);
        uint256 x4 = mulmod(x2, x2, P);
        return mulmod(x4, x, P);
    }

    function _mds(uint256 a, uint256 b) internal pure returns (uint256, uint256) {
        return (
            _addF(mulmod(a, INV2, P), mulmod(b, INV3, P)),
            _addF(mulmod(a, INV3, P), mulmod(b, INV4, P))
        );
    }

    function _rc(uint256 r, uint256 i) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(r, i))) % P;
    }

    function benchPoseidon2() external view returns (uint256 gasUsed) {
        uint256 nrc = (RF + RP) * 2;
        uint256[] memory rc = new uint256[](nrc);
        for (uint256 j = 0; j < nrc; j++) {
            rc[j] = _rc(j / 2, j % 2); // fuera de la region medida
        }

        uint256[2] memory s = [uint256(1), uint256(2)];
        uint256 s0in = s[0];
        uint256 s1in = s[1];

        uint256 gasBefore = gasleft();
        // 8 rondas completas: S-box en ambos elementos
        for (uint256 r = 0; r < RF; r++) {
            s[0] = _addF(s[0], rc[2 * r]);
            s[1] = _addF(s[1], rc[2 * r + 1]);
            s[0] = _sbox(s[0]);
            s[1] = _sbox(s[1]);
            (s[0], s[1]) = _mds(s[0], s[1]);
        }
        // 56 rondas parciales: S-box solo en s[0]
        for (uint256 r = RF; r < RF + RP; r++) {
            s[0] = _addF(s[0], rc[2 * r]);
            s[0] = _sbox(s[0]);
            (s[0], s[1]) = _mds(s[0], s[1]);
        }
        gasUsed = gasBefore - gasleft();

        // Guarda anti dead-code-elimination: si el optimizador hubiera
        // eliminado la permutacion, el estado seguiria siendo el inicial.
        require(s[0] != s0in || s[1] != s1in, "poseidon: permutation eliminated");
    }

    // ------------------------------------------------------------------
    // Coste de ingerir el tensor T (C*D*H = 500 entradas) en la cadena
    // destino y calcular su norma de Frobenius al cuadrado, sum T[i]^2.
    // Es la alternativa nativa que propone el revisor: transmitir T y
    // computar la norma on-chain en lugar de verificar una prueba.
    // ------------------------------------------------------------------
    function benchmarkIngestFrobeniusNorm(uint256[500] calldata T)
        external pure returns (uint256 sum)
    {
        for (uint256 i = 0; i < 500; i++) {
            sum += T[i] * T[i];
        }
    }
}

