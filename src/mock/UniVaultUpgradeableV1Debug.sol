//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;
pragma abicoder v2;

import "hardhat/console.sol";

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
import "../interface/uniswap/IUniswapV3Staker.sol";

// reentrancy guard
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

// UniswapV3 periphery contracts
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

// Harvest System
import "../inheritance/ControllableInit.sol";

// Storage for this UniVault
import "../interface/IUniVaultStorageV1.sol";

// BytesLib
import "../lib/BytesLib.sol";

contract UniVaultUpgradeableV1Debug is ERC20Upgradeable, ERC721HolderUpgradeable, ReentrancyGuardUpgradeable, ControllableInit {
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

    bytes32 internal constant _VAULT_SUBMODULE_DEPOSIT_SLOT = 0xc5c3d06316be7a352fe891a86b6ce1aaea8a598ad7fe60f2036cf375a853829d;
    bytes32 internal constant _VAULT_SUBMODULE_REWARD_SLOT = 0xd5578a737a3565a899d75eebe454c1e08e53168708b84739f7bbf71557b1f5ba;

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

    modifier checkSubmoduleConfig() {
        require(
            getAddress(_VAULT_SUBMODULE_DEPOSIT_SLOT) != address(0) && getAddress(_VAULT_SUBMODULE_REWARD_SLOT) != address(0),
            "submodules not configured"
        );
        _;
    }

    /**
     * @dev Creates the contract and ensures that the slot matches the hash
     */
    constructor() {
        assert(_DATA_CONTRACT_SLOT == bytes32(uint256(keccak256("eip1967.uniVault.dataContract")) - 1));
        assert(_VAULT_SUBMODULE_DEPOSIT_SLOT == bytes32(uint256(keccak256("eip1967.uniVault.vaultSubmodule.deposit")) - 1));
        assert(_VAULT_SUBMODULE_REWARD_SLOT == bytes32(uint256(keccak256("eip1967.uniVault.vaultSubmodule.reward")) - 1));
    }

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
        address _submoduleDeposit,
        address _submoduleReward,
        address _feeRewardForwarder,
        uint256 _feeRatio,
        address _platformTarget,
        uint256 _platformRatio
    ) public onlyGovernance {
        _setSubmodules(_submoduleDeposit, _submoduleReward);

        getStorage().configureFees(_feeRewardForwarder, _feeRatio, _platformTarget, _platformRatio);
    }

    function setSubmodules(address _submoduleDeposit, address _submoduleReward) public onlyGovernance {
        _setSubmodules(_submoduleDeposit, _submoduleReward);
    }

    function _setSubmodules(address _submoduleDeposit, address _submoduleReward) internal {
        setAddress(_VAULT_SUBMODULE_DEPOSIT_SLOT, _submoduleDeposit);
        setAddress(_VAULT_SUBMODULE_REWARD_SLOT, _submoduleReward);
    }

    /**
     * Removes the liquidity from v2 and deposits it into v3
     * @param _amount the amount of the V2 tokens to migrate
     * @param _minAmount0 the amount of token0 that needs to be extracted from the v2 pair
     * @param _minAmount1 the amount of token1 that needs to be extracted from the v2 pair
     * @param _zapFunds indicates if the tokens should be traded to the required ratio
     * @param _sweep indicates if the tokens left over should be send to the msg.sender
     * @param _sqrtRatioX96 the sqrtRatioX96 when the transaction is being submitted
     * @param _tolerance indicates the maximum accepted deviation in percents (100% is 1000) from the ratio
     */
    function migrateToNftFromV2(
        uint256 _amount,
        uint256 _minAmount0,
        uint256 _minAmount1,
        bool _zapFunds,
        bool _sweep,
        uint256 _sqrtRatioX96,
        uint256 _tolerance
    ) public checkSqrtPriceX96(_sqrtRatioX96, _tolerance) nonReentrant checkSubmoduleConfig {
        (bool success, bytes memory data) = (getAddress(_VAULT_SUBMODULE_DEPOSIT_SLOT)).delegatecall(msg.data);
        string memory revertMsg = data._getRevertMsgFromRes();
        require(success, revertMsg);
    }

    /**
     * @dev Makes a deposit for the sender.
     * @param _amount0 the amount of token0 to deposit
     * @param _amount1 the amount of token1 to deposit
     * @param _zapFunds indicates if the tokens should be traded to the required ratio
     * @param _sweep indicates if the tokens left over should be send to the msg.sender
     * @param _sqrtRatioX96 the sqrtRatioX96 when the transaction is being submitted
     * @param _tolerance indicates the maximum accepted deviation in percents (100% is 1000) from the ratio
     */
    function deposit(uint256 _amount0, uint256 _amount1, bool _zapFunds, bool _sweep, uint256 _sqrtRatioX96, uint256 _tolerance)
        public
        checkSqrtPriceX96(_sqrtRatioX96, _tolerance)
        nonReentrant
        checkSubmoduleConfig
    {
        (bool success, bytes memory data) = (getAddress(_VAULT_SUBMODULE_DEPOSIT_SLOT)).delegatecall(msg.data);
        string memory revertMsg = data._getRevertMsgFromRes();
        require(success, revertMsg);
    }

    /**
     * @dev Makes a deposit for the sender by extracting funds from a matching NFT.
     * @param _tokenId the ID of the NFT to extract funds from
     * @param _zapFunds indicates if the tokens should be traded to the required ratio
     * @param _sweep indicates if the tokens left over should be send to the msg.sender
     * @param _sqrtRatioX96 the sqrtRatioX96 when the transaction is being submitted
     * @param _tolerance indicates the maximum accepted deviation in percents (100% is 1000) from the ratio
     */
    function depositNFT(uint256 _tokenId, bool _zapFunds, bool _sweep, uint256 _sqrtRatioX96, uint256 _tolerance)
        public
        checkSqrtPriceX96(_sqrtRatioX96, _tolerance)
        nonReentrant
        checkSubmoduleConfig
    {
        (bool success, bytes memory data) = (getAddress(_VAULT_SUBMODULE_DEPOSIT_SLOT)).delegatecall(msg.data);
        string memory revertMsg = data._getRevertMsgFromRes();
        require(success, revertMsg);
    }

    /**
     * @dev Withdraws shares from the vault in the form of the underlying tokens
     * @param _numberOfShares how many shares should be burned and withdrawn
     * @param _token0 false if the sender wants only token1's
     * @param _token1 false if the sender wants only token0's
     * @param _sqrtRatioX96 the sqrtRatioX96 when the transaction is being submitted
     * @param _tolerance indicates the maximum accepted deviation in percents (100% is 1000) from the ratio
     */
    function withdraw(uint256 _numberOfShares, bool _token0, bool _token1, uint256 _sqrtRatioX96, uint256 _tolerance)
        public
        checkSqrtPriceX96(_sqrtRatioX96, _tolerance)
        nonReentrant
        checkSubmoduleConfig
    {
        (bool success, bytes memory data) = (getAddress(_VAULT_SUBMODULE_DEPOSIT_SLOT)).delegatecall(msg.data);
        string memory revertMsg = data._getRevertMsgFromRes();
        require(success, revertMsg);
    }

    /**
     * @dev Withdraws shares from the vault in the form of the underlying tokens. Both the tokens
     * will be withdrawn as returned by Uniswap. The method is safeguarded in the modifier
     * in the underlying method.
     * @param _numberOfShares how many shares should be burned and withdrawn
     * @param _sqrtRatioX96 the sqrtRatioX96 when the transaction is being submitted
     * @param _tolerance indicates the maximum accepted deviation in percents (100% is 1000) from the ratio
     */
    function withdraw(uint256 _numberOfShares, uint256 _sqrtRatioX96, uint256 _tolerance) external nonReentrant {
        withdraw(_numberOfShares, true, true, _sqrtRatioX96, _tolerance);
    }

    /**
     * Does the hard work. Only whitelisted chads.
     */
    function doHardWork() external onlyControllerOrGovernance checkSubmoduleConfig {
        console.log("do hard work");
        console.log(getAddress(_VAULT_SUBMODULE_DEPOSIT_SLOT));
        // Deposit submodule collect fees & zap & increase liquidity : collectFeesAndCompound()
        (bool success, bytes memory data) =
            (getAddress(_VAULT_SUBMODULE_DEPOSIT_SLOT)).delegatecall(abi.encodeWithSignature("collectFeesAndCompound()"));
        console.log("collectFeesAndCompound completed");
        string memory revertMsg = data._getRevertMsgFromRes();
        console.log("read revertMsg");
        console.log(revertMsg);
        if (success) {
            console.log("succeeded");
        } else {
            console.log("Failed");
        }
        require(success, revertMsg);
    }

    /**
     * @dev Allows governance to get dust that stays behind, or accidental token transfers.
     * No tokens should stay in this contract.
     */
    function sweepDust() external onlyControllerOrGovernance checkSubmoduleConfig {
        (bool success, bytes memory data) = (getAddress(_VAULT_SUBMODULE_DEPOSIT_SLOT)).delegatecall(msg.data);
        string memory revertMsg = data._getRevertMsgFromRes();
        require(success, revertMsg);
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
    }

    /**
     * @dev Increases the upgrade timelock. Governance only.
     */
    function increaseUpgradeDelay(uint256 delay) external onlyGovernance {
        getStorage().setNextImplementationDelay(delay.add(getStorage().nextImplementationDelay()));
    }

    /**
     * Staking Logic
     */

    function isStaked() public view returns (bool) {}

    function depositPosToStaker() public onlyGovernance {}

    function setIncentiveStorage(address _incStorage) public onlyGovernance {}

    function removeStake(uint256 incentiveIndex, bool requireSuccess) public onlyGovernance {}

    function addNewStake(IUniswapV3Staker.IncentiveKey memory key) public onlyGovernance {}

    function withdrawPosFromStaker(bool requireUnstakeSuccess) public onlyGovernance {}
}
