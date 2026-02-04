// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../reputation/ReputationRegistry.sol";

/**
 * @title ValidatorRegistry
 * @dev Registry for managing validators and their stakes with reputation integration
 */
contract ValidatorRegistry {
    struct Validator {
        address validator;
        uint256 stake;
        bool active;
        uint256 reputationThreshold; // Minimum reputation required to remain active
    }

    mapping(address => Validator) public validators;
    address public validationManager;
    address public owner;

    // Reference to reputation registry for validation
    ReputationRegistry public reputationRegistry;

    uint256 public constant MINIMUM_STAKE = 1 ether;
    uint256 public constant DEFAULT_REPUTATION_THRESHOLD = 10; // Minimum reputation to be a validator

    event ValidatorRegistered(address indexed validator, uint256 stake);
    event ValidatorSlashed(address indexed validator, uint256 amount);
    event ValidatorDeactivated(address indexed validator);
    event ValidationManagerSet(address indexed manager);
    event ReputationRegistrySet(address indexed reputationRegistry);
    event ReputationThresholdUpdated(address indexed validator, uint256 newThreshold);

    modifier onlyOwner() {
        require(msg.sender == owner, "ValidatorRegistry: not owner");
        _;
    }

    modifier onlyValidationManager() {
        require(msg.sender == validationManager, "ValidatorRegistry: not validation manager");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    modifier onlyActiveValidator() {
        require(
            validators[msg.sender].active && validators[msg.sender].validator == msg.sender,
            "ValidatorRegistry: not an active validator"
        );
        _;
    }

    /**
     * @dev Sets the reputation registry contract
     * @param _reputationRegistry Address of the reputation registry contract
     */
    function setReputationRegistry(address _reputationRegistry) external onlyOwner {
        reputationRegistry = ReputationRegistry(_reputationRegistry);
        emit ReputationRegistrySet(_reputationRegistry);
    }

    /**
     * @dev Registers a validator with a minimum stake and reputation check
     */
    function registerValidator() external payable {
        require(msg.value >= MINIMUM_STAKE, "ValidatorRegistry: insufficient stake");
        require(!validators[msg.sender].active, "ValidatorRegistry: validator already registered");

        // Check if validator has minimum reputation to register
        if (address(reputationRegistry) != address(0)) {
            uint256 validatorAgentId = getAgentIdForValidator(msg.sender);
            require(
                reputationRegistry.reputationOf(validatorAgentId) >= DEFAULT_REPUTATION_THRESHOLD,
                "ValidatorRegistry: insufficient reputation to register as validator"
            );
        }

        validators[msg.sender] = Validator({
            validator: msg.sender,
            stake: msg.value,
            active: true,
            reputationThreshold: DEFAULT_REPUTATION_THRESHOLD
        });

        emit ValidatorRegistered(msg.sender, msg.value);
    }

    /**
     * @dev Updates the reputation threshold for a validator
     * @param newThreshold The new minimum reputation threshold
     */
    function updateReputationThreshold(uint256 newThreshold) external onlyActiveValidator {
        validators[msg.sender].reputationThreshold = newThreshold;
        emit ReputationThresholdUpdated(msg.sender, newThreshold);
    }

    /**
     * @dev Checks if a validator is active and has sufficient reputation
     * @param validator The address of the validator to check
     * @return Whether the validator is active and has sufficient reputation
     */
    function isActiveValidator(address validator) external view returns (bool) {
        if (!validators[validator].active) {
            return false;
        }

        // If reputation registry is set, also check reputation
        if (address(reputationRegistry) != address(0)) {
            uint256 validatorAgentId = getAgentIdForValidator(validator);
            uint256 currentReputation = reputationRegistry.reputationOf(validatorAgentId);
            uint256 requiredReputation = validators[validator].reputationThreshold;

            return currentReputation >= requiredReputation;
        }

        return true; // If no reputation registry, just check if active
    }

    /**
     * @dev Gets the stake of a validator
     * @param validator The address of the validator
     * @return The stake of the validator
     */
    function stakeOf(address validator) external view returns (uint256) {
        return validators[validator].stake;
    }

    /**
     * @dev Gets the reputation threshold of a validator
     * @param validator The address of the validator
     * @return The reputation threshold of the validator
     */
    function reputationThresholdOf(address validator) external view returns (uint256) {
        return validators[validator].reputationThreshold;
    }

    /**
     * @dev Slashes a validator's stake
     * @param validator The address of the validator to slash
     * @param amount The amount to slash
     */
    function slash(address validator, uint256 amount) external onlyValidationManager {
        Validator storage v = validators[validator];
        require(v.active, "ValidatorRegistry: validator not active");

        uint256 slashAmount = amount > v.stake ? v.stake : amount;
        v.stake -= slashAmount;

        // If stake becomes zero, deactivate the validator
        if (v.stake == 0) {
            v.active = false;
            emit ValidatorDeactivated(validator);
        }

        emit ValidatorSlashed(validator, slashAmount);
    }

    /**
     * @dev Sets the validation manager address
     * @param manager The address of the validation manager
     */
    function setValidationManager(address manager) external onlyOwner {
        require(manager != address(0), "ValidatorRegistry: invalid manager address");

        validationManager = manager;
        emit ValidationManagerSet(manager);
    }

    /**
     * @dev Withdraw remaining stake for a deactivated validator
     */
    function withdrawStake() external {
        Validator storage v = validators[msg.sender];
        require(!v.active, "ValidatorRegistry: validator still active");
        require(v.stake > 0, "ValidatorRegistry: no stake to withdraw");

        uint256 amount = v.stake;
        v.stake = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "ValidatorRegistry: withdrawal failed");
    }

    /**
     * @dev Gets the agent ID associated with a validator
     * @param validator The address of the validator
     * @return The agent ID associated with the validator
     */
    function getAgentIdForValidator(address validator) public pure returns (uint256) {
        // Use a deterministic mapping from validator address to agent ID
        return uint256(keccak256(abi.encodePacked(validator))) % 1000000;
    }
}