// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Submodules
import {IConfigureSubmodule} from "../submodules/IConfigureSubmodule.sol";
import {IUpgradeSubmodule} from "../submodules/IUpgradeSubmodule.sol";
import {IGovernanceSubmodule} from "../submodules/IGovernanceSubmodule.sol";
import {IFunctionInfoSubmodule} from "../submodules/IFunctionInfoSubmodule.sol";
import {IInvestSubmodule} from "../submodules/IInvestSubmodule.sol";

interface INonFungiblePositionVault is
    IConfigureSubmodule,
    IUpgradeSubmodule,
    IGovernanceSubmodule,
    IFunctionInfoSubmodule,
    IInvestSubmodule
{}
