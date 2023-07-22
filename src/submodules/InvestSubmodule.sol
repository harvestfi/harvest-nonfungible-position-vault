//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Helpers
import {Modifiers} from "../core/Modifiers.sol";

contract InvestSubmodule is Modifiers {
    function doHardWork() external onlyGovernanceOrController {}
}
