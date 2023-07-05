//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;
pragma experimental ABIEncoderV2;

// ERC20
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

// Harvest
import "./interface/IUniVaultV1.sol";
import "./interface/IUniVaultStorageV1.sol";

// UniswapV3 core
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";

// UniswapV3 periphery contracts
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

// Uniswap v2
import "./interface/uniswapV2/IUniswapV2Pair.sol";
import "./interface/uniswapV2/IUniswapV2Factory.sol";
import "./interface/uniswapV2/IUniswapV2Router02.sol";

contract UniStatusViewer {
    using SafeMathUpgradeable for uint256;

    address constant _UNI_POS_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address constant _UNI_POOL_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address constant _V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant _V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

    function getSqrtPriceX96(address _token0, address _token1, uint24 _fee) public view returns (uint160) {
        address poolAddr = IUniswapV3Factory(_UNI_POOL_FACTORY).getPool(_token0, _token1, _fee);
        (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(poolAddr).slot0();
        return sqrtPriceX96;
    }

    function getSqrtPriceX96ForPosition(uint256 posId) public view returns (uint160) {
        (,, address _token0, address _token1, uint24 _fee,,,,,,,) = INonfungiblePositionManager(_UNI_POS_MANAGER).positions(posId);
        return getSqrtPriceX96(_token0, _token1, _fee);
    }

    function getAmountsForPosition(uint256 posId) public view returns (uint256 amount0, uint256 amount1) {
        (,, address _token0, address _token1, uint24 _fee, int24 _tickLower, int24 _tickUpper, uint128 _liquidity,,,,) =
            INonfungiblePositionManager(_UNI_POS_MANAGER).positions(posId);
        uint160 sqrtRatioX96 = getSqrtPriceX96(_token0, _token1, _fee);
        uint160 sqrtRatioXA96 = TickMath.getSqrtRatioAtTick(_tickLower);
        uint160 sqrtRatioXB96 = TickMath.getSqrtRatioAtTick(_tickUpper);
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(sqrtRatioX96, sqrtRatioXA96, sqrtRatioXB96, _liquidity);
    }

    function getAmountsForUserShare(address vaultAddr, uint256 userShare)
        public
        view
        returns (uint256 userAmount0, uint256 userAmount1)
    {
        uint256 posId = IUniVaultStorageV1(IUniVaultV1(vaultAddr).getStorage()).posId();
        (uint256 amount0, uint256 amount1) = getAmountsForPosition(posId);
        userAmount0 = amount0.mul(userShare).div(IERC20Upgradeable(vaultAddr).totalSupply());
        userAmount1 = amount1.mul(userShare).div(IERC20Upgradeable(vaultAddr).totalSupply());
    }

    function enumerateNftRelevantTo(uint256 posId, address nftOwner) public view returns (uint256[] memory) {
        (,, address _token0, address _token1,,,,,,,,) = INonfungiblePositionManager(_UNI_POS_MANAGER).positions(posId);
        uint256 userNftCount = INonfungiblePositionManager(_UNI_POS_MANAGER).balanceOf(nftOwner);
        uint256[] memory ids = new uint256[](userNftCount);

        uint256 validCount = 0;
        for (uint256 i = 0; i < userNftCount; i++) {
            uint256 id = INonfungiblePositionManager(_UNI_POS_MANAGER).tokenOfOwnerByIndex(nftOwner, i);

            (,, address _utoken0, address _utoken1,,,,,,,,) = INonfungiblePositionManager(_UNI_POS_MANAGER).positions(posId);
            if (_utoken0 == _token0 && _utoken1 == _token1) {
                ids[validCount] = id;
                validCount++;
            }
        }

        uint256[] memory relevantIds = new uint256[](validCount);
        for (uint256 i = 0; i < validCount; i++) {
            relevantIds[i] = ids[i];
        }
        return relevantIds;
    }

    /**
     * Returns the number of tokens that would be returned now when removing the liquidity
     * from the corresponding v2 pair
     */
    function quoteV2Migration(address _token0, address _token1, uint256 _lpAmount) public view returns (uint256, uint256) {
        address pair = IUniswapV2Factory(_V2_FACTORY).getPair(_token0, _token1);
        (uint112 amount0, uint112 amount1,) = IUniswapV2Pair(pair).getReserves();
        uint256 totalSupply = IERC20Upgradeable(pair).totalSupply();
        if (_token0 == IUniswapV2Pair(pair).token0()) {
            // order matches v3
            return (_lpAmount.mul(uint256(amount0)).div(totalSupply), _lpAmount.mul(uint256(amount1)).div(totalSupply));
        } else {
            // order is reversed
            return (_lpAmount.mul(uint256(amount1)).div(totalSupply), _lpAmount.mul(uint256(amount0)).div(totalSupply));
        }
    }
}
