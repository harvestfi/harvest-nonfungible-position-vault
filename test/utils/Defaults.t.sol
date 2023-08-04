// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// import test base and helpers.
import "forge-std/Test.sol";

contract Defaults is Test {
    address public account0 = address(this);

    function setUp() public virtual {
        console2.log("\n -- Global Defaults\n");

        console2.log("Test contract address, aka account0 deployer, owner", address(this));
        console2.log("msg.sender during setup", msg.sender);
    }
}
