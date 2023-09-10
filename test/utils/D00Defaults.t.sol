// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// import test base and helpers.
import "forge-std/Test.sol";

contract D00Defaults is Test {
    // Network Parameters
    uint256 public forkNetwork;
    uint256 public MAINNET_FORK_BLOCK_NUMBER = 17986801;
    uint256 public MAINNET_FORK_BLOCK_NUMBER_REWARD = 18034100;
    // System Parameters
    string public vaultName = "fPancakeV3";
    address public governance;
    address public controller;
    address public nonFungibleManagerPancake = 0x46A15B0b27311cedF172AB29E4f4766fbE7F4364;
    address public masterchefV3Pancake = 0x556B9306565093C855AEA9AE92A594704c2Cd59e;
    // Position Parameters
    address public whale = 0x598b014cbd88f3e131Fb3b9341bA57E85D8FEBc6;
    address public token0 = 0x0000000000085d4780B73119b644AE5ecd22b376;
    address public token1 = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    uint24 public fee = 100;
    int24 public tickLower = -276337;
    int24 public tickUpper = -276326;
    uint256 public amount0Desired = 122561441877773691664249;
    uint256 public amount1Desired = 128064663508;
    uint256 public amount0Min = 121335827458995953327294;
    uint256 public amount1Min = 123766189343;

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
