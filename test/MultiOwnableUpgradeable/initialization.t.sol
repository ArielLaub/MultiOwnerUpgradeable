// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../utils/TestMultiOwnableUpgradeable.sol";
import "../../src/OwnersGroup.sol";

contract MultiOwnableUpgradeableInitializationTest is Test {
    TestMultiOwnableUpgradeable testContract;
    OwnersGroup ownersGroup;
    address[] validOwners;
    address owner1 = address(0x1);
    address owner2 = address(0x2);
    address owner3 = address(0x3);

    function setUp() public {
        validOwners = new address[](3);
        validOwners[0] = owner1;
        validOwners[1] = owner2;
        validOwners[2] = owner3;

        ownersGroup = new OwnersGroup();
        ownersGroup.initialize(validOwners, validOwners.length, 1 days);
    }

    function test_CorrectInitialization() public {
        // Whitelist the test contract
        testContract = new TestMultiOwnableUpgradeable();
        for (uint256 i = 0; i < validOwners.length; i++) {
            vm.prank(validOwners[i]);
            ownersGroup.setWhitelist(address(testContract), true);
        }
        assertTrue(ownersGroup.isWhitelisted(address(testContract)), "Contract should be whitelisted");

        testContract.initialize(ownersGroup);
        assertEq(address(testContract.ownersGroup()), address(ownersGroup), "OwnersGroup should be set correctly");
    }
}
