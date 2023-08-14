//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Libraries
import {LibDataTypes} from "./LibDataTypes.sol";

library LibEvents {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event SubmoduleUpgrade(LibDataTypes.SubmoduleUpgrade[] _submoduleUpgrade, address _init, bytes _calldata);

    event CreateUpgrade(bytes32 id, address indexed who);
    event UpdateUpgradeExpiration(uint256 duration);
    event UpgradeCancelled(bytes32 id, address indexed who);

    event VaultPauseUpdate(bool paused);
    event FeeConfigurationUpdate(address feeRewardForwarder, uint256 feeRatio, address platformTarget, uint256 platformRatio);
    event ExternalFarmingContractUpdate(address indexed nftPositionManager, address indexed masterchef);
    event PoolConfigurationUpdate(address indexed token0, address indexed token1, uint24 fee, string name);

    // Initializable
    event Initialized(uint8 version);

    // TokenizedVault
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    event SwapFeeClaimed(uint256 token0Fee, uint256 token1Fee, uint256 timestamp);
    event Deposit(address indexed user, uint256 token0Amount, uint256 token1Amount);
    event Withdraw(address indexed user, uint256 token0Amount, uint256 token1Amount);
}
