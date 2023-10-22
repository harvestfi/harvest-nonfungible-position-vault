//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Interfaces
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IConfigureSubmodule} from "../interfaces/submodules/IConfigureSubmodule.sol";

// Libraries
import {Position} from "../libraries/LibAppStorage.sol";
import {LibPositionManager} from "../libraries/LibPositionManager.sol";
import {LibConstants} from "../libraries/LibConstants.sol";
import {LibErrors} from "../libraries/LibErrors.sol";
import {LibEvents} from "../libraries/LibEvents.sol";

// Helpers
import {Modifiers} from "../core/Modifiers.sol";

contract ConfigureSubmodule is Modifiers, IConfigureSubmodule {
    function setProfitSharingNumerator(uint256 _profitSharingNumerator) public onlyGovernance {
        if (_profitSharingNumerator + s.strategistFeeNumerator + s.platformFeeNumerator > LibConstants._MAX_TOTAL_FEE) {
            revert LibErrors.FeeTooHigh(
                LibConstants._MAX_TOTAL_FEE, _profitSharingNumerator + s.strategistFeeNumerator + s.platformFeeNumerator
            );
        }

        s.nextProfitSharingNumerator = _profitSharingNumerator;
        s.nextProfitSharingNumeratorTimestamp = block.timestamp + s.nextImplementationDelay;
        emit LibEvents.QueueProfitSharingChange(s.nextProfitSharingNumerator, s.nextProfitSharingNumeratorTimestamp);
    }

    function confirmSetProfitSharingNumerator() public onlyGovernance {
        if (s.nextProfitSharingNumerator == 0 || s.nextProfitSharingNumeratorTimestamp == 0) {
            revert LibErrors.FeeParametersUnconfigured(s.nextProfitSharingNumerator, s.nextProfitSharingNumeratorTimestamp);
        }

        if (block.timestamp < s.nextProfitSharingNumeratorTimestamp) {
            revert LibErrors.FeeUpdateExpired(s.nextProfitSharingNumeratorTimestamp);
        }

        s.profitSharingNumerator = s.nextProfitSharingNumerator;
        s.nextProfitSharingNumerator = 0;
        s.nextProfitSharingNumeratorTimestamp = 0;
        emit LibEvents.ConfirmProfitSharingChange(s.profitSharingNumerator);
    }

    function setStrategistFeeNumerator(uint256 _strategistFeeNumerator) public onlyGovernance {
        if (_strategistFeeNumerator + s.platformFeeNumerator + s.profitSharingNumerator > LibConstants._MAX_TOTAL_FEE) {
            revert LibErrors.FeeTooHigh(
                LibConstants._MAX_TOTAL_FEE, _strategistFeeNumerator + s.platformFeeNumerator + s.profitSharingNumerator
            );
        }

        s.nextStrategistFeeNumerator = _strategistFeeNumerator;
        s.nextStrategistFeeNumeratorTimestamp = block.timestamp + s.nextImplementationDelay;
        emit LibEvents.QueueStrategistFeeChange(s.nextStrategistFeeNumerator, s.nextStrategistFeeNumeratorTimestamp);
    }

    function confirmSetStrategistFeeNumerator() public onlyGovernance {
        if (s.nextStrategistFeeNumerator == 0 || s.nextStrategistFeeNumeratorTimestamp == 0) {
            revert LibErrors.FeeParametersUnconfigured(s.nextStrategistFeeNumerator, s.nextStrategistFeeNumeratorTimestamp);
        }

        if (block.timestamp < s.nextStrategistFeeNumeratorTimestamp) {
            revert LibErrors.FeeUpdateExpired(s.nextStrategistFeeNumeratorTimestamp);
        }

        s.strategistFeeNumerator = s.nextStrategistFeeNumerator;
        s.nextStrategistFeeNumerator = 0;
        s.nextStrategistFeeNumeratorTimestamp = 0;
        emit LibEvents.ConfirmStrategistFeeChange(s.strategistFeeNumerator);
    }

    function setPlatformFeeNumerator(uint256 _platformFeeNumerator) public onlyGovernance {
        if (_platformFeeNumerator + s.strategistFeeNumerator + s.profitSharingNumerator > LibConstants._MAX_TOTAL_FEE) {
            revert LibErrors.FeeTooHigh(
                LibConstants._MAX_TOTAL_FEE, _platformFeeNumerator + s.strategistFeeNumerator + s.profitSharingNumerator
            );
        }

        s.nextPlatformFeeNumerator = _platformFeeNumerator;
        s.nextPlatformFeeNumeratorTimestamp = block.timestamp + s.nextImplementationDelay;
        emit LibEvents.QueuePlatformFeeChange(s.nextPlatformFeeNumerator, s.nextPlatformFeeNumeratorTimestamp);
    }

    function confirmSetPlatformFeeNumerator() public onlyGovernance {
        if (s.nextPlatformFeeNumerator == 0 || s.nextPlatformFeeNumeratorTimestamp == 0) {
            revert LibErrors.FeeParametersUnconfigured(s.nextPlatformFeeNumerator, s.nextPlatformFeeNumeratorTimestamp);
        }

        if (block.timestamp < s.nextPlatformFeeNumeratorTimestamp) {
            revert LibErrors.FeeUpdateExpired(s.nextPlatformFeeNumeratorTimestamp);
        }

        s.platformFeeNumerator = s.nextPlatformFeeNumerator;
        s.nextPlatformFeeNumerator = 0;
        s.nextPlatformFeeNumeratorTimestamp = 0;
        emit LibEvents.ConfirmPlatformFeeChange(s.platformFeeNumerator);
    }

    function setNextImplementationDelay(uint256 _nextImplementationDelay) public onlyGovernance {
        if (_nextImplementationDelay == 0) {
            revert LibErrors.InvalidTimestamp(LibErrors.TimestampErrorCodes.CannotBeZero, _nextImplementationDelay);
        }

        s.tempNextImplementationDelay = _nextImplementationDelay;
        s.tempNextImplementationDelayTimestamp = block.timestamp + s.nextImplementationDelay;
        emit LibEvents.QueueNextImplementationDelay(s.tempNextImplementationDelay, s.tempNextImplementationDelayTimestamp);
    }

    function confirmNextImplementationDelay() public onlyGovernance {
        if (s.tempNextImplementationDelayTimestamp != 0 && block.timestamp < s.tempNextImplementationDelayTimestamp) {
            revert LibErrors.InvalidTimestamp(LibErrors.TimestampErrorCodes.TooEarly, s.tempNextImplementationDelayTimestamp);
        }

        s.nextImplementationDelay = s.tempNextImplementationDelay;
        s.tempNextImplementationDelay = 0;
        s.tempNextImplementationDelayTimestamp = 0;
        emit LibEvents.ConfirmNextImplementationDelay(s.nextImplementationDelay);
    }

    function configureExternalProtocol(address _nftPositionManager, address _masterchef)
        external
        override
        onlyGovernanceOrController
    {
        s.nonFungibleTokenPositionManager = _nftPositionManager;
        s.masterChef = _masterchef;

        emit LibEvents.ExternalFarmingContractUpdate(_nftPositionManager, _masterchef);
    }

    function configureInfrastructure(address _universalLiquidator, address _universalLiquidatorRegistry)
        external
        override
        onlyGovernanceOrController
    {
        s.universalLiquidator = _universalLiquidator;
        s.universalLiquidatorRegistry = _universalLiquidatorRegistry;

        emit LibEvents.InfrastructureUpdate(_universalLiquidator, _universalLiquidatorRegistry);
    }

    function configurePool(address _token0, address _token1, uint24 _fee, string calldata _vaultNamePrefix)
        external
        override
        onlyGovernanceOrController
    {
        s.token0 = _token0;
        s.token1 = _token1;
        s.fee = _fee;
        s.name =
            string(abi.encodePacked(_vaultNamePrefix, IERC20Metadata(_token0).symbol(), "_", IERC20Metadata(_token1).symbol()));

        emit LibEvents.PoolConfigurationUpdate(_token0, _token1, _fee, s.name);
    }

    function configureUnits() external override onlyGovernanceOrController {
        address token0 = s.token0;
        address token1 = s.token1;
        uint8 decimals0 = IERC20Metadata(token0).decimals();
        uint8 decimals1 = IERC20Metadata(token1).decimals();
        if (decimals0 != decimals1) {
            revert LibErrors.DecimalsMismatch(token0, decimals0, token1, decimals1);
        }
        s.underlyingDecimals = uint8(decimals0);
        s.underlyingUnit = 10 ** decimals0;

        emit LibEvents.UnitsUpdate(s.underlyingDecimals, s.underlyingUnit);
    }

    function addRewardTokens(address[] calldata _rewardTokens) external override onlyGovernance {
        for (uint256 index = 0; index < _rewardTokens.length;) {
            address rewardToken = _rewardTokens[index];
            if (s.rewardTokenRegistered[rewardToken]) {
                revert LibErrors.TokenAlreadyRegistered(rewardToken);
            }

            s.rewardTokens.push(rewardToken);
            s.rewardTokenRegistered[rewardToken] = true;
            unchecked {
                index++;
            }
        }

        emit LibEvents.RewardTokenAdded(s.rewardTokens.length - _rewardTokens.length, s.rewardTokens.length - 1);
    }

    function removeRewardToken(uint256 _index) external override onlyGovernance {
        address removedToken = s.rewardTokens[_index];
        s.rewardTokens[_index] = s.rewardTokens[s.rewardTokens.length - 1];
        s.rewardTokens.pop();
        s.rewardTokenRegistered[removedToken] = false;

        emit LibEvents.RewardTokenRemoved(removedToken);
    }

    function setUnifiedRewardToken(address _rewardToken) external override onlyGovernance {
        s.unifiedRewardToken = _rewardToken;

        emit LibEvents.UnifiedRewardTokenUpdate(_rewardToken);
    }

    function setUnifiedDepositToken(address _depositToken) external override onlyGovernance {
        s.unifiedDepositToken = _depositToken;

        emit LibEvents.UnifiedDepositTokenUpdate(_depositToken);
    }

    function setUnderlyingToken(address _underlyingToken) external override onlyGovernance {
        s.underlyingToken = _underlyingToken;

        emit LibEvents.UnderlyingTokenUpdate(_underlyingToken);
    }

    function addPosition(uint256 _tokenId, uint256 _liquidity, int24 _tickLower, int24 _tickUpper)
        external
        override
        onlyGovernanceOrController
    {
        Position storage position = s.positions[s.positionCount++];
        position.tokenId = _tokenId;
        position.initialLiquidity = _liquidity;
        position.tickLower = _tickLower;
        position.tickUpper = _tickUpper;

        emit LibEvents.PositionAdd(s.positionCount, _tokenId, _liquidity, _tickLower, _tickUpper);
    }

    function updatePosition(uint256 _positionId, uint256 _tokenId, uint256 _liquidity, int24 _tickLower, int24 _tickUpper)
        external
        override
        onlyGovernanceOrController
    {
        Position storage position = s.positions[_positionId];
        position.tokenId = _tokenId;
        position.initialLiquidity = _liquidity;
        position.tickLower = _tickLower;
        position.tickUpper = _tickUpper;

        emit LibEvents.PositionUpdate(_positionId, _tokenId, _liquidity, _tickLower, _tickUpper);
    }

    function setVaultPause(bool _pause) public override onlyGovernanceOrController {
        s.vaultPause = _pause;

        emit LibEvents.VaultPauseUpdate(_pause);
    }

    function setLiquidationRewardPause(bool _pause) public override onlyGovernanceOrController {
        s.liquidationRewardPause = _pause;

        emit LibEvents.LiquidationRewardPauseUpdate(_pause);
    }
}
