//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// External Packages
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

// Interfaces
import {IMasterChefV3} from "../interfaces/protocols/pancake/IMasterChefV3.sol";

// Libraries
import {Position, AppStorage, LibAppStorage} from "./LibAppStorage.sol";
import {LibDataTypes} from "./LibDataTypes.sol";
import {LibErrors} from "./LibErrors.sol";

library LibPositionManager {
    using SafeERC20 for IERC20;

    modifier addressConfiguration() {
        AppStorage storage s = LibAppStorage.systemStorage();
        if (s.nonFungibleTokenPositionManager == address(0) || s.masterChef == address(0)) {
            revert LibErrors.AddressUnconfigured();
        }
        _;
    }

    function mint(
        int24 _tickLower,
        int24 _tickUpper,
        uint256 _amount0Desired,
        uint256 _amount1Desired,
        uint256 _amount0Min,
        uint256 _amount1Min
    ) internal addressConfiguration returns (uint256 _tokenId, uint128 _liquidity, uint256 _amount0, uint256 _amount1) {
        AppStorage storage s = LibAppStorage.systemStorage();

        if (s.token0 == address(0) || s.token1 == address(0) || s.fee == 0) {
            revert LibErrors.AddressUnconfigured();
        }

        // Approve the position manager to transfer the tokens
        IERC20(s.token0).safeIncreaseAllowance(s.nonFungibleTokenPositionManager, _amount0Desired);
        IERC20(s.token1).safeIncreaseAllowance(s.nonFungibleTokenPositionManager, _amount1Desired);

        (_tokenId, _liquidity, _amount0, _amount1) = INonfungiblePositionManager(s.nonFungibleTokenPositionManager).mint(
            INonfungiblePositionManager.MintParams({
                token0: s.token0,
                token1: s.token1,
                fee: s.fee,
                tickLower: _tickLower,
                tickUpper: _tickUpper,
                amount0Desired: _amount0Desired,
                amount1Desired: _amount1Desired,
                amount0Min: _amount0Min,
                amount1Min: _amount1Min,
                recipient: address(this),
                deadline: block.timestamp
            })
        );

        Position storage position = s.positions[s.positionCount++];
        position.tickLower = _tickLower;
        position.tickUpper = _tickUpper;
        position.initialLiquidity = _liquidity;
        position.tokenId = _tokenId;

        // Reset the allowances
        IERC20(s.token0).safeApprove(s.nonFungibleTokenPositionManager, 0);
        IERC20(s.token1).safeApprove(s.nonFungibleTokenPositionManager, 0);
    }

    function stake(uint256 _positionId) internal addressConfiguration {
        AppStorage storage s = LibAppStorage.systemStorage();
        if (s.positions[_positionId].staked) {
            revert LibErrors.PositionStaked(_positionId);
        }
        IERC721Upgradeable(s.nonFungibleTokenPositionManager).safeTransferFrom(
            address(this), s.masterChef, s.positions[_positionId].tokenId
        );
        s.positions[_positionId].staked = true;
    }

    function withdraw(uint256 _positionId) internal {
        AppStorage storage s = LibAppStorage.systemStorage();
        IMasterChefV3(s.masterChef).withdraw(_positionId, address(this));
    }

    function increaseLiquidity(uint256 _positionId, uint256 _depositAmount) internal {
        AppStorage storage s = LibAppStorage.systemStorage();
        // Approve the position manager to transfer the tokens
        IERC20(s.unifiedDepositToken).safeIncreaseAllowance(s.masterChef, _depositAmount);
        LibDataTypes.IncreaseLiquidityParams memory params = LibDataTypes.IncreaseLiquidityParams({
            tokenId: s.positions[_positionId].tokenId,
            amount0Desired: IERC20(s.token0).balanceOf(address(this)),
            amount1Desired: IERC20(s.token1).balanceOf(address(this)),
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp
        });

        IMasterChefV3(s.masterChef).increaseLiquidity(params);
        // Reset the allowances
        IERC20(s.unifiedDepositToken).safeApprove(s.masterChef, 0);
    }

    function decreaseLiquidity(uint256 _positionId, uint128 _rmLiquidity) internal {
        AppStorage storage s = LibAppStorage.systemStorage();
        LibDataTypes.DecreaseLiquidityParams memory params = LibDataTypes.DecreaseLiquidityParams({
            tokenId: s.positions[_positionId].tokenId,
            liquidity: _rmLiquidity,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp
        });

        IMasterChefV3(s.masterChef).decreaseLiquidity(params);
    }

    function collect(uint256 _positionId) internal returns (uint256 amount0, uint256 amount1) {
        AppStorage storage s = LibAppStorage.systemStorage();
        LibDataTypes.CollectParams memory params = LibDataTypes.CollectParams({
            tokenId: s.positions[_positionId].tokenId,
            recipient: address(this),
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        });

        return IMasterChefV3(s.masterChef).collect(params);
    }

    function harvest(uint256 _positionId) internal returns (uint256 reward) {
        AppStorage storage s = LibAppStorage.systemStorage();
        return IMasterChefV3(s.masterChef).harvest(s.positions[_positionId].tokenId, address(this));
    }

    function positionInfo(uint256 _tokenId) internal view returns (address, address, uint24, int24, int24, uint256) {
        AppStorage storage s = LibAppStorage.systemStorage();
        (,, address _token0, address _token1, uint24 _fee, int24 _tickLower, int24 _tickUpper, uint256 _liquidity,,,,) =
            INonfungiblePositionManager(s.nonFungibleTokenPositionManager).positions(_tokenId);
        return (_token0, _token1, _fee, _tickLower, _tickUpper, _liquidity);
    }

    /**
     * @dev Getter for the current sqrtPriceX96 of the Uniswap pool.
     */
    function _getSqrtPriceX96() internal view returns (uint160 _sqrtPriceX96) {
        AppStorage storage s = LibAppStorage.systemStorage();
        address factory = INonfungiblePositionManager(s.nonFungibleTokenPositionManager).factory();
        address poolAddr = IUniswapV3Factory(factory).getPool(s.token0, s.token1, s.fee);
        (_sqrtPriceX96,,,,,,) = IUniswapV3Pool(poolAddr).slot0();
    }
}
