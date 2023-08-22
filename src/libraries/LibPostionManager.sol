//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// External Packages
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

// Libraries
import {Position, AppStorage, LibAppStorage} from "./LibAppStorage.sol";
import {LibErrors} from "./LibErrors.sol";

library LibPostionManager {
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

        // Approve the position manager to transfer the tokens
        IERC20(s.token0).safeApprove(s.nonFungibleTokenPositionManager, 0);
        IERC20(s.token1).safeApprove(s.nonFungibleTokenPositionManager, 0);
    }

    function stake(uint256 _positionId) internal addressConfiguration {
        AppStorage storage s = LibAppStorage.systemStorage();
        if (s.positions[_positionId].staked) {
            revert LibErrors.PositionStaked(_positionId);
        }
        IERC721Upgradeable(s.nonFungibleTokenPositionManager).transferFrom(
            address(this), s.masterChef, s.positions[_positionId].tokenId
        );
        s.positions[_positionId].staked = true;
    }

    function withdraw() internal {}
    function increaseLiquidity() internal {}
    function decreaseLiquidity() internal {}
    function collect() internal {}
    function harvest() internal {}

    function positionInfo(uint256 _tokenId) internal view returns (address, address, uint24, int24, int24, uint256) {
        AppStorage storage s = LibAppStorage.systemStorage();
        (,, address _token0, address _token1, uint24 _fee, int24 _tickLower, int24 _tickUpper, uint256 _initialLiquidity,,,,) =
            INonfungiblePositionManager(s.nonFungibleTokenPositionManager).positions(_tokenId);
        return (_token0, _token1, _fee, _tickLower, _tickUpper, _initialLiquidity);
    }

    function setNonFungiPositionManager(address _address) internal {
        AppStorage storage s = LibAppStorage.systemStorage();
        s.nonFungibleTokenPositionManager = _address;
    }

    function addPosition() internal {}

    function updatePosition() internal {}
}
