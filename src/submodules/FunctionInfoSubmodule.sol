// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/**
 * \
 * Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
 * EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
 * /*****************************************************************************
 */

// Interfaces
import {IFunctionInfoSubmodule} from "../interfaces/submodules/IFunctionInfoSubmodule.sol";
import {IERC165} from "../interfaces/shared/IERC165.sol";

// Libraries
import {LibFunctionRouter} from "../libraries/LibFunctionRouter.sol";
import {LibDataTypes} from "../libraries/LibDataTypes.sol";

// Helpers
import {Modifiers} from "../core/Modifiers.sol";

contract FunctionInfoSubmodule is Modifiers, IFunctionInfoSubmodule, IERC165 {
    // Diamond Loupe Functions
    ////////////////////////////////////////////////////////////////////
    /// These functions are expected to be called frequently by tools.
    //
    // struct Submodule {
    //     address submoduleAddress;
    //     bytes4[] functionSelectors;
    // }
    /// @notice Gets all submodules and their selectors.
    /// @return submodules_ Submodule
    function submodules() external view override returns (LibDataTypes.SubmoduleUpgrade[] memory submodules_) {
        LibFunctionRouter.FunctionRouterStorage storage frs = LibFunctionRouter.functionRouterStorage();
        submodules_ = new LibDataTypes.SubmoduleUpgrade[](frs.selectorCount);
        uint8[] memory numSubmoduleSelectors = new uint8[](frs.selectorCount);
        uint256 numSubmodules;
        uint256 selectorIndex;
        // loop through function selectors
        for (uint256 slotIndex; selectorIndex < frs.selectorCount; slotIndex++) {
            bytes32 slot = frs.selectorSlots[slotIndex];
            for (uint256 selectorSlotIndex; selectorSlotIndex < 8; selectorSlotIndex++) {
                selectorIndex++;
                if (selectorIndex > frs.selectorCount) {
                    break;
                }
                bytes4 selector = bytes4(slot << (selectorSlotIndex << 5));
                address submoduleAddress_ = address(bytes20(frs.submodules[selector]));
                bool continueLoop;
                for (uint256 submoduleIndex; submoduleIndex < numSubmodules; submoduleIndex++) {
                    if (submodules_[submoduleIndex].submoduleAddress == submoduleAddress_) {
                        submodules_[submoduleIndex].functionSelectors[numSubmoduleSelectors[submoduleIndex]] = selector;
                        // probably will never have more than 256 functions from one submodule contract
                        require(numSubmoduleSelectors[submoduleIndex] < 255);
                        numSubmoduleSelectors[submoduleIndex]++;
                        continueLoop = true;
                        break;
                    }
                }
                if (continueLoop) {
                    continue;
                }
                submodules_[numSubmodules].submoduleAddress = submoduleAddress_;
                submodules_[numSubmodules].functionSelectors = new bytes4[](frs.selectorCount);
                submodules_[numSubmodules].functionSelectors[0] = selector;
                numSubmoduleSelectors[numSubmodules] = 1;
                numSubmodules++;
            }
        }
        for (uint256 submoduleIndex; submoduleIndex < numSubmodules; submoduleIndex++) {
            uint256 numSelectors = numSubmoduleSelectors[submoduleIndex];
            bytes4[] memory selectors = submodules_[submoduleIndex].functionSelectors;
            // setting the number of selectors
            assembly {
                mstore(selectors, numSelectors)
            }
        }
        // setting the number of submodules
        assembly {
            mstore(submodules_, numSubmodules)
        }
    }

    /// @notice Gets all the function selectors supported by a specific submodule.
    /// @param _submodule The submodule address.
    /// @return submoduleFunctionSelectors_ The selectors associated with a submodule address.
    function submoduleFunctionSelectors(address _submodule)
        external
        view
        override
        returns (bytes4[] memory submoduleFunctionSelectors_)
    {
        LibFunctionRouter.FunctionRouterStorage storage frs = LibFunctionRouter.functionRouterStorage();
        uint256 numSelectors;
        submoduleFunctionSelectors_ = new bytes4[](frs.selectorCount);
        uint256 selectorIndex;
        // loop through function selectors
        for (uint256 slotIndex; selectorIndex < frs.selectorCount; slotIndex++) {
            bytes32 slot = frs.selectorSlots[slotIndex];
            for (uint256 selectorSlotIndex; selectorSlotIndex < 8; selectorSlotIndex++) {
                selectorIndex++;
                if (selectorIndex > frs.selectorCount) {
                    break;
                }
                bytes4 selector = bytes4(slot << (selectorSlotIndex << 5));
                address submodule = address(bytes20(frs.submodules[selector]));
                if (_submodule == submodule) {
                    submoduleFunctionSelectors_[numSelectors] = selector;
                    numSelectors++;
                }
            }
        }
        // Set the number of selectors in the array
        assembly {
            mstore(submoduleFunctionSelectors_, numSelectors)
        }
    }

    /// @notice Get all the submodule addresses used by a diamond.
    /// @return submoduleAddresses_
    function submoduleAddresses() external view override returns (address[] memory submoduleAddresses_) {
        LibFunctionRouter.FunctionRouterStorage storage frs = LibFunctionRouter.functionRouterStorage();
        submoduleAddresses_ = new address[](frs.selectorCount);
        uint256 numSubmodules;
        uint256 selectorIndex;
        // loop through function selectors
        for (uint256 slotIndex; selectorIndex < frs.selectorCount; slotIndex++) {
            bytes32 slot = frs.selectorSlots[slotIndex];
            for (uint256 selectorSlotIndex; selectorSlotIndex < 8; selectorSlotIndex++) {
                selectorIndex++;
                if (selectorIndex > frs.selectorCount) {
                    break;
                }
                bytes4 selector = bytes4(slot << (selectorSlotIndex << 5));
                address submoduleAddress_ = address(bytes20(frs.submodules[selector]));
                bool continueLoop;
                for (uint256 submoduleIndex; submoduleIndex < numSubmodules; submoduleIndex++) {
                    if (submoduleAddress_ == submoduleAddresses_[submoduleIndex]) {
                        continueLoop = true;
                        break;
                    }
                }
                if (continueLoop) {
                    continue;
                }
                submoduleAddresses_[numSubmodules] = submoduleAddress_;
                numSubmodules++;
            }
        }
        // Set the number of submodule addresses in the array
        assembly {
            mstore(submoduleAddresses_, numSubmodules)
        }
    }

    /// @notice Gets the submodule that supports the given selector.
    /// @dev If submodule is not found return address(0).
    /// @param _functionSelector The function selector.
    /// @return submoduleAddress_ The submodule address.
    function submoduleAddress(bytes4 _functionSelector) external view override returns (address submoduleAddress_) {
        LibFunctionRouter.FunctionRouterStorage storage frs = LibFunctionRouter.functionRouterStorage();
        submoduleAddress_ = address(bytes20(frs.submodules[_functionSelector]));
    }

    // This implements ERC-165.
    function supportsInterface(bytes4 _interfaceId) external view override returns (bool) {
        LibFunctionRouter.FunctionRouterStorage storage frs = LibFunctionRouter.functionRouterStorage();
        return frs.supportedInterfaces[_interfaceId];
    }
}
