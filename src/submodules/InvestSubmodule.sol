//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";

// External Packages
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

// Interfaces
import {IInvestSubmodule} from "../interfaces/submodules/IInvestSubmodule.sol";
import {IUniversalLiquidator} from "../interfaces/utils/IUniversalLiquidator.sol";

// Libraries
import {LibEvents} from "../libraries/LibEvents.sol";
import {LibPostionManager} from "../libraries/LibPostionManager.sol";
import {LibVaultOps} from "../libraries/LibVaultOps.sol";

// Helpers
import {Modifiers} from "../core/Modifiers.sol";

contract InvestSubmodule is Modifiers, IInvestSubmodule {
    using SafeERC20 for IERC20;

    function doHardWork(uint256 _positionId) external override onlyGovernanceOrController {
        console2.log("CAKE: ", IERC20(0x152649eA73beAb28c5b49B26eb48f7EAD6d4c898).balanceOf(address(this)));
        console2.log("TUSD: ", IERC20(0x0000000000085d4780B73119b644AE5ecd22b376).balanceOf(address(this)));
        console2.log("USDT: ", IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7).balanceOf(address(this)));

        // claim rewards: harvest + collect
        LibPostionManager.harvest(_positionId);
        LibPostionManager.collect(_positionId);
        // liquidate to universal reward token through universal liquidators
        if (s.liquidationRewardPause) {
            // profits can be disabled for possible simplified and rapoolId exit
            emit LibEvents.RewardLiquidationPaused(s.liquidationRewardPause);
            return;
        }

        console2.log("CAKE: ", IERC20(0x152649eA73beAb28c5b49B26eb48f7EAD6d4c898).balanceOf(address(this)));
        console2.log("TUSD: ", IERC20(0x0000000000085d4780B73119b644AE5ecd22b376).balanceOf(address(this)));
        console2.log("USDT: ", IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7).balanceOf(address(this)));

        LibVaultOps.beforeProfitShareLiquidation();
        LibVaultOps.notifyProfitInRewardToken();
        LibVaultOps.afterProfitShareLiquidation();

        // increase liquidity (LibPositionManager)
        uint256 tokenBalance = IERC20(s.unifiedDepositToken).balanceOf(address(this));
        if (tokenBalance > 0) {
            LibPostionManager.increaseLiquidity(_positionId);
        }
    }
}
