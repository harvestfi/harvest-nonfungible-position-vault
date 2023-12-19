// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IJoinSubmodule {
    function createPosition(
        int24 _tickLower,
        int24 _tickUpper,
        uint256 _amount0Desired,
        uint256 _amount1Desired,
        uint256 _amount0Min,
        uint256 _amount1Min
    ) external returns (uint256 _tokenId, uint128 _liquidity, uint256 _amount0, uint256 _amount1);

    function stakePosition(uint256 _tokenId) external;
}
