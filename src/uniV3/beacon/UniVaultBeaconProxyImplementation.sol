pragma solidity 0.8.17;

import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "../lib/BytesLib.sol";

contract UniVaultBeaconProxyImplementation is BeaconProxy {
    address public constant BEACON_ADDRESS = 0x0f42336E988Ba07d5c6c1B686844208A2Dec46Ad;

    using BytesLib for bytes;

    constructor() BeaconProxy(BEACON_ADDRESS, "") {}

    /**
     * @dev Initializes the contract. Used by the proxy pattern.
     */
    function initialize(
        uint256, // _tokenId,
        address, // _dataContract,
        address, // _storage,
        address // _zapContract
    ) public {
        _setBeacon(BEACON_ADDRESS, "");
        (bool success, bytes memory data) = (_implementation()).delegatecall(msg.data);
        string memory revertMsg = data._getRevertMsgFromRes();
        require(success, revertMsg);
    }

    /**
     * @dev Initializes the contract (for initializing the implementation)
     */
    function initializeEmpty() public {
        _setBeacon(BEACON_ADDRESS, "");
        (bool success, bytes memory data) = (_implementation()).delegatecall(msg.data);
        string memory revertMsg = data._getRevertMsgFromRes();
        require(success, revertMsg);
    }

    /**
     * @dev sets the beacon address to the current beacon
     * this needs to happen once for each vault
     * once the beacon is set, calling finalizeUpgrade()
     * on the beacon's current implementation
     */
    function finalizeUpgrade() external {
        _setBeacon(BEACON_ADDRESS, "");
        (bool success, bytes memory data) = (_implementation()).delegatecall(msg.data);
        string memory revertMsg = data._getRevertMsgFromRes();
        require(success, revertMsg);
    }
}
