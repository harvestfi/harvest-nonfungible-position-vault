//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Interfaces
import {IVaultInfoSubmodule} from "../interfaces/submodules/IVaultInfoSubmodule.sol";

// Libraries
import {Position} from "../libraries/LibAppStorage.sol";

// Helpers
import {Modifiers} from "../core/Modifiers.sol";

contract VaultInfoSubmodule is Modifiers, IVaultInfoSubmodule {
    function initialized() external view override returns (uint8 _initialized) {
        return s.initialized;
    }

    function initializing() external view override returns (bool _initializing) {
        return s.initializing;
    }

    function vaultPause() external view override returns (bool _vaultPause) {
        return s.vaultPause;
    }

    function governance() external view override returns (address _governance) {
        return s.governance;
    }

    function controller() external view override returns (address _controller) {
        return s.controller;
    }

    function feeRewardForwarder() external view override returns (address _feeRewardForwarder) {
        return s.feeRewardForwarder;
    }

    function platformTarget() external view override returns (address _platformTarget) {
        return s.platformTarget;
    }

    function feeRatio() external view override returns (uint256 _feeRatio) {
        return s.feeRatio;
    }

    function platformRatio() external view override returns (uint256 _platformRatio) {
        return s.platformRatio;
    }

    function upgradeScheduled(bytes32 _id) external view override returns (uint256 _upgradeScheduled) {
        return s.upgradeScheduled[_id];
    }

    function upgradeExpiration() external view override returns (uint256 _upgradeExpiration) {
        return s.upgradeExpiration;
    }

    function token0() external view override returns (address _token0) {
        return s.token0;
    }

    function token1() external view override returns (address _token1) {
        return s.token1;
    }

    function fee() external view override returns (uint24 _fee) {
        return s.fee;
    }

    function positionCount() external view override returns (uint256 _count) {
        return s.positionCount;
    }

    function latestPositionId() external view override returns (uint256 _positionId) {
        return s.positionCount - 1;
    }

    function positions(uint256 _positionId) external view override returns (Position memory _position) {
        return s.positions[_positionId];
    }

    function allPosition() external view override returns (Position[] memory) {
        Position[] memory _positions = new Position[](s.positionCount);
        for (uint256 i; i < s.positionCount; i++) {
            _positions[i] = s.positions[i];
        }
        return _positions;
    }

    function nonFungibleTokenPositionManager() external view override returns (address _nonFungibleTokenPositionManager) {
        return s.nonFungibleTokenPositionManager;
    }

    function masterChef() external view override returns (address _masterChef) {
        return s.masterChef;
    }
    /**
     * @dev Returns the total liquidity stored in the position
     * Dev Note: need to turn on the solc optimizer otherwise the compiler
     * will throw stack too deep on this function
     */
    /*
    function underlyingBalanceWithInvestment() public view returns (uint256) {
        // note that the liquidity is not a token, so there is no local balance added
        (,,,,,,, uint128 liquidity,,,,) = INonfungiblePositionManager(_NFT_POSITION_MANAGER).positions(getStorage().posId());
        return liquidity;
    }
    */

    /**
     * @dev Returns the price per full share, scaled to 1e18
     */
    /*
    function getPricePerFullShare() public view returns (uint256) {
        return totalSupply() == 0 ? _UNDERLYING_UNIT : _UNDERLYING_UNIT.mul(underlyingBalanceWithInvestment()).div(totalSupply());
    }
    *?

    /**
     * @dev Convenience getter for the data contract.
     */
    /*
    function getStorage() public view returns (IUniVaultStorageV1) {
        return IUniVaultStorageV1(getAddress(_DATA_CONTRACT_SLOT));
    }
    */

    /**
     * @dev Convenience getter for the current sqrtPriceX96 of the Uniswap pool.
     */
    /*
    function getSqrtPriceX96() public view returns (uint160) {
        address poolAddr =
            IUniswapV3Factory(_UNI_POOL_FACTORY).getPool(getStorage().token0(), getStorage().token1(), getStorage().fee());
        (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(poolAddr).slot0();
        return sqrtPriceX96;
    }
    */

    /*
    function submoduleAddress(bytes32 submoduleHash) public view returns (address) {
        GlobalStorage storage globalStorage = getGlobalStorage();
        address currentSubmodule = globalStorage.submoduleAddress[submoduleHash];
        return currentSubmodule;
    }
    */
}
