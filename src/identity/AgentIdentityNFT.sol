// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title AgentIdentityNFT
 * @dev ERC-8004 compliant NFT contract for agent identities
 */
contract AgentIdentityNFT is ERC721 {
    using Counters for Counters.Counter;
    
    Counters.Counter private _tokenIdCounter;
    
    mapping(uint256 => address) private _tokenCreators;
    
    event AgentMinted(uint256 indexed agentId, address indexed owner);
    
    constructor() ERC721("AgentIdentityNFT", "AGENT") {}
    
    /**
     * @dev Mints a new agent NFT
     * @param _owner The address that will own the NFT
     * @return agentId The ID of the newly minted agent
     */
    function mint(address _owner) external returns (uint256 agentId) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        _safeMint(_owner, tokenId);
        _tokenCreators[tokenId] = msg.sender;
        
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
}