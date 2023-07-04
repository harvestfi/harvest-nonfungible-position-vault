//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.6;
pragma abicoder v2;

// ERC20
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

// ERC721
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

// UniswapV3 core
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

// UniswapV3 staker
import "./interface/uniswap/IUniswapV3Staker.sol";

// reentrancy guard
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

// UniswapV3 periphery contracts
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

// Harvest System
import "./inheritance/ControllableInit.sol";

// Storage for this UniVault
import "./interface/IUniVaultStorageV1.sol";

// BytesLib
import "./lib/BytesLib.sol";

contract UniVaultUpgradeableV1 is ERC20Upgradeable, ERC721HolderUpgradeable, ReentrancyGuardUpgradeable, ControllableInit {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;
    using BytesLib for bytes;

    bytes32 internal constant _DATA_CONTRACT_SLOT = 0x4c2252f3318958b38b23790562cc9d391075b8dadbfe0e707aed11afe13228b7;
    address internal constant _NFT_POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address internal constant _UNI_POOL_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    uint256 internal constant _UNDERLYING_UNIT = 1e18;
    address internal constant _V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address internal constant _V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address internal constant _UNI_STAKER = 0x1f98407aaB862CdDeF78Ed252D6f557aA5b0f00d;

    bytes32 internal constant _VAULT_PAUSE_SLOT = 0xde039a7c768eade9368187c932ab7b9ca8d5872604278b5ebfe45ab5eaf85140;

    event SwapFeeClaimed(uint256 token0Fee, uint256 token1Fee, uint256 timestamp);
    event Deposit(address indexed user, uint256 token0Amount, uint256 token1Amount);
    event Withdraw(address indexed user, uint256 token0Amount, uint256 token1Amount);

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

    bytes32 internal constant _GLOBAL_STORAGE_SLOT = 0xea3b316d3f7b97449bd56fdd0c7f95b3a874cb501e4c5d85e01bf23443a180c8;

    struct GlobalStorage {
        // direct mapping from function signature to submodule address
        mapping(bytes4 => address) functionToSubmodule;
        // Mapping from submodule hash to submodule, this is used for internal delegate calls as in doHardwork
        // where we know what submodules we are calling, but those functions are not open to the public
        mapping(bytes32 => address) submoduleAddress;
    }

    // functions are tied to a submodule
    // this allows us to update a submodule without updating all the function signature to submodule
    function functionHandler(bytes4 functionSignature) public returns (address submodule) {
        GlobalStorage storage globalStorage = getGlobalStorage();
        return globalStorage.functionToSubmodule[functionSignature];
    }

    function getGlobalStorage() internal pure returns (GlobalStorage storage globalStorage) {
        assembly {
            globalStorage.slot := _GLOBAL_STORAGE_SLOT
        }
    }

    /**
     * @dev Creates the contract and ensures that the slot matches the hash
     */
    constructor() {
        assert(_DATA_CONTRACT_SLOT == bytes32(uint256(keccak256("eip1967.uniVault.dataContract")) - 1));
        assert(_VAULT_PAUSE_SLOT == bytes32(uint256(keccak256("eip1967.univault.pause")) - 1));
        assert(_GLOBAL_STORAGE_SLOT == bytes32(uint256(keccak256("eip1967.uniVault.globalStorage")) - 1));
    }

    function vaultPaused() public returns (bool) {
        return getBoolean(_VAULT_PAUSE_SLOT);
    }

    function setVaultPause(bool _flag) public onlyGovernance {
        return setBoolean(_VAULT_PAUSE_SLOT, _flag);
    }

    function initializeEmpty() public initializer {}

    /**
     * @dev Initializes the contract. Used by the proxy pattern.
     */
    function initialize(uint256 _tokenId, address _dataContract, address _storage, address _zapContract) public initializer {
        // initializing the governance for the contract
        ControllableInit.initialize(_storage);
        // sets data storage contract to the right slot and initializes it
        setAddress(_DATA_CONTRACT_SLOT, _dataContract);

        IERC721Upgradeable(_NFT_POSITION_MANAGER).transferFrom(msg.sender, address(this), _tokenId);

        // fetch info from nft.
        (,, address _token0, address _token1, uint24 _fee, int24 _tickLower, int24 _tickUpper, uint256 _initialLiquidity,,,,) =
            INonfungiblePositionManager(_NFT_POSITION_MANAGER).positions(_tokenId);

        IUniVaultStorageV1(_dataContract).initializeByVault(_token0, _token1, _fee, _tickLower, _tickUpper, _zapContract);
        // initializing the vault token. By default, it has 18 decimals.
        __ERC20_init_unchained(
            string(abi.encodePacked("fUniV3_", ERC20Upgradeable(_token0).symbol(), "_", ERC20Upgradeable(_token1).symbol())),
            string(abi.encodePacked("fUniV3_", ERC20Upgradeable(_token0).symbol(), "_", ERC20Upgradeable(_token1).symbol()))
        );

        // set the NFT ID in the data contract
        getStorage().setPosId(_tokenId);
        // mint the initial shares and send them to the specified recipient, as well as overflow of the tokens

        _mint(msg.sender, uint256(_initialLiquidity));
    }

    function configureVault(
        address submoduleDeposit,
        address _feeRewardForwarder,
        uint256 _feeRatio,
        address _platformTarget,
        uint256 _platformRatio
    ) public onlyGovernance {
        getStorage().configureFees(_feeRewardForwarder, _feeRatio, _platformTarget, _platformRatio);

        setSubmodule(keccak256("deposit"), submoduleDeposit);
    }

    /**
     * Does the hard work. Only whitelisted chads.
     */
    function doHardWork() external onlyControllerOrGovernance {
        address rewardSubmodule = submoduleAddress(keccak256("reward"));
        address depositSubmodule = submoduleAddress(keccak256("deposit"));
        bool success;
        bytes memory data;
        string memory revertMsg;
        // Reward: Pre-process & Claiming & Liquidate
        if (rewardSubmodule != address(0)) {
            (success, data) = (rewardSubmodule).delegatecall(abi.encodeWithSignature("doHardwork_preprocessForReward()"));
            revertMsg = data._getRevertMsgFromRes();
            require(success, revertMsg);
        }

        // Deposit submodule collect fees & zap & increase liquidity : compoundRewards()
        // Does not emit the APR event
        (success, data) = (depositSubmodule).delegatecall(abi.encodeWithSignature("compoundRewards()"));
        revertMsg = data._getRevertMsgFromRes();
        require(success, revertMsg);

        // Deposit submodule collect fees & zap & increase liquidity : collectFeesAndCompound()
        // Does not emits the APR event
        (success, data) = (depositSubmodule).delegatecall(abi.encodeWithSignature("collectFeesAndCompound()"));
        revertMsg = data._getRevertMsgFromRes();
        require(success, revertMsg);

        // Reward: Post-process
        if (rewardSubmodule != address(0)) {
            (success, data) = (rewardSubmodule).delegatecall(abi.encodeWithSignature("doHardwork_postprocessForReward()"));
            revertMsg = data._getRevertMsgFromRes();
            require(success, revertMsg);
        }
    }

    /**
     * @dev Returns the total liquidity stored in the position
     * Dev Note: need to turn on the solc optimizer otherwise the compiler
     * will throw stack too deep on this function
     */
    function underlyingBalanceWithInvestment() public view returns (uint256) {
        // note that the liquidity is not a token, so there is no local balance added
        (,,,,,,, uint128 liquidity,,,,) = INonfungiblePositionManager(_NFT_POSITION_MANAGER).positions(getStorage().posId());
        return liquidity;
    }

    /**
     * @dev A dummy method to get the controller working
     */
    function setStrategy(address unused) public onlyControllerOrGovernance {
        // intentionally a no-op
    }

    /**
     * @dev A dummy method to get the controller working
     */
    function strategy() public view returns (address) {
        return address(this);
    }

    /**
     * @dev Sets the Zap contract
     */
    function setZapContract(address newAddress) public onlyGovernance {
        getStorage().setZapContract(newAddress);
    }

    /**
     * @dev Returns the price per full share, scaled to 1e18
     */
    function getPricePerFullShare() public view returns (uint256) {
        return totalSupply() == 0 ? _UNDERLYING_UNIT : _UNDERLYING_UNIT.mul(underlyingBalanceWithInvestment()).div(totalSupply());
    }

    /**
     * @dev Convenience getter for the data contract.
     */
    function getStorage() public view returns (IUniVaultStorageV1) {
        return IUniVaultStorageV1(getAddress(_DATA_CONTRACT_SLOT));
    }

    /**
     * @dev Convenience getter for token0.
     */
    function token0() public view returns (IERC20Upgradeable) {
        return IERC20Upgradeable(getStorage().token0());
    }

    /**
     * @dev Convenience getter for token1.
     */
    function token1() public view returns (IERC20Upgradeable) {
        return IERC20Upgradeable(getStorage().token1());
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
     * @dev Sets an address to a slot.
     */
    function setAddress(bytes32 slot, address _address) internal {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(slot, _address)
        }
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
     * V1 Data contract & Upgradeability
     */

    // Keeping this for the legacy interface
    /**
     * @dev Configure fees
     * @param _feeRewardForwarder the address of the fee reward forwarder
     * @param _feeRatio the profit sharing fee percentage (100% = 10000)
     * @param _platformTarget the address for gas fees contributions
     * @param _platformRatio the percentage for gas fee contributions (100% = 10000)
     */
    function configureFees(address _feeRewardForwarder, uint256 _feeRatio, address _platformTarget, uint256 _platformRatio)
        external
        onlyGovernance
    {
        getStorage().configureFees(_feeRewardForwarder, _feeRatio, _platformTarget, _platformRatio);
    }

    /**
     * @dev Schedules an upgrade to the new implementation for the proxy.
     */
    function scheduleUpgrade(address impl) public onlyGovernance {
        getStorage().setNextImplementation(impl);
        getStorage().setNextImplementationTimestamp(getStorage().nextImplementationDelay().add(block.timestamp));
    }

    /**
     * @dev Tells the proxy if an upgrade is scheduled and the timelock elapsed.
     */
    function shouldUpgrade() external view returns (bool, address) {
        return (
            getStorage().nextImplementationTimestamp() != 0 && block.timestamp > getStorage().nextImplementationTimestamp()
                && getStorage().nextImplementation() != address(0),
            getStorage().nextImplementation()
        );
    }

    /**
     * @dev Completes the upgrade and resets the upgrade state to no upgrade.
     */
    function finalizeUpgrade() external onlyGovernance {
        getStorage().setNextImplementation(address(0));
        getStorage().setNextImplementationTimestamp(0);

        getStorage().setZapContract(0x9B47D39cb1b02Bb77A517fEA39963534a6243Df3);
        setSubmodule(keccak256("deposit"), 0x5736fDdd7E421B7608B5418a190A5d938b849CeB);
    }

    /**
     * @dev Increases the upgrade timelock. Governance only.
     */
    function increaseUpgradeDelay(uint256 delay) external onlyGovernance {
        getStorage().setNextImplementationDelay(delay.add(getStorage().nextImplementationDelay()));
    }

    function submoduleAddress(bytes32 submoduleHash) public view returns (address) {
        GlobalStorage storage globalStorage = getGlobalStorage();
        address currentSubmodule = globalStorage.submoduleAddress[submoduleHash];
        return currentSubmodule;
    }

    /*
    When we set a submodule, the mother vault deregisters the interface
    from the previous submodule that is registered under the hash,

    it registers the new submodule under the hash,
    then registers the interface for the new submodule
    */
    function setSubmodule(bytes32 submoduleHash, address submoduleAddr) public onlyGovernance {
        GlobalStorage storage globalStorage = getGlobalStorage();
        address oldSubmodule = globalStorage.submoduleAddress[submoduleHash];

        // if there's an old submodule, deregisters its interface
        if (oldSubmodule != address(0)) {
            (bool success, bytes memory data) =
                (oldSubmodule).delegatecall(abi.encodeWithSignature("registerInterface(bytes32,bool)", submoduleHash, false));
            string memory revertMsg = data._getRevertMsgFromRes();
            require(success, revertMsg);
        }

        // register the submodule hash
        globalStorage.submoduleAddress[submoduleHash] = submoduleAddr;

        // register interface from new submodule
        (bool success, bytes memory data) =
            (submoduleAddr).delegatecall(abi.encodeWithSignature("registerInterface(bytes32,bool)", submoduleHash, true));
        string memory revertMsg = data._getRevertMsgFromRes();
        require(success, revertMsg);
    }

    function version() public view returns (string memory) {
        return "1.1.0";
    }

    fallback() external payable {
        address targetSubmodule = functionHandler(msg.sig);
        if (targetSubmodule != address(0)) {
            // code cloned from EIP-2535
            assembly {
                // copy function selector and any arguments
                calldatacopy(0, 0, calldatasize())
                // execute function call using the targetSubmodule
                let result := delegatecall(gas(), targetSubmodule, 0, calldatasize(), 0, 0)
                // get any return value
                returndatacopy(0, 0, returndatasize())
                // return any return value or error back to the caller
                switch result
                case 0 { revert(0, returndatasize()) }
                default { return(0, returndatasize()) }
            }
        } else {
            revert("msg.sig is not assigned to submodule");
        }
    }
}
