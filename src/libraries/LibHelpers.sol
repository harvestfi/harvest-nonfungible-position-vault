// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Libraries
import {LibDataTypes} from "../libraries/LibDataTypes.sol";

/// @notice Pure functions
library LibHelpers {
    // Conversion Utilities

    /**
     * @dev Converts a string to a bytes32 representation.
     *      No length check for the input string is performed in this function, as it is only
     *      used with predefined string constants from LibConstants related to role names,
     *      role group names, and special platform identifiers.
     *      These critical string constants are verified to be 32 bytes or less off-chain
     *      before being used, and can only be set by platform admins.
     * @param strIn The input string to be converted
     * @return The bytes32 representation of the input string
     */
    function _stringToBytes32(string memory strIn) internal pure returns (bytes32) {
        return _bytesToBytes32(bytes(strIn));
    }

    function _bytesToBytes32(bytes memory source) internal pure returns (bytes32 result) {
        if (source.length == 0) {
            return 0x0;
        }
        assembly {
            result := mload(add(source, 32))
        }
    }

    function _bytes32ToBytes(bytes32 input) internal pure returns (bytes memory) {
        bytes memory b = new bytes(32);
        assembly {
            mstore(add(b, 32), input)
        }
        return b;
    }

    function _submoduleUpgradeStructCompare(
        LibDataTypes.SubmoduleUpgrade memory _submoduleUpgradeA,
        LibDataTypes.SubmoduleUpgrade memory _submoduleUpgradeB
    ) internal pure returns (bool) {
        return (_submoduleUpgradeA.submoduleAddress == _submoduleUpgradeB.submoduleAddress)
            && (_submoduleUpgradeA.action == _submoduleUpgradeB.action)
            && _functionSelectorListCompare(_submoduleUpgradeA.functionSelectors, _submoduleUpgradeB.functionSelectors);
    }

    function _functionSelectorListCompare(bytes4[] memory _functionSelectorsA, bytes4[] memory _functionSelectorsB)
        internal
        pure
        returns (bool)
    {
        if (_functionSelectorsA.length != _functionSelectorsB.length) {
            return false;
        }
        for (uint256 i; i < _functionSelectorsA.length;) {
            if (_functionSelectorsA[i] != _functionSelectorsB[i]) {
                return false;
            }
            unchecked {
                i++;
            }
        }
        return true;
    }
}
