//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Interfaces
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Libraries
import {Position, AppStorage, LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibTokenizedVault} from "../libraries/LibTokenizedVault.sol";
import {LibPositionManager} from "../libraries/LibPositionManager.sol";
import {LibErrors} from "../libraries/LibErrors.sol";

// Helpers
import {Modifiers} from "./Modifiers.sol";

contract InitVault is Modifiers {
    function initialize(address _nftPositionManager, address _masterchef, uint256 _tokenId, string calldata _vaultNamePrefix)
        public
        initializer
    {
        Position storage position = s.positions[s.positionCount++];
        s.nonFungibleTokenPositionManager = _nftPositionManager;
        s.masterChef = _masterchef;

        // fetch info from position manager
        (address _token0, address _token1, uint24 _fee, int24 _tickLower, int24 _tickUpper, uint256 _initialLiquidity) =
            LibPositionManager.positionInfo(_tokenId);

        // initialize the state variables
        s.token0 = _token0;
        s.token1 = _token1;
        s.fee = _fee;
        position.tickLower = _tickLower;
        position.tickUpper = _tickUpper;
        position.liquidity = _initialLiquidity;
        position.tokenId = _tokenId;

        // set the decimals and underlying unit
        uint8 decimals0 = IERC20Metadata(_token0).decimals();
        uint8 decimals1 = IERC20Metadata(_token1).decimals();
        if (decimals0 != decimals1) {
            revert LibErrors.DecimalsMismatch(_token0, decimals0, _token1, decimals1);
        }
        s.underlyingDecimals = uint8(decimals0);
        s.underlyingUnit = 10 ** decimals0;

        // stake position
        LibPositionManager.stake(s.positionCount - 1);

        // initializing the vault token. By default, it has 18 decimals.
        LibTokenizedVault.__ERC20_init_unchained(
            string(abi.encodePacked(_vaultNamePrefix, IERC20Metadata(_token0).symbol(), "_", IERC20Metadata(_token1).symbol())),
            string(abi.encodePacked(_vaultNamePrefix, IERC20Metadata(_token0).symbol(), "_", IERC20Metadata(_token1).symbol()))
        );

        // mint the initial shares and send them to the specified recipient, as well as overflow of the tokens
        LibTokenizedVault.mint(msg.sender, uint256(_initialLiquidity));
    }
}
