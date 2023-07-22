// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

library LibDataTypes {
    enum SubmoduleUpgradeAction {
        Add,
        Replace,
        Remove
    }
    // Add=0, Replace=1, Remove=2

    struct SubmoduleUpgrade {
        address submoduleAddress;
        SubmoduleUpgradeAction action;
        bytes4[] functionSelectors;
    }
}
