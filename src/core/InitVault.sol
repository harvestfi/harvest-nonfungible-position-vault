//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// External Packages
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// Libraries
import {AppStorage, LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibPostionManager} from "../libraries/LibPostionManager.sol";

contract InitVault is Initializable, ERC20Upgradeable {
    function initialize(address _nftPositionManager, address _masterchef, uint256 _tokenId, string calldata _vaultName)
        public
        initializer
    {
        AppStorage storage s = LibAppStorage.systemStorage();
        s.systemInitialized = true;
        s.tokenId = _tokenId;
        s.nonFungibleTokenPositionManager = _nftPositionManager;
        s.masterChef = _masterchef;

        // stake position
        LibPostionManager.stake();

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

        // initializing the vault token. By default, it has 18 decimals.
        __ERC20_init_unchained(
            string(abi.encodePacked(_vaultName, ERC20Upgradeable(_token0).symbol(), "_", ERC20Upgradeable(_token1).symbol())),
            string(abi.encodePacked(_vaultName, ERC20Upgradeable(_token0).symbol(), "_", ERC20Upgradeable(_token1).symbol()))
        );

        // mint the initial shares and send them to the specified recipient, as well as overflow of the tokens
        _mint(msg.sender, uint256(_initialLiquidity));
    }
}
