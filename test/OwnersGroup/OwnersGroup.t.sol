// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import {OwnersGroup} from "../../src/OwnersGroup.sol";
import {IOwnersGroup} from "../../src/interfaces/IOwnersGroup.sol";

contract OwnersGroupTest is Test {
    OwnersGroup public ownersGroup;
    address[] public initialOwners;
    uint256 public constant INITIAL_MIN_APPROVERS = 2;
    uint256 public constant INITIAL_EXPIRATION_TIME = 1 days;

    address public owner1 = address(1);
    address public owner2 = address(2);
    address public owner3 = address(3);
    address public nonOwner = address(4);
    address public whitelistedContract = address(5);

    function setUp() public {
        initialOwners = new address[](3);
        initialOwners[0] = owner1;
        initialOwners[1] = owner2;
        initialOwners[2] = owner3;

        ownersGroup = new OwnersGroup();
        ownersGroup.initialize(initialOwners, INITIAL_MIN_APPROVERS, INITIAL_EXPIRATION_TIME);

        for (uint256 i = 0; i < initialOwners.length; i++) {
            vm.prank(initialOwners[i]);
            ownersGroup.setWhitelist(whitelistedContract, true);
        }
    }

    function test_InitializeWithEmptyOwners() public {
        OwnersGroup newOwnersGroup = new OwnersGroup();
        address[] memory emptyOwners;
        vm.expectRevert(abi.encodeWithSelector(IOwnersGroup.NoOwnersProvided.selector));
        newOwnersGroup.initialize(emptyOwners, 1, 1 days);
    }

    function test_InitializeWithZeroAddress() public {
        OwnersGroup newOwnersGroup = new OwnersGroup();
        address[] memory ownersWithZero = new address[](3);
        ownersWithZero[0] = address(1);
        ownersWithZero[1] = address(0);
        ownersWithZero[2] = address(3);
        vm.expectRevert(abi.encodeWithSelector(IOwnersGroup.InvalidOwner.selector, address(0)));
        newOwnersGroup.initialize(ownersWithZero, 2, 1 days);
    }

    function test_InitializeWithValidOwners() public view {
        for (uint256 i = 0; i < initialOwners.length; i++) {
            assertTrue(ownersGroup.isOwner(initialOwners[i]));
        }
        assertEq(ownersGroup.ownerCount(), initialOwners.length);
    }

    function test_InitializeWithInvalidMinRequiredApprovers() public {
        OwnersGroup newOwnersGroup = new OwnersGroup();
        vm.expectRevert(abi.encodeWithSelector(IOwnersGroup.InvalidMinRequiredApprovers.selector, 4, 1, 3));
        newOwnersGroup.initialize(initialOwners, 4, 1 days);

        vm.expectRevert(abi.encodeWithSelector(IOwnersGroup.InvalidMinRequiredApprovers.selector, 0, 1, 3));
        newOwnersGroup.initialize(initialOwners, 0, 1 days);
    }

    function test_OnlyOwnersModifier() public {
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(IOwnersGroup.NotOwner.selector, nonOwner));
        ownersGroup.setMinRequiredApprovers(2);
    }

    function test_OnlyWhitelistedModifier() public {
        bytes32 reqHash = keccak256("test request");

        // Try to approve with a non-whitelisted address
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(IOwnersGroup.NotWhitelisted.selector, nonOwner));
        ownersGroup.approve(reqHash, owner1);

        // Now whitelist the contract itself (assuming the test contract needs to be whitelisted)
        for (uint256 i = 0; i < initialOwners.length; i++) {
            vm.prank(initialOwners[i]);
            ownersGroup.setWhitelist(nonOwner, true);
        }

        // Try to approve with a whitelisted address (the test contract itself)
        vm.prank(nonOwner);
        ownersGroup.approve(reqHash, owner1);
        // This should not revert
    }

    function test_AddNewOwner() public {
        // Simulate approval from all current owners
        for (uint256 i = 0; i < initialOwners.length; i++) {
            vm.prank(initialOwners[i]);
            ownersGroup.addOwner(nonOwner);
        }

        assertTrue(ownersGroup.isOwner(nonOwner));
        assertEq(ownersGroup.ownerCount(), initialOwners.length + 1);
    }

    function test_RemoveOwner() public {
        // Simulate approval from all current owners
        for (uint256 i = 0; i < INITIAL_MIN_APPROVERS; i++) {
            vm.prank(initialOwners[i]);
            ownersGroup.removeOwner(owner1);
        }

        assertFalse(ownersGroup.isOwner(owner1));
        assertEq(ownersGroup.ownerCount(), initialOwners.length - 1);
    }

    function test_RemoveOwnerWithMinRequiredApprovers() public {
        // Set minRequiredApprovers to current owner count
        for (uint256 i = 0; i < INITIAL_MIN_APPROVERS; i++) {
            vm.prank(initialOwners[i]);
            ownersGroup.setMinRequiredApprovers(initialOwners.length);
        }

        // Try to remove an owner
        vm.expectRevert(
            abi.encodeWithSelector(IOwnersGroup.CannotRemoveOwner.selector, initialOwners.length, initialOwners.length)
        );
        vm.prank(owner2);
        ownersGroup.removeOwner(owner1);
    }

    function test_SetMinRequiredApprovers() public {
        uint256 newMinRequired = initialOwners.length;
        bytes32 reqHash = keccak256(
            abi.encodePacked(
                abi.encodeWithSelector(OwnersGroup.setMinRequiredApprovers.selector, newMinRequired),
                block.chainid,
                address(ownersGroup)
            )
        );

        for (uint256 i = 0; i < INITIAL_MIN_APPROVERS; i++) {
            vm.prank(initialOwners[i]);
            vm.expectEmit(true, true, true, true);
            emit IOwnersGroup.RequestApproved(address(ownersGroup), reqHash, i + 1);
            if (i == INITIAL_MIN_APPROVERS - 1) {
                vm.expectEmit(true, true, true, true);
                emit IOwnersGroup.RequestExecuted(address(ownersGroup), reqHash);
            }
            ownersGroup.setMinRequiredApprovers(newMinRequired);
        }
        assertEq(ownersGroup.minRequiredApprovers(), newMinRequired);
    }

    function test_SetInvalidMinRequiredApprovers() public {
        uint256 invalidMinRequired = initialOwners.length + 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                IOwnersGroup.InvalidMinRequiredApprovers.selector, invalidMinRequired, 1, initialOwners.length
            )
        );
        vm.prank(owner1);
        ownersGroup.setMinRequiredApprovers(invalidMinRequired);
    }

    function test_ApproveRequest() public {
        bytes32 reqHash = keccak256("test request");
        // Approve from minimum required owners
        vm.startPrank(whitelistedContract);
        for (uint256 i = 0; i < INITIAL_MIN_APPROVERS; i++) {
            vm.expectEmit(true, true, true, true);
            emit IOwnersGroup.RequestApproved(whitelistedContract, reqHash, i + 1);
            if (i == INITIAL_MIN_APPROVERS - 1) {
                vm.expectEmit(true, true, true, true);
                emit IOwnersGroup.RequestExecuted(whitelistedContract, reqHash);
            }
            ownersGroup.approve(reqHash, initialOwners[i]);
        }
        vm.stopPrank();
    }

    function test_ApproveRequestNotEnoughApprovals() public {
        bytes32 reqHash = keccak256("test request");

        // Approve from less than minimum required owners
        vm.prank(whitelistedContract);
        bool isApproved = ownersGroup.approve(reqHash, initialOwners[0]);
        assertFalse(isApproved);
    }

    function test_ApproveRequestExpired() public {
        bytes32 reqHash = keccak256("test request");

        // First approval
        vm.prank(whitelistedContract);
        ownersGroup.approve(reqHash, initialOwners[0]);

        // Move time forward past the expiration time
        vm.warp(block.timestamp + INITIAL_EXPIRATION_TIME + 1);

        // Try to approve again
        vm.prank(whitelistedContract);
        vm.expectRevert(abi.encodeWithSelector(IOwnersGroup.RequestHasExpired.selector, whitelistedContract, reqHash));
        ownersGroup.approve(reqHash, initialOwners[1]);

        // Verify that the request data has been reset
        // assertEq(ownersGroup.getApprovalCount(whitelistedContract, reqHash), 0);
    }

    function test_SetRequestExpirationTime() public {
        uint256 newExpirationTime = 2 days;
        bytes32 reqHash = keccak256(
            abi.encodePacked(
                abi.encodeWithSelector(OwnersGroup.setRequestExpirationTime.selector, newExpirationTime),
                block.chainid,
                address(ownersGroup)
            )
        );

        for (uint256 i = 0; i < INITIAL_MIN_APPROVERS; i++) {
            vm.prank(initialOwners[i]);
            vm.expectEmit(true, true, true, true);
            emit IOwnersGroup.RequestApproved(address(ownersGroup), reqHash, i + 1);
            if (i == INITIAL_MIN_APPROVERS - 1) {
                vm.expectEmit(true, true, true, true);
                emit IOwnersGroup.RequestExecuted(address(ownersGroup), reqHash);
                vm.expectEmit(true, true, true, true);
                emit IOwnersGroup.RequestExpirationTimeChanged(newExpirationTime);
            }
            ownersGroup.setRequestExpirationTime(newExpirationTime);
        }
        assertEq(ownersGroup.requestExpirationTime(), newExpirationTime);
    }

    function test_SetRequestExpirationTimeWithoutFullApproval() public {
        uint256 newExpirationTime = 2 days;
        vm.prank(initialOwners[0]);
        ownersGroup.setRequestExpirationTime(newExpirationTime);
        assertEq(ownersGroup.requestExpirationTime(), INITIAL_EXPIRATION_TIME);
    }
}
