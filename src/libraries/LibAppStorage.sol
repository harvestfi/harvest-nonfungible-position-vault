// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

struct Position {
    int24 tickLower;
    int24 tickUpper;
    uint256 initialLiquidity;
    uint256 tokenId;
}

struct AppStorage {
    // System
    uint8 initialized;
    bool initializing;
    bool vaultPause;
    address governance;
    address controller;
    // Fee Reward Shares
    address feeRewardForwarder;
    address platformTarget;
    uint256 feeRatio;
    uint256 platformRatio;
    /// Simple two phase upgrade scheme
    mapping(bytes32 => uint256) upgradeScheduled; // id of the upgrade => the time that the upgrade is valid until.
    uint256 upgradeExpiration;
    // Vault
    address token0;
    address token1;
    uint24 fee;
    // Token
    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowances;
    uint256 totalSupply;
    string name;
    string symbol;
    // Position
    uint256 positionCount;
    uint256 latestPositionId;
    mapping(uint256 => Position) positions;
    // External
    address nonFungibleTokenPositionManager;
    address masterChef;
}

library LibAppStorage {
    function systemStorage() internal pure returns (AppStorage storage ds) {
        assembly {
            ds.slot := 0
        }
    }
}
