// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// import test base and helpers.
import "forge-std/Test.sol";

// Core / Infrastructure
import {Controller} from "../../src/controller/Controller.sol";
import {RewardForwarder} from "../../src/controller/RewardForwarder.sol";
import {ProfitSharingReceiver} from "../../src/controller/ProfitSharingReceiver.sol";
import {Storage} from "../../src/controller/inheritance/Storage.sol";

// Libraries
import {LibDataTypes} from "../../src/libraries/LibDataTypes.sol";
import {UniversalLiquidator} from "universal-liquidator/src/core/UniversalLiquidator.sol";
import {UniversalLiquidatorRegistry} from "universal-liquidator/src/core/UniversalLiquidatorRegistry.sol";
import {PancakeV3Dex} from "universal-liquidator/src/core/dexes/PancakeV3Dex.sol";
import {strings} from "lib/solidity-stringutils/src/strings.sol";

contract D00Defaults is Test {
    // Network Parameters
    uint256 public forkNetwork;
    string public _rpcUrl = vm.rpcUrl("mainnet");
    uint256 public MAINNET_FORK_BLOCK_NUMBER = 17828535; //17986801;
    bytes32 public FAST_FORWARD_TX = 0x8760f6a90fe3fb2445c5bb5235eb8d0085594a5db6c1ffa9058bc30305a537ad;
    // System Parameters
    string public vaultName = "fPancakeV3";
    address public governance;
    // Infrastructure: Controller
    Controller public controller;
    Storage public controllerStorage;
    ProfitSharingReceiver public profitSharingReceiver;
    RewardForwarder public rewardForwarder;
    uint256 public nextImplementationDelay = 43200;
    // Infrastructure: Universal Liquidator
    UniversalLiquidator public universalLiquidator;
    UniversalLiquidatorRegistry public universalLiquidatorRegistry;
    PancakeV3Dex public pancakeV3;
    // External protocols
    address public nonFungibleManagerPancake = 0x46A15B0b27311cedF172AB29E4f4766fbE7F4364;
    address public masterchefV3Pancake = 0x556B9306565093C855AEA9AE92A594704c2Cd59e;
    // Position Parameters
    address public whale = 0xBAA2847EA06cd38E06357D363409Fd92D61e9116; //0x598b014cbd88f3e131Fb3b9341bA57E85D8FEBc6;
    address public token0 = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; //0x0000000000085d4780B73119b644AE5ecd22b376;
    address public token1 = 0xdAC17F958D2ee523a2206206994597C13D831ec7; //0xdAC17F958D2ee523a2206206994597C13D831ec7;
    uint24 public fee = 100;
    int24 public tickLower = -10; //-276337;
    int24 public tickUpper = 10; //-276326;
    uint256 public amount0Desired = 439643628526; //122561441877773691664249;
    uint256 public amount1Desired = 1999999999999; //128064663508;
    uint256 public amount0Min = 0; //121335827458995953327294;
    uint256 public amount1Min = 0; //123766189343;

    function setUpUniversalLiquidator() public virtual {
        // deploy universal liquidator
        universalLiquidator = new UniversalLiquidator();
        vm.makePersistent(address(universalLiquidator));
        // deploy universal liquidator registry
        universalLiquidatorRegistry = new UniversalLiquidatorRegistry();
        vm.makePersistent(address(universalLiquidatorRegistry));
        universalLiquidator.setPathRegistry(address(universalLiquidatorRegistry));
        // deploy dexes
        pancakeV3 = new PancakeV3Dex();
        vm.makePersistent(address(pancakeV3));
        universalLiquidatorRegistry.addDex(bytes32(bytes("pancakeV3")), address(pancakeV3));
    }

    function setUpController() public virtual {
        controllerStorage = new Storage();
        profitSharingReceiver = new ProfitSharingReceiver(address(controllerStorage));
        rewardForwarder = new RewardForwarder(address(controllerStorage));
        controller =
        new Controller(address(controllerStorage), 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, governance, address(profitSharingReceiver), address(rewardForwarder), address(universalLiquidator), nextImplementationDelay);

        controllerStorage.setController(address(controller));
    }

    function setUp() public virtual {
        console2.log("\n -- Global Defaults\n");

        // create a fork network
        forkNetwork = vm.createSelectFork(_rpcUrl, MAINNET_FORK_BLOCK_NUMBER);

        governance = makeAddr("Governance 0");
        console2.log("governance address: ", governance);
        console2.log("controller address: ", address(controller));
        vm.label(governance, "Account governance");
        vm.label(address(controller), "Account controller");

        vm.startPrank(governance);

        setUpUniversalLiquidator();
        setUpController();
    }
}
