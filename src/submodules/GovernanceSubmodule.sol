//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Interfaces
import {IGovernanceSubmodule} from "../interfaces/submodules/IGovernanceSubmodule.sol";

// Libraries
import {LibEvents} from "../libraries/LibEvents.sol";

// Helpers
import {Modifiers} from "../core/Modifiers.sol";

// TODO: Require to confirm implementation here
contract GovernanceSubmodule is Modifiers, IGovernanceSubmodule {
    function scheduleUpgrade(address _init) external onlyGovernance {
        s.nextImplementationTimestamp = block.timestamp + s.nextImplementationDelay;
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

    /*
    function createUpgrade(bytes32 id) external onlyGovernance {
        if (s.upgradeScheduled[id] > block.timestamp) {
            revert("Upgrade has already been scheduled");
        }
        // 0 == upgrade is not scheduled / has been cancelled
        // block.timestamp + upgradeExpiration == upgrade is scheduled and expires at this time
        // Set back to 0 when an upgrade is complete
        s.upgradeScheduled[id] = block.timestamp + s.upgradeExpiration;
        emit LibEvents.CreateUpgrade(id, msg.sender);
    }

    function updateUpgradeExpiration(uint256 duration) external onlyGovernance {
        require(1 minutes < duration && duration < 1 weeks, "invalid upgrade expiration period");

        s.upgradeExpiration = duration;
        emit LibEvents.UpdateUpgradeExpiration(duration);
    }

    function cancelUpgrade(bytes32 id) external onlyGovernance {
        require(s.upgradeScheduled[id] > 0, "invalid upgrade ID");

        s.upgradeScheduled[id] = 0;

        emit LibEvents.UpgradeCancelled(id, msg.sender);
    }

    function getUpgrade(bytes32 id) external view returns (uint256 expiry) {
        expiry = s.upgradeScheduled[id];
    }

    function getUpgradeExpiration() external view returns (uint256 upgradeExpiration) {
        upgradeExpiration = s.upgradeExpiration;
    }
    */
}
