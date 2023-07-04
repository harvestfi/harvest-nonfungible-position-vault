pragma solidity 0.8.17;

interface IController {
    function addVaultAndStrategy(address _vault, address _strategy) external;
    function doHardWork(address _vault) external;
}
