//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;
pragma abicoder v2;

interface IUniversalLiquidatorRegistry {
    function universalLiquidator() external returns (address);
}
