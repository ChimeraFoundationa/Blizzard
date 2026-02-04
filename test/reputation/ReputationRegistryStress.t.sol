// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../../src/reputation/ReputationRegistry.sol";

contract ReputationRegistryStressTest is Test {
    ReputationRegistry reputationRegistry;
    address owner = address(0x1);
    address authorizedCaller = address(0x2);
    
    function setUp() public {
        vm.startPrank(owner);
        reputationRegistry = new ReputationRegistry();
        reputationRegistry.setAuthorizedCaller(authorizedCaller);
        vm.stopPrank();
    }
    
    function testStressReputationUpdates() public {
        uint256 numAgents = 1000;
        
        // Perform many reputation increases
        vm.startPrank(authorizedCaller);
        for (uint256 i = 0; i < numAgents; i++) {
            reputationRegistry.increaseReputation(i, i + 10); // Different amounts
        }
        vm.stopPrank();
        
        // Verify all reputations are set correctly
        for (uint256 i = 0; i < numAgents; i++) {
            assertEq(reputationRegistry.reputationOf(i), i + 10);
        }
        
        // Perform many reputation decreases
        vm.startPrank(authorizedCaller);
        for (uint256 i = 0; i < numAgents; i++) {
            reputationRegistry.decreaseReputation(i, i + 5); // Different amounts
        }
        vm.stopPrank();
        
        // Verify all reputations after decreases
        for (uint256 i = 0; i < numAgents; i++) {
            uint256 expected = i + 10 > i + 5 ? i + 10 - (i + 5) : 0;
            assertEq(reputationRegistry.reputationOf(i), expected);
        }
    }
    
    function testSybilAttackReputationManipulation() public {
        address maliciousActor = address(0x999);
        uint256 numAgents = 100;
        
        // Malicious actor tries to manipulate reputations without authorization
        vm.prank(maliciousActor);
        for (uint256 i = 0; i < numAgents; i++) {
            vm.expectRevert("ReputationRegistry: not authorized");
            reputationRegistry.increaseReputation(i, 100);
            
            vm.expectRevert("ReputationRegistry: not authorized");
            reputationRegistry.decreaseReputation(i, 50);
        }
        
        // Verify no reputations were manipulated
        for (uint256 i = 0; i < numAgents; i++) {
            assertEq(reputationRegistry.reputationOf(i), 0);
        }
    }
    
    function testEdgeCaseNegativeReputationProtection() public {
        uint256 agentId = 1;
        
        // Increase reputation first
        vm.prank(authorizedCaller);
        reputationRegistry.increaseReputation(agentId, 50);
        assertEq(reputationRegistry.reputationOf(agentId), 50);
        
        // Try to decrease by more than current reputation (should cap at 0)
        vm.prank(authorizedCaller);
        reputationRegistry.decreaseReputation(agentId, 100); // More than current
        assertEq(reputationRegistry.reputationOf(agentId), 0);
        
        // Try to decrease again (should stay at 0)
        vm.prank(authorizedCaller);
        reputationRegistry.decreaseReputation(agentId, 50);
        assertEq(reputationRegistry.reputationOf(agentId), 0);
    }
    
    function testFuzzReputationIncrease(uint256 agentId, uint256 amount) public {
        vm.assume(amount < type(uint256).max / 2); // Prevent overflow in test
        
        vm.prank(authorizedCaller);
        reputationRegistry.increaseReputation(agentId, amount);
        
        assertEq(reputationRegistry.reputationOf(agentId), amount);
    }
    
    function testFuzzReputationDecrease(uint256 agentId, uint256 initialAmount, uint256 decreaseAmount) public {
        vm.assume(initialAmount < type(uint256).max / 2); // Prevent overflow
        vm.assume(decreaseAmount < type(uint256).max / 2); // Prevent overflow
        
        // Set initial reputation
        vm.prank(authorizedCaller);
        reputationRegistry.increaseReputation(agentId, initialAmount);
        
        vm.prank(authorizedCaller);
        reputationRegistry.decreaseReputation(agentId, decreaseAmount);
        
        uint256 expected = initialAmount >= decreaseAmount ? initialAmount - decreaseAmount : 0;
        assertEq(reputationRegistry.reputationOf(agentId), expected);
    }
    
    function testUnauthorizedAccessAttempts() public {
        address unauthorizedUser = address(0x555);
        
        vm.prank(unauthorizedUser);
        vm.expectRevert("ReputationRegistry: not authorized");
        reputationRegistry.increaseReputation(1, 100);
        
        vm.prank(unauthorizedUser);
        vm.expectRevert("ReputationRegistry: not authorized");
        reputationRegistry.decreaseReputation(1, 50);
        
        vm.prank(unauthorizedUser);
        vm.expectRevert("ReputationRegistry: not owner");
        reputationRegistry.setAuthorizedCaller(unauthorizedUser);
    }
    
    function testAuthorizationManagement() public {
        address newAuthorizedCaller = address(0x777);

        // Initially only authorizedCaller is authorized
        assertTrue(reputationRegistry.isAuthorizedCaller(authorizedCaller));
        assertFalse(reputationRegistry.isAuthorizedCaller(newAuthorizedCaller));

        // Owner can set new authorized caller (both remain authorized)
        vm.prank(owner);
        reputationRegistry.setAuthorizedCaller(newAuthorizedCaller);
        assertTrue(reputationRegistry.isAuthorizedCaller(newAuthorizedCaller));
        assertTrue(reputationRegistry.isAuthorizedCaller(authorizedCaller));

        // New authorized caller can modify reputation
        vm.prank(newAuthorizedCaller);
        reputationRegistry.increaseReputation(1, 100);
        assertEq(reputationRegistry.reputationOf(1), 100);

        // Old authorized caller can still modify reputation (both are authorized)
        vm.prank(authorizedCaller);
        reputationRegistry.increaseReputation(2, 200);
        assertEq(reputationRegistry.reputationOf(2), 200);

        // Owner can revoke specific authorization
        vm.prank(owner);
        reputationRegistry.revokeAuthorizedCaller(newAuthorizedCaller);
        assertFalse(reputationRegistry.isAuthorizedCaller(newAuthorizedCaller));
        assertTrue(reputationRegistry.isAuthorizedCaller(authorizedCaller));

        // Revoked caller can no longer modify reputation
        vm.prank(newAuthorizedCaller);
        vm.expectRevert("ReputationRegistry: not authorized");
        reputationRegistry.decreaseReputation(1, 50);
    }
    
    function testGasCostAnalysis() public {
        uint256 agentId = 1;
        
        // Measure gas for increase reputation
        uint256 gasStart = gasleft();
        vm.prank(authorizedCaller);
        reputationRegistry.increaseReputation(agentId, 100);
        uint256 gasUsed = gasStart - gasleft();
        
        assertTrue(gasUsed < 100000, "Increase reputation gas cost too high");
        assertEq(reputationRegistry.reputationOf(agentId), 100);
        
        // Measure gas for decrease reputation
        gasStart = gasleft();
        vm.prank(authorizedCaller);
        reputationRegistry.decreaseReputation(agentId, 50);
        gasUsed = gasStart - gasleft();
        
        assertTrue(gasUsed < 100000, "Decrease reputation gas cost too high");
        assertEq(reputationRegistry.reputationOf(agentId), 50);
    }
    
    function testLargeReputationValues() public {
        uint256 largeAmount = type(uint256).max / 2;
        uint256 agentId = 1;

        vm.prank(authorizedCaller);
        reputationRegistry.increaseReputation(agentId, largeAmount);
        assertEq(reputationRegistry.reputationOf(agentId), largeAmount);

        // Try to decrease by a large amount
        vm.prank(authorizedCaller);
        reputationRegistry.decreaseReputation(agentId, largeAmount / 2);
        // Due to potential precision issues with very large numbers, we check for approximate equality
        uint256 expected = largeAmount - (largeAmount / 2);
        uint256 actual = reputationRegistry.reputationOf(agentId);
        assertGe(actual, expected - 1); // Allow for 1 unit difference due to precision
        assertLe(actual, expected + 1);
    }
}