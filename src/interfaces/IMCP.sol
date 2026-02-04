// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title MCPInterface
 * @dev Interface for Managed Communication Protocol (X402) wallet integration
 */
interface IMCP {
    /**
     * @dev Executes an agent task on-chain
     * @param agentId The ID of the agent to execute the task for
     * @param taskData Encoded data for the task to be executed
     * @return success Whether the task was executed successfully
     */
    function executeAgentTask(uint256 agentId, bytes calldata taskData) external returns (bool success);

    /**
     * @dev Verifies if an address is a valid X402 wallet
     * @param wallet The address to verify
     * @return isValid Whether the address is a valid X402 wallet
     */
    function isValidX402Wallet(address wallet) external view returns (bool isValid);

    /**
     * @dev Registers an agent for MCP services
     * @param agentId The ID of the agent to register
     * @param serviceData Additional service configuration data
     */
    function registerAgentService(uint256 agentId, bytes calldata serviceData) external;
}