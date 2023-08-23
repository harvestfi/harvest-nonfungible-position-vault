//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// External Packages
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

// Interfaces
import {IUniversalLiquidator} from "../interfaces/protocols/universalLiquidator/IUniversalLiquidator.sol";
import {IInvestSubmodule} from "../interfaces/submodules/IInvestSubmodule.sol";

// Libraries
import {LibEvents} from "../libraries/LibEvents.sol";
import {LibPostionManager} from "../libraries/LibPostionManager.sol";

// Helpers
import {Modifiers} from "../core/Modifiers.sol";

contract InvestSubmodule is Modifiers, IInvestSubmodule {
    using SafeERC20 for IERC20;

    function doHardWork() external override onlyGovernanceOrController {
        // claim rewards: harvest + collect
        LibPostionManager.harvest();
        LibPostionManager.collect();
        // liquidate through universal liquidators

        if (s.liquidationRewardPause) {
            // profits can be disabled for possible simplified and rapoolId exit
            emit LibEvents.RewardLiquidationPaused(s.liquidationRewardPause);
            return;
        }

        address universalRewardToken = s.unifiedRewardToken;
        address universalDepositToken = s.unifiedDepositToken;
        address universalLiquidator = s.universalLiquidator;
        // liquidate all reward token to unifiedRewardToken
        // TODO: determine profit share model
        /*
        for (uint256 i = 0; i < s.rewardTokens.length; i++) {
            address token = s.rewardTokens[i];
            uint256 rewardBalance = IERC20(token).balanceOf(address(this));

            if (rewardBalance == 0) {
                continue;
            }

            uint256 toHodl = rewardBalance * hodlRatio() / hodlRatioBase;
            if (toHodl > 0) {
                IERC20(token).safeTransfer(hodlVault(), toHodl);
                rewardBalance = rewardBalance.sub(toHodl);
                if (rewardBalance == 0) {
                    continue;
                }
            }

            if (token == universalRewardToken) {
                // one of the reward tokens is the same as the token that we liquidate to ->
                // no liquidation necessary
                continue;
            }
            IERC20(token).safeApprove(universalLiquidator, 0);
            IERC20(token).safeApprove(universalLiquidator, rewardBalance);
            // we can accept 1 as the minimum because this will be called only by a trusted worker
            IUniversalLiquidator(universalLiquidator).swap(token, universalRewardToken, rewardBalance, 1, address(this));
        }

        uint256 rewardBalance = IERC20(universalRewardToken).balanceOf(address(this));
        notifyProfitInRewardToken(rewardBalance);
        uint256 remainingRewardBalance = IERC20(universalRewardToken).balanceOf(address(this));

        if (remainingRewardBalance == 0) {
            return;
        }

        if (universalDepositToken != universalRewardToken) {
            IERC20(universalRewardToken).safeApprove(universalLiquidator, 0);
            IERC20(universalRewardToken).safeApprove(universalLiquidator, remainingRewardBalance);

            // we can accept 1 as minimum because this is called only by a trusted role
            IUniversalLiquidator(universalLiquidator).swap(
                universalRewardToken, universalDepositToken, remainingRewardBalance, 1, address(this)
            );
        }
        */
        // increase liquidity (LibPositionManager)
        uint256 tokenBalance = IERC20(universalDepositToken).balanceOf(address(this));
        if (tokenBalance > 0) {
            LibPostionManager.increaseLiquidity();
        }
    }
}
