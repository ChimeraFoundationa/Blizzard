# Blizzard - Trustless AI Agent Infrastructure on Avalanche

## Project Overview

Blizzard is a decentralized validation system deployed on Avalanche, designed for secure and scalable management of agent identities, validators, and reputations using ERC-8004 NFTs.

## 🚀 Key Features

- **ERC-8004 Agent NFTs**: Unique digital identities for validators/agents
- **Validator Staking & Management**: Secure staking and tracking of validators
- **Challenge & Slashing Mechanisms**: Incentivizes correct validations and punishes misconduct
- **Reputation System**: Tracks validator performance, rewarding consistent behavior
- **MCP (Managed Communication Protocol)**: Execute agent tasks and on-chain jobs
- **A2A (Agent-to-Agent)**: Off-chain communication for task delegation
- **Proof-of-Work Integration**: Agents must perform work to gain reputation
- **Anti-Sybil Protection**: Economic barriers and reputation requirements

## 📂 Architecture

### 1. Identity Layer (`src/identity/`)
- `AgentIdentityNFT.sol`: ERC-8004-compliant NFT for agent identities
  - Unique minting with base/null reputation
  - Ownership tracking and existence verification
  - MCP (X402) wallet integration

### 2. Reputation Layer (`src/reputation/`)
- `ReputationRegistry.sol`: Maps agentId → reputation score
  - Authorized caller system for modifications
  - Safe decrease operations (no negative values)
  - Reputation gain via Proof-of-Work contributions
  - Work type and difficulty-based reward calculation

### 3. Validation Layer (`src/validation/`)
- `ValidatorRegistry.sol`: Minimum 1 AVAX stake, active validator tracking, slashing
- `ValidationManager.sol`: Core workflow (submission, challenge, finalize)
  - Reputation rewards integration
  - Full slashing on challenges during challenge period

### 4. Interfaces (`src/interfaces/`)
- `IMCP.sol`: Managed Communication Protocol for X402 wallet integration
- `IA2A.sol`: Agent-to-Agent communication protocol

## 🏗️ Technical Specifications

- **Language**: Solidity 0.8.30
- **Framework**: Foundry/Forge
- **Dependencies**: OpenZeppelin Contracts v4.9.0
- **Target Network**: Avalanche C-Chain
- **Security**: Role-based access control, safe arithmetic, proper validation checks

## 🧪 Testing Coverage

- **Unit Tests**: Core functionality validation
- **Stress Tests**: 1000+ validators, submissions, and reputation updates
- **Sybil Simulation**: 100+ malicious agents attempting attacks
- **Fuzz Testing**: Randomized stake, submission timing, and reputation values
- **Total Tests**: 77 tests passing (original + stress + Sybil + fuzz)

## 📊 Performance Metrics

- **NFTs minted**: 1000+ tokens
- **Validators registered**: 1000+ simultaneous
- **Submissions processed**: 1000+ validations
- **Reputation updates**: 1000+ concurrent operations

## 🚀 Deployment

Deployment scripts available for:
- Local development
- Avalanche Fuji Testnet
- Avalanche Mainnet

## 🛡️ Security Features

- Role-based access controls for critical functions
- Safe arithmetic for all operations
- Slashing and reputation mechanisms to discourage malicious behavior
- Tested against Sybil attacks and edge cases
- Proper validation checks throughout the system

## 📁 Project Structure

```
src/
 ├── identity/      # ERC-8004 Agent NFT
 │   ├── AgentIdentityNFT.sol
 │   └── interfaces/
 │       ├── IMCP.sol
 │       └── IA2A.sol
 ├── reputation/    # Reputation management
 │   └── ReputationRegistry.sol
 └── validation/    # Validators and validation workflow
     ├── ValidatorRegistry.sol
     └── ValidationManager.sol

test/
 ├── identity/      # AgentIdentityNFT tests
 ├── reputation/    # ReputationRegistry tests
 └── validation/    # ValidatorRegistry & ValidationManager tests

script/
 └── DeployBlizzard.s.sol          # Local deployment script
 └── DeployBlizzardAvalanche.s.sol # Avalanche deployment script
```

## 📄 License

MIT License