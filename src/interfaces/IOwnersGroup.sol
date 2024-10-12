// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IOwnersGroup {
    event OwnerAdded(address indexed newOwner);
    event OwnerRemoved(address indexed removedOwner);
    event Whitelisted(address indexed contractAddress, bool isWhitelisted);
    event RequestApproved(address indexed sender, bytes32 indexed reqHash, uint256 approvalCount);
    event RequestExecuted(address indexed sender, bytes32 indexed reqHash);
    event MinRequiredApproversChanged(uint256 newMinRequiredApprovers);
    event RequestExpired(address indexed sender, bytes32 indexed reqHash);
    event RequestExpirationTimeChanged(uint256 newExpirationTime);

    error NotOwner(address account);
    error NotWhitelisted(address account);
    error InvalidOwner(address owner);
    error NoOwnersProvided();
    error InvalidMinRequiredApprovers(uint256 provided, uint256 minAllowed, uint256 maxAllowed);
    error CannotRemoveOwner(uint256 currentOwnerCount, uint256 minRequiredApprovers);
    error RequestHasExpired(address sender, bytes32 reqHash);

    function owners(uint256 index) external view returns (address);
    function ownerCount() external view returns (uint256);
    function isOwner(address owner) external view returns (bool);
    function isWhitelisted(address account) external view returns (bool);

    function approve(bytes32 reqHash, address owner) external returns (bool);
    function setWhitelist(address sender, bool val) external;
    function setMinRequiredApprovers(uint256 _minRequiredApprovers) external;
    function minRequiredApprovers() external view returns (uint256);

    function addOwner(address newOwner) external;
    function removeOwner(address ownerToRemove) external;
}
