//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Interfaces
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IConfigureSubmodule} from "../interfaces/submodules/IConfigureSubmodule.sol";

// Libraries
import {Position} from "../libraries/LibAppStorage.sol";
import {LibPositionManager} from "../libraries/LibPositionManager.sol";
import {LibErrors} from "../libraries/LibErrors.sol";
import {LibEvents} from "../libraries/LibEvents.sol";

// Helpers
import {Modifiers} from "../core/Modifiers.sol";

contract ConfigureSubmodule is Modifiers, IConfigureSubmodule {
    function configureFees(
        address _strategist,
        uint256 _strategistFeeNumerator,
        uint256 _platformFeeNumerator,
        uint256 _profitSharingNumerator
    ) external override onlyGovernance {
        s.strategist = _strategist;
        s.strategistFeeNumerator = _strategistFeeNumerator;
        s.platformFeeNumerator = _platformFeeNumerator;
        s.profitSharingNumerator = _profitSharingNumerator;

        emit LibEvents.FeeConfigurationUpdate(
            _strategist, _strategistFeeNumerator, _platformFeeNumerator, _profitSharingNumerator
        );
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

    function addRewardTokens(address[] calldata _rewardTokens) external override onlyGovernance {
        for (uint256 i = 0; i < _rewardTokens.length; i++) {
            if (s.rewardTokenRegistered[_rewardTokens[i]]) {
                revert LibErrors.TokenAlreadyRegistered(_rewardTokens[i]);
            }

            s.rewardTokens.push(_rewardTokens[i]);
            s.rewardTokenRegistered[_rewardTokens[i]] = true;
        }

        emit LibEvents.RewardTokenAdded(s.rewardTokens.length - _rewardTokens.length - 1, s.rewardTokens.length - 1);
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
