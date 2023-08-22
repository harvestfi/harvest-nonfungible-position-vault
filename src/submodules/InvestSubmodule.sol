//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Interfaces
import {IInvestSubmodule} from "../interfaces/submodules/IInvestSubmodule.sol";

// Helpers
import {Modifiers} from "../core/Modifiers.sol";

contract InvestSubmodule is Modifiers, IInvestSubmodule {
    function doHardWork() external override onlyGovernanceOrController {
        // claim rewards
        // - harvest (LibPositionManager)
        // - collect (LibPositionManager)
        // liquidate through universal liquidators
        // increase liquidity (LibPositionManager)
    }
}
