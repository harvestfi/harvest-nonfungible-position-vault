//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Interfaces
import {IExitSubmodule} from "../interfaces/submodules/IExitSubmodule.sol";

// Helpers
import {Modifiers} from "../core/Modifiers.sol";

contract ExitSubmodule is Modifiers, IExitSubmodule {
    function exitFullAmount() external {}
}
