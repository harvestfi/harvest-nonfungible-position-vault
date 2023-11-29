// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// External Packages
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Utilities
import {D00Defaults, console2} from "./D00Defaults.t.sol";

// Interfaces
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../src/interfaces/protocols/pancake/ISwapRouter.sol";
import "../../src/interfaces/protocols/pancake/INonfungiblePositionManager.sol";
import "../../src/interfaces/protocols/pancake/IPancakeV3Pool.sol";

contract PoolHelper is D00Defaults {
    using SafeERC20 for IERC20;

    function mockSwap(uint256 _round, address _router, bytes memory _path0, bytes memory _path1, address _token0, address _token1)
        public
        virtual
    {
        address whale = makeAddr("Whale 0");
        deal(_token0, whale, 10 ether);
        for (uint256 index; index < _round;) {
            changePrank(whale);

            ISwapRouter.ExactInputParams memory swapInfo =
                ISwapRouter.ExactInputParams(_path0, whale, block.timestamp, IERC20(_token0).balanceOf(whale), 1);
            IERC20(_token0).safeApprove(_router, 0);
            IERC20(_token0).safeApprove(_router, type(uint256).max);
            ISwapRouter(_router).exactInput(swapInfo);

            IERC20(_token1).safeApprove(_router, 0);
            IERC20(_token1).safeApprove(_router, type(uint256).max);
            swapInfo = ISwapRouter.ExactInputParams(_path1, whale, block.timestamp, IERC20(_token1).balanceOf(whale), 1);
            ISwapRouter(_router).exactInput(swapInfo);

            changePrank(governance);
            unchecked {
                index++;
            }
        }
    }

    function getPositionInfo(uint256 _tokenId) public virtual {
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = INonfungiblePositionManager(nonFungibleManagerPancake).positions(_tokenId);

        console2.log("liquidity: ", liquidity);
        console2.log("feeGrowthInside0LastX128: ", feeGrowthInside0LastX128);
        console2.log("feeGrowthInside1LastX128: ", feeGrowthInside1LastX128);
        console2.log("tokensOwed0: ", tokensOwed0);
        console2.log("tokensOwed1: ", tokensOwed1);
    }
}
