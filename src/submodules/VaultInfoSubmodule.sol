//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Interfaces
import {IVaultInfoSubmodule} from "../interfaces/submodules/IVaultInfoSubmodule.sol";

// Helpers
import {Modifiers} from "../core/Modifiers.sol";

contract VaultInfoSubmodule is Modifiers, IVaultInfoSubmodule {
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
 * @dev Convenience getter for token0.
 */
/*
    function token0() public view returns (IERC20Upgradeable) {
        return IERC20Upgradeable(getStorage().token0());
    }

    /**
     * @dev Convenience getter for token1.
     */
/*
    function token1() public view returns (IERC20Upgradeable) {
        return IERC20Upgradeable(getStorage().token1());
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

/*
    function vaultPaused() public view returns (bool) {
        return getBoolean(_VAULT_PAUSE_SLOT);
    }
    */
}
