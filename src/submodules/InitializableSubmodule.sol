//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Interfaces
import {IInitializableSubmodule} from "../interfaces/submodules/IInitializableSubmodule.sol";

// Libraries
import {LibEvents} from "../libraries/LibEvents.sol";

// Helpers
import {Modifiers} from "../core/Modifiers.sol";

contract InitializableSubmodule is Modifiers, IInitializableSubmodule {
    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function disableInitializers() external {
        require(!s.initializing, "Initializable: contract is initializing");
        if (s.initialized != type(uint8).max) {
            s.initialized = type(uint8).max;
            emit LibEvents.Initialized(type(uint8).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function getInitializedVersion() external view returns (uint8) {
        return s.initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function isInitializing() external view returns (bool) {
        return s.initializing;
    }
}
