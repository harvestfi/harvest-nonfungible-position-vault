//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Interfaces
import {IController} from "../interfaces/utils/IController.sol";
import {IGovernanceSubmodule} from "../interfaces/submodules/IGovernanceSubmodule.sol";

// Libraries
import {LibEvents} from "../libraries/LibEvents.sol";

// Helpers
import {Modifiers} from "../core/Modifiers.sol";

contract GovernanceSubmodule is Modifiers, IGovernanceSubmodule {
    function scheduleUpgrade(address _init) external onlyGovernance {
        s.nextImplementationTimestamp = block.timestamp + IController(s.controller).nextImplementationDelay();
        s.nextInitContract = _init;

        emit LibEvents.ScheduleUpgrade(s.nextImplementationTimestamp, s.nextInitContract);
    }

    function finalizeUpgrade() external onlyGovernance {
        s.nextImplementationTimestamp = 0;
        s.nextInitContract = address(0);

        emit LibEvents.ScheduleUpgrade(s.nextImplementationTimestamp, s.nextInitContract);
    }

    function shouldUpgrade() external view returns (bool _upgradeStatus, address _nextImplementation) {
        return (s.nextImplementationTimestamp != 0 && block.timestamp > s.nextImplementationTimestamp, s.nextInitContract);
    }
}
