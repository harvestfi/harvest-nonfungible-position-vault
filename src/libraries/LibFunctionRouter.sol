// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/**
 * \
 * Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
 * EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
 *
 * Implementation of a diamond.
 * /*****************************************************************************
 */

// Interfaces
import {ISubmoduleUpgrade} from "../interfaces/libraries/ISubmoduleUpgrade.sol";

// Libraries
import {AppStorage, LibAppStorage} from "./LibAppStorage.sol";
import {LibHelpers} from "./LibHelpers.sol";
import {LibDataTypes} from "./LibDataTypes.sol";
import {LibErrors} from "./LibErrors.sol";
import {LibEvents} from "./LibEvents.sol";
import {LibConstants} from "./LibConstants.sol";

error InitializationFunctionReverted(address _initializationContractAddress, bytes _calldata);

library LibFunctionRouter {
    bytes32 internal constant FUNCTION_ROUTER_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage");

    struct FunctionRouterStorage {
        // maps function selectors to the submodules that execute the functions.
        // and maps the selectors to their position in the selectorSlots array.
        // func selector => address submodule, selector position
        mapping(bytes4 => bytes32) submodules;
        // array of slots of function selectors.
        // each slot holds 8 function selectors.
        mapping(uint256 => bytes32) selectorSlots;
        // The number of function selectors in selectorSlots
        uint16 selectorCount;
        // Used to query if a contract implements an interface.
        // Used to implement ERC-165.
        mapping(bytes4 => bool) supportedInterfaces;
        // owner of the contract
        address contractOwner;
    }

    function functionRouterStorage() internal pure returns (FunctionRouterStorage storage frs) {
        bytes32 position = FUNCTION_ROUTER_STORAGE_POSITION;
        assembly {
            frs.slot := position
        }
    }

    function setContractOwner(address _newOwner) internal {
        FunctionRouterStorage storage frs = functionRouterStorage();
        address previousOwner = frs.contractOwner;
        frs.contractOwner = _newOwner;
        emit LibEvents.OwnershipTransferred(previousOwner, _newOwner);
    }

    function setGovernance(address _governance) internal {
        AppStorage storage s = LibAppStorage.systemStorage();
        s.governance = _governance;
    }

    function setController(address _controller) internal {
        AppStorage storage s = LibAppStorage.systemStorage();
        s.controller = _controller;
    }

    function contractOwner() internal view returns (address contractOwner_) {
        contractOwner_ = functionRouterStorage().contractOwner;
    }

    function enforceIsContractOwner() internal view {
        if (msg.sender != functionRouterStorage().contractOwner) {
            revert LibErrors.NoPermission();
        }
    }

    function setUpgradeExpiration() internal {
        AppStorage storage s = LibAppStorage.systemStorage();
        /// @dev We set the upgrade expiration to 7 days from now (604800 seconds)
        s.upgradeExpiration = 1 weeks;
    }

    // FIXME
    /*
    function addSubmoduleFunctions(
        address _diamondCutFacet,
        address _diamondLoupeFacet,
        address _ownershipFacet,
        address _aclFacet,
        address _governanceFacet
    ) internal {
        
        LibDataTypes.SubmoduleUpgrade[] memory cut = new LibDataTypes.SubmoduleUpgrade[](5);
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = ISubmoduleUpgrade.submoduleUpgrade.selector;
        cut[0] = LibDataTypes.SubmoduleUpgrade({
            facetAddress: _diamondCutFacet,
            action: LibDataTypes.SubmoduleUpgradeAction.Add,
            functionSelectors: functionSelectors
        });
        functionSelectors = new bytes4[](5);
        functionSelectors[0] = IDiamondLoupe.facets.selector;
        functionSelectors[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        functionSelectors[2] = IDiamondLoupe.facetAddresses.selector;
        functionSelectors[3] = IDiamondLoupe.facetAddress.selector;
        functionSelectors[4] = IERC165.supportsInterface.selector;
        cut[1] = LibDataTypes.SubmoduleUpgrade({
            facetAddress: _diamondLoupeFacet,
            action: LibDataTypes.SubmoduleUpgradeAction.Add,
            functionSelectors: functionSelectors
        });
        functionSelectors = new bytes4[](2);
        functionSelectors[0] = IERC173.transferOwnership.selector;
        functionSelectors[1] = IERC173.owner.selector;
        cut[2] = LibDataTypes.SubmoduleUpgrade({
            facetAddress: _ownershipFacet,
            action: LibDataTypes.SubmoduleUpgradeAction.Add,
            functionSelectors: functionSelectors
        });
        functionSelectors = new bytes4[](10);
        functionSelectors[0] = IACLFacet.assignRole.selector;
        functionSelectors[1] = IACLFacet.unassignRole.selector;
        functionSelectors[2] = IACLFacet.isInGroup.selector;
        functionSelectors[3] = IACLFacet.isParentInGroup.selector;
        functionSelectors[4] = IACLFacet.canAssign.selector;
        functionSelectors[5] = IACLFacet.getRoleInContext.selector;
        functionSelectors[6] = IACLFacet.isRoleInGroup.selector;
        functionSelectors[7] = IACLFacet.canGroupAssignRole.selector;
        functionSelectors[8] = IACLFacet.updateRoleAssigner.selector;
        functionSelectors[9] = IACLFacet.updateRoleGroup.selector;
        cut[3] = LibDataTypes.SubmoduleUpgrade({
            facetAddress: _aclFacet,
            action: LibDataTypes.SubmoduleUpgradeAction.Add,
            functionSelectors: functionSelectors
        });
        functionSelectors = new bytes4[](6);
        functionSelectors[0] = IGovernanceFacet.isSystemInitialized.selector;
        functionSelectors[1] = IGovernanceFacet.createUpgrade.selector;
        functionSelectors[2] = IGovernanceFacet.updateUpgradeExpiration.selector;
        functionSelectors[3] = IGovernanceFacet.cancelUpgrade.selector;
        functionSelectors[4] = IGovernanceFacet.getUpgrade.selector;
        functionSelectors[5] = IGovernanceFacet.getUpgradeExpiration.selector;
        cut[4] = LibDataTypes.SubmoduleUpgrade({
            facetAddress: _governanceFacet,
            action: LibDataTypes.SubmoduleUpgradeAction.Add,
            functionSelectors: functionSelectors
        });
        diamondCut(cut, address(0), "");
    }
    */

    bytes32 internal constant CLEAR_ADDRESS_MASK = bytes32(uint256(0xffffffffffffffffffffffff));
    bytes32 internal constant CLEAR_SELECTOR_MASK = bytes32(uint256(0xffffffff << 224));

    // Internal function version of submoduleUpgrade
    // This code is almost the same as the external submoduleUpgrade,
    // except it is using 'Submodule[] memory _submoduleUpgrade' instead of
    // 'Submodule[] calldata _submoduleUpgrade'.
    // The code is duplicated to prevent copying calldata to memory which
    // causes an error for a two dimensional array.
    function submoduleUpgrade(LibDataTypes.SubmoduleUpgrade[] memory _submoduleUpgrade, address _init, bytes memory _calldata)
        internal
    {
        FunctionRouterStorage storage frs = functionRouterStorage();
        uint256 originalSelectorCount = frs.selectorCount;
        uint256 selectorCount = originalSelectorCount;
        bytes32 selectorSlot;
        // Check if last selector slot is not full
        // "selectorCount & 7" is a gas efficient modulo by eight "selectorCount % 8"
        if (selectorCount & 7 > 0) {
            // get last selectorSlot
            // "selectorSlot >> 3" is a gas efficient division by 8 "selectorSlot / 8"
            selectorSlot = frs.selectorSlots[selectorCount >> 3];
        }
        // loop through diamond cut
        for (uint256 submoduleIndex; submoduleIndex < _submoduleUpgrade.length; submoduleIndex++) {
            (selectorCount, selectorSlot) = addReplaceRemoveSubmoduleSelectors(
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
            // "selectorSlot >> 3" is a gas efficient division by 8 "selectorSlot / 8"
            frs.selectorSlots[selectorCount >> 3] = selectorSlot;
        }
        emit LibEvents.SubmoduleUpgrade(_submoduleUpgrade, _init, _calldata);
        initializeFunctionRouter(_init, _calldata);
    }

    function addReplaceRemoveSubmoduleSelectors(
        uint256 _selectorCount,
        bytes32 _selectorSlot,
        address _newSubmoduleAddress,
        LibDataTypes.SubmoduleUpgradeAction _action,
        bytes4[] memory _selectors
    ) internal returns (uint256, bytes32) {
        FunctionRouterStorage storage frs = functionRouterStorage();
        require(_selectors.length > 0, "LibFunctionRouter: No selectors in submodule to cut");
        if (_action == LibDataTypes.SubmoduleUpgradeAction.Add) {
            enforceHasContractCode(_newSubmoduleAddress, "LibFunctionRouter: Add submodule has no code");
            for (uint256 selectorIndex; selectorIndex < _selectors.length; selectorIndex++) {
                bytes4 selector = _selectors[selectorIndex];
                bytes32 oldSubmodule = frs.submodules[selector];
                require(address(bytes20(oldSubmodule)) == address(0), "LibFunctionRouter: Can't add function that already exists");
                // add submodule for selector
                frs.submodules[selector] = bytes20(_newSubmoduleAddress) | bytes32(_selectorCount);
                // "_selectorCount & 7" is a gas efficient modulo by eight "_selectorCount % 8"
                uint256 selectorInSlotPosition = (_selectorCount & 7) << 5;
                // clear selector position in slot and add selector
                _selectorSlot = (_selectorSlot & ~(CLEAR_SELECTOR_MASK >> selectorInSlotPosition))
                    | (bytes32(selector) >> selectorInSlotPosition);
                // if slot is full then write it to storage
                if (selectorInSlotPosition == 224) {
                    // "_selectorSlot >> 3" is a gas efficient division by 8 "_selectorSlot / 8"
                    frs.selectorSlots[_selectorCount >> 3] = _selectorSlot;
                    _selectorSlot = 0;
                }
                _selectorCount++;
            }
        } else if (_action == LibDataTypes.SubmoduleUpgradeAction.Replace) {
            enforceHasContractCode(_newSubmoduleAddress, "LibFunctionRouter: Replace submodule has no code");
            for (uint256 selectorIndex; selectorIndex < _selectors.length; selectorIndex++) {
                bytes4 selector = _selectors[selectorIndex];
                bytes32 oldSubmodule = frs.submodules[selector];
                address oldSubmoduleAddress = address(bytes20(oldSubmodule));
                // only useful if immutable functions exist
                require(oldSubmoduleAddress != address(this), "LibFunctionRouter: Can't replace immutable function");
                require(
                    oldSubmoduleAddress != _newSubmoduleAddress, "LibFunctionRouter: Can't replace function with same function"
                );
                require(oldSubmoduleAddress != address(0), "LibFunctionRouter: Can't replace function that doesn't exist");
                // replace old submodule address
                frs.submodules[selector] = (oldSubmodule & CLEAR_ADDRESS_MASK) | bytes20(_newSubmoduleAddress);
            }
        } else if (_action == LibDataTypes.SubmoduleUpgradeAction.Remove) {
            require(_newSubmoduleAddress == address(0), "LibFunctionRouter: Remove submodule address must be address(0)");
            // "_selectorCount >> 3" is a gas efficient division by 8 "_selectorCount / 8"
            uint256 selectorSlotCount = _selectorCount >> 3;
            // "_selectorCount & 7" is a gas efficient modulo by eight "_selectorCount % 8"
            uint256 selectorInSlotIndex = _selectorCount & 7;
            for (uint256 selectorIndex; selectorIndex < _selectors.length; selectorIndex++) {
                if (_selectorSlot == 0) {
                    // get last selectorSlot
                    selectorSlotCount--;
                    _selectorSlot = frs.selectorSlots[selectorSlotCount];
                    selectorInSlotIndex = 7;
                } else {
                    selectorInSlotIndex--;
                }
                bytes4 lastSelector;
                uint256 oldSelectorsSlotCount;
                uint256 oldSelectorInSlotPosition;
                // adding a block here prevents stack too deep error
                {
                    bytes4 selector = _selectors[selectorIndex];
                    bytes32 oldSubmodule = frs.submodules[selector];
                    require(
                        address(bytes20(oldSubmodule)) != address(0),
                        "LibFunctionRouter: Can't remove function that doesn't exist"
                    );
                    // only useful if immutable functions exist
                    require(address(bytes20(oldSubmodule)) != address(this), "LibFunctionRouter: Can't remove immutable function");
                    // replace selector with last selector in frs.submodules
                    // gets the last selector
                    lastSelector = bytes4(_selectorSlot << (selectorInSlotIndex << 5));
                    if (lastSelector != selector) {
                        // update last selector slot position info
                        frs.submodules[lastSelector] = (oldSubmodule & CLEAR_ADDRESS_MASK) | bytes20(frs.submodules[lastSelector]);
                    }
                    delete frs.submodules[selector];
                    uint256 oldSelectorCount = uint16(uint256(oldSubmodule));
                    // "oldSelectorCount >> 3" is a gas efficient division by 8 "oldSelectorCount / 8"
                    oldSelectorsSlotCount = oldSelectorCount >> 3;
                    // "oldSelectorCount & 7" is a gas efficient modulo by eight "oldSelectorCount % 8"
                    oldSelectorInSlotPosition = (oldSelectorCount & 7) << 5;
                }
                if (oldSelectorsSlotCount != selectorSlotCount) {
                    bytes32 oldSelectorSlot = frs.selectorSlots[oldSelectorsSlotCount];
                    // clears the selector we are deleting and puts the last selector in its place.
                    oldSelectorSlot = (oldSelectorSlot & ~(CLEAR_SELECTOR_MASK >> oldSelectorInSlotPosition))
                        | (bytes32(lastSelector) >> oldSelectorInSlotPosition);
                    // update storage with the modified slot
                    frs.selectorSlots[oldSelectorsSlotCount] = oldSelectorSlot;
                } else {
                    // clears the selector we are deleting and puts the last selector in its place.
                    _selectorSlot = (_selectorSlot & ~(CLEAR_SELECTOR_MASK >> oldSelectorInSlotPosition))
                        | (bytes32(lastSelector) >> oldSelectorInSlotPosition);
                }
                if (selectorInSlotIndex == 0) {
                    delete frs.selectorSlots[selectorSlotCount];
                    _selectorSlot = 0;
                }
            }
            _selectorCount = selectorSlotCount * 8 + selectorInSlotIndex;
        } else {
            revert("LibFunctionRouter: Incorrect SubmoduleUpgradeAction");
        }
        return (_selectorCount, _selectorSlot);
    }

    function initializeFunctionRouter(address _init, bytes memory _calldata) internal {
        if (_init == address(0)) {
            require(_calldata.length == 0, "LibFunctionRouter: _init is address(0) but_calldata is not empty");
        } else {
            require(_calldata.length > 0, "LibFunctionRouter: _calldata is empty but _init is not address(0)");
            if (_init != address(this)) {
                enforceHasContractCode(_init, "LibFunctionRouter: _init address has no code");
            }
            (bool success, bytes memory error) = _init.delegatecall(_calldata);
            if (!success) {
                if (error.length > 0) {
                    // bubble up the error
                    revert(string(error));
                } else {
                    revert InitializationFunctionReverted(_init, _calldata);
                }
            }
        }
    }

    function enforceHasContractCode(address _contract, string memory _errorMessage) internal view {
        uint256 contractSize;
        assembly {
            contractSize := extcodesize(_contract)
        }
        require(contractSize > 0, _errorMessage);
    }
}
