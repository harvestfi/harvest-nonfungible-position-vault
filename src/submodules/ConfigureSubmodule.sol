//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Helpers
import {Modifiers} from "../core/Modifiers.sol";

contract ConfigureSubmodule is Modifiers {
    function initialize(uint256 _tokenId, address _dataContract, address _storage, address _zapContract) public initialized {
        // initializing the governance for the contract
        ControllableInit.initialize(_storage);
        // sets data storage contract to the right slot and initializes it
        setAddress(_DATA_CONTRACT_SLOT, _dataContract);

        IERC721Upgradeable(_NFT_POSITION_MANAGER).transferFrom(msg.sender, address(this), _tokenId);

        // fetch info from nft.
        (,, address _token0, address _token1, uint24 _fee, int24 _tickLower, int24 _tickUpper, uint256 _initialLiquidity,,,,) =
            INonfungiblePositionManager(_NFT_POSITION_MANAGER).positions(_tokenId);

        IUniVaultStorageV1(_dataContract).initializeByVault(_token0, _token1, _fee, _tickLower, _tickUpper, _zapContract);
        // initializing the vault token. By default, it has 18 decimals.
        __ERC20_init_unchained(
            string(abi.encodePacked("fUniV3_", ERC20Upgradeable(_token0).symbol(), "_", ERC20Upgradeable(_token1).symbol())),
            string(abi.encodePacked("fUniV3_", ERC20Upgradeable(_token0).symbol(), "_", ERC20Upgradeable(_token1).symbol()))
        );

        // set the NFT ID in the data contract
        getStorage().setPosId(_tokenId);

        // mint the initial shares and send them to the specified recipient, as well as overflow of the tokens
        _mint(msg.sender, uint256(_initialLiquidity));
    }

    function configureVault(
        address submoduleDeposit,
        address _feeRewardForwarder,
        uint256 _feeRatio,
        address _platformTarget,
        uint256 _platformRatio
    ) public onlyGovernance {
        getStorage().configureFees(_feeRewardForwarder, _feeRatio, _platformTarget, _platformRatio);

        setSubmodule(keccak256("deposit"), submoduleDeposit);
    }

    function setZapContract(address newAddress) public onlyGovernance {
        getStorage().setZapContract(newAddress);
    }

    function configureFees(address _feeRewardForwarder, uint256 _feeRatio, address _platformTarget, uint256 _platformRatio)
        external
        onlyGovernance
    {
        getStorage().configureFees(_feeRewardForwarder, _feeRatio, _platformTarget, _platformRatio);
    }

    function setVaultPause(bool _flag) public onlyGovernanceOrController {
        return setBoolean(_VAULT_PAUSE_SLOT, _flag);
    }
}
