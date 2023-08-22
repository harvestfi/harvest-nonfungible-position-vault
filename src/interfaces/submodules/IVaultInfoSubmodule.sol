// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Interfaces
import {Position} from "../../libraries/LibAppStorage.sol";

interface IVaultInfoSubmodule {
    // System
    function initialized() external view returns (uint8 _initialized);
    function initializing() external view returns (bool _initializing);
    function vaultPause() external view returns (bool _vaultPause);
    function governance() external view returns (address _governance);
    function controller() external view returns (address _controller);
    // Fee Reward Shares
    function feeRewardForwarder() external view returns (address _feeRewardForwarder);
    function platformTarget() external view returns (address _platformTarget);
    function feeRatio() external view returns (uint256 _feeRatio);
    function platformRatio() external view returns (uint256 _platformRatio);
    /// Simple two phase upgrade scheme
    function upgradeScheduled(bytes32 _id) external view returns (uint256 _upgradeScheduled);
    function upgradeExpiration() external view returns (uint256 _upgradeExpiration);
    // Vault
    function token0() external view returns (address _token0);
    function token1() external view returns (address _token1);
    function fee() external view returns (uint24 _fee);
    // Position
    function positionCount() external view returns (uint256 _count);
    function latestPositionId() external view returns (uint256 _positionId);
    function positions(uint256 _tokenId) external view returns (Position memory _position);
    function allPosition() external view returns (Position[] memory _positions);
    // External
    function nonFungibleTokenPositionManager() external view returns (address _nonFungibleTokenPositionManager);
    function masterChef() external view returns (address _masterChef);
}
