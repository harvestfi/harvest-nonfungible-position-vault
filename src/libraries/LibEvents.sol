//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Libraries
import {LibDataTypes} from "./LibDataTypes.sol";

library LibEvents {
    // Ownership
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    // Upgrade
    event ScheduleUpgrade(uint256 nextImplementationTimestamp, address nextInitContract);
    event SubmoduleUpgrade(LibDataTypes.SubmoduleUpgrade[] _submoduleUpgrade, address _init, bytes _calldata);
    // TODO: Require to confirm implementation here
    //event CreateUpgrade(bytes32 id, address indexed who);
    //event UpdateUpgradeExpiration(uint256 duration);
    //event UpgradeCancelled(bytes32 id, address indexed who);
    // Configuration
    event FeeConfigurationUpdate(
        address indexed strategist, uint256 strategistFeeNumerator, uint256 platformFeeNumerator, uint256 profitSharingNumerator
    );
    event QueueProfitSharingChange(uint256 nextProfitSharingNumerator, uint256 nextProfitSharingNumeratorTimestamp);
    event ConfirmProfitSharingChange(uint256 profitSharingNumerator);
    event QueueStrategistFeeChange(uint256 nextStrategistFeeNumerator, uint256 nextStrategistFeeNumeratorTimestamp);
    event ConfirmStrategistFeeChange(uint256 strategistFeeNumerator);
    event QueuePlatformFeeChange(uint256 nextPlatformFeeNumerator, uint256 nextPlatformFeeNumeratorTimestamp);
    event ConfirmPlatformFeeChange(uint256 platformFeeNumerator);
    event QueueNextImplementationDelay(uint256 nextImplementationDelay, uint256 nextImplementationDelayTimestamp);
    event ConfirmNextImplementationDelay(uint256 nextImplementationDelay);
    event ExternalFarmingContractUpdate(address indexed nftPositionManager, address indexed masterchef);
    event InfrastructureUpdate(address indexed universalLiquidator, address indexed universalLiquidatorRegistry);
    event PoolConfigurationUpdate(address indexed token0, address indexed token1, uint24 fee, string name);
    event UnitsUpdate(uint8 underlyingDecimals, uint256 underlyingUnit);
    event RewardTokenAdded(uint256 fromIndex, uint256 toIndex);
    event RewardTokenRemoved(address indexed removedToken);
    event UnifiedRewardTokenUpdate(address indexed rewardToken);
    event UnifiedDepositTokenUpdate(address indexed depositToken);
    event UnderlyingTokenUpdate(address indexed underlyingToken);
    event PositionAdd(uint256 positionId, uint256 tokenId, uint256 liquidity, int24 tickLower, int24 tickUpper);
    event PositionUpdate(uint256 positionId, uint256 tokenId, uint256 liquidity, int24 tickLower, int24 tickUpper);
    event VaultPauseUpdate(bool paused);
    event LiquidationRewardPauseUpdate(bool paused);
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
