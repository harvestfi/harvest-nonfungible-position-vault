// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IConfigureSubmodule {
    function configureFees(
        address _strategist,
        uint256 _strategistFeeNumerator,
        uint256 _platformFeeNumerator,
        uint256 _profitSharingNumerator
    ) external;
    function configureExternalProtocol(address _nftPositionManager, address _masterchef) external;
    function configureInfrastructure(address _universalLiquidator, address _universalLiquidatorRegistry) external;
    function configurePool(address _token0, address _token1, uint24 _fee, string calldata _vaultName) external;
    function configureUnits() external;
    function addRewardTokens(address[] calldata _rewardTokens) external;
    function removeRewardToken(uint256 _index) external;
    function setUnifiedRewardToken(address _rewardToken) external;
    function setUnifiedDepositToken(address _depositToken) external;
    function setUnderlyingToken(address _underlyingToken) external;
    function addPosition(uint256 _tokenId, uint256 _liquidity, int24 _tickLower, int24 _tickUpper) external;
    function updatePosition(uint256 _positionId, uint256 _tokenId, uint256 _liquidity, int24 _tickLower, int24 _tickUpper)
        external;
    function setVaultPause(bool _pause) external;
    function setLiquidationRewardPause(bool _pause) external;
}
