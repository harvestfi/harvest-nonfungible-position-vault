// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

contract OwnableWhitelist is Ownable {
    mapping(address => bool) public whitelist;

    modifier onlyWhitelisted() {
        require(whitelist[msg.sender] || msg.sender == owner(), "not allowed");
        _;
    }

    function setWhitelist(address target, bool isWhitelisted) public onlyOwner {
        whitelist[target] = isWhitelisted;
    }
}
