// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Utilities
import {D01Deployment, console2} from "../utils/D01Deployment.t.sol";

// Interfaces
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IUSDT.sol";

contract Join is D01Deployment {
    function setUp() public virtual override {
        super.setUp();
    }

    function testJoin() public virtual {
        addJoinSubmodule();

        // configure external protocol
        vault.configureExternalProtocol(nonFungibleManagerPancake, masterchefV3Pancake);

        address _whale = 0x350d0815Ac821769ea8DcF7bbb943eEE20ba23a8;
        address _usdtWhale = 0x5041ed759Dd4aFc3a72b8192C143F72f4724081A;
        address _token0 = 0x0000000000085d4780B73119b644AE5ecd22b376; // TUSD
        address _token1 = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT

        // configure the pool
        vault.configurePool(_token0, _token1, 100, "fPancakeV3");

        changePrank(_whale);
        // transfer tokens to the vault
        uint256 _amount0 = IERC20(_token0).balanceOf(_whale);
        uint256 _amount1 = IERC20(_token1).balanceOf(_whale);
        console2.log(_amount0, _amount1);
        IERC20(_token0).transfer(address(vault), _amount0);
        changePrank(_usdtWhale);
        IUSDT(_token1).transfer(address(vault), _amount1);
        changePrank(governance);

        // join position
        vault.createPosition(-276365, -276326, 29090960153366438287622, 29792654029, 0, 0);
    }

    function testStake() public virtual {
        // deploy the init contract
        // create new position without module
        // stake position
    }

    function testJoinAndStake() public virtual {
        // deploy the init contract
        // create new position with module
        // stake position
    }
}
