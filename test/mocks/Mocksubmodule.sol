//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";

// Libraries
import {AppStorage, LibAppStorage} from "./MockLibAppStorage.sol";

contract MockSubmodule {
    AppStorage internal s;

    function setOne(uint256 _value) public {
        s.checkOne = _value;
    }

    function getOne() public view returns (uint256) {
        return s.checkOne;
    }
}
