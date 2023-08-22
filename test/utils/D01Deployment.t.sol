// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Utilities
import {D00Defaults, console2} from "./D00Defaults.t.sol";

// Core
import {InitVault} from "../../src/core/InitVault.sol";
import {NonFungiblePositionVault} from "../../src/core/NonFungiblePositionVault.sol";
import {JoinSubmodule} from "../../src/submodules/JoinSubmodule.sol";
import {InvestSubmodule} from "../../src/submodules/InvestSubmodule.sol";
import {ExitSubmodule} from "../../src/submodules/ExitSubmodule.sol";
import {VaultInfoSubmodule} from "../../src/submodules/VaultInfoSubmodule.sol";

// Interfaces
import {INonFungiblePositionVault} from "../../src/interfaces/core/INonFungiblePositionVault.sol";
import {IJoinSubmodule} from "../../src/interfaces/submodules/IJoinSubmodule.sol";
import {IInvestSubmodule} from "../../src/interfaces/submodules/IInvestSubmodule.sol";
import {IExitSubmodule} from "../../src/interfaces/submodules/IExitSubmodule.sol";
import {IVaultInfoSubmodule} from "../../src/interfaces/submodules/IVaultInfoSubmodule.sol";

// Libraries
import {LibDataTypes} from "../../src/libraries/LibDataTypes.sol";
import {strings} from "lib/solidity-stringutils/src/strings.sol";

contract D01Deployment is D00Defaults {
    using strings for *;

    InitVault public initVault;
    INonFungiblePositionVault public vault;

    address public joinSubmodule;
    address public investSubmodule;
    address public exitSubmodule;
    address public vaultInfoSubmodule;

    address public nonFungibleManagerPancake = 0x46A15B0b27311cedF172AB29E4f4766fbE7F4364;
    address public masterchefV3Pancake = 0x556B9306565093C855AEA9AE92A594704c2Cd59e;

    function setUp() public virtual override {
        super.setUp();

        // deploy the vault
        vault = INonFungiblePositionVault(address(new NonFungiblePositionVault(governance, controller)));
    }

    function addJoinSubmodule() public virtual {
        // deploy join submodule
        joinSubmodule = address(new JoinSubmodule());

        // create the upgrade
        LibDataTypes.SubmoduleUpgrade[] memory upgrade = new LibDataTypes.SubmoduleUpgrade[](1);

        // Get all function selectors from the forge artifacts for this contract.
        bytes4[] memory functionSelectors = generateSelectors("JoinSubmodule");
        upgrade[0] = LibDataTypes.SubmoduleUpgrade({
            submoduleAddress: joinSubmodule,
            action: LibDataTypes.SubmoduleUpgradeAction.Add,
            functionSelectors: functionSelectors
        });

        vault.submoduleUpgrade(upgrade, address(0), "");
    }

    function addInvestSubmodule() public virtual {
        // deploy invest submodule
        investSubmodule = address(new InvestSubmodule());

        // create the upgrade
        LibDataTypes.SubmoduleUpgrade[] memory upgrade = new LibDataTypes.SubmoduleUpgrade[](1);
        bytes4[] memory functionSelectors = generateSelectors("InvestSubmodule");
        upgrade[0] = LibDataTypes.SubmoduleUpgrade({
            submoduleAddress: investSubmodule,
            action: LibDataTypes.SubmoduleUpgradeAction.Add,
            functionSelectors: functionSelectors
        });

        vault.submoduleUpgrade(upgrade, address(0), "");
    }

    function addExitSubmodule() public virtual {
        // deploy exit submodule
        exitSubmodule = address(new ExitSubmodule());

        // create the upgrade
        LibDataTypes.SubmoduleUpgrade[] memory upgrade = new LibDataTypes.SubmoduleUpgrade[](1);
        bytes4[] memory functionSelectors = generateSelectors("ExitSubmodule");
        upgrade[0] = LibDataTypes.SubmoduleUpgrade({
            submoduleAddress: exitSubmodule,
            action: LibDataTypes.SubmoduleUpgradeAction.Add,
            functionSelectors: functionSelectors
        });

        vault.submoduleUpgrade(upgrade, address(0), "");
    }

    function addVaultInfoSubmodule() public virtual {
        // deploy vault info submodule
        vaultInfoSubmodule = address(new VaultInfoSubmodule());

        // create the upgrade
        LibDataTypes.SubmoduleUpgrade[] memory upgrade = new LibDataTypes.SubmoduleUpgrade[](1);
        bytes4[] memory functionSelectors = generateSelectors("VaultInfoSubmodule");
        upgrade[0] = LibDataTypes.SubmoduleUpgrade({
            submoduleAddress: vaultInfoSubmodule,
            action: LibDataTypes.SubmoduleUpgradeAction.Add,
            functionSelectors: functionSelectors
        });

        vault.submoduleUpgrade(upgrade, address(0), "");
    }

    // return array of function selectors for given facet name
    function generateSelectors(string memory _facetName) internal returns (bytes4[] memory selectors) {
        //get string of contract methods
        string[] memory cmd = new string[](4);
        cmd[0] = "forge";
        cmd[1] = "inspect";
        cmd[2] = _facetName;
        cmd[3] = "methods";
        bytes memory res = vm.ffi(cmd);
        string memory st = string(res);

        // extract function signatures and take first 4 bytes of keccak
        strings.slice memory s = st.toSlice();
        strings.slice memory delim = ":".toSlice();
        strings.slice memory delim2 = ",".toSlice();
        selectors = new bytes4[]((s.count(delim)));

        for (uint256 i = 0; i < selectors.length; i++) {
            s.split('"'.toSlice());
            selectors[i] = bytes4(s.split(delim).until('"'.toSlice()).keccak());
            s.split(delim2);
        }
        return selectors;
    }
}
