// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../../src/validation/ValidatorRegistry.sol";

contract ValidatorRegistryTest is Test {
    ValidatorRegistry validatorRegistry;
    address owner = address(0x1);
    address validationManager = address(0x99);
    address validator1 = address(0x2);
    address validator2 = address(0x3);
    address user = address(0x4);

    function setUp() public {
        vm.startPrank(owner);
        validatorRegistry = new ValidatorRegistry();
        validatorRegistry.setValidationManager(validationManager);
        vm.stopPrank();
    }
    
    function testRegisterValidator() public {
        vm.prank(validator1);
        vm.deal(validator1, 5 ether);
        validatorRegistry.registerValidator{value: 1 ether}();
        
        assertTrue(validatorRegistry.isActiveValidator(validator1));
        assertEq(validatorRegistry.stakeOf(validator1), 1 ether);
    }
    
    function testRegisterValidatorInsufficientStake() public {
        vm.prank(validator1);
        vm.deal(validator1, 0.5 ether);
        vm.expectRevert("ValidatorRegistry: insufficient stake");
        validatorRegistry.registerValidator{value: 0.5 ether}();
    }
    
    function testRegisterValidatorAlreadyRegistered() public {
        vm.startPrank(owner);
        ValidatorRegistry freshValidatorRegistry = new ValidatorRegistry();
        freshValidatorRegistry.setValidationManager(validationManager);
        vm.stopPrank();

        vm.prank(validator1);
        vm.deal(validator1, 5 ether);
        freshValidatorRegistry.registerValidator{value: 1 ether}();

        vm.prank(validator1);
        vm.expectRevert("ValidatorRegistry: validator already registered");
        freshValidatorRegistry.registerValidator{value: 1 ether}();
    }
    
    function testSlashValidator() public {
        vm.prank(validator1);
        vm.deal(validator1, 5 ether);
        validatorRegistry.registerValidator{value: 2 ether}();

        vm.prank(validationManager);
        validatorRegistry.slash(validator1, 1 ether);

        assertEq(validatorRegistry.stakeOf(validator1), 1 ether);
    }
    
    function testSlashValidatorFullStake() public {
        vm.prank(validator1);
        vm.deal(validator1, 5 ether);
        validatorRegistry.registerValidator{value: 2 ether}();

        vm.prank(validationManager);
        validatorRegistry.slash(validator1, 5 ether); // More than stake

        assertEq(validatorRegistry.stakeOf(validator1), 0);
        assertFalse(validatorRegistry.isActiveValidator(validator1));
    }
    
    function testSetValidationManager() public {
        // Create a new validator registry for this test to avoid conflicts
        vm.startPrank(owner);
        ValidatorRegistry newValidatorRegistry = new ValidatorRegistry();

        // Initially, validation manager is address(0), so owner can set it
        newValidatorRegistry.setValidationManager(validator1);

        // Now validator1 should be able to call slash
        vm.stopPrank();
        vm.prank(validator1);
        vm.deal(validator1, 5 ether);
        newValidatorRegistry.registerValidator{value: 2 ether}();

        vm.prank(validator1); // validator1 is now the validation manager
        newValidatorRegistry.slash(validator1, 1 ether);
        assertEq(newValidatorRegistry.stakeOf(validator1), 1 ether);
    }
    
    function testWithdrawStake() public {
        vm.startPrank(owner);
        ValidatorRegistry freshValidatorRegistry = new ValidatorRegistry();
        freshValidatorRegistry.setValidationManager(validationManager);
        vm.stopPrank();

        vm.prank(validator1);
        vm.deal(validator1, 5 ether);
        freshValidatorRegistry.registerValidator{value: 2 ether}();

        vm.prank(validationManager);
        freshValidatorRegistry.slash(validator1, 2 ether); // Full slash - validator becomes inactive with 0 stake

        // Attempting to withdraw should fail because there's no stake to withdraw
        vm.prank(validator1);
        vm.expectRevert("ValidatorRegistry: no stake to withdraw");
        freshValidatorRegistry.withdrawStake();
    }
    
    function testWithdrawStakePartial() public {
        vm.startPrank(owner);
        ValidatorRegistry freshValidatorRegistry = new ValidatorRegistry();
        freshValidatorRegistry.setValidationManager(validationManager);
        vm.stopPrank();

        vm.prank(validator1);
        vm.deal(validator1, 5 ether);
        freshValidatorRegistry.registerValidator{value: 2 ether}();

        vm.prank(validationManager);
        freshValidatorRegistry.slash(validator1, 1 ether); // Partial slash - validator still active with 1 ether stake

        // Attempting to withdraw should fail because validator is still active
        vm.prank(validator1);
        vm.expectRevert("ValidatorRegistry: validator still active");
        freshValidatorRegistry.withdrawStake();
    }
    
    function testOnlyValidationManagerCanSlash() public {
        vm.prank(validator1);
        vm.deal(validator1, 5 ether);
        validatorRegistry.registerValidator{value: 2 ether}();
        
        vm.prank(user); // Not validation manager
        vm.expectRevert("ValidatorRegistry: not validation manager");
        validatorRegistry.slash(validator1, 1 ether);
    }
    
    function testCannotSlashInactiveValidator() public {
        vm.prank(validator1);
        vm.deal(validator1, 5 ether);
        validatorRegistry.registerValidator{value: 2 ether}();

        vm.prank(validationManager);
        validatorRegistry.slash(validator1, 2 ether); // Full slash, makes validator inactive

        vm.prank(validationManager);
        vm.expectRevert("ValidatorRegistry: validator not active");
        validatorRegistry.slash(validator1, 1 ether);
    }
    
    function testStakeOfNonValidator() public {
        assertEq(validatorRegistry.stakeOf(user), 0);
    }
    
    function testIsActiveValidatorNonValidator() public {
        assertFalse(validatorRegistry.isActiveValidator(user));
    }
}