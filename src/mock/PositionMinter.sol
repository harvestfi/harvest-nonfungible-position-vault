//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;
pragma abicoder v2;

// ERC20
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

// ERC721
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

// UniswapV3 core
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

// reentrancy guard
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

// UniswapV3 periphery contracts
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

contract PositionMinter is ERC721HolderUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    address internal constant _NFT_POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address internal constant _UNI_POOL_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    uint256 internal constant _UNDERLYING_UNIT = 1e18;

    uint256 public posId;

    /**
     * @dev Creates the contract and ensures that the slot matches the hash
     */
    constructor() {}

    // creates a new position with the designated range
    function mintPosition(
        address _token0,
        address _token1,
        uint24 _fee,
        int24 _tickLower,
        int24 _tickUpper,
        uint256 _initAmount0,
        uint256 _initAmount1
    ) public {
        IERC20Upgradeable(_token0).safeTransferFrom(msg.sender, address(this), _initAmount0);
        IERC20Upgradeable(_token1).safeTransferFrom(msg.sender, address(this), _initAmount1);
        IERC20Upgradeable(_token0).safeApprove(_NFT_POSITION_MANAGER, 0);
        IERC20Upgradeable(_token0).safeApprove(_NFT_POSITION_MANAGER, _initAmount0);
        IERC20Upgradeable(_token1).safeApprove(_NFT_POSITION_MANAGER, 0);
        IERC20Upgradeable(_token1).safeApprove(_NFT_POSITION_MANAGER, _initAmount1);

        (uint256 _tokenId, uint128 _initialLiquidity,,) = INonfungiblePositionManager(_NFT_POSITION_MANAGER).mint(
            INonfungiblePositionManager.MintParams({
                token0: address(_token0),
                token1: address(_token1),
                fee: _fee,
                tickLower: _tickLower,
                tickUpper: _tickUpper,
                amount0Desired: _initAmount0, // amount0Desired
                amount1Desired: _initAmount1, // amount1Desired
                amount0Min: 0, // amount0Min, first small deposit, can stay 0
                amount1Min: 0, // amount1Min, first small deposit, can stay 0
                recipient: address(this),
                deadline: block.timestamp // will be done on this block.
            })
        );
        posId = _tokenId;
    }

    function approvePosition(address _to) public {
        IERC721Upgradeable(_NFT_POSITION_MANAGER).approve(_to, posId);
    }

    function transferPosition(address _to) public {
        IERC721Upgradeable(_NFT_POSITION_MANAGER).transferFrom(address(this), _to, posId);
    }
}
