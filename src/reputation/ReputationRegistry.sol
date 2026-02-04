// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title ReputationRegistry
 * @dev Registry for managing agent reputations with Proof-of-Work integration
 */
contract ReputationRegistry {
    mapping(uint256 => uint256) private _reputations;
    mapping(address => bool) private _authorizedCallers;

    address public owner;

    event ReputationIncreased(uint256 indexed agentId, uint256 amount);
    event ReputationDecreased(uint256 indexed agentId, uint256 amount);
    event AuthorizedCallerSet(address indexed caller, bool authorized);
    event WorkPerformed(uint256 indexed agentId, uint256 workType, uint256 reward);

    modifier onlyOwner() {
        require(msg.sender == owner, "ReputationRegistry: not owner");
        _;
    }

    modifier onlyAuthorizedCaller() {
        require(_authorizedCallers[msg.sender], "ReputationRegistry: not authorized");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Sets an address as an authorized caller
     * @param caller The address to authorize
     */
    function setAuthorizedCaller(address caller) external onlyOwner {
        _authorizedCallers[caller] = true;
        emit AuthorizedCallerSet(caller, true);
    }

    /**
     * @dev Revokes authorization from an address
     * @param caller The address to revoke authorization from
     */
    function revokeAuthorizedCaller(address caller) external onlyOwner {
        _authorizedCallers[caller] = false;
        emit AuthorizedCallerSet(caller, false);
    }

    /**
     * @dev Increases the reputation of an agent
     * @param agentId The ID of the agent
     * @param amount The amount to increase reputation by
     */
    function increaseReputation(uint256 agentId, uint256 amount) external onlyAuthorizedCaller {
        _reputations[agentId] += amount;
        emit ReputationIncreased(agentId, amount);
    }

    /**
     * @dev Increases reputation through Proof-of-Work
     * @param agentId The ID of the agent performing work
     * @param workType Type of work performed (0=submission, 1=validation, 2=liquidity, etc.)
     * @param workDifficulty Difficulty factor of the work performed
     */
    function performWork(uint256 agentId, uint256 workType, uint256 workDifficulty) external onlyAuthorizedCaller {
        // Calculate reputation reward based on work type and difficulty
        uint256 reward = calculateWorkReward(workType, workDifficulty);
        _reputations[agentId] += reward;

        emit ReputationIncreased(agentId, reward);
        emit WorkPerformed(agentId, workType, reward);
    }

    /**
     * @dev Calculates reputation reward based on work type and difficulty
     * @param workType Type of work performed
     * @param workDifficulty Difficulty factor of the work
     * @return reward Calculated reputation reward
     */
    function calculateWorkReward(uint256 workType, uint256 workDifficulty) public pure returns (uint256 reward) {
        // Different work types have different base rewards
        uint256 baseReward;
        if (workType == 0) { // Submission work
            baseReward = 10;
        } else if (workType == 1) { // Validation work
            baseReward = 15;
        } else if (workType == 2) { // Liquidity provision
            baseReward = 20;
        } else { // Other work types
            baseReward = 5;
        }

        // Apply difficulty multiplier
        reward = baseReward * workDifficulty;
    }

    /**
     * @dev Decreases the reputation of an agent
     * @param agentId The ID of the agent
     * @param amount The amount to decrease reputation by
     */
    function decreaseReputation(uint256 agentId, uint256 amount) external onlyAuthorizedCaller {
        uint256 currentReputation = _reputations[agentId];
        if (amount >= currentReputation) {
            _reputations[agentId] = 0;
        } else {
            _reputations[agentId] = currentReputation - amount;
        }
        emit ReputationDecreased(agentId, amount);
    }

    /**
     * @dev Gets the reputation of an agent
     * @param agentId The ID of the agent
     * @return The reputation of the agent
     */
    function reputationOf(uint256 agentId) external view returns (uint256) {
        return _reputations[agentId];
    }

    /**
     * @dev Checks if an address is authorized to modify reputation
     * @param caller The address to check
     * @return Whether the address is authorized
     */
    function isAuthorizedCaller(address caller) external view returns (bool) {
        return _authorizedCallers[caller];
    }

    /**
     * @dev Checks if an agent has sufficient reputation to participate in validation
     * @param agentId The ID of the agent
     * @return Whether the agent has sufficient reputation
     */
    function hasSufficientReputation(uint256 agentId) external view returns (bool) {
        return _reputations[agentId] > 0; // Require at least minimal reputation
    }
}