//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Libraries
import {LibDataTypes} from "./LibDataTypes.sol";

library LibEvents {
    // Ownership
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    // Upgrade
    event SubmoduleUpgrade(LibDataTypes.SubmoduleUpgrade[] _submoduleUpgrade, address _init, bytes _calldata);
    event CreateUpgrade(bytes32 id, address indexed who);
    event UpdateUpgradeExpiration(uint256 duration);
    event UpgradeCancelled(bytes32 id, address indexed who);
    // Configuration
    event VaultPauseUpdate(bool paused);
    event FeeConfigurationUpdate(address feeRewardForwarder, uint256 feeRatio, address platformTarget, uint256 platformRatio);
    event ExternalFarmingContractUpdate(address indexed nftPositionManager, address indexed masterchef);
    event InfrastructureUpdate(address indexed universalLiquidator, address indexed universalLiquidatorRegistry);
    event PoolConfigurationUpdate(address indexed token0, address indexed token1, uint24 fee, string name);
    event PositionAdd(uint256 positionId, uint256 tokenId, uint256 liquidity, int24 tickLower, int24 tickUpper);
    event PositionUpdate(uint256 positionId, uint256 tokenId, uint256 liquidity, int24 tickLower, int24 tickUpper);
    // Initializable
    event Initialized(uint8 version);
    // TokenizedVault
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    // Position Operations
    event RewardLiquidationPaused(bool paused);
    // Invest Operations
    event ProfitLogInReward(address indexed rewardToken, uint256 profitAmount, uint256 feeAmount, uint256 timestamp);
    event PlatformFeeLogInReward(
        address indexed treasury, address indexed rewardToken, uint256 profitAmount, uint256 feeAmount, uint256 timestamp
    );
    event StrategistFeeLogInReward(
        address indexed strategist, address indexed rewardToken, uint256 profitAmount, uint256 feeAmount, uint256 timestamp
    );
    //
    event SwapFeeClaimed(uint256 token0Fee, uint256 token1Fee, uint256 timestamp);
    event Deposit(address indexed user, uint256 token0Amount, uint256 token1Amount);
    event Withdraw(address indexed user, uint256 token0Amount, uint256 token1Amount);
}
