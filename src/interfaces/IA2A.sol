// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title A2AInterface
 * @dev Interface for Agent-to-Agent communication protocol
 */
interface IA2A {
    /**
     * @dev Sends a message from one agent to another off-chain
     * @param fromAgentId The ID of the sending agent
     * @param toAgentId The ID of the receiving agent
     * @param messageData Encoded message data
     * @return success Whether the message was sent successfully
     */
    function sendMessage(uint256 fromAgentId, uint256 toAgentId, bytes calldata messageData) external returns (bool success);

    /**
     * @dev Registers an agent for A2A communication
     * @param agentId The ID of the agent to register
     * @param communicationEndpoint Endpoint for off-chain communication
     */
    function registerAgent(uint256 agentId, string calldata communicationEndpoint) external;

    /**
     * @dev Gets the communication endpoint for an agent
     * @param agentId The ID of the agent
     * @return endpoint The communication endpoint for the agent
     */
    function getAgentEndpoint(uint256 agentId) external view returns (string memory endpoint);

    /**
     * @dev Verifies if an agent is registered for A2A communication
     * @param agentId The ID of the agent to check
     * @return isRegistered Whether the agent is registered
     */
    function isAgentRegistered(uint256 agentId) external view returns (bool isRegistered);
}