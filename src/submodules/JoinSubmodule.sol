//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// External Packages
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// Interfaces
import {IJoinSubmodule} from "../interfaces/submodules/IJoinSubmodule.sol";

// Libraries
import {LibTokenizedVault} from "../libraries/LibTokenizedVault.sol";
import {LibPositionManager} from "../libraries/LibPositionManager.sol";

// Helpers
import {Modifiers} from "../core/Modifiers.sol";

contract JoinSubmodule is Modifiers, IJoinSubmodule {
    function createPosition(
        int24 _tickLower,
        int24 _tickUpper,
        uint256 _amount0Desired,
        uint256 _amount1Desired,
        uint256 _amount0Min,
        uint256 _amount1Min
    )
        external
        override
        onlyGovernanceOrController
        returns (uint256 _tokenId, uint128 _liquidity, uint256 _amount0, uint256 _amount1)
    {
        (_tokenId, _liquidity, _amount0, _amount1) =
            LibPositionManager.mint(_tickLower, _tickUpper, _amount0Desired, _amount1Desired, _amount0Min, _amount1Min);

        // mint the initial shares and send them to the specified recipient, as well as overflow of the tokens
        LibTokenizedVault.mint(msg.sender, uint256(_liquidity));
    }

    function stakePosition() external override onlyGovernanceOrController {
        LibPositionManager.stake();
    }
}
