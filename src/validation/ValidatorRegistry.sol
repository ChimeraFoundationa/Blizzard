// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title ValidatorRegistry
 * @dev Registry for managing validators and their stakes
 */
contract ValidatorRegistry {
    struct Validator {
        address validator;
        uint256 stake;
        bool active;
    }

    mapping(address => Validator) public validators;
    address public validationManager;
    address public owner;

    uint256 public constant MINIMUM_STAKE = 1 ether;

    event ValidatorRegistered(address indexed validator, uint256 stake);
    event ValidatorSlashed(address indexed validator, uint256 amount);
    event ValidatorDeactivated(address indexed validator);
    event ValidationManagerSet(address indexed manager);

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
     * @dev Registers a validator with a minimum stake
     */
    function registerValidator() external payable {
        require(msg.value >= MINIMUM_STAKE, "ValidatorRegistry: insufficient stake");
        require(!validators[msg.sender].active, "ValidatorRegistry: validator already registered");
        
        validators[msg.sender] = Validator({
            validator: msg.sender,
            stake: msg.value,
            active: true
        });
        
        emit ValidatorRegistered(msg.sender, msg.value);
    }
    
    /**
     * @dev Checks if a validator is active
     * @param validator The address of the validator to check
     * @return Whether the validator is active
     */
    function isActiveValidator(address validator) external view returns (bool) {
        return validators[validator].active;
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
}