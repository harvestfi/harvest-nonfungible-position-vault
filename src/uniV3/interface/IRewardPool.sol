//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

interface IRewardPool {
    function exit() external;
    function stakedBalanceOf(address) external view returns (uint256);
}
