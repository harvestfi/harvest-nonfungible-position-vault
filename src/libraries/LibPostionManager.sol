//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// External Packages
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

// Libraries
import {AppStorage, LibAppStorage} from "./LibAppStorage.sol";

library LibPostionManager {
    function mint() internal {}

    function stake(uint256 _tokenId) internal {
        AppStorage storage s = LibAppStorage.systemStorage();
        IERC721Upgradeable(s.nonFungibleTokenPositionManager).transferFrom(msg.sender, s.masterChef, _tokenId);
    }

    function withdraw() internal {}
    function increaseLiquidity() internal {}
    function decreaseLiquidity() internal {}
    function collect() internal {}
    function harvest() internal {}

    function positionInfo(uint256 _tokenId) internal view returns (address, address, uint24, int24, int24, uint256) {
        AppStorage storage s = LibAppStorage.systemStorage();
        (,, address _token0, address _token1, uint24 _fee, int24 _tickLower, int24 _tickUpper, uint256 _initialLiquidity,,,,) =
            INonfungiblePositionManager(s.nonFungibleTokenPositionManager).positions(_tokenId);
        return (_token0, _token1, _fee, _tickLower, _tickUpper, _initialLiquidity);
    }

    function setNonFungiPositionManager(address _address) internal {
        AppStorage storage s = LibAppStorage.systemStorage();
        s.nonFungibleTokenPositionManager = _address;
    }
}
