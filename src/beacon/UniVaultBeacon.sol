pragma solidity 0.8.17;

import "@openzeppelin/contracts/proxy/UpgradeableBeacon.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

import "@openzeppelin/contracts/utils/EnumerableSet.sol";

contract UniVaultBeacon is UpgradeableBeacon {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeMathUpgradeable for uint256;

    uint256 public nextImplementationDelay = 0;
    mapping(address => uint256) public whitelistedImplementationStartTime;
    EnumerableSet.AddressSet private whitelistedImplementationSet;

    event ImplementationAdded(address newImplementation, uint256 startTime);

    constructor() public UpgradeableBeacon(0xe41E27CD5c99bf93466fCe3F797cf038efc3C37d) {
        // all the existing implementations
        whitelistedImplementationSet.add(0x3833b631B454AE659a2Ca11104854823009969D4);
        whitelistedImplementationSet.add(0xdd40f85251AAAB470EE93AC445DE52F512235Caf);
        whitelistedImplementationSet.add(0x392a5c02635DCDBd4C945785Ce530a9a69DDA6c2);
        whitelistedImplementationSet.add(0xbF1ca4bab407d5A9FcA67D0aF93F4f37C155dE21);
        whitelistedImplementationSet.add(0xe41E27CD5c99bf93466fCe3F797cf038efc3C37d);
    }

    function upgradeTo(address newImplementation) public override onlyOwner {
        require(whitelistedImplementationSet.contains(newImplementation), "implementation not whitelisted");
        require(block.timestamp >= whitelistedImplementationStartTime[newImplementation], "timelock not expired");
        super.upgradeTo(newImplementation);
    }

    function addImplementation(address newImplementation) public onlyOwner {
        require(Address.isContract(newImplementation), "UpgradeableBeacon: implementation is not a contract");
        whitelistedImplementationSet.add(newImplementation);
        uint256 startTime = nextImplementationDelay.add(block.timestamp);
        whitelistedImplementationStartTime[newImplementation] = startTime;
        emit ImplementationAdded(newImplementation, startTime);
    }

    function increaseUpgradeDelay(uint256 delay) external onlyOwner {
        nextImplementationDelay = nextImplementationDelay.add(delay);
    }

    function whitelistedImplementationsLength() public view returns (uint256) {
        return whitelistedImplementationSet.length();
    }

    function whitelistedImplementations(uint256 index) public view returns (address) {
        return whitelistedImplementationSet.at(index);
    }
}
