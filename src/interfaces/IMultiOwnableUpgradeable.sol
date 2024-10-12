// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IMultiOwnableUpgradeable {
    /// @notice Error thrown when a non-owner tries to access an owner-only function
    /// @param account The address that attempted the action
    error NotOwner(address account);

    /// @notice Error thrown when a non-whitelisted contract address is used
    /// @param contractAddress The address that was not whitelisted
    error NotWhitelisted(address contractAddress);
}
