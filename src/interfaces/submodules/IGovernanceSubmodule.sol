// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Libraries
import {LibDataTypes} from "../../libraries/LibDataTypes.sol";

interface IGovernanceSubmodule {
    function scheduleUpgrade(LibDataTypes.SubmoduleUpgrade calldata _submoduleUpgrade, address _initContract) external;

    function finalizeUpgrade() external;

    function shouldUpgrade() external view returns (bool _upgradeStatus, address _nextInitContract);
}
