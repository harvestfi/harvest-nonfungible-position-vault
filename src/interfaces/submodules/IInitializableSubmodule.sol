// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IInitializableSubmodule {
    function disableInitializers() external;
    function getInitializedVersion() external view returns (uint8);
    function isInitializing() external view returns (bool);
}
