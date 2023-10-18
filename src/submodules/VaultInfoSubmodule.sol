//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Interfaces
import {IVaultInfoSubmodule} from "../interfaces/submodules/IVaultInfoSubmodule.sol";

// Libraries
import {Position} from "../libraries/LibAppStorage.sol";
import {LibPositionManager} from "../libraries/LibPositionManager.sol";
import {LibVaultOps} from "../libraries/LibVaultOps.sol";
import {LibConstants} from "../libraries/LibConstants.sol";

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

    function feeDenominator() external pure override returns (uint256 _feeDenominator) {
        return LibConstants._FEE_DENOMINATOR;
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

    function underlyingToken() external view override returns (address _underlyingToken) {
        return s.underlyingToken;
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

    function underlyingDecimals() external view override returns (uint8 _underlyingDecimals) {
        return s.underlyingDecimals;
    }

    function underlyingUnit() external view override returns (uint256 _underlyingUnit) {
        return s.underlyingUnit;
    }

    /**
     * @dev Returns the current amount of underlying assets owned by the vault.
     */
    function underlyingBalanceWithInvestment() public view returns (uint256) {
        return LibVaultOps._getAllPositionLiquidity();
    }

    /**
     * @dev Returns the price per full share, scaled to 1e18
     */
    function getPricePerFullShare() public view override returns (uint256) {
        return s.totalSupply == 0 ? s.underlyingUnit : s.underlyingUnit * underlyingBalanceWithInvestment() / s.totalSupply;
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
