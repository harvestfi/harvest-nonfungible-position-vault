// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

struct Position {
    uint256 tokenId;
    uint256 initialLiquidity;
    int24 tickLower;
    int24 tickUpper;
    bool staked;
}

struct AppStorage {
    // System
    uint8 initialized;
    bool initializing;
    bool vaultPause;
    bool liquidationRewardPause;
    address governance;
    address controller;
    // Fee Reward Shares
    address strategist;
    /// 7% of fees captured go to iFARM stakers
    uint256 profitSharingNumerator; // default: 700;
    uint256 nextProfitSharingNumerator;
    uint256 nextProfitSharingNumeratorTimestamp;
    /// 0% of fees captured go to strategists
    uint256 strategistFeeNumerator;
    uint256 nextStrategistFeeNumerator;
    uint256 nextStrategistFeeNumeratorTimestamp;
    /// 3% of fees captured go to the devs of the platform
    uint256 platformFeeNumerator; // default: 300;
    uint256 nextPlatformFeeNumerator;
    uint256 nextPlatformFeeNumeratorTimestamp;
    /// Simple two phase upgrade scheme
    address nextInitContract;
    uint256 nextImplementationTimestamp;
    uint256 nextImplementationDelay;
    uint256 tempNextImplementationDelay;
    uint256 tempNextImplementationDelayTimestamp;
    //mapping(bytes32 => uint256) upgradeScheduled; // id of the upgrade => the time that the upgrade is valid until.
    //uint256 upgradeExpiration;
    // Vault
    address token0;
    address token1;
    uint24 fee;
    address unifiedRewardToken;
    address unifiedDepositToken;
    address underlyingToken;
    address[] rewardTokens;
    mapping(address => bool) rewardTokenRegistered;
    uint8 underlyingDecimals;
    uint256 underlyingUnit;
    // Token
    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowances;
    uint256 totalSupply;
    string name;
    string symbol;
    // Position
    uint256 positionCount;
    mapping(uint256 => Position) positions;
    // External
    address nonFungibleTokenPositionManager;
    address masterChef;
    // Infrastructure
    address universalLiquidator;
    address universalLiquidatorRegistry;
}

library LibAppStorage {
    function systemStorage() internal pure returns (AppStorage storage ds) {
        assembly {
            ds.slot := 0
        }
    }
}
