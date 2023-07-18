//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.6;

interface IUniStatusViewer {
    function getAmountsForPosition(uint256 posId) external view returns (uint256 amount0, uint256 amount1);
}
