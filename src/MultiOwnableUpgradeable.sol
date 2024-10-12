// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IOwnersGroup} from "./OwnersGroup.sol";

/// @title MultiOwnableUpgradeable
/// @notice An abstract contract for multi-owner functionality with upgradeability
/// @dev Inherits from Initializable for upgradeability support
abstract contract MultiOwnableUpgradeable is Initializable {
    /// @notice The contract managing the group of owners
    IOwnersGroup public ownersGroup;

    /// @notice Error thrown when a non-owner tries to access an owner-only function
    /// @param account The address that attempted the action
    error NotOwner(address account);

    /// @notice Error thrown when a non-whitelisted contract address is used
    /// @param contractAddress The address that was not whitelisted
    error NotWhitelisted(address contractAddress);

    /// @notice Initializes the contract with an owners group
    /// @param _ownersGroup The address of the OwnersGroup contract
    function __MultiOwnableUpgradeable_init(IOwnersGroup _ownersGroup) internal {
        ownersGroup = _ownersGroup;
    }

    /// @notice Modifier to restrict access to owners only
    /// @dev Reverts with Not
    modifier onlyOwners() {
        if (!ownersGroup.isOwner(msg.sender)) {
            revert NotOwner(msg.sender);
        }
        _;
    }

    /// @notice Modifier to restrict access to approved transactions only
    /// @dev Checks if the transaction is approved by the owners group
    modifier onlyApproved() {
        bytes32 reqHash = keccak256(abi.encodePacked(msg.data, block.chainid, address(this)));
        if (ownersGroup.approve(reqHash, msg.sender)) {
            _;
        }
    }
}
