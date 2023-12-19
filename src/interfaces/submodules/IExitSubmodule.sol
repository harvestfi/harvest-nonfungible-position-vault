// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IExitSubmodule {
    function withdrawFullAmount() external;
    function withdrawByAmount() external;
}
