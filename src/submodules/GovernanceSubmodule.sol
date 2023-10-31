//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Interfaces
import {IController} from "../interfaces/utils/IController.sol";
import {IGovernanceSubmodule} from "../interfaces/submodules/IGovernanceSubmodule.sol";

// Libraries
import {LibDataTypes} from "../libraries/LibDataTypes.sol";
import {LibEvents} from "../libraries/LibEvents.sol";

// Helpers
import {Modifiers} from "../core/Modifiers.sol";

contract GovernanceSubmodule is Modifiers, IGovernanceSubmodule {
    function scheduleUpgrade(LibDataTypes.SubmoduleUpgrade calldata _submoduleUpgrade, address _init) external onlyGovernance {
        s.nextImplementationTimestamp = block.timestamp + IController(s.controller).nextImplementationDelay();
        s.submoduleUpgrade = _submoduleUpgrade;
        s.nextInitContract = _init;

        emit LibEvents.ScheduleUpgrade(s.nextImplementationTimestamp, s.nextInitContract);
    }

    function finalizeUpgrade() external onlyGovernance {
        s.nextImplementationTimestamp = 0;
        s.submoduleUpgrade = LibDataTypes.SubmoduleUpgrade(address(0), LibDataTypes.SubmoduleUpgradeAction.None, new bytes4[](0));
        s.nextInitContract = address(0);

        emit LibEvents.ScheduleUpgrade(s.nextImplementationTimestamp, s.nextInitContract);
    }

    function shouldUpgrade() external view returns (bool _upgradeStatus, address _nextImplementation) {
        return (s.nextImplementationTimestamp != 0 && block.timestamp > s.nextImplementationTimestamp, s.nextInitContract);
    }
}
