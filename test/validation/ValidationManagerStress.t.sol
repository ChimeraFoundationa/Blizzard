// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../../src/validation/ValidationManager.sol";
import "../../src/validation/ValidatorRegistry.sol";
import "../../src/reputation/ReputationRegistry.sol";

contract ValidationManagerStressTest is Test {
    ValidationManager validationManager;
    ValidatorRegistry validatorRegistry;
    ReputationRegistry reputationRegistry;
    
    address owner = address(0x1);
    address[] validators;
    uint256 numValidators = 100;
    
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

        // Initialize validators
        validators = new address[](numValidators);
        for (uint256 i = 0; i < numValidators; i++) {
            validators[i] = address(uint160(0x2000 + i));
            vm.deal(validators[i], 5 ether);

            vm.prank(validators[i]);
            validatorRegistry.registerValidator{value: 1 ether}();
        }
    }
    
    function testStressManySubmissions() public {
        uint256 numSubmissions = 1000;
        
        // Have validators submit in round-robin fashion
        for (uint256 i = 0; i < numSubmissions; i++) {
            address currentValidator = validators[i % numValidators];
            
            vm.prank(currentValidator);
            uint256 submissionId = validationManager.submit();
            
            (uint256 agentId, address submittedBy, uint256 submissionTime, bool finalized, bool challenged) = 
                validationManager.submissions(submissionId);
                
            assertEq(submittedBy, currentValidator);
            assertEq(agentId, submissionId); // AgentId matches submissionId in this implementation
            assertTrue(submissionTime > 0);
            assertFalse(finalized);
            assertFalse(challenged);
        }
        
        // Verify all submissions were recorded
        for (uint256 i = 0; i < numSubmissions; i++) {
            (, address submittedBy, , bool finalized, bool challenged) = 
                validationManager.submissions(i);
                
            address expectedValidator = validators[i % numValidators];
            assertEq(submittedBy, expectedValidator);
            assertFalse(finalized);
            assertFalse(challenged);
        }
    }
    
    function testStressChallengeAndFinalize() public {
        uint256 numSubmissions = 100;
        uint256[] memory submissionIds = new uint256[](numSubmissions);
        
        // Submit many validations
        for (uint256 i = 0; i < numSubmissions; i++) {
            address currentValidator = validators[i % numValidators];
            
            vm.prank(currentValidator);
            submissionIds[i] = validationManager.submit();
        }
        
        // Challenge half of them
        for (uint256 i = 0; i < numSubmissions / 2; i++) {
            vm.prank(address(0x999)); // Challenger
            validationManager.challenge(submissionIds[i]);
            
            (, , , bool finalized, bool challenged) = validationManager.submissions(submissionIds[i]);
            assertTrue(challenged);
            assertFalse(finalized);
        }
        
        // Skip time to allow finalization
        vm.warp(block.timestamp + 2 days);
        
        // Finalize the non-challenged ones
        for (uint256 i = numSubmissions / 2; i < numSubmissions; i++) {
            vm.prank(address(0x999)); // Anyone can finalize after challenge period
            validationManager.finalize(submissionIds[i]);
            
            (, , , bool finalized, bool challenged) = validationManager.submissions(submissionIds[i]);
            assertTrue(finalized);
            assertFalse(challenged);
        }
        
        // Verify challenged submissions cannot be finalized
        for (uint256 i = 0; i < numSubmissions / 2; i++) {
            vm.prank(address(0x999));
            vm.expectRevert("ValidationManager: submission was challenged");
            validationManager.finalize(submissionIds[i]);
        }
    }
    
    function testSybilAttackValidationSubmission() public {
        address sybilActor = address(0x999);
        vm.deal(sybilActor, 50 ether); // More funds for multiple registrations

        // Sybil actor registers as validator
        vm.prank(sybilActor);
        validatorRegistry.registerValidator{value: 1 ether}();

        // Sybil actor submits one validation
        vm.prank(sybilActor);
        uint256 submissionId = validationManager.submit();

        (, address submittedBy, , bool finalized, bool challenged) =
            validationManager.submissions(submissionId);

        assertEq(submittedBy, sybilActor);
        assertFalse(finalized);
        assertFalse(challenged);

        // Challenge the submission
        vm.prank(address(0x888)); // Another user challenges
        validationManager.challenge(submissionId);

        // Verify validator was slashed
        assertEq(validatorRegistry.stakeOf(sybilActor), 0);
        assertFalse(validatorRegistry.isActiveValidator(sybilActor));

        // Try to submit again (should fail)
        vm.prank(sybilActor);
        vm.expectRevert("ValidationManager: not an active validator");
        validationManager.submit();
    }
    
    function testEdgeCaseEarlyFinalize() public {
        vm.prank(validators[0]);
        uint256 submissionId = validationManager.submit();
        
        // Try to finalize before challenge period (should fail)
        vm.prank(address(0x999));
        vm.expectRevert("ValidationManager: challenge period not over");
        validationManager.finalize(submissionId);
        
        // Verify submission is not finalized
        (, , , bool finalized, bool challenged) = validationManager.submissions(submissionId);
        assertFalse(finalized);
        assertFalse(challenged);
    }
    
    function testEdgeCaseLateChallenge() public {
        vm.prank(validators[0]);
        uint256 submissionId = validationManager.submit();
        
        // Skip time past challenge period
        vm.warp(block.timestamp + 2 days);
        
        // Try to challenge after challenge period (should fail)
        vm.prank(address(0x999));
        vm.expectRevert("ValidationManager: challenge period expired");
        validationManager.challenge(submissionId);
        
        // Verify submission is not challenged
        (, , , bool finalized, bool challenged) = validationManager.submissions(submissionId);
        assertFalse(finalized);
        assertFalse(challenged);
    }
    
    function testEdgeCaseDuplicateChallenge() public {
        vm.prank(validators[0]);
        uint256 submissionId = validationManager.submit();
        
        // Challenge once
        vm.prank(address(0x999));
        validationManager.challenge(submissionId);
        
        // Try to challenge again (should fail)
        vm.prank(address(0x888)); // Different challenger
        vm.expectRevert("ValidationManager: submission already challenged");
        validationManager.challenge(submissionId);
        
        // Verify submission is challenged
        (, , , bool finalized, bool challenged) = validationManager.submissions(submissionId);
        assertFalse(finalized);
        assertTrue(challenged);
    }
    
    function testFuzzSubmissionTiming(address validator, uint256 delay) public {
        vm.assume(validator != address(0) && validator != owner);
        vm.assume(delay < 100 days); // Reasonable delay
        
        // Register validator if not already registered
        if (!validatorRegistry.isActiveValidator(validator)) {
            vm.deal(validator, 5 ether);
            vm.prank(validator);
            validatorRegistry.registerValidator{value: 1 ether}();
        }
        
        vm.prank(validator);
        uint256 submissionId = validationManager.submit();
        
        // Warp time by fuzzed delay
        vm.warp(block.timestamp + delay);
        
        // Check if submission can be challenged based on timing
        bool canBeChallenged = validationManager.canBeChallenged(submissionId);
        bool canBeFinalized = validationManager.canBeFinalized(submissionId);
        
        (, , uint256 submissionTime, , ) = validationManager.submissions(submissionId);
        bool withinChallengePeriod = block.timestamp < submissionTime + 1 days;
        bool afterChallengePeriod = block.timestamp >= submissionTime + 1 days;

        (, , , , bool challenged) = validationManager.submissions(submissionId);
        assertEq(canBeChallenged, withinChallengePeriod);
        assertEq(canBeFinalized, afterChallengePeriod && !challenged);
    }
    
    function testFuzzReputationRewards(uint256 numSuccessfulSubmissions) public {
        vm.assume(numSuccessfulSubmissions > 0 && numSuccessfulSubmissions <= 50);
        
        uint256[] memory submissionIds = new uint256[](numSuccessfulSubmissions);
        
        // Submit validations
        for (uint256 i = 0; i < numSuccessfulSubmissions; i++) {
            address currentValidator = validators[i % numValidators];
            
            vm.prank(currentValidator);
            submissionIds[i] = validationManager.submit();
        }
        
        // Skip time to allow finalization
        vm.warp(block.timestamp + 2 days);
        
        // Finalize all submissions
        for (uint256 i = 0; i < numSuccessfulSubmissions; i++) {
            vm.prank(address(0x999)); // Anyone can finalize
            validationManager.finalize(submissionIds[i]);
        }
        
        // Verify reputation rewards (each successful submission gives 10 reputation)
        // Note: AgentId corresponds to submissionId in our implementation
        for (uint256 i = 0; i < numSuccessfulSubmissions; i++) {
            uint256 expectedReputation = 10; // 10 points per successful validation
            assertEq(reputationRegistry.reputationOf(i), expectedReputation);
        }
    }
    
    function testValidatorSlashingImpact() public {
        address validator = validators[0];
        
        // Submit a validation
        vm.prank(validator);
        uint256 submissionId = validationManager.submit();
        
        // Challenge the submission (this should slash the validator)
        vm.prank(address(0x999));
        validationManager.challenge(submissionId);
        
        // Verify validator was slashed
        assertEq(validatorRegistry.stakeOf(validator), 0);
        assertFalse(validatorRegistry.isActiveValidator(validator));
        
        // Try to submit again (should fail)
        vm.prank(validator);
        vm.expectRevert("ValidationManager: not an active validator");
        validationManager.submit();
    }
    
    function testGasCostAnalysis() public {
        address validator = address(0x8888);
        vm.deal(validator, 5 ether);

        vm.prank(validator);
        validatorRegistry.registerValidator{value: 1 ether}();

        // Measure gas for submission
        uint256 gasStart = gasleft();
        vm.prank(validator);
        uint256 submissionId = validationManager.submit();
        uint256 gasUsed = gasStart - gasleft();

        assertTrue(gasUsed < 300000, "Submission gas cost too high");

        // Measure gas for challenge
        gasStart = gasleft();
        vm.prank(address(0x999));
        validationManager.challenge(submissionId);
        gasUsed = gasStart - gasleft();

        assertTrue(gasUsed < 300000, "Challenge gas cost too high");

        // Register a new validator since the previous one was slashed
        address validator2 = address(0x8889);
        vm.deal(validator2, 5 ether);

        vm.prank(validator2);
        validatorRegistry.registerValidator{value: 1 ether}();

        vm.prank(validator2);
        uint256 submissionId2 = validationManager.submit();

        // Skip time and measure gas for finalize on a different submission
        vm.warp(block.timestamp + 2 days);

        // Now finalize the new submission (not the challenged one)
        gasStart = gasleft();
        vm.prank(address(0x999));
        validationManager.finalize(submissionId2);
        gasUsed = gasStart - gasleft();

        assertTrue(gasUsed < 300000, "Finalize gas cost too high");
    }
    
    function testConcurrentSubmissions() public {
        // Submit multiple validations from different validators simultaneously
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(validators[i]);
            validationManager.submit();
        }
        
        // Verify all submissions exist
        for (uint256 i = 0; i < 10; i++) {
            (, address submittedBy, , bool finalized, bool challenged) = validationManager.submissions(i);
            assertEq(submittedBy, validators[i]);
            assertFalse(finalized);
            assertFalse(challenged);
        }
        
        // Challenge some of them
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(address(0x999));
            validationManager.challenge(i);
        }
        
        // Skip time and finalize the rest
        vm.warp(block.timestamp + 2 days);
        
        for (uint256 i = 5; i < 10; i++) {
            vm.prank(address(0x999));
            validationManager.finalize(i);
        }
        
        // Verify outcomes
        for (uint256 i = 0; i < 5; i++) {
            (, , , bool finalized, bool challenged) = validationManager.submissions(i);
            assertFalse(finalized);
            assertTrue(challenged);
        }
        
        for (uint256 i = 5; i < 10; i++) {
            (, , , bool finalized, bool challenged) = validationManager.submissions(i);
            assertTrue(finalized);
            assertFalse(challenged);
        }
    }
}