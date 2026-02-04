// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../../src/reputation/ReputationRegistry.sol";

contract ReputationRegistryTest is Test {
    ReputationRegistry reputationRegistry;
    address owner = address(0x1);
    address authorizedCaller = address(0x2);
    address user = address(0x3);

    function setUp() public {
        vm.startPrank(owner);
        reputationRegistry = new ReputationRegistry();
        reputationRegistry.setAuthorizedCaller(authorizedCaller);
        vm.stopPrank();
    }
    
    function testSetAuthorizedCaller() public {
        address newCaller = address(0x4);
        vm.prank(owner);
        reputationRegistry.setAuthorizedCaller(newCaller);
        
        assertTrue(reputationRegistry.isAuthorizedCaller(newCaller));
    }
    
    function testRevokeAuthorizedCaller() public {
        vm.prank(owner);
        reputationRegistry.revokeAuthorizedCaller(authorizedCaller);
        
        assertFalse(reputationRegistry.isAuthorizedCaller(authorizedCaller));
    }
    
    function testIncreaseReputation() public {
        vm.prank(authorizedCaller);
        reputationRegistry.increaseReputation(1, 100);
        
        assertEq(reputationRegistry.reputationOf(1), 100);
    }
    
    function testDecreaseReputation() public {
        vm.prank(authorizedCaller);
        reputationRegistry.increaseReputation(1, 100);
        
        vm.prank(authorizedCaller);
        reputationRegistry.decreaseReputation(1, 30);
        
        assertEq(reputationRegistry.reputationOf(1), 70);
    }
    
    function testDecreaseReputationBelowZero() public {
        vm.prank(authorizedCaller);
        reputationRegistry.increaseReputation(1, 100);
        
        vm.prank(authorizedCaller);
        reputationRegistry.decreaseReputation(1, 150); // More than current reputation
        
        assertEq(reputationRegistry.reputationOf(1), 0);
    }
    
    function testReputationOfInitialValue() public {
        assertEq(reputationRegistry.reputationOf(1), 0);
    }
    
    function testUnauthorizedCallerCannotModifyReputation() public {
        vm.prank(user); // Unauthorized user
        vm.expectRevert("ReputationRegistry: not authorized");
        reputationRegistry.increaseReputation(1, 100);
        
        vm.prank(user); // Unauthorized user
        vm.expectRevert("ReputationRegistry: not authorized");
        reputationRegistry.decreaseReputation(1, 100);
    }
    
    function testOnlyOwnerCanSetAuthorizedCaller() public {
        vm.prank(user); // Unauthorized user
        vm.expectRevert("ReputationRegistry: not owner");
        reputationRegistry.setAuthorizedCaller(user);
    }
    
    function testMultipleAgentsReputation() public {
        vm.prank(authorizedCaller);
        reputationRegistry.increaseReputation(1, 100);
        
        vm.prank(authorizedCaller);
        reputationRegistry.increaseReputation(2, 200);
        
        vm.prank(authorizedCaller);
        reputationRegistry.decreaseReputation(1, 50);
        
        assertEq(reputationRegistry.reputationOf(1), 50);
        assertEq(reputationRegistry.reputationOf(2), 200);
    }
}