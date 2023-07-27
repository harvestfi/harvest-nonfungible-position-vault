// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/*
 * \
 * Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
 * EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
 * /*****************************************************************************
 */

// Libraries
import {LibDataTypes} from "../../libraries/LibDataTypes.sol";

interface IFunctionInfoSubmodule {
    /// @notice Gets all submodule addresses and their four byte function selectors.
    /// @return submodules_ Submodule
    function submodules() external view returns (LibDataTypes.Submodule[] memory submodules_);

    /// @notice Gets all the function selectors supported by a specific submodule.
    /// @param _submodule The submodule address.
    /// @return submoduleFunctionSelectors_
    function submoduleFunctionSelectors(address _submodule) external view returns (bytes4[] memory submoduleFunctionSelectors_);

    /// @notice Get all the submodule addresses used by a diamond.
    /// @return submoduleAddresses_
    function submoduleAddresses() external view returns (address[] memory submoduleAddresses_);

    /// @notice Gets the submodule that supports the given selector.
    /// @dev If submodule is not found return address(0).
    /// @param _functionSelector The function selector.
    /// @return submoduleAddress_ The submodule address.
    function submoduleAddress(bytes4 _functionSelector) external view returns (address submoduleAddress_);
}
