//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Interfaces
import {IGovernanceSubmodule} from "../interfaces/submodules/IGovernanceSubmodule.sol";

// Libraries
import {AppStorage, LibAppStorage} from "../core/AppStorage.sol";
import {LibEvents} from "../libraries/LibEvents.sol";

// Helpers
import {Modifiers} from "../core/Modifiers.sol";

contract GovernanceFacet is Modifiers, IGovernanceSubmodule {
    /**
     * @notice Check if the system has been initialized.
     * @dev This will get the value from AppStorage.systemInitialized.
     */
    function isSystemInitialized() external view returns (bool) {
        AppStorage storage s = LibAppStorage.systemStorage();
        return s.systemInitialized;
    }

    function createUpgrade(bytes32 id) external onlyGovernance {
        AppStorage storage s = LibAppStorage.systemStorage();

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
        AppStorage storage s = LibAppStorage.systemStorage();

        require(1 minutes < duration && duration < 1 weeks, "invalid upgrade expiration period");

        s.upgradeExpiration = duration;
        emit LibEvents.UpdateUpgradeExpiration(duration);
    }

    function cancelUpgrade(bytes32 id) external onlyGovernance {
        AppStorage storage s = LibAppStorage.systemStorage();

        require(s.upgradeScheduled[id] > 0, "invalid upgrade ID");

        s.upgradeScheduled[id] = 0;

        emit LibEvents.UpgradeCancelled(id, msg.sender);
    }

    function getUpgrade(bytes32 id) external view returns (uint256 expiry) {
        AppStorage storage s = LibAppStorage.systemStorage();
        expiry = s.upgradeScheduled[id];
    }

    function getUpgradeExpiration() external view returns (uint256 upgradeExpiration) {
        AppStorage storage s = LibAppStorage.systemStorage();
        upgradeExpiration = s.upgradeExpiration;
    }
}
