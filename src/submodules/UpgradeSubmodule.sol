// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/**
 * \
 * Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
 * EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
 * /*****************************************************************************
 */

// Interfaces
import {IUpgradeSubmodule} from "../interfaces/submodules/IUpgradeSubmodule.sol";

// Libraries
import {LibFunctionRouter} from "../libraries/LibFunctionRouter.sol";
import {LibDataTypes} from "../libraries/LibDataTypes.sol";
import {LibEvents} from "../libraries/LibEvents.sol";

contract UpgradeSubmodule is IUpgradeSubmodule {
    /// @notice Add/replace/remove any number of functions and optionally execute
    ///         a function with delegatecall
    /// @param _submoduleUpgrade Contains the submodule addresses and function selectors
    /// @param _init The address of the contract or submodule to execute _calldata
    /// @param _calldata A function call, including function selector and arguments
    ///                  _calldata is executed with delegatecall on _init
    function submoduleUpgrade(LibDataTypes.SubmoduleUpgrade[] calldata _submoduleUpgrade, address _init, bytes calldata _calldata)
        external
        override
    {
        LibFunctionRouter.enforceIsContractOwner();
        LibFunctionRouter.FunctionRouterStorage storage frs = LibFunctionRouter.functionRouterStorage();
        uint256 originalSelectorCount = frs.selectorCount;
        uint256 selectorCount = originalSelectorCount;
        bytes32 selectorSlot;
        // Check if last selector slot is not full
        // "selectorCount & 7" is a gas efficient modulo by eight "selectorCount % 8"
        if (selectorCount & 7 > 0) {
            // get last selectorSlot
            // "selectorCount >> 3" is a gas efficient division by 8 "selectorCount / 8"
            selectorSlot = frs.selectorSlots[selectorCount >> 3];
        }
        // loop through submodule cut
        for (uint256 submoduleIndex = 0; submoduleIndex < _submoduleUpgrade.length; submoduleIndex++) {
            (selectorCount, selectorSlot) = LibFunctionRouter.addReplaceRemoveSubmoduleSelectors(
                selectorCount,
                selectorSlot,
                _submoduleUpgrade[submoduleIndex].submoduleAddress,
                _submoduleUpgrade[submoduleIndex].action,
                _submoduleUpgrade[submoduleIndex].functionSelectors
            );
        }
        if (selectorCount != originalSelectorCount) {
            frs.selectorCount = uint16(selectorCount);
        }
        // If last selector slot is not full
        // "selectorCount & 7" is a gas efficient modulo by eight "selectorCount % 8"
        if (selectorCount & 7 > 0) {
            // "selectorCount >> 3" is a gas efficient division by 8 "selectorCount / 8"
            frs.selectorSlots[selectorCount >> 3] = selectorSlot;
        }
        emit LibEvents.SubmoduleUpgrade(_submoduleUpgrade, _init, _calldata);
        LibFunctionRouter.initializeFunctionRouter(_init, _calldata);
    }
}
