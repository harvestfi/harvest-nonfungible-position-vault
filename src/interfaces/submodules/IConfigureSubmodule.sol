// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IConfigureSubmodule {
    function configureFees(address _feeRewardForwarder, uint256 _feeRatio, address _platformTarget, uint256 _platformRatio)
        external;
    function configureExternalProtocol(address _nftPositionManager, address _masterchef) external;
    function configurePool(address _token0, address _token1, uint24 _fee, string calldata _vaultName) external;
    function setVaultPause(bool _pause) external;
}
