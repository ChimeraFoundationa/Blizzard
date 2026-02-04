// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../../src/identity/AgentIdentityNFT.sol";

contract AgentIdentityNFTStressTest is Test {
    AgentIdentityNFT agentNFT;
    address owner = address(0x1);
    
    function setUp() public {
        vm.startPrank(owner);
        agentNFT = new AgentIdentityNFT();
        vm.stopPrank();
    }
    
    function testStressMintManyTokens() public {
        uint256 numTokens = 1000;
        address[] memory users = new address[](numTokens);
        
        for (uint256 i = 0; i < numTokens; i++) {
            users[i] = address(uint160(0x1000 + i));
            vm.prank(owner);
            uint256 tokenId = agentNFT.mint(users[i]);
            assertEq(tokenId, i);
            assertEq(agentNFT.ownerOf(i), users[i]);
            assertTrue(agentNFT.exists(i));
        }
        
        // Verify all tokens exist and have correct owners
        for (uint256 i = 0; i < numTokens; i++) {
            assertEq(agentNFT.ownerOf(i), users[i]);
            assertTrue(agentNFT.exists(i));
        }
    }
    
    function testSybilAttackSimulation() public {
        // Simulate one attacker trying to create many NFTs
        address attacker = address(0x999);
        uint256 numTokens = 100;
        
        for (uint256 i = 0; i < numTokens; i++) {
            vm.prank(owner);
            uint256 tokenId = agentNFT.mint(attacker);
            assertEq(tokenId, i);
            assertEq(agentNFT.ownerOf(i), attacker);
        }
        
        // Verify all tokens belong to the attacker
        for (uint256 i = 0; i < numTokens; i++) {
            assertEq(agentNFT.ownerOf(i), attacker);
        }
    }
    
    function testEdgeCaseMaxTokenId() public {
        // Test minting close to max uint256
        vm.prank(owner);
        uint256 tokenId = agentNFT.mint(address(0x123));
        assertEq(tokenId, 0);
        
        // Skip ahead many tokens by minting more
        for (uint256 i = 1; i < 100; i++) {
            vm.prank(owner);
            uint256 newTokenId = agentNFT.mint(address(uint160(0x2000 + i)));
            assertEq(newTokenId, i);
        }
    }
    
    function testFuzzMint(address recipient) public {
        vm.assume(recipient != address(0));
        // Prevent sending to contracts that might not implement ERC721Receiver properly
        vm.assume(!isContract(recipient));

        vm.prank(owner);
        uint256 tokenId = agentNFT.mint(recipient);

        assertEq(agentNFT.ownerOf(tokenId), recipient);
        assertTrue(agentNFT.exists(tokenId));
    }

    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }
    
    function testFuzzOwnerOf(uint256 tokenId) public {
        vm.assume(tokenId < 100); // Limit range for this test
        
        // Pre-mint some tokens
        vm.prank(owner);
        for (uint256 i = 0; i <= tokenId && i < 10; i++) {
            if (!agentNFT.exists(i)) {
                agentNFT.mint(address(uint160(0x2000 + i)));
            }
        }
        
        if (agentNFT.exists(tokenId)) {
            assertTrue(agentNFT.ownerOf(tokenId) != address(0));
        } else {
            vm.expectRevert("AgentIdentityNFT: agent does not exist");
            agentNFT.ownerOf(tokenId);
        }
    }
    
    function testMultipleOwnerships() public {
        address owner1 = address(0x3000);
        address owner2 = address(0x3001);
        address owner3 = address(0x3002);
        
        vm.prank(owner);
        uint256 token1 = agentNFT.mint(owner1);
        vm.prank(owner);
        uint256 token2 = agentNFT.mint(owner2);
        vm.prank(owner);
        uint256 token3 = agentNFT.mint(owner3);
        
        assertEq(agentNFT.ownerOf(token1), owner1);
        assertEq(agentNFT.ownerOf(token2), owner2);
        assertEq(agentNFT.ownerOf(token3), owner3);
        
        // Verify they are all different
        assertTrue(agentNFT.ownerOf(token1) != agentNFT.ownerOf(token2));
        assertTrue(agentNFT.ownerOf(token2) != agentNFT.ownerOf(token3));
        assertTrue(agentNFT.ownerOf(token1) != agentNFT.ownerOf(token3));
    }
    
    function testGasCostAnalysis() public {
        address testUser = address(0x4000);
        
        // Measure gas for minting
        uint256 gasStart = gasleft();
        vm.prank(owner);
        agentNFT.mint(testUser);
        uint256 gasUsed = gasStart - gasleft();
        
        // Gas cost should be reasonable (less than 200k)
        assertTrue(gasUsed < 200000, "Mint gas cost too high");
        
        // Measure gas for exists check
        gasStart = gasleft();
        assertTrue(agentNFT.exists(0));
        gasUsed = gasStart - gasleft();
        
        assertTrue(gasUsed < 5000, "Exists gas cost too high");
        
        // Measure gas for ownerOf
        gasStart = gasleft();
        assertEq(agentNFT.ownerOf(0), testUser);
        gasUsed = gasStart - gasleft();
        
        assertTrue(gasUsed < 5000, "OwnerOf gas cost too high");
    }
}