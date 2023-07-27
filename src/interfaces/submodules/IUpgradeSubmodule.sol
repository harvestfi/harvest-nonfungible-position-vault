// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/*
 * \
 * Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
 * EIP-2535 Systems: https://eips.ethereum.org/EIPS/eip-2535
 * /*****************************************************************************
 */

// Libraries
import {LibDataTypes} from "../../libraries/LibDataTypes.sol";

interface IUpgradeSubmodule {
    /// @notice Add/replace/remove any number of functions and optionally execute
    ///         a function with delegatecall
    /// @param __submoduleUpgrade Contains the submodule addresses and function selectors
    /// @param _init The address of the contract or submodule to execute _calldata
    /// @param _calldata A function call, including function selector and arguments
    ///                  _calldata is executed with delegatecall on _init
    function submoduleUpgrade(
        LibDataTypes.SubmoduleUpgrade[] calldata __submoduleUpgrade,
        address _init,
        bytes calldata _calldata
    ) external;
}
