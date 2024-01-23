// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IVaultInfoSubmodule {
    // System
    function initialized() external view returns (uint8 _initialized);
    function initializing() external view returns (bool _initializing);
    function vaultPause() external view returns (bool _vaultPause);
    function liquidationRewardPause() external view returns (bool _liquidationRewardPause);
    function governance() external view returns (address _governance);
    function controller() external view returns (address _controller);
    // Fee Reward Shares
    function feeDenominator() external view returns (uint256 _feeDenominator);
    function strategist() external view returns (address _strategist);
    // Vault
    function token0() external view returns (address _token0);
    function token1() external view returns (address _token1);
    function fee() external view returns (uint24 _fee);
    function unifiedRewardToken() external view returns (address _unifiedRewardToken);
    function unifiedDepositToken() external view returns (address _unifiedDepositToken);
    function underlyingToken() external view returns (address _underlyingToken);
    function totalRewardToken() external view returns (uint256 _totalCount);
    function rewardToken(uint256 _index) external view returns (address _rewardToken);
    function rewardTokenRegistered(address _rewardToken) external view returns (bool _registered);
    function underlyingDecimals() external view returns (uint8 _underlyingDecimals);
    function underlyingUnit() external view returns (uint256 _underlyingUnit);
    function underlyingBalanceWithInvestment() external view returns (uint256 _balance);
    function getPricePerFullShare() external view returns (uint256 _price);
    // Position
    function currentTokenId() external view returns (uint256 _currentTokenId);
    // External
    function nonFungibleTokenPositionManager() external view returns (address _nonFungibleTokenPositionManager);
    function masterChef() external view returns (address _masterChef);
    // Infrastructure
    function universalLiquidator() external view returns (address _universalLiquidator);
    function universalLiquidatorRegistry() external view returns (address _universalLiquidatorRegistry);
}
