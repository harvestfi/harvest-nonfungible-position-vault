pragma solidity 0.7.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "../UniVaultProxy.sol";
import "../inheritance/GovernableInit.sol";
import "../UniVaultStorageV1.sol";
import "../interface/IUniVaultV1.sol";
import "../interface/IUniVaultStorageV1.sol";

import "../submodules/UniVaultSubModuleChangeRangeV2Managed.sol";
import "../submodules/interface/IUniVaultSubmoduleChangeRangeV2Managed.sol";

contract UniV3VaultFactory is Ownable {
    address public uniVaultBeaconProxyImplementation = 0xEB779f9ed1bac88b83993b2856a2957A14cF92D0;
    address public zap = 0x9B47D39cb1b02Bb77A517fEA39963534a6243Df3;
    address public positionManager = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address public depositSubmodule = 0x406370ceFa004a3cb5D4f2730b679D488F4E7568;
    address public feeRewardForwarder = 0x153C544f72329c1ba521DDf5086cf2fA98C86676;
    uint256 public profitSharingRatio = 2000;
    address public platformFeeCollector = 0xd00FCE4966821Da1EdD1221a02aF0AFc876365e4;
    uint256 public platformFeeRatio = 1000;
    address public lastDeployedAddress = address(0);

    // managed vault
    address public depositSubmoduleManaged = address(0);
    address public changeRangeSubmoduleManaged = address(0);

    mapping(address => bool) public whitelist;

    modifier onlyWhitelisted() {
        require(whitelist[msg.sender] || msg.sender == owner(), "not allowed");
        _;
    }

    function setWhitelist(address target, bool isWhitelisted) external onlyOwner {
        whitelist[target] = isWhitelisted;
    }

    function overrideDepositSubmodule(address newAddress) external onlyOwner {
        depositSubmodule = newAddress;
    }

    function overrideChangeRangeSubmoduleManaged(address newAddress) external onlyOwner {
        changeRangeSubmoduleManaged = newAddress;
    }

    function overrideDepositSubmoduleManaged(address newAddress) external onlyOwner {
        depositSubmoduleManaged = newAddress;
    }

    function governance() external view returns (address) {
        // fake governance
        return address(this);
    }

    function isGovernance(address addr) external view returns (bool) {
        return addr == address(this);
    }

    function deploy(address store, uint256 univ3PoolId) external onlyWhitelisted returns (address vault) {
        INonfungiblePositionManager uniV3posManager = INonfungiblePositionManager(positionManager);

        UniVaultProxy vaultProxy = new UniVaultProxy(
      uniVaultBeaconProxyImplementation, ""
    );

        uniV3posManager.approve(address(vaultProxy), univ3PoolId);

        UniVaultStorageV1 vaultStorage = new UniVaultStorageV1(address(vaultProxy));

        IUniVaultV1 vault = IUniVaultV1(address(vaultProxy));
        vault.initialize(
            univ3PoolId,
            address(vaultStorage),
            address(this), // using the fake storage at first
            zap
        );

        vault.configureVault(depositSubmodule, feeRewardForwarder, profitSharingRatio, platformFeeCollector, platformFeeRatio);

        GovernableInit(address(vault)).setStorage(store); // setting to the right storage
        lastDeployedAddress = address(vault);
        return lastDeployedAddress;
    }

    function deployManaged(address store, uint256[] calldata univ3PoolIds) external onlyWhitelisted returns (address vault) {
        require(depositSubmoduleManaged != address(0), "depositSubmoduleManaged not set");
        require(changeRangeSubmoduleManaged != address(0), "changeRangeSubmoduleManaged not set");
        INonfungiblePositionManager uniV3posManager = INonfungiblePositionManager(positionManager);

        UniVaultProxy vaultProxy = new UniVaultProxy(
      uniVaultBeaconProxyImplementation, ""
    );

        uniV3posManager.approve(address(vaultProxy), univ3PoolIds[0]);

        UniVaultStorageV1 vaultStorage = new UniVaultStorageV1(address(vaultProxy));

        IUniVaultV1 vault = IUniVaultV1(address(vaultProxy));
        vault.initialize(
            univ3PoolIds[0],
            address(vaultStorage),
            address(this), // using the fake storage at first
            zap
        );

        vault.configureVault(
            depositSubmoduleManaged, feeRewardForwarder, profitSharingRatio, platformFeeCollector, platformFeeRatio
        );

        require(changeRangeSubmoduleManaged != address(0), "change range submodule not defined");
        vault.setSubmodule(bytes32(keccak256("changeRange")), changeRangeSubmoduleManaged);

        // transferring other position tokens
        for (uint256 i = 1; i < univ3PoolIds.length; i++) {
            uniV3posManager.transferFrom(address(this), address(vaultProxy), univ3PoolIds[i]);
        }
        IUniVaultSubmoduleChangeRangeV2Managed(address(vault)).addPositionIds(univ3PoolIds);

        GovernableInit(address(vault)).setStorage(store); // setting to the right storage
        lastDeployedAddress = address(vault);
        return lastDeployedAddress;
    }

    function info(address vault)
        external
        view
        returns (address[] memory Underlying, address NewVault, address DataContract, uint256 FeeAmount, uint256 PosId)
    {
        DataContract = address(IUniVaultV1(vault).getStorage());
        PosId = IUniVaultStorageV1(DataContract).posId();
        address token0;
        address token1;
        uint24 fee;
        INonfungiblePositionManager uniV3posManager = INonfungiblePositionManager(positionManager);
        (,, token0, token1, fee,,,,,,,) = uniV3posManager.positions(PosId);

        Underlying = new address[](2);
        Underlying[0] = token0;
        Underlying[1] = token1;
        NewVault = vault;
        FeeAmount = uint256(fee);
    }

    function withdrawPosition(uint256 univ3PoolId, address destination) external onlyOwner {
        INonfungiblePositionManager uniV3posManager = INonfungiblePositionManager(positionManager);
        uniV3posManager.transferFrom(address(this), destination, univ3PoolId);
    }
}
