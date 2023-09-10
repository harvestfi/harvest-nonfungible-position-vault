// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Utilities
import {D01Deployment, console2} from "../utils/D01Deployment.t.sol";

// libraries
import {Position} from "../../src/libraries/LibAppStorage.sol";
import {LibErrors} from "../../src/libraries/LibErrors.sol";

// Interfaces
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IUSDT.sol";
import "../../src/interfaces/protocols/pancake/IMasterChefV3.sol";
import "../../src/interfaces/protocols/pancake/ILMPool.sol";

contract Invest is D01Deployment {
    function setUp() public virtual override {
        super.setUp();
        addVaultInfoSubmodule();
        addJoinSubmodule();
    }

    function testDoHardWork() public virtual {
        vm.makePersistent(address(vault));
        addInvestSubmodule();
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
        // set reward token
        address[] memory _rewardTokens = new address[](3);
        _rewardTokens[0] = 0x152649eA73beAb28c5b49B26eb48f7EAD6d4c898; // CAKE
        _rewardTokens[1] = 0x0000000000085d4780B73119b644AE5ecd22b376; // TUSD
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
        uint256 tokenId = vault.positions(vault.positionCount() - 1).tokenId;
        // simulate swap transaction that happened in the pool
        bytes32 _hash = 0xc63ca44c870c098ef79c0c15c25006c8a586256dea53803bbb7f13e910626483;
        vm.rollFork(forkNetwork, _hash);

        tokenId = vault.positions(vault.positionCount() - 1).tokenId;

        // do hard work
        vault.doHardWork(vault.positionCount() - 1);
    }
}
