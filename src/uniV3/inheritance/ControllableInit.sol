pragma solidity 0.7.6;

import "./GovernableInit.sol";

// A clone of Governable supporting the Initializable interface and pattern
contract ControllableInit is GovernableInit {
    constructor() {}

    function initialize(address _storage) public initializer {
        GovernableInit.initializeGovernable(_storage);
    }

    modifier onlyController() {
        require(Storage(_storage()).isController(msg.sender), "Not a controller");
        _;
    }

    modifier onlyControllerOrGovernance() {
        require(
            (Storage(_storage()).isController(msg.sender) || Storage(_storage()).isGovernance(msg.sender)),
            "The caller must be controller or governance"
        );
        _;
    }

    function controller() public view returns (address) {
        return Storage(_storage()).controller();
    }
}
