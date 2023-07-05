//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;
pragma abicoder v2;

import "../interface/oracle/IDexPriceAggregator.sol";
import "./UniVaultSubModuleDepositV1.sol";
import "./interface/IUniStatusViewer.sol";

contract UniVaultSubmoduleDepositV2Managed is UniVaultSubmoduleDepositV1 {
    bytes32 internal constant _LOCAL_STORAGE_SLOT_V2_MANAGED = 0xdd1c3014cf51b49660316473e7024b762c61f45d6f2f14c569c080603d95a229;
    address internal constant DEX_PRICE_AGGREGATOR = 0x813A5C304b8E37fA98F43A33DCCf60fA5cDb8739;

    using SafeMathUpgradeable for uint256;

    struct LocalStorageV2Managed {
        bool depositCapReached;
        uint256 withdrawalTimestamp;
        uint256 capInCapToken;
        address capToken; // token for capInCapToken
        uint256 capTokenIndex; // 0 for capToken = token0 and 1 for capToken = token1
        address otherToken; // the "other" token: if capToken is token0, then otherToken is token1
        uint256 otherTokenIndex; // 0 if otherToken = token0, and 1 if otherToken = token1
    }

    modifier checkTimestamp() {
        require(block.timestamp >= getWithdrawalTimestamp(), "Locked with timestamp");
        _;
    }

    modifier checkDepositCap() {
        require(!depositCapReached(), "Deposit cap reached");
        _;
        if (checkCap()) {
            setDepositCapReached();
        }
    }

    constructor() {
        assert(
            _LOCAL_STORAGE_SLOT_V2_MANAGED
                == bytes32(uint256(keccak256("eip1967.uniVault.depositSubmodule.localStorageV2Managed")) - 1)
        );
    }

    function getLocalStorageV2Managed() internal pure returns (LocalStorageV2Managed storage localStorage) {
        assembly {
            localStorage.slot := _LOCAL_STORAGE_SLOT_V2_MANAGED
        }
    }

    function registerInterface(bytes32 submoduleHash, bool register) public override {
        super.registerInterface(submoduleHash, register);
        address currentSubmoduleAddress = getGlobalStorage().submoduleAddress[submoduleHash];

        uint256 functionNum = 8;
        bytes4[8] memory functionLists = [
            bytes4(keccak256("setWithdrawalTimestamp(uint256)")),
            bytes4(keccak256("resetDepositCapReached(bool)")),
            bytes4(keccak256("checkCap()")),
            bytes4(keccak256("getCap()")),
            bytes4(keccak256("currentValueInCapToken()")),
            bytes4(keccak256("setDepositCap(uint256,address)")),
            bytes4(keccak256("getWithdrawalTimestamp()")),
            bytes4(keccak256("depositCapReached()"))
        ];

        address registeringSubmodule = (register) ? currentSubmoduleAddress : address(0);
        for (uint256 i = 0; i < functionNum; i++) {
            getGlobalStorage().functionToSubmodule[functionLists[i]] = registeringSubmodule;
        }
    }

    function withdraw(uint256, bool, bool, uint256, uint256) public pure override returns (uint256, uint256) {
        revert("please use new interface for withdraw()");
    }

    function withdraw(
        uint256 _numberOfShares,
        bool _token0,
        bool _token1,
        uint256 _sqrtRatioX96,
        uint256 _tolerance,
        uint256 _amount0OutMin,
        uint256 _amount1OutMin,
        uint160 _sqrtPriceLimitX96
    ) public override checkTimestamp returns (uint256, uint256) {
        return super.withdraw(
            _numberOfShares, _token0, _token1, _sqrtRatioX96, _tolerance, _amount0OutMin, _amount1OutMin, _sqrtPriceLimitX96
        );
    }

    function setWithdrawalTimestamp(uint256 _timestamp) public onlyGovernance {
        require(block.timestamp >= getWithdrawalTimestamp() + 24 hours, "Wait for this lock to expire");
        LocalStorageV2Managed storage localStorage = getLocalStorageV2Managed();
        localStorage.withdrawalTimestamp = _timestamp;
    }

    function setDepositCap(uint256 _capInCapToken, address _capToken) public onlyGovernance {
        LocalStorageV2Managed storage localStorage = getLocalStorageV2Managed();
        require(_capToken == address(token0()) || _capToken == address(token1()), "_capToken must be token0 or token1");
        localStorage.capInCapToken = _capInCapToken;
        localStorage.capToken = _capToken;
        localStorage.capTokenIndex = _capToken == address(token0()) ? 0 : 1;
        localStorage.otherToken = _capToken == address(token0()) ? address(token1()) : address(token0());
        localStorage.otherTokenIndex = _capToken == address(token1()) ? 0 : 1;
    }

    function getWithdrawalTimestamp() public view returns (uint256) {
        LocalStorageV2Managed storage localStorage = getLocalStorageV2Managed();
        return localStorage.withdrawalTimestamp;
    }

    function depositCapReached() public view returns (bool) {
        LocalStorageV2Managed storage localStorage = getLocalStorageV2Managed();
        return localStorage.depositCapReached;
    }

    function getCap() public view returns (uint256 cap, address capToken) {
        LocalStorageV2Managed storage localStorage = getLocalStorageV2Managed();
        cap = localStorage.capInCapToken;
        capToken = localStorage.capToken;
    }

    function setDepositCapReached() internal {
        LocalStorageV2Managed storage localStorage = getLocalStorageV2Managed();
        localStorage.depositCapReached = true;
    }

    function resetDepositCapReached(bool value) public onlyGovernance {
        LocalStorageV2Managed storage localStorage = getLocalStorageV2Managed();
        localStorage.depositCapReached = value;
    }

    function currentValueInCapToken() public view returns (uint256) {
        LocalStorageV2Managed storage localStorage = getLocalStorageV2Managed();
        require(localStorage.capInCapToken > 0, "Cap not configured");
        (uint256 current0, uint256 current1) =
            IUniStatusViewer(0x6e87AbD51CCB2290EE1ff65C3749C9420a0cD36E).getAmountsForPosition(getStorage().posId());
        uint256[2] memory currentBalance =
            [current0.add(token0().balanceOf(address(this))), current1.add(token1().balanceOf(address(this)))];

        uint256 outputAmount = 0;
        if (currentBalance[localStorage.otherTokenIndex] > 0) {
            outputAmount = IDexPriceAggregator(DEX_PRICE_AGGREGATOR).assetToAsset(
                localStorage.otherToken, currentBalance[localStorage.otherTokenIndex], localStorage.capToken, 1800
            );
        }
        return currentBalance[localStorage.capTokenIndex].add(outputAmount);
    }

    function checkCap() public view returns (bool) {
        LocalStorageV2Managed storage localStorage = getLocalStorageV2Managed();
        if (localStorage.capInCapToken == 0) {
            return true; // the cap is not enforced if 0
        }
        // return true IF REACHED or EXCEEDED
        return currentValueInCapToken() >= localStorage.capInCapToken;
    }

    function deposit(uint256, uint256, bool, uint256, uint256) public pure override returns (uint256, uint256) {
        revert("please use new interface for deposit()");
    }

    function deposit(
        uint256 _amount0,
        uint256 _amount1,
        bool _zapFunds,
        uint256 _sqrtRatioX96,
        uint256 _tolerance,
        uint256 _zapAmount0OutMin,
        uint256 _zapAmount1OutMin,
        uint160 _zapSqrtPriceLimitX96
    ) public override checkDepositCap returns (uint256, uint256) {
        return super.deposit(
            _amount0, _amount1, _zapFunds, _sqrtRatioX96, _tolerance, _zapAmount0OutMin, _zapAmount1OutMin, _zapSqrtPriceLimitX96
        );
    }

    function migrateToNftFromV2(uint256, uint256, uint256, bool, uint256, uint256)
        public
        pure
        override
        returns (uint256, uint256)
    {
        revert("please use new interface for migrateToNftFromV2");
    }

    function migrateToNftFromV2(
        uint256 _amount,
        uint256 _minAmountForRemoveLiquidity0,
        uint256 _minAmountForRemoveLiquidity1,
        bool _zapFunds,
        uint256 _sqrtRatioX96,
        uint256 _tolerance,
        uint256 _amount0OutMinForZap,
        uint256 _amount1OutMinForZap,
        uint160 _sqrtPriceLimitX96
    ) public override checkDepositCap returns (uint256, uint256) {
        return super.migrateToNftFromV2(
            _amount,
            _minAmountForRemoveLiquidity0,
            _minAmountForRemoveLiquidity1,
            _zapFunds,
            _sqrtRatioX96,
            _tolerance,
            _amount0OutMinForZap,
            _amount1OutMinForZap,
            _sqrtPriceLimitX96
        );
    }
}
