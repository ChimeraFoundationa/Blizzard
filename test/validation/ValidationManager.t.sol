// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../../src/validation/ValidationManager.sol";
import "../../src/validation/ValidatorRegistry.sol";
import "../../src/reputation/ReputationRegistry.sol";

contract ValidationManagerTest is Test {
    ValidationManager validationManager;
    ValidatorRegistry validatorRegistry;
    ReputationRegistry reputationRegistry;
    
    address owner = address(0x1);
    address validator1 = address(0x2);
    address validator2 = address(0x3);
    address user = address(0x4);
    
    function setUp() public {
        vm.startPrank(owner);
        reputationRegistry = new ReputationRegistry();
        validatorRegistry = new ValidatorRegistry();

        // Deploy validation manager
        validationManager = new ValidationManager(address(validatorRegistry), address(reputationRegistry));

        // Set up authorized caller for reputation registry
        reputationRegistry.setAuthorizedCaller(address(validationManager));

        // Set validation manager in validator registry
        validatorRegistry.setValidationManager(address(validationManager));
        vm.stopPrank();
    }
    
    function testSubmit() public {
        // Register validator first
        vm.prank(validator1);
        vm.deal(validator1, 5 ether);
        validatorRegistry.registerValidator{value: 1 ether}();
        
        // Submit validation
        vm.prank(validator1);
        uint256 submissionId = validationManager.submit();
        
        (uint256 agentId, address submittedBy, uint256 submissionTime, bool finalized, bool challenged) = 
            validationManager.submissions(submissionId);
        
        assertEq(agentId, 0); // First submission gets agentId 0
        assertEq(submittedBy, validator1);
        assertEq(submissionTime, block.timestamp);
        assertFalse(finalized);
        assertFalse(challenged);
    }
    
    function testSubmitOnlyActiveValidator() public {
        vm.prank(user); // Not a validator
        vm.expectRevert("ValidationManager: not an active validator");
        validationManager.submit();
    }
    
    function testChallengeSubmission() public {
        // Register validator first
        vm.prank(validator1);
        vm.deal(validator1, 5 ether);
        validatorRegistry.registerValidator{value: 2 ether}();
        
        // Submit validation
        vm.prank(validator1);
        uint256 submissionId = validationManager.submit();
        
        // Challenge the submission
        vm.prank(user);
        validationManager.challenge(submissionId);
        
        (, , , bool finalized, bool challenged) = validationManager.submissions(submissionId);
        assertTrue(challenged);
        assertFalse(finalized);
        
        // Check that validator was slashed
        assertEq(validatorRegistry.stakeOf(validator1), 0);
        assertFalse(validatorRegistry.isActiveValidator(validator1));
    }
    
    function testChallengeSubmissionAfterPeriod() public {
        // Register validator first
        vm.prank(validator1);
        vm.deal(validator1, 5 ether);
        validatorRegistry.registerValidator{value: 2 ether}();
        
        // Submit validation
        vm.prank(validator1);
        uint256 submissionId = validationManager.submit();
        
        // Skip time past challenge period
        vm.warp(block.timestamp + 2 days);
        
        vm.prank(user);
        vm.expectRevert("ValidationManager: challenge period expired");
        validationManager.challenge(submissionId);
    }
    
    function testChallengeAlreadyChallenged() public {
        // Register validator first
        vm.prank(validator1);
        vm.deal(validator1, 5 ether);
        validatorRegistry.registerValidator{value: 2 ether}();
        
        // Submit validation
        vm.prank(validator1);
        uint256 submissionId = validationManager.submit();
        
        // Challenge the submission
        vm.prank(user);
        validationManager.challenge(submissionId);
        
        // Try to challenge again
        vm.prank(user);
        vm.expectRevert("ValidationManager: submission already challenged");
        validationManager.challenge(submissionId);
    }
    
    function testFinalizeSubmissionAfterPeriod() public {
        // Register validator first
        vm.prank(validator1);
        vm.deal(validator1, 5 ether);
        validatorRegistry.registerValidator{value: 2 ether}();
        
        // Submit validation
        vm.prank(validator1);
        uint256 submissionId = validationManager.submit();
        
        // Skip time past challenge period
        vm.warp(block.timestamp + 2 days);
        
        // Finalize the submission
        vm.prank(user); // Anyone can finalize after challenge period
        validationManager.finalize(submissionId);
        
        (, , , bool finalized, bool challenged) = validationManager.submissions(submissionId);
        assertTrue(finalized);
        assertFalse(challenged);
        
        // Check that validator got reputation
        assertEq(reputationRegistry.reputationOf(0), 10); // AgentId 0 gets 10 reputation
    }
    
    function testFinalizeSubmissionTooEarly() public {
        // Register validator first
        vm.prank(validator1);
        vm.deal(validator1, 5 ether);
        validatorRegistry.registerValidator{value: 2 ether}();
        
        // Submit validation
        vm.prank(validator1);
        uint256 submissionId = validationManager.submit();
        
        // Try to finalize before challenge period
        vm.prank(user);
        vm.expectRevert("ValidationManager: challenge period not over");
        validationManager.finalize(submissionId);
    }
    
    function testFinalizeChallengedSubmission() public {
        // Register validator first
        vm.prank(validator1);
        vm.deal(validator1, 5 ether);
        validatorRegistry.registerValidator{value: 2 ether}();
        
        // Submit validation
        vm.prank(validator1);
        uint256 submissionId = validationManager.submit();
        
        // Skip time past challenge period
        vm.warp(block.timestamp + 2 days);
        
        // Challenge the submission (even though it's after challenge period, this should fail)
        vm.prank(user);
        vm.expectRevert("ValidationManager: challenge period expired");
        validationManager.challenge(submissionId);
        
        // But if we challenge during the period and then try to finalize:
        vm.warp(block.timestamp - 1.5 days); // Back to during challenge period
        vm.prank(validator1);
        uint256 submissionId2 = validationManager.submit();
        
        vm.prank(user);
        validationManager.challenge(submissionId2);
        
        vm.warp(block.timestamp + 2 days); // Forward to after challenge period
        
        vm.prank(user);
        vm.expectRevert("ValidationManager: submission was challenged");
        validationManager.finalize(submissionId2);
    }
    
    function testCanBeChallenged() public {
        // Register validator first
        vm.prank(validator1);
        vm.deal(validator1, 5 ether);
        validatorRegistry.registerValidator{value: 2 ether}();
        
        // Submit validation
        vm.prank(validator1);
        uint256 submissionId = validationManager.submit();
        
        assertTrue(validationManager.canBeChallenged(submissionId));
        
        // Skip time past challenge period
        vm.warp(block.timestamp + 2 days);
        
        assertFalse(validationManager.canBeChallenged(submissionId));
    }
    
    function testCanBeFinalized() public {
        // Register validator first
        vm.prank(validator1);
        vm.deal(validator1, 5 ether);
        validatorRegistry.registerValidator{value: 2 ether}();
        
        // Submit validation
        vm.prank(validator1);
        uint256 submissionId = validationManager.submit();
        
        // Not yet finalizable (challenge period not over)
        assertFalse(validationManager.canBeFinalized(submissionId));
        
        // Skip time past challenge period
        vm.warp(block.timestamp + 2 days);
        
        assertTrue(validationManager.canBeFinalized(submissionId));
    }
    
    function testMultipleSubmissions() public {
        // Register validators
        vm.prank(validator1);
        vm.deal(validator1, 5 ether);
        validatorRegistry.registerValidator{value: 2 ether}();
        
        vm.startPrank(validator1);
        uint256 submissionId1 = validationManager.submit();
        uint256 submissionId2 = validationManager.submit();
        vm.stopPrank();
        
        assertEq(submissionId1, 0);
        assertEq(submissionId2, 1);
        
        // Check both submissions
        (uint256 agentId1, address validatorAddr1, , bool finalized1, bool challenged1) = 
            validationManager.submissions(submissionId1);
        (uint256 agentId2, address validatorAddr2, , bool finalized2, bool challenged2) = 
            validationManager.submissions(submissionId2);
        
        assertEq(agentId1, 0);
        assertEq(validatorAddr1, validator1);
        assertFalse(finalized1);
        assertFalse(challenged1);
        
        assertEq(agentId2, 1);
        assertEq(validatorAddr2, validator1);
        assertFalse(finalized2);
        assertFalse(challenged2);
    }
}