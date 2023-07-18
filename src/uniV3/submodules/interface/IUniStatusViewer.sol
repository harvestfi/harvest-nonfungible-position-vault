//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

interface IUniStatusViewer {
    function getAmountsForPosition(uint256 posId) external view returns (uint256 amount0, uint256 amount1);
}
