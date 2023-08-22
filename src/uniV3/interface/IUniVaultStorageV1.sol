//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

interface IUniVaultStorageV1 {
    function initializeByVault(
        address _token0,
        address _token1,
        uint24 _fee,
        int24 _tickLower,
        int24 _tickUpper,
        address _zapContract
    ) external;

    function posId() external view returns (uint256);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function zapContract() external view returns (address);
    function vault() external view returns (address);
    function feeRewardForwarder() external view returns (address);
    function profitShareRatio() external view returns (uint256);
    function platformTarget() external view returns (address);
    function platformRatio() external view returns (uint256);

    function tickUpper() external view returns (int24);
    function tickLower() external view returns (int24);
    function fee() external view returns (uint24);

    function nextImplementation() external view returns (address);
    function nextImplementationTimestamp() external view returns (uint256);
    function nextImplementationDelay() external view returns (uint256);

    function setZapContract(address _zap) external;
    function setToken0(address _token) external;
    function setToken1(address _token) external;
    function setFee(uint24 _fee) external;
    function setTickUpper(int24 _tick) external;
    function setTickLower(int24 _tick) external;

    function setPosId(uint256 _posId) external;
    function _setVault(address _vault) external;
    function setFeeRewardForwarder(address _feeRewardForwarder) external;

    function configureFees(address _feeRewardForwarder, uint256 _feeRatio, address _platformTarget, uint256 _platformRatio)
        external;

    function setNextImplementation(address _impl) external;
    function setNextImplementationTimestamp(uint256 _timestamp) external;
    function setNextImplementationDelay(uint256 _delay) external;
}
