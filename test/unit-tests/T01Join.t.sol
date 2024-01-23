// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Utilities
import {D01Deployment, console2} from "../utils/D01Deployment.t.sol";

// libraries
import {LibErrors} from "../../src/libraries/LibErrors.sol";

// Interfaces
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IUSDT.sol";
import {INonfungiblePositionManager} from "../../src/interfaces/protocols/pancake/INonfungiblePositionManager.sol";

contract T01Join is D01Deployment {
    function setUp() public virtual override {
        super.setUp();
        addVaultInfoSubmodule();
    }

    function testJoin() public virtual {
        addJoinSubmodule();
        // transfer tokens to the vault
        changePrank(whale);
        uint256 _amount0 = IERC20(token0).balanceOf(whale);
        uint256 _amount1 = IERC20(token1).balanceOf(whale);
        IERC20(token0).transfer(address(vault), _amount0);
        IUSDT(token1).transfer(address(vault), _amount1);

        changePrank(governance);
        // stake position should fail before configure external protocol
        vm.expectRevert(LibErrors.AddressUnconfigured.selector);
        vault.createPosition(tickLower, tickUpper, amount0Desired, amount1Desired, amount0Min, amount1Min);
        // configure external protocol
        vault.configureExternalProtocol(nonFungibleManagerPancake, masterchefV3Pancake);
        // configure the pool
        vault.configurePool(token0, token1, fee, vaultName);
        // join position
        vault.createPosition(tickLower, tickUpper, amount0Desired, amount1Desired, amount0Min, amount1Min);
        uint256 currentTokenId = vault.currentTokenId();
        assertNotEq(currentTokenId, 0);
    }

    function testStake() public virtual {
        addJoinSubmodule();
        changePrank(whale);
        // mint position
        (uint256 tokenId, uint128 liquidity,,) = INonfungiblePositionManager(nonFungibleManagerPancake).mint(
            INonfungiblePositionManager.MintParams(
                token0,
                token1,
                fee,
                tickLower,
                tickUpper,
                amount0Desired,
                amount1Desired,
                amount0Min,
                amount1Min,
                address(vault),
                block.timestamp
            )
        );

        changePrank(governance);
        vault.updatePosition(tokenId, liquidity, tickLower, tickUpper);
        // stake position should fail before configure external protocol
        vm.expectRevert(LibErrors.AddressUnconfigured.selector);
        vault.stakePosition();
        // configure external protocol
        vault.configureExternalProtocol(nonFungibleManagerPancake, masterchefV3Pancake);
        // stake position
        vault.stakePosition();
    }

    function testJoinAndStake() public virtual {
        addJoinSubmodule();
        // TODO: Modularize token transfer settings
        // transfer tokens to the vault
        changePrank(whale);
        uint256 _amount0 = IERC20(token0).balanceOf(whale);
        uint256 _amount1 = IERC20(token1).balanceOf(whale);
        IERC20(token0).transfer(address(vault), _amount0);
        IUSDT(token1).transfer(address(vault), _amount1);

        changePrank(governance);
        // configure external protocol
        vault.configureExternalProtocol(nonFungibleManagerPancake, masterchefV3Pancake);
        // configure the pool
        vault.configurePool(token0, token1, fee, vaultName);
        // join position
        vault.createPosition(tickLower, tickUpper, amount0Desired, amount1Desired, amount0Min, amount1Min);
        // stake position
        vault.stakePosition();
    }
}
