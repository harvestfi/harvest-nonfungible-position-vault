//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./interface/IUniVaultV1.sol";

contract UniVaultProxy is ERC1967Proxy {
    constructor(address _logic, bytes memory _data) ERC1967Proxy(_logic, _data) {}

    /**
     * The main logic. If the timer has elapsed and there is a schedule upgrade,
     * the governance can upgrade the vault
     */
    function upgrade() external {
        (bool should, address newImplementation) = IUniVaultV1(address(this)).shouldUpgrade();
        require(should, "Upgrade not scheduled");
        _upgradeTo(newImplementation);

        // the finalization needs to be executed on itself to update the storage of this proxy
        // it also needs to be invoked by the governance, not by address(this), so delegatecall is needed
        (bool success,) = address(this).delegatecall(abi.encodeWithSignature("finalizeUpgrade()"));

        require(success, "Issue when finalizing the upgrade");
    }

    function implementation() external view returns (address) {
        return _implementation();
    }
}
