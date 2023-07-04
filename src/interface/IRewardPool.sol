//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.6;

interface IRewardPool {
    function exit() external;
    function stakedBalanceOf(address) external view returns (uint256);
}
