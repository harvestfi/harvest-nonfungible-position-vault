// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

library LibDataTypes {
    enum SubmoduleUpgradeAction {
        Add,
        Replace,
        Remove,
        None
    }
    // Add=0, Replace=1, Remove=2

    struct SubmoduleUpgrade {
        address submoduleAddress;
        SubmoduleUpgradeAction action;
        bytes4[] functionSelectors;
    }

    struct IncreaseLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }
}
