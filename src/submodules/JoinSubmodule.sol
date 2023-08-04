//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Libraries
import {AppStorage, LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibPostionManager} from "../libraries/LibPostionManager.sol";

// Helpers
import {Modifiers} from "../core/Modifiers.sol";

contract JoinSubmodule is Modifiers {
    AppStorage internal s;

    function createPosition() public {
        LibPostionManager.mint();
    }

    function stakePosition() public {
        LibPostionManager.stake();
    }
}
