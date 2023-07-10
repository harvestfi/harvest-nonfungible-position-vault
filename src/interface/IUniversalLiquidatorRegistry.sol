//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.6;
pragma abicoder v2;

interface IUniversalLiquidatorRegistry {
    function universalLiquidator() external returns (address);
}
