// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// Libraries
import {LibDataTypes} from "../../../libraries/LibDataTypes.sol";

interface IMasterChefV3 {
    function latestPeriodEndTime() external view returns (uint256);

    function latestPeriodStartTime() external view returns (uint256);

    function getLatestPeriodInfoByPid(uint256 _pid) external view returns (uint256 cakePerSecond, uint256 endTime);

    function getLatestPeriodInfo(address _v3Pool) external view returns (uint256 cakePerSecond, uint256 endTime);

    function pendingCake(uint256 _tokenId) external view returns (uint256 reward);

    function onERC721Received(address, address _from, uint256 _tokenId, bytes calldata) external returns (bytes4);

    function harvest(uint256 _tokenId, address _to) external returns (uint256 reward);

    function updateLiquidity(uint256 _tokenId) external;

    function withdraw(uint256 _tokenId, address _to) external returns (uint256 reward);

    function increaseLiquidity(LibDataTypes.IncreaseLiquidityParams memory params)
        external
        payable
        returns (uint128 liquidity, uint256 amount0, uint256 amount1);

    function decreaseLiquidity(LibDataTypes.DecreaseLiquidityParams memory params)
        external
        returns (uint256 amount0, uint256 amount1);

    function collect(LibDataTypes.CollectParams memory params) external returns (uint256 amount0, uint256 amount1);

    function collectTo(LibDataTypes.CollectParams memory params, address to)
        external
        returns (uint256 amount0, uint256 amount1);

    function unwrapWETH9(uint256 amountMinimum, address recipient) external;

    function sweepToken(address token, uint256 amountMinimum, address recipient) external;

    function burn(uint256 _tokenId) external;

    function upkeep(uint256 amount, uint256 duration, bool withUpdate) external;
}
