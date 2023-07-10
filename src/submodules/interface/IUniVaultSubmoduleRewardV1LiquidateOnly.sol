//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.6;
pragma abicoder v2;

interface IUniVaultSubmoduleRewardV1LiquidateOnly {
    function rewardToken(uint256 i) external view returns (address);
    function setLiquidationPath(address rewardToken, bytes32[] memory _dexes, address[] memory _path) external;
    function addRewardTokens(address[] memory newTokens) external;
    function removeRewardToken(uint256 i) external;
}
