// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// External Packages
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

interface ITokenizedVaultSubmodule is IERC20Upgradeable, IERC20MetadataUpgradeable {}
