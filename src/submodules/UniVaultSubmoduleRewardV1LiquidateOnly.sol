//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

// ERC20
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

// UniswapV3 core
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

// reentrancy guard
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

// Harvest System
import "../interface/IFeeRewardForwarderV6.sol";
import "../inheritance/ControllableInit.sol";

// Storage for this UniVault
import "../interface/IUniVaultStorageV1.sol";

// BytesLib
import "../lib/BytesLib.sol";

// UL
import "../interface/IUniversalLiquidatorRegistry.sol";
import "../interface/IUniversalLiquidator.sol";

contract UniVaultSubmoduleRewardV1LiquidateOnly is ReentrancyGuardUpgradeable, ControllableInit {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;
    using BytesLib for bytes;

    // We expect all reward submodule to have this reward token list
    bytes32 internal constant _GLOBAL_STORAGE_SLOT = 0xea3b316d3f7b97449bd56fdd0c7f95b3a874cb501e4c5d85e01bf23443a180c8;
    bytes32 internal constant _LOCAL_STORAGE_SLOT = 0x35ecaa58d3f4a450860c27672873a69d5a15a6ad65d4531955c5d03adc76b07e;
    bytes32 internal constant _DATA_CONTRACT_SLOT = 0x4c2252f3318958b38b23790562cc9d391075b8dadbfe0e707aed11afe13228b7;
    bytes32 internal constant _VAULT_PAUSE_SLOT = 0xde039a7c768eade9368187c932ab7b9ca8d5872604278b5ebfe45ab5eaf85140;
    address internal constant _UNI_POOL_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    address internal constant _UL_REGISTRY_ADDRESS = 0x7882172921E99d590E097cD600554339fBDBc480;

    struct LocalStorage {
        address[] tokens;
        mapping(address => bool) tokenExists;
        mapping(address => bytes32[]) dexes;
        mapping(address => address[]) path;
    }

    // This is the storage for the mother level vault
    // it is used here to register / deregister interface
    struct GlobalStorage {
        // direct mapping from function signature to submodule address
        mapping(bytes4 => address) functionToSubmodule;
        // Mapping from submodule hash to submodule, this is used for internal delegate calls as in doHardwork
        // where we know what submodules we are calling, but those functions are not open to the public
        mapping(bytes32 => address) submoduleAddress;
    }

    /**
     * @dev Ensures that the price between submitting the transaction and when
     * the transaction gets mined did not move (checks slippage)
     */
    modifier checkSqrtPriceX96(uint256 offChainSqrtPriceX96, uint256 tolerance) {
        uint256 current = uint256(getSqrtPriceX96());
        uint256 step = offChainSqrtPriceX96.mul(tolerance).div(1000);
        require(current < offChainSqrtPriceX96.add(step), "Price too high");
        require(current > offChainSqrtPriceX96.sub(step), "Price too low");
        _;
    }

    modifier checkVaultNotPaused() {
        require(!getBoolean(_VAULT_PAUSE_SLOT), "Vault is paused");
        _;
    }

    modifier onlySelf() {
        require(msg.sender == address(this), "only for internal");
        _;
    }

    constructor() {
        assert(_LOCAL_STORAGE_SLOT == bytes32(uint256(keccak256("eip1967.uniVault.rewardSubmodule.localStorage")) - 1));
    }

    function getGlobalStorage() internal pure returns (GlobalStorage storage globalStorage) {
        assembly {
            globalStorage.slot := _GLOBAL_STORAGE_SLOT
        }
    }

    function registerInterface(bytes32 submoduleHash, bool register) public {
        GlobalStorage storage globalStorage = getGlobalStorage();
        address currentSubmoduleAddress = globalStorage.submoduleAddress[submoduleHash];

        uint256 functionNum = 4;
        bytes4[4] memory functionLists = [
            bytes4(keccak256("rewardToken(uint256)")),
            bytes4(keccak256("setLiquidationPath(address,bytes32[],address[])")),
            bytes4(keccak256("addRewardTokens(address[])")),
            bytes4(keccak256("removeRewardToken(uint256)"))
        ];

        address registeringSubmodule = (register) ? currentSubmoduleAddress : address(0);
        for (uint256 i = 0; i < functionNum; i++) {
            globalStorage.functionToSubmodule[functionLists[i]] = registeringSubmodule;
        }
    }

    function rewardToken(uint256 i) public view returns (address) {
        LocalStorage storage localStorage = getLocalStorage();
        return localStorage.tokens[i];
    }

    // rewardToken to liquidate
    // guarded by onlyGovernance
    function setLiquidationPath(address _rewardToken, bytes32[] memory _dexes, address[] memory _path) public onlyGovernance {
        LocalStorage storage localStorage = getLocalStorage();
        localStorage.dexes[_rewardToken] = _dexes;
        localStorage.path[_rewardToken] = _path;
    }

    // Guarded by onlyGovernance in the main contract.
    function addRewardTokens(address[] memory newTokens) public onlyGovernance {
        LocalStorage storage localStorage = getLocalStorage();
        uint256 newTokenLength = newTokens.length;
        for (uint256 i = 0; i < newTokenLength; i++) {
            require(!localStorage.tokenExists[newTokens[i]], "Token already exists");
            require(
                (newTokens[i] != address(getStorage().token0())) && (newTokens[i] != address(getStorage().token1())),
                "Reward token cannot be token0/token1"
            );
            localStorage.tokens.push(newTokens[i]);
            localStorage.tokenExists[newTokens[i]] = true;
        }
    }

    // Guarded by onlyGovernance in the main contract.
    function removeRewardToken(uint256 i) public onlyGovernance {
        LocalStorage storage localStorage = getLocalStorage();
        require(i < localStorage.tokens.length, "i out of bounds");
        address removedToken = localStorage.tokens[i];
        localStorage.tokens[i] = localStorage.tokens[localStorage.tokens.length - 1];
        localStorage.tokens.pop();
        localStorage.tokenExists[removedToken] = false;
    }

    // For stakewise, there are multiple rewards
    // We assume that they are already sent to vault by the bot.
    function doHardwork_preprocessForReward() public {
        _liquidateRewards();
    }

    function _liquidateRewards() internal {
        LocalStorage storage localStorage = getLocalStorage();

        uint256 rewardCount = localStorage.tokens.length;

        for (uint256 i = 0; i < rewardCount; i++) {
            address _rewardToken = localStorage.tokens[i];
            uint256 remainingAmount = IERC20Upgradeable(_rewardToken).balanceOf(address(this));
            if (remainingAmount > 0) {
                address ulAddress = IUniversalLiquidatorRegistry(_UL_REGISTRY_ADDRESS).universalLiquidator();

                IERC20Upgradeable(_rewardToken).safeApprove(ulAddress, 0);
                IERC20Upgradeable(_rewardToken).safeApprove(ulAddress, remainingAmount);
                IUniversalLiquidator(ulAddress).swapTokenOnMultipleDEXes(
                    remainingAmount, 0, address(this), localStorage.dexes[_rewardToken], localStorage.path[_rewardToken]
                );
            }
        }
    }

    function doHardwork_postprocessForReward() public {}

    function getLocalStorage() internal pure returns (LocalStorage storage localStorage) {
        assembly {
            localStorage.slot := _LOCAL_STORAGE_SLOT
        }
    }

    /**
     * @dev Convenience getter for the data contract.
     */
    function getStorage() public view returns (IUniVaultStorageV1) {
        return IUniVaultStorageV1(getAddress(_DATA_CONTRACT_SLOT));
    }

    /**
     * @dev Reads an address from a slot.
     */
    function getAddress(bytes32 slot) internal view returns (address str) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            str := sload(slot)
        }
    }

    /**
     * @dev Sets an boolean to a slot.
     */
    function setBoolean(bytes32 slot, bool _flag) internal {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(slot, _flag)
        }
    }

    /**
     * @dev Reads an address from a slot.
     */
    function getBoolean(bytes32 slot) internal view returns (bool str) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            str := sload(slot)
        }
    }

    /**
     * @dev Convenience getter for the current sqrtPriceX96 of the Uniswap pool.
     */
    function getSqrtPriceX96() public view returns (uint160) {
        address poolAddr =
            IUniswapV3Factory(_UNI_POOL_FACTORY).getPool(getStorage().token0(), getStorage().token1(), getStorage().fee());
        (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(poolAddr).slot0();
        return sqrtPriceX96;
    }
}
