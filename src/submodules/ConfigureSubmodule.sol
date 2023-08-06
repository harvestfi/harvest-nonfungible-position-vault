//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Interfaces
import {IConfigureSubmodule} from "../interfaces/submodules/IConfigureSubmodule.sol";

// Libraries
import {AppStorage, LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibPostionManager} from "../libraries/LibPostionManager.sol";
import {LibEvents} from "../libraries/LibEvents.sol";

// Helpers
import {Modifiers} from "../core/Modifiers.sol";

contract ConfigureSubmodule is Modifiers, IConfigureSubmodule {
    AppStorage internal s;

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

    function configurePool(address _token0, address _token1, uint24 _fee, string calldata _vaultName)
        external
        override
        onlyGovernanceOrController
    {
        s.token0 = _token0;
        s.token1 = _token1;
        s.fee = _fee;
        s.vaultName = _vaultName;

        emit LibEvents.PoolConfigurationUpdate(_token0, _token1, _fee, _vaultName);
    }

    function setVaultPause(bool _pause) public override onlyGovernanceOrController {
        s.vaultPause = _pause;

        emit LibEvents.VaultPauseUpdate(_pause);
    }
}
