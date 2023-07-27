// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IConfigureSubmodule {
    function configureFees(address _feeRewardForwarder, uint256 _feeRatio, address _platformTarget, uint256 _platformRatio)
        external;

    function setVaultPause(bool _pause) external;
}
