// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";

// Core
import {InitVault} from "../../src/core/InitVault.sol";
import {NonFungiblePositionVault} from "../../src/core/NonFungiblePositionVault.sol";
import {InvestSubmodule} from "../../src/submodules/InvestSubmodule.sol";

// Interfaces
import {INonFungiblePositionVault} from "../../src/interfaces/core/INonFungiblePositionVault.sol";
import {IInvestSubmodule} from "../../src/interfaces/submodules/IInvestSubmodule.sol";
import {INonfungiblePositionManager} from "../../src/interfaces/protocols/pancake/INonfungiblePositionManager.sol";

// Libraries
import {LibDataTypes} from "../../src/libraries/LibDataTypes.sol";

// Utilities
import {Defaults} from "../utils/Defaults.t.sol";

contract Deploy is Defaults {
    InitVault public initVault;
    INonFungiblePositionVault public vault;

    uint256 public forkNetwork;
    uint256 public MAINNET_FORK_BLOCK_NUMBER = 17811954;

    address public owner;
    address public governance;
    address public controller;
    address public nonFungibleManagerPancake = 0x46A15B0b27311cedF172AB29E4f4766fbE7F4364;
    address public masterchefV3Pancake = 0x556B9306565093C855AEA9AE92A594704c2Cd59e;

    string public vaultName = "fPancakeV3";

    function setUp() public virtual override {
        super.setUp();

        // create a fork network
        string memory _rpcUrl = vm.rpcUrl("mainnet");
        forkNetwork = vm.createFork(_rpcUrl, MAINNET_FORK_BLOCK_NUMBER);
        vm.selectFork(forkNetwork);

        // create accounts
        owner = account0;
        vm.label(account0, "Account 0 (Test Contract address, deployer, owner)");

        governance = makeAddr("Governance 0");
        controller = makeAddr("Controller 0");
    }

    function testDeployAndInit() public virtual {
        // deploy the init contract
        initVault = new InitVault();

        // deploy all facets
        address investSubmodule = address(new InvestSubmodule());

        // deploy the vault
        vault = INonFungiblePositionVault(address(new NonFungiblePositionVault(owner, governance, controller)));

        // create the upgrade
        LibDataTypes.SubmoduleUpgrade[] memory upgrade = new LibDataTypes.SubmoduleUpgrade[](1);
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = IInvestSubmodule.doHardWork.selector;
        upgrade[0] = LibDataTypes.SubmoduleUpgrade({
            submoduleAddress: investSubmodule,
            action: LibDataTypes.SubmoduleUpgradeAction.Add,
            functionSelectors: functionSelectors
        });

        // create the token position
        address _whale = 0x350d0815Ac821769ea8DcF7bbb943eEE20ba23a8;
        address _token0 = 0x0000000000085d4780B73119b644AE5ecd22b376; // TUSD
        address _token1 = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT

        vm.prank(_whale);
        (uint256 tokenId,,,) = INonfungiblePositionManager(nonFungibleManagerPancake).mint(
            INonfungiblePositionManager.MintParams(
                _token0, _token1, 100, -276365, -276326, 29090960153366438287622, 29792654029, 0, 0, owner, 1690795199
            )
        );

        // approve the token position
        INonfungiblePositionManager(nonFungibleManagerPancake).approve(address(vault), tokenId);

        // create token position
        vault.submoduleUpgrade(
            upgrade,
            address(initVault),
            abi.encodeCall(initVault.initialize, (nonFungibleManagerPancake, masterchefV3Pancake, tokenId, vaultName))
        );
    }
}
