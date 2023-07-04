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
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";

// UniswapV3 periphery contracts
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

// Harvest System
import "./inheritance/GovernableInit.sol";

// Storage for this UniVault
import "./UniVaultStorageV1.sol";

contract Zap {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    bytes32 internal constant _DATA_CONTRACT_SLOT = 0x4c2252f3318958b38b23790562cc9d391075b8dadbfe0e707aed11afe13228b7;
    address internal constant _SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address internal constant _UNI_POOL_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    uint128 internal constant _LIQUIDITY_CONSTANT = 1e18;

    /**
     * @dev Constructs the contract and asserts the right slot for the data contract.
     * This slot has to match the slot in the vault, otherwise the delegatecalls
     * will not be able to finds it.
     */
    constructor() {
        assert(_DATA_CONTRACT_SLOT == bytes32(uint256(keccak256("eip1967.uniVault.dataContract")) - 1));
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
     * The safeguarding against slippage is left to the caller.
     * @param _originalAmount0 the current amount for token0 available for zapping
     * @param _originalAmount1 the current amount for token1 available for zapping
     */
    function zap(
        uint160 _sqrtPriceLimitX96,
        uint256 _originalAmount0,
        uint256 _originalAmount1,
        uint256 _amount0OutMin,
        uint256 _amount1OutMin
    ) public returns (uint256, uint256) {
        require(_originalAmount0 > 0 || _originalAmount1 > 0, "Cannot be both 0");
        if (_originalAmount0 == 0) {
            return _zapZero0(_originalAmount1, _amount0OutMin, _sqrtPriceLimitX96);
        }
        if (_originalAmount1 == 0) {
            return _zapZero1(_originalAmount0, _amount1OutMin, _sqrtPriceLimitX96);
        }

        uint160 sqrtRatioX96 = getSqrtPriceX96(); // current price
        uint160 sqrtRatioXA96 = TickMath.getSqrtRatioAtTick(getStorage().tickLower()); // "price" at the lower tick
        uint160 sqrtRatioXB96 = TickMath.getSqrtRatioAtTick(getStorage().tickUpper()); // "price" at the upper tick

        if (sqrtRatioX96 <= sqrtRatioXA96) {
            // we are below the low range, swap amount1 to token0
            // none of the amounts is 0, because the execution would be transferred
            return swap(_sqrtPriceLimitX96, 0, _originalAmount1, 0, _amount1OutMin);
        } else if (sqrtRatioX96 >= sqrtRatioXB96) {
            // we are above range, swapping token0 to token1
            // none of the amounts is 0, because the execution would be transferred
            return swap(_sqrtPriceLimitX96, _originalAmount0, 0, _amount0OutMin, 0);
        }

        // we are within the range
        uint128 liquidity0 = LiquidityAmounts.getLiquidityForAmount0(sqrtRatioX96, sqrtRatioXB96, _originalAmount0);
        uint128 liquidity1 = LiquidityAmounts.getLiquidityForAmount1(sqrtRatioXA96, sqrtRatioX96, _originalAmount1);

        if (liquidity0 < liquidity1) {
            // we are swapping token1 for token0
            return swapSufficientAmountOfToken1(
                liquidity0, [sqrtRatioX96, sqrtRatioXA96, sqrtRatioXB96, _sqrtPriceLimitX96], _originalAmount1, _amount0OutMin
            );
        } else {
            // we are swapping token0 for token1
            return swapSufficientAmountOfToken0(
                liquidity1, [sqrtRatioX96, sqrtRatioXA96, sqrtRatioXB96, _sqrtPriceLimitX96], _originalAmount0, _amount1OutMin
            );
        }
    }

    function swapSufficientAmountOfToken1(
        uint128 liquidity0,
        uint160[4] memory ratios,
        uint256 _originalAmount1,
        uint256 _amount0OutMin
    ) internal returns (uint256, uint256) {
        // obtains the ratio of assets across the entire uniswap liquidity
        // the ratio will be used as a spot price for expressing the amount of
        // token1 that came into the swap in the units of token0
        (uint256 amountForPrice0, uint256 amountForPrice1) = LiquidityAmounts.getAmountsForLiquidity(
            ratios[0],
            TickMath.getSqrtRatioAtTick(TickMath.MIN_TICK),
            TickMath.getSqrtRatioAtTick(TickMath.MAX_TICK),
            _LIQUIDITY_CONSTANT
        );

        // calculate how much of each token we actually need to get the liquidity
        // the rest of the token1 amount will be treated as excess and swapped to token0
        // if there is no token0, so liquidity0 == 0, we still need some ratio
        // for scaling the excess based on amount1/amount0, so we use _LIQUIDITY_CONSTANT
        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            ratios[0], ratios[1], ratios[2], liquidity0 == 0 ? _LIQUIDITY_CONSTANT : liquidity0
        );

        uint256 _leftover1;
        if (liquidity0 == 0) {
            // we have no token0, so the entire amount of token1 should be used for swapping
            _leftover1 = _originalAmount1;
        } else {
            // we have and need amount0 of token0, this will be matched by amount1 of token1
            // the rest of token1 is _leftover1 and it will be swapped to the proper rate
            // we know that _originalAmount1 >= amount1 because the caller checks
            // that liquidity0 < liquidity1
            _leftover1 = _originalAmount1.sub(amount1);
        }

        // converts the amount of token0 into the common unit of token1
        uint256 _amount0InToken1 = amount0.mul(amountForPrice1).div(amountForPrice0);
        // calculates how much of the token1 excess should stay in token1
        uint256 toKeepInToken1 = _leftover1.mul(amount1).div(_amount0InToken1.add(amount1));
        // swaps the excess of token1 that should be converted to token0
        return swap(ratios[3], 0, _leftover1.sub(toKeepInToken1), _amount0OutMin, 0);
    }

    function swapSufficientAmountOfToken0(
        uint128 liquidity1,
        uint160[4] memory ratios,
        uint256 _originalAmount0,
        uint256 _amount1OutMin
    ) internal returns (uint256, uint256) {
        // obtains the ratio of assets across the entire uniswap liquidity
        // the ratio will be used as a spot price for expressing the amount of
        // token0 that came into the swap in the units of token1
        (uint256 amountForPrice0, uint256 amountForPrice1) = LiquidityAmounts.getAmountsForLiquidity(
            ratios[0],
            TickMath.getSqrtRatioAtTick(TickMath.MIN_TICK),
            TickMath.getSqrtRatioAtTick(TickMath.MAX_TICK),
            _LIQUIDITY_CONSTANT
        );

        // calculate how much of each token we actually need to get the liquidity
        // the rest of the token0 amount will be treated as excess and swapped to token1
        // if there is no token1, so liquidity1 == 0, we still need some ratio
        // for scaling the excess based on amount1/amount0, so we use _LIQUIDITY_CONSTANT
        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            ratios[0], ratios[1], ratios[2], liquidity1 == 0 ? _LIQUIDITY_CONSTANT : liquidity1
        );
        uint256 _leftover0;
        if (liquidity1 == 0) {
            // we have no token1, so the entire amount of token0 should be used for swapping
            _leftover0 = _originalAmount0;
        } else {
            // we have and need amount1 of token1, this will be matched by amount0 of token0
            // the rest of token0 is _leftover0 and it will be swapped to the proper rate
            // we know that _originalAmount0 >= amount0 because the caller checks
            // that liquidity1 > liquidity0
            _leftover0 = _originalAmount0.sub(amount0);
        }

        // converts the amount of token1 into the common unit of token0
        uint256 _amount1InToken0 = amount1.mul(amountForPrice0).div(amountForPrice1);
        // calculates how much of the token0 excess should stay in token0
        uint256 toKeepInToken0 = _leftover0.mul(amount0).div(_amount1InToken0.add(amount0));
        // swaps the excess of token0 that should be converted to token1
        return swap(ratios[3], _leftover0.sub(toKeepInToken0), 0, 0, _amount1OutMin);
    }

    // for compatibility
    function zap(uint256 _originalAmount0, uint256 _originalAmount1) external {
        zap(0, _originalAmount0, _originalAmount1, 0, 0);
    }

    // for compatibility
    function swap(uint256 _amount0In, uint256 _amount1In) external {
        swap(0, _amount0In, _amount1In, 0, 0);
    }

    /**
     * @dev Swaps token0 amount for token1 or the other way round. One of the parameters
     * always has to be 0. The safeguarding against slippage is left to the caller.
     * @param _amount0In the amount to swap for token1
     * @param _amount1In the amount to swap for token0
     */
    function swap(uint160 _sqrtPriceLimitX96, uint256 _amount0In, uint256 _amount1In, uint256 _amount0Out, uint256 _amount1Out)
        public
        returns (uint256, uint256)
    {
        require(_amount1In == 0 || _amount0In == 0, "Choose one token");
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        if (_amount0In == 0) {
            tokenIn = getStorage().token1();
            tokenOut = getStorage().token0();
            amountIn = _amount1In;
            amountOut = _amount0Out;
        } else {
            tokenIn = getStorage().token0();
            tokenOut = getStorage().token1();
            amountIn = _amount0In;
            amountOut = _amount1Out;
        }

        IERC20Upgradeable(tokenIn).safeApprove(_SWAP_ROUTER, 0);
        IERC20Upgradeable(tokenIn).safeApprove(_SWAP_ROUTER, amountIn);
        uint256 actualAmountOut = ISwapRouter(_SWAP_ROUTER).exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: getStorage().fee(),
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: amountOut,
                sqrtPriceLimitX96: _sqrtPriceLimitX96
            })
        );

        if (_amount0In == 0) {
            return (actualAmountOut, 0);
        }
        return (0, actualAmountOut);
    }

    /**
     * @dev Handles zap for the case when we have 0 token0s
     */
    function _zapZero0(uint256 _originalAmount1, uint256 _amount0OutMin, uint160 _sqrtPriceLimitX96)
        internal
        returns (uint256, uint256)
    {
        uint160 sqrtRatioX96 = getSqrtPriceX96();
        uint160 sqrtRatioXA96 = TickMath.getSqrtRatioAtTick(getStorage().tickLower());
        uint160 sqrtRatioXB96 = TickMath.getSqrtRatioAtTick(getStorage().tickUpper());

        if (sqrtRatioX96 <= sqrtRatioXA96) {
            // we are below the low range, swap _originalAmount1 to token0
            // the amount is not 0, because this was checked upstream
            return swap(_sqrtPriceLimitX96, 0, _originalAmount1, _amount0OutMin, 0);
        } else if (sqrtRatioX96 >= sqrtRatioXB96) {
            // we are above range, should be swapping token0 to token1, but we do not have any
            // so this is a no-op
            return (0, 0);
        }

        return swapSufficientAmountOfToken1(
            0, [sqrtRatioX96, sqrtRatioXA96, sqrtRatioXB96, _sqrtPriceLimitX96], _originalAmount1, _amount0OutMin
        );
    }

    /**
     * @dev Handles zap for the case when we have 0 token1s
     */
    function _zapZero1(uint256 _originalAmount0, uint256 _amount1OutMin, uint160 _sqrtPriceLimitX96)
        internal
        returns (uint256, uint256)
    {
        uint160 sqrtRatioX96 = getSqrtPriceX96();
        uint160 sqrtRatioXA96 = TickMath.getSqrtRatioAtTick(getStorage().tickLower());
        uint160 sqrtRatioXB96 = TickMath.getSqrtRatioAtTick(getStorage().tickUpper());

        if (sqrtRatioX96 <= sqrtRatioXA96) {
            return (0, 0);
            // we are below the low range, swap amount1 to token0 but that amount is 0
            // this is a no-op
        } else if (sqrtRatioX96 >= sqrtRatioXB96) {
            // the amount is not 0, because this was checked upstream
            return swap(_sqrtPriceLimitX96, _originalAmount0, 0, 0, _amount1OutMin);
        }

        return swapSufficientAmountOfToken0(
            0, [sqrtRatioX96, sqrtRatioXA96, sqrtRatioXB96, _sqrtPriceLimitX96], _originalAmount0, _amount1OutMin
        );
    }

    /**
     * @dev Convenience getter for the data contract.
     */
    function getStorage() public view returns (UniVaultStorageV1) {
        return UniVaultStorageV1(getAddress(_DATA_CONTRACT_SLOT));
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
     * @dev Reads an address from a slot.
     */
    function getAddress(bytes32 slot) internal view returns (address str) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            str := sload(slot)
        }
    }
}
