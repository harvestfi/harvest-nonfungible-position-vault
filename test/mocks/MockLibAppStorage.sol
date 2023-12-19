// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

struct AppStorage {
    address governance;
    address controller;
    uint256 checkOne;
}

library LibAppStorage {
    function systemStorage() internal pure returns (AppStorage storage ds) {
        assembly {
            ds.slot := 0
        }
    }
}
