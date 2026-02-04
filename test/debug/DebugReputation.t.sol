// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../src/validation/ValidationManager.sol";
import "../../src/validation/ValidatorRegistry.sol";
import "../../src/reputation/ReputationRegistry.sol";

contract DebugTest is Test {
    ValidationManager validationManager;
    ValidatorRegistry validatorRegistry;
    ReputationRegistry reputationRegistry;

    address owner = address(0x1);
    address validator1 = address(0x2);

    function setUp() public {
        reputationRegistry = new ReputationRegistry();
        validatorRegistry = new ValidatorRegistry();

        // Deploy validation manager
        validationManager = new ValidationManager(address(validatorRegistry), address(reputationRegistry));

        // Set up authorized caller for reputation registry
        vm.prank(address(this)); // Use test contract as owner
        reputationRegistry.setAuthorizedCaller(address(validationManager));

        // Also allow the owner to set authorized callers for test setup
        vm.prank(address(this)); // Use test contract as owner
        reputationRegistry.setAuthorizedCaller(owner);

        // Set validation manager in validator registry
        vm.prank(address(this)); // Use test contract as owner
        validatorRegistry.setValidationManager(address(validationManager));
        
        // Set reputation registry in validator registry
        vm.prank(address(this)); // Use test contract as owner
        validatorRegistry.setReputationRegistry(address(reputationRegistry));
    }

    function testDebugReputationSetup() public {
        vm.deal(validator1, 5 ether);

        // Calculate agent ID the same way validator registry does
        uint256 validatorAgentId = validatorRegistry.getAgentIdForValidator(validator1);
        console.log("Validator Agent ID:", validatorAgentId);

        // Check reputation before setting
        uint256 repBefore = reputationRegistry.reputationOf(validatorAgentId);
        console.log("Reputation before:", repBefore);

        // Set reputation for the validator
        vm.prank(owner);
        reputationRegistry.increaseReputation(validatorAgentId, 15); // Above default threshold of 10

        // Check that reputation was set correctly
        uint256 repAfter = reputationRegistry.reputationOf(validatorAgentId);
        console.log("Reputation after:", repAfter);
        assertEq(repAfter, 15);

        // Check that reputation registry is properly set in validator registry
        address repRegInValidator = address(validatorRegistry.reputationRegistry());
        console.log("Reputation registry in validator registry:", repRegInValidator);
        console.log("Our reputation registry:", address(reputationRegistry));
        assertEq(repRegInValidator, address(reputationRegistry));

        // Check if validator registry has reputation check enabled
        // Try to register validator - this should work now
        vm.prank(validator1);
        validatorRegistry.registerValidator{value: 1 ether}();

        // Verify validator is active
        assertTrue(validatorRegistry.isActiveValidator(validator1));
    }
}