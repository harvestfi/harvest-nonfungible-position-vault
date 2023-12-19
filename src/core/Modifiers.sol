//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// @notice modifiers

// Packages
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

// Libraries
import {AppStorage, LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibHelpers} from "../libraries/LibHelpers.sol";
import {LibErrors} from "../libraries/LibErrors.sol";
import {LibEvents} from "../libraries/LibEvents.sol";
import {LibConstants} from "../libraries/LibConstants.sol";

/**
 * @title Modifiers
 * @notice Function modifiers to control access
 * @dev Function modifiers to control access
 */

contract Modifiers {
    AppStorage internal s;

    modifier initializer() {
        bool isTopLevelCall = !s.initializing;
        if (!((isTopLevelCall && s.initialized < 1) || (!((address(this)).code.length > 0) && s.initialized == 1))) {
            revert LibErrors.Initialized();
        }
        s.initialized = 1;
        if (isTopLevelCall) {
            s.initializing = true;
        }
        _;
        if (isTopLevelCall) {
            s.initializing = false;
            emit LibEvents.Initialized(1);
        }
    }

    modifier reinitializer(uint8 version) {
        if (!(!s.initializing && s.initialized < version)) {
            revert LibErrors.Initialized();
        }

        s.initialized = version;
        s.initializing = true;
        _;
        s.initializing = false;
        emit LibEvents.Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        if (!s.initializing) {
            revert LibErrors.NotInitializing();
        }
        _;
    }

    modifier onlyGovernance() {
        if (s.governance != msg.sender) {
            revert LibErrors.NotGovernance();
        }
        _;
    }

    modifier onlyGovernanceOrController() {
        if (s.governance != msg.sender && s.controller != msg.sender) {
            revert LibErrors.NotGovernanceOrController();
        }
        _;
    }

    modifier checkSqrtPriceX96(uint256 offChainSqrtPriceX96, uint256 tolerance) {
        address poolAddr = IUniswapV3Factory(LibConstants._UNI_POOL_FACTORY).getPool(s.token0, s.token1, s.fee);
        (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(poolAddr).slot0();
        uint256 current = uint256(sqrtPriceX96);
        uint256 step = offChainSqrtPriceX96 * tolerance / 1000;
        require(current < offChainSqrtPriceX96 + step, "Price too high");
        require(current > offChainSqrtPriceX96 - step, "Price too low");
        _;
    }

    modifier checkVaultNotPaused() {
        if (s.vaultPause) {
            revert LibErrors.Paused();
        }
        _;
    }

    modifier controllerConfigured() {
        if (s.controller == address(0)) {
            revert LibErrors.AddressUnconfigured();
        }
        _;
    }
}
