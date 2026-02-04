// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../interfaces/IMCP.sol";

/**
 * @title AgentIdentityNFT
 * @dev ERC-8004 compliant NFT contract for agent identities with MCP integration
 */
contract AgentIdentityNFT is ERC721 {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    mapping(uint256 => address) private _tokenCreators;
    mapping(uint256 => uint256) private _reputationScores; // Base/null reputation at creation

    // MCP integration
    IMCP public mcpContract;

    event AgentMinted(uint256 indexed agentId, address indexed owner);
    event MCPContractSet(address indexed mcpContract);

    constructor() ERC721("AgentIdentityNFT", "AGENT") {
        // Initialize with base/null reputation
    }

    /**
     * @dev Sets the MCP contract for X402 wallet integration
     * @param _mcpContract Address of the MCP contract
     */
    function setMCPContract(address _mcpContract) external {
        require(msg.sender == owner(), "AgentIdentityNFT: only owner can set MCP contract");
        mcpContract = IMCP(_mcpContract);
        emit MCPContractSet(_mcpContract);
    }

    /**
     * @dev Mints a new agent NFT with base/null reputation
     * @param _owner The address that will own the NFT
     * @return agentId The ID of the newly minted agent
     */
    function mint(address _owner) external returns (uint256 agentId) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        _safeMint(_owner, tokenId);
        _tokenCreators[tokenId] = msg.sender;

        // Initialize with base/null reputation (0 by default)
        _reputationScores[tokenId] = 0;

        emit AgentMinted(tokenId, _owner);

        return tokenId;
    }

    /**
     * @dev Checks if an agent ID exists
     * @param agentId The ID of the agent to check
     * @return bool Whether the agent exists
     */
    function exists(uint256 agentId) external view returns (bool) {
        return _exists(agentId);
    }

    /**
     * @dev Gets the owner of an agent
     * @param agentId The ID of the agent
     * @return address The owner of the agent
     */
    function ownerOf(uint256 agentId) public view override returns (address) {
        require(_exists(agentId), "AgentIdentityNFT: agent does not exist");
        return super.ownerOf(agentId);
    }

    /**
     * @dev Returns the creator of a token
     * @param agentId The ID of the agent
     * @return address The creator of the token
     */
    function tokenCreator(uint256 agentId) external view returns (address) {
        require(_exists(agentId), "AgentIdentityNFT: agent does not exist");
        return _tokenCreators[agentId];
    }

    /**
     * @dev Returns the reputation score of an agent (base/null at creation)
     * @param agentId The ID of the agent
     * @return The reputation score of the agent
     */
    function reputationOf(uint256 agentId) external view returns (uint256) {
        require(_exists(agentId), "AgentIdentityNFT: agent does not exist");
        return _reputationScores[agentId];
    }

    /**
     * @dev Returns the contract owner (needed for access control)
     */
    function owner() public view virtual returns (address) {
        return _msgSender();
    }
}