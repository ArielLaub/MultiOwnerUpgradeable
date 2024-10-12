// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../utils/TestMultiOwnableUpgradeable.sol";
import "../../src/OwnersGroup.sol";

contract MultiOwnableUpgradeableOnlyOwnersTest is Test {
    TestMultiOwnableUpgradeable testContract;
    OwnersGroup ownersGroup;
    address[] owners;
    address owner1 = address(0x1);
    address owner2 = address(0x2);
    address owner3 = address(0x3);
    address nonOwner = address(0x4);

    event RequestApproved(address indexed sender, bytes32 indexed reqHash, uint256 approvalCount);
    event RequestExecuted(address indexed sender, bytes32 indexed reqHash);

    function setUp() public {
        owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        ownersGroup = new OwnersGroup();
        ownersGroup.initialize(owners, owners.length, 1 days);

        testContract = new TestMultiOwnableUpgradeable();
        testContract.initialize(ownersGroup);

        // Whitelist the test contract
        for (uint256 i = 0; i < owners.length; i++) {
            vm.prank(owners[i]);
            ownersGroup.setWhitelist(address(testContract), true);
        }
    }

    function test_RevertWhen_CalledByNonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(IOwnersGroup.NotOwner.selector, nonOwner));
        testContract.setSomeValue(42);
    }

    function test_FirstApproval() public {
        bytes32 reqHash = keccak256(
            abi.encodePacked(
                abi.encodeWithSelector(TestMultiOwnableUpgradeable.setSomeValue.selector, 42),
                block.chainid,
                address(testContract)
            )
        );

        vm.prank(owner1);
        vm.expectEmit(true, true, false, true);
        emit RequestApproved(address(testContract), reqHash, 1);
        testContract.setSomeValue(42);

        assertEq(testContract.getSomeValue(), 0, "Function should not be executed on first approval");
    }

    function test_NotLastRequiredApproval() public {
        bytes32 reqHash = keccak256(
            abi.encodePacked(
                abi.encodeWithSelector(TestMultiOwnableUpgradeable.setSomeValue.selector, 42),
                block.chainid,
                address(testContract)
            )
        );

        vm.prank(owner1);
        testContract.setSomeValue(42);

        vm.prank(owner2);
        vm.expectEmit(true, true, false, true);
        emit RequestApproved(address(testContract), reqHash, 2);
        testContract.setSomeValue(42);

        assertEq(testContract.getSomeValue(), 0, "Function should not be executed on second approval");
    }

    function test_LastRequiredApproval() public {
        bytes32 reqHash = keccak256(
            abi.encodePacked(
                abi.encodeWithSelector(TestMultiOwnableUpgradeable.setSomeValue.selector, 42),
                block.chainid,
                address(testContract)
            )
        );
        assertTrue(ownersGroup.ownerCount() == 3, "verify owner count");
        for (uint256 i = 0; i < owners.length; i++) {
            vm.startPrank(owners[i]);
            vm.expectEmit(true, true, false, true);
            emit RequestApproved(address(testContract), reqHash, i + 1);
            if (i == owners.length - 1) {
                vm.expectEmit(true, true, false, true);
                emit RequestExecuted(address(testContract), reqHash);
            }
            testContract.setSomeValue(42);
            vm.stopPrank();
        }

        assertEq(testContract.getSomeValue(), 42, "Function should be executed on last approval");
    }
}
