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
    error DecimalsMismatch(address _token0, uint8 _decimals0, address _token1, uint8 _decimals1);
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
