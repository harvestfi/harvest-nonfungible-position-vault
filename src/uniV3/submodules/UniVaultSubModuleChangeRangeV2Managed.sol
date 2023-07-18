//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;
pragma abicoder v2;

import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

import "./UniVaultSubModuleChangeRangeV1.sol";
import "../interface/uniswapV2/IUniswapV2Router02.sol";

contract UniVaultSubmoduleChangeRangeV2Managed is UniVaultSubmoduleChangeRangeV1 {
    using SafeMathUpgradeable for uint256;

    uint256 internal constant INDEX_NOT_FOUND = type(uint256).max;
    bytes32 internal constant _LOCAL_STORAGE_SLOT_V2_MANAGED = 0x06bc87915c202efffe30f9e888a1400ac812e3fce7b75d676c422e2b1ca89608;

    event RangeChanged(uint256 oldPosId, uint256 newPosId, uint256 original0, uint256 original1, uint256 final0, uint256 final1);

    struct LocalStorageV2Managed {
        uint256[] positionIds;
        mapping(address => bool) rangeManagers;
        mapping(address => bool) rangeSwitchers;
        uint256 rangeChangedTime;
        uint256 rangeChangeDelayTime;
        uint256 maxLossRatio;
        address[] sellPath;
    }

    modifier onlyRangeSwitcher() {
        LocalStorageV2Managed storage localStorage = getLocalStorageV2Managed();
        require(localStorage.rangeSwitchers[msg.sender] || msg.sender == governance(), "only range switcher");
        _;
    }

    modifier onlyRangeManager() {
        LocalStorageV2Managed storage localStorage = getLocalStorageV2Managed();
        require(localStorage.rangeManagers[msg.sender] || msg.sender == governance(), "only range manager");
        _;
    }

    constructor() {
        assert(
            _LOCAL_STORAGE_SLOT_V2_MANAGED
                == bytes32(uint256(keccak256("eip1967.uniVault.changeRangeSubmodule.localStorageV2Managed")) - 1)
        );
    }

    function getLocalStorageV2Managed() internal pure returns (LocalStorageV2Managed storage localStorage) {
        assembly {
            localStorage.slot := _LOCAL_STORAGE_SLOT_V2_MANAGED
        }
    }

    // returns position ids of the available ranges
    function getRangePositionIds() public view returns (uint256[] memory) {
        LocalStorageV2Managed storage localStorage = getLocalStorageV2Managed();
        return localStorage.positionIds;
    }

    function getCurrentRangePositionId() public view returns (uint256) {
        return getStorage().posId();
    }

    function setSellPath(address[] memory newSellPath) public onlyGovernance {
        LocalStorageV2Managed storage localStorage = getLocalStorageV2Managed();
        localStorage.sellPath = newSellPath;
    }

    function isManaged() public pure returns (bool) {
        return true;
    }

    function registerInterface(bytes32 submoduleHash, bool register) public override {
        GlobalStorage storage globalStorage = getGlobalStorage();
        address currentSubmoduleAddress = globalStorage.submoduleAddress[submoduleHash];

        uint256 functionNum = 16;
        bytes4[16] memory functionLists = [
            bytes4(keccak256("isManaged()")),
            bytes4(keccak256("getCurrentRangePositionId()")),
            bytes4(keccak256("changeRangeGuarded(uint256,uint256,uint256)")),
            bytes4(keccak256("isInRange(uint256)")),
            bytes4(keccak256("getRangeChangedTime()")),
            bytes4(keccak256("addPositionIds(uint256[])")),
            bytes4(keccak256("removePositionId(uint256)")),
            bytes4(keccak256("getAmountsForPosition(uint256)")),
            bytes4(keccak256("isCurrentPositionInRange()")),
            bytes4(keccak256("getPositionIds()")),
            bytes4(keccak256("getPositionIdsThatAreInRange()")),
            bytes4(keccak256("changeRangeUnguarded(uint256,uint256,uint256)")),
            bytes4(keccak256("setMaxLossRatio(uint256)")),
            bytes4(keccak256("setSellPath(address[])")),
            bytes4(keccak256("getRangePositionIds()")),
            bytes4(keccak256("findIndexOfPositionId(uint256"))
        ];

        address registeringSubmodule = (register) ? currentSubmoduleAddress : address(0);
        for (uint256 i = 0; i < functionNum; i++) {
            globalStorage.functionToSubmodule[functionLists[i]] = registeringSubmodule;
        }

        // custom initialization for inner storage
        LocalStorageV2Managed storage localStorage = getLocalStorageV2Managed();
        localStorage.rangeChangedTime = block.timestamp;
        localStorage.maxLossRatio = 50; // 0.5%
    }

    function getSqrtPriceX96(address _token0, address _token1, uint24 _fee) public view returns (uint160) {
        address poolAddr = IUniswapV3Factory(_UNI_POOL_FACTORY).getPool(_token0, _token1, _fee);
        (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(poolAddr).slot0();
        return sqrtPriceX96;
    }

    function getAmountsForPosition(uint256 posId) public view returns (uint256 amount0, uint256 amount1) {
        (,, address _token0, address _token1, uint24 _fee, int24 _tickLower, int24 _tickUpper, uint128 _liquidity,,,,) =
            INonfungiblePositionManager(_NFT_POSITION_MANAGER).positions(posId);
        uint160 sqrtRatioX96 = getSqrtPriceX96(_token0, _token1, _fee);
        uint160 sqrtRatioXA96 = TickMath.getSqrtRatioAtTick(_tickLower);
        uint160 sqrtRatioXB96 = TickMath.getSqrtRatioAtTick(_tickUpper);
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(sqrtRatioX96, sqrtRatioXA96, sqrtRatioXB96, _liquidity);
    }

    function isInRange(uint256 positionId) public view returns (bool) {
        (,, address _token0, address _token1, uint24 _fee, int24 _tickLower, int24 _tickUpper,,,,,) =
            INonfungiblePositionManager(_NFT_POSITION_MANAGER).positions(positionId);
        uint160 sqrtRatioX96 = getSqrtPriceX96(_token0, _token1, _fee);
        uint160 sqrtRatioXA96 = TickMath.getSqrtRatioAtTick(_tickLower);
        uint160 sqrtRatioXB96 = TickMath.getSqrtRatioAtTick(_tickUpper);
        return (sqrtRatioX96 >= sqrtRatioXA96) && (sqrtRatioX96 <= sqrtRatioXB96);
    }

    // returns timestamp since last position change
    function getRangeChangedTime() public view returns (uint256) {
        LocalStorageV2Managed storage localStorage = getLocalStorageV2Managed();
        return localStorage.rangeChangedTime;
    }

    function findIndexOfPositionId(uint256 positionId) public view returns (uint256) {
        LocalStorageV2Managed storage localStorage = getLocalStorageV2Managed();
        for (uint256 i = 0; i < localStorage.positionIds.length; i++) {
            if (localStorage.positionIds[i] == positionId) {
                return i;
            }
        }
        return INDEX_NOT_FOUND;
    }

    function setMaxLossRatio(uint256 _newLossRatio) public onlyGovernance {
        LocalStorageV2Managed storage localStorage = getLocalStorageV2Managed();
        require(_newLossRatio <= 10000, "max ratio is 10000");
        localStorage.maxLossRatio = _newLossRatio;
    }

    // adds a new range. Checks that the assets are matching
    function addPositionIds(uint256[] calldata newPositionIds) external onlyRangeManager {
        LocalStorageV2Managed storage localStorage = getLocalStorageV2Managed();
        for (uint256 i = 0; i < newPositionIds.length; i++) {
            require(IERC721Upgradeable(_NFT_POSITION_MANAGER).ownerOf(newPositionIds[i]) == address(this), "pos owner mismatch");
            require(findIndexOfPositionId(newPositionIds[i]) == INDEX_NOT_FOUND, "position aleady exists");
            localStorage.positionIds.push(newPositionIds[i]);
        }
    }

    // removes a range position id. Cannot remove the current range
    function removePositionId(uint256 existingPositionId) external onlyRangeManager {
        require(getCurrentRangePositionId() != existingPositionId, "Cannot remove current position token id");
        LocalStorageV2Managed storage localStorage = getLocalStorageV2Managed();
        require(localStorage.positionIds.length > 1, "Cannot remove the last position token");
        uint256 existingPositionIndex = findIndexOfPositionId(existingPositionId);
        require(existingPositionIndex != INDEX_NOT_FOUND, "Position id not found");
        localStorage.positionIds[existingPositionIndex] = localStorage.positionIds[localStorage.positionIds.length - 1];
        localStorage.positionIds.pop();
    }

    // returns true if the current position is in range
    function isCurrentPositionInRange() public view returns (bool) {
        return isInRange(getCurrentRangePositionId());
    }

    // returns all supported positions
    function getPositionIds() public view returns (uint256[] memory result) {
        LocalStorageV2Managed storage localStorage = getLocalStorageV2Managed();
        return localStorage.positionIds;
    }

    // iterates over all the positions and returns the positions that are in range at the moment
    function getPositionIdsThatAreInRange() public view returns (uint256[] memory) {
        LocalStorageV2Managed storage localStorage = getLocalStorageV2Managed();
        uint256 relevantNumber = 0;
        for (uint256 i = 0; i < localStorage.positionIds.length; i++) {
            if (isInRange(localStorage.positionIds[i])) {
                relevantNumber++;
            }
        }
        uint256 index = 0;
        uint256[] memory result = new uint256[](relevantNumber);
        for (uint256 i = 0; i < localStorage.positionIds.length; i++) {
            if (isInRange(localStorage.positionIds[i])) {
                result[index++] = localStorage.positionIds[i];
            }
        }
        return result;
    }

    function changeRangeGuarded(uint256 newPosId, uint256 minFinalAmount0, uint256 minFinalAmount1)
        public
        onlyRangeSwitcher
        returns (uint256 original0, uint256 original1, uint256 final0, uint256 final1)
    {
        LocalStorageV2Managed storage localStorage = getLocalStorageV2Managed();
        require(isInRange(newPosId), "new position must be in range for the switching");
        require(block.timestamp.sub(localStorage.rangeChangedTime) >= localStorage.rangeChangeDelayTime, "Not enough time passed");
        (original0, original1, final0, final1) = _changeRangeUnguarded(newPosId, minFinalAmount0, minFinalAmount1);
    }

    function _changeRangeUnguarded(uint256 newPosId, uint256 minFinalAmount0, uint256 minFinalAmount1)
        internal
        returns (uint256 original0, uint256 original1, uint256 final0, uint256 final1)
    {
        uint256 oldPosId = getCurrentRangePositionId();
        (original0, original1) = getAmountsForPosition(oldPosId);
        original0 = original0.add(token0().balanceOf(address(this)));
        original1 = original1.add(token1().balanceOf(address(this)));
        require(findIndexOfPositionId(newPosId) != INDEX_NOT_FOUND, "Position id not supported");
        LocalStorageV2Managed storage localStorage = getLocalStorageV2Managed();
        localStorage.rangeChangedTime = block.timestamp;
        _changeRange(newPosId);
        (final0, final1) = getAmountsForPosition(newPosId);
        final0 = final0.add(token0().balanceOf(address(this)));
        final1 = final1.add(token1().balanceOf(address(this)));
        require(final0 >= minFinalAmount0, "Amount of token0 after range switch is too low");
        require(final1 >= minFinalAmount1, "Amount of token1 after range switch is too low");

        address[] memory finalSellPath;
        if (localStorage.sellPath.length == 0) {
            finalSellPath = new address[](2);
            finalSellPath[0] = address(token0());
            finalSellPath[1] = address(token1());
        } else {
            finalSellPath = localStorage.sellPath;
        }

        // converting final0 into token1
        uint256[] memory amounts;

        uint256 allFinalTokensConvertedIntoToken1 = final1;
        if (final0 > 0) {
            amounts = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D).getAmountsOut(final0, finalSellPath);
            allFinalTokensConvertedIntoToken1 = final1.add(amounts[1]);
        }
        // converting original0 into token1
        uint256 allOriginalTokensConvertedIntoToken1 = original1;
        if (original0 > 0) {
            amounts = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D).getAmountsOut(original0, finalSellPath);
            allOriginalTokensConvertedIntoToken1 = original1.add(amounts[1]);
        }

        // if there is loss, check if it is too much
        if (allFinalTokensConvertedIntoToken1 < allOriginalTokensConvertedIntoToken1) {
            uint256 loss = allOriginalTokensConvertedIntoToken1.sub(allFinalTokensConvertedIntoToken1);
            require(allOriginalTokensConvertedIntoToken1.mul(localStorage.maxLossRatio).div(10000) >= loss, "Too much loss");
        }

        emit RangeChanged(oldPosId, newPosId, original0, original1, final0, final1);
    }

    function changeRangeUnguarded(uint256 newPosId, uint256 minFinalAmount0, uint256 minFinalAmount1)
        public
        onlyRangeManager
        returns (uint256 original0, uint256 original1, uint256 final0, uint256 final1)
    {
        return _changeRangeUnguarded(newPosId, minFinalAmount0, minFinalAmount1);
    }
}
