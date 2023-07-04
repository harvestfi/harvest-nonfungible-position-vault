//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;
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

// reentrancy guard
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

// UniswapV3 periphery contracts
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

// Harvest System
import "../interface/IFeeRewardForwarderV6.sol";
import "../inheritance/ControllableInit.sol";

// Storage for this UniVault
import "../interface/IUniVaultStorageV1.sol";

// quick fix for Changing Range
contract UniVaultUpgradeableV1qfCR is ERC20Upgradeable, ERC721HolderUpgradeable, ReentrancyGuardUpgradeable, ControllableInit {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    bytes32 internal constant _DATA_CONTRACT_SLOT = 0x4c2252f3318958b38b23790562cc9d391075b8dadbfe0e707aed11afe13228b7;
    address internal constant _NFT_POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address internal constant _UNI_POOL_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    uint256 internal constant _UNDERLYING_UNIT = 1e18;

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

    /**
     * @dev Creates the contract and ensures that the slot matches the hash
     */
    constructor() {
        assert(_DATA_CONTRACT_SLOT == bytes32(uint256(keccak256("eip1967.uniVault.dataContract")) - 1));
    }

    // Stripped down most implementation to save contract size.

    // creates a new position with the designated range
    function mintPosition(int24 _tickLower, int24 _tickUpper, uint256 _initAmount0, uint256 _initAmount1) public onlyGovernance {
        token0().safeTransferFrom(msg.sender, address(this), _initAmount0);
        token1().safeTransferFrom(msg.sender, address(this), _initAmount1);
        token0().safeApprove(_NFT_POSITION_MANAGER, 0);
        token0().safeApprove(_NFT_POSITION_MANAGER, _initAmount0);
        token1().safeApprove(_NFT_POSITION_MANAGER, 0);
        token1().safeApprove(_NFT_POSITION_MANAGER, _initAmount1);

        (uint256 _tokenId, uint128 _initialLiquidity,,) = INonfungiblePositionManager(_NFT_POSITION_MANAGER).mint(
            INonfungiblePositionManager.MintParams({
                token0: address(token0()),
                token1: address(token1()),
                fee: getStorage().fee(),
                tickLower: _tickLower,
                tickUpper: _tickUpper,
                amount0Desired: _initAmount0, // amount0Desired
                amount1Desired: _initAmount1, // amount1Desired
                amount0Min: 0, // amount0Min, first small deposit, can stay 0
                amount1Min: 0, // amount1Min, first small deposit, can stay 0
                recipient: address(this),
                deadline: block.timestamp // will be done on this block.
            })
        );
    }

    // switch to the designated position
    function changeRange(uint256 newPosId) public onlyGovernance {
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
        _zap();

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

        // then lets sweep the rest.
        _transferLeftOverTo(msg.sender);
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
     * @dev Allows governance to get dust that stays behind, or accidental token transfers.
     * No tokens should stay in this contract.
     */
    function sweepDust() external onlyControllerOrGovernance {
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
     * @dev Zap takes in what users provided and calculates an approximately balanced amount for
     * liquidity provision. It then swaps one token to another to make the tokens balanced.
     * To reduce the size of the bytecode for this contract, zap is an independent contract
     * that we make a delegatecall to.
     */
    function _zap() internal {
        uint256 _originalAmount0 = token0().balanceOf(address(this));
        uint256 _originalAmount1 = token1().balanceOf(address(this));
        (bool success, bytes memory data) = getStorage().zapContract().delegatecall(
            abi.encodeWithSignature("zap(uint256,uint256)", _originalAmount0, _originalAmount1)
        );
        if (!success) {
            // there is no return value, we do not want to decode is there is no failure
            require(success, abi.decode(data, (string)));
        }
    }

    /**
     * @dev Swap takes in token amount and swap it to another. This code resides in the zap contract.
     * To reduce the size of the bytecode for this contract, zap is an independent contract
     * that we make a delegatecall to.
     */
    function _swap(uint256 _amount0In, uint256 _amount1In) internal {
        (bool success, bytes memory data) =
            getStorage().zapContract().delegatecall(abi.encodeWithSignature("swap(uint256,uint256)", _amount0In, _amount1In));
        if (!success) {
            // there is no return value, we do not want to decode is there is no failure
            require(success, abi.decode(data, (string)));
        }
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
}
