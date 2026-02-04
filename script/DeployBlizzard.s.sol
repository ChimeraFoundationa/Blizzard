// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {AgentIdentityNFT} from "../src/identity/AgentIdentityNFT.sol";
import {ReputationRegistry} from "../src/reputation/ReputationRegistry.sol";
import {ValidatorRegistry} from "../src/validation/ValidatorRegistry.sol";
import {ValidationManager} from "../src/validation/ValidationManager.sol";

contract DeployBlizzard is Script {
    AgentIdentityNFT public agentIdentityNFT;
    ReputationRegistry public reputationRegistry;
    ValidatorRegistry public validatorRegistry;
    ValidationManager public validationManager;

    function run() public {
        vm.startBroadcast();

        // Deploy Agent Identity NFT contract
        agentIdentityNFT = new AgentIdentityNFT();
        console.log("AgentIdentityNFT deployed at:", address(agentIdentityNFT));

        // Deploy Reputation Registry contract
        reputationRegistry = new ReputationRegistry();
        console.log("ReputationRegistry deployed at:", address(reputationRegistry));

        // Deploy Validator Registry contract
        validatorRegistry = new ValidatorRegistry();
        console.log("ValidatorRegistry deployed at:", address(validatorRegistry));

        // Deploy Validation Manager contract
        validationManager = new ValidationManager(
            address(validatorRegistry),
            address(reputationRegistry)
        );
        console.log("ValidationManager deployed at:", address(validationManager));

        // Configure the contracts
        // Set ValidationManager as authorized caller for ReputationRegistry
        reputationRegistry.setAuthorizedCaller(address(validationManager));
        console.log("ValidationManager set as authorized caller for ReputationRegistry");

        // Set ValidationManager in ValidatorRegistry
        validatorRegistry.setValidationManager(address(validationManager));
        console.log("ValidationManager set in ValidatorRegistry");

        vm.stopBroadcast();

        // Log deployment addresses
        console.log("=== Blizzard Deployment Complete ===");
        console.log("AgentIdentityNFT:", address(agentIdentityNFT));
        console.log("ReputationRegistry:", address(reputationRegistry));
        console.log("ValidatorRegistry:", address(validatorRegistry));
        console.log("ValidationManager:", address(validationManager));
    }
}