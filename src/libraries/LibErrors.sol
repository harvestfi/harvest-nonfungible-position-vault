// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

library LibErrors {
    // Library Checkers
    error AddressUnconfigured();
    // Access Control List
    error NoPermission();
    error NotGovernance();
    error NotGovernanceOrController();
    // Configuration
    error TokenAlreadyRegistered(address _token);
    error InvalidToken(address _token);
    // Position
    error PositionStaked(uint256 _positionId);
    // Vault
    error Paused();
    error Initialized();
    error NotInitializing();
    error InitializationFunctionReverted(address _initializationContractAddress, bytes _calldata);
    // Operations
    error LiquidationInfoUnconfigured();
}
