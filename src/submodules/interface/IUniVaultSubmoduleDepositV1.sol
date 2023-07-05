//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;
pragma abicoder v2;

interface IUniVaultSubmoduleDepositV1 {
    function migrateToNftFromV2(
        uint256 _amount,
        uint256 _minAmountForRemoveLiquidity0,
        uint256 _minAmountForRemoveLiquidity1,
        bool _zapFunds,
        uint256 _sqrtRatioX96,
        uint256 _tolerance
    ) external returns (uint256, uint256);

    function migrateToNftFromV2(
        uint256 _amount,
        uint256 _minAmountForRemoveLiquidity0,
        uint256 _minAmountForRemoveLiquidity1,
        bool _zapFunds,
        uint256 _sqrtRatioX96,
        uint256 _tolerance,
        uint256 _amount0OutMinForZap,
        uint256 _amount1OutMinForZap,
        uint160 _sqrtPriceLimitX96
    ) external returns (uint256, uint256);

    function deposit(uint256 _amount0, uint256 _amount1, bool _zapFunds, uint256 _sqrtRatioX96, uint256 _tolerance)
        external
        returns (uint256, uint256);

    function deposit(
        uint256 _amount0,
        uint256 _amount1,
        bool _zapFunds,
        uint256 _sqrtRatioX96,
        uint256 _tolerance,
        uint256 _zapAmount0OutMin,
        uint256 _zapAmount1OutMin,
        uint160 _zapSqrtPriceLimitX96
    ) external returns (uint256, uint256);

    function withdraw(uint256 _numberOfShares, bool _token0, bool _token1, uint256 _sqrtRatioX96, uint256 _tolerance)
        external
        returns (uint256, uint256);

    function withdraw(
        uint256 _numberOfShares,
        bool _token0,
        bool _token1,
        uint256 _sqrtRatioX96,
        uint256 _tolerance,
        uint256 _amount0OutMin,
        uint256 _amount1OutMin,
        uint160 _sqrtPriceLimitX96
    ) external returns (uint256, uint256);

    function _collectFeesAndCompound() external;
    function _compoundRewards() external;
    function sweepDust() external;
}
