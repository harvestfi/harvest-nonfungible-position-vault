//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Interfaces
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IConfigureSubmodule} from "../interfaces/submodules/IConfigureSubmodule.sol";

// Libraries
import {Position} from "../libraries/LibAppStorage.sol";
import {LibPostionManager} from "../libraries/LibPostionManager.sol";
import {LibEvents} from "../libraries/LibEvents.sol";

// Helpers
import {Modifiers} from "../core/Modifiers.sol";

contract ConfigureSubmodule is Modifiers, IConfigureSubmodule {
    function configureFees(address _feeRewardForwarder, uint256 _feeRatio, address _platformTarget, uint256 _platformRatio)
        external
        override
        onlyGovernance
    {
        s.feeRewardForwarder = _feeRewardForwarder;
        s.platformTarget = _platformTarget;
        s.feeRatio = _feeRatio;
        s.platformRatio = _platformRatio;

        emit LibEvents.FeeConfigurationUpdate(_feeRewardForwarder, _feeRatio, _platformTarget, _platformRatio);
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
}
