// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

library LibErrors {
    enum TimestampErrorCodes {
        CannotBeZero,
        TooEarly
    }

    // Library Checkers
    error AddressUnconfigured();
    // Access Control List
    error NoPermission();
    error NotGovernance();
    error NotGovernanceOrController();
    // Configuration
    error FeeTooHigh(uint256 _maxFee, uint256 _setFee);
    error FeeParametersUnconfigured(uint256 _numerator, uint256 _timestamp);
    error FeeUpdateExpired(uint256 _nextFeeTimestamp);
    error TokenAlreadyRegistered(address _token);
    error InvalidToken(address _token);
    error InvalidTimestamp(TimestampErrorCodes _errorCode, uint256 _timestamp);
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
