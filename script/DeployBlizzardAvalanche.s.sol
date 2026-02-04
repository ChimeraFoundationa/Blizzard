// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {AgentIdentityNFT} from "../src/identity/AgentIdentityNFT.sol";
import {ReputationRegistry} from "../src/reputation/ReputationRegistry.sol";
import {ValidatorRegistry} from "../src/validation/ValidatorRegistry.sol";
import {ValidationManager} from "../src/validation/ValidationManager.sol";

/*
 * Deploy script specifically for Avalanche C-Chain
 * This script deploys all Blizzard contracts with proper initialization
 */
contract DeployBlizzardAvalanche is Script {
    AgentIdentityNFT public agentIdentityNFT;
    ReputationRegistry public reputationRegistry;
    ValidatorRegistry public validatorRegistry;
    ValidationManager public validationManager;

    function run() public {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        // Deploy Agent Identity NFT contract (ERC-8004 compliant)
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

        // Configure the contracts for proper operation
        // Set ValidationManager as authorized caller for ReputationRegistry
        reputationRegistry.setAuthorizedCaller(address(validationManager));
        console.log("ValidationManager authorized for ReputationRegistry");

        // Set ValidationManager in ValidatorRegistry
        validatorRegistry.setValidationManager(address(validationManager));
        console.log("ValidationManager set in ValidatorRegistry");

        vm.stopBroadcast();

        // Log deployment addresses for verification
        console.log("=== Blizzard Deployment on Avalanche Complete ===");
        console.log("Network: Avalanche C-Chain");
        console.log("AgentIdentityNFT:", address(agentIdentityNFT));
        console.log("ReputationRegistry:", address(reputationRegistry));
        console.log("ValidatorRegistry:", address(validatorRegistry));
        console.log("ValidationManager:", address(validationManager));

        // Save addresses to a file for later reference
        string memory addresses = string.concat(
            "AgentIdentityNFT=", vm.toString(address(agentIdentityNFT)), "\n",
            "ReputationRegistry=", vm.toString(address(reputationRegistry)), "\n",
            "ValidatorRegistry=", vm.toString(address(validatorRegistry)), "\n",
            "ValidationManager=", vm.toString(address(validationManager)), "\n"
        );
        
        vm.writeFile("broadcast/avalanche_addresses.txt", addresses);
    }
}