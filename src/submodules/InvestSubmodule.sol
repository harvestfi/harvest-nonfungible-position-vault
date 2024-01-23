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

    function doHardWork() external override onlyGovernanceOrController {
        // claim rewards: harvest + collect
        LibPositionManager.harvest();
        LibPositionManager.collect();
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
            uint256 _amount0;
            uint256 _amount1;
            if (s.unifiedDepositToken == s.token0) {
                _amount0 = tokenBalance;
            } else {
                _amount1 = tokenBalance;
            }
            LibZap.zap(0, _amount0, _amount1, 0, 0);
            LibPositionManager.increaseLiquidity();
        }
    }
}
