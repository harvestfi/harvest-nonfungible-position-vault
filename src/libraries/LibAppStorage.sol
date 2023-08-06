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
    bool vaultPause;
    bool systemInitialized;
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
    string vaultName;
    // Position
    mapping(uint256 => Position) positions;
    // External
    address nonFungibleTokenPositionManager;
    address masterChef;
}

library LibAppStorage {
    bytes32 internal constant SYSTEM_STORAGE_POSITION = keccak256("system.standard.storage");

    function systemStorage() internal pure returns (AppStorage storage ds) {
        bytes32 position = SYSTEM_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}
