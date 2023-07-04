//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;
pragma abicoder v2;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

// This is a mock contract to create fees in UniswapV3 pair.
contract BoredSwapper {
    address internal constant _SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    constructor() {}

    function accrueFees(address originToken, address intermediateToken, uint24 fee, uint256 originTokenAmountIn) public {
        IERC20Upgradeable(originToken).approve(_SWAP_ROUTER, uint256(-1));
        IERC20Upgradeable(intermediateToken).approve(_SWAP_ROUTER, uint256(-1));

        uint256 intermediateBalanceBefore = IERC20Upgradeable(intermediateToken).balanceOf(address(this));

        require(
            IERC20Upgradeable(originToken).balanceOf(address(this)) >= originTokenAmountIn,
            "funds needed to simulate the increment of fees!"
        );

        ISwapRouter(_SWAP_ROUTER).exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: originToken,
                tokenOut: intermediateToken,
                fee: fee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: originTokenAmountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        uint256 intermediateBalanceAfter = IERC20Upgradeable(intermediateToken).balanceOf(address(this));
        uint256 intermediateBalanceDiff = intermediateBalanceAfter - intermediateBalanceBefore;

        ISwapRouter(_SWAP_ROUTER).exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: intermediateToken,
                tokenOut: originToken,
                fee: fee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: intermediateBalanceDiff,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
    }

    function withdraw(address token) public {
        uint256 balance = IERC20Upgradeable(token).balanceOf(address(this));
        IERC20Upgradeable(token).transfer(msg.sender, balance);
    }
}
