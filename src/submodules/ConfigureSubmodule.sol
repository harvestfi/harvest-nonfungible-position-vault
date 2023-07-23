//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// External Packages
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

// Libraries
import {AppStorage, LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibPostionManager} from "../libraries/LibPostionManager.sol";
import {LibEvents} from "../libraries/LibEvents.sol";

// Helpers
import {Modifiers} from "../core/Modifiers.sol";

contract ConfigureSubmodule is Modifiers, ERC20Upgradeable {
    AppStorage internal s;

    //FIXME: This should be moved to InitVault.sol
    function initialize(uint256 _tokenId) public initialized {
        // stake position
        LibPostionManager.stake(_tokenId);

        // fetch info from position manager
        (address _token0, address _token1, uint24 _fee, int24 _tickLower, int24 _tickUpper, uint256 _initialLiquidity) =
            LibPostionManager.positionInfo(_tokenId);

        // initialize the state variables
        s.token0 = _token0;
        s.token1 = _token1;
        s.fee = _fee;
        s.tickLower = _tickLower;
        s.tickUpper = _tickUpper;
        s.initialLiquidity = _initialLiquidity;
        s.tokenId = _tokenId;

        // initializing the vault token. By default, it has 18 decimals.
        __ERC20_init_unchained(
            string(abi.encodePacked("fUniV3_", ERC20Upgradeable(_token0).symbol(), "_", ERC20Upgradeable(_token1).symbol())),
            string(abi.encodePacked("fUniV3_", ERC20Upgradeable(_token0).symbol(), "_", ERC20Upgradeable(_token1).symbol()))
        );

        // mint the initial shares and send them to the specified recipient, as well as overflow of the tokens
        _mint(msg.sender, uint256(_initialLiquidity));
    }

    function configureFees(address _feeRewardForwarder, uint256 _feeRatio, address _platformTarget, uint256 _platformRatio)
        external
        onlyGovernance
    {
        s.feeRewardForwarder = _feeRewardForwarder;
        s.platformTarget = _platformTarget;
        s.feeRatio = _feeRatio;
        s.platformRatio = _platformRatio;

        emit LibEvents.FeeConfigurationUpdate(_feeRewardForwarder, _feeRatio, _platformTarget, _platformRatio);
    }

    function setVaultPause(bool _pause) public onlyGovernanceOrController {
        s.vaultPause = _pause;

        emit LibEvents.VaultPauseUpdate(_pause);
    }
}
