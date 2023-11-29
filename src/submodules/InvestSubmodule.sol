//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// External Packages
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Interfaces
import {IInvestSubmodule} from "../interfaces/submodules/IInvestSubmodule.sol";
import {IUniversalLiquidator} from "../interfaces/utils/IUniversalLiquidator.sol";

// Libraries
import {LibEvents} from "../libraries/LibEvents.sol";
import {LibPositionManager} from "../libraries/LibPositionManager.sol";
import {LibVaultOps} from "../libraries/LibVaultOps.sol";
import {LibZap} from "../libraries/LibZap.sol";

// Helpers
import {Modifiers} from "../core/Modifiers.sol";

contract InvestSubmodule is Modifiers, IInvestSubmodule {
    using SafeERC20 for IERC20;

    function doHardWork(uint256 _positionId) external override onlyGovernanceOrController {
        // claim rewards: harvest + collect
        LibPositionManager.harvest(_positionId);
        LibPositionManager.collect(_positionId);
        // liquidate to universal reward token through universal liquidators
        if (s.liquidationRewardPause) {
            // profits can be disabled for possible simplified and rapoolId exit
            emit LibEvents.RewardLiquidationPaused(s.liquidationRewardPause);
            return;
        }

        LibVaultOps.beforeProfitShareLiquidation();
        //LibVaultOps.notifyProfitInRewardToken();
        LibVaultOps.afterProfitShareLiquidation();

        // increase liquidity (LibPositionManager)
        uint256 tokenBalance = IERC20(s.unifiedDepositToken).balanceOf(address(this));
        if (tokenBalance > 0) {
            if (s.unifiedDepositToken == s.token0) {
                (uint256 actualAmount0, uint256 actualAmount1) = LibZap.zap(_positionId, 0, tokenBalance, 0, 0, 0);
                //LibPositionManager.increaseLiquidity(_positionId, tokenBalance);
            } else {}
        }
    }
}
