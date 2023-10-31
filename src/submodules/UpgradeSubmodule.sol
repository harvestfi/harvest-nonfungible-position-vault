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
import {LibErrors} from "../libraries/LibErrors.sol";

// Helpers
import {Modifiers} from "../core/Modifiers.sol";

// TODO: Require to make this part gated the upgrade time
contract UpgradeSubmodule is Modifiers, IUpgradeSubmodule {
    /// @notice Add/replace/remove any number of functions and optionally execute
    ///         a function with delegatecall
    /// @param _submoduleUpgrade Contains the submodule addresses and function selectors
    /// @param _init The address of the contract or submodule to execute _calldata
    /// @param _calldata A function call, including function selector and arguments
    ///                  _calldata is executed with delegatecall on _init
    function submoduleUpgrade(LibDataTypes.SubmoduleUpgrade calldata _submoduleUpgrade, address _init, bytes calldata _calldata)
        external
        override
        onlyGovernanceOrController
    {
        if (s.nextInitContract != _init) {
            revert LibErrors.InvalidAddress(LibErrors.AddressErrorCodes.DoesNotMatch, s.nextInitContract);
        }

        if (s.nextImplementationTimestamp < block.timestamp) {
            revert LibErrors.InvalidTimestamp(LibErrors.TimestampErrorCodes.TooEarly, s.nextImplementationTimestamp);
        }

        // TODO: Finish implement this
        if (s.submoduleUpgrade != _submoduleUpgrade) {}

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
        (selectorCount, selectorSlot) = LibFunctionRouter.addReplaceRemoveSubmoduleSelectors(
            selectorCount,
            selectorSlot,
            _submoduleUpgrade.submoduleAddress,
            _submoduleUpgrade.action,
            _submoduleUpgrade.functionSelectors
        );
        if (selectorCount != originalSelectorCount) {
            frs.selectorCount = uint16(selectorCount);
        }
        // If last selector slot is not full
        // "selectorCount & 7" is a gas efficient modulo by eight "selectorCount % 8"
        if (selectorCount & 7 > 0) {
            // "selectorCount >> 3" is a gas efficient division by 8 "selectorCount / 8"
            frs.selectorSlots[selectorCount >> 3] = selectorSlot;
        }
        LibDataTypes.SubmoduleUpgrade[] memory __submoduleUpgrade = new LibDataTypes.SubmoduleUpgrade[](1);
        __submoduleUpgrade[0] = _submoduleUpgrade;
        emit LibEvents.SubmoduleUpgrade(__submoduleUpgrade, _init, _calldata);
        LibFunctionRouter.initializeFunctionRouter(_init, _calldata);
    }
}
