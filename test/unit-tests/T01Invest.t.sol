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
import {INonfungiblePositionManager} from "../../src/interfaces/protocols/pancake/INonfungiblePositionManager.sol";

contract Invest is D01Deployment {
    function setUp() public virtual override {
        super.setUp();
        addVaultInfoSubmodule();
        addJoinSubmodule();
    }

    function testDoHardWork() public virtual {
        addInvestSubmodule();
        // init addresses
        address _whale = 0x350d0815Ac821769ea8DcF7bbb943eEE20ba23a8;
        address _usdtWhale = 0x5041ed759Dd4aFc3a72b8192C143F72f4724081A;
        address _token0 = 0x0000000000085d4780B73119b644AE5ecd22b376; // TUSD
        address _token1 = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
        // transfer tokens to the vault
        changePrank(_whale);
        uint256 _amount0 = IERC20(_token0).balanceOf(_whale);
        uint256 _amount1 = IERC20(_token1).balanceOf(_whale);
        IERC20(_token0).transfer(address(vault), _amount0);
        changePrank(_usdtWhale);
        IUSDT(_token1).transfer(address(vault), _amount1);

        changePrank(governance);
        // configure external protocol
        vault.configureExternalProtocol(nonFungibleManagerPancake, masterchefV3Pancake);
        // configure the pool
        vault.configurePool(_token0, _token1, 100, "fPancakeV3");
        // join position
        vault.createPosition(-276365, -276326, 29090960153366438287622, 29792654029, 0, 0);
        // stake position
        vault.stakePosition(vault.positionCount() - 1);
        // time elapse
        vm.roll(MAINNET_FORK_BLOCK_NUMBER + 5049);
        // set reward token
        address _rewardToken0 = 0x152649eA73beAb28c5b49B26eb48f7EAD6d4c898; // CAKE
        address _rewardToken1 = 0x0000000000085d4780B73119b644AE5ecd22b376; // TUSD
        address _rewardToken2 = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
        console2.log(
            "Pending Cake: ", IMasterChefV3(masterchefV3Pancake).pendingCake(vault.positions(vault.positionCount() - 1).tokenId)
        );
        // do hard work
        vault.doHardWork(vault.positionCount() - 1);
    }
}
