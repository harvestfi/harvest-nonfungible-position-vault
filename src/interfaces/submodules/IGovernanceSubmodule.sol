// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IGovernanceSubmodule {
    function scheduleUpgrade(address _initContract) external;

    function finalizeUpgrade() external;

    function shouldUpgrade() external view returns (bool _upgradeStatus, address _nextInitContract);
}
