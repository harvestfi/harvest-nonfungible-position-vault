// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Utilities
import {D00Defaults, console2} from "../utils/D00Defaults.t.sol";

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

// Mocks
import {MockVault} from "../mocks/MockVault.sol";
import {MockSubmodule} from "../mocks/MockSubmodule.sol";
import {MockSubmoduleV2} from "../mocks/MockSubmoduleV2.sol";

contract System is D00Defaults {
    InitVault public initVault;
    INonFungiblePositionVault public vault;

    function setUp() public virtual override {
        super.setUp();
    }

    function testDeployAndInit() public virtual {
        // deploy the init contract
        initVault = new InitVault();

        // deploy all facets
        address investSubmodule = address(new InvestSubmodule());

        // deploy the vault
        vault = INonFungiblePositionVault(address(new NonFungiblePositionVault(governance, address(controller))));

        // create the upgrade
        //LibDataTypes.SubmoduleUpgrade memory upgrade = new LibDataTypes.SubmoduleUpgrade;
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = IInvestSubmodule.doHardWork.selector;
        LibDataTypes.SubmoduleUpgrade memory upgrade = LibDataTypes.SubmoduleUpgrade({
            submoduleAddress: investSubmodule,
            action: LibDataTypes.SubmoduleUpgradeAction.Add,
            functionSelectors: functionSelectors
        });

        changePrank(whale);
        (uint256 tokenId,,,) = INonfungiblePositionManager(nonFungibleManagerPancake).mint(
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

        //schedule the upgrade
        vault.scheduleUpgrade(upgrade, address(initVault));

        // initialize the vault
        vault.submoduleUpgrade(
            upgrade,
            address(initVault),
            abi.encodeCall(initVault.initialize, (nonFungibleManagerPancake, masterchefV3Pancake, tokenId, vaultName))
        );
    }

    // TODO: Here could apply fuzzer as input
    function testStorageUpgrade() public virtual {
        // deploy the vault
        vault = INonFungiblePositionVault(address(new NonFungiblePositionVault(governance, address(controller))));
        // deploy the mock submodule
        MockSubmodule mockSubmodule = new MockSubmodule();
        // deploy the mock submodule v2
        MockSubmoduleV2 mockSubmoduleV2 = new MockSubmoduleV2();
        // create the first upgrade
        bytes4[] memory functionSelectors = new bytes4[](2);
        functionSelectors[0] = MockSubmodule.setOne.selector;
        functionSelectors[1] = MockSubmodule.getOne.selector;
        LibDataTypes.SubmoduleUpgrade memory upgrade = LibDataTypes.SubmoduleUpgrade({
            submoduleAddress: address(mockSubmodule),
            action: LibDataTypes.SubmoduleUpgradeAction.Add,
            functionSelectors: functionSelectors
        });
        //schedule the upgrade
        vault.scheduleUpgrade(upgrade, address(0));

        vault.submoduleUpgrade(upgrade, address(0), "");
        // set the variables
        (bool result, bytes memory resultData) = address(vault).call(abi.encodeWithSelector(MockSubmodule.setOne.selector, 123));
        assertTrue(result, "setOne should succeed");
        // get the variable vaule
        (result, resultData) = address(vault).call(abi.encodeWithSelector(MockSubmodule.getOne.selector));
        assertEq(abi.decode(resultData, (uint256)), 123);
        // create the second upgrade
        bytes4[] memory functionSelectors2 = new bytes4[](2);
        functionSelectors2[0] = MockSubmoduleV2.setTwo.selector;
        functionSelectors2[1] = MockSubmoduleV2.getTwo.selector;
        LibDataTypes.SubmoduleUpgrade memory upgrade2 = LibDataTypes.SubmoduleUpgrade({
            submoduleAddress: address(mockSubmoduleV2),
            action: LibDataTypes.SubmoduleUpgradeAction.Add,
            functionSelectors: functionSelectors2
        });
        //schedule the upgrade
        vault.scheduleUpgrade(upgrade2, address(0));

        vault.submoduleUpgrade(upgrade2, address(0), "");
        bytes4[] memory functionSelectors3 = new bytes4[](2);
        functionSelectors3[0] = MockSubmoduleV2.setOne.selector;
        functionSelectors3[1] = MockSubmoduleV2.getOne.selector;
        LibDataTypes.SubmoduleUpgrade memory upgrade3 = LibDataTypes.SubmoduleUpgrade({
            submoduleAddress: address(mockSubmoduleV2),
            action: LibDataTypes.SubmoduleUpgradeAction.Replace,
            functionSelectors: functionSelectors3
        });
        //schedule the upgrade
        vault.scheduleUpgrade(upgrade3, address(0));

        vault.submoduleUpgrade(upgrade3, address(0), "");
        // set the variables
        (result, resultData) = address(vault).call(abi.encodeWithSelector(MockSubmoduleV2.setTwo.selector, 456));
        assertTrue(result, "setTwo should succeed");
        // get the variables vaule
        (result, resultData) = address(vault).call(abi.encodeWithSelector(MockSubmoduleV2.getOne.selector));
        assertEq(abi.decode(resultData, (uint256)), 123);
        (result, resultData) = address(vault).call(abi.encodeWithSelector(MockSubmoduleV2.getTwo.selector));
        assertEq(abi.decode(resultData, (uint256)), 456);
        // reset the variables
        (result, resultData) = address(vault).call(abi.encodeWithSelector(MockSubmoduleV2.setOne.selector, 789));
        assertTrue(result, "setOne should succeed");
        // get the variables vaule
        (result, resultData) = address(vault).call(abi.encodeWithSelector(MockSubmoduleV2.getOne.selector));
        assertEq(abi.decode(resultData, (uint256)), 789);
        (result, resultData) = address(vault).call(abi.encodeWithSelector(MockSubmoduleV2.getTwo.selector));
        assertEq(abi.decode(resultData, (uint256)), 456);
    }
}
