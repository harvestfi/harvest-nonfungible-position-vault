//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.6;
pragma abicoder v2;

// ERC20
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

// ERC721
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

// UniswapV3 core
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

// reentrancy guard
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

// UniswapV3 periphery contracts
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

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

contract UniVaultSubmoduleChangeRangeV1 is ReentrancyGuardUpgradeable, ControllableInit {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;
    using BytesLib for bytes;

    // We expect all reward submodule to have this reward token list
    bytes32 internal constant _GLOBAL_STORAGE_SLOT = 0xea3b316d3f7b97449bd56fdd0c7f95b3a874cb501e4c5d85e01bf23443a180c8;
    bytes32 internal constant _DATA_CONTRACT_SLOT = 0x4c2252f3318958b38b23790562cc9d391075b8dadbfe0e707aed11afe13228b7;
    bytes32 internal constant _VAULT_PAUSE_SLOT = 0xde039a7c768eade9368187c932ab7b9ca8d5872604278b5ebfe45ab5eaf85140;
    address internal constant _UNI_POOL_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    address internal constant _NFT_POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;

    // This is the storage for the mother level vault
    // it is used here to register / deregister interface
    struct GlobalStorage {
        // direct mapping from function signature to submodule address
        mapping(bytes4 => address) functionToSubmodule;
        // Mapping from submodule hash to submodule, this is used for internal delegate calls as in doHardwork
        // where we know what submodules we are calling, but those functions are not open to the public
        mapping(bytes32 => address) submoduleAddress;
    }

    modifier checkVaultNotPaused() {
        require(!getBoolean(_VAULT_PAUSE_SLOT), "Vault is paused");
        _;
    }

    modifier onlySelf() {
        require(msg.sender == address(this), "only for internal");
        _;
    }

    function getGlobalStorage() internal pure returns (GlobalStorage storage globalStorage) {
        assembly {
            globalStorage.slot := _GLOBAL_STORAGE_SLOT
        }
    }

    function registerInterface(bytes32 submoduleHash, bool register) public virtual {
        GlobalStorage storage globalStorage = getGlobalStorage();
        address currentSubmoduleAddress = globalStorage.submoduleAddress[submoduleHash];

        uint256 functionNum = 1;
        bytes4[1] memory functionLists = [bytes4(keccak256("changeRange(uint256)"))];

        address registeringSubmodule = (register) ? currentSubmoduleAddress : address(0);
        for (uint256 i = 0; i < functionNum; i++) {
            globalStorage.functionToSubmodule[functionLists[i]] = registeringSubmodule;
        }
    }

    function _changeRange(uint256 newPosId) internal {
        // If there is no such position, this will also fail.
        require(IERC721Upgradeable(_NFT_POSITION_MANAGER).ownerOf(newPosId) == address(this), "pos owner mismatch");

        // making sure that we are pointing to the same thing.
        (,,,,,,, uint128 _oldLiquidity,,,,) = INonfungiblePositionManager(_NFT_POSITION_MANAGER).positions(getStorage().posId());
        // fetching information from new position
        (,, address _t0, address _t1, uint24 _fee, int24 _newTickLower, int24 _newTickUpper,,,,,) =
            INonfungiblePositionManager(_NFT_POSITION_MANAGER).positions(newPosId);

        require(_t0 == address(token0()) && _t1 == address(token1()), "pool mismatch");
        getStorage().setFee(_fee);

        uint256 oldPosId = getStorage().posId();

        // remove liquidity from old
        (uint256 _receivedToken0, uint256 _receivedToken1) = INonfungiblePositionManager(_NFT_POSITION_MANAGER).decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: oldPosId,
                liquidity: _oldLiquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );

        // collect the amount fetched above + previous accumulated fees
        INonfungiblePositionManager(_NFT_POSITION_MANAGER).collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: oldPosId,
                recipient: address(this),
                amount0Max: uint128(-1), // collect all token0 (since we are changing ranges)
                amount1Max: uint128(-1) // collect all token1 (since we are changing ranges)
            })
        );

        // set new ranges
        getStorage().setTickLower(_newTickLower);
        getStorage().setTickUpper(_newTickUpper);

        // Zap will balance it to the new range
        _zap(0, 0, 0); // zap the tokens to the proper ratio

        // point the storge to the new Pos Id
        getStorage().setPosId(newPosId);

        // we should now put them all into the new position.

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
    }

    function changeRange(uint256 newPosId) public onlyGovernance {
        _changeRange(newPosId);
        _transferLeftOverTo(msg.sender);
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
}
