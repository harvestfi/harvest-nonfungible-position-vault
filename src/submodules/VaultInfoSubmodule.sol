//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Interfaces
import {IVaultInfoSubmodule} from "../interfaces/submodules/IVaultInfoSubmodule.sol";

// Libraries
import {Position} from "../libraries/LibAppStorage.sol";
import {LibPositionManager} from "../libraries/LibPositionManager.sol";

// Helpers
import {Modifiers} from "../core/Modifiers.sol";

contract VaultInfoSubmodule is Modifiers, IVaultInfoSubmodule {
    function initialized() external view override returns (uint8 _initialized) {
        return s.initialized;
    }

    function initializing() external view override returns (bool _initializing) {
        return s.initializing;
    }

    function vaultPause() external view override returns (bool _vaultPause) {
        return s.vaultPause;
    }

    function liquidationRewardPause() external view override returns (bool _liquidationRewardPause) {
        return s.liquidationRewardPause;
    }

    function governance() external view override returns (address _governance) {
        return s.governance;
    }

    function controller() external view override returns (address _controller) {
        return s.controller;
    }

    function feeDenominator() external view override returns (uint256 _feeDenominator) {
        return s.FEE_DENOMINATOR;
    }

    function strategist() external view override returns (address _strategist) {
        return s.strategist;
    }

    function strategistFeeNumerator() external view override returns (uint256 _strategistFeeNumerator) {
        return s.strategistFeeNumerator;
    }

    function platformFeeNumerator() external view override returns (uint256 _platformFeeNumerator) {
        return s.platformFeeNumerator;
    }

    function profitSharingNumerator() external view override returns (uint256 _profitSharingNumerator) {
        return s.profitSharingNumerator;
    }

    function upgradeScheduled(bytes32 _id) external view override returns (uint256 _upgradeScheduled) {
        return s.upgradeScheduled[_id];
    }

    function upgradeExpiration() external view override returns (uint256 _upgradeExpiration) {
        return s.upgradeExpiration;
    }

    function token0() external view override returns (address _token0) {
        return s.token0;
    }

    function token1() external view override returns (address _token1) {
        return s.token1;
    }

    function fee() external view override returns (uint24 _fee) {
        return s.fee;
    }

    function unifiedRewardToken() external view override returns (address _unifiedRewardToken) {
        return s.unifiedRewardToken;
    }

    function unifiedDepositToken() external view override returns (address _unifiedDepositToken) {
        return s.unifiedDepositToken;
    }

    function totalRewardToken() public view override returns (uint256 _totalCount) {
        return s.rewardTokens.length;
    }

    function rewardToken(uint256 _index) public view override returns (address _token) {
        return s.rewardTokens[_index];
    }

    function rewardTokenRegistered(address _rewardToken) external view override returns (bool _registered) {
        return s.rewardTokenRegistered[_rewardToken];
    }

    /*
    * Returns the cash balance across all users in this contract.
    */
    // TODO: Check if this is needed
    function underlyingBalanceInVault() public view returns (uint256) {
        return 0; //IERC20Upgradeable(underlying()).balanceOf(address(this));
    }

    /**
     * @dev Returns the current amount of underlying assets owned by the vault.
     */
    function underlyingBalanceWithInvestment() public view returns (uint256) {
        uint256 totalLiquidity;
        for (uint256 index; index < s.positionCount;) {
            (,,,,, uint256 liquidity) = LibPositionManager.positionInfo(s.positions[index].tokenId);
            totalLiquidity += liquidity;
            unchecked {
                index++;
            }
        }
        return underlyingBalanceInVault() + totalLiquidity;
    }

    /**
     * @dev Returns the price per full share, scaled to 1e18
     */
    function getPricePerFullShare() public view override returns (uint256) {
        return s.totalSupply == 0 ? s.UNDERLYING_UNIT : s.UNDERLYING_UNIT * underlyingBalanceWithInvestment() / s.totalSupply;
    }

    function positionCount() external view override returns (uint256 _count) {
        return s.positionCount;
    }

    function latestPositionId() external view override returns (uint256 _positionId) {
        return s.positionCount - 1;
    }

    function positions(uint256 _positionId) external view override returns (Position memory _position) {
        return s.positions[_positionId];
    }

    function allPosition() external view override returns (Position[] memory) {
        Position[] memory _positions = new Position[](s.positionCount);
        for (uint256 index; index < s.positionCount;) {
            _positions[index] = s.positions[index];
            unchecked {
                index++;
            }
        }
        return _positions;
    }

    function nonFungibleTokenPositionManager() external view override returns (address _nonFungibleTokenPositionManager) {
        return s.nonFungibleTokenPositionManager;
    }

    function masterChef() external view override returns (address _masterChef) {
        return s.masterChef;
    }

    function universalLiquidator() external view override returns (address _universalLiquidator) {
        return s.universalLiquidator;
    }

    function universalLiquidatorRegistry() external view override returns (address _universalLiquidatorRegistry) {
        return s.universalLiquidatorRegistry;
    }
}
