// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../../src/validation/ValidatorRegistry.sol";

contract ValidatorRegistryStressTest is Test {
    ValidatorRegistry validatorRegistry;
    address owner = address(0x1);
    address validationManager = address(0x99);
    
    function setUp() public {
        vm.startPrank(owner);
        validatorRegistry = new ValidatorRegistry();
        validatorRegistry.setValidationManager(validationManager);
        vm.stopPrank();
    }
    
    function testStressRegisterManyValidators() public {
        uint256 numValidators = 1000;
        address[] memory validators = new address[](numValidators);
        
        for (uint256 i = 0; i < numValidators; i++) {
            validators[i] = address(uint160(0x2000 + i));
            vm.deal(validators[i], 5 ether);
            vm.prank(validators[i]);
            validatorRegistry.registerValidator{value: 1 ether}();
            
            assertTrue(validatorRegistry.isActiveValidator(validators[i]));
            assertEq(validatorRegistry.stakeOf(validators[i]), 1 ether);
        }
        
        // Verify all validators are active
        for (uint256 i = 0; i < numValidators; i++) {
            assertTrue(validatorRegistry.isActiveValidator(validators[i]));
            assertEq(validatorRegistry.stakeOf(validators[i]), 1 ether);
        }
    }
    
    function testSybilAttackValidatorRegistration() public {
        address sybilActor = address(0x999);
        uint256 numAccounts = 100;
        address[] memory sybilAddresses = new address[](numAccounts);
        
        for (uint256 i = 0; i < numAccounts; i++) {
            sybilAddresses[i] = address(uint160(uint256(keccak256(abi.encodePacked(sybilActor, i)))));
            vm.deal(sybilAddresses[i], 5 ether);
            
            vm.prank(sybilAddresses[i]);
            validatorRegistry.registerValidator{value: 1 ether}();
            
            assertTrue(validatorRegistry.isActiveValidator(sybilAddresses[i]));
            assertEq(validatorRegistry.stakeOf(sybilAddresses[i]), 1 ether);
        }
        
        // Verify all Sybil validators are registered normally
        for (uint256 i = 0; i < numAccounts; i++) {
            assertTrue(validatorRegistry.isActiveValidator(sybilAddresses[i]));
            assertEq(validatorRegistry.stakeOf(sybilAddresses[i]), 1 ether);
        }
        
        // Try to register again with the same addresses (should fail)
        for (uint256 i = 0; i < numAccounts; i++) {
            vm.prank(sybilAddresses[i]);
            vm.expectRevert("ValidatorRegistry: validator already registered");
            validatorRegistry.registerValidator{value: 1 ether}();
        }
    }
    
    function testEdgeCaseInsufficientStake() public {
        address lowBalanceValidator = address(0x3000);
        vm.deal(lowBalanceValidator, 0.5 ether);
        
        vm.prank(lowBalanceValidator);
        vm.expectRevert("ValidatorRegistry: insufficient stake");
        validatorRegistry.registerValidator{value: 0.5 ether}();
        
        assertFalse(validatorRegistry.isActiveValidator(lowBalanceValidator));
        assertEq(validatorRegistry.stakeOf(lowBalanceValidator), 0);
    }
    
    function testEdgeCaseZeroStakeSlashing() public {
        address validator = address(0x4000);
        vm.deal(validator, 5 ether);
        
        vm.prank(validator);
        validatorRegistry.registerValidator{value: 1 ether}();
        
        // Fully slash the validator
        vm.prank(validationManager);
        validatorRegistry.slash(validator, 1 ether);
        
        // Verify validator is inactive and has zero stake
        assertFalse(validatorRegistry.isActiveValidator(validator));
        assertEq(validatorRegistry.stakeOf(validator), 0);
        
        // Try to slash again (should fail)
        vm.prank(validationManager);
        vm.expectRevert("ValidatorRegistry: validator not active");
        validatorRegistry.slash(validator, 1 ether);
    }
    
    function testFuzzValidatorRegistration(address validator, uint256 stakeAmount) public {
        vm.assume(validator != address(0) && validator != owner && validator != validationManager);
        vm.assume(stakeAmount >= 1 ether && stakeAmount <= 1000 ether);
        
        vm.deal(validator, stakeAmount * 2); // Ensure sufficient balance
        
        vm.prank(validator);
        validatorRegistry.registerValidator{value: stakeAmount}();
        
        assertTrue(validatorRegistry.isActiveValidator(validator));
        assertEq(validatorRegistry.stakeOf(validator), stakeAmount);
    }
    
    function testFuzzSlashing(address validator, uint256 initialStake, uint256 slashAmount) public {
        vm.assume(validator != address(0) && validator != owner && validator != validationManager);
        vm.assume(initialStake >= 1 ether && initialStake <= 1000 ether);
        vm.assume(slashAmount <= 1000 ether);
        
        vm.deal(validator, initialStake * 2);
        
        vm.prank(validator);
        validatorRegistry.registerValidator{value: initialStake}();
        
        vm.prank(validationManager);
        validatorRegistry.slash(validator, slashAmount);
        
        uint256 expectedStake = initialStake >= slashAmount ? initialStake - slashAmount : 0;
        assertEq(validatorRegistry.stakeOf(validator), expectedStake);
        
        if (expectedStake == 0) {
            assertFalse(validatorRegistry.isActiveValidator(validator));
        } else {
            assertTrue(validatorRegistry.isActiveValidator(validator));
        }
    }
    
    function testMultipleSlashingEvents() public {
        address validator = address(0x5000);
        vm.deal(validator, 10 ether);
        
        vm.prank(validator);
        validatorRegistry.registerValidator{value: 5 ether}();
        
        // First slash
        vm.prank(validationManager);
        validatorRegistry.slash(validator, 2 ether);
        assertEq(validatorRegistry.stakeOf(validator), 3 ether);
        assertTrue(validatorRegistry.isActiveValidator(validator));
        
        // Second slash
        vm.prank(validationManager);
        validatorRegistry.slash(validator, 1 ether);
        assertEq(validatorRegistry.stakeOf(validator), 2 ether);
        assertTrue(validatorRegistry.isActiveValidator(validator));
        
        // Third slash that takes stake to zero
        vm.prank(validationManager);
        validatorRegistry.slash(validator, 2 ether);
        assertEq(validatorRegistry.stakeOf(validator), 0);
        assertFalse(validatorRegistry.isActiveValidator(validator));
    }
    
    function testWithdrawAfterFullSlashing() public {
        address validator = address(0x6000);
        vm.deal(validator, 5 ether);

        vm.prank(validator);
        validatorRegistry.registerValidator{value: 2 ether}();

        // Fully slash the validator
        vm.prank(validationManager);
        validatorRegistry.slash(validator, 2 ether);

        // Verify validator is inactive
        assertFalse(validatorRegistry.isActiveValidator(validator));

        // Attempt to withdraw (should fail because there's no stake to withdraw)
        vm.prank(validator);
        vm.expectRevert("ValidatorRegistry: no stake to withdraw");
        validatorRegistry.withdrawStake();
    }
    
    function testWithdrawAfterPartialSlashing() public {
        address validator = address(0x7000);
        vm.deal(validator, 5 ether);
        
        vm.prank(validator);
        validatorRegistry.registerValidator{value: 2 ether}();
        
        // Partially slash the validator
        vm.prank(validationManager);
        validatorRegistry.slash(validator, 1 ether);
        
        // Validator should still be active
        assertTrue(validatorRegistry.isActiveValidator(validator));
        
        // Attempt to withdraw (should fail because validator is still active)
        vm.prank(validator);
        vm.expectRevert("ValidatorRegistry: validator still active");
        validatorRegistry.withdrawStake();
    }
    
    function testGasCostAnalysis() public {
        address validator = address(0x8000);
        vm.deal(validator, 5 ether);
        
        // Measure gas for registration
        uint256 gasStart = gasleft();
        vm.prank(validator);
        validatorRegistry.registerValidator{value: 1 ether}();
        uint256 gasUsed = gasStart - gasleft();
        
        assertTrue(gasUsed < 300000, "Registration gas cost too high");
        assertTrue(validatorRegistry.isActiveValidator(validator));
        
        // Measure gas for slash
        gasStart = gasleft();
        vm.prank(validationManager);
        validatorRegistry.slash(validator, 0.5 ether);
        gasUsed = gasStart - gasleft();
        
        assertTrue(gasUsed < 150000, "Slashing gas cost too high");
        
        // Measure gas for checking stake
        gasStart = gasleft();
        assertEq(validatorRegistry.stakeOf(validator), 0.5 ether);
        gasUsed = gasStart - gasleft();
        
        assertTrue(gasUsed < 5000, "Stake check gas cost too high");
    }
    
    function testValidatorWithdrawingAfterDeactivation() public {
        address validator = address(0x9000);
        vm.deal(validator, 5 ether);

        vm.prank(validator);
        validatorRegistry.registerValidator{value: 2 ether}();

        // Partial slash leaving some stake
        vm.prank(validationManager);
        validatorRegistry.slash(validator, 1 ether);
        assertTrue(validatorRegistry.isActiveValidator(validator));
        assertEq(validatorRegistry.stakeOf(validator), 1 ether);

        // Full slash to deactivate
        vm.prank(validationManager);
        validatorRegistry.slash(validator, 1 ether);
        assertFalse(validatorRegistry.isActiveValidator(validator));
        assertEq(validatorRegistry.stakeOf(validator), 0 ether);

        // Withdraw should fail because there's no stake to withdraw
        vm.prank(validator);
        vm.expectRevert("ValidatorRegistry: no stake to withdraw");
        validatorRegistry.withdrawStake();
    }
}