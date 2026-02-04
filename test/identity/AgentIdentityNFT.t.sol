// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../../src/identity/AgentIdentityNFT.sol";

contract AgentIdentityNFTTest is Test {
    AgentIdentityNFT agentNFT;
    
    address owner = address(0x1);
    address user1 = address(0x2);
    address user2 = address(0x3);
    
    function setUp() public {
        agentNFT = new AgentIdentityNFT();
    }
    
    function testMint() public {
        vm.prank(owner);
        uint256 agentId = agentNFT.mint(user1);
        
        assertEq(agentId, 0);
        assertEq(agentNFT.ownerOf(agentId), user1);
        assertTrue(agentNFT.exists(agentId));
    }
    
    function testMintAndGetOwner() public {
        vm.prank(owner);
        uint256 agentId = agentNFT.mint(user1);
        
        assertEq(agentNFT.ownerOf(agentId), user1);
    }
    
    function testExists() public {
        vm.prank(owner);
        uint256 agentId = agentNFT.mint(user1);
        
        assertTrue(agentNFT.exists(agentId));
        assertFalse(agentNFT.exists(999));
    }
    
    function testOwnerOfNonExistentToken() public {
        vm.expectRevert("AgentIdentityNFT: agent does not exist");
        agentNFT.ownerOf(999);
    }
    
    function testTokenCreator() public {
        vm.prank(owner);
        uint256 agentId = agentNFT.mint(user1);
        
        assertEq(agentNFT.tokenCreator(agentId), owner);
    }
    
    function testTokenCreatorNonExistentToken() public {
        vm.expectRevert("AgentIdentityNFT: agent does not exist");
        agentNFT.tokenCreator(999);
    }
    
    function testMultipleMints() public {
        vm.prank(owner);
        uint256 agentId1 = agentNFT.mint(user1);
        
        vm.prank(owner);
        uint256 agentId2 = agentNFT.mint(user2);
        
        assertEq(agentId1, 0);
        assertEq(agentId2, 1);
        assertEq(agentNFT.ownerOf(agentId1), user1);
        assertEq(agentNFT.ownerOf(agentId2), user2);
        assertTrue(agentNFT.exists(agentId1));
        assertTrue(agentNFT.exists(agentId2));
    }
}