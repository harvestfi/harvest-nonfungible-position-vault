// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/**
 * @dev Settings keys.
 */
library LibConstants {
    // FIXME
    uint256 internal constant _UNDERLYING_UNIT = 1e18;

    address internal constant _NFT_POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address internal constant _UNI_POOL_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    address internal constant _V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address internal constant _V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address internal constant _UNI_STAKER = 0x1f98407aaB862CdDeF78Ed252D6f557aA5b0f00d;
}
