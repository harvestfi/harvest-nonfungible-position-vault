// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Submodules
import {IConfigureSubmodule} from "../submodules/IConfigureSubmodule.sol";
import {IUpgradeSubmodule} from "../submodules/IUpgradeSubmodule.sol";
import {IGovernanceSubmodule} from "../submodules/IGovernanceSubmodule.sol";
import {IFunctionInfoSubmodule} from "../submodules/IFunctionInfoSubmodule.sol";
import {ITokenizedVaultSubmodule} from "../submodules/ITokenizedVaultSubmodule.sol";
import {IInvestSubmodule} from "../submodules/IInvestSubmodule.sol";
import {IJoinSubmodule} from "../submodules/IJoinSubmodule.sol";
import {IExitSubmodule} from "../submodules/IExitSubmodule.sol";
import {IVaultInfoSubmodule} from "../submodules/IVaultInfoSubmodule.sol";

interface INonFungiblePositionVault is
    IConfigureSubmodule,
    IUpgradeSubmodule,
    IGovernanceSubmodule,
    IFunctionInfoSubmodule,
    ITokenizedVaultSubmodule,
    IJoinSubmodule,
    IInvestSubmodule,
    IExitSubmodule,
    IVaultInfoSubmodule
{}
