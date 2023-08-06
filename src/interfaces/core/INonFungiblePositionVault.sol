// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// External Packages
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// Submodules
import {IConfigureSubmodule} from "../submodules/IConfigureSubmodule.sol";
import {IExitSubmodule} from "../submodules/IExitSubmodule.sol";
import {IFunctionInfoSubmodule} from "../submodules/IFunctionInfoSubmodule.sol";
import {IGovernanceSubmodule} from "../submodules/IGovernanceSubmodule.sol";
import {IInvestSubmodule} from "../submodules/IInvestSubmodule.sol";
import {IJoinSubmodule} from "../submodules/IJoinSubmodule.sol";
import {IUpgradeSubmodule} from "../submodules/IUpgradeSubmodule.sol";
import {IVaultInfoSubmodule} from "../submodules/IVaultInfoSubmodule.sol";

interface INonFungiblePositionVault is
    IERC20Upgradeable,
    IConfigureSubmodule,
    IUpgradeSubmodule,
    IGovernanceSubmodule,
    IFunctionInfoSubmodule,
    IInvestSubmodule
{}
