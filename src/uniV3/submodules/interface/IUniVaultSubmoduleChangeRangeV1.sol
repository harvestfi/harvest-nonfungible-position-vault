//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;
pragma abicoder v2;

interface IUniVaultSubmoduleChangeRangeV1 {
    function changeRange(uint256 newPosId) external;
}
