// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// import test base and helpers.
import "forge-std/Test.sol";

contract D00Defaults is Test {
    uint256 public forkNetwork;
    uint256 public MAINNET_FORK_BLOCK_NUMBER = 17811954;

    address public governance;
    address public controller;

    function setUp() public virtual {
        console2.log("\n -- Global Defaults\n");

        // create a fork network
        string memory _rpcUrl = vm.rpcUrl("mainnet");
        forkNetwork = vm.createFork(_rpcUrl, MAINNET_FORK_BLOCK_NUMBER);
        vm.selectFork(forkNetwork);

        governance = makeAddr("Governance 0");
        controller = makeAddr("Controller 0");
        console2.log("governance address: ", governance);
        console2.log("controller address: ", controller);
        vm.label(governance, "Account governance");
        vm.label(controller, "Account controller");

        vm.startPrank(governance);
    }
}
