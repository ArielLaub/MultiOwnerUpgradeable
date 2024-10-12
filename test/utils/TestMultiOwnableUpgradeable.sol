pragma solidity ^0.8.27;

import {MultiOwnableUpgradeable} from "../../src/MultiOwnableUpgradeable.sol";
import {IOwnersGroup} from "../../src/interfaces/IOwnersGroup.sol";

contract TestMultiOwnableUpgradeable is MultiOwnableUpgradeable {
    uint256 private _someValue;

    function initialize(IOwnersGroup _ownersGroup) public initializer {
        __MultiOwnableUpgradeable_init(_ownersGroup);
    }

    function setSomeValue(uint256 newValue) public onlyOwners {
        _setSomeValue(newValue);
    }

    function _setSomeValue(uint256 newValue) internal onlyApproved {
        _someValue = newValue;
    }

    function getSomeValue() public view returns (uint256) {
        return _someValue;
    }
}
