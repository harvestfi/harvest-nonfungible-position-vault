//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// External Packages
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

// Interfaces
import {IController} from "../interfaces/utils/IController.sol";
import {IRewardForwarder} from "../interfaces/utils/IRewardForwarder.sol";
import {IUniversalLiquidator} from "../interfaces/utils/IUniversalLiquidator.sol";

// Libraries
import {AppStorage, LibAppStorage} from "./LibAppStorage.sol";
import {LibPositionManager} from "./LibPositionManager.sol";
import {LibConstants} from "./LibConstants.sol";
import {LibErrors} from "./LibErrors.sol";
import {LibEvents} from "./LibEvents.sol";

library LibVaultOps {
    using SafeERC20 for IERC20;

    function beforeProfitShareLiquidation() internal {
        AppStorage storage s = LibAppStorage.systemStorage();

        if (s.unifiedRewardToken == address(0) || s.unifiedDepositToken == address(0) || s.rewardTokens.length == 0) {
            revert LibErrors.LiquidationInfoUnconfigured();
        }

        address universalRewardToken = s.unifiedRewardToken;
        address universalLiquidator = s.universalLiquidator;
        // liquidate all reward token to unifiedRewardToken
        for (uint256 i = 0; i < s.rewardTokens.length; i++) {
            address token = s.rewardTokens[i];
            uint256 balance = IERC20(token).balanceOf(address(this));

            if (token == universalRewardToken || balance == 0) {
                // skip if token is already unifiedRewardToken or balance is 0
                continue;
            }
            IERC20(token).safeApprove(universalLiquidator, 0);
            IERC20(token).safeApprove(universalLiquidator, balance);
            // we can accept 1 as the minimum because this will be called only by a trusted worker
            IUniversalLiquidator(universalLiquidator).swap(token, universalRewardToken, balance, 1, address(this));
        }
    }

    function afterProfitShareLiquidation() internal {
        AppStorage storage s = LibAppStorage.systemStorage();

        address universalRewardToken = s.unifiedRewardToken;
        address universalLiquidator = s.universalLiquidator;
        address universalDepositToken = s.unifiedDepositToken;
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
    }

    function notifyProfitInRewardToken() internal {
        AppStorage storage s = LibAppStorage.systemStorage();
        address rewardToken = s.unifiedRewardToken;
        uint256 rewardBalance = IERC20(s.unifiedRewardToken).balanceOf(address(this));
        if (rewardBalance > 100) {
            uint256 feeDenominator = LibConstants._FEE_DENOMINATOR;
            uint256 strategistFee = rewardBalance * IController(s.controller).strategistFeeNumerator() / feeDenominator;
            uint256 platformFee = rewardBalance * IController(s.controller).platformFeeNumerator() / feeDenominator;
            uint256 profitSharingFee = rewardBalance * IController(s.controller).profitSharingNumerator() / feeDenominator;

            address strategyFeeRecipient = s.strategist;
            address platformFeeRecipient = s.governance;

            emit LibEvents.ProfitLogInReward(rewardToken, rewardBalance, profitSharingFee, block.timestamp);
            emit LibEvents.PlatformFeeLogInReward(platformFeeRecipient, rewardToken, rewardBalance, platformFee, block.timestamp);
            emit LibEvents.StrategistFeeLogInReward(
                strategyFeeRecipient, rewardToken, rewardBalance, strategistFee, block.timestamp
            );

            address rewardForwarder = IController(s.controller).rewardForwarder();
            IERC20(rewardToken).safeApprove(rewardForwarder, 0);
            IERC20(rewardToken).safeApprove(rewardForwarder, rewardBalance);

            // Distribute/send the fees
            IRewardForwarder(rewardForwarder).notifyFee(rewardToken, profitSharingFee, strategistFee, platformFee);
        } else {
            emit LibEvents.ProfitLogInReward(rewardToken, 0, 0, block.timestamp);
            emit LibEvents.PlatformFeeLogInReward(s.governance, rewardToken, 0, 0, block.timestamp);
            emit LibEvents.StrategistFeeLogInReward(s.strategist, rewardToken, 0, 0, block.timestamp);
        }
    }

    function getAllPositionLiquidity() internal view returns (uint256 totalLiquidity) {
        AppStorage storage s = LibAppStorage.systemStorage();
        for (uint256 index; index < s.positionCount;) {
            (,,,,, uint256 liquidity) = LibPositionManager.positionInfo(s.positions[index].tokenId);
            totalLiquidity += liquidity;
            unchecked {
                index++;
            }
        }
    }
}
