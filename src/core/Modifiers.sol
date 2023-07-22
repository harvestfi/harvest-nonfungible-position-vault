//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// @notice modifiers

// Packages
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

// Libraries
import {AppStorage, LibAppStorage} from "../core/AppStorage.sol";
import {LibHelpers} from "../libraries/LibHelpers.sol";
import {LibErrors} from "../libraries/LibErrors.sol";
import {LibConstants} from "../libraries/LibConstants.sol";

/**
 * @title Modifiers
 * @notice Function modifiers to control access
 * @dev Function modifiers to control access
 */

contract Modifiers {
    modifier initialized() {
        if (!LibAppStorage.systemStorage().systemInitialized) {
            revert LibErrors.Initialized();
        }
        _;
    }

    modifier onlyGovernance() {
        if (LibAppStorage.systemStorage().governance != msg.sender) {
            revert LibErrors.NotGovernance();
        }
        _;
    }

    modifier onlyGovernanceOrController() {
        if (LibAppStorage.systemStorage().governance != msg.sender || LibAppStorage.systemStorage().controller != msg.sender) {
            revert LibErrors.NotGovernanceOrController();
        }
        _;
    }

    modifier checkSqrtPriceX96(uint256 offChainSqrtPriceX96, uint256 tolerance) {
        address poolAddr = IUniswapV3Factory(LibConstants._UNI_POOL_FACTORY).getPool(
            LibAppStorage.systemStorage().token0, LibAppStorage.systemStorage().token1, LibAppStorage.systemStorage().fee
        );
        (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(poolAddr).slot0();
        uint256 current = uint256(sqrtPriceX96);
        uint256 step = offChainSqrtPriceX96 * tolerance / 1000;
        require(current < offChainSqrtPriceX96 + step, "Price too high");
        require(current > offChainSqrtPriceX96 - step, "Price too low");
        _;
    }

    modifier checkVaultNotPaused() {
        if (LibAppStorage.systemStorage().vaultPause) {
            revert LibErrors.Paused();
        }
        _;
    }
}
