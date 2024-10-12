// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {IOwnersGroup} from "./interfaces/IOwnersGroup.sol";

/// @title OwnersGroup
/// @notice A contract for managing a group of owners with multi-signature functionality
/// @dev Inherits from Initializable and implements IOwnersGroup
contract OwnersGroup is Initializable, IOwnersGroup {
    address[] public owners;
    mapping(address => bool) public isOwner;

    mapping(address => mapping(bytes32 => mapping(address => bool))) private _approvals;
    mapping(address => mapping(bytes32 => uint256)) private _approvalCount;
    mapping(address => bool) public isWhitelisted;

    uint256 public override minRequiredApprovers;

    uint256 public requestExpirationTime;
    mapping(address => mapping(bytes32 => uint256)) private _firstApprovalTime;

    /// @notice Initializes the contract with a set of owners, minimum required approvers, and request expiration time
    /// @param initialOwners Array of initial owner addresses
    /// @param _minRequiredApprovers Minimum number of approvers required for actions
    /// @param _requestExpirationTime Time in seconds after which a request expires
    /// @dev This function can only be called once due to the initializer modifier
    function initialize(address[] memory initialOwners, uint256 _minRequiredApprovers, uint256 _requestExpirationTime)
        public
        initializer
    {
        if (initialOwners.length == 0) {
            revert NoOwnersProvided();
        }
        if (_minRequiredApprovers == 0 || _minRequiredApprovers > initialOwners.length) {
            revert InvalidMinRequiredApprovers(_minRequiredApprovers, 1, initialOwners.length);
        }

        for (uint256 i = 0; i < initialOwners.length; i++) {
            if (initialOwners[i] == address(0)) {
                revert InvalidOwner(address(0));
            }
            if (!isOwner[initialOwners[i]]) {
                isOwner[initialOwners[i]] = true;
                owners.push(initialOwners[i]);
            }
        }
        minRequiredApprovers = _minRequiredApprovers;
        requestExpirationTime = _requestExpirationTime;
    }

    /// @notice Modifier to restrict access to owners only
    modifier onlyOwners() {
        if (!isOwner[msg.sender]) {
            revert NotOwner(msg.sender);
        }
        _;
    }

    /// @notice Modifier to restrict access to whitelisted addresses only
    modifier onlyWhitelisted() {
        if (!isWhitelisted[msg.sender]) {
            revert NotWhitelisted(msg.sender);
        }
        _;
    }

    /// @notice Modifier to ensure a function call is approved by the required number of owners
    modifier onlyApproved() {
        bytes32 reqHash = keccak256(abi.encodePacked(msg.data, block.chainid, address(this)));
        if (_approve(address(this), reqHash, msg.sender)) {
            _;
        }
    }

    /// @notice Adds a new owner to the group
    /// @param newOwner Address of the new owner to be added
    function addOwner(address newOwner) external onlyOwners {
        if (newOwner == address(0)) {
            revert InvalidOwner(address(0));
        }
        _addOwner(newOwner);
    }

    /// @notice Removes an owner from the group
    /// @param ownerToRemove Address of the owner to be removed
    function removeOwner(address ownerToRemove) external onlyOwners {
        if (owners.length <= minRequiredApprovers) {
            revert CannotRemoveOwner(owners.length, minRequiredApprovers);
        }
        _removeOwner(ownerToRemove);
    }

    /// @notice Approves a request for a specific owner
    /// @param reqHash Hash of the request to be approved
    /// @param owner Address of the owner approving the request
    /// @return bool True if the approval results in execution, false otherwise
    function approve(bytes32 reqHash, address owner) external onlyWhitelisted returns (bool) {
        return _approve(msg.sender, reqHash, owner);
    }

    /// @notice Internal function to handle the approval process
    /// @param sender Address initiating the approval
    /// @param reqHash Hash of the request to be approved
    /// @param owner Address of the owner approving the request
    /// @return bool True if the approval results in execution, false otherwise
    function _approve(address sender, bytes32 reqHash, address owner) internal returns (bool) {
        if (!isOwner[owner]) {
            revert NotOwner(owner);
        }

        uint256 firstApprovalTime = _firstApprovalTime[sender][reqHash];
        if (firstApprovalTime == 0) {
            _firstApprovalTime[sender][reqHash] = block.timestamp;
        } else if (block.timestamp > firstApprovalTime + requestExpirationTime) {
            _resetRequest(sender, reqHash);
            revert RequestHasExpired(sender, reqHash);
        }

        if (!_approvals[sender][reqHash][owner]) {
            _approvals[sender][reqHash][owner] = true;
            _approvalCount[sender][reqHash]++;
            emit RequestApproved(sender, reqHash, _approvalCount[sender][reqHash]);
        }

        if (_shouldExecute(sender, reqHash)) {
            _resetRequest(sender, reqHash);
            emit RequestExecuted(sender, reqHash);
            return true;
        } else {
            return false;
        }
    }

    /// @notice Resets the request data when it expires or is executed
    /// @param sender Address initiating the request
    /// @param reqHash Hash of the request
    function _resetRequest(address sender, bytes32 reqHash) internal {
        delete _approvalCount[sender][reqHash];
        delete _firstApprovalTime[sender][reqHash];
        for (uint256 i = 0; i < owners.length; i++) {
            delete _approvals[sender][reqHash][owners[i]];
        }
    }

    /// @notice Sets the whitelist status for a given address
    /// @param sender Address to be whitelisted or removed from whitelist
    /// @param val Boolean value indicating whitelist status
    function setWhitelist(address sender, bool val) public onlyOwners onlyApproved {
        isWhitelisted[sender] = val;
        emit Whitelisted(sender, val);
    }

    /// @notice Checks if a request should be executed based on approval count
    /// @param sender Address initiating the request
    /// @param requestHash Hash of the request
    /// @return bool True if the request should be executed, false otherwise
    function _shouldExecute(address sender, bytes32 requestHash) internal view returns (bool) {
        return _approvalCount[sender][requestHash] >= minRequiredApprovers;
    }

    /// @notice Internal function to add a new owner
    /// @param newOwner Address of the new owner to be added
    function _addOwner(address newOwner) internal onlyApproved {
        if (!isOwner[newOwner]) {
            isOwner[newOwner] = true;
            owners.push(newOwner);
            emit OwnerAdded(newOwner);
        }
    }

    /// @notice Internal function to remove an owner
    /// @param ownerToRemove Address of the owner to be removed
    function _removeOwner(address ownerToRemove) internal onlyApproved {
        if (isOwner[ownerToRemove]) {
            isOwner[ownerToRemove] = false;
            for (uint256 i = 0; i < owners.length; i++) {
                if (owners[i] == ownerToRemove) {
                    owners[i] = owners[owners.length - 1];
                    owners.pop();
                    break;
                }
            }
            emit OwnerRemoved(ownerToRemove);
        }
    }

    /// @notice Sets the minimum number of required approvers
    /// @param _minRequiredApprovers New minimum number of required approvers
    function setMinRequiredApprovers(uint256 _minRequiredApprovers) external override onlyOwners {
        if (_minRequiredApprovers == 0 || _minRequiredApprovers > owners.length) {
            revert InvalidMinRequiredApprovers(_minRequiredApprovers, 1, owners.length);
        }
        _setMinRequiredApprovers(_minRequiredApprovers);
    }

    /// @notice Internal function to set the minimum number of required approvers
    /// @param _minRequiredApprovers New minimum number of required approvers
    function _setMinRequiredApprovers(uint256 _minRequiredApprovers) internal onlyApproved {
        minRequiredApprovers = _minRequiredApprovers;
        emit MinRequiredApproversChanged(_minRequiredApprovers);
    }

    /// @notice Sets the request expiration time
    /// @param _requestExpirationTime New expiration time in seconds
    function setRequestExpirationTime(uint256 _requestExpirationTime) external onlyOwners onlyApproved {
        requestExpirationTime = _requestExpirationTime;
        emit RequestExpirationTimeChanged(_requestExpirationTime);
    }

    function ownerCount() external view returns (uint256) {
        return owners.length;
    }
}
