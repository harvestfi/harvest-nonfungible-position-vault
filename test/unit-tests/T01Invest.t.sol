// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Utilities
import {D01Deployment, console2} from "../utils/D01Deployment.t.sol";
import {PoolHelper} from "../utils/PoolHelper.t.sol";

// libraries
import {Position} from "../../src/libraries/LibAppStorage.sol";
import {LibErrors} from "../../src/libraries/LibErrors.sol";

// Interfaces
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract T01Invest is D01Deployment {
    function setUp() public virtual override {
        super.setUp();
        addVaultInfoSubmodule();
        addJoinSubmodule();
    }

    function testDoHardWork() public virtual {
        addInvestSubmodule();
        // transfer tokens to the vault
        uint256 _amount0 = IERC20(token0).balanceOf(whale);
        uint256 _amount1 = IERC20(token1).balanceOf(whale);

        deal(token0, address(vault), _amount0);
        deal(token1, address(vault), _amount1);

        changePrank(governance);
        // configure external protocol
        vault.configureExternalProtocol(nonFungibleManagerPancake, masterchefV3Pancake);
        vault.configureInfrastructure(address(universalLiquidator), address(universalLiquidatorRegistry));
        // configure liquidation path
        address[] memory _path = new address[](2);
        // CAKE -> WETH
        _path[0] = 0x152649eA73beAb28c5b49B26eb48f7EAD6d4c898;
        _path[1] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        universalLiquidatorRegistry.setPath(bytes32(bytes("pancakeV3")), _path);
        // USDC -> WETH
        _path[0] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        _path[1] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        universalLiquidatorRegistry.setPath(bytes32(bytes("pancakeV3")), _path);
        // USDT -> WETH
        _path[0] = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        _path[1] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        universalLiquidatorRegistry.setPath(bytes32(bytes("pancakeV3")), _path);
        // WETH -> USDT
        _path[0] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        _path[1] = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        universalLiquidatorRegistry.setPath(bytes32(bytes("pancakeV3")), _path);
        // configure liquidation fee
        // CAKE -> WETH
        pancakeV3.setFee(0x152649eA73beAb28c5b49B26eb48f7EAD6d4c898, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, 2500);
        // USDC -> WETH
        pancakeV3.setFee(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, 500);
        // USDT -> WETH
        pancakeV3.setFee(0xdAC17F958D2ee523a2206206994597C13D831ec7, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, 500);
        // configure the pool
        vault.configurePool(token0, token1, fee, vaultName);
        // set reward token
        address[] memory _rewardTokens = new address[](3);
        _rewardTokens[0] = 0x152649eA73beAb28c5b49B26eb48f7EAD6d4c898; // CAKE
        _rewardTokens[1] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        _rewardTokens[2] = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
        vault.addRewardTokens(_rewardTokens);
        // set unified reward token
        vault.setUnifiedRewardToken(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // WETH
        // set unified deposit token
        vault.setUnifiedDepositToken(0xdAC17F958D2ee523a2206206994597C13D831ec7); // USDT

        // join position
        vault.createPosition(tickLower, tickUpper, amount0Desired, amount1Desired, amount0Min, amount1Min);
        // stake position
        vault.stakePosition(vault.positionCount() - 1);

        bytes memory encodedPath0 = abi.encodePacked(token0, fee, token1);
        bytes memory encodedPath1 = abi.encodePacked(token1, fee, token0);
        mockSwap(10, 0x1b81D678ffb9C0263b24A97847620C99d213eB14, encodedPath0, encodedPath1, token0, token1);

        // do hard work
        vault.doHardWork(vault.positionCount() - 1);
    }
}
