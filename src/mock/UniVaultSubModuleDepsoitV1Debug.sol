//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;
pragma abicoder v2;

// ERC20
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

// ERC721
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

// reentrancy guard
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

// UniswapV3 core
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

// Harvest System
import "../interface/IFeeRewardForwarderV6.sol";
import "../inheritance/ControllableInit.sol";

// UniswapV3 periphery contracts
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

// Storage for this UniVault
import "../interface/IUniVaultStorageV1.sol";
import "../interface/IUniVaultV1.sol";

// UniswapV2
import "../interface/uniswapV2/IUniswapV2Pair.sol";
import "../interface/uniswapV2/IUniswapV2Factory.sol";
import "../interface/uniswapV2/IUniswapV2Router02.sol";

// BytesLib
import "../lib/BytesLib.sol";

import "../submodules/interface/IUniVaultSubmoduleDepositV1.sol";

contract UniVaultSubmoduleDepositV1Debug is
    ERC20Upgradeable,
    ERC721HolderUpgradeable,
    ReentrancyGuardUpgradeable,
    ControllableInit,
    IUniVaultSubmoduleDepositV1
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;
    using BytesLib for bytes;

    bytes32 internal constant _GLOBAL_STORAGE_SLOT = 0xea3b316d3f7b97449bd56fdd0c7f95b3a874cb501e4c5d85e01bf23443a180c8;
    bytes32 internal constant _DATA_CONTRACT_SLOT = 0x4c2252f3318958b38b23790562cc9d391075b8dadbfe0e707aed11afe13228b7;
    bytes32 internal constant _LAST_FEE_COLLECTION_SLOT = 0xf7ab4724ec8615b241f089fd2c85cb68f4f3ebaf0381312d3b6137db479257a9;
    address internal constant _NFT_POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address internal constant _UNI_POOL_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    uint256 internal constant _UNDERLYING_UNIT = 1e18;
    address internal constant _V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address internal constant _V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address internal constant _UNI_STAKER = 0x1f98407aaB862CdDeF78Ed252D6f557aA5b0f00d;
    bytes32 internal constant _VAULT_PAUSE_SLOT = 0xde039a7c768eade9368187c932ab7b9ca8d5872604278b5ebfe45ab5eaf85140;

    event SwapFeeClaimed(uint256 token0Fee, uint256 token1Fee, uint256 timestamp);
    event RewardAmountClaimed(uint256 token0Fee, uint256 token1Fee, uint256 timestamp);
    event Deposit(address indexed user, uint256 token0Amount, uint256 token1Amount);
    event Withdraw(address indexed user, uint256 token0Amount, uint256 token1Amount);
    event SharePriceChangeTrading(uint256 oldPrice, uint256 newPrice, uint256 previousTimestamp, uint256 newTimestamp);

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
        assert(_LAST_FEE_COLLECTION_SLOT == bytes32(uint256(keccak256("eip1967.uniVault.lastHardWorkTimestamp")) - 1));
        assert(_VAULT_PAUSE_SLOT == bytes32(uint256(keccak256("eip1967.univault.pause")) - 1));
    }

    function getGlobalStorage() internal pure returns (GlobalStorage storage globalStorage) {
        assembly {
            globalStorage.slot := _GLOBAL_STORAGE_SLOT
        }
    }

    function registerInterface(bytes32 submoduleHash, bool register) public {
        GlobalStorage storage globalStorage = getGlobalStorage();
        address currentSubmoduleAddress = globalStorage.submoduleAddress[submoduleHash];

        uint256 functionNum = 9;
        bytes4[9] memory functionLists = [
            bytes4(keccak256("migrateToNftFromV2(uint256,uint256,uint256,bool,uint256,uint256,uint256,uint256,uint160)")),
            bytes4(keccak256("deposit(uint256,uint256,bool,uint256,uint256,uint256,uint256,uint160)")),
            bytes4(keccak256("withdraw(uint256,bool,bool,uint256,uint256,uint256,uint256,uint160)")),
            bytes4(keccak256("_collectFeesAndCompound()")),
            bytes4(keccak256("_compoundRewards()")),
            bytes4(keccak256("sweepDust()")),
            // Exposing Legacy interface
            bytes4(keccak256("migrateToNftFromV2(uint256,uint256,uint256,bool,uint256,uint256)")),
            bytes4(keccak256("deposit(uint256,uint256,bool,bool,uint256,uint256)")),
            bytes4(keccak256("withdraw(uint256,bool,bool,uint256,uint256)"))
        ];

        address registeringSubmodule = (register) ? currentSubmoduleAddress : address(0);
        for (uint256 i = 0; i < functionNum; i++) {
            globalStorage.functionToSubmodule[functionLists[i]] = registeringSubmodule;
        }
    }

    function migrateToNftFromV2(
        uint256 _amount,
        uint256 _minAmountForRemoveLiquidity0,
        uint256 _minAmountForRemoveLiquidity1,
        bool _zapFunds,
        uint256 _sqrtRatioX96,
        uint256 _tolerance
    ) public override checkSqrtPriceX96(_sqrtRatioX96, _tolerance) returns (uint256, uint256) {
        return _migrateToNftFromV2(_amount, _minAmountForRemoveLiquidity0, _minAmountForRemoveLiquidity1, _zapFunds, 0, 0, 0);
    }

    function migrateToNftFromV2(
        uint256 _amount,
        uint256 _minAmountForRemoveLiquidity0,
        uint256 _minAmountForRemoveLiquidity1,
        bool _zapFunds,
        uint256 _sqrtRatioX96,
        uint256 _tolerance,
        uint256 _amount0OutMinForZap,
        uint256 _amount1OutMinForZap,
        uint160 _sqrtPriceLimitX96
    ) public override checkSqrtPriceX96(_sqrtRatioX96, _tolerance) returns (uint256, uint256) {
        return _migrateToNftFromV2(
            _amount,
            _minAmountForRemoveLiquidity0,
            _minAmountForRemoveLiquidity1,
            _zapFunds,
            _amount0OutMinForZap,
            _amount1OutMinForZap,
            _sqrtPriceLimitX96
        );
    }

    function _migrateToNftFromV2(
        uint256 _amount,
        uint256 _minAmountForRemoveLiquidity0,
        uint256 _minAmountForRemoveLiquidity1,
        bool _zapFunds,
        uint256 _amount0OutMinForZap,
        uint256 _amount1OutMinForZap,
        uint160 _zapSqrtPriceLimitX96
    ) internal returns (uint256, uint256) {
        address pair = IUniswapV2Factory(_V2_FACTORY).getPair(address(token0()), address(token1()));
        IERC20Upgradeable(pair).safeTransferFrom(msg.sender, address(this), _amount);
        IERC20Upgradeable(pair).safeApprove(_V2_ROUTER, 0);
        IERC20Upgradeable(pair).safeApprove(_V2_ROUTER, _amount);
        IUniswapV2Router02(_V2_ROUTER).removeLiquidity(
            address(token0()),
            address(token1()),
            _amount,
            _minAmountForRemoveLiquidity0,
            _minAmountForRemoveLiquidity1,
            address(this),
            block.timestamp
        );
        // deposit tokens
        return _deposit(msg.sender, _zapFunds, _amount0OutMinForZap, _amount1OutMinForZap, _zapSqrtPriceLimitX96);
    }

    function deposit(uint256 _amount0, uint256 _amount1, bool _zapFunds, bool _sweep, uint256 _sqrtRatioX96, uint256 _tolerance)
        public
        override
        checkSqrtPriceX96(_sqrtRatioX96, _tolerance)
        nonReentrant
        checkVaultNotPaused
        returns (uint256, uint256)
    {
        return _pullFundsAndDeposit(_amount0, _amount1, _zapFunds, 0, 0, 0);
    }

    function deposit(
        uint256 _amount0,
        uint256 _amount1,
        bool _zapFunds,
        uint256 _sqrtRatioX96,
        uint256 _tolerance,
        uint256 _zapAmount0OutMin,
        uint256 _zapAmount1OutMin,
        uint160 _zapSqrtPriceLimitX96
    ) public override checkSqrtPriceX96(_sqrtRatioX96, _tolerance) nonReentrant checkVaultNotPaused returns (uint256, uint256) {
        return _pullFundsAndDeposit(_amount0, _amount1, _zapFunds, _zapAmount0OutMin, _zapAmount1OutMin, _zapSqrtPriceLimitX96);
    }

    function _pullFundsAndDeposit(
        uint256 _amount0,
        uint256 _amount1,
        bool _zapFunds,
        uint256 _zapAmount0OutMin,
        uint256 _zapAmount1OutMin,
        uint160 _zapSqrtPriceLimitX96
    ) internal returns (uint256, uint256) {
        // it is possible for _amount0 and _amount1 to be 0, so no need for requirement statement.
        token0().safeTransferFrom(msg.sender, address(this), _amount0);
        token1().safeTransferFrom(msg.sender, address(this), _amount1);
        // deposit tokens
        return _deposit(msg.sender, _zapFunds, _zapAmount0OutMin, _zapAmount1OutMin, _zapSqrtPriceLimitX96);
    }

    /**
     * @dev Handles the deposit
     * @param _to the address of who the shares should be minted to
     */
    function _deposit(
        address _to,
        bool _zapFunds,
        uint256 _zapAmount0OutMin,
        uint256 _zapAmount1OutMin,
        uint160 _zapSqrtPriceLimitX96
    ) internal returns (uint256, uint256) {
        // zap funds if desired
        (uint256 zapActualAmountOut0, uint256 zapActualAmountOut1) = (0, 0);
        if (_zapFunds) {
            (zapActualAmountOut0, zapActualAmountOut1) = _zap(_zapAmount0OutMin, _zapAmount1OutMin, _zapSqrtPriceLimitX96);
        }

        // the assumes that the deposits are already in
        // they were transferred in by the deposit method, and potentially zap-swapped
        uint256 previousUnderlyingBalanceWithInvestment = IUniVaultV1(address(this)).underlyingBalanceWithInvestment();
        uint256 _amount0 = token0().balanceOf(address(this));
        uint256 _amount1 = token1().balanceOf(address(this));
        // approvals for the liquidity increase
        token0().safeApprove(_NFT_POSITION_MANAGER, 0);
        token0().safeApprove(_NFT_POSITION_MANAGER, _amount0);
        token1().safeApprove(_NFT_POSITION_MANAGER, 0);
        token1().safeApprove(_NFT_POSITION_MANAGER, _amount1);
        // increase the liquidity
        (uint128 _liquidity,,) = INonfungiblePositionManager(_NFT_POSITION_MANAGER).increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: getStorage().posId(),
                amount0Desired: _amount0,
                amount1Desired: _amount1,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );
        emit Deposit(_to, _amount0, _amount1);
        // mint shares of the vault to the recipient
        uint256 toMint = IERC20Upgradeable(address(this)).totalSupply() == 0
            ? uint256(_liquidity)
            : (uint256(_liquidity)).mul(IERC20Upgradeable(address(this)).totalSupply()).div(previousUnderlyingBalanceWithInvestment);
        _mint(_to, toMint);
        _transferLeftOverTo(msg.sender);
        return (zapActualAmountOut0, zapActualAmountOut1);
    }

    // The function is not registered in the interface of mother vault,
    // thus regular users cannot invoke this.
    function compoundRewards() public {}

    // _compoundRewards is registered as an interface in the mother vault,
    // but using the onlySelf modifier, this acts as an internal function.
    // the reason to expose this and called only be this address via external call
    // is to enable the try catch structure
    function _compoundRewards() external override onlySelf {}

    // Not registered, only callable in the mother vault level.
    function collectFeesAndCompound() public {
        try this._collectFeesAndCompound() {}
        catch {
            emit SharePriceChangeTrading(
                IUniVaultV1(address(this)).getPricePerFullShare(),
                IUniVaultV1(address(this)).getPricePerFullShare(),
                getUint256(_LAST_FEE_COLLECTION_SLOT),
                block.timestamp
            );
            setUint256(_LAST_FEE_COLLECTION_SLOT, block.timestamp);
        }
    }

    // registered but guarded by onlySelf to act as internal
    function _collectFeesAndCompound() external override onlySelf {
        require(getStorage().feeRewardForwarder() != address(0), "feeRewardForwarder not set");
        require(getStorage().platformTarget() != address(0), "platformTarget not set");

        uint256 token0FromReward = token0().balanceOf(address(this));
        uint256 token1FromReward = token1().balanceOf(address(this));
        emit RewardAmountClaimed(token0FromReward, token1FromReward, block.timestamp);

        // collect the earned fees
        (uint256 _collected0, uint256 _collected1) = INonfungiblePositionManager(_NFT_POSITION_MANAGER).collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: getStorage().posId(),
                recipient: address(this),
                amount0Max: type(uint128).max, // collect all token0
                amount1Max: type(uint128).max // collect all token1
            })
        );
        emit SwapFeeClaimed(_collected0, _collected1, block.timestamp);

        _collected0 = token0FromReward.add(_collected0);
        _collected1 = token1FromReward.add(_collected1);

        // handles profit sharing calculations and notifications
        uint256 _profitRatio0 = _collected0.mul(getStorage().profitShareRatio()).div(10000);
        uint256 _profitRatio1 = _collected1.mul(getStorage().profitShareRatio()).div(10000);
        uint256 _platformRatio0 = _collected0.mul(getStorage().platformRatio()).div(10000);
        uint256 _platformRatio1 = _collected1.mul(getStorage().platformRatio()).div(10000);
        if (_profitRatio0 != 0) {
            token0().safeApprove(getStorage().feeRewardForwarder(), 0);
            token0().safeApprove(getStorage().feeRewardForwarder(), _profitRatio0);
            IFeeRewardForwarderV6(getStorage().feeRewardForwarder()).poolNotifyFixedTarget(getStorage().token0(), _profitRatio0);
        }
        if (_profitRatio1 != 0) {
            token1().safeApprove(getStorage().feeRewardForwarder(), 0);
            token1().safeApprove(getStorage().feeRewardForwarder(), _profitRatio1);

            IFeeRewardForwarderV6(getStorage().feeRewardForwarder()).poolNotifyFixedTarget(getStorage().token1(), _profitRatio1);
        }
        if (_platformRatio0 != 0) {
            token0().safeTransfer(getStorage().platformTarget(), _platformRatio0);
        }
        if (_platformRatio1 != 0) {
            token1().safeTransfer(getStorage().platformTarget(), _platformRatio1);
        }

        // zap the tokens to the proper ratio
        _zap(0, 0, 0);

        // increase liquidity
        // this will increase the underlyingBalanceWithInvestment and getPricePerFullShare
        // while totalSupply remains the same.

        token0().safeApprove(_NFT_POSITION_MANAGER, 0);
        token0().safeApprove(_NFT_POSITION_MANAGER, token0().balanceOf(address(this)));
        token1().safeApprove(_NFT_POSITION_MANAGER, 0);
        token1().safeApprove(_NFT_POSITION_MANAGER, token1().balanceOf(address(this)));

        uint256 sharePriceBefore = IUniVaultV1(address(this)).getPricePerFullShare();
        INonfungiblePositionManager(_NFT_POSITION_MANAGER).increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: getStorage().posId(),
                amount0Desired: token0().balanceOf(address(this)),
                amount1Desired: token1().balanceOf(address(this)),
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );

        emit SharePriceChangeTrading(
            sharePriceBefore,
            IUniVaultV1(address(this)).getPricePerFullShare(),
            getUint256(_LAST_FEE_COLLECTION_SLOT),
            block.timestamp
        );

        // Set new timestamp
        setUint256(_LAST_FEE_COLLECTION_SLOT, block.timestamp);
    }

    function withdraw(uint256 _numberOfShares, bool _token0, bool _token1, uint256 _sqrtRatioX96, uint256 _tolerance)
        public
        override
        checkSqrtPriceX96(_sqrtRatioX96, _tolerance)
        nonReentrant
        checkVaultNotPaused
        returns (uint256, uint256)
    {
        return _withdraw(_numberOfShares, _token0, _token1, 0, 0, 0);
    }

    function withdraw(
        uint256 _numberOfShares,
        bool _token0,
        bool _token1,
        uint256 _sqrtRatioX96,
        uint256 _tolerance,
        uint256 _amount0OutMin,
        uint256 _amount1OutMin,
        uint160 _sqrtPriceLimitX96
    ) public override checkSqrtPriceX96(_sqrtRatioX96, _tolerance) nonReentrant checkVaultNotPaused returns (uint256, uint256) {
        return _withdraw(_numberOfShares, _token0, _token1, _amount0OutMin, _amount1OutMin, _sqrtPriceLimitX96);
    }

    function _withdraw(
        uint256 _numberOfShares,
        bool _token0,
        bool _token1,
        uint256 _amount0OutMin,
        uint256 _amount1OutMin,
        uint160 _sqrtPriceLimitX96
    ) internal returns (uint256, uint256) {
        require(_token0 || _token1, "At least one side must be wanted");
        // calculates the liquidity before burning any shares
        uint128 liquidityShare = uint128(
            (IUniVaultV1(address(this)).underlyingBalanceWithInvestment()).mul(_numberOfShares).div(
                IERC20Upgradeable(address(this)).totalSupply()
            )
        );
        // burn the respective shares
        // guards the balance via safe math in burn
        _burn(msg.sender, _numberOfShares);
        // withdraw liquidity from the NFT
        (uint256 _receivedToken0, uint256 _receivedToken1) = INonfungiblePositionManager(_NFT_POSITION_MANAGER).decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: getStorage().posId(),
                liquidity: liquidityShare,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );
        // collect the amount fetched above
        INonfungiblePositionManager(_NFT_POSITION_MANAGER).collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: getStorage().posId(),
                recipient: address(this),
                amount0Max: uint128(_receivedToken0), // collect all token0 accounted for the liquidity
                amount1Max: uint128(_receivedToken1) // collect all token1 accounted for the liquidity
            })
        );

        (uint256 zapActualAmountOut0, uint256 zapActualAmountOut1) = (0, 0);

        // make swaps as desired
        if (!_token0) {
            uint256 balance0 = token0().balanceOf(address(this));
            if (balance0 > 0) {
                (zapActualAmountOut0, zapActualAmountOut1) = _swap(balance0, 0, _amount0OutMin, 0, _sqrtPriceLimitX96);
            }
        }
        if (!_token1) {
            uint256 balance1 = token1().balanceOf(address(this));
            if (balance1 > 0) {
                (zapActualAmountOut0, zapActualAmountOut1) = _swap(0, balance1, 0, _amount1OutMin, _sqrtPriceLimitX96);
            }
        }
        emit Withdraw(msg.sender, _receivedToken0, _receivedToken1);
        // transfer everything we have in the contract to msg.sender
        _transferLeftOverTo(msg.sender);
        return (zapActualAmountOut0, zapActualAmountOut1);
    }

    /**
     * @dev Zap takes in what users provided and calculates an approximately balanced amount for
     * liquidity provision. It then swaps one token to another to make the tokens balanced.
     * To reduce the size of the bytecode for this contract, zap is an independent contract
     * that we make a delegatecall to.
     */
    function _zap(uint256 _amount0OutMin, uint256 _amount1OutMin, uint160 _sqrtPriceLimitX96)
        internal
        returns (uint256, uint256)
    {
        uint256 _originalAmount0 = token0().balanceOf(address(this));
        uint256 _originalAmount1 = token1().balanceOf(address(this));
        (bool success, bytes memory data) = getStorage().zapContract().delegatecall(
            abi.encodeWithSignature(
                "zap(uint160,uint256,uint256,uint256,uint256)",
                _sqrtPriceLimitX96,
                _originalAmount0,
                _originalAmount1,
                _amount0OutMin,
                _amount1OutMin
            )
        );
        if (success) {
            return abi.decode(data, (uint256, uint256));
        }
        string memory revertMsg = data._getRevertMsgFromRes();
        require(success, revertMsg);
        return (0, 0);
    }

    /**
     * @dev Swap takes in token amount and swap it to another. This code resides in the zap contract.
     * To reduce the size of the bytecode for this contract, zap is an independent contract
     * that we make a delegatecall to.
     */
    function _swap(
        uint256 _amount0In,
        uint256 _amount1In,
        uint256 _amount0OutMin,
        uint256 _amount1OutMin,
        uint256 _sqrtPriceLimitX96
    ) internal returns (uint256, uint256) {
        (bool success, bytes memory data) = getStorage().zapContract().delegatecall(
            abi.encodeWithSignature(
                "swap(uint160,uint256,uint256,uint256,uint256)",
                _sqrtPriceLimitX96,
                _amount0In,
                _amount1In,
                _amount0OutMin,
                _amount1OutMin
            )
        );
        if (success) {
            return abi.decode(data, (uint256, uint256));
        }
        string memory revertMsg = data._getRevertMsgFromRes();
        require(success, revertMsg);
        return (0, 0);
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

    function sweepDust() external override onlyControllerOrGovernance {
        _transferLeftOverTo(msg.sender);
    }

    /**
     * @dev Handles transferring the leftovers
     */
    function _transferLeftOverTo(address _to) internal {
        uint256 balance0 = token0().balanceOf(address(this));
        uint256 balance1 = token1().balanceOf(address(this));
        if (balance0 > 0) {
            token0().safeTransfer(_to, balance0);
        }
        if (balance1 > 0) {
            token1().safeTransfer(_to, balance1);
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
     * @dev Sets a value to a slot.
     */
    function setUint256(bytes32 slot, uint256 _value) internal {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(slot, _value)
        }
    }

    /**
     * @dev Reads an uint from a slot.
     */
    function getUint256(bytes32 slot) internal view returns (uint256 str) {
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
