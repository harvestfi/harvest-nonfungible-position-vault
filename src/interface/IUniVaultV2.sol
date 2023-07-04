//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.6;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./IUniVaultStorageV1.sol";
import "../submodules/interface/IUniVaultSubmoduleDepositV2.sol";

interface IUniVaultV2 is IUniVaultSubmoduleDepositV2, IERC20Upgradeable {
    function initialize(uint256 _tokenId, address _dataContract, address _storage, address _zapContract) external;

    function initializeEmpty() external;

    function doHardWork() external;

    function configureVault(
        address submoduleDeposit,
        address _feeRewardForwarder,
        uint256 _feeRatio,
        address _platformTarget,
        uint256 _platformRatio
    ) external;

    function configureFees(address _feeRewardForwarder, uint256 _feeRatio, address _platformTarget, uint256 _platformRatio)
        external;

    function underlyingBalanceWithInvestment() external view returns (uint256);
    function getPricePerFullShare() external view returns (uint256);
    function getStorage() external view returns (IUniVaultStorageV1);
    function token0() external view returns (IERC20Upgradeable);
    function token1() external view returns (IERC20Upgradeable);

    function getSqrtPriceX96() external view returns (uint160);
    function scheduleUpgrade(address impl) external;
    function shouldUpgrade() external view returns (bool, address);
    function finalizeUpgrade() external;
    function increaseUpgradeDelay(uint256 delay) external;
    function submoduleAddress(bytes32 submoduleHash) external view returns (address);
    function setSubmodule(bytes32 submoduleHash, address submoduleAddr) external;

    function setZapContract(address newZap) external;
}
