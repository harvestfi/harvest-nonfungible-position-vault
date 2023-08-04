// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

library LibErrors {
    // Access Control List
    error NoPermission();
    error NotGovernance();
    error NotGovernanceOrController();
    // Vault
    error Paused();
    error Initialized();
    error InitializationFunctionReverted(address _initializationContractAddress, bytes _calldata);
}
