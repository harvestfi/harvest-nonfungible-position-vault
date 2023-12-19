//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Libraries
import {LibFunctionRouter} from "../../src/libraries/LibFunctionRouter.sol";

contract MockVault {
    constructor(address _governance, address _controller) payable {
        LibFunctionRouter.setGovernance(_governance);
        LibFunctionRouter.setController(_controller);
        // FIXME
        //LibFunctionRouter.setUpgradeExpiration();
    }

    // Find submodule for function that is called and execute the
    // function if a submodule is found and return any value.
    // solhint-disable no-complex-fallback
    fallback() external payable {
        LibFunctionRouter.FunctionRouterStorage storage frs = LibFunctionRouter.functionRouterStorage();

        // get submodule from function selector
        address submodule = address(bytes20(frs.submodules[msg.sig]));
        // require(submodule != address(0), "FunctionRouter: Function does not exist"); - don't need to do this since we check for code below
        LibFunctionRouter.enforceHasContractCode(submodule, "FunctionRouter: Submodule has no code");
        // Execute external function from submodule using delegatecall and return any value.
        assembly {
            // copy function selector and any arguments
            calldatacopy(0, 0, calldatasize())
            // execute function call using the submodule
            let result := delegatecall(gas(), submodule, 0, calldatasize(), 0, 0)
            // get any return value
            returndatacopy(0, 0, returndatasize())
            // return any return value or error back to the caller
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    // solhint-disable no-empty-blocks
    receive() external payable {}
}
