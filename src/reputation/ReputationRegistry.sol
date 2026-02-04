// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title ReputationRegistry
 * @dev Registry for managing agent reputations
 */
contract ReputationRegistry {
    mapping(uint256 => uint256) private _reputations;
    mapping(address => bool) private _authorizedCallers;
    
    address public owner;
    
    event ReputationIncreased(uint256 indexed agentId, uint256 amount);
    event ReputationDecreased(uint256 indexed agentId, uint256 amount);
    event AuthorizedCallerSet(address indexed caller, bool authorized);
    
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
}