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
    uint256 FEE_DENOMINATOR; // default: 10000
    address strategist;
    uint256 strategistFeeNumerator; // default: 0
    uint256 platformFeeNumerator; // default: 300
    uint256 profitSharingNumerator; // default: 700
    /// Simple two phase upgrade scheme
    mapping(bytes32 => uint256) upgradeScheduled; // id of the upgrade => the time that the upgrade is valid until.
    uint256 upgradeExpiration;
    // Vault
    address token0;
    address token1;
    uint24 fee;
    address unifiedRewardToken;
    address unifiedDepositToken;
    address underlyingToken; //TODO: Add configuration and info getter
    address[] rewardTokens;
    mapping(address => bool) rewardTokenRegistered;
    uint8 underlyingDecimals; //TODO: Add configuration and info getter
    uint256 UNDERLYING_UNIT; //TODO: Add configuration and info getter
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
