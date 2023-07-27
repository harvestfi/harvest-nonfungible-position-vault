// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Core
import {InitVault} from "../../src/core/InitVault.sol";
import {NonFungiblePositionVault} from "../../src/core/NonFungiblePositionVault.sol";
import {InvestSubmodule} from "../../src/submodules/InvestSubmodule.sol";

// Interfaces
import {INonFungiblePositionVault} from "../../src/interfaces/core/INonFungiblePositionVault.sol";
import {IInvestSubmodule} from "../../src/interfaces/submodules/IInvestSubmodule.sol";

// Libraries
import {LibDataTypes} from "../../src/libraries/LibDataTypes.sol";

// Utilities
import {Defaults} from "../utils/Defaults.t.sol";

contract Deploy is Defaults {
    InitVault public initVault;
    INonFungiblePositionVault public vault;

    address public owner;
    address public governance;
    address public controller;

    function setUp() public virtual override {
        super.setUp();

        // deploy the init contract
        initVault = new InitVault();

        // deploy all facets
        address investSubmodule = address(new InvestSubmodule());

        owner = account0;
        vm.label(account0, "Account 0 (Test Contract address, deployer, owner)");

        governance = makeAddr("Governance 0");
        controller = makeAddr("Controller 0");

        vault = INonFungiblePositionVault(address(new NonFungiblePositionVault(owner, governance, controller)));
        LibDataTypes.SubmoduleUpgrade[] memory upgrade = new LibDataTypes.SubmoduleUpgrade[](1);
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = IInvestSubmodule.doHardWork.selector;
        upgrade[0] = LibDataTypes.SubmoduleUpgrade({
            submoduleAddress: investSubmodule,
            action: LibDataTypes.SubmoduleUpgradeAction.Add,
            functionSelectors: functionSelectors
        });

        uint256 tokenId;

        // create token position
        vault.submoduleUpgrade(upgrade, address(initVault), abi.encodeCall(initVault.initialize, (tokenId)));
    }
}
