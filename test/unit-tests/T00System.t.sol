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

    address public nonFungibleManagerPancake = 0x46A15B0b27311cedF172AB29E4f4766fbE7F4364;
    address public masterchefV3Pancake = 0x556B9306565093C855AEA9AE92A594704c2Cd59e;

    string public vaultName = "fPancakeV3";

    function setUp() public virtual override {
        super.setUp();
    }

    function testDeployAndInit() public virtual {
        // deploy the init contract
        initVault = new InitVault();

        // deploy all facets
        address investSubmodule = address(new InvestSubmodule());

        // deploy the vault
        vault = INonFungiblePositionVault(address(new NonFungiblePositionVault(governance, controller)));

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

        changePrank(_whale);
        (uint256 tokenId,,,) = INonfungiblePositionManager(nonFungibleManagerPancake).mint(
            INonfungiblePositionManager.MintParams(
                _token0, _token1, 100, -276365, -276326, 29090960153366438287622, 29792654029, 0, 0, address(vault), 1690795199
            )
        );
        changePrank(governance);

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
        vault = INonFungiblePositionVault(address(new NonFungiblePositionVault(governance, controller)));
        // deploy the mock submodule
        MockSubmodule mockSubmodule = new MockSubmodule();
        // deploy the mock submodule v2
        MockSubmoduleV2 mockSubmoduleV2 = new MockSubmoduleV2();
        // create the first upgrade
        LibDataTypes.SubmoduleUpgrade[] memory upgrade = new LibDataTypes.SubmoduleUpgrade[](1);
        bytes4[] memory functionSelectors = new bytes4[](2);
        functionSelectors[0] = MockSubmodule.setOne.selector;
        functionSelectors[1] = MockSubmodule.getOne.selector;
        upgrade[0] = LibDataTypes.SubmoduleUpgrade({
            submoduleAddress: address(mockSubmodule),
            action: LibDataTypes.SubmoduleUpgradeAction.Add,
            functionSelectors: functionSelectors
        });
        vault.submoduleUpgrade(upgrade, address(0), "");
        // set the variables
        (bool result, bytes memory resultData) = address(vault).call(abi.encodeWithSelector(MockSubmodule.setOne.selector, 123));
        assertTrue(result, "setOne should succeed");
        // get the variable vaule
        (result, resultData) = address(vault).call(abi.encodeWithSelector(MockSubmodule.getOne.selector));
        assertEq(abi.decode(resultData, (uint256)), 123);
        // create the second upgrade
        LibDataTypes.SubmoduleUpgrade[] memory upgrade2 = new LibDataTypes.SubmoduleUpgrade[](1);
        bytes4[] memory functionSelectors2 = new bytes4[](2);
        functionSelectors2[0] = MockSubmoduleV2.setTwo.selector;
        functionSelectors2[1] = MockSubmoduleV2.getTwo.selector;
        upgrade2[0] = LibDataTypes.SubmoduleUpgrade({
            submoduleAddress: address(mockSubmoduleV2),
            action: LibDataTypes.SubmoduleUpgradeAction.Add,
            functionSelectors: functionSelectors2
        });
        vault.submoduleUpgrade(upgrade2, address(0), "");
        LibDataTypes.SubmoduleUpgrade[] memory upgrade3 = new LibDataTypes.SubmoduleUpgrade[](1);
        bytes4[] memory functionSelectors3 = new bytes4[](2);
        functionSelectors3[0] = MockSubmoduleV2.setOne.selector;
        functionSelectors3[1] = MockSubmoduleV2.getOne.selector;
        upgrade3[0] = LibDataTypes.SubmoduleUpgrade({
            submoduleAddress: address(mockSubmoduleV2),
            action: LibDataTypes.SubmoduleUpgradeAction.Replace,
            functionSelectors: functionSelectors3
        });
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
