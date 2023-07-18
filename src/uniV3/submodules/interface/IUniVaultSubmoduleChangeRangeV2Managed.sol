//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.6;
pragma abicoder v2;

interface IUniVaultSubmoduleChangeRangeV2Managed {
    function addPositionIds(uint256[] calldata newPosIds) external;
    function getAmountsForPosition(uint256 posId) external view returns (uint256 amount0, uint256 amount1);
}
