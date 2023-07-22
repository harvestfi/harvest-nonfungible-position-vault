// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

library LibErrors {
    error NoPermission();
    error NotGovernance();
    error NotGovernanceOrController();
    error Paused();
    error Initialized();
}
