//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Libraries
import {AppStorage, LibAppStorage} from "./MockLibAppStorageV2.sol";

contract MockSubmoduleV2 {
    AppStorage internal s;

    function setOne(uint256 _value) public {
        s.checkOne = _value;
    }

    function setTwo(uint256 _value) public {
        s.checkTwo = _value;
    }

    function getOne() public view returns (uint256) {
        return s.checkOne;
    }

    function getTwo() public view returns (uint256) {
        return s.checkTwo;
    }
}
