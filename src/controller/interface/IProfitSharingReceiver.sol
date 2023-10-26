// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IProfitSharingReceiver {
    function governance() external view returns (address);

    function withdrawTokens(address[] calldata _tokens) external;
}
