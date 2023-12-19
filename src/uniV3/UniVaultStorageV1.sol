//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

contract UniVaultStorageV1 {
    uint256 public posId;
    address public token0;
    address public token1;
    address public zapContract;
    address public vault;
    address public feeRewardForwarder;
    uint256 public profitShareRatio;
    address public platformTarget;
    uint256 public platformRatio;

    int24 public tickUpper;
    int24 public tickLower;
    uint24 public fee;
    address public nextImplementation;
    uint256 public nextImplementationTimestamp;
    uint256 public nextImplementationDelay;

    modifier onlyVault() {
        require(msg.sender == vault, "Only vault");
        _;
    }

    constructor(address _vault) {
        vault = _vault;
    }

    function initializeByVault(
        address _token0,
        address _token1,
        uint24 _fee,
        int24 _tickLower,
        int24 _tickUpper,
        address _zapContract
    ) public onlyVault {
        token0 = _token0;
        token1 = _token1;
        fee = _fee;
        tickLower = _tickLower;
        tickUpper = _tickUpper;
        zapContract = _zapContract;
    }

    function setZapContract(address _zap) public onlyVault {
        zapContract = _zap;
    }

    function setToken0(address _token) public onlyVault {
        token0 = _token;
    }

    function setToken1(address _token) public onlyVault {
        token1 = _token;
    }

    function setFee(uint24 _fee) public onlyVault {
        fee = _fee;
    }

    function setTickUpper(int24 _tick) public onlyVault {
        tickUpper = _tick;
    }

    function setTickLower(int24 _tick) public onlyVault {
        tickLower = _tick;
    }

    function setPosId(uint256 _posId) public onlyVault {
        posId = _posId;
    }

    function setVault(address _vault) public onlyVault {
        vault = _vault;
    }

    function setFeeRewardForwarder(address _feeRewardForwarder) public onlyVault {
        feeRewardForwarder = _feeRewardForwarder;
    }

    function configureFees(address _feeRewardForwarder, uint256 _feeRatio, address _platformTarget, uint256 _platformRatio)
        public
        onlyVault
    {
        feeRewardForwarder = _feeRewardForwarder;
        profitShareRatio = _feeRatio;
        platformTarget = _platformTarget;
        platformRatio = _platformRatio;
    }

    function setNextImplementation(address _impl) public onlyVault {
        nextImplementation = _impl;
    }

    function setNextImplementationTimestamp(uint256 _timestamp) public onlyVault {
        nextImplementationTimestamp = _timestamp;
    }

    function setNextImplementationDelay(uint256 _delay) public onlyVault {
        nextImplementationDelay = _delay;
    }
}
