// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

struct AppStorage {
    uint256 checkOne;
    uint256 checkTwo;
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
